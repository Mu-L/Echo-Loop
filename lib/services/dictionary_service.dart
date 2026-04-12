/// 本地词典查询服务
///
/// 基于 SQLite 的离线词典，由 [DictionaryProvider] 负责下载和打开数据库，
/// 本服务仅提供查询能力。数据库未就绪时，查询方法返回 null / 空 map。
library;

import 'package:flutter/foundation.dart';
import 'package:lemmatizerx/lemmatizerx.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/dict_entry.dart';

/// 词典服务单例
class DictionaryService {
  DictionaryService._();

  /// 测试用构造器，允许注入已打开的数据库
  @visibleForTesting
  DictionaryService.withDatabase(Database db) : _db = db;

  static DictionaryService _instance = DictionaryService._();

  /// 全局单例
  static DictionaryService get instance => _instance;

  /// 测试用：替换全局单例，返回旧实例以便恢复
  @visibleForTesting
  static DictionaryService replaceInstance(DictionaryService service) {
    final old = _instance;
    _instance = service;
    return old;
  }

  Database? _db;
  final Lemmatizer _lemmatizer = Lemmatizer();

  static final RegExp _edgePunctuationPattern = RegExp(
    r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$',
  );

  /// 词典数据库是否已就绪
  bool get isAvailable => _db != null;

  /// 打开指定路径的词典数据库
  ///
  /// 由 [DictionaryProvider] 在词典下载完成后调用。
  /// 如果之前已打开其他数据库，会先关闭。
  void openDatabase(String dbPath) {
    _db?.dispose();
    _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  }

  /// 关闭当前数据库连接
  ///
  /// 切换母语词典时需要先关闭再打开新词典。
  void close() {
    _db?.dispose();
    _db = null;
  }

  /// 查询单词，返回词典条目；未找到或数据库未就绪时返回 null
  ///
  /// 精确匹配失败时，自动通过词形还原（lemmatization）尝试查找原形。
  DictEntry? lookup(String word) {
    if (_db == null) return null;

    final lower = _normalizeLookupWord(word);
    if (lower.isEmpty) return null;

    // 精确匹配
    final exact = _queryWord(lower);
    if (exact != null) return exact;

    // 词形还原 fallback：获取所有可能的原形，逐个查询
    final lemmas = _lemmatizer.lemmas(lower);
    for (final lemma in lemmas) {
      for (final form in lemma.lemmas) {
        if (form == lower) continue; // 跳过与原词相同的形式
        final result = _queryWord(form);
        if (result != null) return result;
      }
    }

    return null;
  }

  String _normalizeLookupWord(String word) {
    return word.trim().replaceAll(_edgePunctuationPattern, '').toLowerCase();
  }

  /// 直接查询数据库
  DictEntry? _queryWord(String word) {
    final result = _db!.select(
      'SELECT word, phonetic, translation, collins, tag FROM words WHERE word = ? COLLATE NOCASE',
      [word],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    return DictEntry.fromRow(
      word: row['word'] as String,
      phonetic: row['phonetic'] as String,
      translation: row['translation'] as String?,
      collins: (row['collins'] as int?) ?? 0,
      tag: row['tag'] as String?,
    );
  }

  /// 批量查询多个单词的词典条目
  ///
  /// 返回 word → DictEntry 的映射，未找到的单词不包含在结果中。
  /// 数据库未就绪时返回空 map。
  Map<String, DictEntry> lookupAll(List<String> words) {
    if (_db == null) return {};
    final result = <String, DictEntry>{};

    // 1. 归一化，建立 normalizedWord → [原始 word] 的映射
    final normalizedToOriginals = <String, List<String>>{};
    for (final word in words) {
      final lower = _normalizeLookupWord(word);
      if (lower.isEmpty) continue;
      (normalizedToOriginals[lower] ??= []).add(word);
    }
    if (normalizedToOriginals.isEmpty) return result;

    // 2. 批量精确匹配（单次 SQL IN 查询）
    final allNormalized = normalizedToOriginals.keys.toList();
    final found = _queryWords(allNormalized);
    for (final MapEntry(key: lower, value: entry) in found.entries) {
      for (final original in normalizedToOriginals[lower]!) {
        result[original] = entry;
      }
    }

    // 3. 对未命中的词做词形还原 fallback（逐个查询）
    final missed = allNormalized.where((w) => !found.containsKey(w)).toList();
    for (final lower in missed) {
      final lemmas = _lemmatizer.lemmas(lower);
      DictEntry? entry;
      for (final lemma in lemmas) {
        for (final form in lemma.lemmas) {
          if (form == lower) continue;
          entry = _queryWord(form);
          if (entry != null) break;
        }
        if (entry != null) break;
      }
      if (entry != null) {
        for (final original in normalizedToOriginals[lower]!) {
          result[original] = entry;
        }
      }
    }
    return result;
  }

  /// 批量查询多个单词（单次 SQL），返回 normalizedWord → DictEntry
  Map<String, DictEntry> _queryWords(List<String> words) {
    if (words.isEmpty) return {};
    final result = <String, DictEntry>{};

    // SQLite 变量上限通常 999，分批查询
    const batchSize = 500;
    for (var i = 0; i < words.length; i += batchSize) {
      final batch = words.sublist(
        i,
        i + batchSize > words.length ? words.length : i + batchSize,
      );
      final placeholders = List.filled(batch.length, '?').join(',');
      final rows = _db!.select(
        'SELECT word, phonetic, translation, collins, tag '
        'FROM words WHERE word COLLATE NOCASE IN ($placeholders)',
        batch,
      );
      for (final row in rows) {
        final word = (row['word'] as String).toLowerCase();
        result[word] = DictEntry.fromRow(
          word: row['word'] as String,
          phonetic: row['phonetic'] as String,
          translation: row['translation'] as String?,
          collins: (row['collins'] as int?) ?? 0,
          tag: row['tag'] as String?,
        );
      }
    }
    return result;
  }

  /// 释放资源
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
