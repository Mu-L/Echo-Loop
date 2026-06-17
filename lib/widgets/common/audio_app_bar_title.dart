import 'package:flutter/material.dart';

/// 音频类页面通用的 AppBar 标题：音频名 + 所属合集副标题。
///
/// 没有所属合集时只显示音频名。多合集用「、」拼接。
/// 学习计划页与全能播放器共用，保证字体、间距、图标完全一致。
class AudioAppBarTitle extends StatelessWidget {
  /// 主标题（音频名）。
  final String audioName;

  /// 副标题展示的合集名列表；为空则不显示副标题。
  final List<String> collectionNames;

  const AudioAppBarTitle({
    super.key,
    required this.audioName,
    required this.collectionNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (collectionNames.isEmpty) {
      return Text(audioName);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          audioName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                collectionNames.join('、'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
