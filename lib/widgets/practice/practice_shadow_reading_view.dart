/// 练习页面共享的跟读模式视图
///
/// 录音参数用 [RecordingConfig?] 包装：null 时 fallback 到简单跟读视图（倒计时+提示文字）。
/// 用于难句补练（传 RecordingConfig）和收藏复习（初始不传，同步后传入）。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../providers/listen_and_repeat_turn_controller_provider.dart'
    show ListenAndRepeatTurnPhase, ListenAndRepeatTurnState;
import '../../providers/sentence_ai_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/countdown_chip.dart';
import '../../widgets/intensive_listen/sentence_annotation_card.dart';
import '../../widgets/common/speech_rating_badge.dart';
import '../../widgets/listen_and_repeat/speech_practice_turn_panel.dart';

/// 录音配置（包装所有录音相关参数）
class RecordingConfig {
  /// 录音控制器状态
  final ListenAndRepeatTurnState turnState;

  /// 当前句子的 promptId
  final String currentPromptId;

  /// 当前录音结果
  final SpeechPracticeAttempt? currentAttempt;

  /// 是否正在录制当前句子
  final bool isRecordingCurrent;

  /// 是否正在播放当前句子的录音回放
  final bool isPlayingAttempt;

  /// 录音按钮点击
  final VoidCallback onRecordTap;

  /// 录音回放点击
  final void Function(String) onAttemptPlaybackTap;

  /// 评估后倒计时剩余时长（由 player provider 驱动）
  final Duration pauseRemaining;

  /// 评估后倒计时总时长
  final Duration pauseDuration;

  /// 倒计时是否暂停
  final bool isCountdownPaused;

  /// 快进倒计时
  final VoidCallback onFastForward;

  /// 暂停/恢复倒计时
  final VoidCallback onCountdownTap;

  const RecordingConfig({
    required this.turnState,
    required this.currentPromptId,
    required this.currentAttempt,
    required this.isRecordingCurrent,
    required this.isPlayingAttempt,
    required this.onRecordTap,
    required this.onAttemptPlaybackTap,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCountdownPaused = false,
    this.isPostEvalCountdown = false,
    required this.onFastForward,
    required this.onCountdownTap,
  });

  /// 是否处于评估后倒计时状态（由外部 playerState.isPostEvalCountdown 传入）
  final bool isPostEvalCountdown;
}

/// 跟读模式视图（听不懂 → 显示字幕 + 可选自动录音 + 评分反馈）
class PracticeShadowReadingView extends StatelessWidget {
  /// 当前句子文本
  final String text;

  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 取消标记（难句/收藏）
  final VoidCallback onRemoveMark;

  /// AI 翻译/解析 Notifier
  final SentenceAiNotifier? aiNotifier;

  /// 音频项 ID（查词关联）
  final String? audioItemId;

  /// 句子索引（查词关联）
  final int? sentenceIndex;

  /// 录音配置（null 时使用简单跟读视图）
  final RecordingConfig? recording;

  const PracticeShadowReadingView({
    super.key,
    required this.text,
    required this.playerState,
    required this.l10n,
    required this.onRemoveMark,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.recording,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ai = aiNotifier;
    final cachedTranslation = ai?.getCachedTranslation(text)?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    final rec = recording;

    // 倒计时中：直接显示 CountdownChip（和复述页面一致）
    final isCountdown = rec != null && rec.isPostEvalCountdown;

    // 录音面板：非倒计时 + 停顿中（和复述页面同构：不在倒计时就显示录音按钮）
    final shouldShowTurnPanel =
        !isCountdown && rec != null && playerState.isPauseBetweenPlays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 句子卡片（含难句标记、可点击查词、AI 翻译/解析、录音反馈）
          Expanded(
            child: SingleChildScrollView(
              child: SentenceAnnotationCard(
                key: ValueKey(text),
                text: text,
                isDifficult: true,
                onToggle: onRemoveMark,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                highlightedSegments: rec?.currentAttempt?.referenceSegments,
                onRequestTranslation: ai != null
                    ? () async {
                        final result = await ai.getTranslation(text);
                        return result.translation;
                      }
                    : null,
                onRequestAnalysis: ai != null
                    ? () async {
                        final result = await ai.getAnalysis(text);
                        return result.toDisplayString();
                      }
                    : null,
                cachedTranslation: cachedTranslation,
                cachedAnalysis: cachedAnalysisText,
              ),
            ),
          ),

          // 评级 badge（点击播放录音），和复述页面同位置
          if (rec != null &&
              rec.currentAttempt != null &&
              rec.currentAttempt!.score != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s,
                bottom: AppSpacing.xs,
              ),
              child: Center(
                child: SpeechRatingBadge(
                  l10n: l10n,
                  attempt: rec.currentAttempt!,
                  isPlaying: rec.isPlayingAttempt,
                  onTap: rec.currentAttempt!.hasRecording
                      ? () => rec.onAttemptPlaybackTap(rec.currentPromptId)
                      : null,
                ),
              ),
            ),

          // 底部固定区域
          if (isCountdown)
            // 评估后倒计时：CountdownChip + 快进按钮（和复述页面一致）
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24 + AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 32),
                      const SizedBox(width: 48),
                      CountdownChip(
                        remaining: rec.pauseRemaining,
                        total: rec.pauseDuration,
                        isPaused: rec.isCountdownPaused,
                        onTap: rec.onCountdownTap,
                      ),
                      const SizedBox(width: 48),
                      GestureDetector(
                        onTap: rec.onFastForward,
                        child: Icon(
                          Icons.fast_forward_rounded,
                          size: 32,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (shouldShowTurnPanel)
            // 录音面板
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: SpeechPracticeTurnPanel(
                l10n: l10n,
                turnState: rec.turnState,
                isRecordingCurrent: rec.isRecordingCurrent,
                onRecordTap: rec.onRecordTap,
                currentAttempt: rec.currentAttempt,
              ),
            )
          else if (rec == null && playerState.isPauseBetweenPlays)
            // 无录音配置 + 停顿中：简单跟读视图（倒计时 + 提示文字）
            _SimpleShadowReadingPause(playerState: playerState, l10n: l10n)
          else
            // 播放中 / 其他状态
            SizedBox(
              height: 116,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (playerState.isPlaying)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.headphones,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.listenAndRepeatListenHint,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }
}

/// 简单跟读暂停视图（无录音时的 fallback：倒计时+提示文字）
class _SimpleShadowReadingPause extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;

  const _SimpleShadowReadingPause({
    required this.playerState,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 124,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            l10n.listenAndRepeatYourTurnHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          CountdownChip(
            remaining: playerState.pauseRemaining,
            total: playerState.pauseDuration,
            isPaused: playerState.isCountdownPaused,
            onTap: () {}, // 简单模式下不支持暂停
          ),
        ],
      ),
    );
  }
}
