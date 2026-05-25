/// 跟读设置 Provider
///
/// 存储跟读会话的设置（遍数、停顿模式、手动/自动模式等）。
/// 设置面板读写此 Provider，ListenAndRepeatController 通过 Config 读取。
/// 设置仅在会话内临时生效，不持久化。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/intensive_listen_settings.dart';

part 'listen_and_repeat_settings_provider.g.dart';

/// 跟读设置 Provider
@Riverpod(keepAlive: true)
class ListenAndRepeatSettings extends _$ListenAndRepeatSettings {
  @override
  IntensiveListenSettings build() => const IntensiveListenSettings();

  /// 更新设置
  void update(IntensiveListenSettings newSettings) {
    state = newSettings;
  }

  /// 用指定遍数 + 入口播放速度初始化
  void initialize({required int repeatCount, double playbackSpeed = 1.0}) {
    state = IntensiveListenSettings(
      repeatCount: repeatCount,
      playbackSpeed: playbackSpeed,
    );
  }
}
