/// 跟读/复述页面共享的中间操作区
///
/// 固定槽位布局，避免状态切换时布局跳动：
/// 1. 状态文字槽位（居中，20px）
/// 2. 间距（8px）
/// 3. 按钮行（56px）：badge(左) + 中间内容(居中) + 快进(右)
///    与 PlaybackControls 同 Row 结构，badge 对齐 prev，快进对齐 next。
///
/// 底部播放控制和遍数标签由外部 footer 组件统一负责。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../providers/speech/speech_recording_controller.dart';
import '../../theme/app_theme.dart';
import 'playback_controls.dart' show PlaybackControls;
import 'processing_indicator.dart';
import 'recording_button.dart' show RecordingButton, RecordingButtonMode;
import 'status_label.dart';

/// 状态文字槽位高度
const double _kStatusSlotHeight = 20;

/// 槽位间距
const double _kSlotGap = 8;

/// 按钮行高度
const double _kButtonRowHeight = 56;

/// 按钮行到底部 footer 的间距
const double _kBottomGap = 16;

/// 固定总高度：状态文字(20) + 间距(8) + 按钮行(56) + 底部间距(16) = 100
const double kTurnAreaHeight = _kStatusSlotHeight + _kSlotGap + _kButtonRowHeight + _kBottomGap;

/// 跟读/复述页面共享的中间操作区
class RepeatPracticePanel extends StatelessWidget {
  // ========== 评分 badge ==========

  /// 评分 badge（可选，显示在按钮左侧、prev 按钮上方）
  final Widget? ratingBadge;

  // ========== 中间区域数据 ==========

  /// 提示文本（如 "先听再跟读"，播放中显示）
  final String? hintText;

  /// 是否显示倒计时
  final bool showCountdown;

  /// 是否处于停顿状态（录音/等待/倒计时）
  final bool isInPause;

  /// 录音状态
  final SpeechRecordingState turnState;

  /// 当前 promptId
  final String currentPromptId;

  /// 当前评估结果
  final SpeechPracticeAttempt? currentAttempt;

  /// 倒计时 widget（由调用方通过 Consumer 构建，监听各自的 provider）
  final Widget? countdownWidget;

  /// 快进按钮（可选）
  final Widget? fastForwardButton;

  /// 录音按钮点击回调
  final VoidCallback onRecordTap;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  const RepeatPracticePanel({
    super.key,
    this.ratingBadge,
    this.hintText,
    required this.showCountdown,
    required this.isInPause,
    required this.turnState,
    required this.currentPromptId,
    this.currentAttempt,
    this.countdownWidget,
    this.fastForwardButton,
    required this.onRecordTap,
    required this.l10n,
    required this.theme,
  });

  /// 是否处于评估加载中
  bool get _isProcessing =>
      isInPause &&
      turnState.promptId == currentPromptId &&
      turnState.phase == SpeechRecordingPhase.processing;

  @override
  Widget build(BuildContext context) {
    // processing 状态：加载动画独占整个区域（自然高度 > 56px）
    if (_isProcessing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: SizedBox(
          height: kTurnAreaHeight,
          child: Center(
            child: ProcessingIndicator(text: l10n.listenAndRepeatAnalyzing),
          ),
        ),
      );
    }

    final statusWidget = _buildStatusText(context);
    final hasStatus = statusWidget != null;
    final hasBadge = ratingBadge != null;
    final hasFF = showCountdown && fastForwardButton != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: SizedBox(
        height: kTurnAreaHeight,
        child: Column(
          children: [
            // 状态文字槽位（固定高度，AnimatedOpacity 控制显隐）
            SizedBox(
              height: _kStatusSlotHeight,
              child: Center(
                child: AnimatedOpacity(
                  opacity: hasStatus ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: statusWidget ?? const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: _kSlotGap),
            // 按钮行：badge(左) + 中间内容(居中) + 快进(右)
            // 与 PlaybackControls 同 Row 结构
            SizedBox(
              height: _kButtonRowHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 左槽位：badge（与 prev 按钮同宽同位）
                  SizedBox(
                    width: PlaybackControls.controlButtonSize,
                    height: _kButtonRowHeight,
                    child: OverflowBox(
                      maxWidth: 160,
                      minHeight: 0,
                      alignment: Alignment.center,
                      child: AnimatedOpacity(
                        opacity: hasBadge ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !hasBadge,
                          child: ratingBadge ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  // 中间槽位：主内容
                  _buildCenterContent(context),
                  const SizedBox(width: 48),
                  // 右槽位：快进按钮（与 next 按钮同宽同位）
                  SizedBox(
                    width: PlaybackControls.controlButtonSize,
                    height: _kButtonRowHeight,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: hasFF ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !hasFF,
                          child: hasFF
                              ? fastForwardButton!
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 底部间距（与 footer 之间的间距）
            const SizedBox(height: _kBottomGap),
          ],
        ),
      ),
    );
  }

  /// 中间内容（优先级：hintText > countdown > recording/processing > empty）
  Widget _buildCenterContent(BuildContext context) {
    // 播放中：提示文本
    if (hintText != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            hintText!,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // 倒计时
    if (showCountdown && countdownWidget != null) {
      return countdownWidget!;
    }

    // 停顿中：录音按钮 / 加载动画
    if (isInPause) {
      return _buildRecordingButton(context);
    }

    return const SizedBox.shrink();
  }

  /// 录音按钮（processing 已在 build 中拦截）
  Widget _buildRecordingButton(BuildContext context) {
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);
    final mode = isRecordingCurrent
        ? switch (turnState.phase) {
            SpeechRecordingPhase.awaitingSpeech ||
            SpeechRecordingPhase.speaking => RecordingButtonMode.recording,
            _ => RecordingButtonMode.idle,
          }
        : RecordingButtonMode.idle;

    return RecordingButton(mode: mode, onTap: onRecordTap);
  }

  /// 状态文字（录音提示 / 错误信息）
  Widget? _buildStatusText(BuildContext context) {
    // 非停顿状态无状态文字
    if (!isInPause) return null;

    final isProcessing =
        turnState.promptId == currentPromptId &&
        turnState.phase == SpeechRecordingPhase.processing;
    if (isProcessing) return null;

    final hasError = currentAttempt?.errorMessage != null;
    if (hasError) {
      return StatusLabel(
        text: currentAttempt!.errorMessage,
        color: Theme.of(context).colorScheme.error,
        bold: true,
      );
    }

    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);
    final mode = isRecordingCurrent
        ? switch (turnState.phase) {
            SpeechRecordingPhase.awaitingSpeech ||
            SpeechRecordingPhase.speaking => RecordingButtonMode.recording,
            _ => RecordingButtonMode.idle,
          }
        : RecordingButtonMode.idle;

    if (mode == RecordingButtonMode.recording) {
      return StatusLabel(text: l10n.listenAndRepeatRecordingInProgress);
    }

    return null;
  }
}
