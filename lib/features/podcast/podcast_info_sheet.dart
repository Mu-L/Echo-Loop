/// Podcast 信息只读展示弹窗
///
/// - [showPodcastFeedInfoSheet]：合集级详情（标题/简介/图片/Apple 链接/link/RSS）
/// - [showPodcastEpisodeInfoSheet]：音频级详情（标题/简介/网页 link/音频下载链接）
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/collection.dart';
import '../../theme/app_theme.dart';
import 'podcast_models.dart';

/// 展示 podcast 合集的详情（只读）。
void showPodcastFeedInfoSheet(
  BuildContext context,
  Collection collection, {
  String? refreshStatusText,
}) {
  final l10n = AppLocalizations.of(context)!;
  final meta = _decodeMeta(collection.podcastMetaJson);
  final title = meta?.title ?? collection.name;
  final description = meta?.description ?? collection.description;
  final imageUrl = meta?.imageUrl ?? collection.coverUrl;
  final lastRefreshed = collection.podcastLastRefreshedAt;

  showPodcastInfoSheet(
    context,
    title: l10n.podcastDetails,
    heroTitle: title,
    heroAuthor: meta?.author,
    heroDescription: description,
    imageUrl: imageUrl,
    dateText: refreshStatusText != null || lastRefreshed == null
        ? null
        : l10n.podcastLastRefreshed(_formatDateTime(lastRefreshed)),
    refreshStatusText: refreshStatusText,
    links: [
      // 合集级详情只把 Apple Podcasts 原始输入展示为主链接；RSS 订阅输入
      // 统一展示在 RSS 链接行，避免同一个 feed 被重复标成普通链接。
      if (_isApplePodcastUrl(collection.podcastInputUrl))
        PodcastInfoLink(l10n.podcastAppleLink, collection.podcastInputUrl!),
      if (_hasText(collection.podcastFeedUrl))
        PodcastInfoLink(l10n.podcastFeedUrl, collection.podcastFeedUrl!),
    ],
  );
}

/// 生成 Podcast 合集刷新状态文案，供合集详情页和合集列表菜单共用。
String? podcastRefreshStatusText(
  AppLocalizations l10n,
  Collection collection, {
  DateTime? refreshingAt,
}) {
  final isZh = l10n.localeName.startsWith('zh');
  if (refreshingAt != null) {
    final time = _formatDateTime(refreshingAt);
    return isZh ? '刷新中 · $time' : 'Refreshing · $time';
  }

  final refreshedAt = collection.podcastLastRefreshedAt;
  if (refreshedAt == null) return null;
  if (!podcastHasRefreshError(collection)) return null;
  final time = _formatDateTime(refreshedAt);
  return isZh ? '失败 · $time' : 'Failed · $time';
}

/// Podcast 合集是否存在最近一次刷新错误。
bool podcastHasRefreshError(Collection collection) {
  return collection.podcastLastRefreshError?.trim().isNotEmpty == true;
}

/// Podcast 合集列表上的刷新失败短标记。
String podcastRefreshFailedLabel(AppLocalizations l10n) {
  return l10n.localeName.startsWith('zh') ? '刷新失败' : 'Refresh failed';
}

/// 展示通用 Podcast 信息弹窗。
///
/// 发现页精选播客预览和本地已订阅 Podcast 合集共用同一套详情布局，
/// 避免同一类内容在不同入口呈现不一致。
void showPodcastInfoSheet(
  BuildContext context, {
  required String title,
  required String heroTitle,
  required List<PodcastInfoLink> links,
  String? heroAuthor,
  String? heroDescription,
  String? imageUrl,
  String? dateText,
  String? refreshStatusText,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: title,
      heroTitle: heroTitle,
      heroAuthor: heroAuthor,
      heroDescription: heroDescription,
      imageUrl: imageUrl,
      dateText: dateText,
      refreshStatusText: refreshStatusText,
      links: links,
    ),
  );
}

/// 展示 podcast episode 的详情（只读）。
void showPodcastEpisodeInfoSheet(BuildContext context, AudioItem item) {
  final l10n = AppLocalizations.of(context)!;
  final episodeLink = _episodeLink(item);
  // meta 行：发布日期 · 时长，二者都可能缺省。
  final metaParts = <String>[
    if (item.originalDate != null)
      l10n.publishedOn(_formatDate(item.originalDate!)),
    if (item.totalDuration > 0)
      l10n.audioDuration(_formatDuration(item.totalDuration)),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: l10n.podcastEpisodeMeta,
      heroTitle: item.name,
      heroDescription: item.podcastDescription,
      dateText: metaParts.isEmpty ? null : metaParts.join(' · '),
      // 单集封面优先用 episode 自带图，缺省时 _PodcastArtwork 会显示占位图标。
      imageUrl: item.podcastImageUrl,
      links: [
        if (_hasText(episodeLink))
          PodcastInfoLink(l10n.podcastOriginalLink, episodeLink!),
        if (_hasText(item.podcastEnclosureUrl))
          PodcastInfoLink(l10n.podcastEnclosureUrl, item.podcastEnclosureUrl!),
      ],
    ),
  );
}

/// 展示预览态 podcast 单集（[PodcastEpisode]）的详情（只读）。
///
/// 与已入库的 [showPodcastEpisodeInfoSheet] 布局一致，但数据来自 RSS 预览而非
/// 本地 [AudioItem]，用于订阅前在预览页查看单集标题/摘要/发布时间/下载链接。
/// [podcastImageUrl] 作为单集无自带封面时的兜底头图。
void showPodcastPreviewEpisodeSheet(
  BuildContext context,
  PodcastEpisode episode, {
  String? podcastImageUrl,
}) {
  final l10n = AppLocalizations.of(context)!;
  final metaParts = <String>[
    if (episode.pubDate != null)
      l10n.publishedOn(_formatDate(episode.pubDate!)),
    if (episode.durationSeconds != null && episode.durationSeconds! > 0)
      l10n.audioDuration(_formatDuration(episode.durationSeconds!)),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: l10n.podcastEpisodeMeta,
      heroTitle: episode.title,
      heroDescription: episode.description,
      dateText: metaParts.isEmpty ? null : metaParts.join(' · '),
      imageUrl: _hasText(episode.imageUrl) ? episode.imageUrl : podcastImageUrl,
      links: [
        if (_hasText(episode.link))
          PodcastInfoLink(l10n.podcastOriginalLink, episode.link!),
        if (_hasText(episode.enclosureUrl))
          PodcastInfoLink(l10n.podcastEnclosureUrl, episode.enclosureUrl),
      ],
    ),
  );
}

PodcastFeedMeta? _decodeMeta(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return PodcastFeedMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _episodeLink(AudioItem item) {
  if (_hasText(item.podcastLink)) return item.podcastLink;
  final guid = item.podcastEpisodeGuid;
  if (!_hasText(guid)) return null;
  final uri = Uri.tryParse(guid!);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  return switch (uri.scheme) {
    'http' || 'https' => guid,
    _ => null,
  };
}

bool _isApplePodcastUrl(String? value) {
  if (!_hasText(value)) return false;
  final url = value!;
  final uri = Uri.tryParse(url);
  final host = uri?.host.toLowerCase();
  return host == 'podcasts.apple.com' || host == 'itunes.apple.com';
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

/// 日期 + 时分（yyyy-MM-dd HH:mm），用于「上次刷新」展示。
String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// 时长（秒 → mm:ss 或 h:mm:ss）。
String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

class PodcastInfoLink {
  final String label;
  final String url;

  const PodcastInfoLink(this.label, this.url);
}

/// 匹配正文中的 http/https 链接（到空白为止）。
final _urlPattern = RegExp(r'https?://[^\s]+');

/// 用外部浏览器打开链接，失败时提示。
Future<void> _openExternalUrl(BuildContext context, String value) async {
  final l10n = AppLocalizations.of(context)!;
  final uri = Uri.tryParse(value);
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.podcastOpenLinkFailed)));
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.podcastOpenLinkFailed)));
  }
}

/// 可选中的正文文本，其中的 http/https 链接渲染为可点击（点击外部打开）。
///
/// 末尾常见标点（`.,;:!?)]}` 与全角句读）不并入链接，避免把句号带进 URL。
class _LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _LinkifiedText({required this.text, this.style});

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style;
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: widget.text.substring(index, match.start)));
      }
      var url = match.group(0)!;
      var trailing = '';
      // 把结尾标点从链接里剥出来，避免污染目标 URL。
      while (url.isNotEmpty && '.,;:!?)]}）】。，、'.contains(url[url.length - 1])) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }
      final target = url;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openExternalUrl(context, target);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: url, style: linkStyle, recognizer: recognizer));
      if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      index = match.end;
    }
    if (index < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(index)));
    }

    return SelectableText.rich(TextSpan(style: baseStyle, children: spans));
  }
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final String heroTitle;
  final String? heroAuthor;
  final String? heroDescription;
  final String? imageUrl;
  final String? dateText;
  final String? refreshStatusText;
  final List<PodcastInfoLink> links;

  const _InfoSheet({
    required this.title,
    required this.heroTitle,
    required this.links,
    this.heroAuthor,
    this.heroDescription,
    this.imageUrl,
    this.dateText,
    this.refreshStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.xl + bottom,
            ),
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.l),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.l),
              _InfoHero(
                title: heroTitle,
                author: heroAuthor,
                description: heroDescription,
                imageUrl: imageUrl,
                dateText: dateText,
                refreshStatusText: refreshStatusText,
              ),
              if (links.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.l),
                for (final link in links) _LinkRow(link: link),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoHero extends StatelessWidget {
  final String title;
  final String? author;
  final String? description;
  final String? imageUrl;
  final String? dateText;
  final String? refreshStatusText;

  const _InfoHero({
    required this.title,
    this.author,
    this.description,
    this.imageUrl,
    this.dateText,
    this.refreshStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 封面只与标题/作者/日期并排；简介移到整行下方占满宽度，
    // 避免文字比封面高时封面下方左侧出现大片空白。
    final headColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(title, style: theme.textTheme.titleLarge),
        if (_hasText(author)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            author!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasText(dateText)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasText(refreshStatusText)) ...[
          const SizedBox(height: AppSpacing.xs),
          _RefreshStatusLine(text: refreshStatusText!),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PodcastArtwork(imageUrl: imageUrl, size: 88),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: headColumn),
          ],
        ),
        if (_hasText(description)) ...[
          const SizedBox(height: AppSpacing.m),
          _LinkifiedText(
            text: description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _RefreshStatusLine extends StatelessWidget {
  final String text;

  const _RefreshStatusLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = text.contains('失败') || text.contains('Failed')
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PodcastArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _PodcastArtwork({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.podcasts_rounded,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: !_hasText(imageUrl)
            ? placeholder
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final PodcastInfoLink link;

  const _LinkRow({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 主点击打开链接；桌面右键（onSecondaryTapDown）/ 移动端长按
    // （onLongPressStart）在指针处弹出「复制」菜单，不常驻复制图标。
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: GestureDetector(
        onSecondaryTapDown: (d) => _showCopyMenu(context, d.globalPosition),
        onLongPressStart: (d) => _showCopyMenu(context, d.globalPosition),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openExternalUrl(context, link.url),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 在 [position]（全局坐标）弹出仅含「复制」的上下文菜单。
  Future<void> _showCopyMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.copy_rounded, size: 18),
              const SizedBox(width: AppSpacing.s),
              Text(l10n.copy),
            ],
          ),
        ),
      ],
    );
    if (selected == 'copy' && context.mounted) {
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
    }
  }
}
