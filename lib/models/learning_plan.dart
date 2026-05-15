/// 全局学习计划值对象
///
/// 单一事实来源：每个大阶段当前实际计划做哪些子步骤。从 [LearningSettings]
/// 派生（仅 `retellEnabled` 一个维度），UI / 推进 / reconcile / 进度计算
/// 都只读这个对象的 API（`subStagesFor` / `includes` / `indexOf`），
/// 不再四处判断 `retellEnabled`。
///
/// 未来扩展（全局自定义学习流）：只需扩 [LearningSettings] 字段 +
/// 改 [LearningPlan.fromSettings] 一处，consumer 零修改。
library;

import '../database/enums.dart';
import '../providers/learning_settings_provider.dart';

/// 不可变学习计划。
class LearningPlan {
  final Map<LearningStage, List<SubStageType>> _stages;

  const LearningPlan(this._stages);

  /// 从用户全局设置派生计划。
  ///
  /// 当前规则：`retellEnabled == false` 时移除所有复述类子步骤。
  factory LearningPlan.fromSettings(LearningSettings settings) {
    return LearningPlan({
      for (final stage in LearningStage.values)
        stage: stage.allSubStages
            .where(
              (sub) => !isRetellSubStage(sub) || settings.retellEnabled,
            )
            .toList(growable: false),
    });
  }

  /// 指定大阶段的计划子步骤列表（有序）。
  ///
  /// 该阶段无任何 planned 子步骤时返回空列表（如 [LearningStage.completed]，
  /// 或所有子步骤都被设置过滤掉）。
  List<SubStageType> subStagesFor(LearningStage stage) =>
      _stages[stage] ?? const [];

  /// 判断 [sub] 是否在 [stage] 的计划列表内。
  bool includes(LearningStage stage, SubStageType sub) =>
      subStagesFor(stage).contains(sub);

  /// 返回 [sub] 在 [stage] 计划列表中的索引；不在列表返回 -1。
  int indexOf(LearningStage stage, SubStageType sub) =>
      subStagesFor(stage).indexOf(sub);

  /// 全部 planned 子步骤计数（跨所有阶段，用作进度比例分母）。
  int get totalPlannedCount =>
      _stages.values.fold(0, (s, l) => s + l.length);

  /// 找当前阶段 plan 内 [currentSubStage] 之后的下一个 planned 子步骤。
  ///
  /// - 当前阶段 plan 内有后续 → 返回 `(stage, nextSubStage)`
  /// - 当前是 plan 末尾、不在 plan、或阶段 plan 空 → 返回 `null`
  ///
  /// 跨阶段不引导：完成本大阶段是自然终点，调用方按 `null` 表示"无后续"
  /// 来决定 UI（例如完成弹窗只显示「完成」按钮）。
  ({LearningStage stage, SubStageType subStage})? nextPlannedAfter(
    LearningStage currentStage,
    SubStageType currentSubStage,
  ) {
    final planned = subStagesFor(currentStage);
    final idx = planned.indexOf(currentSubStage);
    if (idx < 0) return null;
    if (idx + 1 >= planned.length) return null;
    return (stage: currentStage, subStage: planned[idx + 1]);
  }
}
