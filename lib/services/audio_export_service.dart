/// 音频项导出服务
///
/// 负责将音频文件和/或字幕文件导出为单个文件或 ZIP 压缩包。
/// 纯业务逻辑，不依赖 UI 框架或 Riverpod。
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 音频项导出服务
class AudioExportService {
  /// 导出音频项文件到临时目录
  ///
  /// 根据 [includeAudio] 和 [includeTranscript] 选择导出内容：
  /// - 仅选一项：复制该文件并重命名为 [displayName] + 原扩展名
  /// - 两项都选：打包为 ZIP，内含重命名后的音频和字幕文件
  ///
  /// 返回导出文件的完整路径（调用方负责清理临时文件）。
  Future<String> exportAudioItem({
    required String displayName,
    required String audioPath,
    String? transcriptPath,
    required bool includeAudio,
    required bool includeTranscript,
  }) async {
    if (!includeAudio && !includeTranscript) {
      throw ArgumentError('至少需要选择一项导出内容');
    }
    if (includeTranscript && transcriptPath == null) {
      throw ArgumentError('选择了导出字幕但字幕路径为空');
    }

    final safeName = sanitizeFileName(displayName);
    final tempDir = await _createTempDir();

    // 单文件导出：直接复制并重命名
    if (includeAudio && !includeTranscript) {
      return _copySingleFile(audioPath, safeName, tempDir);
    }
    if (includeTranscript && !includeAudio) {
      return _copySingleFile(transcriptPath!, safeName, tempDir);
    }

    // 双文件导出：打包为 ZIP
    return _packZip(
      audioPath: audioPath,
      transcriptPath: transcriptPath!,
      safeName: safeName,
      tempDir: tempDir,
    );
  }

  /// 清理文件名中的非法字符
  ///
  /// 替换 `/\:*?"<>|` 为 `_`，合并连续下划线，去除首尾空白，
  /// 截断至 200 字符以避免超出操作系统路径长度限制。
  String sanitizeFileName(String name) {
    var result = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    result = result.replaceAll(RegExp(r'_+'), '_');
    result = result.trim();
    // 去除首尾下划线
    result = result.replaceAll(RegExp(r'^_+|_+$'), '');
    if (result.length > 200) {
      result = result.substring(0, 200);
    }
    if (result.isEmpty) {
      result = 'export';
    }
    return result;
  }

  /// 复制单个文件到临时目录，以 [safeName] + 原扩展名命名
  Future<String> _copySingleFile(
    String sourcePath,
    String safeName,
    Directory tempDir,
  ) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('源文件不存在', sourcePath);
    }
    final ext = p.extension(sourcePath);
    final destPath = p.join(tempDir.path, '$safeName$ext');
    await sourceFile.copy(destPath);
    return destPath;
  }

  /// 将音频和字幕文件打包为 ZIP
  Future<String> _packZip({
    required String audioPath,
    required String transcriptPath,
    required String safeName,
    required Directory tempDir,
  }) async {
    final audioFile = File(audioPath);
    final transcriptFile = File(transcriptPath);
    if (!await audioFile.exists()) {
      throw FileSystemException('音频文件不存在', audioPath);
    }
    if (!await transcriptFile.exists()) {
      throw FileSystemException('字幕文件不存在', transcriptPath);
    }

    final audioExt = p.extension(audioPath);
    final transcriptExt = p.extension(transcriptPath);

    final archive = Archive();

    // 添加音频文件
    final audioBytes = await audioFile.readAsBytes();
    archive.addFile(
      ArchiveFile('$safeName$audioExt', audioBytes.length, audioBytes),
    );

    // 添加字幕文件
    final transcriptBytes = await transcriptFile.readAsBytes();
    archive.addFile(
      ArchiveFile(
        '$safeName$transcriptExt',
        transcriptBytes.length,
        transcriptBytes,
      ),
    );

    final zipData = ZipEncoder().encode(archive);
    final zipPath = p.join(tempDir.path, '$safeName.zip');
    await File(zipPath).writeAsBytes(zipData);
    return zipPath;
  }

  /// 创建临时目录
  Future<Directory> _createTempDir() async {
    final systemTemp = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        systemTemp.path,
        'audio_export_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }
}
