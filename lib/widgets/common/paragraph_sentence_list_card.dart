/// 段落句子列表卡片
///
/// 统一渲染段落内句子列表，供全文盲听和段落复述共用。
library;

import 'package:flutter/material.dart';

import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import 'masked_sentence_tile.dart';

/// 段落句子列表卡片
class ParagraphSentenceListCard extends StatelessWidget {
  final List<Sentence> sentences;
  final RetellDisplayMode displayMode;
  final Map<int, Set<int>> keywordMap;
  final int playingSentenceIndex;

  /// 已收藏句子索引集合（用于显示只读标记）
  final Set<int> bookmarkedSentenceIndices;

  /// 点击句子回调
  final ValueChanged<Sentence>? onSentenceTap;

  const ParagraphSentenceListCard({
    super.key,
    required this.sentences,
    required this.displayMode,
    required this.keywordMap,
    required this.playingSentenceIndex,
    this.bookmarkedSentenceIndices = const {},
    this.onSentenceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        itemCount: sentences.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: AppSpacing.m,
          endIndent: AppSpacing.m,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final sentence = sentences[index];
          return MaskedSentenceTile(
            sentence: sentence,
            displayMode: displayMode,
            keywordIndices: keywordMap[sentence.index] ?? const {},
            isPlayingSentence: index == playingSentenceIndex,
            isBookmarked: bookmarkedSentenceIndices.contains(sentence.index),
            onTap: onSentenceTap == null
                ? null
                : () => onSentenceTap!(sentence),
          );
        },
      ),
    );
  }
}
