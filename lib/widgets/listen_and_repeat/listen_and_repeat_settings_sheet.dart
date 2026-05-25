/// 跟读设置底部弹窗
///
/// 支持配置每句循环次数和句间停顿模式（智能/固定/倍数）。
/// 所有修改即时生效（直接写回 Provider），设置仅对当次跟读有效。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import '../../theme/app_theme.dart';

/// 显示跟读设置底部弹窗
void showListenAndRepeatSettingsSheet({required BuildContext context}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _ListenAndRepeatSettingsSheet(),
  );
}

/// 跟读设置面板（即时生效，无需确认按钮）
class _ListenAndRepeatSettingsSheet extends ConsumerWidget {
  const _ListenAndRepeatSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(listenAndRepeatSettingsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条
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
              l10n.listenAndRepeatSettings,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 临时提示
            Text(
              l10n.listenAndRepeatSettingsTemporaryHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 控制模式
            _buildControlModeSection(l10n, theme, settings, ref),
            const SizedBox(height: AppSpacing.l),

            // 播放速度（手动/自动模式下都生效）
            _buildPlaybackSpeedSection(l10n, theme, settings, ref),

            // 自动模式才显示循环次数和停顿设置
            if (!settings.isManualMode) ...[
              const SizedBox(height: AppSpacing.l),

              // 每句循环次数
              _buildRepeatCountRow(l10n, theme, settings, ref),
              const SizedBox(height: AppSpacing.l),

              // 句间停顿
              Text(
                l10n.intensiveListenPauseLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // 模式切换
              _buildPauseModeSelector(l10n, settings, ref),
              const SizedBox(height: AppSpacing.m),

              // 模式详情
              _buildPauseModeDetail(l10n, theme, settings, ref),
            ],
          ],
        ),
      ),
    );
  }

  /// 播放速度滑块
  ///
  /// 速度仅对当前会话生效，步进为 0.05x，覆盖 0.5x-2.0x。
  Widget _buildPlaybackSpeedSection(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.playbackSpeed,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _formatSpeed(settings.playbackSpeed),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: settings.playbackSpeed.clamp(0.5, 2.0),
          min: 0.5,
          max: 2.0,
          divisions: 30,
          label: _formatSpeed(settings.playbackSpeed),
          onChanged: (value) {
            final speed = (value * 20).round() / 20;
            ref
                .read(listenAndRepeatSettingsProvider.notifier)
                .update(settings.copyWith(playbackSpeed: speed));
          },
        ),
      ],
    );
  }

  /// 统一显示速度标签：整数速度显示为 1x，0.05 步进保留必要小数。
  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) return '${speed.toInt()}x';
    if ((speed * 10).roundToDouble() == speed * 10) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed.toStringAsFixed(2)}x';
  }

  /// 控制模式选择区域
  Widget _buildControlModeSection(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listenAndRepeatControlModeLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ShadowingControlMode>(
            segments: [
              ButtonSegment(
                value: ShadowingControlMode.auto,
                label: Text(l10n.listenAndRepeatControlModeAuto),
                icon: const Icon(Icons.autorenew, size: 18),
              ),
              ButtonSegment(
                value: ShadowingControlMode.manual,
                label: Text(l10n.listenAndRepeatControlModeManual),
                icon: const Icon(Icons.touch_app, size: 18),
              ),
            ],
            selected: {settings.controlMode},
            onSelectionChanged: (selected) {
              ref
                  .read(listenAndRepeatSettingsProvider.notifier)
                  .update(settings.copyWith(controlMode: selected.first));
            },
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                settings.isManualMode
                    ? l10n.listenAndRepeatControlModeManualDesc
                    : l10n.listenAndRepeatControlModeAutoDesc,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 每句循环次数选择行
  Widget _buildRepeatCountRow(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.intensiveListenRepeatCount, style: theme.textTheme.bodyLarge),
        DropdownButton<int>(
          value: settings.repeatCount,
          underline: const SizedBox.shrink(),
          items: List.generate(10, (i) => i + 1).map((count) {
            return DropdownMenuItem(
              value: count,
              child: Text(l10n.intensiveListenRepeatCountValue(count)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(listenAndRepeatSettingsProvider.notifier)
                  .update(settings.copyWith(repeatCount: value));
            }
          },
        ),
      ],
    );
  }

  /// 停顿模式切换（SegmentedButton）
  Widget _buildPauseModeSelector(
    AppLocalizations l10n,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PauseMode>(
        segments: [
          ButtonSegment(
            value: PauseMode.smart,
            label: Text(l10n.intensiveListenPauseSmart),
          ),
          ButtonSegment(
            value: PauseMode.fixed,
            label: Text(l10n.intensiveListenPauseFixed),
          ),
          ButtonSegment(
            value: PauseMode.multiplier,
            label: Text(l10n.intensiveListenPauseMultiplierMode),
          ),
        ],
        selected: {settings.pauseMode},
        onSelectionChanged: (selected) {
          ref
              .read(listenAndRepeatSettingsProvider.notifier)
              .update(settings.copyWith(pauseMode: selected.first));
        },
        showSelectedIcon: false,
      ),
    );
  }

  /// 停顿模式详情区域
  Widget _buildPauseModeDetail(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    switch (settings.pauseMode) {
      case PauseMode.smart:
        return Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.listenAndRepeatPauseSmartDesc,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ],
        );

      case PauseMode.fixed:
        final options = IntensiveListenSettings.fixedPauseOptions;
        var idx = options.indexOf(settings.fixedPauseSeconds);
        if (idx < 0) idx = 2; // 回退到 5 秒
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: idx.toDouble(),
                min: 0,
                max: (options.length - 1).toDouble(),
                divisions: options.length - 1,
                label: '${options[idx]}s',
                onChanged: (v) {
                  ref
                      .read(listenAndRepeatSettingsProvider.notifier)
                      .update(
                        settings.copyWith(
                          fixedPauseSeconds: options[v.round()],
                        ),
                      );
                },
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${settings.fixedPauseSeconds}s',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case PauseMode.multiplier:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.intensiveListenPauseMultiplierLabel,
              style: theme.textTheme.bodyLarge,
            ),
            DropdownButton<double>(
              value: settings.pauseMultiplier,
              underline: const SizedBox.shrink(),
              items: IntensiveListenSettings.multiplierOptions.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(
                    l10n.intensiveListenPauseMultiplierValue(
                      value.toStringAsFixed(
                        value == value.roundToDouble() ? 0 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(listenAndRepeatSettingsProvider.notifier)
                      .update(settings.copyWith(pauseMultiplier: value));
                }
              },
            ),
          ],
        );
    }
  }
}
