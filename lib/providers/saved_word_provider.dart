import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/providers.dart';
import '../models/dict_entry.dart';
import '../services/dictionary_service.dart';

part 'saved_word_provider.g.dart';

/// 收藏单词列表 Provider（流式）
///
/// 监听所有收藏单词的变化，按收藏时间倒序。
@Riverpod(keepAlive: true)
class SavedWordList extends _$SavedWordList {
  @override
  Stream<List<SavedWord>> build() {
    final dao = ref.watch(savedWordDaoProvider);
    return dao.watchAll();
  }

  /// 收藏单词
  ///
  /// [word] 小写 lemmatized 形式。
  /// 可选提供来源音频和句子信息。
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) async {
    final dao = ref.read(savedWordDaoProvider);
    await dao.saveWord(
      word: word,
      audioItemId: audioItemId,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText,
      sentenceStartMs: sentenceStartMs,
      sentenceEndMs: sentenceEndMs,
    );
  }

  /// 取消收藏单词
  Future<void> removeWord(String word) async {
    final dao = ref.read(savedWordDaoProvider);
    await dao.removeWord(word);
  }
}

/// 收藏单词列表的批量字典条目
///
/// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
/// 避免每个列表项独立异步查询导致释义延迟闪烁。
@riverpod
Future<Map<String, DictEntry>> savedWordDictEntries(ref) async {
  final wordsAsync = await ref.watch(savedWordListProvider.future);
  if (wordsAsync.isEmpty) return {};
  final wordStrings = wordsAsync.map((w) => w.word).toList();
  return DictionaryService.instance.lookupAll(wordStrings);
}

/// 监听单个单词是否已收藏
@riverpod
Stream<bool> isWordSaved(ref, String word) {
  final dao = ref.watch(savedWordDaoProvider);
  return dao.watchIsWordSaved(word);
}
