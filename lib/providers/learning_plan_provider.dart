/// 全局学习计划 Provider
///
/// 派生自 [learningSettingsProvider]，供 UI / 推进 / reconcile / 进度计算
/// 统一读取。settings 变化时 plan 自动重建，consumer 不需要手动 reconcile。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_plan.dart';
import 'learning_settings_provider.dart';

final learningPlanProvider = Provider<LearningPlan>((ref) {
  final settings = ref.watch(learningSettingsProvider);
  return LearningPlan.fromSettings(settings);
});
