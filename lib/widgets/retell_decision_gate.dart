/// 复述功能首次设置 gate
///
/// 在用户**进入学习计划页之前**确保已就「是否启用复述」做出过选择。
/// 与「进入 plan 页之后再弹窗」相比，前置 gate 解决两个问题：
/// 1. 关闭复述后 plan 页不需要刷新 widget 状态（initState 时 settings 已最终确定）
/// 2. 避免与盲听简报等 plan 页内自动弹窗叠加
///
/// 命名风格对齐 `lib/widgets/speech_permission_dialog.dart` 的
/// `ensureSpeechReadyForRecording` / `ensureSpeechReadyForSubStage`。
///
/// 返回值：
/// - `true`  → 用户已做过选择（开启或不开启），调用方可继续 push plan 页
/// - `false` → 用户点关闭按钮/点遮罩取消，**未**做选择，调用方应停留原页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../providers/learning_settings_provider.dart';
import 'retell_intro_dialog.dart';

/// 确保已就复述做出设置选择。
///
/// - SP 中已存在 `setupChoiceMadeAtMs` → 直接返回 `true`
/// - 未存在 → 弹 [RetellIntroDialog]：
///   - 用户点「现在开启」或「暂不开启」→ dialog 自行写 setRetellEnabled +
///     markSetupChoiceMade，返回 `true`
///   - 用户关闭弹窗（X 按钮或点遮罩）→ 不修改设置、不标记已决策，返回 `false`
Future<bool> ensureRetellDecisionMade(
  BuildContext context,
  WidgetRef ref,
) async {
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs.containsKey(LearningSettingsKeys.setupChoiceMadeAtMs)) return true;

  ref.read(analyticsServiceProvider).track(Events.retellIntroDialogShown, {});

  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const RetellIntroDialog(),
  );
  // result 为 null 表示用户关闭弹窗未做选择，调用方停留原页面
  return result != null;
}
