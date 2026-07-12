/// 订阅可用性查询：当前平台是否启用订阅。
///
/// UI 层所有「要不要展示订阅入口 / 能不能进 Paywall」的判断统一 watch 本
/// provider，不直接读 config——集中一个入口，测试可 override 模拟各平台。
///
/// 真相源是 channel-aware 的 [subscriptionAvailableFor]：先由 `platform +
/// DISTRIBUTION_CHANNEL` 决定 [clientPaymentChannel]（见 `client_distribution.dart`），
/// 再看该渠道对应实现是否配置就绪（原生 RC key / 网页 Purchase Link）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../config/revenuecat_config.dart';
import '../../../config/web_purchase_config.dart';
import '../../../config/client_distribution.dart';

part 'subscription_availability.g.dart';

/// 当前平台是否支持订阅（订阅 UI 展示总闸）。
@riverpod
bool subscriptionAvailability(Ref ref) => subscriptionAvailableFor(
  channel: clientPaymentChannel,
  // 本地 StoreKit 测试模式仅对 Apple 渠道生效（与 purchaseServiceTypeFor 一致），
  // 避免 Android 下 USE_LOCAL_STOREKIT=true 但无 Google key 时门控误判可用、
  // 购买却落回 Stub。
  nativeStoreConfigured:
      isRevenueCatConfigured ||
      (useLocalStoreKit &&
          clientPaymentChannel == ClientPaymentChannel.appleStore),
  webConfigured: isWebCheckoutConfigured,
);

/// 根据本地渠道与对应实现的配置状态决定是否展示订阅能力。
bool subscriptionAvailableFor({
  required ClientPaymentChannel channel,
  required bool nativeStoreConfigured,
  required bool webConfigured,
}) {
  return switch (channel) {
    ClientPaymentChannel.appleStore ||
    ClientPaymentChannel.googlePlay => nativeStoreConfigured,
    ClientPaymentChannel.web => webConfigured,
    ClientPaymentChannel.unavailable => false,
  };
}

/// 当前是否走「网页支付」渠道（侧载 APK / 桌面）。
///
/// Paywall 据此切换购买交互：true 时不展示商店套餐卡、改为「浏览器结账 + 回流对账」。
/// 测试可 override 模拟网页渠道。
@riverpod
bool webCheckoutMode(Ref ref) => webCheckoutModeFor(
  channel: clientPaymentChannel,
  webConfigured: isWebCheckoutConfigured,
);

/// 仅 direct 且网页结账配置完整时进入 Web checkout 模式。
bool webCheckoutModeFor({
  required ClientPaymentChannel channel,
  required bool webConfigured,
}) => channel == ClientPaymentChannel.web && webConfigured;
