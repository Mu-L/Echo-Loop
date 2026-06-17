/// LoopSettingsPopup 组件测试
///
/// 测试循环设置浮层的渲染与交互：两组独立循环（整篇 / 单句）各有主开关，
/// 开启后展开「标签 + 滑条 + 值」单行滑块。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/widgets/settings_dialog.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 辅助函数：直接渲染循环设置浮层内容。
Widget _buildLoopPopupTest({ListeningPracticeState? practiceState}) {
  return createTestApp(
    const Align(child: LoopSettingsPopup()),
    overrides: [
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      listeningPracticeProvider.overrideWith(
        () => TestListeningPractice(
          practiceState ?? const ListeningPracticeState(),
        ),
      ),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
    ],
  );
}

void main() {
  group('LoopSettingsPopup', () {
    group('渲染', () {
      testWidgets('显示两组循环主开关', (tester) async {
        await tester.pumpWidget(_buildLoopPopupTest());
        await tester.pumpAndSettle();

        expect(find.text('Loop Settings'), findsOneWidget);
        expect(find.text('Whole-text loop'), findsOneWidget);
        expect(find.text('Single-sentence loop'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));
      });

      testWidgets('两个循环都关时不显示子滑块', (tester) async {
        await tester.pumpWidget(_buildLoopPopupTest());
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNothing);
        expect(find.text('Repeat Count'), findsNothing);
      });

      testWidgets('整篇循环开启时展开重复次数 + 间隔滑块', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNWidgets(2));
        expect(find.text('Repeat Count'), findsOneWidget);
        expect(find.text('Interval (seconds)'), findsOneWidget);
      });

      testWidgets('两组循环同时开启时展开 4 个滑块', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true, loopSentence: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsNWidgets(4));
      });

      testWidgets('无限次数显示 ∞ 文案', (tester) async {
        await tester.pumpWidget(
          _buildLoopPopupTest(
            practiceState: const ListeningPracticeState(
              settings: PlaybackSettings(loopWhole: true, wholeLoopCount: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('∞'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('切换主开关触发 updateSettings 并展开子滑块', (tester) async {
        late ListeningPractice controller;
        await tester.pumpWidget(
          createTestApp(
            Align(
              child: Consumer(
                builder: (context, ref, _) {
                  controller = ref.read(listeningPracticeProvider.notifier);
                  return const LoopSettingsPopup();
                },
              ),
            ),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(const ListeningPracticeState()),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 点击「整篇循环」主开关
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        expect(controller.state.settings.loopWhole, isTrue);
        expect(find.byType(Slider), findsNWidgets(2));
      });
    });
  });
}
