import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// copyWith 用于区分"未传参"与"显式传 null"的哨兵值
const _sentinel = Object();

class AudioItem {
  final String id;
  final String name;
  final String audioPath; // 相对路径，如 "audios/file.mp3"
  final String? transcriptPath; // 相对路径，如 "transcripts/file.srt"
  final DateTime addedDate;
  final int totalDuration; // in seconds
  final int sentenceCount;
  final int wordCount;
  final bool isStarred;

  AudioItem({
    required this.id,
    required this.name,
    required this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    this.totalDuration = 0,
    this.sentenceCount = 0,
    this.wordCount = 0,
    this.isStarred = false,
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
    'isStarred': isStarred,
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
    isStarred: json['isStarred'] ?? false,
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
    bool? isStarred,
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
      isStarred: isStarred ?? this.isStarred,
    );
  }
}
