/// 复述功能引导弹窗
///
/// 用户首次进入任意音频学习计划页**之前**由 `ensureRetellDecisionMade`
/// 触发（见 `lib/widgets/retell_decision_gate.dart`），告知复述是难度较大
/// 的练习方法，让用户主动选择是否启用。
///
/// 返回值约定：
/// - `true`：用户选「现在开启」→ `setRetellEnabled(true)` + 已决策
/// - `false`：用户选「暂不开启」→ `setRetellEnabled(false)` + 已决策
/// - `null`：用户点关闭按钮或点遮罩 → 不修改设置、不标记已决策（下次会再问）
///
/// 两个按钮视觉权重对等（OutlinedButton × 2），中性选择不引导倾向。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_settings_provider.dart';

/// 复述功能引导弹窗。
class RetellIntroDialog extends ConsumerWidget {
  const RetellIntroDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.retellPromptTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.retellPromptBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _applyChoice(
                              ref,
                              enable: false,
                              analyticsChoice: 'dismiss',
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop(false);
                            }
                          },
                          child: Text(l10n.retellPromptDismiss),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _applyChoice(
                              ref,
                              enable: true,
                              analyticsChoice: 'enable',
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          child: Text(l10n.retellPromptEnable),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 右上角关闭按钮（不修改设置，不标记已决策）
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip:
                    MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 写入用户选择：埋点 + 翻转 retellEnabled + 标记已决策。
  Future<void> _applyChoice(
    WidgetRef ref, {
    required bool enable,
    required String analyticsChoice,
  }) async {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(
      Events.retellIntroDialogChoice,
      {EventParams.choice: analyticsChoice},
    );
    final notifier = ref.read(learningSettingsProvider.notifier);
    await notifier.setRetellEnabled(enable);
    await notifier.markSetupChoiceMade();
    analytics.track(Events.retellToggleChanged, {
      EventParams.enabled: enable,
      EventParams.source: 'intro_dialog',
    });
  }
}
