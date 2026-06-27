import 'package:drift/drift.dart';

/// 通用 AI 结果缓存表
///
/// 作为三级缓存的 L2 层（SQLite），存储后端返回的各类 AI 结果 JSON。
/// 不限句子级——凡可按 key 索引、可重建的 AI 结果都可入表，由 [type] 区分。
/// 通过 (textHash, type) 唯一键查找，支持按访问时间清理过期缓存。
/// 表名 `sentence_ai_cache` 为历史遗留（最初仅缓存句子翻译），现已通用化。
class SentenceAiCache extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 被缓存文本的 SHA-256 哈希值（归一化后）。
  /// 句子级 type 用句子文本；词级 type（如 `ai_dictionary`）用 `词|目标语言`。
  TextColumn get textHash => text()();

  /// 结果类型，区分同表不同来源：
  /// `translation`（句子翻译）/ `analysis`（句子解析）/ `ai_dictionary`（AI 词典）。
  TextColumn get type => text()();

  /// API 返回的 JSON 字符串
  TextColumn get result => text()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();

  /// 最后访问时间（用于 LRU 清理）
  DateTimeColumn get lastAccessedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {textHash, type},
  ];
}
