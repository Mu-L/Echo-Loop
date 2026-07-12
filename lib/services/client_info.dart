/// 客户端平台/渠道/版本标识（API 请求公共 header）。
///
/// 后端按 `x-app-platform` + `x-app-distribution` 决定是否执行 AI 免费额度限制
/// （env `AI_QUOTA_ENFORCED_CLIENTS` 组合列表，见 docs/subscription-setup.md）。
/// 老版本客户端缺少渠道 header，后端一律放行（fail-open）。
library;

import '../config/client_distribution.dart';

export '../config/client_distribution.dart' show clientPlatformName;

/// 平台标识 header 名（与后端约定，小写）。
const String kAppPlatformHeader = 'x-app-platform';

/// 分发渠道 header 名（与后端约定，小写）。
const String kAppDistributionHeader = 'x-app-distribution';

/// App 版本 header 名（为未来按版本灰度预留）。
const String kAppVersionHeader = 'x-app-version';

/// API 请求的公共客户端标识 headers。
///
/// [appVersion] 为空/null 时省略版本 header（如测试环境拿不到 PackageInfo）。
Map<String, String> clientInfoHeaders({String? appVersion}) {
  final platform = clientPlatformName();
  final distribution = clientDistribution;
  return {
    if (platform.isNotEmpty) kAppPlatformHeader: platform,
    if (distribution != null) kAppDistributionHeader: distribution.headerValue,
    if (appVersion != null && appVersion.isNotEmpty)
      kAppVersionHeader: appVersion,
  };
}
