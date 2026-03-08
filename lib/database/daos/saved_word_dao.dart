import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/saved_words.dart';

part 'saved_word_dao.g.dart';

/// 收藏单词 DAO
///
/// 提供收藏单词的 CRUD 操作，支持流式监听。
@DriftAccessor(tables: [SavedWords])
class SavedWordDao extends DatabaseAccessor<AppDatabase>
    with _$SavedWordDaoMixin {
  SavedWordDao(super.db);

  /// 监听所有未删除的收藏单词（按收藏时间倒序）
  Stream<List<SavedWord>> watchAll() {
    return (select(savedWords)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// 获取所有未删除的收藏单词
  Future<List<SavedWord>> getAll() {
    return (select(savedWords)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 保存单词（冲突时更新来源信息和更新时间）
  ///
  /// [word] 必须是小写 lemmatized 形式。
  /// [audioItemId]、[sentenceIndex]、[sentenceText] 为可选来源信息。
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) {
    final now = DateTime.now();
    return into(savedWords).insert(
      SavedWordsCompanion(
        word: Value(word),
        audioItemId: Value(audioItemId),
        sentenceIndex: Value(sentenceIndex),
        sentenceText: Value(sentenceText),
        sentenceStartMs: Value(sentenceStartMs),
        sentenceEndMs: Value(sentenceEndMs),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      onConflict: DoUpdate(
        (old) => SavedWordsCompanion(
          audioItemId: Value(audioItemId),
          sentenceIndex: Value(sentenceIndex),
          sentenceText: Value(sentenceText),
          sentenceStartMs: Value(sentenceStartMs),
          sentenceEndMs: Value(sentenceEndMs),
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ),
        target: [savedWords.word],
      ),
    );
  }

  /// 移除收藏单词（硬删除）
  Future<void> removeWord(String word) {
    return (delete(savedWords)..where((t) => t.word.equals(word))).go();
  }

  /// 查询单词是否已收藏
  Future<bool> isWordSaved(String word) async {
    final row =
        await (select(savedWords)
              ..where((t) => t.word.equals(word) & t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// 清除指定音频关联的上下文信息（音频删除时调用）
  ///
  /// 将 sentenceIndex、sentenceText 和时间信息置 NULL，保留单词本身。
  /// audioItemId 由 FK SET NULL 自动处理，此方法处理非外键字段。
  /// 注意：sentenceStartMs/sentenceEndMs 保留不清除，确保删除字幕后仍可播放。
  Future<void> clearContextForAudio(String audioItemId) {
    return (update(
      savedWords,
    )..where((t) => t.audioItemId.equals(audioItemId))).write(
      const SavedWordsCompanion(
        sentenceIndex: Value(null),
        sentenceText: Value(null),
      ),
    );
  }

  /// 流式监听单词是否已收藏
  Stream<bool> watchIsWordSaved(String word) {
    return (select(savedWords)
          ..where((t) => t.word.equals(word) & t.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row != null);
  }
}
