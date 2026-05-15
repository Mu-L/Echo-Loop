/// 学习设置 Provider
///
/// 全局控制是否启用「复述（retell）」功能。默认关闭，用户可在
/// 设置 → 学习设置 中切换；首次进入任意音频学习计划页时一次性弹窗询问。
///
/// 持久化分两个 SP key：
/// - `learning_retell_enabled` (bool)：开关状态
/// - `retell_setup_choice_at_ms` (int)：首次弹窗已展示时间戳
///   （存在即视为已展示过，永不重弹）
///
/// 采用手动 Notifier 模式（不走 riverpod_generator），对齐
/// [lib/features/onboarding_survey/providers/onboarding_survey_provider.dart]。
/// `build()` 从 [initialLearningSettingsProvider] 同步读 SP 注入的快照，
/// 避免 router redirect / 学习计划页 initState 在异步加载完成前拿不到状态。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../services/app_logger.dart';

export '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;

/// 同步从 SP 预读的学习设置初值，由 main() 通过 override 注入。
///
/// 未 override 时抛出，强制启动期显式注入。
final initialLearningSettingsProvider = Provider<LearningSettings>((ref) {
  throw UnimplementedError(
    'initialLearningSettingsProvider must be overridden in main()',
  );
});

/// 学习设置 SP key 常量。
abstract final class LearningSettingsKeys {
  static const retellEnabled = 'learning_retell_enabled';
  static const setupChoiceMadeAtMs = 'retell_setup_choice_at_ms';
}

/// 学习设置不可变值对象。
///
/// 当前仅一个用户偏好（[retellEnabled]）+ 一个展示状态（[setupChoiceMade]）。
/// 未来扩展只需新增字段并在 [fromPrefsSync] / [copyWith] 中补对应处理。
class LearningSettings {
  /// 是否启用复述练习（默认 false）。
  final bool retellEnabled;

  /// 首次进入音频学习计划页的引导弹窗是否已展示。
  ///
  /// 由 SP key [LearningSettingsKeys.setupChoiceMadeAtMs] 是否存在派生，
  /// 用户答完弹窗后永久翻转为 true。
  final bool setupChoiceMade;

  const LearningSettings({
    this.retellEnabled = false,
    this.setupChoiceMade = false,
  });

  /// 同步从 [SharedPreferences] 派生当前状态，用于启动期 override 注入。
  factory LearningSettings.fromPrefsSync(SharedPreferences prefs) {
    return LearningSettings(
      retellEnabled: prefs.getBool(LearningSettingsKeys.retellEnabled) ?? false,
      setupChoiceMade:
          prefs.containsKey(LearningSettingsKeys.setupChoiceMadeAtMs),
    );
  }

  LearningSettings copyWith({
    bool? retellEnabled,
    bool? setupChoiceMade,
  }) {
    return LearningSettings(
      retellEnabled: retellEnabled ?? this.retellEnabled,
      setupChoiceMade: setupChoiceMade ?? this.setupChoiceMade,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningSettings &&
          runtimeType == other.runtimeType &&
          retellEnabled == other.retellEnabled &&
          setupChoiceMade == other.setupChoiceMade;

  @override
  int get hashCode => Object.hash(retellEnabled, setupChoiceMade);
}

/// 学习设置 Notifier。
///
/// 单向数据流：[setRetellEnabled] 仅写自己的 state + SP；progress 端通过
/// `ref.listen(learningSettingsProvider)` 监听变化触发 reconcile，
/// 不在此 Notifier 内反向 read progress notifier 避免双向耦合。
class LearningSettingsNotifier extends Notifier<LearningSettings> {
  @override
  LearningSettings build() => ref.read(initialLearningSettingsProvider);

  /// 切换 retellEnabled，写 SP + 更新 state。
  ///
  /// 调用方负责埋点（不同 source 需要不同的 source 参数）。
  Future<void> setRetellEnabled(bool enabled) async {
    if (state.retellEnabled == enabled) return;
    state = state.copyWith(retellEnabled: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.retellEnabled, enabled);
    } catch (e) {
      AppLogger.log('LearningSettings', 'setRetellEnabled 写 SP 失败: $e');
    }
  }

  /// 标记引导弹窗已展示。
  ///
  /// SP key 不存在时写入时间戳；存在则跳过（幂等，不覆盖原时间戳）。
  /// 内存 `setupChoiceMade` 翻转为 true 便于其他 watch 该字段的 UI 同步。
  /// **不**基于内存 flag 提前返回——SP 才是权威来源，允许"删除 SP 重置"。
  Future<void> markSetupChoiceMade() async {
    state = state.copyWith(setupChoiceMade: true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (!prefs.containsKey(LearningSettingsKeys.setupChoiceMadeAtMs)) {
        await prefs.setInt(
          LearningSettingsKeys.setupChoiceMadeAtMs,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      AppLogger.log('LearningSettings', 'markSetupChoiceMade 写 SP 失败: $e');
    }
  }
}

/// 学习设置 Provider 入口。
final learningSettingsProvider =
    NotifierProvider<LearningSettingsNotifier, LearningSettings>(
  LearningSettingsNotifier.new,
);
