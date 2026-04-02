/// 跟读会话阶段状态机
///
/// 表达跟读流程的顶层阶段，每个阶段互斥。
/// 流程：PlayingPrompt → Recording → (ReviewingRecording) → WaitingInterval → 下一遍/句
///
/// **每个阶段携带该阶段特有的数据**，编译期保证不会在错误阶段访问错误数据。
library;

/// 跟读流程阶段
sealed class ListenAndRepeatPhase {
  const ListenAndRepeatPhase();
}

/// 空闲（未开始或已停止）
class Idle extends ListenAndRepeatPhase {
  const Idle();
}

/// 播放原句中
class PlayingPrompt extends ListenAndRepeatPhase {
  const PlayingPrompt();
}

/// 录音中（用户跟读）
class Recording extends ListenAndRepeatPhase {
  /// 当前录音的 promptId
  final String promptId;

  const Recording({required this.promptId});
}

/// 播放录音回放中
class ReviewingRecording extends ListenAndRepeatPhase {
  /// 录音文件路径
  final String recordingPath;

  const ReviewingRecording({required this.recordingPath});
}

/// 遍间等待（倒计时 T 秒，唯一可以有倒计时的阶段）
class WaitingInterval extends ListenAndRepeatPhase {
  /// 倒计时剩余时间
  final Duration remaining;

  /// 倒计时总时长
  final Duration total;

  /// 是否暂停
  final bool isPaused;

  const WaitingInterval({
    required this.remaining,
    required this.total,
    this.isPaused = false,
  });

  WaitingInterval copyWith({
    Duration? remaining,
    Duration? total,
    bool? isPaused,
  }) {
    return WaitingInterval(
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// 等待用户操作
///
/// 录音失败/超时、用户点了翻译/解析/查词、打开设置弹窗等场景。
/// 不自动推进，等用户主动操作后恢复自动流程。
class WaitingForUser extends ListenAndRepeatPhase {
  /// 等待原因
  final WaitingReason reason;

  const WaitingForUser(this.reason);
}

/// 等待用户的原因
enum WaitingReason {
  /// 录音失败或超时，需要重试
  recordingFailed,

  /// 用户手动干预（查词典/翻译/设置/暂停播放等）
  userInteraction,

  /// 手动模式，等用户主动操作
  manualMode,
}

/// 当前句子所有遍数完成（短暂过渡，自动推进到下一句或完成）
class SentenceCompleted extends ListenAndRepeatPhase {
  const SentenceCompleted();
}

/// 整个会话完成（所有句子全部跟读完）
class SessionCompleted extends ListenAndRepeatPhase {
  const SessionCompleted();
}
