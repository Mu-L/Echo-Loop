/// 练习页面共享的顶部进度条区域
///
/// 显示线性进度条、句数进度、句子时长、时间戳。
/// 当 [audioName] 非 null 时额外显示音频来源行。
/// 用于难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';

/// 顶部进度条区域
class PracticeProgressSection extends StatelessWidget {
  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 句子时长文本（如 "2.3s"）
  final String? durationText;

  /// 音频来源名称（非 null 时显示来源行）
  final String? audioName;

  /// 时间戳文本（如 "01:23.4 - 01:25.7"）
  final String? timestampText;

  const PracticeProgressSection({
    super.key,
    required this.playerState,
    required this.l10n,
    this.durationText,
    this.audioName,
    this.timestampText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = playerState.totalSentences;
    final current = playerState.currentSentenceIndex + 1;
    final progress = total > 0 ? current / total : 0.0;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final timestampStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );

    // 根据是否有 audioName 决定使用哪种进度文案
    final progressText = audioName != null
        ? l10n.bookmarkReviewProgress(current, total)
        : l10n.reviewDifficultPracticeProgress(current, total);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(progressText, style: subtitleStyle),
              const Spacer(),
              if (durationText case final dur?) Text(dur, style: subtitleStyle),
              if (timestampText case final ts?) ...[
                const SizedBox(width: 6),
                Text(ts, style: timestampStyle),
              ],
            ],
          ),
          // 来源音频名称
          if (audioName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.bookmarkReviewFromAudio(audioName!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
