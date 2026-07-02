/// 句内分词与词级选区（纯逻辑，供 SelectableSentenceText 使用，可独立单测）
///
/// 分词沿用标注卡既有正则 `\s+|[^\s]+`：把句子切成「空白段 / 非空白段」
/// 交替的 token 序列，并记录每个 token 在原文中的字符区间，
/// 供 RenderParagraph 的 position/box 几何查询与选区文本截取共用。
library;

/// 句内 token（带原文字符区间）
class WordToken {
  /// 在原文中的起始字符偏移（含）
  final int start;

  /// 在原文中的结束字符偏移（不含）
  final int end;

  /// 原始片段文本（词含标点，或纯空白）
  final String text;

  /// 是否为「词」：剥标点后仍含字母/数字（可作为查词单元）
  final bool isWord;

  const WordToken({
    required this.start,
    required this.end,
    required this.text,
    required this.isWord,
  });
}

/// 分词正则：空白段或非空白连续段（与标注卡既有实现一致）
final RegExp _tokenPattern = RegExp(r'\s+|[^\s]+');

/// 「词」判定：含至少一个字母或数字（纯标点段不可查词）
final RegExp _hasAlnum = RegExp(r'[A-Za-z0-9]');

/// 把句子切分为带字符偏移的 token 列表
List<WordToken> tokenizeSentence(String text) {
  return _tokenPattern
      .allMatches(text)
      .map(
        (m) => WordToken(
          start: m.start,
          end: m.end,
          text: m.group(0) ?? '',
          isWord:
              (m.group(0) ?? '').trim().isNotEmpty &&
              _hasAlnum.hasMatch(m.group(0) ?? ''),
        ),
      )
      .toList(growable: false);
}

/// 词级选区：token 索引闭区间（两端都指向 isWord 的 token）
class WordSelection {
  /// 起始 token 索引（含）
  final int startToken;

  /// 结束 token 索引（含），恒 >= [startToken]
  final int endToken;

  const WordSelection(this.startToken, this.endToken)
    : assert(startToken <= endToken);

  /// 是否单词选区
  bool get isSingleWord => startToken == endToken;

  /// 选区覆盖的原文文本（含区间内的标点与空白，边缘由 normalizeWord 清洗）
  String textOf(String text, List<WordToken> tokens) =>
      text.substring(tokens[startToken].start, tokens[endToken].end);

  /// 选区覆盖的字符区间 [start, end)
  (int, int) charRangeOf(List<WordToken> tokens) =>
      (tokens[startToken].start, tokens[endToken].end);

  @override
  bool operator ==(Object other) =>
      other is WordSelection &&
      other.startToken == startToken &&
      other.endToken == endToken;

  @override
  int get hashCode => Object.hash(startToken, endToken);
}

/// 词级吸附：字符偏移 → 最近的 word token 索引。
///
/// 命中词内直接返回该词；落在空白/标点/越界时按字符距离取最近的词。
/// 无任何 word token 时返回 -1。
int snapToWordToken(List<WordToken> tokens, int charOffset) {
  var best = -1;
  var bestDist = 1 << 30;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (!t.isWord) continue;
    if (charOffset >= t.start && charOffset < t.end) return i;
    final dist = charOffset < t.start
        ? t.start - charOffset
        : charOffset - t.end + 1;
    if (dist < bestDist) {
      bestDist = dist;
      best = i;
    }
  }
  return best;
}

/// 精确命中：字符偏移所在的 word token 索引；不在任何词内返回 -1。
///
/// 供点词判定使用（点空白/标点不触发查词，与吸附语义区分）。
int wordTokenAtChar(List<WordToken> tokens, int charOffset) {
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (charOffset >= t.start && charOffset < t.end) return t.isWord ? i : -1;
  }
  return -1;
}
