// 字幕文件选择与上传工具
//
// 提供字幕文件选择、保存到沙盒、覆盖确认等公共方法，
// 供音频列表项菜单和合集详情页共用。
import 'dart:convert';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle/subtitle.dart' show SubtitleType;
import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../database/providers.dart';
import '../models/audio_item.dart';
import '../models/word_timestamp.dart';
import '../providers/audio_library_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/subtitle_parser.dart';
import 'synthetic_word_timestamps.dart';
import 'transcript_stats.dart';

/// 字幕字节解码结果。
class TranscriptDecodeResult {
  const TranscriptDecodeResult({required this.text, required this.charset});

  /// 解码后的字幕文本，后续会作为 DB 内字幕唯一内容保存。
  final String text;

  /// 实际采用的字符集名称，用于日志诊断。
  final String charset;
}

/// 选择字幕文件并返回其原始字符串内容（不复制到沙盒）。用户取消返回 null。
///
/// 字幕内容入库后的上传入口：选文件 → 严格校验 → 直接返回内容，由调用方写入
/// DB 列。校验失败抛 [SubtitleParseException]。
Future<String?> pickTranscriptContent() async {
  final result = await pickTranscriptContentWithMetadata();
  return result?.text;
}

/// 选择字幕文件并返回文本内容与采用的字符集。用户取消返回 null。
Future<TranscriptDecodeResult?> pickTranscriptContentWithMetadata() async {
  final FilePickerResult? result;
  if (!kIsWeb && Platform.isIOS) {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      allowMultiple: false,
    );
  } else {
    final initialDir = !kIsWeb && Platform.isMacOS
        ? await _getDownloadsDirectory()
        : null;
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      initialDirectory: initialDir,
      allowMultiple: false,
    );
  }

  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final ext = _extensionOf(file.name).toLowerCase();
  if (ext != 'srt' && ext != 'vtt') {
    throw SubtitleParseException(SubtitleParseErrorKind.unsupportedFormat, ext);
  }
  final type = ext == 'vtt' ? SubtitleType.vtt : SubtitleType.srt;

  // 读取内容：优先文件路径，其次 bytes / readStream（web）。字幕站常见
  // 非 UTF-8 编码文件，不能直接用 File.readAsString() 的严格 UTF-8。
  final Uint8List bytes;
  if (file.path != null) {
    bytes = await File(file.path!).readAsBytes();
  } else if (file.bytes != null) {
    bytes = file.bytes!;
  } else if (file.readStream != null) {
    final chunks = <int>[];
    await for (final chunk in file.readStream!) {
      chunks.addAll(chunk);
    }
    bytes = Uint8List.fromList(chunks);
  } else {
    throw Exception('Unable to access picked file');
  }

  final decoded = await decodeTranscriptBytes(bytes, type: type);

  // 严格校验内容（失败抛 SubtitleParseException）。
  await SubtitleParser.parseSubtitleStrictString(decoded.text, type: type);
  return decoded;
}

/// 解码字幕文件字节。
///
/// 优先处理 BOM / UTF-16 / UTF-8；失败时使用平台 charset 转换尝试常见字幕编码，
/// 并结合字幕结构和乱码特征评分，避免把中文/日文/韩文字幕误按 Windows-1252 解码。
Future<TranscriptDecodeResult> decodeTranscriptBytes(
  List<int> bytes, {
  SubtitleType type = SubtitleType.srt,
}) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final bom = _decodeBom(data);
  if (bom != null) return bom;

  final utf16Guess = _decodeLikelyUtf16(data);
  if (utf16Guess != null) return utf16Guess;

  final candidates = <TranscriptDecodeResult>[];
  try {
    final utf8Candidate = TranscriptDecodeResult(
      text: utf8.decode(data, allowMalformed: false),
      charset: 'utf-8',
    );
    if (await _strictSentenceCount(utf8Candidate.text, type) != null) {
      return utf8Candidate;
    }
    candidates.add(utf8Candidate);
  } on FormatException {
    // 继续尝试常见本地编码。
  }

  for (final charset in _fallbackCharsets) {
    final decoded = await _tryDecodeCharset(charset, data);
    if (decoded != null) candidates.add(decoded);
  }

  var best = await _bestParsableCandidate(candidates, type);
  if (best != null) return best;

  if (candidates.isNotEmpty) {
    candidates.sort(
      (a, b) => _textQualityScore(b.text) - _textQualityScore(a.text),
    );
    return candidates.first;
  }

  return TranscriptDecodeResult(
    text: utf8.decode(data, allowMalformed: true),
    charset: 'utf-8-malformed',
  );
}

TranscriptDecodeResult? _decodeBom(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return TranscriptDecodeResult(
      text: utf8.decode(bytes.sublist(3), allowMalformed: false),
      charset: 'utf-8-bom',
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return TranscriptDecodeResult(
      text: _decodeUtf16(bytes, littleEndian: true, offset: 2),
      charset: 'utf-16le-bom',
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return TranscriptDecodeResult(
      text: _decodeUtf16(bytes, littleEndian: false, offset: 2),
      charset: 'utf-16be-bom',
    );
  }
  return null;
}

TranscriptDecodeResult? _decodeLikelyUtf16(Uint8List bytes) {
  final sampleLength = bytes.length < 200 ? bytes.length : 200;
  if (sampleLength < 8) return null;

  var evenZeros = 0;
  var oddZeros = 0;
  for (var i = 0; i < sampleLength; i++) {
    if (bytes[i] != 0) continue;
    if (i.isEven) {
      evenZeros++;
    } else {
      oddZeros++;
    }
  }

  final threshold = sampleLength ~/ 6;
  if (oddZeros >= threshold && oddZeros > evenZeros * 2) {
    return TranscriptDecodeResult(
      text: _decodeUtf16(bytes, littleEndian: true),
      charset: 'utf-16le',
    );
  }
  if (evenZeros >= threshold && evenZeros > oddZeros * 2) {
    return TranscriptDecodeResult(
      text: _decodeUtf16(bytes, littleEndian: false),
      charset: 'utf-16be',
    );
  }
  return null;
}

String _decodeUtf16(
  Uint8List bytes, {
  required bool littleEndian,
  int offset = 0,
}) {
  final codeUnits = <int>[];
  final end = bytes.length - ((bytes.length - offset).isOdd ? 1 : 0);
  for (var i = offset; i + 1 < end; i += 2) {
    final unit = littleEndian
        ? bytes[i] | (bytes[i + 1] << 8)
        : (bytes[i] << 8) | bytes[i + 1];
    codeUnits.add(unit);
  }
  return String.fromCharCodes(codeUnits);
}

Future<TranscriptDecodeResult?> _tryDecodeCharset(
  String charset,
  Uint8List bytes,
) async {
  try {
    return TranscriptDecodeResult(
      text: await CharsetConverter.decode(charset, bytes),
      charset: charset.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

Future<TranscriptDecodeResult?> _bestParsableCandidate(
  List<TranscriptDecodeResult> candidates,
  SubtitleType type,
) async {
  TranscriptDecodeResult? best;
  var bestScore = -1 << 31;
  for (final candidate in candidates) {
    final sentenceCount = await _strictSentenceCount(candidate.text, type);
    if (sentenceCount == null) continue;
    final score = sentenceCount * 1000 + _textQualityScore(candidate.text);
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

Future<int?> _strictSentenceCount(String text, SubtitleType type) async {
  try {
    final sentences = await SubtitleParser.parseSubtitleStrictString(
      text,
      type: type,
    );
    return sentences.length;
  } on SubtitleParseException {
    return null;
  }
}

int _textQualityScore(String text) {
  var score = 0;
  for (final rune in text.runes) {
    if (_isReplacementOrControl(rune)) score -= 30;
    if (_isLikelyMojibake(rune)) score -= 10;
    if (_isCjkOrKanaOrHangul(rune)) {
      score += 8;
    } else if (_isCommonLetterRange(rune)) {
      score += 2;
    }
  }
  return score;
}

bool _isReplacementOrControl(int rune) {
  if (rune == 0xFFFD) return true;
  return rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D;
}

bool _isLikelyMojibake(int rune) {
  return rune == 0x00C2 || // Â
      rune == 0x00C3 || // Ã
      rune == 0x00A4 || // ¤
      rune == 0x00A5 || // ¥
      rune == 0x00BD || // ½
      rune == 0x00BE; // ¾
}

bool _isCommonLetterRange(int rune) {
  return (rune >= 0x0041 && rune <= 0x007A) ||
      (rune >= 0x0400 && rune <= 0x04FF) ||
      _isCjkOrKanaOrHangul(rune);
}

bool _isCjkOrKanaOrHangul(int rune) {
  return (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0x3400 && rune <= 0x9FFF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
}

const _fallbackCharsets = <String>[
  'GB18030',
  'GBK',
  'Big5',
  'Shift_JIS',
  'EUC-KR',
  'Windows-1252',
  'Windows-1251',
  'ISO-8859-1',
];

/// 提取文件名扩展名（不含点）。
String _extensionOf(String name) {
  final lastDot = name.lastIndexOf('.');
  if (lastDot < 0 || lastDot == name.length - 1) return '';
  return name.substring(lastDot + 1);
}

/// 为音频上传字幕（含已有字幕覆盖确认）
///
/// 如果音频已有字幕，先弹出确认对话框；确认后选择文件并更新音频项。
Future<void> uploadTranscriptForAudio(
  BuildContext context,
  WidgetRef ref,
  AudioItem audioItem,
) async {
  final l10n = AppLocalizations.of(context)!;

  // 已有字幕时弹出覆盖确认
  if (audioItem.hasTranscript) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.replaceTranscriptTitle),
        content: Text(l10n.replaceTranscriptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.replace),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  // 选择字幕文件
  try {
    final content = await pickTranscriptContent();
    if (content == null) return;

    // 统计字幕句子数和单词数
    final stats = await getTranscriptStatsFromSrt(content);

    // 本地字幕没有真实词级时间戳，保存时按字符长度生成近似词级时间戳。
    final wordTimestampsJson = encodeWordTimestamps(
      await generateSyntheticWordTimestampsFromSrt(content),
    );

    // 字幕内容 + 近似词级时间戳原子写入 DB；transcriptPath 置 null。
    await ref
        .read(audioItemDaoProvider)
        .saveTranscriptContent(
          audioItem.id,
          srt: content,
          wordTimestampsJson: wordTimestampsJson,
        );

    // 更新音频项的统计数据与来源
    if (!context.mounted) return;
    ref
        .read(audioLibraryProvider.notifier)
        .updateAudioItem(
          audioItem.copyWith(
            transcriptPath: null,
            sentenceCount: stats.$1,
            wordCount: stats.$2,
            transcriptSource: TranscriptSource.local,
          ),
        );
  } on SubtitleParseException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(subtitleParseErrorMessage(l10n, e))));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.pickTranscriptFileFailed}: $e')),
    );
  }
}

/// 把 [SubtitleParseException] 映射为本地化的提示文案。
String subtitleParseErrorMessage(
  AppLocalizations l10n,
  SubtitleParseException e,
) {
  switch (e.kind) {
    case SubtitleParseErrorKind.unsupportedFormat:
      return l10n.subtitleUnsupportedFormat(e.detail ?? '?');
    case SubtitleParseErrorKind.formatInvalid:
      return l10n.subtitleFormatInvalid;
    case SubtitleParseErrorKind.empty:
      return l10n.subtitleFileEmpty;
  }
}

/// 获取 macOS 下载目录路径
Future<String?> _getDownloadsDirectory() async {
  try {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return path.join(home, 'Downloads');
  } catch (_) {
    return null;
  }
}
