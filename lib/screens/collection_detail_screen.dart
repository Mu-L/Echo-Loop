import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';
import '../models/audio_item.dart';
import '../models/collection.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/transcript_picker.dart';
import '../widgets/add_audio_dialog.dart';

/// 合集详情页面 - 展示合集中的音频，支持上传音频
class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    ref.watch(audioLibraryProvider); // watch to rebuild when library changes

    final collection = collectionState.rawCollections
        .where((c) => c.id == collectionId)
        .firstOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Collection not found')),
      );
    }

    // 获取合集中的音频项（从 junction 表缓存中读取）
    final audioIds = collectionState.getAudioIds(collectionId);
    final audioItems = audioIds
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addAudioToCollection,
            onPressed: () => _showAddAudioDialog(context, collection),
          ),
        ],
      ),
      body: audioItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    l10n.emptyCollection,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    l10n.tapToAddAudio,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton.icon(
                    onPressed: () => _showAddAudioDialog(context, collection),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addAudioToCollection),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: audioItems.length,
              itemBuilder: (context, index) {
                final item = audioItems[index];
                return _CollectionAudioTile(
                  audioItem: item,
                  collectionId: collectionId,
                );
              },
            ),
    );
  }

  /// 显示添加音频对话框
  void _showAddAudioDialog(BuildContext context, Collection collection) {
    showDialog(
      context: context,
      builder: (context) => AddAudioDialog(collectionId: collection.id),
    );
  }
}

/// 合集中的音频列表项
class _CollectionAudioTile extends ConsumerWidget {
  final AudioItem audioItem;
  final String collectionId;

  const _CollectionAudioTile({
    required this.audioItem,
    required this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentAudioItem = ref.watch(
      listeningPracticeProvider.select((s) => s.currentAudioItem),
    );
    final isCurrentlyPlaying = currentAudioItem?.id == audioItem.id;

    // 监听学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[audioItem.id],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isCurrentlyPlaying
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: Icon(
            Icons.audiotrack,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          audioItem.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            // 音频时长
            if (audioItem.totalDuration > 0) ...[
              Icon(
                Icons.schedule,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                _formatDuration(audioItem.totalDuration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
            ],
            if (audioItem.hasTranscript) ...[
              Icon(
                Icons.subtitles,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.transcript,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              l10n.addedOn(_formatDate(audioItem.addedDate)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (progress != null && progress.isStarted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: progress.isCompleted
                      ? Theme.of(context).colorScheme.tertiaryContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  progress.isCompleted
                      ? l10n.learningCompleted
                      : progress.currentStage.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: progress.isCompleted
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentlyPlaying)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.playing,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton(
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
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.delete),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameAudioDialog(context, ref);
                } else if (value == 'transcript') {
                  uploadTranscriptForAudio(context, ref, audioItem);
                } else if (value == 'delete') {
                  _confirmRemove(context, ref);
                }
              },
            ),
          ],
        ),
        onTap: () async {
          // 验证音频文件是否存在
          final fullAudioPath = await audioItem.getFullAudioPath();
          final audioFile = File(fullAudioPath);
          if (!await audioFile.exists()) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.audioFileNotFound),
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
          if (!context.mounted) return;
          context.push(AppRoutes.learningPlan(collectionId, audioItem.id));
        },
      ),
    );
  }

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
  void _showRenameAudioDialog(BuildContext context, WidgetRef ref) {
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

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 32),
        title: Text(l10n.removeFromCollection),
        content: Text(l10n.removeFromCollectionConfirm(audioItem.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(collectionListProvider.notifier)
                  .removeAudioFromCollection(collectionId, audioItem.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

