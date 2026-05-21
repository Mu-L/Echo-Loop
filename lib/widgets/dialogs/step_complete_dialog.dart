/// 步骤完成通用对话框
///
/// 合并了精听、跟读、复述、难句补练、盲听等多个播放器页面的完成对话框。
/// 统一的布局：右上角关闭按钮、标题行（图标 + 标题）、步骤进度、自定义内容、
/// 可选难度选择器、底部操作按钮。
///
/// 按钮布局根据上下文分三种情况：
/// 1. 有下一步可继续：[完成] [继续：X]
/// 2. 末步骤：[完成首次学习/复习]（全宽）
/// 3. 非末步骤但下一步不可用：[完成]（全宽）
///
/// 使用 [showDialog] + `useRootNavigator: true` 显示弹窗，
/// 弹窗挂到 root Navigator，与 GoRouter 路由栈隔离。
/// `barrierDismissible: true`，点击外部区域或右上角关闭按钮返回 null。
library;

import 'package:flutter/material.dart';
import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 用户在完成对话框中的选择
enum StepCompleteAction {
  /// 继续下一步
  continueNext,

  /// 完成当前步骤，返回计划页
  back,
}

/// 步骤完成对话框返回结果
///
/// [action] 用户选择的操作。
/// [difficulty] 仅在 [showDifficultySelector] 为 true 时有值。
typedef StepCompleteResult = ({
  StepCompleteAction action,
  DifficultyLevel? difficulty,
});

/// 显示步骤完成对话框
///
/// 返回 `null` 表示用户点击外部区域或关闭按钮关闭，
/// 返回 [StepCompleteResult] 表示用户点击了操作按钮。
///
/// [title] 对话框标题文本。
/// [contentBody] 自定义内容区域（如完成统计信息）。
/// [stepIndex] 当前完成的步骤序号（0-based），null 表示不显示步骤进度。
/// [totalSteps] 当前阶段总步骤数。
/// [stageName] 当前阶段名称（如"首次学习"）。
/// [nextStepName] 下一步名称（null 表示下一步不可用或不存在）。
/// [isLastStep] 是否为当前阶段的最后一步。
/// [showDifficultySelector] 是否显示 5 档难度选择器。
Future<StepCompleteResult?> showStepCompleteDialog({
  required BuildContext context,
  required String title,
  Widget? contentBody,
  int? stepIndex,
  int? totalSteps,
  String? stageName,
  String? nextStepName,
  bool isLastStep = false,
  bool showDifficultySelector = false,
}) {
  return showDialog<StepCompleteResult>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) => StepCompleteDialog(
      onResult: (result) => Navigator.of(dialogContext).pop(result),
      title: title,
      contentBody: contentBody,
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      stageName: stageName,
      nextStepName: nextStepName,
      isLastStep: isLastStep,
      showDifficultySelector: showDifficultySelector,
    ),
  );
}

/// 步骤完成通用对话框组件
class StepCompleteDialog extends StatefulWidget {
  /// 对话框标题
  final String title;

  /// 自定义内容区域
  final Widget? contentBody;

  /// 当前步骤序号（0-based），null 则不显示步骤进度
  final int? stepIndex;

  /// 总步骤数
  final int? totalSteps;

  /// 阶段名称
  final String? stageName;

  /// 下一步名称（null = 不可用）
  final String? nextStepName;

  /// 是否为最后一步
  final bool isLastStep;

  /// 是否显示难度选择器
  final bool showDifficultySelector;

  /// 结果回调
  final void Function(StepCompleteResult?) onResult;

  const StepCompleteDialog({
    super.key,
    required this.onResult,
    required this.title,
    this.contentBody,
    this.stepIndex,
    this.totalSteps,
    this.stageName,
    this.nextStepName,
    this.isLastStep = false,
    this.showDifficultySelector = false,
  });

  @override
  State<StepCompleteDialog> createState() => _StepCompleteDialogState();
}

class _StepCompleteDialogState extends State<StepCompleteDialog> {
  /// 选中的难度等级（null = 未选择）
  DifficultyLevel? _selectedDifficulty;

  /// 操作按钮是否可用
  ///
  /// 显示难度选择器时必须选择难度后才可用，否则直接可用。
  bool get _actionsEnabled =>
      !widget.showDifficultySelector || _selectedDifficulty != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 主体内容
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Flexible(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                // 步骤进度信息
                if (widget.stepIndex != null &&
                    widget.totalSteps != null &&
                    widget.stageName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.stepProgressLabel(
                      widget.stepIndex! + 1,
                      widget.totalSteps!,
                      widget.stageName!,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                // 自定义内容
                if (widget.contentBody != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  widget.contentBody!,
                ],
                // 难度选择器
                if (widget.showDifficultySelector) ...[
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    l10n.selectDifficulty,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _buildDifficultySelector(l10n),
                ],
                const SizedBox(height: AppSpacing.l),
                // 底部操作按钮
                ..._buildActions(context, l10n),
              ],
            ),
          ),
          // 右上角关闭按钮
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: () => widget.onResult(null),
              icon: const Icon(Icons.close, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 5 档难度选择器
  ///
  /// 风格与 App 整体协调：上方一根极细绿→红渐变线提示难度递进，
  /// 下方 5 个等宽中性按钮；选中态使用主色（navy）实底白字，
  /// 未选中为浅灰描边 + 主文字色。
  Widget _buildDifficultySelector(AppLocalizations l10n) {
    final difficultyLabels = {
      DifficultyLevel.veryEasy: l10n.difficultyVeryEasy,
      DifficultyLevel.easy: l10n.difficultyEasy,
      DifficultyLevel.medium: l10n.difficultyMedium,
      DifficultyLevel.hard: l10n.difficultyHard,
      DifficultyLevel.veryHard: l10n.difficultyVeryHard,
    };
    // 选中时按档位使用对应渐变色，与上方指示条颜色对齐
    final difficultyColors = {
      DifficultyLevel.veryEasy: const Color(0xFF43A047),
      DifficultyLevel.easy: const Color(0xFF9CCC65),
      DifficultyLevel.medium: const Color(0xFFFFB300),
      DifficultyLevel.hard: const Color(0xFFFB8C00),
      DifficultyLevel.veryHard: const Color(0xFFE53935),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 极细渐变指示条：绿→红，提示难度从易到难
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF43A047), // 绿
                Color(0xFF9CCC65),
                Color(0xFFFFB300), // 黄
                Color(0xFFFB8C00),
                Color(0xFFE53935), // 红
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        // 5 等宽中性按钮
        Row(
          children: [
            for (var i = 0; i < DifficultyLevel.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: _DifficultyButton(
                  label: difficultyLabels[DifficultyLevel.values[i]]!,
                  selectedColor: difficultyColors[DifficultyLevel.values[i]]!,
                  selected: _selectedDifficulty == DifficultyLevel.values[i],
                  onTap: () {
                    setState(() {
                      final level = DifficultyLevel.values[i];
                      _selectedDifficulty = _selectedDifficulty == level
                          ? null
                          : level;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建底部操作按钮
  ///
  /// 三种情况：
  /// 1. 有下一步可继续：[完成 Outlined] [继续：X Filled] 同一行
  /// 2. 末步骤：[完成首次学习/复习 Filled]（全宽）
  /// 3. 非末步骤但下一步不可用：[完成 Filled]（全宽）
  List<Widget> _buildActions(BuildContext context, AppLocalizations l10n) {
    if (widget.nextStepName != null) {
      // 情况 1：有下一步可继续
      return [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: _actionsEnabled
                    ? () => widget.onResult((
                        action: StepCompleteAction.back,
                        difficulty: _selectedDifficulty,
                      ))
                    : null,
                child: Text(l10n.done),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: _actionsEnabled
                    ? () => widget.onResult((
                        action: StepCompleteAction.continueNext,
                        difficulty: _selectedDifficulty,
                      ))
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.continueToStep(widget.nextStepName!)),
                ),
              ),
            ),
          ],
        ),
      ];
    } else if (widget.isLastStep) {
      // 情况 2：末步骤
      final l10nCtx = AppLocalizations.of(context)!;
      final isFirstStudy = widget.stageName == l10nCtx.firstStudy;
      final completeText = isFirstStudy
          ? l10n.completeFirstStudy
          : l10n.completeReview;

      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _actionsEnabled
                ? () => widget.onResult((
                    action: StepCompleteAction.back,
                    difficulty: _selectedDifficulty,
                  ))
                : null,
            child: Text(completeText),
          ),
        ),
      ];
    } else {
      // 情况 3：非末步骤但下一步不可用
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _actionsEnabled
                ? () => widget.onResult((
                    action: StepCompleteAction.back,
                    difficulty: _selectedDifficulty,
                  ))
                : null,
            child: Text(l10n.done),
          ),
        ),
      ];
    }
  }
}

/// 单个难度按钮：中性配色，选中态使用对应档位颜色实底白字
class _DifficultyButton extends StatelessWidget {
  final String label;
  final Color selectedColor;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.label,
    required this.selectedColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? selectedColor : scheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? selectedColor : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
