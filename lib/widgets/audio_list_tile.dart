// 音频列表项组件
//
// 独立 ConsumerWidget，精确订阅各 provider，
// 样式与合集详情页中的音频列表项保持一致。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../utils/transcript_picker.dart';

/// 音频列表项 — 用于资源库音频视图
class AudioListTile extends ConsumerWidget {
  /// 音频项数据
  final AudioItem audioItem;

  /// 管理合集回调
  final VoidCallback? onManageCollections;

  /// 删除音频回调
  final VoidCallback? onDelete;

  const AudioListTile({
    super.key,
    required this.audioItem,
    this.onManageCollections,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 精确订阅学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id],
      ),
    );

    // 精确订阅所属合集
    final collectionIds = ref.watch(
      collectionListProvider.select(
        (s) => s.audioToCollectionsMap[audioItem.id],
      ),
    );

    // 获取合集名称
    final collectionState = ref.watch(collectionListProvider);
    final collectionNames = <String>[];
    if (collectionIds != null) {
      for (final cId in collectionIds) {
        final c = collectionState.rawCollections
            .where((c) => c.id == cId)
            .firstOrNull;
        if (c != null) collectionNames.add(c.name);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: Icon(Icons.audiotrack, color: theme.colorScheme.primary),
        ),
        title: Text(
          audioItem.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        // 使用 Wrap 避免内容溢出
        subtitle: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 音频时长
            if (audioItem.totalDuration > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatDuration(audioItem.totalDuration),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            // 字幕图标 + 文字
            if (audioItem.hasTranscript)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.subtitles,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.transcript,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            // 添加时间
            Text(
              l10n.addedOn(_formatDate(audioItem.addedDate)),
              style: theme.textTheme.bodySmall,
            ),
            // 学习进度 badge
            if (progress != null && progress.isStarted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: progress.isCompleted
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  progress.isCompleted
                      ? l10n.learningCompleted
                      : progress.currentStage.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: progress.isCompleted
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onPrimaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
            // 合集标签 chips
            ...collectionNames.map(
              (name) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.renameAudio),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'transcript',
              child: Row(
                children: [
                  const Icon(Icons.subtitles_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.uploadTranscript),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'manage',
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.manageCollections),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(l10n.delete),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'rename') {
              _showRenameDialog(context, ref);
            } else if (value == 'transcript') {
              uploadTranscriptForAudio(context, ref, audioItem);
            } else if (value == 'manage') {
              onManageCollections?.call();
            } else if (value == 'delete') {
              onDelete?.call();
            }
          },
        ),
        onTap: () {
          context.push(AppRoutes.audioLearningPlan(audioItem.id));
        },
      ),
    );
  }

  /// 格式化添加日期为 M/d/yyyy（与合集详情页一致）
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// 格式化音频时长（秒 → mm:ss 或 h:mm:ss）
  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 重命名音频对话框
  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: audioItem.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameAudio),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.audioName),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              ref
                  .read(audioLibraryProvider.notifier)
                  .updateAudioItem(audioItem.copyWith(name: name));
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(audioLibraryProvider.notifier)
                    .updateAudioItem(audioItem.copyWith(name: name));
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}
