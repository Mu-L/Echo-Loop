/// 段落内容可见性菜单
///
/// 目前用于段落复述页面的文本可见性切换。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/retell_settings.dart';

/// 段落内容可见性菜单
class ParagraphVisibilityControls extends StatelessWidget {
  final RetellDisplayMode selectedMode;
  final ValueChanged<RetellDisplayMode> onChanged;

  const ParagraphVisibilityControls({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        return SegmentedButton<RetellDisplayMode>(
          direction: isCompact ? Axis.vertical : Axis.horizontal,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: RetellDisplayMode.hideAll,
              label: _ParagraphVisibilitySegmentLabel(
                text: _displayModeLabel(
                  context,
                  regularText: l10n.retellDisplayHideAll,
                  compactEnglishText: 'Hide',
                  isCompact: isCompact,
                ),
              ),
            ),
            ButtonSegment(
              value: RetellDisplayMode.keywordsOnly,
              label: _ParagraphVisibilitySegmentLabel(
                text: _displayModeLabel(
                  context,
                  regularText: l10n.retellDisplayKeywordsOnly,
                  compactEnglishText: 'Visible',
                  isCompact: isCompact,
                ),
              ),
            ),
            ButtonSegment(
              value: RetellDisplayMode.showAll,
              label: _ParagraphVisibilitySegmentLabel(
                text: _displayModeLabel(
                  context,
                  regularText: l10n.retellDisplayShowAll,
                  compactEnglishText: 'Show',
                  isCompact: isCompact,
                ),
              ),
            ),
          ],
          selected: {selectedMode},
          onSelectionChanged: (selected) => onChanged(selected.first),
        );
      },
    );
  }
}

String _displayModeLabel(
  BuildContext context, {
  required String regularText,
  required String compactEnglishText,
  required bool isCompact,
}) {
  if (!isCompact) return regularText;
  return Localizations.localeOf(context).languageCode == 'en'
      ? compactEnglishText
      : regularText;
}

class _ParagraphVisibilitySegmentLabel extends StatelessWidget {
  final String text;

  const _ParagraphVisibilitySegmentLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
