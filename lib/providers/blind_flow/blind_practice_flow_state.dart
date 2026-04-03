/// 盲听练习流程状态
library;

import 'blind_practice_flow_phase.dart';

/// 盲听流程状态
class BlindPracticeFlowState {
  /// 当前阶段
  final BlindPracticeFlowPhase phase;

  /// 当前句索引（0-based）
  final int sentenceIndex;

  /// 句子总数
  final int totalSentences;

  /// 当前遍次（0-based）
  final int repeatIndex;

  /// 当前句总遍数
  final int totalRepeats;

  /// 流程令牌（异步回调校验用）
  final int flowToken;

  const BlindPracticeFlowState({
    this.phase = const BlindIdle(),
    this.sentenceIndex = 0,
    this.totalSentences = 0,
    this.repeatIndex = 0,
    this.totalRepeats = 1,
    this.flowToken = 0,
  });

  BlindPracticeFlowState copyWith({
    BlindPracticeFlowPhase? phase,
    int? sentenceIndex,
    int? totalSentences,
    int? repeatIndex,
    int? totalRepeats,
    int? flowToken,
  }) {
    return BlindPracticeFlowState(
      phase: phase ?? this.phase,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      repeatIndex: repeatIndex ?? this.repeatIndex,
      totalRepeats: totalRepeats ?? this.totalRepeats,
      flowToken: flowToken ?? this.flowToken,
    );
  }

  bool get isFirstSentence => sentenceIndex <= 0;

  bool get isLastSentence => sentenceIndex >= totalSentences - 1;

  bool get isLastRepeat => repeatIndex >= totalRepeats - 1;

  bool get isCountingDown => phase is BlindWaitingInterval;

  bool get isWaitingForUser => phase is BlindWaitingForUser;
}
