import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/time_provider.dart';

class _GuardLearningProgressNotifier extends LearningProgressNotifier {
  final LearningProgressState _initialState;

  _GuardLearningProgressNotifier(this._initialState);

  @override
  LearningProgressState build() => _initialState;
}

void main() {
  test('复习未到时间时 completeCurrentSubStage 不推进进度', () async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final initialProgress = LearningProgress(
      audioItemId: 'audio-1',
      currentStage: LearningStage.review1,
      currentSubStage: SubStageType.blindListen,
      lastStageCompletedAt: now,
      currentStageStartedAt: now,
      updatedAt: now,
    );

    final container = ProviderContainer(
      overrides: [
        learningProgressNotifierProvider.overrideWith(
          () => _GuardLearningProgressNotifier(
            LearningProgressState(progressMap: {'audio-1': initialProgress}),
          ),
        ),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(learningProgressNotifierProvider.notifier)
        .completeCurrentSubStage('audio-1');

    final after = container
        .read(learningProgressNotifierProvider)
        .progressMap['audio-1']!;
    expect(after.currentStage, initialProgress.currentStage);
    expect(after.currentSubStage, initialProgress.currentSubStage);
    expect(after.totalStudyDurationMs, initialProgress.totalStudyDurationMs);
  });
}
