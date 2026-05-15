/// RetellIntroDialog Widget 测试
///
/// 覆盖：
/// - 弹窗渲染（标题/正文/两按钮）
/// - 「立即开启」→ setRetellEnabled(true) + markSetupChoiceMade
/// - 「暂不开启」→ 仅 markSetupChoiceMade
/// - 重复触发 ensureRetellDecisionMade → 不弹（已展示）
library;

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/widgets/retell_decision_gate.dart';
import 'package:echo_loop/widgets/retell_intro_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildHost({
    bool introShown = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (introShown) LearningSettingsKeys.setupChoiceMadeAtMs: 1700000000000,
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
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: Consumer(
          builder: (context, ref, _) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ensureRetellDecisionMade(context, ref),
                  child: const Text('Trigger'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('未展示过 → 触发弹窗显示', (tester) async {
    await tester.pumpWidget(await buildHost());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(RetellIntroDialog), findsOneWidget);
    expect(find.text('Enable speaking practice?'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Enable now'), findsOneWidget);
  });

  testWidgets('点击「立即开启」→ retellEnabled=true + introShown=true',
      (tester) async {
    await tester.pumpWidget(await buildHost());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable now'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(Scaffold));
    final container = ProviderScope.containerOf(element);
    final settings = container.read(learningSettingsProvider);
    expect(settings.retellEnabled, isTrue);
    expect(settings.setupChoiceMade, isTrue);
  });

  testWidgets('点击「暂不开启」→ retellEnabled=false + introShown=true',
      (tester) async {
    await tester.pumpWidget(await buildHost());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(Scaffold));
    final container = ProviderScope.containerOf(element);
    final settings = container.read(learningSettingsProvider);
    expect(settings.retellEnabled, isFalse);
    expect(settings.setupChoiceMade, isTrue);
  });

  testWidgets('已展示过 → 触发后不弹窗', (tester) async {
    await tester.pumpWidget(await buildHost(introShown: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(RetellIntroDialog), findsNothing);
  });

  testWidgets('快速重复触发 → SP setInt 同步缓存阻止双弹', (tester) async {
    await tester.pumpWidget(await buildHost());
    await tester.pumpAndSettle();

    // 第一次触发：弹窗出现
    await tester.tap(find.text('Trigger'));
    await tester.pump();
    expect(find.byType(RetellIntroDialog), findsOneWidget);

    // 关闭弹窗
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // 第二次触发：不弹
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(RetellIntroDialog), findsNothing);
  });

  testWidgets('点击关闭按钮 → 不修改设置、不标记已决策（保留原页面）', (tester) async {
    await tester.pumpWidget(await buildHost());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(RetellIntroDialog), findsOneWidget);

    // 点关闭按钮（IconButton with Icons.close）
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(Scaffold));
    final container = ProviderScope.containerOf(element);
    final settings = container.read(learningSettingsProvider);
    // 关闭弹窗不修改设置、不标记已决策
    expect(settings.setupChoiceMade, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(LearningSettingsKeys.setupChoiceMadeAtMs),
      isFalse,
      reason: '关闭弹窗未做决定，SP key 不应被写入',
    );

    // 再次触发 → 弹窗仍然出现
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(RetellIntroDialog), findsOneWidget);
  });

  testWidgets('开启状态下选「暂不开启」→ 关闭复述（bug 4 回归）', (tester) async {
    // 模拟：用户已在设置页开启复述，此时被 gate 弹窗（理论上不会，但作为防御）
    SharedPreferences.setMockInitialValues({
      LearningSettingsKeys.retellEnabled: true,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialLearningSettingsProvider.overrideWithValue(
            LearningSettings.fromPrefsSync(prefs),
          ),
          analyticsOverride(),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => ensureRetellDecisionMade(context, ref),
                    child: const Text('Trigger'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(RetellIntroDialog), findsOneWidget);

    // 「暂不开启」必须把 retellEnabled 写为 false（即使之前是 true）
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(Scaffold));
    final container = ProviderScope.containerOf(element);
    expect(
      container.read(learningSettingsProvider).retellEnabled,
      isFalse,
      reason: '选「暂不开启」必须关闭复述，不论初始状态',
    );
  });

  testWidgets('删除 SP 后再次触发 → 弹窗重新出现（重置语义回归）', (tester) async {
    await tester.pumpWidget(await buildHost(introShown: true));
    await tester.pumpAndSettle();

    // 验证已展示态下不弹
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(RetellIntroDialog), findsNothing);

    // 模拟用户/调试者删除 SP key
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LearningSettingsKeys.setupChoiceMadeAtMs);

    // 再次触发：弹窗应该出现（SP 是权威来源，不读内存 flag）
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.byType(RetellIntroDialog), findsOneWidget);
  });
}
