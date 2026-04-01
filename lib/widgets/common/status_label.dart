/// 状态标签（共享组件）
///
/// 固定高度的单行文字标签，用于显示录音状态、错误提示等。
/// 高度固定 24px，防止内容出现/消失时布局跳动。
library;

import 'package:flutter/material.dart';

/// 状态标签
///
/// 纯展示组件，显示一行状态文字。[text] 为 null 时占位不显示。
class StatusLabel extends StatelessWidget {
  /// 状态文字（null 则不显示，但保留占位高度）
  final String? text;

  /// 文字颜色（null 则使用 onSurfaceVariant）
  final Color? color;

  /// 是否加粗（如错误提示）
  final bool bold;

  const StatusLabel({super.key, this.text, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 24,
      child: text != null
          ? Text(
              text!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w500 : null,
              ),
            )
          : null,
    );
  }
}
