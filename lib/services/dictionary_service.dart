/// 本地词典查询服务
///
/// 基于 SQLite 的离线词典，从 assets 中加载 dict.db，
/// 首次使用时复制到应用文档目录，后续直接打开查询。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lemmatizerx/lemmatizerx.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  /// 确保数据库已初始化
  Future<void> _ensureInitialized() async {
    if (_db != null) return;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, 'dict.db');
    final dbFile = File(dbPath);

    // 首次使用时从 assets 复制到文档目录
    if (!dbFile.existsSync()) {
      final data = await rootBundle.load('assets/dict/dict.db');
      await dbFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    _db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  }

  /// 查询单词，返回词典条目；未找到返回 null
  ///
  /// 精确匹配失败时，自动通过词形还原（lemmatization）尝试查找原形。
  Future<DictEntry?> lookup(String word) async {
    await _ensureInitialized();

    final lower = word.toLowerCase();

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

  /// 释放资源
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
