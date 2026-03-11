import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluency/database/enums.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';

import '../helpers/mock_providers.dart';

class _ReplayTestAudioEngine extends TestAudioEngine {
  int _sessionId = 0;

  _ReplayTestAudioEngine()
    : super(initialState: const AudioEngineState(sessionId: 0));

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _sessionId += 1;
  }
}

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    savedIndices.add(sentenceIndex);
    final progress =
        state.progressMap[audioItemId] ??
        LearningProgress(
          audioItemId: audioItemId,
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      shadowingSentenceIndex: sentenceIndex,
      clearShadowingSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _PassiveLearningSession extends TestLearningSession {
  _PassiveLearningSession(super.initialState);

  @override
  void addInputWords(int count) {}

  @override
  void addOutputWords(int count) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ListenAndRepeatPlayer 开始播放时保存断点', () {
    test('startPlaying 会异步保存当前句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.listenAndRepeat,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.listenAndRepeat,
                audioItemId: 'audio-1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(listenAndRepeatPlayerProvider.notifier);
      await notifier.initialize(
        [
          Sentence(
            index: 0,
            text: 'First sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
          Sentence(
            index: 1,
            text: 'Second sentence',
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 3),
          ),
        ],
        startIndex: 1,
      );

      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(1));
      expect(progressNotifier.savedIndices.first, 1);
    });
  });
}
