/// 学习设置页面
///
/// 控制全局学习行为偏好，本期只支持「启用复述练习」开关。
/// 默认关闭：复述类子阶段（段落复述 / 复习段落复述 / 全文复述）从「按
/// 计划学习」流中过滤掉，且关闭瞬间会触发 reconcile 推进当前停留在
/// 复述子阶段的进度。自由练习入口不受影响。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_settings_provider.dart';
import '../theme/app_theme.dart';

/// 学习设置页面
class LearningSettingsScreen extends ConsumerWidget {
  const LearningSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(learningSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
          _SectionHeader(title: l10n.speakingPracticeSection),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.retellEnabledToggle),
              subtitle: Text(l10n.retellEnabledSubtitle),
              value: settings.retellEnabled,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setRetellEnabled(value);
                ref.read(analyticsServiceProvider).track(
                  Events.retellToggleChanged,
                  {
                    EventParams.enabled: value,
                    EventParams.source: 'settings_page',
                  },
                );
              },
            ),
          ),
          _DescriptionText(text: l10n.retellEnabledDescription),
        ],
      ),
    );
  }
}

/// Section 标题
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Section 下方灰色说明文字
class _DescriptionText extends StatelessWidget {
  final String text;
  const _DescriptionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m + AppSpacing.xs,
        AppSpacing.s,
        AppSpacing.m,
        0,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
