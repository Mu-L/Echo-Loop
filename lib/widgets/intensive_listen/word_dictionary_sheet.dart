/// 词典查询底部弹窗
///
/// 点击单词时弹出，显示音标、释义、柯林斯星级和考试标签。
/// 未查到结果时显示"未收录"提示。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dict_entry.dart';
import '../../services/dictionary_service.dart';
import '../../theme/app_theme.dart';

/// 显示词典底部弹窗
Future<void> showWordDictionarySheet({
  required BuildContext context,
  required String word,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => WordDictionarySheet(word: word),
  );
}

/// 词典弹窗内容
class WordDictionarySheet extends StatefulWidget {
  /// 查询的单词
  final String word;

  const WordDictionarySheet({super.key, required this.word});

  @override
  State<WordDictionarySheet> createState() => _WordDictionarySheetState();
}

class _WordDictionarySheetState extends State<WordDictionarySheet> {
  DictEntry? _entry;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    final entry = await DictionaryService.instance.lookup(widget.word);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _notFound = entry == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          12,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            else if (_notFound)
              _buildNotFound(theme)
            else
              _buildContent(theme, _entry!),
          ],
        ),
      ),
    );
  }

  /// 未找到结果
  Widget _buildNotFound(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词
          Text(
            widget.word,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // 未收录提示
          Text(
            AppLocalizations.of(context)!.intensiveListenWordDictNotFound,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 词典内容
  Widget _buildContent(ThemeData theme, DictEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 单词
        Text(
          entry.word,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        // 音标 + 星级 + 考试标签（紧凑一行）
        _buildMetaLine(theme, entry),
        const SizedBox(height: AppSpacing.m),

        // 释义
        if (entry.translation != null && entry.translation!.isNotEmpty)
          _buildTranslation(theme, entry.translation!),

        const SizedBox(height: AppSpacing.s),
      ],
    );
  }

  /// 音标、星级、考试标签合并为一行
  Widget _buildMetaLine(ThemeData theme, DictEntry entry) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 音标
        if (entry.phonetic.isNotEmpty)
          Text(
            '/${entry.phonetic}/',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),

        // 柯林斯星级
        if (entry.collins > 0) _buildStars(theme, entry.collins),

        // 考试标签
        if (entry.examTags.isNotEmpty) _buildExamTags(theme, entry.examTags),
      ],
    );
  }

  /// 柯林斯五星评级
  Widget _buildStars(ThemeData theme, int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isFilled = i < rating;
        return Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Icon(
            isFilled ? Icons.star_rounded : Icons.star_rounded,
            size: 14,
            color: isFilled
                ? Colors.amber.shade600
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        );
      }),
    );
  }

  /// 考试标签组
  Widget _buildExamTags(ThemeData theme, List<String> tags) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tags.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '·',
                style: TextStyle(
                  color: theme.colorScheme.outlineVariant,
                  fontSize: 10,
                ),
              ),
            ),
          Text(
            tags[i],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }

  /// 释义内容 — 解析词性前缀，区分显示
  Widget _buildTranslation(ThemeData theme, String translation) {
    final lines = translation.split('\n').where((l) => l.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildDefinitionLine(theme, line.trim()),
          ),
      ],
    );
  }

  /// 单条释义行 — 词性标签 + 释义文本
  ///
  /// 识别 "vt." "n." "a." "adv." 等词性前缀，
  /// 以蓝色小标签显示词性，后接释义正文。
  Widget _buildDefinitionLine(ThemeData theme, String line) {
    final posMatch = RegExp(r'^([a-z]+\.(?:\s*&\s*[a-z]+\.)*)\s*').firstMatch(line);

    if (posMatch == null) {
      // 无词性前缀，直接显示
      return Text(
        line,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
      );
    }

    final pos = posMatch.group(1)!;
    final definition = line.substring(posMatch.end);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 词性标签
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pos,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 释义文本
        Expanded(
          child: Text(
            definition,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
