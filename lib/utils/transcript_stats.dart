// 字幕统计工具
//
// 解析字幕文件，统计句子数和单词数。
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../services/subtitle_parser.dart';

/// 解析字幕文件，返回 (sentenceCount, wordCount)
///
/// [transcriptRelativePath] 为相对于 Documents 目录的路径，
/// 如 "transcripts/test.srt"。
/// 解析失败时返回 (0, 0)。
Future<(int, int)> getTranscriptStats(String transcriptRelativePath) async {
  final docs = await getApplicationDocumentsDirectory();
  final fullPath = path.join(docs.path, transcriptRelativePath);

  final sentences = await SubtitleParser.parseSubtitle(fullPath);
  if (sentences.isEmpty) return (0, 0);

  final sentenceCount = sentences.length;
  int wordCount = 0;
  for (final sentence in sentences) {
    final words = sentence.text.trim().split(RegExp(r'\s+'));
    wordCount += words.where((w) => w.isNotEmpty).length;
  }

  return (sentenceCount, wordCount);
}
