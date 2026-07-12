/// App 版本更新对话框
///
/// 根据更新类型显示不同的对话框：
/// - Soft update: 可关闭，包含"稍后提醒"和"立即更新"按钮
/// - Force update: 不可关闭，无"稍后"按钮，提供"复制下载链接"逃生通道
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';

/// 当前是否已有更新弹窗在显示。
///
/// 更新弹窗有多个触发点（冷启动/回前台的 MainShell listener、设置页手动检查），
/// 用模块级标志单点守卫，避免不同触发点在已有弹窗上再叠一个。
bool _updateDialogVisible = false;

/// 测试用：复位「弹窗已显示」标志，避免模块级状态跨测试污染。
@visibleForTesting
void debugResetUpdateDialogVisible() => _updateDialogVisible = false;

/// 判断更新弹窗是否真正阻断（不可关闭）。
///
/// 仅当强制更新 **且** 有可用下载链接时才阻断。若强更但 downloadUrl 缺失
/// （清单配置异常），阻断只会得到一个点了没反应的"立即更新"按钮，把用户彻底
/// 卡死；此时退化为可关闭，作为兜底逃生。
bool _isBlocking(bool isForceUpdate, String? downloadUrl) =>
    isForceUpdate && downloadUrl != null && downloadUrl.isNotEmpty;

/// 显示版本更新对话框
///
/// [isForceUpdate] 标识是否为强制更新；实际是否不可关闭还取决于是否有可用
/// 下载链接（见 [_isBlocking]）。
/// [onDismiss] 在可关闭时用户点击"稍后"触发。
/// [downloadUrl] 当前平台的下载链接。
Future<void> showAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  required bool isForceUpdate,
  required String? downloadUrl,
  Future<void> Function()? onUpdate,
  VoidCallback? onDismiss,
}) {
  // 已有更新弹窗时忽略重复请求，防止叠加。
  if (_updateDialogVisible) return Future<void>.value();
  _updateDialogVisible = true;

  final blocking = _isBlocking(isForceUpdate, downloadUrl);
  return showDialog(
    context: context,
    barrierDismissible: !blocking,
    builder: (context) => PopScope(
      canPop: !blocking,
      child: _AppUpdateDialogContent(
        info: info,
        isForceUpdate: isForceUpdate,
        downloadUrl: downloadUrl,
        onUpdate: onUpdate,
        onDismiss: onDismiss,
      ),
    ),
  ).whenComplete(() => _updateDialogVisible = false);
}

class _AppUpdateDialogContent extends StatelessWidget {
  final AppUpdateInfo info;
  final bool isForceUpdate;
  final String? downloadUrl;
  final Future<void> Function()? onUpdate;
  final VoidCallback? onDismiss;

  const _AppUpdateDialogContent({
    required this.info,
    required this.isForceUpdate,
    required this.downloadUrl,
    this.onUpdate,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    // 是否真正阻断（不可关闭）：与 showAppUpdateDialog 同一公式。
    // 强更但无下载链接时退化为可关闭，给出"稍后"退出按钮。
    final blocking = _isBlocking(isForceUpdate, downloadUrl);

    // 标题
    final title = isForceUpdate
        ? l10n.forceUpdateTitle
        : l10n.updateAvailable(info.latestVersion);

    // 正文：release notes（更新内容）。强制更新时在其上方额外加一段不可用提示。
    final releaseNotes =
        info.releaseNotes[locale] ?? info.releaseNotes['en'] ?? '';

    return AlertDialog(
      title: Text(title),
      // 强制更新时正文偏长，限制宽度并允许滚动，避免内容被裁切
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 强制更新提示：当前版本不可用（次要文字色，弱化于标题与更新内容）
              if (isForceUpdate)
                Text(
                  l10n.forceUpdateMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              // 更新内容（what's new），强制 / 软更新都展示
              if (releaseNotes.isNotEmpty) ...[
                if (isForceUpdate) const SizedBox(height: 16),
                _ReleaseNotesCard(
                  title: l10n.releaseNotesTitle,
                  notes: releaseNotes,
                ),
              ],
              // 强制更新逃生通道：复制下载链接
              if (isForceUpdate && downloadUrl != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _copyLink(context, l10n),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(l10n.copyDownloadLink),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // 可关闭时（软更新，或强更但无可用下载链接的兜底）：稍后提醒
        if (!blocking)
          TextButton(
            onPressed: () {
              onDismiss?.call();
              Navigator.of(context).pop();
            },
            child: Text(l10n.updateLater),
          ),
        // 立即更新
        FilledButton(
          onPressed: () async => _launchUpdate(context),
          child: Text(l10n.updateNow),
        ),
      ],
    );
  }

  Future<void> _launchUpdate(BuildContext context) async {
    if (onUpdate != null) {
      await onUpdate!();
    } else if (downloadUrl != null) {
      // 无 handler / 非法 URL 时 launchUrl 会抛异常，吞掉避免未捕获异步错误
      // （对齐 AppUpdateLauncher._tryLaunch 的语义）。
      try {
        await launchUrl(
          Uri.parse(downloadUrl!),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        // 打开失败静默处理，用户仍可用"复制下载链接"逃生
      }
    }
    // soft update 时关闭对话框
    if (!isForceUpdate && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _copyLink(BuildContext context, AppLocalizations l10n) {
    if (downloadUrl == null) return;
    Clipboard.setData(ClipboardData(text: downloadUrl!));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
  }
}

/// 更新内容卡片：浅色圆角容器，顶部标题 + 下方逐行列表，
/// 让 release notes 在视觉上自成一组，与上方的强制更新提示区分。
class _ReleaseNotesCard extends StatelessWidget {
  final String title;
  final String notes;

  const _ReleaseNotesCard({required this.title, required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ReleaseNotesText(text: notes),
        ],
      ),
    );
  }
}

/// 简易 release notes 渲染：按行拆分，`- ` / `* ` 开头的行渲染为带圆点的列表项
class _ReleaseNotesText extends StatelessWidget {
  final String text;

  const _ReleaseNotesText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) _buildLine(lines[i], i, context),
      ],
    );
  }

  Widget _buildLine(String raw, int index, BuildContext context) {
    final line = raw.trimRight();
    final padTop = index == 0 ? 0.0 : 4.0;
    final trimmed = line.trimLeft();
    final isBullet = trimmed.startsWith('- ') || trimmed.startsWith('* ');

    if (isBullet) {
      final dotColor =
          DefaultTextStyle.of(context).style.color ??
          Theme.of(context).colorScheme.onSurface;
      return Padding(
        padding: EdgeInsets.only(top: padTop),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8, top: 7),
              child: SizedBox(
                width: 4,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Expanded(child: Text(trimmed.substring(2))),
          ],
        ),
      );
    }

    if (line.isEmpty) {
      return const SizedBox(height: 4);
    }

    return Padding(
      padding: EdgeInsets.only(top: padTop),
      child: Text(line),
    );
  }
}
