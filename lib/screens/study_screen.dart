import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers/study_task_provider.dart';
import '../providers/time_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/review/review_briefing_sheet.dart';

/// 学习任务列表页
///
/// 任务排序策略：复习优先，且可立即开始的复习排在最前。
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tasks = ref.watch(studyTaskProvider);
    final now = ref.watch(nowProvider)();

    final readyReviews = tasks
        .where((t) => t.type == StudyTaskType.reviewReady)
        .toList();
    final upcomingReviews = tasks
        .where((t) => t.type == StudyTaskType.reviewUpcoming)
        .toList();
    final firstStudies = tasks
        .where((t) => t.type == StudyTaskType.firstStudy)
        .toList();

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                _isChinese(context) ? '暂无待完成任务' : 'No study tasks yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _isChinese(context)
                    ? '导入音频后即可开始首学。'
                    : 'Import audio files to start first study.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        Text(
          _isChinese(context) ? '学习任务' : 'Study Tasks',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.m),
        if (readyReviews.isNotEmpty)
          _TaskSection(
            title: _isChinese(context) ? '待复习（可开始）' : 'Ready to review',
            tasks: readyReviews,
            l10n: l10n,
            now: now,
          ),
        if (upcomingReviews.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          _TaskSection(
            title: _isChinese(context) ? '待复习（未到时间）' : 'Upcoming reviews',
            tasks: upcomingReviews,
            l10n: l10n,
            now: now,
          ),
        ],
        if (firstStudies.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          _TaskSection(
            title: _isChinese(context) ? '首学任务' : 'First study',
            tasks: firstStudies,
            l10n: l10n,
            now: now,
          ),
        ],
      ],
    );
  }
}

class _TaskSection extends StatelessWidget {
  final String title;
  final List<StudyTask> tasks;
  final AppLocalizations l10n;
  final DateTime now;

  const _TaskSection({
    required this.title,
    required this.tasks,
    required this.l10n,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s),
        ...tasks.map((task) => _TaskCard(task: task, l10n: l10n, now: now)),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StudyTask task;
  final AppLocalizations l10n;
  final DateTime now;

  const _TaskCard({required this.task, required this.l10n, required this.now});

  @override
  Widget build(BuildContext context) {
    final isDisabled = task.type == StudyTaskType.reviewUpcoming;
    final subtitle = switch (task.type) {
      StudyTaskType.reviewReady => task.isOverdue
          ? _formatOverdue(context, task.overdueDuration)
          : (_isChinese(context) ? '可开始复习' : 'Ready now'),
      StudyTaskType.reviewUpcoming => _formatNextReview(
        context,
        task.nextReviewAt,
        now,
      ),
      StudyTaskType.firstStudy =>
        _isChinese(context) ? '首学未完成' : 'First study pending',
    };

    return Card(
      child: ListTile(
        leading: Icon(
          task.type == StudyTaskType.firstStudy
              ? Icons.school
              : Icons.refresh_rounded,
        ),
        title: Text(task.audioName),
        subtitle: Text('${_stageName(l10n, task.stage)} · $subtitle'),
        trailing: FilledButton.tonal(
          onPressed: isDisabled
              ? null
              : () {
                  if (task.type == StudyTaskType.firstStudy) {
                    context.push(AppRoutes.audioLearningPlan(task.audioId));
                  } else {
                    showReviewBriefingSheet(
                      context: context,
                      stage: task.stage,
                      subStage: task.subStage,
                      onStartPractice: () {
                        context.push(
                          AppRoutes.audioReviewSubStage(
                            task.audioId,
                            task.subStage.key,
                          ),
                        );
                      },
                    );
                  }
                },
          child: Text(_isChinese(context) ? '开始学习' : 'Start'),
        ),
      ),
    );
  }
}

String _formatNextReview(
  BuildContext context,
  DateTime? nextReviewAt,
  DateTime now,
) {
  if (nextReviewAt == null) {
    return _isChinese(context) ? '等待中' : 'Waiting';
  }

  if (now.isAfter(nextReviewAt) || now.isAtSameMomentAs(nextReviewAt)) {
    return _isChinese(context) ? '可开始复习' : 'Ready now';
  }

  final diff = nextReviewAt.difference(now);
  if (diff.inDays > 0) {
    return _isChinese(context)
        ? '${diff.inDays} 天后可复习'
        : 'Available in ${diff.inDays} day(s)';
  }
  final hours = diff.inHours.clamp(1, 999);
  return _isChinese(context) ? '$hours 小时后可复习' : 'Available in $hours hour(s)';
}

String _formatOverdue(BuildContext context, Duration? overdue) {
  if (overdue == null) {
    return _isChinese(context) ? '已逾期' : 'Overdue';
  }

  if (overdue.inDays > 0) {
    return _isChinese(context)
        ? '已逾期 ${overdue.inDays} 天'
        : 'Overdue by ${overdue.inDays} day(s)';
  }

  final hours = overdue.inHours.clamp(1, 999);
  return _isChinese(context) ? '已逾期 $hours 小时' : 'Overdue by $hours hour(s)';
}

String _stageName(AppLocalizations l10n, LearningStage stage) {
  return switch (stage) {
    LearningStage.firstLearn => l10n.firstStudy,
    LearningStage.review0 => l10n.reviewRound0,
    LearningStage.review1 => l10n.reviewRound1,
    LearningStage.review2 => l10n.reviewRound2,
    LearningStage.review4 => l10n.reviewRound4,
    LearningStage.review7 => l10n.reviewRound7,
    LearningStage.review14 => l10n.reviewRound14,
    LearningStage.review28 => l10n.reviewRound28,
    LearningStage.completed => _isChineseFromL10n(l10n) ? '已完成' : 'Completed',
  };
}

bool _isChinese(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'zh';
}

bool _isChineseFromL10n(AppLocalizations l10n) {
  return l10n.localeName.startsWith('zh');
}
