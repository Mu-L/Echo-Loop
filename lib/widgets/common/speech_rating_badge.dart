/// 语音练习评级 Badge（共享组件）
///
/// 融合评级文字 + 播放图标的可点击胶囊 Badge。
/// 跟读、复述、难句补练页面共用，各自控制外部布局位置。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/rating_thresholds.dart';
import '../../models/speech_practice_models.dart';
import '../../services/audio_playback_service.dart';
import 'tappable_wrapper.dart';

// 重导出 RatingThresholds，保持现有 import 兼容
export '../../models/rating_thresholds.dart';

/// 语音练习评级 Badge。
///
/// Badge 自己管理录音回放和图标切换：
/// - 未播放：喇叭图标
/// - 播放中：停止图标
///
/// 页面层只需通过 [onBeforePlayback] 在播放前执行必要的流程清理，
/// 例如取消倒计时、切到 WaitingForUser、暂停主音频等。
class SpeechRatingBadge extends StatefulWidget {
  final AppLocalizations l10n;
  final SpeechPracticeAttempt attempt;

  /// 播放前回调。
  ///
  /// 用于让调用方先清理页面级状态，再开始播放录音。
  final FutureOr<void> Function()? onBeforePlayback;

  /// 评分阈值，默认跟读阈值。
  final RatingThresholds thresholds;

  /// 音频播放服务工厂。
  ///
  /// 默认使用真实播放服务，测试中可注入替身。
  final AudioPlaybackService Function()? playbackServiceFactory;

  const SpeechRatingBadge({
    super.key,
    required this.l10n,
    required this.attempt,
    this.onBeforePlayback,
    this.thresholds = RatingThresholds.listenAndRepeat,
    this.playbackServiceFactory,
  });

  @override
  State<SpeechRatingBadge> createState() => _SpeechRatingBadgeState();
}

class _SpeechRatingBadgeState extends State<SpeechRatingBadge> {
  late final AudioPlaybackService _playbackService;
  int _playbackToken = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playbackService =
        widget.playbackServiceFactory?.call() ?? AudioPlaybackService();
  }

  @override
  void didUpdateWidget(covariant SpeechRatingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = oldWidget.attempt.filePath;
    final newPath = widget.attempt.filePath;
    if (oldPath != newPath && _isPlaying) {
      unawaited(_stopPlayback());
    }
  }

  @override
  void dispose() {
    _playbackToken += 1;
    unawaited(_playbackService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTranscript = (widget.attempt.finalTranscript ?? '').isNotEmpty;

    // 无识别结果时降级为纯文字反馈
    if (!hasTranscript) {
      return Text(
        _feedbackText(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: _statusColor(theme),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final style = _ratingStyle(theme);

    return TappableWrapper(
      onTap: widget.attempt.hasRecording ? _handleTap : null,
      feedbackType: TapFeedback.opacity,
      pressedOpacity: 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [style.backgroundStart, style.backgroundEnd],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _ratingLabel(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: style.textColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (widget.attempt.hasRecording) ...[
              const SizedBox(width: 6),
              Icon(
                _isPlaying ? Icons.stop_rounded : Icons.volume_up_outlined,
                size: 16,
                color: style.textColor.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_isPlaying) {
      await _stopPlayback();
      return;
    }

    final filePath = widget.attempt.filePath;
    if (filePath == null || filePath.isEmpty) return;

    await widget.onBeforePlayback?.call();
    if (!mounted) return;

    final token = ++_playbackToken;
    setState(() => _isPlaying = true);

    try {
      await _playbackService.play(filePath);
    } finally {
      if (mounted && token == _playbackToken) {
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _stopPlayback() async {
    _playbackToken += 1;
    await _playbackService.stop();
    if (!mounted) return;
    setState(() => _isPlaying = false);
  }

  String _ratingLabel() {
    final score = widget.attempt.score ?? 0;
    if (score >= widget.thresholds.perfect) {
      return widget.l10n.listenAndRepeatRatingPerfect;
    }
    if (score >= widget.thresholds.excellent) {
      return widget.l10n.listenAndRepeatRatingExcellent;
    }
    if (score >= widget.thresholds.good) {
      return widget.l10n.listenAndRepeatRatingGood;
    }
    if (score >= widget.thresholds.fair) {
      return widget.l10n.listenAndRepeatRatingFair;
    }
    return widget.l10n.listenAndRepeatRatingKeepGoing;
  }

  String _feedbackText() {
    return switch (widget.attempt.status) {
      SpeechPracticeAttemptStatus.noEnglishDetected =>
        widget.l10n.listenAndRepeatRecognitionNoEnglish,
      SpeechPracticeAttemptStatus.permissionDenied =>
        widget.l10n.listenAndRepeatRecognitionPermissionDenied,
      SpeechPracticeAttemptStatus.unavailable =>
        widget.l10n.listenAndRepeatRecognitionUnavailable,
      SpeechPracticeAttemptStatus.error =>
        widget.l10n.listenAndRepeatRecognitionError,
      SpeechPracticeAttemptStatus.awaitingFinal ||
      SpeechPracticeAttemptStatus.passed ||
      SpeechPracticeAttemptStatus.belowThreshold ||
      SpeechPracticeAttemptStatus.recording ||
      SpeechPracticeAttemptStatus.idle => '',
    };
  }

  Color _statusColor(ThemeData theme) {
    return switch (widget.attempt.status) {
      SpeechPracticeAttemptStatus.passed => const Color(0xFF2E9B51),
      SpeechPracticeAttemptStatus.awaitingFinal => theme.colorScheme.primary,
      SpeechPracticeAttemptStatus.belowThreshold ||
      SpeechPracticeAttemptStatus.noEnglishDetected ||
      SpeechPracticeAttemptStatus.permissionDenied ||
      SpeechPracticeAttemptStatus.unavailable ||
      SpeechPracticeAttemptStatus.error => theme.colorScheme.error,
      _ => theme.colorScheme.onSurface,
    };
  }

  _RatingBadgeStyle _ratingStyle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final score = widget.attempt.score ?? 0;

    if (score >= widget.thresholds.perfect) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFFFE082),
              backgroundStart: Color(0x33C9A030),
              backgroundEnd: Color(0x1A7A5F14),
              borderColor: Color(0x40E0B84A),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF8B6914),
              backgroundStart: Color(0xFFFFF8E1),
              backgroundEnd: Color(0xFFFFF0B8),
              borderColor: Color(0xFFE0C068),
            );
    }
    if (score >= widget.thresholds.excellent) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFB9F5C8),
              backgroundStart: Color(0x3347B66B),
              backgroundEnd: Color(0x1A245B38),
              borderColor: Color(0x4057C878),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF1E7A3D),
              backgroundStart: Color(0xFFEAF8EF),
              backgroundEnd: Color(0xFFDDF2E4),
              borderColor: Color(0xFFA8D6B6),
            );
    }
    if (score >= widget.thresholds.good) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFE4F3B2),
              backgroundStart: Color(0x33A4B84B),
              backgroundEnd: Color(0x1A56611F),
              borderColor: Color(0x40BDD460),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF687A18),
              backgroundStart: Color(0xFFF6F8DF),
              backgroundEnd: Color(0xFFEEF3C8),
              borderColor: Color(0xFFD6DD9A),
            );
    }
    if (score >= widget.thresholds.fair) {
      return isDark
          ? const _RatingBadgeStyle(
              textColor: Color(0xFFF7D79B),
              backgroundStart: Color(0x33C68A38),
              backgroundEnd: Color(0x1A6D4617),
              borderColor: Color(0x40E0A450),
            )
          : const _RatingBadgeStyle(
              textColor: Color(0xFF8A5A14),
              backgroundStart: Color(0xFFFFF1DD),
              backgroundEnd: Color(0xFFF9E3BF),
              borderColor: Color(0xFFE6C48C),
            );
    }
    return isDark
        ? const _RatingBadgeStyle(
            textColor: Color(0xFFB0BEC5),
            backgroundStart: Color(0x33607D8B),
            backgroundEnd: Color(0x1A37474F),
            borderColor: Color(0x4078909C),
          )
        : const _RatingBadgeStyle(
            textColor: Color(0xFF546E7A),
            backgroundStart: Color(0xFFECEFF1),
            backgroundEnd: Color(0xFFE0E4E8),
            borderColor: Color(0xFFB0BEC5),
          );
  }
}

/// 评级 Badge 内部样式
class _RatingBadgeStyle {
  final Color textColor;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color borderColor;

  const _RatingBadgeStyle({
    required this.textColor,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.borderColor,
  });
}
