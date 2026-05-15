/// LearningSettingsScreen Widget 测试
///
/// 覆盖：
/// - 开关初始值显示
/// - 切换开关写入 SP + 翻转 state
/// - 说明文字渲染
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/screens/learning_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildApp({bool retellEnabled = false}) async {
    SharedPreferences.setMockInitialValues({
      if (retellEnabled) LearningSettingsKeys.retellEnabled: true,
    });
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialLearningSettingsProvider.overrideWithValue(
          LearningSettings.fromPrefsSync(prefs),
        ),
        analyticsOverride(),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('zh')],
        home: LearningSettingsScreen(),
      ),
    );
  }

  testWidgets('默认显示开关 OFF + 说明文字', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
    // 说明文字（部分关键词）
    expect(find.textContaining('Speaking practice'), findsWidgets);
  });

  testWidgets('点击开关 → 翻转 state + 写 SP', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LearningSettingsKeys.retellEnabled), isTrue);
  });

  testWidgets('初始 ON 时开关显示 ON', (tester) async {
    await tester.pumpWidget(await buildApp(retellEnabled: true));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue);
  });
}
