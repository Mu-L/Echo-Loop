import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前时间读取函数类型。
typedef NowGetter = DateTime Function();

/// 统一的当前时间 Provider。
///
/// 生产环境使用系统时间，测试可 override 为固定时间，
/// 以便稳定验证复习解锁边界（例如 now == nextReviewAt）。
final nowProvider = Provider<NowGetter>((ref) {
  return DateTime.now;
});
