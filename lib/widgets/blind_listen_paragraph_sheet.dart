/// 盲听段落选择底部弹窗
///
/// 复用 [showParagraphSelectionSheet] 通用组件，
/// 增加段间停顿倍数选项。
library;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/sentence.dart';
import 'common/paragraph_selection_sheet.dart';

/// 显示盲听段落选择弹窗
///
/// [stageLabel] 可选的阶段名（如"第三轮复习"），显示在标题下方
/// [estimatedDurationText] 可选的预估时长文本，显示在说明下方
Future<void> showBlindListenParagraphSheet({
  required BuildContext context,
  required List<Sentence> sentences,
  String? stageLabel,
  String? estimatedDurationText,
  double defaultPlaybackSpeed = 1.0,
  required void Function(
    Duration targetDuration,
    double pauseMultiplier,
    double playbackSpeed,
  )
  onStartPractice,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showParagraphSelectionSheet(
    context: context,
    icon: Icons.headphones,
    title: l10n.blindListenBriefingTitle,
    subtitle: l10n.blindListenBriefingTip,
    sentences: sentences,
    defaultSeconds: -1,
    showPauseMultiplier: true,
    showPlaybackSpeed: true,
    defaultPlaybackSpeed: defaultPlaybackSpeed,
    pauseMultiplierOptions: const [0.5, 1.0, 1.5, 2.0, 3.0],
    stageLabel: stageLabel,
    estimatedDurationText: estimatedDurationText,
    // 盲听不显示可见词比例（仅复述用），第三个回调参数忽略
    onStartPractice: (_, _, _) {},
    onStartPracticeWithPlaybackSpeed: (duration, multiplier, _, speed) =>
        onStartPractice(duration, multiplier, speed),
  );
}
