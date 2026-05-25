import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/widgets/retell/retell_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _RecordingAudioEngine extends TestAudioEngine {
  double recordedSpeed = 1.0;

  @override
  Future<void> setSpeed(double speed) async {
    recordedSpeed = speed;
  }
}

void main() {
  Widget createTestWidget({_RecordingAudioEngine? audioEngine}) {
    return createTestApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showRetellSettingsSheet(context),
            child: const Text('Open Settings'),
          ),
        ),
      ),
      overrides: [
        audioEngineProvider.overrideWith(
          () => audioEngine ?? _RecordingAudioEngine(),
        ),
      ],
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('默认显示 1x 播放速度滑块', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await openSheet(tester);

    expect(find.text('Playback Speed'), findsOneWidget);
    expect(find.text('1x'), findsAtLeast(1));
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(slider.value, 1.0);
    expect(slider.min, 0.5);
    expect(slider.max, 2.0);
    expect(slider.divisions, 30);
  });

  testWidgets('滑块更新复述设置并同步 AudioEngine 速度', (tester) async {
    final audioEngine = _RecordingAudioEngine();
    await tester.pumpWidget(createTestWidget(audioEngine: audioEngine));
    await openSheet(tester);

    tester.widget<Slider>(find.byType(Slider).first).onChanged!(1.25);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Playback Speed')),
    );
    expect(container.read(retellPlayerProvider).settings.playbackSpeed, 1.25);
    expect(audioEngine.recordedSpeed, 1.25);
    expect(find.text('1.25x'), findsOneWidget);
  });
}
