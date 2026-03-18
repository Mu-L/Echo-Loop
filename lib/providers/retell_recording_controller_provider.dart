/// 复述录音控制器 provider。
///
/// 独立于跟读的 [ListenAndRepeatTurnController]，专为复述场景设计。
/// 状态机：idle → recording → processing → idle。
///
/// 自动模式录音流程（严格对齐跟读）：
/// 1. startRecording → recording，启动 60s 等待开口计时器
/// 2. 检测到语音 → 取消等待计时器，启动最大录音时长计时器
/// 3. 双通道检测结束：
///    - 通道 1：声学静音（silenceDuration）+ 启发式阈值
///    - 通道 2：转录停滞（liveTranscript 停止更新）
///    - 兜底：绝对静音超时（_silenceTimeout，默认 20s）
///    - 兜底：最大录音时长
/// 4. 自动停止 → processing → 评估 → idle
/// 5. 段间停顿由 RetellPlayer 管理
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import '../services/app_logger.dart';
import '../services/speech_completion_detector.dart';
import 'listen_and_repeat_turn_controller_provider.dart'
    show speechPracticeCompletionHeuristicProvider;
import 'speech_practice_session_provider.dart';

/// 等待开口最大时长
const _awaitingSpeechTimeout = Duration(seconds: 60);

/// 绝对静音兜底阈值
const _defaultSilenceTimeout = Duration(seconds: 20);

/// 自动模式默认最大录音时长
const _defaultMaxRecordingDuration = Duration(seconds: 30);

/// 手动模式录音兜底上限
const _manualModeMaxDuration = Duration(seconds: 60);

/// 复述录音阶段
enum RetellRecordingPhase {
  /// 就绪，等用户开始或自动开始
  idle,

  /// 正在录音（含等待开口 + 正在说话）
  recording,

  /// 停止录音，等待 final transcript + 评估
  processing,
}

/// 复述录音状态
class RetellRecordingState {
  /// 当前阶段
  final RetellRecordingPhase phase;

  /// 当前录音对应的 promptId
  final String? promptId;

  /// 等待开口超时后置 true，阻止 screen 层重新自动开始录音
  final bool awaitingSpeechTimedOut;

  const RetellRecordingState({
    this.phase = RetellRecordingPhase.idle,
    this.promptId,
    this.awaitingSpeechTimedOut = false,
  });

  /// 是否处于活跃状态（非 idle）
  bool get isActive => phase != RetellRecordingPhase.idle;

  RetellRecordingState copyWith({
    RetellRecordingPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    bool? awaitingSpeechTimedOut,
  }) {
    return RetellRecordingState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      awaitingSpeechTimedOut:
          awaitingSpeechTimedOut ?? this.awaitingSpeechTimedOut,
    );
  }
}

/// 复述录音控制器 provider
final retellRecordingControllerProvider =
    NotifierProvider<RetellRecordingController, RetellRecordingState>(
      RetellRecordingController.new,
    );

/// 复述录音控制器。
///
/// 录音流程严格对齐跟读 [ListenAndRepeatTurnController]：
/// - 通道 1：声学静音 + [SpeechPracticeCompletionHeuristic] 动态阈值
/// - 通道 2：转录停滞计时器（嘈杂环境备用通道）
/// - 兜底：绝对静音超时 + 最大录音时长
class RetellRecordingController extends Notifier<RetellRecordingState> {
  // ── 计时器 ──
  Timer? _awaitingSpeechTimer;
  Timer? _maxDurationTimer;
  Timer? _transcriptStaleTimer;

  // ── 内部状态 ──
  bool _isStopping = false;
  bool _hasDetectedSpeech = false;
  String? _lastKnownTranscript;
  String? _cachedReferenceText;

  // ── 配置 ──
  bool _isManualMode = false;

  /// 绝对静音兜底阈值（通道 1 的无转录兜底）
  Duration _silenceTimeout = _defaultSilenceTimeout;

  /// 自动模式最大录音时长（检测到语音后启动）
  Duration _maxRecordingDuration = _defaultMaxRecordingDuration;

  @override
  RetellRecordingState build() {
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
    return const RetellRecordingState();
  }

  // ========== 配置方法 ==========

  /// 设置手动控制模式
  void setManualMode(bool value) {
    _isManualMode = value;
  }

  /// 设置绝对静音兜底阈值（默认 20s）
  void setSilenceTimeout(Duration value) {
    _silenceTimeout = value;
  }

  /// 设置最大录音时长（默认 30s，仅自动模式；手动模式固定 60s）
  void setMaxRecordingDuration(Duration value) {
    _maxRecordingDuration = value;
  }

  // ========== 录音控制 ==========

  /// 开始录音
  ///
  /// 自动模式：启动 60s 等待开口计时器。
  /// 手动模式：不启动等待计时器。
  /// 两种模式均不立即启动最大录音时长计时器（等检测到语音后启动）。
  Future<void> startRecording({
    required String promptId,
    required String referenceText,
  }) async {
    if (state.promptId == promptId && state.isActive) {
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _cachedReferenceText = referenceText;

    AppLogger.log('RetellRec', '┌ startRecording (manual=$_isManualMode)');
    AppLogger.log('RetellRec', '│ promptId=$promptId');
    AppLogger.log('RetellRec', '│ referenceText=${referenceText.length}字');

    state = RetellRecordingState(
      phase: RetellRecordingPhase.recording,
      promptId: promptId,
    );

    final session = ref.read(speechPracticeSessionProvider.notifier);
    await session.startRecording(promptId: promptId);
    final currentAttempt = session.attemptFor(promptId);
    if (currentAttempt?.status != SpeechPracticeAttemptStatus.recording) {
      AppLogger.log('RetellRec', '└ 录音启动失败 → idle');
      state = state.copyWith(phase: RetellRecordingPhase.idle);
      return;
    }

    // 自动模式：启动 60s 等待开口计时器
    if (!_isManualMode) {
      AppLogger.log('RetellRec', '│ 启动 ${_awaitingSpeechTimeout.inSeconds}s 等待开口计时器');
      _scheduleAwaitingSpeechTimer(promptId);
    }

    AppLogger.log('RetellRec', '└ 录音已开始，等待用户开口...');
  }

  /// 手动停止录音并评估
  Future<void> stopAndEvaluate({
    required String referenceText,
  }) async {
    final promptId = state.promptId;
    if (promptId == null) return;

    AppLogger.log('RetellRec', '● 手动停止录音');
    _isStopping = true;
    _enterProcessing(promptId);
    await ref
        .read(speechPracticeSessionProvider.notifier)
        .stopRecordingAndEvaluate(
          promptId: promptId,
          referenceText: referenceText,
        );
  }

  // ========== 清理方法 ==========

  /// 清除当前回合状态（保留配置）
  void clearRecording() {
    AppLogger.log('RetellRec', '● clearRecording → idle');
    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    state = const RetellRecordingState();
  }

  /// 完全重置（页面 dispose 时调用）
  void fullReset() {
    clearRecording();
    _isManualMode = false;
    _cachedReferenceText = null;
    _silenceTimeout = _defaultSilenceTimeout;
    _maxRecordingDuration = _defaultMaxRecordingDuration;
  }

  // ========== 内部方法 ==========

  void _enterProcessing(String promptId) {
    if (state.promptId != promptId) return;
    _cancelAllTimers();
    AppLogger.log('RetellRec', '→ processing');
    state = state.copyWith(phase: RetellRecordingPhase.processing);
  }

  // ── 等待开口计时器 ──

  /// 60s 内未检测到语音 → 取消录音，标记超时，等待用户手动操作。
  void _scheduleAwaitingSpeechTimer(String promptId) {
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = Timer(_awaitingSpeechTimeout, () async {
      if (state.promptId != promptId ||
          state.phase != RetellRecordingPhase.recording) {
        return;
      }
      AppLogger.log('RetellRec', '⏰ ${_awaitingSpeechTimeout.inSeconds}s 未检测到语音 → 退出自动录音');
      await ref
          .read(speechPracticeSessionProvider.notifier)
          .cancelActiveRecording();
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        awaitingSpeechTimedOut: true,
      );
    });
  }

  // ── 核心状态变化监听 ──

  void _handleSpeechPracticeStateChanged(
    SpeechPracticeSessionState? previous,
    SpeechPracticeSessionState next,
  ) {
    final promptId = state.promptId;
    if (promptId == null) return;

    final previousAttempt = previous?.attempts[promptId];
    final attempt = next.attempts[promptId];
    if (attempt == null) return;

    // awaitingFinal → processing
    if (attempt.status == SpeechPracticeAttemptStatus.awaitingFinal) {
      _enterProcessing(promptId);
      return;
    }

    // 评估完成 → idle
    if (attempt.hasFinalFeedback &&
        !(previousAttempt?.hasFinalFeedback ?? false)) {
      AppLogger.log('RetellRec', '✓ 评估完成: '
          'status=${attempt.status.name}, '
          'score=${attempt.score?.toStringAsFixed(2)}, '
          'matched=${attempt.matchedTokenCount}/${attempt.totalTargetTokenCount}');
      _cancelAllTimers();
      state = state.copyWith(phase: RetellRecordingPhase.idle);
      return;
    }

    // ── recording 阶段：语音检测 + 自动停止 ──
    if (state.phase != RetellRecordingPhase.recording || _isStopping) return;

    // 检测语音：VAD 触发或 ASR 已产出文字
    final liveText = attempt.liveTranscript?.trim() ?? '';
    if (liveText.isNotEmpty &&
        liveText != (previousAttempt?.liveTranscript?.trim() ?? '')) {
      AppLogger.log('RetellRec', '📝 live: "$liveText"');
    }
    final hasVoiceInput = attempt.hasDetectedSpeech || liveText.isNotEmpty;

    // 首次检测到语音 → 切换到 speaking 逻辑
    if (!_hasDetectedSpeech && hasVoiceInput) {
      _handleSpeechDetected(promptId);
    }

    // 手动模式：不做自动停止检测（除了 maxDuration 兜底）
    if (_isManualMode) return;

    // 只有检测到语音后才开始自动停止检测
    if (!_hasDetectedSpeech) return;

    _handleSpeakingAttemptUpdate(
      promptId: promptId,
      attempt: attempt,
      previousAttempt: previousAttempt,
    );
  }

  /// 首次检测到语音的处理
  void _handleSpeechDetected(String promptId) {
    _hasDetectedSpeech = true;
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = null;

    final effectiveMaxDuration =
        _isManualMode ? _manualModeMaxDuration : _maxRecordingDuration;

    AppLogger.log('RetellRec', '🎤 检测到语音');
    AppLogger.log('RetellRec', '│ 启动最大录音时长计时器: ${effectiveMaxDuration.inSeconds}s');
    _scheduleMaxDurationTimer(
      promptId: promptId,
      maxDuration: effectiveMaxDuration,
    );
  }

  /// speaking 阶段的双通道自动停止检测（严格对齐跟读）
  void _handleSpeakingAttemptUpdate({
    required String promptId,
    required SpeechPracticeAttempt attempt,
    required SpeechPracticeAttempt? previousAttempt,
  }) {
    if (!attempt.hasDetectedSpeech) return;

    final referenceText = _cachedReferenceText;
    if (referenceText == null) return;

    final liveTranscript = attempt.liveTranscript?.trim() ?? '';

    // ── 静音检测 ──
    //
    // 复述场景只在高匹配率时提前停止（规则 A/B），低匹配率不做静音检测，
    // 完全靠 maxDuration 兜底。用户需要时间思考，中间停顿是正常的。
    final currentSilence = attempt.silenceDuration;
    if (currentSilence > Duration.zero && liveTranscript.isNotEmpty) {
      final ctx = buildMatchContext(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      );
      if (ctx.hasMatch) {
        final ruleA = detectTailMatch(ctx);
        final ruleB = detectOverallMatchRate(ctx);
        // 只在规则 A 或 B 明确触发时才提前停止
        for (final rule in [ruleA, ruleB]) {
          if (rule.triggered && currentSilence >= rule.threshold!) {
            final pct = (ctx.matchRate * 100).toInt();
            AppLogger.log('RetellRec', '⏹ 静音停止: '
                '${currentSilence.inMilliseconds}ms ≥ '
                '${rule.threshold!.inMilliseconds}ms | '
                '匹配${ctx.lcsPairs.length}/${ctx.referenceTokens.length}词'
                '($pct%), ${rule.description}');
            _stopForEvaluation(promptId: promptId,
                reason: rule.description);
            return;
          }
        }
      }
    }

    // ── 转录停滞检测（通道 2，嘈杂环境备用）──
    //
    // 同样只在规则 A/B 触发时才设置定时器，否则不设。
    if (liveTranscript.isNotEmpty && liveTranscript != _lastKnownTranscript) {
      _lastKnownTranscript = liveTranscript;
      _resetTranscriptStaleTimer(
        promptId: promptId,
        referenceText: referenceText,
        transcript: liveTranscript,
      );
    }
  }

  /// 转录停滞定时器：只在规则 A/B 触发时才设置。
  void _resetTranscriptStaleTimer({
    required String promptId,
    required String referenceText,
    required String transcript,
  }) {
    _transcriptStaleTimer?.cancel();

    final ctx = buildMatchContext(
      referenceText: referenceText,
      partialTranscript: transcript,
    );
    if (!ctx.hasMatch) return;

    // 取规则 A/B 中最短的触发阈值
    Duration? shortest;
    String? desc;
    for (final rule in [detectTailMatch(ctx), detectOverallMatchRate(ctx)]) {
      if (rule.triggered) {
        if (shortest == null || rule.threshold! < shortest) {
          shortest = rule.threshold;
          desc = rule.description;
        }
      }
    }
    // 无规则触发 → 不设定时器，靠 maxDuration 兜底
    if (shortest == null) return;

    _transcriptStaleTimer = Timer(shortest, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != RetellRecordingPhase.recording) return;
      final pct = (ctx.matchRate * 100).toInt();
      AppLogger.log('RetellRec', '⏹ 转录停滞停止: '
          '${shortest!.inMilliseconds}ms | '
          '匹配${ctx.lcsPairs.length}/${ctx.referenceTokens.length}词'
          '($pct%), $desc');
      _stopForEvaluation(promptId: promptId, reason: '转录停滞($desc)');
    });
  }

  // ── 最大录音时长 ──

  void _scheduleMaxDurationTimer({
    required String promptId,
    required Duration maxDuration,
  }) {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxDuration, () {
      if (state.promptId != promptId) return;
      if (state.phase == RetellRecordingPhase.recording) {
        AppLogger.log('RetellRec', '⏰ 最大录音时长 ${maxDuration.inSeconds}s');
        _stopForEvaluation(promptId: promptId, reason: '最大录音时长');
      }
    });
  }

  // ── 自动停止 ──

  void _stopForEvaluation({
    required String promptId,
    String reason = '',
  }) {
    AppLogger.log('RetellRec', '⏹ 自动停止录音 ($reason)');
    _isStopping = true;
    _enterProcessing(promptId);

    final referenceText = _cachedReferenceText;
    if (referenceText == null) {
      AppLogger.log('RetellRec', '⚠ 无法获取 referenceText');
      return;
    }

    unawaited(
      ref
          .read(speechPracticeSessionProvider.notifier)
          .stopRecordingAndEvaluate(
            promptId: promptId,
            referenceText: referenceText,
          ),
    );
  }

  // ── 生命周期 ──

  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      AppLogger.log('RetellRec', 'App 进入后台 → idle');
      _cancelAllTimers();
      _isStopping = false;
      _hasDetectedSpeech = false;
      _lastKnownTranscript = null;
      state = const RetellRecordingState();
    }
  }

  void _cancelAllTimers() {
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _transcriptStaleTimer?.cancel();
    _transcriptStaleTimer = null;
  }
}
