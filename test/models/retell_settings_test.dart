import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/retell_settings.dart';

void main() {
  group('RetellSettings.calculatePauseDuration', () {
    test('smart 模式：2秒 + 3倍段落时长', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 10 秒 → 2 + 30 = 32 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );
      expect(result, const Duration(seconds: 32));
    });

    test('smart 模式：最短 5 秒', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 0 秒 → 2 + 0 = 2 秒，clamp 到 5 秒
      final result = settings.calculatePauseDuration(Duration.zero);
      expect(result, const Duration(seconds: 5));
    });

    test('smart 模式：最长 300 秒', () {
      const settings = RetellSettings(pauseMode: PauseMode.smart);
      // 段落 120 秒 → 2 + 360 = 362 秒，clamp 到 300 秒
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 120),
      );
      expect(result, const Duration(seconds: 300));
    });

    test('fixed 模式：使用固定秒数', () {
      const settings = RetellSettings(
        pauseMode: PauseMode.fixed,
        fixedPauseSeconds: 20,
      );
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );
      expect(result, const Duration(seconds: 20));
    });

    test('multiplier 模式：段落时长乘以倍数', () {
      const settings = RetellSettings(
        pauseMode: PauseMode.multiplier,
        pauseMultiplier: 2.0,
      );
      final result = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );
      expect(result, const Duration(seconds: 20));
    });
  });
}
