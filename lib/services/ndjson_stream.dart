/// NDJSON 流解析工具
///
/// 把字节流（Dio `ResponseType.stream` 的 `ResponseBody.stream`）解析为
/// 逐行 JSON 对象流：每行是一个语法完整的 JSON（部分对象快照），`\n` 分隔。
///
/// 用 `utf8.decoder` + `LineSplitter` 两个标准 transformer：
/// - `utf8.decoder` 流式解码，自动缓冲跨 chunk 的多字节字符切分；
/// - `LineSplitter` 处理跨 chunk 的行缓冲，并在流结束时吐出无尾随 `\n` 的末行。
///
/// 纯函数、无副作用；错误帧（`__error`）不在此判定，由调用方（API 客户端）识别。
library;

import 'dart:async';
import 'dart:convert';

/// 将 NDJSON 字节流解析为 JSON 对象流。
///
/// 空行跳过；无法解析或非 Map 的行视为协议损坏，抛 [FormatException]。
///
/// [onLine] 会在 JSON 解析前收到每一条非空原始行，供调用方做调试日志；回调异常会被
/// 忽略，避免日志链路影响流式解析。
///
/// [idleTimeout] 非 null 时启用「帧间空闲超时」：字节流每收到一块数据即重置计时，
/// 超过该时长仍无新字节则抛 [TimeoutException]（流开到一半服务端僵死时的止损）。
/// 默认 null 保持原行为不变。
Stream<Map<String, dynamic>> decodeNdjson(
  Stream<List<int>> bytes, {
  void Function(String line)? onLine,
  Duration? idleTimeout,
}) async* {
  // .cast<List<int>>()：Dio 的 ResponseBody.stream 实为 Stream<Uint8List>，
  // 直接 transform(utf8.decoder) 会因 reified 类型是 Uint8List 触发协变检查失败
  // （要求 StreamTransformer<Uint8List,String>）。cast 归一为 List<int> 后匹配。
  var byteStream = bytes.cast<List<int>>();
  if (idleTimeout != null) {
    byteStream = byteStream.timeout(
      idleTimeout,
      onTimeout: (sink) =>
          sink.addError(TimeoutException('NDJSON 帧间空闲超时', idleTimeout)),
    );
  }
  final lines = byteStream
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      onLine?.call(trimmed);
    } catch (_) {
      // 调试日志不能影响流式解析主流程。
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('NDJSON frame must be a JSON object', trimmed);
    }
    yield decoded;
  }
}
