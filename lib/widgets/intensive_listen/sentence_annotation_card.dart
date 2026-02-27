/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典占位弹窗）、
/// 难句标记切换、翻译占位和分析占位区域。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'word_dictionary_sheet.dart';

/// 标注模式句子卡片
class SentenceAnnotationCard extends StatelessWidget {
  /// 句子文本
  final String text;

  /// 当前句子是否标记为难句
  final bool isDifficult;

  /// 切换难句标记回调
  final VoidCallback onToggle;

  const SentenceAnnotationCard({
    super.key,
    required this.text,
    required this.isDifficult,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 将文本拆分为单词，每个单词可点击
    final words = text.split(RegExp(r'(\s+)'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 难句标记（可点击切换）
        GestureDetector(
          onTap: onToggle,
          child: Row(
            children: [
              Icon(
                isDifficult ? Icons.star : Icons.star_border,
                color: isDifficult ? Colors.amber : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  isDifficult
                      ? l10n.intensiveListenAutoMarkedDifficult
                      : l10n.intensiveListenNotDifficult,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // 句子文本（单词可点击）
        RichText(
          text: TextSpan(
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
            children: words.map((word) {
              // 空白字符直接显示
              if (word.trim().isEmpty) {
                return TextSpan(text: word);
              }
              return TextSpan(
                text: '$word ',
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // 去掉标点再查词典
                    final cleanWord = word.replaceAll(
                      RegExp(r'[.,!?;:\-—…、，。！？；：]'),
                      '',
                    );
                    if (cleanWord.isNotEmpty) {
                      showWordDictionarySheet(
                        context: context,
                        word: cleanWord,
                      );
                    }
                  },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.l),

        // 翻译占位
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            l10n.intensiveListenTranslationPlaceholder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),

        // 分析占位
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            l10n.intensiveListenAnalysisPlaceholder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
