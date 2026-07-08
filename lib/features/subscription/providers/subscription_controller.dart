/// 订阅权益控制器：App 内权益的**唯一真相源**。
///
/// 职责（对齐项目「单向数据流 + 集中状态变更入口」）：
/// - 启动用本地缓存 seed，再触发与在线权威源（后端 / RC）的对账（C4 合并规则）。
/// - 监听 [supabaseSessionProvider]：登出清权益、切换用户重对账（身份单一来源）。
/// - 用 generation counter 防异步竞态（吸取 CLAUDE.md §7.1/§7.2 教训：
///   旧用户的异步回调到达时必须丢弃，不能污染新用户 state）。
///
/// UI 永远只读本 controller 的 state，不直接读缓存 / RC / 后端。
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../services/app_logger.dart';
import '../models/entitlement.dart';
import '../services/entitlement_cache.dart';
import '../services/entitlement_reconciler.dart';
import '../services/entitlement_repository.dart';
import '../services/purchase_service.dart';
import '../services/revenuecat_purchase_service.dart';
import '../state/entitlement_state.dart';
import 'subscription_identity.dart';

part 'subscription_controller.g.dart';

@Riverpod(keepAlive: true)
class SubscriptionController extends _$SubscriptionController {
  /// 防竞态代际计数。每次重对账 / 登录切换前自增，异步回调校验不匹配则丢弃。
  int _generation = 0;

  /// 调试用权益覆盖（仅 debug 构建）。非 null 时 [refresh] 短路为该状态，
  /// 用于不发起真实购买即测试会员 UI / Paywall 门禁。release 不暴露入口。
  EntitlementStatus? _debugOverride;

  @override
  EntitlementState build() {
    // 监听身份变化：登出清权益、切换用户重对账。
    // fireImmediately：build 时立即以当前身份触发一次，确保已登录用户即使在
    // 「身份早已落定后」才首次创建本 controller，也会执行一次 Purchases.logIn 绑定
    // （否则默认只在值变化时回调 → 老用户登录态无变化 → logIn 从不执行 → 匿名购买）。
    ref.listen(subscriptionIdentityProvider, (previous, next) {
      _onIdentityChanged(previous, next);
    }, fireImmediately: true);
    // 监听平台侧权益变化（续费 / 退款 / 试用转正），运行期实时刷新。
    final sub = _purchases.entitlementStream.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    // 冷启动首帧返回「未知」中间态（C5），随后异步对账。
    unawaited(refresh());
    return const EntitlementState.unknown();
  }

  EntitlementCache get _cache => ref.read(entitlementCacheProvider);
  EntitlementRepository get _repository =>
      ref.read(entitlementRepositoryProvider);
  PurchaseService get _purchases => ref.read(purchaseServiceProvider);

  SubscriptionIdentity get _identity => ref.read(subscriptionIdentityProvider);

  /// 与在线权威源对账并刷新权益。集中状态变更入口之一。
  Future<void> refresh() async {
    // 调试覆盖生效时跳过在线对账，保持人为设定的状态。
    final override = _debugOverride;
    if (override != null) {
      state = _stateForOverride(override);
      return;
    }
    final generation = ++_generation;
    final identity = _identity;
    final userId = identity.userId;
    final accessToken = identity.accessToken;

    final cached = await _readValidCache(userId);
    Entitlement? remote;
    String? error;
    try {
      // 后端权威源（Phase 1 接入；当前 stub 返回 null）。
      if (userId != null && accessToken != null) {
        remote = await _repository.fetchRemote(
          userId: userId,
          accessToken: accessToken,
        );
      }
      // 后端未就绪时，用 RevenueCat 已服务端校验的 CustomerInfo 作为在线权威源。
      remote ??= await _purchases.currentEntitlement();
    } catch (e) {
      // 失败不静默吞：记录错误、保留兜底，不误判为无权益。
      error = e.toString();
    }

    if (generation != _generation) return; // 已被更新的对账 / 登录切换作废。

    final next = reconcileEntitlement(
      remote: remote,
      cached: cached,
      now: clock.now(),
    );
    state = error == null ? next : next.copyWith(error: error, isStale: true);

    // 对账关键日志：在线源 / 缓存各自结果 + 合并后最终态，便于排查
    // 「删了订阅仍显示已订阅」「在线不可达走缓存」等问题。
    AppLogger.log(
      'Subscription',
      '对账完成: remote=${remote != null ? "isPremium=${remote.isPremium}" : "无"} '
          'cached=${cached != null ? "isPremium=${cached.entitlement.isPremium}" : "无"} '
          '→ status=${state.status.name} isStale=${state.isStale}'
          '${error != null ? " error=$error" : ""}',
    );

    if (remote != null) {
      await _writeCache(remote, userId);
    }
  }

  /// 发起购买。成功后立即本地解锁（不等后端 webhook，避免延迟），再触发后端对账。
  Future<void> purchase(String planId) async {
    AppLogger.log(
      'Subscription',
      '发起购买: planId=$planId userId=${_identity.userId ?? "匿名"}',
    );
    await _ensurePurchaseIdentity(); // fail-closed：未绑定 Supabase user_id 直接中止。
    try {
      final entitlement = await _purchases.purchase(planId);
      await _applyEntitlement(entitlement, _identity.userId);
      AppLogger.log(
        'Subscription',
        '购买成功: isPremium=${entitlement.isPremium} productId=${entitlement.productId} '
            'expiresAt=${entitlement.expiresAt?.toIso8601String() ?? "无"}',
      );
      unawaited(refresh());
    } on PurchaseException catch (e) {
      // 取消与失败分别记录：取消属正常路径，不当错误处理。
      AppLogger.log(
        'Subscription',
        e.cancelled
            ? '购买取消: planId=$planId'
            : '购买失败: planId=$planId msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      AppLogger.log('Subscription', '购买异常: planId=$planId error=$e');
      rethrow;
    }
  }

  /// 恢复购买。
  Future<void> restore() async {
    AppLogger.log('Subscription', '发起恢复购买: userId=${_identity.userId ?? "匿名"}');
    await _ensurePurchaseIdentity(); // fail-closed：未绑定 Supabase user_id 直接中止。
    try {
      final entitlement = await _purchases.restore();
      await _applyEntitlement(entitlement, _identity.userId);
      AppLogger.log(
        'Subscription',
        '恢复完成: isPremium=${entitlement.isPremium} productId=${entitlement.productId}',
      );
      unawaited(refresh());
    } catch (e) {
      AppLogger.log('Subscription', '恢复购买失败: error=$e');
      rethrow;
    }
  }

  /// 清本地权益缓存 + 失效平台 SDK 缓存后强制重对账（调试用）。
  ///
  /// 解决「后台已删订阅但 App 仍显示已订阅」：本地 secure_storage 缓存与
  /// RevenueCat SDK 的 CustomerInfo 缓存都会让旧权益继续生效，这里一并清掉
  /// 再回源对账。同时解除调试覆盖，回到真实在线结果。
  Future<void> clearLocalCacheAndRefresh() async {
    _debugOverride = null;
    _generation++; // 作废在途对账。
    await _cache.clear();
    await _purchases.invalidateCustomerInfoCache();
    await refresh();
  }

  /// 手动覆盖权益状态（仅 debug 构建）。传 null 解除覆盖并重新对账。
  ///
  /// 用于不发起真实购买即验证会员 UI / Paywall 门禁；release 构建无入口。
  void debugOverrideEntitlement(EntitlementStatus? status) {
    if (!kDebugMode) return;
    _debugOverride = status;
    if (status == null) {
      unawaited(refresh());
      return;
    }
    _generation++; // 作废在途对账，避免被真实结果覆盖。
    state = _stateForOverride(status);
  }

  /// 由覆盖状态构造对应的 [EntitlementState]。
  EntitlementState _stateForOverride(EntitlementStatus status) {
    return switch (status) {
      EntitlementStatus.premium => EntitlementState(
        status: EntitlementStatus.premium,
        entitlement: const Entitlement(
          isPremium: true,
          productId: 'debug_override',
        ),
        isStale: false,
      ),
      EntitlementStatus.free => const EntitlementState.free(),
      EntitlementStatus.unknown => const EntitlementState.unknown(),
    };
  }

  /// 立即把一份权益应用为当前 state 并落盘（购买 / 恢复成功路径）。
  Future<void> _applyEntitlement(
    Entitlement entitlement,
    String? userId,
  ) async {
    final generation = ++_generation;
    if (generation != _generation) return;
    state = EntitlementState(
      status: entitlement.isActive(clock.now())
          ? EntitlementStatus.premium
          : EntitlementStatus.free,
      entitlement: entitlement,
      isStale: false,
    );
    await _writeCache(entitlement, userId);
  }

  /// 购买 / 恢复前的 fail-closed 身份门禁。
  ///
  /// 权益必须绑定到 Supabase user_id（跨设备、可恢复、能被 webhook 落库）。
  /// 未登录，或购买服务无法确认已绑定到该用户（RC 仍是匿名 / 绑定异常）时，
  /// 抛 [PurchaseException] 中止，**绝不允许在匿名身份上成交**。
  Future<void> _ensurePurchaseIdentity() async {
    final userId = _identity.userId;
    if (userId == null) {
      AppLogger.log('Subscription', '购买中止：未登录，无法绑定 Supabase user_id');
      throw PurchaseException('订阅需先登录账号');
    }
    final bound = await _purchases.ensureIdentified(userId);
    if (!bound) {
      AppLogger.log('Subscription', '购买中止：身份未就绪（未绑定到 userId=$userId）');
      throw PurchaseException('订阅身份未就绪，请稍后重试');
    }
  }

  /// 响应订阅身份变化。
  Future<void> _onIdentityChanged(
    SubscriptionIdentity? previous,
    SubscriptionIdentity next,
  ) async {
    final previousUserId = previous?.userId;
    final nextUserId = next.userId;
    if (previousUserId == nextUserId) return; // 仅 token 刷新，忽略。

    _generation++; // 作废在途对账。
    if (nextUserId == null) {
      // 登出：清权益 + 清缓存 + 解绑购买身份。
      await _purchases.identify(null);
      await _cache.clear();
      state = const EntitlementState.free();
      return;
    }
    // 登录 / 切换用户：绑定购买身份后重对账。
    await _purchases.identify(nextUserId);
    await refresh();
  }

  /// 读取缓存，并校验归属用户；与当前用户不一致的缓存视为无效（防跨账号泄漏）。
  Future<CachedEntitlement?> _readValidCache(String? userId) async {
    final cached = await _cache.read();
    if (cached == null) return null;
    if (cached.userId != userId) return null;
    return cached;
  }

  Future<void> _writeCache(Entitlement entitlement, String? userId) async {
    await _cache.write(
      CachedEntitlement(
        userId: userId,
        entitlement: entitlement,
        cachedAt: clock.now(),
      ),
    );
  }
}
