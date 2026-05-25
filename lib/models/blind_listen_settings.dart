/// 盲听设置模型
///
/// 控制盲听段落播放的播放速度、重复次数和段间停顿模式。
/// 仅在会话内临时生效，不持久化。
library;

import 'intensive_listen_settings.dart' show PauseMode, ShadowingControlMode;

/// 盲听设置（会话内临时生效）
class BlindListenSettings {
  /// 每段重复次数（1-5，默认 1）
  final int repeatCount;

  /// 停顿模式（默认 multiplier）
  final PauseMode pauseMode;

  /// 固定间隔秒数（默认 10）
  final int fixedPauseSeconds;

  /// 段长倍数（默认 0.5）
  final double pauseMultiplier;

  /// 控制模式（默认 auto）
  final ShadowingControlMode controlMode;

  /// 播放速度（0.5x-2.0x，默认 1.0x）
  final double playbackSpeed;

  /// 是否为手动控制模式
  bool get isManualMode => controlMode == ShadowingControlMode.manual;

  /// 入口弹窗使用的离散速度选项
  ///
  /// 包含 0.75 / 0.85 / 0.95 这几个"按难度+轮次回升映射"会落到的档位，
  /// 保证下拉默认值在选项列表中可被命中。
  static const List<double> briefingPlaybackSpeedOptions = [
    0.5,
    0.7,
    0.75,
    0.8,
    0.85,
    0.9,
    0.95,
    1.0,
    1.1,
    1.3,
    1.5,
    2.0,
  ];

  /// 固定间隔可选值（秒）
  static const List<int> fixedPauseOptions = [5, 10, 15, 20, 25, 30, 45, 60];

  /// 倍数可选值
  static const List<double> multiplierOptions = [
    0.3,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    4.0,
    5.0,
  ];

  const BlindListenSettings({
    this.repeatCount = 1,
    this.pauseMode = PauseMode.multiplier,
    this.fixedPauseSeconds = 10,
    this.pauseMultiplier = 0.5,
    this.controlMode = ShadowingControlMode.auto,
    this.playbackSpeed = 1.0,
  });

  /// 从弹窗回调的 pauseMultiplier 创建设置
  ///
  /// -1.0 表示"自动"（智能模式），其他值为段长倍数模式。
  factory BlindListenSettings.fromMultiplier(double pauseMultiplier) {
    if (pauseMultiplier < 0) {
      return const BlindListenSettings(pauseMode: PauseMode.smart);
    }
    return BlindListenSettings(pauseMultiplier: pauseMultiplier);
  }

  /// 根据段落时长计算段间停顿时长
  ///
  /// 全模式统一 clamp 到 [3s, 30s]：
  /// - 自动模式: 0.5 × 段长
  /// - 固定模式: fixedPauseSeconds
  /// - 倍数模式: pauseMultiplier × 段长
  Duration calculatePauseDuration(Duration paragraphDuration) {
    final ms = switch (pauseMode) {
      PauseMode.smart => (paragraphDuration.inMilliseconds * 0.5).round(),
      PauseMode.fixed => fixedPauseSeconds * 1000,
      PauseMode.multiplier =>
        (paragraphDuration.inMilliseconds * pauseMultiplier).round(),
    };
    return Duration(milliseconds: ms.clamp(3000, 30000));
  }

  BlindListenSettings copyWith({
    int? repeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
    ShadowingControlMode? controlMode,
    double? playbackSpeed,
  }) {
    return BlindListenSettings(
      repeatCount: repeatCount ?? this.repeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
      controlMode: controlMode ?? this.controlMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}
