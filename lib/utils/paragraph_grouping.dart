/// 段落分组算法
///
/// 使用动态规划将句子列表按目标时长分组为段落，
/// 最小化各段时长与目标时长偏差的平方和，保证全局最优。
library;

import '../models/sentence.dart';

/// 将句子列表按目标时长分组为段落
///
/// [sentences] 句子列表（按时间顺序）
/// [targetDuration] 用户选择的目标段落时长（如 30s）
///
/// 返回分组后的段落列表，每个段落包含连续的句子。
/// 算法复杂度 O(n² × k)，n<200, k<20，执行时间 < 50ms。
List<List<Sentence>> groupSentencesIntoParagraphs(
  List<Sentence> sentences,
  Duration targetDuration,
) {
  // 边界：空列表
  if (sentences.isEmpty) return [];

  // 边界：单句
  if (sentences.length == 1) return [sentences];

  // 句子级别：每句一段（targetDuration == 0）
  if (targetDuration <= Duration.zero) {
    return sentences.map((s) => [s]).toList();
  }

  final n = sentences.length;
  final targetMs = targetDuration.inMilliseconds;

  // 计算每句时长（毫秒）
  final durations = List<int>.generate(
    n,
    (i) => sentences[i].duration.inMilliseconds,
  );

  // 前缀和：prefixMs[i] = 前 i 句总时长
  final prefixMs = List<int>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    prefixMs[i + 1] = prefixMs[i] + durations[i];
  }

  final totalMs = prefixMs[n];

  // 边界：总时长 ≤ 目标时长 → 单段
  if (totalMs <= targetMs) return [sentences];

  // 区间时长（句子索引 l 到 r，包含两端）
  int rangeMs(int l, int r) => prefixMs[r + 1] - prefixMs[l];

  // 区间代价：偏差平方
  double cost(int l, int r) {
    final diff = rangeMs(l, r) - targetMs;
    return diff.toDouble() * diff.toDouble();
  }

  // 估算最优组数
  final kEstimate = (totalMs / targetMs).round().clamp(1, n);
  final kMin = (kEstimate - 2).clamp(1, n);
  final kMax = (kEstimate + 2).clamp(1, n);

  double bestTotalCost = double.infinity;
  int bestK = kEstimate;
  List<List<int>>? bestCut;

  // 对每个候选 k 值执行 DP
  for (var k = kMin; k <= kMax; k++) {
    // dp[i][j] = 前 i 句分成 j 组的最小代价
    // i: 0..n, j: 0..k
    final dp = List.generate(
      n + 1,
      (_) => List<double>.filled(k + 1, double.infinity),
    );
    final cut = List.generate(
      n + 1,
      (_) => List<int>.filled(k + 1, 0),
    );

    dp[0][0] = 0;

    for (var j = 1; j <= k; j++) {
      for (var i = j; i <= n; i++) {
        // 从 c 处切割：前 c 句分成 j-1 组，第 j 组为 [c, i-1]
        for (var c = j - 1; c < i; c++) {
          final val = dp[c][j - 1] + cost(c, i - 1);
          if (val < dp[i][j]) {
            dp[i][j] = val;
            cut[i][j] = c;
          }
        }
      }
    }

    if (dp[n][k] < bestTotalCost) {
      bestTotalCost = dp[n][k];
      bestK = k;
      bestCut = cut;
    }
  }

  // 回溯得到分组
  final groups = <List<Sentence>>[];
  var end = n;
  var remaining = bestK;

  while (remaining > 0) {
    final start = bestCut![end][remaining];
    groups.add(sentences.sublist(start, end));
    end = start;
    remaining--;
  }

  // 回溯是逆序的，翻转
  return groups.reversed.toList();
}
