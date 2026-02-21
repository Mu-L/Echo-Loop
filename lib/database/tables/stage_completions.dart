import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 步骤完成历史表
///
/// 记录每个学习步骤的完成事件，支持按步骤查看完成时间和耗时。
/// 用于学习时间线回溯、耗时统计和完成记录展示。
class StageCompletions extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 音频 ID，外键关联 audio_items（级联删除）
  TextColumn get audioItemId =>
      text().references(AudioItems, #id, onDelete: KeyAction.cascade)();

  /// 完成的大阶段键（对应 LearningStage.key）
  TextColumn get stage => text()();

  /// 完成的子步骤键（对应 SubStageType.key）
  TextColumn get subStage => text()();

  /// 完成时间
  DateTimeColumn get completedAt => dateTime()();

  /// 该步骤耗时（毫秒），默认 0
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
}
