/// 倒计时控制按钮（共享组件）
///
/// 56×56 圆形按钮，外围带进度环，内部显示倒计时秒数，
/// 右下角显示暂停/恢复小徽章。点击自动切换暂停/恢复。
///
/// **纯展示组件**：只负责倒计时圆环，快进按钮由调用方控制。
library;

import 'package:flutter/material.dart';
import 'tappable_wrapper.dart';

/// 倒计时控制按钮
///
/// 点击自动切换暂停/恢复。
class CountdownChip extends StatelessWidget {
  /// 倒计时剩余时间
  final Duration remaining;

  /// 倒计时总时长
  final Duration total;

  /// 是否已暂停
  final bool isPaused;

  /// 暂停回调
  final VoidCallback onPause;

  /// 恢复回调
  final VoidCallback onResume;

  const CountdownChip({
    super.key,
    required this.remaining,
    required this.total,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    return TappableWrapper(
      onTap: isPaused ? onResume : onPause,
      feedbackType: TapFeedback.scale,
      scaleDown: 0.90,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                valueColor: AlwaysStoppedAnimation(
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              '$seconds',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            // 右下角状态徽章：暂停时 play，倒计时中 pause
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                  border: Border.all(color: theme.colorScheme.surface),
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
