/// 语音完成检测器集合。
///
/// 将录音自动停止的各种检测算法拆分为独立函数，方便跟读/复述分别组合使用。
/// 每个检测器接收 [SpeechMatchContext]（LCS 匹配结果），返回 [DetectionResult]。
library;

/// LCS 匹配上下文，由调用方一次性计算后传入各检测器。
class SpeechMatchContext {
  /// 原文 token 列表（小写）
  final List<String> referenceTokens;

  /// 转录 token 列表（小写）
  final List<String> transcriptTokens;

  /// LCS 匹配对（referenceIndex, transcriptIndex）
  final List<(int, int)> lcsPairs;

  /// 匹配到的原文索引集合
  final Set<int> matchedRefIndexes;

  /// 匹配率（0-1）
  final double matchRate;

  SpeechMatchContext({
    required this.referenceTokens,
    required this.transcriptTokens,
    required this.lcsPairs,
  })  : matchedRefIndexes = lcsPairs.map((p) => p.$1).toSet(),
        matchRate = referenceTokens.isEmpty
            ? 0.0
            : lcsPairs.length / referenceTokens.length;

  /// 是否有有效匹配数据
  bool get hasMatch => lcsPairs.isNotEmpty;
}

/// 单个检测器的结果。
class DetectionResult {
  /// 建议的静音阈值（null = 该检测器未触发）
  final Duration? threshold;

  /// 人类可读的原因说明
  final String description;

  const DetectionResult({this.threshold, required this.description});

  /// 检测器是否触发（给出了阈值）
  bool get triggered => threshold != null;
}

/// 从原文和转录文本构建 [SpeechMatchContext]。
///
/// 共享的 tokenize + LCS 计算，避免各检测器重复计算。
SpeechMatchContext buildMatchContext({
  required String referenceText,
  required String partialTranscript,
}) {
  final refTokens = _tokenize(referenceText);
  final transTokens = _tokenize(partialTranscript);
  final pairs = (refTokens.isEmpty || transTokens.isEmpty)
      ? <(int, int)>[]
      : _computeLcsPairs(refTokens, transTokens);
  return SpeechMatchContext(
    referenceTokens: refTokens,
    transcriptTokens: transTokens,
    lcsPairs: pairs,
  );
}

// ========== 检测器 ==========

/// 检测 A：连续尾部匹配。
///
/// 原文末尾有 ≥1 个连续词被匹配，且该尾部子序列在原文中唯一出现。
/// 触发条件说明：用户说出了原文结尾的独特片段，大概率已读完。
DetectionResult detectTailMatch(SpeechMatchContext ctx) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'A:无匹配');
  }

  final tokens = ctx.referenceTokens;
  var consecutiveTail = 0;
  for (var i = tokens.length - 1; i >= 0; i--) {
    if (ctx.matchedRefIndexes.contains(i)) {
      consecutiveTail++;
    } else {
      break;
    }
  }

  if (consecutiveTail < 1) {
    return const DetectionResult(description: 'A:末尾未匹配');
  }

  final uniqueStart = tokens.length - consecutiveTail;
  if (!_isSubsequenceUnique(tokens, uniqueStart)) {
    return DetectionResult(
      description: 'A:尾部连续${consecutiveTail}词但非唯一',
    );
  }

  return DetectionResult(
    threshold: const Duration(seconds: 1),
    description: 'A:尾部连续${consecutiveTail}词且唯一→1s',
  );
}

/// 检测 B：全句匹配率。
///
/// 100% → 1s, ≥95% → 2s, ≥90% → 3s，低于 90% 不触发。
DetectionResult detectOverallMatchRate(SpeechMatchContext ctx) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'B:无匹配');
  }

  final pct = (ctx.matchRate * 100).toInt();
  if (ctx.matchRate >= 1.0) {
    return DetectionResult(
      threshold: const Duration(seconds: 1),
      description: 'B:匹配率${pct}%→1s',
    );
  }
  if (ctx.matchRate >= 0.95) {
    return DetectionResult(
      threshold: const Duration(seconds: 2),
      description: 'B:匹配率${pct}%→2s',
    );
  }
  if (ctx.matchRate >= 0.90) {
    return DetectionResult(
      threshold: const Duration(seconds: 3),
      description: 'B:匹配率${pct}%→3s',
    );
  }

  return DetectionResult(
    description: 'B:匹配率${pct}%<90%,未触发',
  );
}

/// 检测 C：末尾 N 词命中数。
///
/// 检查原文最后 [tailSize] 个词中有几个被匹配，命中越多阈值越短。
/// 5命中→1s, 4→2s, 3→3s, 2→4s, ≤1→5s。
DetectionResult detectTailHitCount(SpeechMatchContext ctx, {int tailSize = 5}) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'C:无匹配');
  }

  final tokens = ctx.referenceTokens;
  final effectiveTailSize = tokens.length < tailSize ? tokens.length : tailSize;
  final tailStart = tokens.length - effectiveTailSize;

  var tailMatchCount = 0;
  for (var i = tailStart; i < tokens.length; i++) {
    if (ctx.matchedRefIndexes.contains(i)) {
      tailMatchCount++;
    }
  }

  final threshold = switch (tailMatchCount) {
    <= 1 => const Duration(seconds: 5),
    2 => const Duration(seconds: 4),
    3 => const Duration(seconds: 3),
    4 => const Duration(seconds: 2),
    _ => const Duration(seconds: 1),
  };

  return DetectionResult(
    threshold: threshold,
    description: 'C:尾部${effectiveTailSize}词命中$tailMatchCount→${threshold.inSeconds}s',
  );
}

/// 组合多个检测结果，取最短阈值。
///
/// 返回 [DetectionResult]，包含最终阈值和所有检测器的汇总说明。
/// 如果没有检测器触发，返回 [fallback] 阈值。
DetectionResult combineDetections(
  List<DetectionResult> results,
  SpeechMatchContext ctx, {
  required Duration fallback,
}) {
  DetectionResult? winner;
  for (final r in results) {
    if (!r.triggered) continue;
    if (winner == null || r.threshold! < winner.threshold!) {
      winner = r;
    }
  }

  final matched = ctx.lcsPairs.length;
  final total = ctx.referenceTokens.length;
  final pct = (ctx.matchRate * 100).toInt();
  final summary = '匹配$matched/${total}词($pct%)';

  if (winner == null) {
    return DetectionResult(
      threshold: fallback,
      description: '$summary, 无规则触发→兜底${fallback.inSeconds}s',
    );
  }

  return DetectionResult(
    threshold: winner.threshold,
    description: '$summary, ${winner.description}',
  );
}

// ========== 内部工具函数 ==========

final RegExp _englishWordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

List<String> _tokenize(String text) {
  return _englishWordPattern
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0) ?? '')
      .where((token) => token.isNotEmpty)
      .toList();
}

/// 检查 [tokens] 从 [start] 到末尾的连续子序列在 [tokens] 中是否只出现一次。
bool _isSubsequenceUnique(List<String> tokens, int start) {
  final tail = tokens.sublist(start);
  final tailLength = tail.length;
  var count = 0;
  for (var i = 0; i <= tokens.length - tailLength; i++) {
    var match = true;
    for (var j = 0; j < tailLength; j++) {
      if (tokens[i + j] != tail[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      count++;
      if (count > 1) return false;
    }
  }
  return count == 1;
}

List<(int, int)> _computeLcsPairs(
  List<String> referenceTokens,
  List<String> transcriptTokens,
) {
  final rows = referenceTokens.length + 1;
  final cols = transcriptTokens.length + 1;
  final dp = List.generate(rows, (_) => List.filled(cols, 0));

  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] =
            dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  final pairs = <(int, int)>[];
  var i = referenceTokens.length;
  var j = transcriptTokens.length;
  while (i > 0 && j > 0) {
    if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
      pairs.add((i - 1, j - 1));
      i -= 1;
      j -= 1;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
      i -= 1;
    } else {
      j -= 1;
    }
  }
  return pairs.reversed.toList();
}
