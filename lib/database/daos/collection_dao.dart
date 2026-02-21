import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/collections.dart';
import '../tables/collection_audio_items.dart';

part 'collection_dao.g.dart';

/// 合集 DAO
/// 提供合集的 CRUD 操作及合集-音频关联管理
@DriftAccessor(tables: [Collections, CollectionAudioItems])
class CollectionDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionDaoMixin {
  CollectionDao(super.db);

  /// 获取所有未删除的合集
  Future<List<Collection>> getAllActive() {
    return (select(collections)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdDate)]))
        .get();
  }

  /// 监听所有未删除的合集
  Stream<List<Collection>> watchAllActive() {
    return (select(collections)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdDate)]))
        .watch();
  }

  /// 根据 ID 获取合集
  Future<Collection?> getById(String id) {
    return (select(
      collections,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入或更新合集
  Future<void> upsert(CollectionsCompanion entry) {
    return into(collections).insertOnConflictUpdate(entry);
  }

  /// 软删除合集
  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (update(collections)..where((t) => t.id.equals(id))).write(
      CollectionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: Value(2),
      ),
    );
  }

  /// 硬删除合集
  Future<void> hardDelete(String id) {
    return (delete(collections)..where((t) => t.id.equals(id))).go();
  }

  // --- Junction 表操作 ---

  /// 获取合集中的音频 ID 列表（按排序序号）
  Future<List<String>> getAudioIds(String collectionId) async {
    final rows =
        await (select(collectionAudioItems)
              ..where((t) => t.collectionId.equals(collectionId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map((r) => r.audioItemId).toList();
  }

  /// 监听合集中的音频 ID 列表
  Stream<List<String>> watchAudioIds(String collectionId) {
    return (select(collectionAudioItems)
          ..where((t) => t.collectionId.equals(collectionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map((r) => r.audioItemId).toList());
  }

  /// 获取合集中的音频数量
  Future<int> getAudioCount(String collectionId) async {
    final count = countAll();
    final query = selectOnly(collectionAudioItems)
      ..addColumns([count])
      ..where(collectionAudioItems.collectionId.equals(collectionId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// 添加音频到合集
  Future<void> addAudio(String collectionId, String audioItemId) async {
    // 获取当前最大排序序号
    final maxOrder = await _getMaxSortOrder(collectionId);
    await into(collectionAudioItems).insertOnConflictUpdate(
      CollectionAudioItemsCompanion(
        collectionId: Value(collectionId),
        audioItemId: Value(audioItemId),
        sortOrder: Value(maxOrder + 1),
        addedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 从合集中移除音频
  Future<void> removeAudio(String collectionId, String audioItemId) {
    return (delete(collectionAudioItems)..where(
          (t) =>
              t.collectionId.equals(collectionId) &
              t.audioItemId.equals(audioItemId),
        ))
        .go();
  }

  /// 从所有合集中移除指定音频（当音频被删除时调用）
  Future<void> removeAudioFromAll(String audioItemId) {
    return (delete(
      collectionAudioItems,
    )..where((t) => t.audioItemId.equals(audioItemId))).go();
  }

  /// 获取合集内当前最大排序序号
  Future<int> _getMaxSortOrder(String collectionId) async {
    final maxCol = collectionAudioItems.sortOrder.max();
    final query = selectOnly(collectionAudioItems)
      ..addColumns([maxCol])
      ..where(collectionAudioItems.collectionId.equals(collectionId));
    final row = await query.getSingle();
    return row.read(maxCol) ?? -1;
  }

  /// 批量插入合集-音频关联（用于迁移）
  Future<void> batchInsertJunctions(
    List<CollectionAudioItemsCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAll(
        collectionAudioItems,
        entries,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}
