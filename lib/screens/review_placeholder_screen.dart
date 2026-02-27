import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../models/learning_progress.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/time_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 复习子步骤占位页
///
/// 当前阶段只负责流程推进，后续再替换为真实训练页面。
class ReviewPlaceholderScreen extends ConsumerWidget {
  final String audioItemId;
  final String subStageKey;

  const ReviewPlaceholderScreen({
    super.key,
    required this.audioItemId,
    required this.subStageKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItemId],
      ),
    );
    final now = ref.watch(nowProvider)();
    final displaySubStage = SubStageType.fromKey(subStageKey);
    final isLockedReview = progress?.isReviewLockedAt(now) ?? false;
    final lockHint = _reviewLockHint(context, l10n, progress, now);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goToLearningPlan(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => _goToLearningPlan(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(_isChinese(context) ? '复习步骤' : 'Review Step'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _subStageTitle(context, l10n, displaySubStage),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _subStageDescription(context, displaySubStage),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                _isChinese(context)
                    ? '当前版本为占位页面，先打通提醒与流程。'
                    : 'This is a placeholder screen for flow validation.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              if (lockHint != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  lockHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: progress == null || isLockedReview
                    ? null
                    : () => _completeAndContinue(context, ref),
                child: Text(
                  _isChinese(context) ? '标记完成并继续' : 'Mark complete & continue',
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.study),
                child: Text(_isChinese(context) ? '返回任务列表' : 'Back to tasks'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeAndContinue(BuildContext context, WidgetRef ref) async {
    final before = ref.read(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItemId],
      ),
    );
    final now = ref.read(nowProvider)();
    if (before == null) return;
    if (before.isReviewLockedAt(now)) return;

    await ref
        .read(learningProgressNotifierProvider.notifier)
        .completeCurrentSubStage(audioItemId);

    final after = ref.read(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItemId],
      ),
    );
    if (!context.mounted) return;

    if (after == null || after.isCompleted) {
      context.go(AppRoutes.study);
      return;
    }

    final isReviewStage =
        after.currentStage.index >= LearningStage.review0.index &&
        after.currentStage.index <= LearningStage.review28.index;
    if (!isReviewStage) {
      context.go(AppRoutes.audioLearningPlan(audioItemId));
      return;
    }

    context.go(
      AppRoutes.audioReviewSubStage(audioItemId, after.currentSubStage.key),
    );
  }

  String? _reviewLockHint(
    BuildContext context,
    AppLocalizations l10n,
    LearningProgress? progress,
    DateTime now,
  ) {
    if (progress == null) return null;
    if (!progress.isReviewLockedAt(now) && !progress.isReviewOverdueAt(now)) {
      return null;
    }

    if (progress.isReviewOverdueAt(now)) {
      return _formatOverdueText(context, progress.overdueDurationAt(now));
    }

    final reviewAt = progress.nextReviewAt;
    if (reviewAt == null) return l10n.reviewReady;

    if (now.isAfter(reviewAt) || now.isAtSameMomentAs(reviewAt)) {
      return l10n.reviewReady;
    }

    final diff = reviewAt.difference(now);
    if (diff.inDays > 0) {
      return l10n.reviewCountdown(diff.inDays);
    }
    return l10n.reviewCountdownHours(diff.inHours.clamp(1, 999));
  }

  String _formatOverdueText(BuildContext context, Duration? overdue) {
    final isZh = _isChinese(context);
    if (overdue == null) return isZh ? '已逾期' : 'Overdue';
    if (overdue.inDays > 0) {
      return isZh
          ? '已逾期 ${overdue.inDays} 天'
          : 'Overdue by ${overdue.inDays} day(s)';
    }
    final hours = overdue.inHours.clamp(1, 999);
    return isZh ? '已逾期 $hours 小时' : 'Overdue by $hours hour(s)';
  }

  void _goToLearningPlan(BuildContext context) {
    context.go(AppRoutes.audioLearningPlan(audioItemId));
  }
}

String _subStageTitle(
  BuildContext context,
  AppLocalizations l10n,
  SubStageType subStage,
) {
  return switch (subStage) {
    SubStageType.blindListen => l10n.stepBlindListening,
    SubStageType.intensiveListen => l10n.stepIntensiveListening,
    SubStageType.listenAndRepeat => l10n.stepShadowing,
    SubStageType.retell => l10n.stepRetelling,
    SubStageType.reviewDifficultPractice =>
      _isChinese(context) ? '难句补练' : 'Difficult sentence practice',
    SubStageType.reviewRetellParagraph =>
      _isChinese(context) ? '段级复述' : 'Paragraph retelling',
    SubStageType.reviewRetellSummary =>
      _isChinese(context) ? '全文总结复述' : 'Summary retelling',
  };
}

String _subStageDescription(BuildContext context, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen =>
      _isChinese(context)
          ? '全文听一遍，先不看字幕。'
          : 'Listen to the full audio once without subtitles.',
    SubStageType.intensiveListen =>
      _isChinese(context)
          ? '逐句精听并处理听不懂的部分。'
          : 'Work sentence by sentence and resolve difficult parts.',
    SubStageType.listenAndRepeat =>
      _isChinese(context)
          ? '针对关键句进行跟读巩固。'
          : 'Shadow important sentences for reinforcement.',
    SubStageType.retell =>
      _isChinese(context)
          ? '按段复述主要内容。'
          : 'Retell the main points paragraph by paragraph.',
    SubStageType.reviewDifficultPractice =>
      _isChinese(context)
          ? '先盲听难句，听不懂再进入补练。'
          : 'Blind listen difficult sentences first, then remedial practice.',
    SubStageType.reviewRetellParagraph =>
      _isChinese(context) ? '按段复述本轮复习内容。' : 'Retell this round by paragraph.',
    SubStageType.reviewRetellSummary =>
      _isChinese(context)
          ? '用 3-5 句话总结全文大意。'
          : 'Summarize the whole audio in 3-5 sentences.',
  };
}

bool _isChinese(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'zh';
}
