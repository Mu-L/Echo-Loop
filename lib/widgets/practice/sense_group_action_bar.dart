/// 意群快捷操作工具条
///
/// 浮动在 badge 上方，提供收藏与 AI lookup 快捷操作。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 意群快捷操作工具条
///
/// 圆角浅色背景，书签按钮在左，AI lookup 按钮在右。
class SenseGroupActionBar extends StatelessWidget {
  /// 是否已收藏
  final bool isSaved;

  /// 收藏/取消收藏回调
  final VoidCallback onToggleSave;

  /// AI 查词回调
  final VoidCallback onLookup;

  /// AI lookup 是否可点击
  final bool lookupEnabled;

  const SenseGroupActionBar({
    super.key,
    required this.isSaved,
    required this.onToggleSave,
    required this.onLookup,
    this.lookupEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF24262B) : colorScheme.surface;
    final borderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.62 : 0.72,
    );
    final fgColor = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.14),
            blurRadius: isDark ? 18 : 14,
            spreadRadius: isDark ? -1 : -2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: isDark ? const Offset(0, -1) : const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionIconButton(
              key: const Key('sense_group_save_action'),
              tooltip: isSaved ? 'Remove bookmark' : 'Save phrase',
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              color: isSaved ? Colors.amber.shade700 : fgColor,
              onTap: onToggleSave,
            ),
            Container(
              width: 1,
              height: 20,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.34 : 0.62,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            _ActionIconButton(
              key: const Key('sense_group_lookup_action'),
              tooltip: 'AI lookup',
              icon: Icons.auto_awesome,
              color: lookupEnabled ? fgColor : fgColor.withValues(alpha: 0.38),
              onTap: lookupEnabled ? onLookup : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: SizedBox(
          width: 34,
          height: 38,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}
