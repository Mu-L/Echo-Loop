// 网页支付（RevenueCat Web Purchase Link）配置
//
// 面向**无商店内购通道**的分发渠道：Android 侧载 APK、macOS 官网/GitHub 下载、
// Windows。这些端没有可用的 RevenueCat 原生 SDK，购买改为在浏览器打开
// RevenueCat 托管的 Web Purchase Link（底层计费引擎为 Paddle，作为 MoR），权益仍由 RC webhook 落库、
// 客户端经后端 `/api/entitlements` 读回（见 `entitlement_repository.dart`）。
//
// **Google Play 政策洁净（关键）**：网页支付入口**只能进「非商店」构建**。是否启用
// 由编译期 `--dart-define=DISTRIBUTION_CHANNEL` 决定——APK/桌面构建注入 `direct`
// 才启用；Play 版（appbundle）不注入或注入 `play`，构建里根本不含引导外部支付的路径。
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../services/app_logger.dart';
import 'client_distribution.dart';

/// RevenueCat Web Purchase Link 模板。
///
/// 模板必须包含 `{app_user_id}` 占位符，例如：
/// `https://pay.rev.cat/<token>/{app_user_id}/paywall`
///
/// release 注入 production 模板，debug/测试注入 sandbox 模板；不注入则网页支付不可用。
const webPurchaseLinkTemplate = String.fromEnvironment(
  'WEB_PURCHASE_LINK_TEMPLATE',
);

const _appUserIdPlaceholder = '{app_user_id}';

/// 当前构建是否属于「启用网页支付」的分发渠道（仅编译期判定，Play 版恒 false）。
bool get isWebCheckoutChannel =>
    clientPaymentChannel == ClientPaymentChannel.web;

/// 网页支付是否可用（渠道启用 **且** 已注入 Purchase Link base）。
///
/// 二者缺一即不可用：渠道未开 → 政策洁净不暴露入口；模板缺失 → 无处结账。
bool get isWebCheckoutConfigured =>
    isWebCheckoutChannel &&
    webPurchaseLinkTemplate.contains(_appUserIdPlaceholder);

/// 拼出携带用户身份的 Web Purchase Link。
///
/// 必须附 URL-encoded 的 Supabase user.id 作为 RevenueCat app_user_id：不附则
/// RevenueCat 返回 404（见官方文档），且权益无法绑定到用户。调用方须保证已登录。
/// [userId] 为空时返回 null（调用方应先要求登录，不发起结账）。
Uri? buildWebPurchaseUri(String userId) {
  final uri = isWebCheckoutConfigured && userId.isNotEmpty
      ? composeWebPurchaseUri(webPurchaseLinkTemplate, userId)
      : null;
  logWebPurchaseConfig(stage: 'buildWebPurchaseUri', userId: userId, uri: uri);
  return uri;
}

/// 纯函数：把模板中的 `{app_user_id}` 替换成已编码的用户 ID。
///
/// 模板为空、缺占位符或 [userId] 为空时返回 null。
@visibleForTesting
Uri? composeWebPurchaseUri(String template, String userId) {
  if (template.isEmpty ||
      userId.isEmpty ||
      !template.contains(_appUserIdPlaceholder)) {
    return null;
  }
  return Uri.parse(
    template.replaceAll(_appUserIdPlaceholder, Uri.encodeComponent(userId)),
  );
}

/// 记录网页支付关键配置状态。
///
/// 不打印完整 userId，避免日志导出时泄露用户标识；模板本身是公开 purchase link，
/// 这里仅打印是否配置和占位符状态。
void logWebPurchaseConfig({required String stage, String? userId, Uri? uri}) {
  AppLogger.log(
    'Subscription',
    'webPurchase[$stage] channel=$rawDistributionChannel '
        'isWebCheckoutChannel=$isWebCheckoutChannel '
        'templateConfigured=${webPurchaseLinkTemplate.isNotEmpty} '
        'templateHasAppUserId=${webPurchaseLinkTemplate.contains(_appUserIdPlaceholder)} '
        'isWebCheckoutConfigured=$isWebCheckoutConfigured '
        'userIdPresent=${userId != null && userId.isNotEmpty} '
        'userIdLength=${userId?.length ?? 0} '
        'uriBuilt=${uri != null} uriHost=${uri?.host ?? "null"} '
        'uriPath=${uri?.path ?? "null"}',
  );
}
