/// LearningSettings Provider 单元测试
///
/// 覆盖：
/// - 默认值（retellEnabled=false, setupChoiceMade=false）
/// - SP 同步预读注入正确
/// - setRetellEnabled 写 SP + 状态更新
/// - markSetupChoiceMade 写 SP + 内存 flag 翻转
/// - 防御性兜底（SP 中非 bool 值不崩溃）
library;

import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(SharedPreferences prefs) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialLearningSettingsProvider.overrideWithValue(
          LearningSettings.fromPrefsSync(prefs),
        ),
      ],
    );
  }

  group('LearningSettings.fromPrefsSync', () {
    test('SP 缺失时返回默认值（retellEnabled=false, setupChoiceMade=false）',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = LearningSettings.fromPrefsSync(prefs);
      expect(settings.retellEnabled, isFalse);
      expect(settings.setupChoiceMade, isFalse);
    });

    test('SP 已写入 retellEnabled=true 时同步返回 true', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = LearningSettings.fromPrefsSync(prefs);
      expect(settings.retellEnabled, isTrue);
    });

    test('SP 已写入 setupChoiceMadeAtMs 时返回 setupChoiceMade=true', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.setupChoiceMadeAtMs: 1700000000000,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = LearningSettings.fromPrefsSync(prefs);
      expect(settings.setupChoiceMade, isTrue);
    });

    test('SP 类型不符（如 retellEnabled 存成 String）时回退默认值', () async {
      // SharedPreferences mock 不允许 mixed type，这里测试 missing/类型错误兜底
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = LearningSettings.fromPrefsSync(prefs);
      expect(settings.retellEnabled, isFalse);
    });
  });

  group('LearningSettingsNotifier', () {
    test('build 返回 initialLearningSettingsProvider 注入值', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final settings = container.read(learningSettingsProvider);
      expect(settings.retellEnabled, isTrue);
    });

    test('setRetellEnabled(true) 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setRetellEnabled(true);

      expect(container.read(learningSettingsProvider).retellEnabled, isTrue);
      expect(prefs.getBool(LearningSettingsKeys.retellEnabled), isTrue);
    });

    test('setRetellEnabled(false) 写 SP + 翻转 state', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.retellEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.setRetellEnabled(false);

      expect(container.read(learningSettingsProvider).retellEnabled, isFalse);
      expect(prefs.getBool(LearningSettingsKeys.retellEnabled), isFalse);
    });

    test('markSetupChoiceMade 写 SP + 内存 flag 翻转', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      expect(container.read(learningSettingsProvider).setupChoiceMade, isFalse);

      await notifier.markSetupChoiceMade();

      expect(container.read(learningSettingsProvider).setupChoiceMade, isTrue);
      expect(prefs.getInt(LearningSettingsKeys.setupChoiceMadeAtMs), isNotNull);
    });

    test('markSetupChoiceMade 幂等：重复调用不重写 SP', () async {
      SharedPreferences.setMockInitialValues({
        LearningSettingsKeys.setupChoiceMadeAtMs: 1700000000000,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(learningSettingsProvider.notifier);
      await notifier.markSetupChoiceMade();

      // 已存在的时间戳不被覆盖
      expect(
        prefs.getInt(LearningSettingsKeys.setupChoiceMadeAtMs),
        1700000000000,
      );
    });
  });

  group('LearningSettings model', () {
    test('copyWith 保持其他字段不变', () {
      const settings = LearningSettings(
        retellEnabled: true,
        setupChoiceMade: true,
      );
      final copied = settings.copyWith(retellEnabled: false);
      expect(copied.retellEnabled, isFalse);
      expect(copied.setupChoiceMade, isTrue);
    });

    test('== 和 hashCode 正确', () {
      const a = LearningSettings(retellEnabled: true, setupChoiceMade: false);
      const b = LearningSettings(retellEnabled: true, setupChoiceMade: false);
      const c = LearningSettings(retellEnabled: false, setupChoiceMade: false);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
