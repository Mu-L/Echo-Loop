import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/services/audio_playback_service.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/common/speech_rating_badge.dart';

class _FakeAudioPlaybackService extends AudioPlaybackService {
  Completer<void>? _playCompleter;

  @override
  Future<void> play(String filePath) {
    _playCompleter = Completer<void>();
    return _playCompleter!.future;
  }

  @override
  Future<void> stop() async {
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Future<void> dispose() async {
    _playCompleter?.complete();
    _playCompleter = null;
  }
}

void main() {
  Widget createTestWidget(_FakeAudioPlaybackService service) {
    return MaterialApp(
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: SpeechRatingBadge(
              l10n: AppLocalizations.of(context)!,
              attempt: const SpeechPracticeAttempt(
                promptId: 'test:0',
                filePath: '/tmp/test.m4a',
                finalTranscript: 'test transcript',
                score: 0.9,
                status: SpeechPracticeAttemptStatus.passed,
              ),
              playbackServiceFactory: () => service,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('badge 自己管理播放图标切换', (tester) async {
    final service = _FakeAudioPlaybackService();

    await tester.pumpWidget(createTestWidget(service));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);

    await tester.tap(find.byType(SpeechRatingBadge));
    await tester.pump();

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);

    await tester.tap(find.byType(SpeechRatingBadge));
    await tester.pump();

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });
}
