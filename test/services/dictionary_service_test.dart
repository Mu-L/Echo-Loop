/// DictionaryService 词形还原查询测试
///
/// 使用内存 SQLite 数据库验证精确匹配和词形还原 fallback 逻辑。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/services/dictionary_service.dart';
import 'package:sqlite3/sqlite3.dart';

/// 创建内存数据库并插入测试数据
Database _createTestDb() {
  final db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE words (
      word TEXT PRIMARY KEY,
      phonetic TEXT NOT NULL,
      translation TEXT,
      collins INTEGER DEFAULT 0,
      tag TEXT
    )
  ''');
  final insertSql = "INSERT INTO words (word, phonetic, translation, collins, tag) VALUES"
      " ('professor', 'prəfesər', 'n. 教授', 4, 'gk cet4 cet6 ky toefl ielts'),"
      " ('run', 'rʌn', 'vi. 跑, 奔', 5, 'zk gk cet4'),"
      " ('go', 'gəu', 'vi. 去, 走', 5, 'zk gk cet4'),"
      " ('good', 'gud', 'a. 好的', 5, 'zk gk cet4'),"
      " ('happy', 'hæpi', 'a. 快乐的', 4, 'zk gk cet4'),"
      " ('study', 'stʌdi', 'n. 学习, 研究', 4, 'zk gk cet4'),"
      " ('child', 'tʃaild', 'n. 孩子', 5, 'zk gk cet4'),"
      " ('mouse', 'maus', 'n. 鼠, 鼠标', 3, 'zk gk cet4')";
  db.execute(insertSql);
  return db;
}

void main() {
  late DictionaryService service;
  late Database db;

  setUp(() {
    db = _createTestDb();
    service = DictionaryService.withDatabase(db);
  });

  tearDown(() {
    db.dispose();
  });

  group('精确匹配', () {
    test('查到已有单词', () async {
      final entry = await service.lookup('professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
      expect(entry.phonetic, contains('fes'));
    });

    test('大小写不敏感', () async {
      final entry = await service.lookup('Professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('查不到且无法还原的词返回 null', () async {
      final entry = await service.lookup('xyznotaword');
      expect(entry, isNull);
    });
  });

  group('词形还原 fallback', () {
    test('复数 -s → 原形（professors → professor）', () async {
      final entry = await service.lookup('professors');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('动词 -ing → 原形（running → run）', () async {
      final entry = await service.lookup('running');
      expect(entry, isNotNull);
      expect(entry!.word, 'run');
    });

    test('动词 -s → 原形（goes → go）', () async {
      final entry = await service.lookup('goes');
      expect(entry, isNotNull);
      expect(entry!.word, 'go');
    });

    test('比较级 -er → 原形（happier → happy）', () async {
      final entry = await service.lookup('happier');
      expect(entry, isNotNull);
      expect(entry!.word, 'happy');
    });

    test('过去式 -ied → 原形（studied → study）', () async {
      final entry = await service.lookup('studied');
      expect(entry, isNotNull);
      expect(entry!.word, 'study');
    });

    test('不规则复数（children → child）', () async {
      final entry = await service.lookup('children');
      expect(entry, isNotNull);
      expect(entry!.word, 'child');
    });

    test('不规则复数（mice → mouse）', () async {
      final entry = await service.lookup('mice');
      expect(entry, isNotNull);
      expect(entry!.word, 'mouse');
    });

    test('不规则过去式（went → go）', () async {
      final entry = await service.lookup('went');
      expect(entry, isNotNull);
      expect(entry!.word, 'go');
    });

    test('最高级 -est → 原形（happiest → happy）', () async {
      final entry = await service.lookup('happiest');
      expect(entry, isNotNull);
      expect(entry!.word, 'happy');
    });

    test('过去分词 -ed（studied → study）', () async {
      final entry = await service.lookup('studies');
      expect(entry, isNotNull);
      expect(entry!.word, 'study');
    });
  });
}
