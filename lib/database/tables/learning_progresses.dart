import 'package:drift/drift.dart';

import 'audio_items.dart';

/// 学习进度表
///
/// 单表设计，一行一个音频。完成状态由 currentStage + currentSubStage 推导。
/// 两列均为 TEXT，存储枚举的字符串键，解耦存储与枚举顺序。
class LearningProgresses extends Table {
  /// 音频 ID，主键 + 外键关联 audio_items（级联删除）
  TextColumn get audioItemId =>
      text().references(AudioItems, #id, onDelete: KeyAction.cascade)();

  /// 当前大阶段键（对应 LearningStage.key）
  TextColumn get currentStage =>
      text().withDefault(const Constant('firstLearn'))();

  /// 当前子步骤键（对应 SubStageType.key）
  TextColumn get currentSubStage =>
      text().withDefault(const Constant('blindListen'))();

  /// 难度等级（0=easy, 1=medium, 2=hard）
  IntColumn get difficulty => integer().withDefault(const Constant(1))();

  /// 首学完成时间（复习间隔计算基准，首学完成前为 null）
  DateTimeColumn get firstLearnCompletedAt => dateTime().nullable()();

  /// 上一阶段完成时间（复习调度核心字段，用于计算下次复习时间）
  DateTimeColumn get lastStageCompletedAt => dateTime().nullable()();

  /// 当前阶段开始时间（进入该阶段的时间，用于断点续学和耗时计算）
  DateTimeColumn get currentStageStartedAt => dateTime().nullable()();

  /// 累计学习时长（毫秒）
  IntColumn get totalStudyDurationMs =>
      integer().withDefault(const Constant(0))();

  /// 最后更新时间
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {audioItemId};
}
