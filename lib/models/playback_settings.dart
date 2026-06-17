/// 自由练习播放器设置模型。
///
/// 循环行为由两组**相互独立、可同时开启**的开关描述：
/// - 整篇循环（[loopWhole]）：整篇播完后回到开头重播，总共播 [wholeLoopCount] 遍
///   （`0`=∞ 无限）；每遍之间停顿 [wholeInterval]。
/// - 单句循环（[loopSentence]）：每句重复 [sentenceLoopCount] 次（`0`=∞ 无限）后进
///   下一句；每次重复之间停顿 [sentenceInterval]。
///
/// 两者可同时开启：每句重复若干次，整篇走到末尾后再整体循环若干遍。
class PlaybackSettings {
  /// 整篇循环开关。
  final bool loopWhole;

  /// 整篇循环的总播放遍数。`1-10`：播该遍数后停止；`0`：无限循环（∞）。
  final int wholeLoopCount;

  /// 整篇每遍之间的间隔时间（0-10 秒）。
  final Duration wholeInterval;

  /// 单句循环开关。
  final bool loopSentence;

  /// 单句循环时当前句的重复次数。`1-10`：重复该次数后进下一句；`0`：无限重复（∞）。
  final int sentenceLoopCount;

  /// 单句每次重复之间的间隔时间（0-10 秒）。
  final Duration sentenceInterval;

  /// 播放速度。
  final double playbackSpeed;

  /// 单句模式：控制字幕展示方式。
  final bool singleSentenceMode;

  /// 是否显示字幕文本。
  final bool showTranscript;

  const PlaybackSettings({
    this.loopWhole = false,
    this.wholeLoopCount = 3,
    this.wholeInterval = const Duration(seconds: 3),
    this.loopSentence = false,
    this.sentenceLoopCount = 3,
    this.sentenceInterval = const Duration(seconds: 2),
    this.playbackSpeed = 1.0,
    this.singleSentenceMode = false,
    this.showTranscript = true,
  });

  /// 整篇循环是否为无限（开启且次数为 0）。
  bool get isInfiniteWhole => loopWhole && wholeLoopCount == 0;

  /// 单句循环是否为无限（开启且次数为 0）。
  bool get isInfiniteSentence => loopSentence && sentenceLoopCount == 0;

  Map<String, dynamic> toJson() => {
    'loopWhole': loopWhole,
    'wholeLoopCount': wholeLoopCount,
    'wholeInterval': wholeInterval.inMilliseconds,
    'loopSentence': loopSentence,
    'sentenceLoopCount': sentenceLoopCount,
    'sentenceInterval': sentenceInterval.inMilliseconds,
    'playbackSpeed': playbackSpeed,
    'singleSentenceMode': singleSentenceMode,
    'showTranscript': showTranscript,
  };

  /// 从 JSON 还原设置，并兼容旧版持久化数据。
  ///
  /// 以是否含 `loopWhole`/`loopSentence` 键区分新旧 schema：
  /// - 新 schema：直接读取六个循环字段（带范围校验）。
  /// - 旧 schema：把单一 `repeatMode`（及更旧的 `loopEnabled`/`loopAudioEnabled`
  ///   布尔）迁移为新字段——`one`→单句循环，`all`→整篇循环（∞，保留旧「整段循环=
  ///   永远循环」语义），`off`→两者皆关。旧 `loopCount`/`pauseInterval` 顺带迁移到
  ///   单句循环参数，越界值静默截断到新范围。
  factory PlaybackSettings.fromJson(Map<String, dynamic> json) {
    final speed = (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0;
    final single = json['singleSentenceMode'] == true;
    final transcript = json['showTranscript'] ?? true;

    final hasNew =
        json.containsKey('loopWhole') || json.containsKey('loopSentence');
    if (hasNew) {
      return PlaybackSettings(
        loopWhole: json['loopWhole'] == true,
        wholeLoopCount: _parseCount(json['wholeLoopCount'], 3),
        wholeInterval: _parseInterval(json['wholeInterval'], 3),
        loopSentence: json['loopSentence'] == true,
        sentenceLoopCount: _parseCount(json['sentenceLoopCount'], 3),
        sentenceInterval: _parseInterval(json['sentenceInterval'], 2),
        playbackSpeed: speed,
        singleSentenceMode: single,
        showTranscript: transcript,
      );
    }

    // 旧 schema 迁移
    switch (_legacyMode(json)) {
      case 'one':
        return PlaybackSettings(
          loopSentence: true,
          sentenceLoopCount: _parseCount(json['loopCount'], 3),
          sentenceInterval: _parseInterval(json['pauseInterval'], 2),
          playbackSpeed: speed,
          singleSentenceMode: single,
          showTranscript: transcript,
        );
      case 'all':
        return PlaybackSettings(
          loopWhole: true,
          wholeLoopCount: 0, // ∞：保留旧整段循环的无限语义
          playbackSpeed: speed,
          singleSentenceMode: single,
          showTranscript: transcript,
        );
      default:
        return PlaybackSettings(
          playbackSpeed: speed,
          singleSentenceMode: single,
          showTranscript: transcript,
        );
    }
  }

  /// 解析循环次数：`0`=∞；`1-10` 合法；`>10` 截到 10；其余非法值回退 [def]。
  static int _parseCount(dynamic raw, int def) {
    if (raw is! int) return def;
    if (raw == 0) return 0; // ∞
    if (raw < 1) return def;
    return raw > 10 ? 10 : raw;
  }

  /// 解析间隔时间：范围 0-10 秒，越界截断；缺失则用 [defSecs]。
  static Duration _parseInterval(dynamic ms, int defSecs) {
    final raw = ms is int ? ms : defSecs * 1000;
    int secs = (raw / 1000).round();
    if (secs < 0) secs = 0;
    if (secs > 10) secs = 10;
    return Duration(seconds: secs);
  }

  /// 解析旧版循环模式名（`one`/`all`/`off`），兼容更旧的布尔字段。
  static String _legacyMode(Map<String, dynamic> json) {
    final raw = json['repeatMode'];
    if (raw == 'one' || raw == 'all' || raw == 'off') return raw as String;
    if (json['loopEnabled'] == true) return 'one';
    if (json['loopAudioEnabled'] == true) return 'all';
    return 'off';
  }

  PlaybackSettings copyWith({
    bool? loopWhole,
    int? wholeLoopCount,
    Duration? wholeInterval,
    bool? loopSentence,
    int? sentenceLoopCount,
    Duration? sentenceInterval,
    double? playbackSpeed,
    bool? singleSentenceMode,
    bool? showTranscript,
  }) {
    return PlaybackSettings(
      loopWhole: loopWhole ?? this.loopWhole,
      wholeLoopCount: wholeLoopCount ?? this.wholeLoopCount,
      wholeInterval: wholeInterval ?? this.wholeInterval,
      loopSentence: loopSentence ?? this.loopSentence,
      sentenceLoopCount: sentenceLoopCount ?? this.sentenceLoopCount,
      sentenceInterval: sentenceInterval ?? this.sentenceInterval,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      singleSentenceMode: singleSentenceMode ?? this.singleSentenceMode,
      showTranscript: showTranscript ?? this.showTranscript,
    );
  }
}
