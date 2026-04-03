/// 段落练习页共享骨架
///
/// 统一渲染顶部进度、段落内容区、可选中部控制区和底部播放控制。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'paragraph_progress_header.dart';
import 'practice_playback_footer.dart';

/// 段落练习页共享骨架
class ParagraphPracticeScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final double progress;
  final int currentIndex;
  final int totalParagraphs;
  final Duration paragraphDuration;
  final Widget paragraphContent;
  final Widget? contentControls;
  final Widget? practiceControls;
  final bool canGoPrev;
  final bool isLast;
  final IconData centerIcon;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCenter;
  final bool isManualMode;
  final String playCountText;
  final AppLocalizations l10n;
  final ThemeData theme;

  const ParagraphPracticeScaffold({
    super.key,
    required this.title,
    required this.onClose,
    required this.onOpenSettings,
    required this.progress,
    required this.currentIndex,
    required this.totalParagraphs,
    required this.paragraphDuration,
    required this.paragraphContent,
    this.contentControls,
    this.practiceControls,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: onOpenSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress),
          ParagraphProgressHeader(
            currentIndex: currentIndex,
            totalParagraphs: totalParagraphs,
            paragraphDuration: paragraphDuration,
          ),
          Expanded(child: paragraphContent),
          if (contentControls != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.m,
                right: AppSpacing.m,
                top: AppSpacing.s,
              ),
              child: contentControls!,
            ),
          if (practiceControls != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.m,
                right: AppSpacing.m,
                top: AppSpacing.s,
              ),
              child: practiceControls!,
            ),
          const SizedBox(height: AppSpacing.m),
          PracticePlaybackFooter(
            canGoPrev: canGoPrev,
            isLast: isLast,
            centerIcon: centerIcon,
            onPrevious: onPrevious,
            onNext: onNext,
            onCenter: onCenter,
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
