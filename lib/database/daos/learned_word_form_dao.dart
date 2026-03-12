import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/learned_word_forms.dart';

part 'learned_word_form_dao.g.dart';

/// 已学习词形排序方式
enum LearnedWordSortMode {
  /// 最近学习优先
  timeDesc,

  /// 最早学习优先
  timeAsc,

  /// 词形 A → Z
  alphabeticalAsc,

  /// 词形 Z → A
  alphabeticalDesc,
}

/// 已学习词形 DAO
///
/// 提供唯一词形的批量写入和统计查询。
@DriftAccessor(tables: [LearnedWordForms])
class LearnedWordFormDao extends DatabaseAccessor<AppDatabase>
    with _$LearnedWordFormDaoMixin {
  LearnedWordFormDao(super.db);

  /// 批量插入首次学习的词形。
  ///
  /// 同一词形只保留最早一次的首次学习时间。
  Future<void> insertIfAbsentAll(Map<String, DateTime> wordForms) async {
    if (wordForms.isEmpty) return;

    await transaction(() async {
      for (final entry in wordForms.entries) {
        await into(learnedWordForms).insert(
          LearnedWordFormsCompanion(
            wordForm: Value(entry.key),
            firstLearnedAt: Value(entry.value),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// 获取累计唯一词形数。
  Future<int> countAll() async {
    final countExp = learnedWordForms.id.count();
    final row = await (selectOnly(
      learnedWordForms,
    )..addColumns([countExp])).getSingle();
    return row.read(countExp) ?? 0;
  }

  /// 获取指定时间范围内首次学习的词形数。
  Future<int> countFirstLearnedBetween(DateTime start, DateTime end) async {
    final countExp = learnedWordForms.id.count();
    final row =
        await (selectOnly(learnedWordForms)
              ..addColumns([countExp])
              ..where(
                learnedWordForms.firstLearnedAt.isBiggerOrEqualValue(start) &
                    learnedWordForms.firstLearnedAt.isSmallerThanValue(end),
              ))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  /// 分页获取已学习词形列表。
  ///
  /// [offset] 从 0 开始，配合 [limit] 实现本地分页。
  Future<List<LearnedWordForm>> fetchPage({
    required int limit,
    required int offset,
    required LearnedWordSortMode sortMode,
  }) {
    final query = select(learnedWordForms);

    switch (sortMode) {
      case LearnedWordSortMode.timeDesc:
        query.orderBy([
          (t) => OrderingTerm.desc(t.firstLearnedAt),
          (t) => OrderingTerm.desc(t.id),
        ]);
      case LearnedWordSortMode.timeAsc:
        query.orderBy([
          (t) => OrderingTerm.asc(t.firstLearnedAt),
          (t) => OrderingTerm.asc(t.id),
        ]);
      case LearnedWordSortMode.alphabeticalAsc:
        query.orderBy([
          (t) => OrderingTerm.asc(t.wordForm),
          (t) => OrderingTerm.asc(t.id),
        ]);
      case LearnedWordSortMode.alphabeticalDesc:
        query.orderBy([
          (t) => OrderingTerm.desc(t.wordForm),
          (t) => OrderingTerm.desc(t.id),
        ]);
    }

    query.limit(limit, offset: offset);
    return query.get();
  }
}
