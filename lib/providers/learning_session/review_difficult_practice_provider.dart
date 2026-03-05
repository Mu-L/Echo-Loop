/// 复习难句补练 Provider
///
/// 复习阶段的核心训练步骤：仅加载已标记为难句（bookmarked）的句子，
/// 每句盲听 1 遍 → 句间停顿 → 自动推进下一句。
/// 用户可随时「偷看」字幕或按「听不懂」进入标注模式（暂停 + 揭示文本），
/// 标注模式退出时带字幕重播一遍再自动推进。
///
/// 交互对齐逐句精听（IntensiveListenPlayer），使用布尔标志位替代枚举阶段。
/// R1+ 支持取消难句标记（听懂的句子可 unbookmark）。
///
/// 使用 SentencePlaybackEngine 的 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/sentence.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'sentence_playback_engine.dart';

part 'review_difficult_practice_provider.g.dart';

/// 难句补练状态
///
/// 字段对齐 [IntensiveListenState]，使用布尔标志位描述播放阶段。
class ReviewDifficultPracticeState {
  /// 当前句子索引（在难句列表中的索引）
  final int currentSentenceIndex;

  /// 难句总数
  final int totalSentences;

  /// 当前遍数（1-based，难句补练固定为 1 遍盲听）
  final int currentPlayCount;

  /// 是否正在播放
  final bool isPlaying;

  /// 是否处于遍间停顿中（难句补练固定 1 遍，此字段保留以复用 UI）
  final bool isPauseBetweenPlays;

  /// 是否处于句间停顿中
  final bool isPauseBetweenSentences;

  /// 停顿剩余时间
  final Duration pauseRemaining;

  /// 停顿总时长
  final Duration pauseDuration;

  /// 是否处于标注模式（听不懂 → 暂停 + 揭示文本）
  final bool isAnnotationMode;

  /// 是否处于标注模式重播（带字幕重播一遍）
  final bool isAnnotationReplay;

  /// 是否偷看字幕（不暂停、不标记，切句时重置）
  final bool isTextRevealed;

  /// 是否已完成所有句子
  final bool isCompleted;

  const ReviewDifficultPracticeState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isAnnotationMode = false,
    this.isAnnotationReplay = false,
    this.isTextRevealed = false,
    this.isCompleted = false,
  });

  ReviewDifficultPracticeState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isAnnotationMode,
    bool? isAnnotationReplay,
    bool? isTextRevealed,
    bool? isCompleted,
  }) {
    return ReviewDifficultPracticeState(
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      currentPlayCount: currentPlayCount ?? this.currentPlayCount,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays ?? this.isPauseBetweenPlays,
      isPauseBetweenSentences:
          isPauseBetweenSentences ?? this.isPauseBetweenSentences,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isAnnotationMode: isAnnotationMode ?? this.isAnnotationMode,
      isAnnotationReplay: isAnnotationReplay ?? this.isAnnotationReplay,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 难句补练 Provider
///
/// 组合 SentencePlaybackEngine 实现盲听→自动推进的逐句训练循环。
/// 用户可偷看字幕或进入标注模式（听不懂），交互与精听一致。
@Riverpod(keepAlive: true)
class ReviewDifficultPractice extends _$ReviewDifficultPractice {
  /// 难句列表（可变，取消标记时会移除）
  List<Sentence> _sentences = [];

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  @override
  ReviewDifficultPracticeState build() {
    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
    );
    ref.onDispose(() => _engine.cleanup());
    return const ReviewDifficultPracticeState();
  }

  /// 初始化难句补练
  ///
  /// [sentences] 难句列表（已过滤，仅 bookmarked 的句子）
  /// [startIndex] 断点续学句子索引（0-based），默认从头开始
  void initialize(List<Sentence> sentences, {int startIndex = 0}) {
    _engine.cleanup();
    _sentences = sentences.map((s) => s.copyWith()).toList();

    // 确保 startIndex 在有效范围内
    final validIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: _sentences.length,
    );
  }

  /// 获取当前句子索引（用于断点保存）
  int get currentIndex => state.currentSentenceIndex;

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
          ? _sentences[state.currentSentenceIndex]
          : null;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 开始播放（从当前句子开始盲听）
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    await _startSentence();
  }

  /// 暂停播放
  void pause() {
    _engine.invalidateSession();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
    );
  }

  /// 恢复播放
  ///
  /// 标注模式下不恢复（保持暂停），其他情况从当前句重新开始。
  Future<void> resume() async {
    if (state.isAnnotationMode) return;
    await _startSentence();
  }

  /// 进入标注模式（听不懂）
  ///
  /// 暂停音频 → 揭示文本。因为都已是难句，不需要额外标记。
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;

    _engine.invalidateSession();

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isTextRevealed: false,
    );
  }

  /// 退出标注模式（点击"继续"）
  ///
  /// 带字幕重播当前句一遍 → 播完自动推进到下一句
  Future<void> exitAnnotationMode() async {
    state = state.copyWith(
      isAnnotationMode: false,
      isAnnotationReplay: true,
      isPlaying: true,
    );

    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) {
      await _finishAnnotationReplay();
      return;
    }

    // 播放一遍（使用 playOnce）
    final sessionId = _engine.newSession();
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.playClipOnce(sentence, sessionId);

    if (!_engine.isActiveSession(sessionId)) return;

    await _finishAnnotationReplay();
  }

  /// 标注模式下重播当前句子一遍
  ///
  /// 仅在标注模式下可用，播放一遍后停止，不推进、不退出标注模式。
  Future<void> replayInAnnotationMode() async {
    if (!state.isAnnotationMode) return;
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    final sessionId = _engine.newSession();
    state = state.copyWith(isPlaying: true);

    final engine = ref.read(audioEngineProvider.notifier);
    await engine.playClipOnce(sentence, sessionId);

    if (!_engine.isActiveSession(sessionId)) return;
    state = state.copyWith(isPlaying: false);
  }

  /// 设置偷看字幕状态（按住显示，松开隐藏）
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  /// 取消当前句子的难句标记
  ///
  /// 从播放列表移除当前句子，返回被移除的句子（供外部删除书签）。
  /// 若列表为空→标记完成；否则自动调整索引并重置状态。
  Sentence? removeDifficultMark() {
    if (_sentences.isEmpty) return null;

    _engine.invalidateSession();

    final removedIndex = state.currentSentenceIndex;
    final removed = _sentences[removedIndex];
    _sentences.removeAt(removedIndex);

    if (_sentences.isEmpty) {
      state = state.copyWith(
        isCompleted: true,
        isPlaying: false,
        totalSentences: 0,
      );
      return removed;
    }

    // 调整索引：移除的是最后一句则回退一格
    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      isPlaying: false,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      currentPlayCount: 1,
    );

    return removed;
  }

  /// 跳到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
    await _startSentence();
  }

  /// 跳到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
    await _startSentence();
  }

  /// 释放资源
  void disposePlayer() {
    _engine.cleanup();
    _sentences = [];
    state = const ReviewDifficultPracticeState();
  }

  // ========== 内部方法 ==========

  /// 开始播放当前句子（盲听 1 遍）
  Future<void> _startSentence() async {
    final sentence = currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    state = state.copyWith(
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );

    // 播放一遍盲听
    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: 1,
      pauseCalculator: (_) => Duration.zero,
      onPlayCountChanged: (_) {},
      onPauseStarted: (_) {},
      onPauseEnded: () {},
      onTick: (_) {},
      onAllPlaysCompleted: () async {
        // 盲听完成 → 句间停顿 → 自动推进
        await _autoAdvance();
      },
    );
  }

  /// 自动推进到下一句（含句间停顿）
  Future<void> _autoAdvance() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;

    // 计算句间停顿时长：max(句长, 1000ms)
    final sentence = currentSentence;
    final pauseDur = sentence != null
        ? Duration(
            milliseconds: math.max(sentence.duration.inMilliseconds, 1000),
          )
        : const Duration(seconds: 1);

    await _engine.autoAdvance(
      pauseDuration: pauseDur,
      onPauseStarted: (dur) {
        state = state.copyWith(
          isPlaying: false,
          isPauseBetweenPlays: true,
          isPauseBetweenSentences: true,
          pauseDuration: dur,
          pauseRemaining: dur,
        );
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAdvance: () async {
        if (isLastSentence) {
          // 最后一句停顿结束 → 标记完成
          state = state.copyWith(
            isCompleted: true,
            isPlaying: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
          );
        } else {
          // 推进到下一句
          state = state.copyWith(
            currentSentenceIndex: state.currentSentenceIndex + 1,
            currentPlayCount: 1,
            isTextRevealed: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
            isAnnotationMode: false,
            isAnnotationReplay: false,
          );
          await _startSentence();
        }
      },
    );
  }

  /// 标注重播完成后推进
  Future<void> _finishAnnotationReplay() async {
    state = state.copyWith(isAnnotationReplay: false, isPlaying: false);
    await _autoAdvance();
  }
}
