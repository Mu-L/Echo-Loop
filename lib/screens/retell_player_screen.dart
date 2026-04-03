/// 复述播放器页面
///
/// 段落复述的核心交互页面。
/// 布局: AppBar → 进度条 → 句子列表 → (录音结果卡) → 阶段指示器 → 底部控制。
/// 支持 listening/retelling 双阶段切换、显示模式循环。
/// retelling 阶段通过 [RetellRecordingController] 驱动录音识别流程。
/// 录音回放通过 [AudioPlaybackService] 播放本地 .m4a 文件。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../models/speech_practice_models.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../providers/speech/speech_recording_controller.dart'
    show SpeechRecordingPhase, SpeechRecordingState;
import '../providers/retell_recording_controller_provider.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/common/recording_button.dart'
    show RecordingButton, RecordingButtonMode;
import '../widgets/common/speech_rating_badge.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/playback_controls.dart' show PlaybackControls;
import '../widgets/common/paragraph_practice_scaffold.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/common/paragraph_visibility_controls.dart';
import '../widgets/retell/retell_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';

/// 复述播放器页面
class RetellPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const RetellPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<RetellPlayerScreen> createState() => _RetellPlayerScreenState();
}

class _RetellPlayerScreenState extends ConsumerState<RetellPlayerScreen>
    with WakelockMixin {
  bool _isShowingDialog = false;

  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 用户在当前段手动停止过录音 → 本段不再自动录音/倒计时
  bool _manualStoppedThisParagraph = false;

  ProviderSubscription<RetellPlayerState>? _playerSubscription;
  ProviderSubscription<RetellRecordingState>? _recordingSubscription;

  @override
  void initState() {
    super.initState();
    _playerSubscription = ref.listenManual<RetellPlayerState>(
      retellPlayerProvider,
      _onRetellPlayerStateChanged,
    );
    _recordingSubscription = ref.listenManual<RetellRecordingState>(
      retellRecordingControllerProvider,
      _onRetellRecordingStateChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 同步初始控制模式到录音控制器
      final settings = ref.read(retellPlayerProvider).settings;
      ref
          .read(retellRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
      ref.read(retellPlayerProvider.notifier).startPlaying();
      _maybeAutoStartRecording();
    });
  }

  @override
  void dispose() {
    _playerSubscription?.close();
    _recordingSubscription?.close();
    super.dispose();
  }

  void _onRetellPlayerStateChanged(
    RetellPlayerState? prev,
    RetellPlayerState next,
  ) {
    if (_isExiting || prev == null) return;
    _logRetellPlayerStateTransition(prev, next);

    if (!prev.stepFinished && next.stepFinished) {
      ref.read(learningSessionProvider.notifier).pauseStudyTimer();
      shortenIdleTimeout(5);
      _handleCompleted();
    }

    if (prev.settings.controlMode != next.settings.controlMode) {
      final controller = ref.read(retellRecordingControllerProvider.notifier);
      controller.setManualMode(next.settings.isManualMode);
      if (next.settings.isManualMode) {
        final recState = ref.read(retellRecordingControllerProvider);
        if (recState.phase == RetellRecordingPhase.recording) {
          unawaited(controller.cancelActiveRecording());
        }
        if (next.isRetellCountdown) {
          ref.read(retellPlayerProvider.notifier).cancelCountdown();
        }
      }
    }

    if (prev.currentParagraphIndex != next.currentParagraphIndex) {
      ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    }

    _maybeAutoStartRecording();
  }

  void _onRetellRecordingStateChanged(
    RetellRecordingState? prev,
    RetellRecordingState next,
  ) {
    if (prev != null) {
      _logRetellRecordingStateTransition(prev, next);
    }
    if (prev?.phase == RetellRecordingPhase.processing &&
        next.phase == RetellRecordingPhase.idle) {
      final currentPlayerState = ref.read(retellPlayerProvider);
      if (!currentPlayerState.userOverrodeDisplayMode) {
        ref
            .read(retellPlayerProvider.notifier)
            .setDisplayModeWithoutOverride(RetellDisplayMode.showAll);
      }

      final latestState = ref.read(retellPlayerProvider);
      if (latestState.phase == RetellPhase.retelling &&
          !latestState.isWaitingForUser &&
          !latestState.settings.isManualMode &&
          !_manualStoppedThisParagraph) {
        AppLogger.log('RetellScreen', '评估完成 → 启动段间停顿');
        ref
            .read(retellPlayerProvider.notifier)
            .startPostEvaluationPause(score: next.currentAttempt?.score);
      }
    }

    _maybeAutoStartRecording();
  }

  void _maybeAutoStartRecording() {
    if (!mounted || _isShowingDialog) return;

    final state = ref.read(retellPlayerProvider);
    final retellRecState = ref.read(retellRecordingControllerProvider);
    if (state.phase != RetellPhase.retelling ||
        state.isWaitingForUser ||
        state.settings.isManualMode ||
        retellRecState.phase != RetellRecordingPhase.idle ||
        retellRecState.awaitingSpeechTimedOut ||
        state.isRetellCountdown ||
        _manualStoppedThisParagraph) {
      return;
    }

    final promptId = _currentPromptId();
    final referenceText = ref
        .read(retellPlayerProvider.notifier)
        .currentParagraphReferenceText;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latestRecState = ref.read(retellRecordingControllerProvider);
      if (latestRecState.phase != RetellRecordingPhase.idle) {
        AppLogger.log(
          'RetellScreen',
          '⏭ 自动录音跳过: phase=${latestRecState.phase.name}',
        );
        return;
      }
      if (latestRecState.awaitingSpeechTimedOut) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 等待开口超时');
        return;
      }
      final latestState = ref.read(retellPlayerProvider);
      if (latestState.phase != RetellPhase.retelling) {
        AppLogger.log(
          'RetellScreen',
          '⏭ 自动录音跳过: retellPhase=${latestState.phase.name}',
        );
        return;
      }
      if (latestState.isWaitingForUser) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: waitingForUser');
        return;
      }
      if (latestState.isRetellCountdown) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 倒计时中');
        return;
      }
      if (_manualStoppedThisParagraph) {
        AppLogger.log('RetellScreen', '⏭ 自动录音跳过: 本段已手动停止');
        return;
      }

      AppLogger.log(
        'RetellScreen',
        '自动开始录音: 段落${latestState.currentParagraphIndex + 1}',
      );
      _updateRecordingThresholds();
      unawaited(
        ref
            .read(retellRecordingControllerProvider.notifier)
            .startRecording(promptId: promptId, referenceText: referenceText),
      );
    });
  }

  /// 构造当前段落的 promptId
  String _currentPromptId() {
    final state = ref.read(retellPlayerProvider);
    return 'retell:${widget.audioItemId}:${state.currentParagraphIndex}';
  }

  /// 更新录音相关阈值
  void _updateRecordingThresholds() {
    final player = ref.read(retellPlayerProvider.notifier);
    final settings = ref.read(retellPlayerProvider).settings;
    final paragraphDuration = player.currentParagraphDuration;
    final controller = ref.read(retellRecordingControllerProvider.notifier);

    final maxRecording = settings.calculateRetellingDuration(paragraphDuration);
    AppLogger.log(
      'RetellScreen',
      '更新阈值: 静音=20s, '
          '最大录音=${maxRecording.inMilliseconds}ms',
    );
    controller.setSilenceTimeout(const Duration(seconds: 20));
    controller.setMaxRecordingDuration(maxRecording);
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final state = ref.read(retellPlayerProvider);
    if (state.phase != RetellPhase.retelling) return;

    final controller = ref.read(retellRecordingControllerProvider.notifier);
    final player = ref.read(retellPlayerProvider.notifier);
    final recState = ref.read(retellRecordingControllerProvider);

    final promptId = _currentPromptId();
    if (recState.isRecordingPrompt(promptId)) {
      AppLogger.log('RetellScreen', '手动停止录音 → 本段退出自动模式');
      _manualStoppedThisParagraph = true;
      await controller.stopAndEvaluate(
        referenceText: player.currentParagraphReferenceText,
      );
      return;
    }

    // 自动停止刚触发（phase 已是 processing），用户也点了停止 → 标记手动操作
    if (recState.phase == RetellRecordingPhase.processing &&
        recState.promptId == promptId) {
      AppLogger.log('RetellScreen', '录音已在处理中 → 标记为手动操作');
      _manualStoppedThisParagraph = true;
      return;
    }

    // 如果在倒计时中点击录音，取消倒计时
    if (state.isRetellCountdown) {
      AppLogger.log('RetellScreen', '录音按钮点击 → 取消倒计时');
      player.cancelCountdown();
    }

    AppLogger.log(
      'RetellScreen',
      '手动开始录音: '
          '段落${ref.read(retellPlayerProvider).currentParagraphIndex + 1}',
    );
    _updateRecordingThresholds();
    await controller.startRecording(
      promptId: promptId,
      referenceText: player.currentParagraphReferenceText,
    );
  }

  /// 为播放录音回放做准备。
  ///
  /// Badge 自己负责播放和图标切换，这里只清理页面状态。
  Future<void> _prepareAttemptPlayback() async {
    final playerState = ref.read(retellPlayerProvider);
    if (playerState.isPlaying) {
      await ref.read(retellPlayerProvider.notifier).pause();
    }

    // 取消段间停顿倒计时
    if (playerState.isRetellCountdown) {
      AppLogger.log('RetellScreen', '播放录音 → 取消倒计时');
      ref.read(retellPlayerProvider.notifier).cancelCountdown();
    }

    // 标记本段手动操作过 → 不再自动录音/倒计时
    AppLogger.log('RetellScreen', '播放录音 → 等待用户操作');
    _manualStoppedThisParagraph = true;
  }

  void _logRetellPlayerStateTransition(
    RetellPlayerState prev,
    RetellPlayerState next,
  ) {
    // 仅 pauseRemaining 变化时不输出日志（倒计时期间变化太频繁）
    if (prev.currentParagraphIndex == next.currentParagraphIndex &&
        prev.playingSentenceIndex == next.playingSentenceIndex &&
        prev.phase == next.phase &&
        prev.currentRepeatCount == next.currentRepeatCount &&
        prev.displayMode == next.displayMode &&
        prev.isPlaying == next.isPlaying &&
        prev.isRetellCountdown == next.isRetellCountdown &&
        prev.isCountdownPaused == next.isCountdownPaused &&
        prev.isCountdownFastForward == next.isCountdownFastForward &&
        prev.isWaitingForUser == next.isWaitingForUser &&
        prev.stepFinished == next.stepFinished) {
      return;
    }

    AppLogger.log(
      'RetellScreen',
      '播放器状态变化: '
          'paragraph ${prev.currentParagraphIndex}→${next.currentParagraphIndex}, '
          'sentence ${prev.playingSentenceIndex}→${next.playingSentenceIndex}, '
          'phase ${prev.phase.name}→${next.phase.name}, '
          'repeat ${prev.currentRepeatCount}→${next.currentRepeatCount}, '
          'display ${prev.displayMode.name}→${next.displayMode.name}, '
          'playing ${prev.isPlaying}→${next.isPlaying}, '
          'countdown ${prev.isRetellCountdown}/${prev.isCountdownPaused}/${prev.isCountdownFastForward}'
          '→${next.isRetellCountdown}/${next.isCountdownPaused}/${next.isCountdownFastForward}, '
          'waiting ${prev.isWaitingForUser}→${next.isWaitingForUser}, '
          'remaining ${prev.pauseRemaining.inMilliseconds}'
          '→${next.pauseRemaining.inMilliseconds}ms, '
          'stepFinished ${prev.stepFinished}→${next.stepFinished}',
    );
  }

  void _logRetellRecordingStateTransition(
    RetellRecordingState prev,
    RetellRecordingState next,
  ) {
    if (prev.phase == next.phase &&
        prev.promptId == next.promptId &&
        prev.awaitingSpeechTimedOut == next.awaitingSpeechTimedOut &&
        prev.currentAttempt?.status == next.currentAttempt?.status &&
        prev.currentAttempt?.score == next.currentAttempt?.score &&
        prev.liveTranscript == next.liveTranscript) {
      return;
    }

    AppLogger.log(
      'RetellScreen',
      '录音状态变化: '
          'phase ${prev.phase.name}→${next.phase.name}, '
          'prompt ${prev.promptId ?? "none"}→${next.promptId ?? "none"}, '
          'awaitTimeout ${prev.awaitingSpeechTimedOut}→${next.awaitingSpeechTimedOut}, '
          'attempt ${prev.currentAttempt?.status.name ?? "none"}'
          '→${next.currentAttempt?.status.name ?? "none"}, '
          'score ${prev.currentAttempt?.score?.toStringAsFixed(2) ?? "null"}'
          '→${next.currentAttempt?.score?.toStringAsFixed(2) ?? "null"}, '
          'live="${next.liveTranscript}"',
    );
  }

  /// 取消录音和回放
  Future<void> _cancelRecordingAndPlayback() async {
    final controller = ref.read(retellRecordingControllerProvider.notifier);
    await controller.cancelActiveRecording();
  }

  /// 处理退出
  Future<void> _handleExit() async {
    _isExiting = true;
    await _cancelRecordingAndPlayback();
    ref.read(retellPlayerProvider.notifier).pause();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);

    if (sessionState.isFreePlay) {
      final sentenceIndex = ref
          .read(retellPlayerProvider.notifier)
          .currentParagraphFirstSentenceIndex;
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(
            widget.audioItemId,
            sentenceIndex,
            isFreePlay: true,
          );
      await _exit();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.retellExitConfirmTitle),
        content: Text(l10n.retellExitConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) {
      _isExiting = false;
      return;
    }

    final sentenceIndex = ref
        .read(retellPlayerProvider.notifier)
        .currentParagraphFirstSentenceIndex;
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveRetellParagraphIndex(
          widget.audioItemId,
          sentenceIndex,
          isFreePlay: false,
        );
    await _exit();
  }

  /// 执行退出
  Future<void> _exit() async {
    _isExiting = true;
    await ref.read(retellRecordingControllerProvider.notifier).fullReset();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 获取当前步骤的上下文信息
  ({int stepIndex, int totalSteps, String stageName}) _getStepContext() {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      final subStages = LearningStage.firstLearn.subStages;
      final idx = subStages.indexOf(SubStageType.retell);
      return (
        stepIndex: idx,
        totalSteps: subStages.length,
        stageName: reviewStageLabel(l10n, LearningStage.firstLearn),
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: reviewStageLabel(l10n, stage),
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final retellState = ref.read(retellPlayerProvider);

    // 自由练习模式：使用公用弹窗
    if (sessionState.isFreePlay) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementRetellPassCount(widget.audioItemId);

      if (!mounted) {
        _isShowingDialog = false;
        return;
      }

      await handleFreePlayComplete(
        context: context,
        title: l10n.retellCompleteTitle,
        message: l10n.retellCompleteMessage(retellState.totalParagraphs),
        replayLabel: l10n.retellPracticeAgain,
        onStudyAgain: () async {
          await ref
              .read(retellRecordingControllerProvider.notifier)
              .fullReset();
          await ref.read(retellPlayerProvider.notifier).restart();
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveRetellParagraphIndex(
                widget.audioItemId,
                null,
                isFreePlay: true,
              );
          await _exit();
        },
      );
      _isShowingDialog = false;
      return;
    }

    // 正常学习模式：使用步骤完成弹窗
    final stepCtx = _getStepContext();

    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.retellCompleteTitle,
      contentBody: Text(
        l10n.retellCompleteMessage(retellState.totalParagraphs),
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      isLastStep: true,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementRetellPassCount(widget.audioItemId);

    if (result != null) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      await _exit();
    } else {
      // 关闭弹窗 → 留在页面，不做操作
    }
  }

  /// 提示文字行：统一在按钮上方，用颜色区分状态。
  Widget? _buildStatusText(
    RetellPlayerState state,
    SpeechRecordingState turnState,
    SpeechPracticeAttempt? attempt,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    // listening 阶段 / 倒计时阶段：不显示录音提示
    if (state.phase == RetellPhase.listening || state.isRetellCountdown) {
      return null;
    }

    // 评估结果：错误提示放在这里（红色），正常结果由上方结果卡展示
    if (attempt != null && attempt.hasFinalFeedback) {
      final isError =
          attempt.status == SpeechPracticeAttemptStatus.noEnglishDetected ||
          attempt.status == SpeechPracticeAttemptStatus.error ||
          attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable;
      if (isError) {
        final errorText = switch (attempt.status) {
          SpeechPracticeAttemptStatus.noEnglishDetected =>
            l10n.listenAndRepeatRecognitionNoEnglish,
          SpeechPracticeAttemptStatus.permissionDenied =>
            l10n.listenAndRepeatTapToRecord,
          _ => attempt.errorMessage ?? l10n.listenAndRepeatAnalyzing,
        };
        return Text(
          errorText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return null;
    }

    // 录音状态文字
    final label = switch (turnState.phase) {
      SpeechRecordingPhase.speaking => l10n.retellPromptToRetell,
      SpeechRecordingPhase.processing => l10n.listenAndRepeatAnalyzing,
      _ => null,
    };
    if (label == null) {
      return null;
    }
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  /// 固定槽位练习控制区。
  ///
  /// 上层：状态文字（居中，固定 20px 槽位）
  /// 下层：badge + 按钮 Row（与 PlaybackControls 同结构，badge 在 prev 位置）
  /// 总高度固定 20 + 8 + 56 = 84px。
  static const _kStatusSlotHeight = 20.0;
  static const _kSlotGap = 8.0;
  static const _kButtonHeight = 56.0;
  static const _kPracticeControlsHeight =
      _kStatusSlotHeight + _kSlotGap + _kButtonHeight; // 84

  /// scaffold 给 practiceControls 的水平 padding 是 AppSpacing.m(16)，
  /// footer 内部的水平 padding 是 AppSpacing.l(24)，
  /// 差值 8 用于对齐 badge 和 prev 按钮的 x 位置。
  static const _kExtraPadding = AppSpacing.l - AppSpacing.m; // 8

  Widget _buildFixedPracticeControls({
    required RetellPlayerState state,
    required SpeechRecordingState turnState,
    required SpeechPracticeAttempt? currentAttempt,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    final hasBadge = currentAttempt != null && currentAttempt.score != null;
    final statusText = _buildStatusText(
      state,
      turnState,
      currentAttempt,
      l10n,
      theme,
    );
    final hasStatus = statusText != null;

    return SizedBox(
      height: _kPracticeControlsHeight,
      child: Column(
        children: [
          // 上层：状态文字居中（固定高度槽位）
          SizedBox(
            height: _kStatusSlotHeight,
            child: Center(
              child: AnimatedOpacity(
                opacity: hasStatus ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: statusText ?? const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: _kSlotGap),
          // 下层：badge(prev 位) + 按钮(center 位) + 空(next 位)
          // 与 PlaybackControls 同 Row 结构，保证 x 对齐
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kExtraPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // badge 槽位（布局宽度与 prev 按钮一致，内容可溢出）
                SizedBox(
                  width: PlaybackControls.controlButtonSize,
                  height: _kButtonHeight,
                  child: OverflowBox(
                    maxWidth: 160,
                    minHeight: 0,
                    alignment: Alignment.center,
                    child: AnimatedOpacity(
                      opacity: hasBadge ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !hasBadge,
                        child: hasBadge
                            ? SpeechRatingBadge(
                                l10n: l10n,
                                attempt: currentAttempt,
                                onBeforePlayback: _prepareAttemptPlayback,
                                thresholds: RatingThresholds.retell,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                // 按钮槽位（与 play 按钮同位）
                _buildCenterButton(state, turnState, l10n),
                const SizedBox(width: 48),
                // 空槽位（与 next 按钮同宽）
                SizedBox(width: PlaybackControls.controlButtonSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 中间按钮：录音按钮 或 段间停顿倒计时环。
  Widget _buildCenterButton(
    RetellPlayerState state,
    SpeechRecordingState turnState,
    AppLocalizations l10n,
  ) {
    // listening 阶段：播放前/等待态显示"先听再复述"，播放中显示"认真听..."
    if (state.phase == RetellPhase.listening) {
      final theme = Theme.of(context);
      final hintText = state.isPlaying
          ? l10n.retellListeningPhase
          : l10n.retellPreListenHint;
      return SizedBox(
        height: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Text(
              hintText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 段间停顿：倒计时环取代录音按钮（Consumer 隔离 tick 重建）
    if (state.isRetellCountdown) {
      return Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(retellPlayerProvider);
          return CountdownChip(
            remaining: s.pauseRemaining,
            total: s.pauseDuration,
            isPaused: s.isCountdownPaused,
            onPause: () =>
                ref.read(retellPlayerProvider.notifier).pauseCountdown(),
            onResume: () =>
                ref.read(retellPlayerProvider.notifier).resumeCountdown(),
          );
        },
      );
    }

    // retelling 阶段：录音按钮
    final buttonMode = switch (turnState.phase) {
      SpeechRecordingPhase.awaitingSpeech ||
      SpeechRecordingPhase.speaking => RecordingButtonMode.recording,
      SpeechRecordingPhase.processing => RecordingButtonMode.disabled,
      _ => RecordingButtonMode.idle,
    };
    return RecordingButton(mode: buttonMode, onTap: _handleRecordTap);
  }

  /// 重播当前段落
  Future<void> _handleReplay() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '重播当前段落');
    await _cancelRecordingAndPlayback();
    ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).replayDuringCountdown();
  }

  /// 切段：retelling 阶段走 completeRetellingTurn（记录统计 + 遍数逻辑）。
  ///
  /// 最后一段时保留录音结果（badge）和手动标记，避免完成弹窗期间
  /// 触发自动录音或 badge 消失。
  Future<void> _goToNextParagraph() async {
    final retellState = ref.read(retellPlayerProvider);
    final isLastParagraph =
        retellState.currentParagraphIndex >= retellState.totalParagraphs - 1;

    if (!isLastParagraph) {
      _manualStoppedThisParagraph = false;
      ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    }

    AppLogger.log('RetellScreen', '→ 下一段 (last=$isLastParagraph)');
    await _cancelRecordingAndPlayback();

    if (retellState.phase == RetellPhase.retelling) {
      await ref.read(retellPlayerProvider.notifier).completeRetellingTurn();
    } else {
      await ref.read(retellPlayerProvider.notifier).goToNextParagraph();
    }

    // 最后一段 → 直接触发完成处理
    if (isLastParagraph) {
      _handleCompleted();
    }
  }

  Future<void> _goToPreviousParagraph() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '→ 上一段');
    await _cancelRecordingAndPlayback();
    ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).goToPreviousParagraph();
  }

  Future<void> _openSettings() async {
    final recordingState = ref.read(retellRecordingControllerProvider);
    if (recordingState.phase == RetellRecordingPhase.recording) {
      await ref
          .read(retellRecordingControllerProvider.notifier)
          .cancelActiveRecording();
      ref.read(retellPlayerProvider.notifier).enterWaitingForUser();
    } else {
      ref
          .read(retellPlayerProvider.notifier)
          .enterWaitingForUser(afterCurrentParagraph: true);
    }
    if (!mounted) return;
    await showRetellSettingsSheet(context);
  }

  Future<void> _handleWordTap(Sentence sentence, String word) async {
    final recordingState = ref.read(retellRecordingControllerProvider);
    final playerState = ref.read(retellPlayerProvider);

    if (recordingState.phase == RetellRecordingPhase.recording) {
      await ref
          .read(retellRecordingControllerProvider.notifier)
          .cancelActiveRecording();
      ref.read(retellPlayerProvider.notifier).enterWaitingForUser();
    } else {
      ref.read(retellPlayerProvider.notifier).enterWaitingForUser(
            afterCurrentParagraph:
                playerState.phase == RetellPhase.listening &&
                playerState.isPlaying,
          );
    }

    if (!mounted) return;
    await showWordDictionarySheet(
      context: context,
      word: word,
      audioItemId: widget.audioItemId,
      sentenceIndex: sentence.index,
      sentenceText: sentence.text,
      sentenceStartMs: sentence.startTime.inMilliseconds,
      sentenceEndMs: sentence.endTime.inMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 只监听非倒计时字段，排除 pauseRemaining，
    // 避免倒计时每 100ms tick 导致整个页面重建
    ref.watch(
      retellPlayerProvider.select(
        (s) => (
          s.currentParagraphIndex,
          s.totalParagraphs,
          s.playingSentenceIndex,
          s.phase,
          s.currentRepeatCount,
          s.displayMode,
          s.settings,
          s.isPlaying,
          s.isRetellCountdown,
          s.pauseDuration,
          s.isCountdownPaused,
          s.isCountdownFastForward,
          s.userOverrodeDisplayMode,
          s.stepFinished,
        ),
      ),
    );
    final state = ref.read(retellPlayerProvider);
    final player = ref.read(retellPlayerProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      retellRecordingControllerProvider.select(
        (s) =>
            (s.phase, s.awaitingSpeechTimedOut, s.currentAttempt, s.promptId),
      ),
    );
    final retellRecState = ref.read(retellRecordingControllerProvider);

    // 映射为 SpeechRecordingState 供 RecordingButton 复用
    final turnState = _mapToTurnState(retellRecState);

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;
    final keywords = player.keywordsMap;
    final progress = (state.totalParagraphs > 0)
        ? (state.currentParagraphIndex + 1) / state.totalParagraphs
        : 0.0;

    // 录音结果（从 controller state 获取）
    final currentAttempt = retellRecState.currentAttempt;

    return wakelockBody(
      child: LearningHotkeyScope(
        onPlayPause: () {
          if (state.phase == RetellPhase.listening) {
            state.isPlaying ? player.pause() : player.resume();
          } else if (state.isRetellCountdown) {
            _handleReplay();
          } else {
            _handleReplay();
          }
        },
        onPrevious: _goToPreviousParagraph,
        onNext: _goToNextParagraph,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await _handleExit();
            },
            child: ParagraphPracticeScaffold(
              title: l10n.retellTitle,
              onClose: _handleExit,
              onOpenSettings: _openSettings,
              progress: progress,
              currentIndex: state.currentParagraphIndex,
              totalParagraphs: state.totalParagraphs,
              paragraphDuration: paragraphDuration,
              paragraphContent: ParagraphSentenceListCard(
                sentences: sentences,
                displayMode:
                    state.settings.keywordMethod != KeywordMethod.off
                    ? state.displayMode
                    : RetellDisplayMode.hideAll,
                keywordMap: keywords,
                playingSentenceIndex: state.phase == RetellPhase.listening
                    ? state.playingSentenceIndex
                    : -1,
                onWordTap: _handleWordTap,
              ),
              contentControls: state.settings.keywordMethod != KeywordMethod.off
                  ? ParagraphVisibilityControls(
                      selectedMode: state.displayMode,
                      onChanged: player.setDisplayMode,
                    )
                  : null,
              practiceControls: _buildFixedPracticeControls(
                state: state,
                turnState: turnState,
                currentAttempt: currentAttempt,
                l10n: l10n,
                theme: theme,
              ),
              canGoPrev: state.currentParagraphIndex > 0,
              isLast:
                  state.currentParagraphIndex >= state.totalParagraphs - 1,
              centerIcon: _isRetellMainPlaybackActive(state)
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onPrevious: _goToPreviousParagraph,
              onNext: _goToNextParagraph,
              onCenter: state.phase == RetellPhase.listening
                  ? (_isRetellMainPlaybackActive(state)
                        ? player.pause
                        : player.resume)
                  : _handleReplay,
              isManualMode: state.settings.isManualMode,
              playCountText: l10n.retellRepeatInfo(
                state.currentRepeatCount,
                state.settings.repeatCount,
              ),
              l10n: l10n,
              theme: theme,
            ),
          ),
        ),
    );
  }
}

bool _isRetellMainPlaybackActive(RetellPlayerState state) {
  return state.phase == RetellPhase.listening &&
      state.isPlaying &&
      !state.isRetellCountdown &&
      !state.isCountdownPaused &&
      !state.isWaitingForUser;
}

/// 将 [RetellRecordingState] 映射为 [SpeechRecordingState]，
/// 供 [RecordingButton] 复用。
SpeechRecordingState _mapToTurnState(RetellRecordingState rs) {
  return SpeechRecordingState(
    phase: switch (rs.phase) {
      RetellRecordingPhase.idle => SpeechRecordingPhase.idle,
      RetellRecordingPhase.recording => SpeechRecordingPhase.speaking,
      RetellRecordingPhase.processing => SpeechRecordingPhase.processing,
    },
  );
}
