// 精听播放器页面测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/screens/intensive_listen_player_screen.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

/// 测试用 BookmarkDao — 所有方法通过 noSuchMethod 返回空值
class _TestBookmarkDao implements BookmarkDao {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    if (memberName.contains('watchByAudioId')) {
      return Stream<List<dynamic>>.value([]);
    }
    // 大部分 DAO 方法返回 Future<void>
    return Future<void>.value();
  }
}

void main() {
  /// 创建测试用的精听状态
  IntensiveListenState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    IntensiveListenSettings settings = const IntensiveListenSettings(),
    bool isPlaying = true,
    bool isAnnotationMode = false,
    bool isAnnotationReplay = false,
    bool isTextRevealed = false,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
    bool isCompleted = false,
    Set<int> difficultSentences = const {},
  }) {
    return IntensiveListenState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      settings: settings,
      isPlaying: isPlaying,
      isAnnotationMode: isAnnotationMode,
      isAnnotationReplay: isAnnotationReplay,
      isTextRevealed: isTextRevealed,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
      isCompleted: isCompleted,
      difficultSentences: difficultSentences,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    IntensiveListenState? playerState,
    LearningSessionState? sessionState,
  }) {
    final sentences = createTestSentences(count: 5);

    final router = GoRouter(
      initialLocation: '/collections/col-1/test-1/intensive-listen',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/intensive-listen',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return IntensiveListenPlayerScreen(
              collectionId: collectionId,
              audioItemId: audioId,
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(
            ListeningPracticeState(sentences: sentences),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(
          () =>
              TestLearningSession(sessionState ?? const LearningSessionState()),
        ),
        intensiveListenPlayerProvider.overrideWith(
          () => TestIntensiveListenPlayer(
            playerState ?? createPlayerState(),
            sentences,
          ),
        ),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
      ],
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  group('IntensiveListenPlayerScreen', () {
    testWidgets('显示精听 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Intensive Listening'), findsOneWidget);
    });

    testWidgets('AppBar 显示设置按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('显示进度文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Intensive 3/10" (1-based)
      expect(find.text('Intensive 3/10'), findsOneWidget);
    });

    testWidgets('普通模式显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsOneWidget);
      expect(find.text("Can't understand"), findsOneWidget);
    });

    testWidgets('普通模式显示播放遍数（默认 1 次）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(currentPlayCount: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 1/1'), findsOneWidget);
    });

    testWidgets('自定义遍数正确显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentPlayCount: 2,
            settings: const IntensiveListenSettings(repeatCount: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 2/3'), findsOneWidget);
    });

    testWidgets('标注模式显示继续按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('标注重播模式显示重播指示器', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationReplay: true,
            isPlaying: true,
          ),
        ),
      );
      // CircularProgressIndicator 持续动画，不能用 pumpAndSettle
      await tester.pump();
      await tester.pump();

      expect(find.text('Replaying with subtitles...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('显示播放/暂停和上下句按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      // 播放中显示暂停图标
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('第一句时上一句按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(currentSentenceIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      final prevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous),
      );
      expect(prevButton.onPressed, isNull);
    });

    testWidgets('最后一句时下一句按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 4,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('遍间停顿显示下一遍文案', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: false,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Next play in 3s'), findsOneWidget);
    });

    testWidgets('句间停顿显示下一句文案', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPauseBetweenSentences: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Next sentence in 3s'), findsOneWidget);
    });

    testWidgets('中文本地化正确显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('逐句精听'), findsOneWidget);
      expect(find.text('偷看字幕'), findsOneWidget);
      expect(find.text('听不懂'), findsOneWidget);
    });

    testWidgets('点击设置按钮打开设置面板', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // 设置面板标题
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('标注模式显示实心星标和难句文案', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 实心星标（标注卡片内）
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
      // 难句文案
      expect(find.text('Auto-marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('标注模式取消标记后显示空心星标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            difficultSentences: {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 空心星标
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
      // 未标记文案
      expect(find.text('Tap to mark as difficult'), findsOneWidget);
    });

    testWidgets('标注模式中文文案正确显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已自动标记为难句，点此取消'), findsOneWidget);
    });

    testWidgets('标注模式点击星标可切换难句状态', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击标注卡片内的星标
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();

      // 验证状态变更：难句集合不再包含当前句子
      // （TestIntensiveListenPlayer 会处理 toggleDifficultSentence）
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('正常模式下难句显示标记行', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 难句标记行：★ + 文案
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Auto-marked difficult, tap to undo'), findsOneWidget);
      // "听不懂"按钮仍然存在
      expect(find.text("Can't understand"), findsOneWidget);
    });

    testWidgets('正常模式下非难句显示空心星标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            difficultSentences: {1, 2},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 当前句子（索引0）不在难句集合中，显示空心星标 + 灰色文案
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.text('Tap to mark as difficult'), findsOneWidget);
    });

    testWidgets('正常模式下点击标记行可取消标记', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            difficultSentences: {0},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击标记行取消难句
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();

      // 取消后变为空心星标 + 灰色文案
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.text('Tap to mark as difficult'), findsOneWidget);
    });

    testWidgets('标注模式下导航按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
            isAnnotationMode: true,
            isPlaying: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous),
      );
      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next),
      );
      expect(prevButton.onPressed, isNull);
      expect(nextButton.onPressed, isNull);
    });
  });
}
