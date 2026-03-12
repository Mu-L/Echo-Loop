// 学习统计头部组件 Widget 测试
//
// 验证统计卡片显示、时间格式化、柱状图条件渲染等 UI 行为。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drift/native.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/database/app_database.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/widgets/study/study_stats_header.dart';
import 'package:fluency/providers/study_stats_provider.dart';
import 'package:fluency/theme/app_theme.dart';

// ========== 测试用 Mock ==========

/// 测试用 StudyStatsNotifier — 返回预设数据，不访问 StudyTimeService
class _TestStudyStatsNotifier extends StudyStatsNotifier {
  final StudyStats _data;

  _TestStudyStatsNotifier(this._data);

  @override
  Future<StudyStats> build() async => _data;
}

void main() {
  AppDatabase createTestDb() {
    return AppDatabase(
      NativeDatabase.memory(
        setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  Widget createTestWidget({
    required StudyStats stats,
    Locale locale = const Locale('en'),
    AppDatabase? db,
  }) {
    return ProviderScope(
      overrides: [
        if (db != null) appDatabaseProvider.overrideWithValue(db),
        studyStatsNotifierProvider.overrideWith(
          () => _TestStudyStatsNotifier(stats),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const Scaffold(body: StudyStatsHeader()),
      ),
    );
  }

  group('StudyStatsHeader — 统计卡片', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('显示今日和本周时长', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1800, // 30 min
            weekTotalSeconds: 7200, // 2h 0m
            learnedWordFormCount: 1234,
            todayNewWordForms: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today: 30 min'), findsOneWidget);
      expect(find.text('Week: 2h 0m'), findsOneWidget);
      expect(find.text('Vocab: 1,234 · Today +12'), findsOneWidget);
    });

    testWidgets('零时长显示 0 min', (tester) async {
      await tester.pumpWidget(createTestWidget(stats: const StudyStats()));
      await tester.pumpAndSettle();

      expect(find.text('Today: 0 min'), findsOneWidget);
      expect(find.text('Week: 0 min'), findsOneWidget);
    });

    testWidgets('显示计时器和日期图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(stats: const StudyStats(todaySeconds: 60), db: db),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.date_range_outlined), findsOneWidget);
      expect(find.byIcon(Icons.spellcheck_rounded), findsOneWidget);
    });

    testWidgets('点击词汇量 badge 打开底部弹窗', (tester) async {
      await db.learnedWordFormDao.insertIfAbsentAll({
        'beta': DateTime(2026, 3, 12, 10),
      });

      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            learnedWordFormCount: 1,
            todayNewWordForms: 1,
          ),
          db: db,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vocab: 1 · Today +1'));
      await tester.pumpAndSettle();

      expect(find.text('Vocab'), findsWidgets);
      expect(find.text('1 words'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });

    testWidgets('大时长格式化为小时分钟', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 5400, // 90 min = 1h 30m
            weekTotalSeconds: 10800, // 180 min = 3h 0m
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today: 1h 30m'), findsOneWidget);
      expect(find.text('Week: 3h 0m'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 柱状图', () {
    testWidgets('有学习数据时显示柱状图', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(dailySeconds: [0, 0, 0, 0, 0, 0, 600]),
        ),
      );
      await tester.pumpAndSettle();

      // Card 存在（柱状图的容器）
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('全零数据不显示柱状图', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(dailySeconds: [0, 0, 0, 0, 0, 0, 0]),
        ),
      );
      await tester.pumpAndSettle();

      // 无 Card（柱状图不渲染）
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('柱状图显示星期标签', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(dailySeconds: [300, 600, 0, 0, 0, 0, 900]),
        ),
      );
      await tester.pumpAndSettle();

      // 每个星期缩写在图中至少出现一次（由当前日期决定顺序）
      final weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      // 所有 7 个星期缩写都应在柱状图中出现
      for (final label in weekdayLabels) {
        expect(find.text(label), findsAtLeast(1));
      }
    });

    testWidgets('非零柱体显示分钟数', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            dailySeconds: [0, 0, 0, 0, 0, 0, 1800], // 30 min
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 柱顶数字（30m）
      expect(find.text('30m'), findsOneWidget);
    });
  });

  group('StudyStatsHeader — 中文本地化', () {
    testWidgets('中文标签', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const StudyStats(
            todaySeconds: 1800,
            weekTotalSeconds: 3600,
            learnedWordFormCount: 1234,
            todayNewWordForms: 12,
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日: 30 分钟'), findsOneWidget);
      expect(find.text('本周: 1小时0分钟'), findsOneWidget);
      expect(find.text('词汇量: 1,234 · 今日 +12'), findsOneWidget);
    });
  });
}
