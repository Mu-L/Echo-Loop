import 'package:drift/drift.dart';

/// 用户已学习词形表
///
/// 记录用户在真实学习音频中首次听到的唯一词形。
/// 统计口径使用 surface form，因此 child 和 children 分开记录。
class LearnedWordForms extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 统一清洗后的小写词形，全局唯一
  TextColumn get wordForm => text().unique()();

  /// 首次学习时间
  DateTimeColumn get firstLearnedAt => dateTime()();
}
