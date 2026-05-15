/// 复述功能开关集成测试
///
/// 端到端验证设置入口可达 + 开关切换写入 Provider。
/// 深层行为（reconcile / 卡片过滤 / 进度计算 / 引导弹窗触发）已被
/// unit + widget 测试覆盖（learning_settings_provider_test.dart /
/// learning_progress_provider_test.dart / retell_intro_dialog_test.dart /
/// learning_settings_screen_test.dart）。
library;

import 'package:echo_loop/main.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 复述功能开关集成测试
void retellToggleTests() {
  group('流程 X：复述功能开关', () {
    testWidgets('设置 → 学习 → 学习设置：开关切换可达且 state 翻转', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 进入我的页
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // 点击「Learning settings」入口
      await tester.tap(find.text('Learning settings'));
      await tester.pumpAndSettle();

      // 学习设置子页应展示开关标题
      expect(find.text('Enable speaking practice'), findsOneWidget);

      // 默认 retellEnabled=true（来自 learningSettingsTestOverrides 默认值）
      final context = tester.element(find.byType(EchoLoopApp));
      final container = ProviderScope.containerOf(context);
      expect(container.read(learningSettingsProvider).retellEnabled, isTrue);

      // 切换开关（true → false）
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(container.read(learningSettingsProvider).retellEnabled, isFalse);

      // 再切回（false → true）
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(container.read(learningSettingsProvider).retellEnabled, isTrue);
    });
  });
}
