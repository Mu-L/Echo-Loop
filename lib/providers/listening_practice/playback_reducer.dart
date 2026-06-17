/// 自由练习播放器的「下一步」决策纯函数。
///
/// 把「一句/整篇播放完成后该做什么」从命令式协程中剥离为无副作用的纯函数，
/// 便于单元测试覆盖全部分支。Provider 只负责把音频引擎的完成事件喂给
/// [decideNext]，再根据返回的 [NextAction] 驱动引擎（seek / setClip / play / stop）。
///
/// 支持两组相互独立、可同时开启的循环：
/// - 整篇循环（[loopWhole]）：整篇播完后回到开头重播，总共播 [wholeLoopCount] 遍。
/// - 单句循环（[loopSentence]）：每句重复 [sentenceLoopCount] 次后进下一句。
library;

/// [decideNext] 的决策结果。
sealed class NextAction {
  const NextAction();
}

/// 重播当前句（单句循环）。[pauseBefore] 为重播前的停顿。
class ReplayCurrent extends NextAction {
  /// 执行前的间隔停顿。
  final Duration pauseBefore;

  const ReplayCurrent({this.pauseBefore = Duration.zero});
}

/// 跳到播放列表中第 [position] 条（顺次推进或回卷到开头）。
/// [pauseBefore] 为跳转前的停顿。
class GoToPosition extends NextAction {
  /// 目标在播放列表中的序号（0-based）。
  final int position;

  /// 执行前的间隔停顿。
  final Duration pauseBefore;

  const GoToPosition(this.position, {this.pauseBefore = Duration.zero});
}

/// 停止播放。
class StopPlayback extends NextAction {
  const StopPlayback();
}

/// 决定「播放完成事件」后的下一步动作。
///
/// 关键：完成事件在两种播放形态下含义不同——
/// - clip（逐句）模式：每句结束都发一次 completed；
/// - gapless（整段无缝）模式：整条拼接轨道只在末尾发一次 completed（整篇结束）。
///
/// 因此必须显式传入 [isClipMode]。入参均为业务真相源的快照，函数无副作用：
/// - [isClipMode]：true=逐句 clip（单句循环开 或 收藏模式）；false=整段无缝。
/// - [loopSentence]/[sentenceLoopCount]/[sentenceInterval]：单句循环参数
///   （[sentenceLoopCount] 为 `0` 表示无限重复当前句）。
/// - [loopWhole]/[wholeLoopCount]/[wholeInterval]：整篇循环参数
///   （[wholeLoopCount] 为 `0` 表示无限循环整篇）。
/// - [sentenceRepeatsDone]：当前句已完成播放次数（含刚结束这次，>=1）。
/// - [wholeLoopsDone]：整篇已完成遍数（本次完成事件计入前的值）。
/// - [currentPos]：当前句在播放列表中的序号（0-based）。
/// - [playableCount]：播放列表长度（全文=句子数；收藏=收藏句数）。
NextAction decideNext({
  required bool isClipMode,
  required bool loopSentence,
  required int sentenceLoopCount,
  required Duration sentenceInterval,
  required bool loopWhole,
  required int wholeLoopCount,
  required Duration wholeInterval,
  required int sentenceRepeatsDone,
  required int wholeLoopsDone,
  required int currentPos,
  required int playableCount,
}) {
  if (playableCount <= 0) return const StopPlayback();

  final isLast = currentPos >= playableCount - 1;

  // gapless：completed=整篇结束。此时单句循环必为关（开了就会进 clip 模式），
  // 只需处理整篇循环回卷。
  if (!isClipMode) {
    if (_shouldLoopWhole(loopWhole, wholeLoopCount, wholeLoopsDone)) {
      return GoToPosition(0, pauseBefore: wholeInterval);
    }
    return const StopPlayback();
  }

  // clip：completed=当前句结束。
  // 1) 先把当前句重复够（单句循环）。
  if (loopSentence &&
      (sentenceLoopCount == 0 || sentenceRepeatsDone < sentenceLoopCount)) {
    return ReplayCurrent(pauseBefore: sentenceInterval);
  }

  // 2) 当前句已重复够 → 推进。
  if (!isLast) {
    // 句间间隔：单句循环开则用其间隔；仅整篇循环（收藏逐句）时不停顿。
    final gap = loopSentence ? sentenceInterval : Duration.zero;
    return GoToPosition(currentPos + 1, pauseBefore: gap);
  }

  // 3) 到列表末尾 → 整篇循环判定。
  if (_shouldLoopWhole(loopWhole, wholeLoopCount, wholeLoopsDone)) {
    return GoToPosition(0, pauseBefore: wholeInterval);
  }
  return const StopPlayback();
}

/// 是否应继续整篇循环：开启且（无限 或 已完成遍数未达目标）。
bool _shouldLoopWhole(bool loopWhole, int wholeLoopCount, int wholeLoopsDone) {
  if (!loopWhole) return false;
  if (wholeLoopCount == 0) return true; // ∞
  return wholeLoopsDone < wholeLoopCount;
}
