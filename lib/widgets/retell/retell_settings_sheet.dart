/// 复述设置面板
///
/// 底部弹窗，即时生效，仅本次会话。
/// 设置项：重复次数 + 段间停顿 + 可见词生成方式 + 可见词比例
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/retell_settings.dart';
import '../../providers/learning_session/retell_player_provider.dart';
import '../../theme/app_theme.dart';

/// 显示复述设置面板
Future<void> showRetellSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _RetellSettingsSheet(),
  );
}

class _RetellSettingsSheet extends ConsumerWidget {
  const _RetellSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(retellPlayerProvider);
    final settings = state.settings;

    return SafeArea(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽指示条
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.m),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题
          Text(
            l10n.retellSettingsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 本次生效提示（紧跟标题下方）
          Text(
            l10n.settingsSessionOnly,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // ── 1. 重复次数 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.retellRepeatCount,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              DropdownButton<int>(
                value: settings.repeatCount,
                underline: const SizedBox.shrink(),
                items: List.generate(5, (i) {
                  final count = i + 1;
                  return DropdownMenuItem(
                    value: count,
                    child: Text('$count'),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(retellPlayerProvider.notifier).updateSettings(
                          settings.copyWith(repeatCount: value),
                        );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),

          // ── 2. 段间停顿 ──
          Text(
            l10n.retellPauseMode,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<PauseMode>(
            segments: [
              ButtonSegment(
                value: PauseMode.smart,
                label: Text(l10n.pauseModeSmart),
              ),
              ButtonSegment(
                value: PauseMode.fixed,
                label: Text(l10n.pauseModeFixed),
              ),
              ButtonSegment(
                value: PauseMode.multiplier,
                label: Text(l10n.pauseModeMultiplier),
              ),
            ],
            selected: {settings.pauseMode},
            onSelectionChanged: (selected) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(pauseMode: selected.first),
                  );
            },
          ),

          // 固定间隔选项（仅 fixed 模式，ChoiceChip 与跟读一致）
          if (settings.pauseMode == PauseMode.fixed) ...[
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: RetellSettings.fixedPauseOptions.map((seconds) {
                return ChoiceChip(
                  label: Text('${seconds}s'),
                  selected: settings.fixedPauseSeconds == seconds,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(retellPlayerProvider.notifier).updateSettings(
                            settings.copyWith(fixedPauseSeconds: seconds),
                          );
                    }
                  },
                );
              }).toList(),
            ),
          ],

          // 倍数选项（仅 multiplier 模式，DropdownButton 与跟读一致）
          if (settings.pauseMode == PauseMode.multiplier) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.pauseMultiplier, style: theme.textTheme.bodyLarge),
                DropdownButton<double>(
                  value: settings.pauseMultiplier,
                  underline: const SizedBox.shrink(),
                  items: RetellSettings.multiplierOptions.map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(
                        '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}x',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(retellPlayerProvider.notifier).updateSettings(
                            settings.copyWith(pauseMultiplier: value),
                          );
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),

          // ── 3. 可见词生成方式 ──
          Text(
            l10n.retellKeywordMethod,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<KeywordMethod>(
            segments: [
              ButtonSegment(
                value: KeywordMethod.off,
                label: Text(l10n.retellKeywordMethodOff),
              ),
              ButtonSegment(
                value: KeywordMethod.random,
                label: Text(l10n.retellKeywordMethodRandom),
              ),
              ButtonSegment(
                value: KeywordMethod.ai,
                label: Tooltip(
                  message: l10n.retellKeywordMethodAiComingSoon,
                  child: Text(l10n.retellKeywordMethodAi),
                ),
                enabled: false,
              ),
            ],
            selected: {settings.keywordMethod},
            onSelectionChanged: (selected) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(keywordMethod: selected.first),
                  );
            },
          ),

          // 可见词比例（关闭时隐藏）
          if (settings.keywordMethod != KeywordMethod.off) ...[
            const SizedBox(height: AppSpacing.l),
            Text(
              l10n.retellKeywordRatio,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                for (final ratio in KeywordRatio.values)
                  ChoiceChip(
                    label: Text('${ratio.numerator}/${ratio.denominator}'),
                    selected: settings.keywordRatio == ratio,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(retellPlayerProvider.notifier)
                            .updateSettings(
                              settings.copyWith(keywordRatio: ratio),
                            );
                      }
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }
}
