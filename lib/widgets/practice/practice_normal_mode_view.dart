/// 练习页面共享的普通模式视图（盲听 — 文字遮盖/偷看）
///
/// 包含 HiddenTextPlaceholder 和 ActionChip。
/// 手动模式下隐藏倒计时，不显示盲听标签。
/// 用于难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/countdown_chip.dart';

/// 普通模式视图（文字遮盖 / 偷看）
class PracticeNormalModeView extends StatelessWidget {
  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  /// 切换偷看字幕
  final VoidCallback onPeekToggle;

  /// 听不懂（进入跟读模式）
  final VoidCallback onCantUnderstand;

  /// 取消标记（难句/收藏）
  final VoidCallback onRemoveMark;

  /// 暂停/恢复倒计时
  final VoidCallback onPauseCountdown;

  /// 当前句子文本
  final String? sentenceText;

  const PracticeNormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onCantUnderstand,
    required this.onRemoveMark,
    required this.onPauseCountdown,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句/收藏标记行
          GestureDetector(
            onTap: onRemoveMark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    l10n.intensiveListenMarkedDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.bookmark, color: Colors.amber, size: 18),
              ],
            ),
          ),

          // 遮盖/偷看区域
          Expanded(
            child: Center(
              child: playerState.isTextRevealed && sentenceText != null
                  ? Text(
                      sentenceText!,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                      textAlign: TextAlign.center,
                    )
                  : const _HiddenTextPlaceholder(),
            ),
          ),

          // 倒计时控制（手动模式隐藏，不显示盲听标签）
          SizedBox(
            height: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (playerState.isPauseBetweenPlays &&
                    !playerState.settings.isManualMode)
                  CountdownChip(
                    remaining: playerState.pauseRemaining,
                    total: playerState.pauseDuration,
                    isPaused: playerState.isCountdownPaused,
                    onTap: onPauseCountdown,
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),

          // 偷看/听不懂按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPeekToggle,
                child: _ActionChip(
                  icon: playerState.isTextRevealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: l10n.intensiveListenPeek,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton.tonal(
                onPressed: onCantUnderstand,
                child: Text(l10n.intensiveListenCantUnderstand),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  const _HiddenTextPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.hearing,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.l),
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 200 - i * 40,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

/// 操作按钮
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
