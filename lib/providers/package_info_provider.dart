/// PackageInfo Provider
///
/// 在 main.dart 中通过 ProviderScope.overrides 注入实例，
/// 与 appDatabaseProvider 模式一致。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// PackageInfo Provider
/// 在 main.dart 中通过 ProviderScope override 注入实例
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError('packageInfoProvider 必须在 ProviderScope 中 override');
});

/// 读取 app 版本号（供 `x-app-version` header 上报）。
///
/// [packageInfoProvider] 未 override（如部分测试环境）时降级为 null（省略版本
/// header），不让辅助信息阻断客户端构建（同 §7.18 惰性降级原则）。多个后端 client
/// 共用此 helper，避免各处重复实现。
String? readAppVersion(Ref ref) {
  try {
    return ref.read(packageInfoProvider).version;
  } catch (_) {
    return null;
  }
}
