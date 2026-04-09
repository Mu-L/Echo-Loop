import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// copyWith 用于区分"未传参"与"显式传 null"的哨兵值
const _sentinel = Object();

/// 字幕来源枚举
enum TranscriptSource {
  /// 本地文件上传
  local,

  /// AI 转录生成
  ai;

  /// 从整数值创建（数据库存储用）
  static TranscriptSource? fromIndex(int? index) {
    if (index == null) return null;
    if (index >= 0 && index < values.length) return values[index];
    return null;
  }
}

class AudioItem {
  final String id;
  final String name;
  final String audioPath; // 相对路径，如 "audios/file.mp3"
  final String? transcriptPath; // 相对路径，如 "transcripts/file.srt"
  final DateTime addedDate;
  final int totalDuration; // in seconds
  final int sentenceCount;
  final int wordCount;
  final bool isPinned;

  /// 字幕来源：null 表示无字幕
  final TranscriptSource? transcriptSource;

  /// 音频文件 SHA256 指纹（缓存，避免重复计算）
  final String? audioSha256;

  /// AI 转录使用的语言（'en' / 'multi'）
  final String? transcriptLanguage;

  AudioItem({
    required this.id,
    required this.name,
    required this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    this.totalDuration = 0,
    this.sentenceCount = 0,
    this.wordCount = 0,
    this.isPinned = false,
    this.transcriptSource,
    this.audioSha256,
    this.transcriptLanguage,
  });

  bool get hasTranscript =>
      transcriptPath != null && transcriptPath!.isNotEmpty;

  /// 获取音频文件的完整路径
  Future<String> getFullAudioPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return path.join(docs.path, audioPath);
  }

  /// 获取字幕文件的完整路径
  Future<String?> getFullTranscriptPath() async {
    if (!hasTranscript) return null;
    final docs = await getApplicationDocumentsDirectory();
    return path.join(docs.path, transcriptPath!);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'audioPath': audioPath,
    'transcriptPath': transcriptPath,
    'addedDate': addedDate.toIso8601String(),
    'totalDuration': totalDuration,
    'sentenceCount': sentenceCount,
    'wordCount': wordCount,
    'isPinned': isPinned,
    'transcriptSource': transcriptSource?.index,
    'audioSha256': audioSha256,
    'transcriptLanguage': transcriptLanguage,
  };

  factory AudioItem.fromJson(Map<String, dynamic> json) => AudioItem(
    id: json['id'],
    name: json['name'],
    audioPath: json['audioPath'],
    transcriptPath: json['transcriptPath'],
    addedDate: DateTime.parse(json['addedDate']),
    totalDuration: json['totalDuration'] ?? 0,
    sentenceCount: json['sentenceCount'] ?? 0,
    wordCount: json['wordCount'] ?? 0,
    isPinned: json['isPinned'] ?? json['isStarred'] ?? false,
    transcriptSource: TranscriptSource.fromIndex(json['transcriptSource']),
    audioSha256: json['audioSha256'],
    transcriptLanguage: json['transcriptLanguage'],
  );

  AudioItem copyWith({
    String? id,
    String? name,
    String? audioPath,
    Object? transcriptPath = _sentinel,
    DateTime? addedDate,
    int? totalDuration,
    int? sentenceCount,
    int? wordCount,
    bool? isPinned,
    Object? transcriptSource = _sentinel,
    Object? audioSha256 = _sentinel,
    Object? transcriptLanguage = _sentinel,
  }) {
    return AudioItem(
      id: id ?? this.id,
      name: name ?? this.name,
      audioPath: audioPath ?? this.audioPath,
      transcriptPath: transcriptPath == _sentinel
          ? this.transcriptPath
          : transcriptPath as String?,
      addedDate: addedDate ?? this.addedDate,
      totalDuration: totalDuration ?? this.totalDuration,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      wordCount: wordCount ?? this.wordCount,
      isPinned: isPinned ?? this.isPinned,
      transcriptSource: transcriptSource == _sentinel
          ? this.transcriptSource
          : transcriptSource as TranscriptSource?,
      audioSha256: audioSha256 == _sentinel
          ? this.audioSha256
          : audioSha256 as String?,
      transcriptLanguage: transcriptLanguage == _sentinel
          ? this.transcriptLanguage
          : transcriptLanguage as String?,
    );
  }
}
