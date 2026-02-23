/// 全文盲听完成对话框
///
/// 播放完成后弹出，展示步骤进度、已听遍数和 5 档难度选择。
/// 无默认值，必须选择难度后才能点击操作按钮。
///
/// 按钮布局根据上下文分三种情况：
/// 1. 有下一步可继续：[返回计划] [继续：X] + [再听一遍]
/// 2. 末步骤：[再听一遍] [完成首学/复习]
/// 3. 非末步骤但下一步不可用：[再听一遍] [返回计划]
///
/// 不可通过返回键或点击外部区域关闭。
library;

import 'package:flutter/material.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 盲听完成对话框返回结果
///
/// [difficulty] 为用户选择的难度等级。
/// [continueToNext] 为 true 表示用户选择"继续下一步"，
/// false 表示"返回计划"或"完成阶段"。
typedef BlindListenResult = ({
  DifficultyLevel difficulty,
  bool continueToNext,
});

/// 显示盲听完成对话框
///
/// 返回 `null` 表示用户选择"再听一遍"，
/// 返回 [BlindListenResult] 表示用户选择难度后点击了操作按钮。
///
/// [stepIndex] 当前完成的步骤序号（0-based）。
/// [totalSteps] 当前阶段总步骤数。
/// [stageName] 当前阶段名称（如"首学"）。
/// [nextStepName] 下一步名称（null 表示下一步不可用或不存在）。
/// [isLastStep] 是否为当前阶段的最后一步。
Future<BlindListenResult?> showBlindListenCompleteDialog({
  required BuildContext context,
  required int passCount,
  required int stepIndex,
  required int totalSteps,
  required String stageName,
  String? nextStepName,
  bool isLastStep = false,
}) {
  return showDialog<BlindListenResult?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BlindListenCompleteDialog(
      passCount: passCount,
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      stageName: stageName,
      nextStepName: nextStepName,
      isLastStep: isLastStep,
    ),
  );
}

/// 盲听完成对话框
class BlindListenCompleteDialog extends StatefulWidget {
  /// 已完成的盲听遍数
  final int passCount;

  /// 当前完成的步骤序号（0-based）
  final int stepIndex;

  /// 当前阶段总步骤数
  final int totalSteps;

  /// 当前阶段名称
  final String stageName;

  /// 下一步名称（null = 下一步不可用或不存在）
  final String? nextStepName;

  /// 是否为当前阶段最后一步
  final bool isLastStep;

  const BlindListenCompleteDialog({
    super.key,
    required this.passCount,
    required this.stepIndex,
    required this.totalSteps,
    required this.stageName,
    this.nextStepName,
    this.isLastStep = false,
  });

  @override
  State<BlindListenCompleteDialog> createState() =>
      _BlindListenCompleteDialogState();
}

class _BlindListenCompleteDialogState extends State<BlindListenCompleteDialog> {
  /// 选中的难度等级（null = 未选择）
  DifficultyLevel? _selectedDifficulty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    /// 难度标签（国际化）
    final difficultyLabels = {
      DifficultyLevel.veryEasy: l10n.difficultyVeryEasy,
      DifficultyLevel.easy: l10n.difficultyEasy,
      DifficultyLevel.medium: l10n.difficultyMedium,
      DifficultyLevel.hard: l10n.difficultyHard,
      DifficultyLevel.veryHard: l10n.difficultyVeryHard,
    };

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Expanded(child: Text(l10n.blindListenComplete)),
            // 再听一遍（右上角文字按钮）
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.listenAgain),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 步骤进度
            Text(
              l10n.stepProgressLabel(
                widget.stepIndex + 1,
                widget.totalSteps,
                widget.stageName,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 已听遍数
            Text(
              l10n.blindListenPassInfo(widget.passCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 难度选择标题
            Text(
              l10n.selectDifficulty,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // 5 档难度选择
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: DifficultyLevel.values.map((level) {
                final isSelected = _selectedDifficulty == level;
                return ChoiceChip(
                  label: Text(difficultyLabels[level] ?? level.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDifficulty = selected ? level : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
        // 底部操作按钮（返回计划 + 继续 同一行）
        actions: _buildActions(l10n),
      ),
    );
  }

  /// 构建底部操作按钮
  ///
  /// 三种情况：
  /// 1. 有下一步可继续：[返回计划 Outlined] [继续：X Filled] 同一行
  /// 2. 末步骤：[完成首学/复习 Filled]（全宽）
  /// 3. 非末步骤但下一步不可用：[返回计划 Filled]（全宽）
  ///
  /// "再听一遍"按钮已移至标题栏右上角。
  /// 使用单个 Row 包裹，避免 OverflowBar 不兼容 Expanded 的问题。
  List<Widget> _buildActions(AppLocalizations l10n) {
    if (widget.nextStepName != null) {
      // 情况 1：有下一步可继续 — 返回计划（左） + 继续（右）
      return [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _selectedDifficulty != null
                    ? () => Navigator.of(context).pop(
                          (difficulty: _selectedDifficulty!, continueToNext: false),
                        )
                    : null,
                child: Text(l10n.backToPlan),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: FilledButton(
                onPressed: _selectedDifficulty != null
                    ? () => Navigator.of(context).pop(
                          (difficulty: _selectedDifficulty!, continueToNext: true),
                        )
                    : null,
                child: Text(l10n.continueToStep(widget.nextStepName!)),
              ),
            ),
          ],
        ),
      ];
    } else if (widget.isLastStep) {
      // 情况 2：末步骤 — 完成按钮全宽
      final l10nCtx = AppLocalizations.of(context)!;
      final isFirstStudy = widget.stageName == l10nCtx.firstStudy ||
          widget.stageName == LearningStage.firstLearn.label;
      final completeText = isFirstStudy
          ? l10n.completeFirstStudy
          : l10n.completeReview;

      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedDifficulty != null
                ? () => Navigator.of(context).pop(
                      (difficulty: _selectedDifficulty!, continueToNext: false),
                    )
                : null,
            child: Text(completeText),
          ),
        ),
      ];
    } else {
      // 情况 3：非末步骤但下一步不可用 — 返回计划全宽
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedDifficulty != null
                ? () => Navigator.of(context).pop(
                      (difficulty: _selectedDifficulty!, continueToNext: false),
                    )
                : null,
            child: Text(l10n.backToPlan),
          ),
        ),
      ];
    }
  }
}
