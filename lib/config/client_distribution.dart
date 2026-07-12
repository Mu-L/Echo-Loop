/// 客户端平台与分发渠道的统一身份协议。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// 对外分发渠道协议，只允许商店与直装三类正式值。
enum ClientDistribution {
  play('play'),
  appStore('app_store'),
  direct('direct');

  const ClientDistribution(this.headerValue);

  final String headerValue;
}

/// 客户端本地选择的支付实现类型。
enum ClientPaymentChannel { appleStore, googlePlay, web, unavailable }

/// 编译期注入的原始分发渠道。
const rawDistributionChannel = String.fromEnvironment('DISTRIBUTION_CHANNEL');

/// 解析分发渠道，并兼容旧构建值 `apk` / `desktop`。
///
/// 未注入或非法值返回 null，使本地支付入口保守隐藏、后端请求省略渠道 header。
@visibleForTesting
ClientDistribution? parseClientDistribution(String rawValue) {
  switch (rawValue.trim().toLowerCase()) {
    case 'play':
      return ClientDistribution.play;
    case 'app_store':
      return ClientDistribution.appStore;
    case 'direct':
    case 'apk':
    case 'desktop':
      return ClientDistribution.direct;
    default:
      return null;
  }
}

/// 当前构建的规范化分发渠道。
ClientDistribution? get clientDistribution =>
    parseClientDistribution(rawDistributionChannel);

/// 当前平台名：`ios` / `macos` / `android` / `windows`，未知平台返回空串。
String clientPlatformName() {
  if (kIsWeb) return '';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  return '';
}

/// 判断平台与渠道是否属于正式支持的组合。
@visibleForTesting
bool isValidClientIdentity(String platform, ClientDistribution distribution) {
  return switch ((platform, distribution)) {
    ('android', ClientDistribution.play || ClientDistribution.direct) => true,
    ('ios', ClientDistribution.appStore) => true,
    ('macos', ClientDistribution.appStore || ClientDistribution.direct) => true,
    ('windows', ClientDistribution.direct) => true,
    _ => false,
  };
}

/// 根据平台与渠道选择支付实现；非法组合一律不可用。
@visibleForTesting
ClientPaymentChannel paymentChannelForIdentity(
  String platform,
  ClientDistribution? distribution,
) {
  if (distribution == null || !isValidClientIdentity(platform, distribution)) {
    return ClientPaymentChannel.unavailable;
  }
  return switch (distribution) {
    ClientDistribution.appStore => ClientPaymentChannel.appleStore,
    ClientDistribution.play => ClientPaymentChannel.googlePlay,
    ClientDistribution.direct => ClientPaymentChannel.web,
  };
}

/// 当前构建应使用的支付实现。
ClientPaymentChannel get clientPaymentChannel =>
    paymentChannelForIdentity(clientPlatformName(), clientDistribution);
