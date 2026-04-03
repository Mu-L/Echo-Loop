/// 盲听练习流程阶段状态机
///
/// 表达盲听模式下的顶层阶段，每个阶段互斥。
library;

/// 盲听流程阶段
sealed class BlindPracticeFlowPhase {
  const BlindPracticeFlowPhase();
}

/// 空闲（未开始或已停止）
class BlindIdle extends BlindPracticeFlowPhase {
  const BlindIdle();
}

/// 播放原句中
class BlindPlayingPrompt extends BlindPracticeFlowPhase {
  const BlindPlayingPrompt();
}

/// 倒计时等待
class BlindWaitingInterval extends BlindPracticeFlowPhase {
  /// 倒计时剩余时间
  final Duration remaining;

  /// 倒计时总时长
  final Duration total;

  /// 是否暂停
  final bool isPaused;

  /// 是否为句间停顿
  final bool isBetweenSentences;

  const BlindWaitingInterval({
    required this.remaining,
    required this.total,
    required this.isBetweenSentences,
    this.isPaused = false,
  });

  BlindWaitingInterval copyWith({
    Duration? remaining,
    Duration? total,
    bool? isPaused,
    bool? isBetweenSentences,
  }) {
    return BlindWaitingInterval(
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      isPaused: isPaused ?? this.isPaused,
      isBetweenSentences: isBetweenSentences ?? this.isBetweenSentences,
    );
  }
}

/// 等待用户操作
class BlindWaitingForUser extends BlindPracticeFlowPhase {
  /// 等待原因
  final BlindWaitingReason reason;

  const BlindWaitingForUser(this.reason);
}

/// 等待用户原因
enum BlindWaitingReason {
  /// 用户主动交互
  userInteraction,
}

/// 整个会话完成
class BlindSessionCompleted extends BlindPracticeFlowPhase {
  const BlindSessionCompleted();
}
