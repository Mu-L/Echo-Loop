import 'dart:async';

import '../models/sentence.dart';
import '../models/study_stage.dart';
import '../utils/word_counter.dart';
import 'learned_vocabulary_tracker.dart';
import 'study_time_service.dart';

/// 学习事件记录器
///
/// 封装每播完一句/段、每完成一次录音时的统计写入逻辑。
/// 由 [SentencePlaybackEngine]（自动注入）和非引擎模式（手动调用）使用。
///
/// 统一处理三类事件：
/// - 播完单句：[onSentencePlayed] — 记录听力时长 + 词数 + 词形
/// - 播完一段：[onInputCompleted] — 通用版本，段落模式手动调用
/// - 录音完成：[onRecordingCompleted] — 记录说的时长
class StudyEventRecorder {
  final StudyTimeService _studyTimeService;
  final LearnedVocabularyTracker? _vocabTracker;
  final StudyStage _stage;

  StudyEventRecorder({
    required StudyTimeService studyTimeService,
    LearnedVocabularyTracker? vocabTracker,
    required StudyStage stage,
  })  : _studyTimeService = studyTimeService,
        _vocabTracker = vocabTracker,
        _stage = stage;

  /// 播完一遍后调用（单句粒度）
  ///
  /// [SentencePlaybackEngine.playSentenceLoop] 每次 playClipOnce 成功后自动调用。
  /// 记录听力时长（sentence.duration）、输入词数、已学词形。
  void onSentencePlayed(Sentence sentence) {
    onInputCompleted(
      durationSeconds: sentence.duration.inSeconds,
      wordCount: countWords(sentence.text),
      text: sentence.text,
    );
  }

  /// 播完一段/一句后调用（通用版本）
  ///
  /// 段落模式（盲听、复述）手动调用，传整段的时长和词数。
  void onInputCompleted({
    required int durationSeconds,
    required int wordCount,
    required String text,
  }) {
    if (durationSeconds > 0) {
      unawaited(
        _studyTimeService.addInputTime(durationSeconds, stage: _stage),
      );
    }
    if (wordCount > 0) {
      unawaited(_studyTimeService.addInputWords(wordCount));
    }
    final tracker = _vocabTracker;
    if (tracker != null) {
      unawaited(tracker.recordSentence(text));
    }
  }

  /// 录音完成后调用：记录说的时长
  ///
  /// 只有实际录音才计入说的时间；不录音 = 不计入。
  /// 由 [RecordingService.stopRecording] 自动调用。
  void onRecordingCompleted(int durationSeconds) {
    if (durationSeconds > 0) {
      unawaited(
        _studyTimeService.addOutputTime(durationSeconds, stage: _stage),
      );
    }
  }
}
