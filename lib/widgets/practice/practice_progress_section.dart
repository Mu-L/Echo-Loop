/// 练习页面共享的顶部进度条区域
///
/// 显示线性进度条、句数进度、句子时长、时间戳。
/// 当 [showAudioSource] 为 true 且 [audioName] 非 null 时额外显示音频来源行。
/// 用于难句补练、难句跟读和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 顶部进度条区域
class PracticeProgressSection extends StatelessWidget {
  /// 当前句子序号（1-based）
  final int current;

  /// 句子总数
  final int total;

  /// 进度文本（如 "第 4/55 句"），由调用方通过 l10n 生成
  final String progressText;

  /// 句子时长文本（如 "2.3s"）
  final String? durationText;

  /// 音频来源名称（非 null 时显示来源行）
  final String? audioName;

  /// 是否显示音频来源行
  final bool showAudioSource;

  /// 时间戳文本（如 "01:23.4 - 01:25.7"）
  final String? timestampText;

  /// 本地化（仅 audioName 非 null 时用于来源行文案）
  final AppLocalizations? l10n;

  const PracticeProgressSection({
    super.key,
    required this.current,
    required this.total,
    required this.progressText,
    this.durationText,
    this.audioName,
    this.showAudioSource = false,
    this.timestampText,
    this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total > 0 ? current / total : 0.0;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final timestampStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );

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
          if (showAudioSource && audioName != null && l10n != null) ...[
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
                    l10n!.bookmarkReviewFromAudio(audioName!),
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
