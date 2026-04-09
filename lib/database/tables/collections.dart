import 'package:drift/drift.dart';

/// 合集表
class Collections extends Table {
  /// UUID 主键
  TextColumn get id => text()();

  /// 合集名称
  TextColumn get name => text()();

  /// 创建时间
  DateTimeColumn get createdDate => dateTime()();

  /// 置顶
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 最后修改时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除标记
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步状态
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
