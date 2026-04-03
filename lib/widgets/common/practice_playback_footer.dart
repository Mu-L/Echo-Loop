/// 练习页面共享底部控制区
///
/// 统一渲染上一句/播放/下一句和遍数标签。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../practice/practice_play_count_label.dart';
import 'playback_controls.dart';

/// 练习页面共享底部控制区
class PracticePlaybackFooter extends StatelessWidget {
  /// 是否可以返回上一句
  final bool canGoPrev;

  /// 是否为最后一句
  final bool isLast;

  /// 中间按钮图标
  final IconData centerIcon;

  /// 上一句回调
  final VoidCallback onPrevious;

  /// 下一句回调
  final VoidCallback onNext;

  /// 播放/暂停回调
  final VoidCallback onCenter;

  /// 是否为手动模式
  final bool isManualMode;

  /// 预格式化的遍数文本
  final String playCountText;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  const PracticePlaybackFooter({
    super.key,
    required this.canGoPrev,
    required this.isLast,
    required this.centerIcon,
    required this.onPrevious,
    required this.onNext,
    required this.onCenter,
    required this.isManualMode,
    required this.playCountText,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        bottom: AppSpacing.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlaybackControls(
            canGoPrev: canGoPrev,
            isLast: isLast,
            centerIcon: centerIcon,
            onPrevious: onPrevious,
            onNext: onNext,
            onCenter: onCenter,
          ),
          const SizedBox(height: AppSpacing.s),
          PracticePlayCountLabel(
            isManualMode: isManualMode,
            playCountText: playCountText,
            l10n: l10n,
            theme: theme,
          ),
        ],
      ),
    );
  }
}
