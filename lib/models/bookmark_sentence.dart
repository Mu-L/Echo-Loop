/// 带音频来源信息的句子（用于跨音频收藏复习）
///
/// 包装 [Sentence] 并附加音频来源信息，支持跨音频复习场景。
/// 从 [BookmarkWithAudio] 转换而来。
import 'sentence.dart';

/// 带音频来源的收藏句子
class BookmarkSentence {
  /// 句子数据
  final Sentence sentence;

  /// 来源音频 ID
  final String audioItemId;

  /// 来源音频名称（用于 UI 显示）
  final String audioName;

  /// 书签数据中的原始句子索引
  final int originalSentenceIndex;

  const BookmarkSentence({
    required this.sentence,
    required this.audioItemId,
    required this.audioName,
    required this.originalSentenceIndex,
  });
}
