/// 词典源展示辅助
///
/// 集中管理「源 id → 显示名 / 品牌色」映射，供切换器与设置页共用。
/// local/ai 名称走 l10n、色写死；网页词典名称与颜色取自各自的 [WebDictConfig]
/// （品牌名不本地化）。未知 id 回退 id 本身 / 主色。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/dictionary/web_dictionary_source.dart';

/// 网页词典 id → 配置 速查表（展示用）
final Map<String, WebDictConfig> _webConfigById = {
  for (final c in kWebDictConfigs) c.id: c,
};

/// 取词典源的显示名
String dictSourceLabel(AppLocalizations l10n, String id) => switch (id) {
  'local' => l10n.dictSourceLocal,
  'ai' => l10n.dictSourceAi,
  _ => _webConfigById[id]?.displayName ?? id,
};

/// 取词典源的品牌强调色（用于图标着色，让各源在列表中可区分）。
///
/// AI 紫与 [AiSourceButton] 一致；本地蓝；网页词典取各自配置色。未知 id 回退主色。
Color dictSourceColor(ColorScheme scheme, String id) => switch (id) {
  'local' => const Color(0xFF3B82F6), // 蓝
  'ai' => const Color(0xFFAB47BC), // 紫（同 AI 按钮）
  _ => _webConfigById[id]?.color ?? scheme.primary,
};
