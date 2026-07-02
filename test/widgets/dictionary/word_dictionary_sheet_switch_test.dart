/// 弹窗多源切换集成测试：默认本地 → 切到 AI → 切回本地（复用缓存）。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

class MockDictionaryService extends Mock implements DictionaryService {}

/// 返回固定结果的 fake 源，记录调用次数
class _FixedSource implements DictionarySource {
  @override
  final String id;
  final DictionaryLookupResult result;
  int calls = 0;
  _FixedSource(this.id, this.result);
  @override
  IconData get icon => Icons.abc;
  @override
  bool get canBeDisabled => id == 'cambridge';
  @override
  bool get requiresNetwork => id != 'local';
  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return result;
  }
}

DictionaryEntry _aiEntry({String headword = 'run'}) => DictionaryEntry(
  headword: headword,
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
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService oldInstance;
  late _FixedSource local;
  late _FixedSource ai;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final mock = MockDictionaryService();
    when(() => mock.isAvailable).thenReturn(true);
    oldInstance = DictionaryService.replaceInstance(mock);
    local = _FixedSource(
      'local',
      const LocalDictResult(
        DictEntry(word: 'run', phonetic: 'rʌn', translation: 'v. 跑'),
      ),
    );
    ai = _FixedSource('ai', AiDictResult(_aiEntry()));
  });

  tearDown(() => DictionaryService.replaceInstance(oldInstance));

  Widget wrap({_FixedSource? aiSource, String word = 'run'}) {
    final aiSrc = aiSource ?? ai;
    return ProviderScope(
      overrides: [
        analyticsOverride(),
        dictionaryOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dictionarySourcesProvider.overrideWithValue([local, aiSrc]),
        dictionarySourcesByIdProvider.overrideWithValue({
          'local': local,
          'ai': aiSrc,
        }),
        resolvedDefaultSourceIdProvider.overrideWithValue('local'),
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
        home: Scaffold(
          body: DictionaryPanel(
            query: DictionaryPanelQuery(word: word),
            onClose: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('默认本地 → 切 AI → 切回本地复用缓存', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 默认本地：显示释义「跑」，切换器为 Local Dictionary
    expect(find.text('跑'), findsOneWidget);
    expect(find.text('Local Dictionary'), findsOneWidget);

    // 切到 AI（独立的 AI 快捷按钮）
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('奔跑'), findsOneWidget);
    expect(ai.calls, 1);

    // 切回本地：点切换器 chip 打开菜单，选 Local Dictionary，复用缓存不重复查询
    await tester.tap(find.text('Local Dictionary')); // 切换器 chip
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local Dictionary').last); // 菜单项
    await tester.pumpAndSettle();
    expect(find.text('跑'), findsOneWidget);
    expect(local.calls, 1); // 仍只查过一次
  });

  testWidgets('切到 AI 成功后，标题替换为 AI headword（区别于查询词）', (tester) async {
    // 查询词 "geese" 在各源都不出现：标题始终用结果 headword。
    // 切到 AI 后，标题为 AI 返回的 headword "goose"。
    final aiGoose = _FixedSource(
      'ai',
      AiDictResult(_aiEntry(headword: 'goose')),
    );
    await tester.pumpWidget(wrap(aiSource: aiGoose, word: 'geese'));
    await tester.pumpAndSettle();

    // 查询词从不直接作标题（本地命中后显示本地 headword）
    expect(find.text('geese'), findsNothing);

    // 切到 AI：标题为 AI headword goose
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('goose'), findsOneWidget);
  });
}
