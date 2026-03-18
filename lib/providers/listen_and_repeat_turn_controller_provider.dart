/// 跟读回合状态机 provider。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import '../services/app_logger.dart';
import '../services/speech_completion_detector.dart';
import 'speech_practice_session_provider.dart';

const _awaitingSpeechFallbackDelay = Duration(seconds: 60);
const _defaultSilenceThreshold = Duration(seconds: 5);
const _maxRecordingMultiplier = 2.5;
const _maxRecordingBuffer = Duration(seconds: 5);
const _maxRecordingFloor = Duration(seconds: 10);
const _reviewCountdownDuration = Duration(seconds: 5);
// const _autoRetryDelay = Duration(seconds: 4);
// const _maxConsecutiveFailures = 3;

enum ListenAndRepeatTurnPhase {
  idle,
  awaitingSpeech,
  speaking,
  processing,
  reviewCountdown,

  waitingForUser,
}

class ListenAndRepeatTurnState {
  final ListenAndRepeatTurnPhase phase;
  final String? promptId;
  final String? referenceText;
  final Duration reviewCountdownRemaining;
  final bool isReviewCountdownPaused;

  const ListenAndRepeatTurnState({
    this.phase = ListenAndRepeatTurnPhase.idle,
    this.promptId,
    this.referenceText,
    this.reviewCountdownRemaining = _reviewCountdownDuration,
    this.isReviewCountdownPaused = false,
  });

  bool get isActive =>
      phase != ListenAndRepeatTurnPhase.idle &&
      phase != ListenAndRepeatTurnPhase.waitingForUser;

  ListenAndRepeatTurnState copyWith({
    ListenAndRepeatTurnPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    String? referenceText,
    bool clearReferenceText = false,
    Duration? reviewCountdownRemaining,
    bool? isReviewCountdownPaused,
  }) {
    return ListenAndRepeatTurnState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      referenceText: clearReferenceText
          ? null
          : (referenceText ?? this.referenceText),
      reviewCountdownRemaining:
          reviewCountdownRemaining ?? this.reviewCountdownRemaining,
      isReviewCountdownPaused:
          isReviewCountdownPaused ?? this.isReviewCountdownPaused,
    );
  }
}

class SpeechPracticeCompletionHeuristic {
  const SpeechPracticeCompletionHeuristic();

  /// 根据实时转录与参考句的匹配程度，计算所需静音等待时长。
  ///
  /// 委托给 [speech_completion_detector.dart] 中的独立检测器：
  /// A. [detectTailMatch] — 连续尾部匹配 + 唯一 → 1s
  /// B. [detectOverallMatchRate] — 全句匹配率 → 1-3s
  /// C. [detectTailHitCount] — 末尾 5 词命中数 → 1-5s
  ///
  /// 三条规则取最小值，无规则触发时返回 [_defaultSilenceThreshold]。
  Duration computeSilenceThreshold({
    required String referenceText,
    required String partialTranscript,
  }) {
    return computeSilenceThresholdDetailed(
      referenceText: referenceText,
      partialTranscript: partialTranscript,
    ).threshold!;
  }

  /// 与 [computeSilenceThreshold] 逻辑一致，额外返回触发原因（用于调试日志）。
  DetectionResult computeSilenceThresholdDetailed({
    required String referenceText,
    required String partialTranscript,
  }) {
    final ctx = buildMatchContext(
      referenceText: referenceText,
      partialTranscript: partialTranscript,
    );
    if (!ctx.hasMatch) {
      return DetectionResult(
        threshold: _defaultSilenceThreshold,
        description: '无匹配, 默认${_defaultSilenceThreshold.inSeconds}s',
      );
    }

    return combineDetections(
      [
        detectTailMatch(ctx),
        detectOverallMatchRate(ctx),
        detectTailHitCount(ctx),
      ],
      ctx,
      fallback: _defaultSilenceThreshold,
    );
  }
}

final speechPracticeCompletionHeuristicProvider =
    Provider<SpeechPracticeCompletionHeuristic>((ref) {
      return const SpeechPracticeCompletionHeuristic();
    });

final listenAndRepeatTurnControllerProvider =
    NotifierProvider<ListenAndRepeatTurnController, ListenAndRepeatTurnState>(
      ListenAndRepeatTurnController.new,
    );

class ListenAndRepeatTurnController extends Notifier<ListenAndRepeatTurnState> {
  Timer? _speechFallbackTimer;
  Timer? _reviewTickTimer;
  Timer? _maxDurationTimer;
  Timer? _transcriptStaleTimer;
  String? _lastKnownTranscript;
  Duration _sentenceDuration = Duration.zero;
  bool _isStopping = false;

  /// 手动控制模式标志：录音评估后不自动倒计时推进。
  bool _isManualMode = false;

  /// 外部注入的"继续"回调，由使用方（跟读页/难句补练页）注册。
  Future<void> Function()? _onContinue;

  @override
  ListenAndRepeatTurnState build() {
    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _cancelAllTimers();
    });
    ref.listen<SpeechPracticeSessionState>(
      speechPracticeSessionProvider,
      _handleSpeechPracticeStateChanged,
    );
    return const ListenAndRepeatTurnState();
  }

  /// 注册"继续"回调，由使用方在 initState 中调用。
  void setOnContinue(Future<void> Function()? callback) {
    _onContinue = callback;
  }

  /// 设置手动控制模式。
  ///
  /// 手动模式下录音评估完成后不自动启动倒计时推进，
  /// 用户需手动点击下一句。
  void setManualMode(bool value) {
    _isManualMode = value;
  }

  Future<void> ensureTurn({
    required String promptId,
    required String referenceText,
    bool allowAutoFallback = true,
    Duration sentenceDuration = Duration.zero,
  }) async {
    if (state.promptId == promptId && state.isActive) {
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    _lastKnownTranscript = null;
    _sentenceDuration = sentenceDuration;
    AppLogger.log('Turn', '→ awaitingSpeech (manual=$_isManualMode)');
    state = ListenAndRepeatTurnState(
      phase: ListenAndRepeatTurnPhase.awaitingSpeech,
      promptId: promptId,
      referenceText: referenceText,
      reviewCountdownRemaining: _reviewCountdownDuration,
    );

    final session = ref.read(speechPracticeSessionProvider.notifier);
    await session.startRecording(promptId: promptId);
    final currentAttempt = ref
        .read(speechPracticeSessionProvider.notifier)
        .attemptFor(promptId);
    if (currentAttempt?.status != SpeechPracticeAttemptStatus.recording) {
      AppLogger.log('Turn', '→ idle (recording failed to start)');
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
      return;
    }

    // 手动模式：不启动任何自动计时器，完全由用户控制
    // 自动模式：只启动等待开口计时器（60s），最大录音时长在检测到语音后才启动
    if (!_isManualMode && allowAutoFallback) {
      AppLogger.log('Turn', '启动 60s 等待开口计时器');
      _scheduleAwaitingSpeechTimer(promptId);
    }
  }

  /// 自动跟读回合开始：启动录音并启用提醒与回退。
  Future<void> ensureAutoTurn({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: true,
      sentenceDuration: sentenceDuration,
    );
  }

  /// 手动回退后的重新录音：仍然使用同一状态机，但不再显示 5/15 秒自动提醒。
  Future<void> startManualRecording({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: false,
      sentenceDuration: sentenceDuration,
    );
  }

  void enterProcessing(String promptId) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimer();
    _cancelReviewCountdown();
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    AppLogger.log('Turn', '→ processing');
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.processing);
  }

  Future<void> handleManualStop() async {
    AppLogger.log('Turn', 'handleManualStop');
    final promptId = state.promptId;
    final referenceText = state.referenceText;
    if (promptId == null || referenceText == null) {
      return;
    }
    _isStopping = true;
    enterProcessing(promptId);
    await ref
        .read(speechPracticeSessionProvider.notifier)
        .stopRecordingAndEvaluate(
          promptId: promptId,
          referenceText: referenceText,
        );
  }

  Future<void> handleContinue() async {
    AppLogger.log('Turn', '→ idle (handleContinue)');
    _cancelReviewCountdown();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
    if (_onContinue != null) {
      await _onContinue!();
    } else {
      AppLogger.log('Turn', 'handleContinue: _onContinue 未注册!');
    }
  }

  void pauseReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(isReviewCountdownPaused: true);
  }

  void resumeReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (state.reviewCountdownRemaining <= Duration.zero) {
      unawaited(handleContinue());
      return;
    }
    state = state.copyWith(isReviewCountdownPaused: false);
    _startReviewCountdown();
  }

  /// 快进倒计时：立即跳过，进入下一句。
  void fastForwardReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    unawaited(handleContinue());
  }

  void resetReviewCountdownOnPlayback() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: true,
    );
  }

  void activateReviewCountdown({required String promptId}) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimer();
    _cancelReviewCountdown();
    state = state.copyWith(
      phase: ListenAndRepeatTurnPhase.reviewCountdown,
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: false,
    );
    _startReviewCountdown();
  }

  /// App 进入后台时清理 turn，停止所有定时器。
  /// 回前台后进入 waitingForUser，避免自动触发录音。
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      AppLogger.log('Turn', 'App 进入后台 → waitingForUser');
      _cancelAllTimers();
      _isStopping = false;
      state = const ListenAndRepeatTurnState(
        phase: ListenAndRepeatTurnPhase.waitingForUser,
      );
    }
  }

  /// 清除当前回合状态（保留页面级配置 _isManualMode / _onContinue）。
  void clearTurn() {
    AppLogger.log('Turn', 'clearTurn → idle');
    _cancelAllTimers();
    _isStopping = false;
    state = const ListenAndRepeatTurnState();
  }

  /// 完全重置（页面 dispose 时调用）。
  void fullReset() {
    clearTurn();
    _isManualMode = false;
    _onContinue = null;
  }

  void _handleSpeechPracticeStateChanged(
    SpeechPracticeSessionState? previous,
    SpeechPracticeSessionState next,
  ) {
    final promptId = state.promptId;
    if (promptId == null) {
      return;
    }
    final previousAttempt = previous?.attempts[promptId];
    final attempt = next.attempts[promptId];
    if (attempt == null) {
      return;
    }

    _handleAttemptPlaybackChanged(
      previousPlayingPromptId: previous?.playingPromptId,
      nextPlayingPromptId: next.playingPromptId,
      promptId: promptId,
    );

    if (attempt.status == SpeechPracticeAttemptStatus.awaitingFinal) {
      enterProcessing(promptId);
      return;
    }

    if (attempt.hasFinalFeedback &&
        !(previousAttempt?.hasFinalFeedback ?? false)) {
      AppLogger.log('Turn', '评估完成: status=${attempt.status.name}, '
          'score=${attempt.score?.toStringAsFixed(2)}');
      // 权限被拒或平台不可用时回退为手动录音，重试也无法解决
      if (attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable) {
        AppLogger.log('Turn', '→ waitingForUser (${attempt.status.name})');
        _cancelAllTimers();
        state = state.copyWith(phase: ListenAndRepeatTurnPhase.waitingForUser);
        return;
      }
      if (_isManualMode) {
        AppLogger.log('Turn', '→ idle (手动模式，等待用户操作)');
        _cancelAllTimers();
        state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
      } else {
        AppLogger.log('Turn', '→ reviewCountdown (自动推进)');
        activateReviewCountdown(promptId: promptId);
      }
      return;
    }

    // VAD 检测到语音，或 ASR 已产出文字（用户压低声音时 VAD 可能不触发）
    final liveText = attempt.liveTranscript?.trim() ?? '';
    if (liveText.isNotEmpty && liveText != (previousAttempt?.liveTranscript?.trim() ?? '')) {
      AppLogger.log('Turn', 'live: "$liveText"');
    }
    final hasVoiceInput =
        attempt.hasDetectedSpeech || liveText.isNotEmpty;

    if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech &&
        hasVoiceInput) {
      _cancelAwaitingSpeechTimer();
      AppLogger.log('Turn', '→ speaking (检测到语音)');
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.speaking);
      // 检测到语音后才启动最大录音时长计时器
      if (!_isManualMode) {
        final referenceText = state.referenceText;
        if (promptId == state.promptId && referenceText != null) {
          final maxDur = _computeMaxRecordingDuration(_sentenceDuration);
          AppLogger.log('Turn', '启动最大录音时长计时器: ${maxDur.inMilliseconds}ms');
          _scheduleMaxDurationTimer(
            promptId: promptId,
            referenceText: referenceText,
            sentenceDuration: _sentenceDuration,
          );
        }
      }
    }

    // 手动模式：不做静音检测/转录停滞检测，完全由用户点击停止
    if (state.phase == ListenAndRepeatTurnPhase.speaking &&
        !_isStopping &&
        !_isManualMode) {
      _handleSpeakingAttemptUpdate(
        promptId: promptId,
        attempt: attempt,
        previousAttempt: previousAttempt,
      );
    }
  }

  /// 60 秒内未检测到语音信号，退出录音模式等待用户操作。
  void _scheduleAwaitingSpeechTimer(String promptId) {
    _speechFallbackTimer?.cancel();
    _speechFallbackTimer = Timer(_awaitingSpeechFallbackDelay, () async {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      AppLogger.log('Turn', '→ waitingForUser (60s 未检测到语音)');
      await ref
          .read(speechPracticeSessionProvider.notifier)
          .cancelActiveRecording();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.waitingForUser);
    });
  }

  void _handleSpeakingAttemptUpdate({
    required String promptId,
    required SpeechPracticeAttempt attempt,
    required SpeechPracticeAttempt? previousAttempt,
  }) {
    final prompt = state.promptId;
    final referenceText = state.referenceText;
    if (prompt != promptId || referenceText == null) {
      return;
    }
    if (!attempt.hasDetectedSpeech) {
      return;
    }

    final liveTranscript = attempt.liveTranscript?.trim() ?? '';

    // ── 通道 1：声学静音 ──
    final currentSilence = attempt.silenceDuration;
    if (currentSilence > Duration.zero && liveTranscript.isNotEmpty) {
      final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
      final required = heuristic.computeSilenceThreshold(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      );
      if (currentSilence >= required) {
        _stopForEvaluation(
          promptId: promptId,
          referenceText: referenceText,
          reason: '用户读完，静音${currentSilence.inMilliseconds}ms',
        );
        return;
      }
    }
    // 静音 5s 兜底（无转录时）
    if (currentSilence >= _defaultSilenceThreshold) {
      _stopForEvaluation(
        promptId: promptId,
        referenceText: referenceText,
        reason: '静音兜底 ${currentSilence.inSeconds}s',
      );
      return;
    }

    // ── 通道 2：转录停滞（应对嘈杂环境） ──
    if (liveTranscript.isNotEmpty && liveTranscript != _lastKnownTranscript) {
      _lastKnownTranscript = liveTranscript;
      _resetTranscriptStaleTimer(
        promptId: promptId,
        referenceText: referenceText,
        transcript: liveTranscript,
      );
    }
  }

  /// 转录内容停止更新时的定时器。
  ///
  /// 阈值与声学静音相同（动态计算）。在嘈杂环境中，
  /// 声学静音检测失效，此计时器作为备用结束通道。
  void _resetTranscriptStaleTimer({
    required String promptId,
    required String referenceText,
    required String transcript,
  }) {
    _transcriptStaleTimer?.cancel();
    final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
    final threshold = heuristic.computeSilenceThreshold(
      referenceText: referenceText,
      partialTranscript: transcript,
    );
    _transcriptStaleTimer = Timer(threshold, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != ListenAndRepeatTurnPhase.speaking) return;
      _stopForEvaluation(
        promptId: promptId,
        referenceText: referenceText,
        reason: '转录停滞 ${threshold.inMilliseconds}ms',
      );
    });
  }

  void _handleAttemptPlaybackChanged({
    required String? previousPlayingPromptId,
    required String? nextPlayingPromptId,
    required String promptId,
  }) {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (previousPlayingPromptId != promptId &&
        nextPlayingPromptId == promptId) {
      resetReviewCountdownOnPlayback();
      return;
    }
    if (previousPlayingPromptId == promptId &&
        nextPlayingPromptId != promptId) {
      state = state.copyWith(
        reviewCountdownRemaining: _reviewCountdownDuration,
        isReviewCountdownPaused: false,
      );
      _startReviewCountdown();
    }
  }

  void _startReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown ||
          state.isReviewCountdownPaused) {
        return;
      }
      final nextRemaining =
          state.reviewCountdownRemaining - const Duration(milliseconds: 100);
      if (nextRemaining <= Duration.zero) {
        timer.cancel();
        state = state.copyWith(reviewCountdownRemaining: Duration.zero);
        await handleContinue();
        return;
      }
      state = state.copyWith(reviewCountdownRemaining: nextRemaining);
    });
  }

  void _stopForEvaluation({
    required String promptId,
    required String referenceText,
    String reason = '',
  }) {
    AppLogger.log('Turn', '自动停止录音 ($reason)');
    _isStopping = true;
    enterProcessing(promptId);
    unawaited(
      ref
          .read(speechPracticeSessionProvider.notifier)
          .stopRecordingAndEvaluate(
            promptId: promptId,
            referenceText: referenceText,
          ),
    );
  }

  void _cancelAwaitingSpeechTimer() {
    _speechFallbackTimer?.cancel();
    _speechFallbackTimer = null;
  }

  void _cancelReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = null;
  }

  /// 启动录音最大时长兜底计时器。
  ///
  /// 超时后静默停止录音并正常评分，用户无感知。
  void _scheduleMaxDurationTimer({
    required String promptId,
    required String referenceText,
    required Duration sentenceDuration,
  }) {
    _maxDurationTimer?.cancel();
    final maxDuration = _computeMaxRecordingDuration(sentenceDuration);
    _maxDurationTimer = Timer(maxDuration, () {
      if (state.promptId != promptId) return;
      if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
          state.phase == ListenAndRepeatTurnPhase.speaking) {
        _stopForEvaluation(
          promptId: promptId,
          referenceText: referenceText,
          reason: '最大录音时长 ${maxDuration.inMilliseconds}ms',
        );
      }
    });
  }

  /// 计算录音最大时长：`max(2.5 × sentenceDuration + 5s, 10s)`。
  Duration _computeMaxRecordingDuration(Duration sentenceDuration) {
    final computed =
        sentenceDuration * _maxRecordingMultiplier + _maxRecordingBuffer;
    return computed < _maxRecordingFloor ? _maxRecordingFloor : computed;
  }

  void _cancelAllTimers() {
    _cancelAwaitingSpeechTimer();
    _cancelReviewCountdown();
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _transcriptStaleTimer?.cancel();
    _transcriptStaleTimer = null;
  }
}
