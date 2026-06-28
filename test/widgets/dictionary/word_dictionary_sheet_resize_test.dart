/// 词典弹窗高度可拖拽测试：AI / 网页源默认 2/3 屏高，上拉指示条放大、下拉缩小。
///
/// 网页源用 linux 平台覆盖让 WebView 走「在浏览器打开」降级分支，避免在 widget
/// test 里渲染真实平台视图；只验证弹窗外层 SizedBox 高度随拖拽变化。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary/web_dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/intensive_listen/word_dictionary_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

class _MockDictionaryService extends Mock implements DictionaryService {}

/// 返回固定 AI 结果的 fake 源
class _FixedAiSource implements DictionarySource {
  @override
  String get id => 'ai';
  @override
  IconData get icon => Icons.auto_awesome;
  @override
  bool get canBeDisabled => false;
  @override
  bool get requiresNetwork => true;
  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => AiDictResult(
    DictionaryEntry(
      headword: 'run',
      pronunciation: const Pronunciation(uk: '', us: ''),
      meanings: const [
        WordMeaning(
          partOfSpeech: 'v.',
          translation: ['奔跑'],
          definition: 'to move fast on foot',
          usageNote: '',
          examples: [],
          synonyms: [],
          antonyms: [],
        ),
      ],
      commonExpressions: const [],
      wordFamily: const [],
      forms: const [],
      etymology: '',
      learnerTips: const [],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService oldInstance;
  late WebDictionarySource web;
  late _FixedAiSource ai;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final mock = _MockDictionaryService();
    when(() => mock.isAvailable).thenReturn(true);
    oldInstance = DictionaryService.replaceInstance(mock);
    web = WebDictionarySource(
      WebDictConfig(
        id: 'cambridge',
        displayName: 'Cambridge',
        icon: Icons.menu_book,
        color: const Color(0xFF000000),
        buildUrl: (w) => 'https://example.com/$w',
      ),
    );
    ai = _FixedAiSource();
  });

  tearDown(() => DictionaryService.replaceInstance(oldInstance));

  // linux 下 WebDictionaryView 走「在浏览器打开」降级，不渲染平台视图。
  // 必须在测试体内复位（invariant 校验早于 tearDown）。
  Future<void> withLinux(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Widget wrap({String defaultId = 'cambridge'}) => ProviderScope(
    overrides: [
      analyticsOverride(),
      dictionaryOverride(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      dictionarySourcesProvider.overrideWithValue([web, ai]),
      dictionarySourcesByIdProvider.overrideWithValue({
        'cambridge': web,
        'ai': ai,
      }),
      resolvedDefaultSourceIdProvider.overrideWithValue(defaultId),
      dictionaryLookupContextProvider.overrideWithValue(
        const DictionaryLookupContext(
          accessToken: 'tok',
          targetLanguage: 'zh-CN',
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: const Scaffold(body: WordDictionarySheet(word: 'run')),
    ),
  );

  testWidgets('网页源默认 2/3 屏高，上拉指示条放大、下拉缩小', (tester) async {
    await withLinux(() async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final sizer = find.byKey(const Key('dict_sheet_sizer'));
    final handle = find.byKey(const Key('dict_drag_handle'));
    expect(sizer, findsOneWidget);
    expect(handle, findsOneWidget);

    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final initial = tester.getSize(sizer).height;
    // 默认约 2/3 屏高（受 SafeArea 影响略小，给足容差）
    expect(initial, closeTo(screenH * 2 / 3, 40));

    // 上拉放大
    await tester.drag(handle, const Offset(0, -200));
    await tester.pumpAndSettle();
    final enlarged = tester.getSize(sizer).height;
    expect(enlarged, greaterThan(initial + 150));

    // 下拉缩小
    await tester.drag(handle, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getSize(sizer).height, lessThan(enlarged));
    });
  });

  testWidgets('上拉不超过 95% 屏高上限', (tester) async {
    await withLinux(() async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final handle = find.byKey(const Key('dict_drag_handle'));
    final sizer = find.byKey(const Key('dict_sheet_sizer'));
    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // 远超上限的拖拽量
    await tester.drag(handle, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getSize(sizer).height, lessThanOrEqualTo(screenH * 0.95 + 1));
    });
  });

  testWidgets('AI 源默认 2/3 屏高，上拉指示条放大', (tester) async {
    await tester.pumpWidget(wrap(defaultId: 'ai'));
    await tester.pumpAndSettle();

    // 渲染的是 AI 结果（释义「奔跑」），确认走 AI 源
    expect(find.text('奔跑'), findsOneWidget);

    final sizer = find.byKey(const Key('dict_sheet_sizer'));
    final handle = find.byKey(const Key('dict_drag_handle'));
    expect(sizer, findsOneWidget);
    expect(handle, findsOneWidget);

    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final initial = tester.getSize(sizer).height;
    expect(initial, closeTo(screenH * 2 / 3, 40));

    await tester.drag(handle, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getSize(sizer).height, greaterThan(initial + 150));
  });
}
