/// 练习页面共享的底部播放控制组件
///
/// 布局：[上一句] --- [播放/暂停] --- [下一句/完成]
/// 最后一句自动切换为完成图标（check_circle_rounded），`canGoNext` 始终 true。
/// 用于难句补练（ReviewDifficultPracticeScreen）和收藏复习（BookmarkReviewScreen）。
library;

import 'package:flutter/material.dart';

import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';

/// 底部播放控制
class PracticePlaybackControls extends StatelessWidget {
  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 上一句回调
  final VoidCallback onPrevious;

  /// 下一句/完成回调
  final VoidCallback onNext;

  /// 播放/暂停回调
  final VoidCallback onPlayPause;

  const PracticePlaybackControls({
    super.key,
    required this.playerState,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canGoPrev = playerState.currentSentenceIndex > 0;
    final isLastSentence =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            enabled: canGoPrev,
            onTap: canGoPrev ? onPrevious : null,
          ),
          const SizedBox(width: 48),

          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 28,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),

          _NavButton(
            icon: isLastSentence
                ? Icons.check_circle_rounded
                : Icons.skip_next_rounded,
            enabled: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（上一句/下一句/完成）
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 0.6 : 0.15,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
