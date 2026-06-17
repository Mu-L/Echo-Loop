/// 自由练习（全能播放器）循环设置浮层
///
/// 悬浮在控制栏循环图标上方的浮层（非底部 sheet），即时生效并持久化。包含两组
/// **相互独立、可同时开启**的循环：
/// - 整篇循环：整篇播完后回到开头重播，可设总遍数（含 ∞）与每遍间隔。
/// - 单句循环：每句重复若干次（含 ∞）后进下一句，可设次数与每次间隔。
///
/// 每个区块由一个主开关控制；开启后用 [AnimatedSize] 展开「重复次数 / 间隔时长」两行
/// 滑块。布局紧凑：标签、滑条、当前值同处一行。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/playback_settings.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../theme/app_theme.dart';

/// 循环设置浮层内容（卡片）。由调用方放进 Overlay 并锚定到循环按钮上方。
class LoopSettingsPopup extends ConsumerWidget {
  const LoopSettingsPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(
      listeningPracticeProvider.select((s) => s.settings),
    );
    final controller = ref.read(listeningPracticeProvider.notifier);

    void update(PlaybackSettings next) => controller.updateSettings(next);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  l10n.loopSettings,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 整篇循环
              _LoopSection(
                icon: Icons.repeat,
                title: l10n.wholeTextLoop,
                enabled: settings.loopWhole,
                count: settings.wholeLoopCount,
                intervalSeconds: settings.wholeInterval.inSeconds,
                onEnabledChanged: (v) =>
                    update(settings.copyWith(loopWhole: v)),
                onCountChanged: (v) =>
                    update(settings.copyWith(wholeLoopCount: v)),
                onIntervalChanged: (v) => update(
                  settings.copyWith(wholeInterval: Duration(seconds: v)),
                ),
              ),
              const Divider(height: AppSpacing.s),
              // 单句循环
              _LoopSection(
                icon: Icons.repeat_one,
                title: l10n.singleSentenceLoop,
                enabled: settings.loopSentence,
                count: settings.sentenceLoopCount,
                intervalSeconds: settings.sentenceInterval.inSeconds,
                onEnabledChanged: (v) =>
                    update(settings.copyWith(loopSentence: v)),
                onCountChanged: (v) =>
                    update(settings.copyWith(sentenceLoopCount: v)),
                onIntervalChanged: (v) => update(
                  settings.copyWith(sentenceInterval: Duration(seconds: v)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单组循环区块：紧凑主开关行 + 开启后展开的两行「标签 + 滑条 + 值」。
class _LoopSection extends StatelessWidget {
  const _LoopSection({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.count,
    required this.intervalSeconds,
    required this.onEnabledChanged,
    required this.onCountChanged,
    required this.onIntervalChanged,
  });

  /// 区块图标（整篇=repeat，单句=repeat_one）。
  final IconData icon;

  /// 区块标题。
  final String title;

  /// 该循环是否开启。
  final bool enabled;

  /// 重复次数模型值：`0`=∞，`1-10`=有限。
  final int count;

  /// 间隔秒数（0-10）。
  final int intervalSeconds;

  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 紧凑主开关行
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onEnabledChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        // 子设置：开启后展开
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: enabled
              ? Column(
                  children: [
                    // 重复次数：1-10 + ∞（末位）
                    _LabeledSliderRow(
                      label: l10n.repeatCount,
                      sliderValue: _countToSlider(count),
                      min: 1,
                      max: 11,
                      divisions: 10,
                      valueLabel: _countLabel(l10n, count),
                      onChanged: (pos) => onCountChanged(_sliderToCount(pos)),
                    ),
                    // 间隔时长：0-10 秒
                    _LabeledSliderRow(
                      label: l10n.intervalTime,
                      sliderValue: intervalSeconds.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      valueLabel: '$intervalSeconds ${l10n.seconds}',
                      onChanged: (v) => onIntervalChanged(v.round()),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// 次数模型值 → 滑块位置：∞(0) 放最右端 11。
  static double _countToSlider(int count) => count == 0 ? 11 : count.toDouble();

  /// 滑块位置 → 次数模型值：11=∞(0)。
  static int _sliderToCount(double pos) => pos >= 11 ? 0 : pos.round();

  /// 次数显示文案：∞ 或「N 次」。
  static String _countLabel(AppLocalizations l10n, int count) =>
      count == 0 ? '∞' : '$count ${l10n.times}';
}

/// 紧凑的「标签 + 滑条 + 当前值」单行组件。
class _LabeledSliderRow extends StatelessWidget {
  const _LabeledSliderRow({
    required this.label,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double sliderValue;
  final double min;
  final double max;
  final int divisions;

  /// 右侧及拖动气泡显示的当前值文案。
  final String valueLabel;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: sliderValue.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
              semanticFormatterCallback: (_) => valueLabel,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
