import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/providers.dart';

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

/// 监听单个单词是否已收藏
@riverpod
Stream<bool> isWordSaved(ref, String word) {
  final dao = ref.watch(savedWordDaoProvider);
  return dao.watchIsWordSaved(word);
}
