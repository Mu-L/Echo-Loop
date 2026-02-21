import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/stage_completions.dart';

part 'stage_completion_dao.g.dart';

/// 步骤完成历史 DAO
///
/// 提供步骤完成记录的插入、查询和删除操作。
@DriftAccessor(tables: [StageCompletions])
class StageCompletionDao extends DatabaseAccessor<AppDatabase>
    with _$StageCompletionDaoMixin {
  StageCompletionDao(super.db);

  /// 插入一条步骤完成记录
  Future<void> insertRecord(StageCompletionsCompanion entry) {
    return into(stageCompletions).insert(entry);
  }

  /// 查询指定音频的所有完成记录（按完成时间升序）
  Future<List<StageCompletion>> getByAudioId(String audioItemId) {
    return (select(stageCompletions)
          ..where((t) => t.audioItemId.equals(audioItemId))
          ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]))
        .get();
  }

  /// 删除指定音频的所有完成记录
  Future<void> deleteByAudioId(String audioItemId) {
    return (delete(
      stageCompletions,
    )..where((t) => t.audioItemId.equals(audioItemId))).go();
  }
}
