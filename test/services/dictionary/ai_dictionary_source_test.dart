import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/services/dictionary/ai_dictionary_source.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCacheDao extends Mock implements SentenceAiCacheDao {}

class MockApiClient extends Mock implements SentenceAiApiClient {}

DictionaryEntry _entry(String headword) => DictionaryEntry(
  headword: headword,
  pronunciation: const Pronunciation(uk: 'rʌn', us: 'rʌn'),
  meanings: const [],
  commonExpressions: const [],
  wordFamily: const [],
  forms: const [],
  etymology: '',
  learnerTips: const [],
);

void main() {
  late MockCacheDao dao;
  late MockApiClient api;
  late AiDictionarySource source;

  setUp(() {
    dao = MockCacheDao();
    api = MockApiClient();
    source = AiDictionarySource(cacheDao: () => dao, apiClient: () => api);
  });

  const word = 'run';
  const tokenReq = DictionaryLookupRequest(
    word: word,
    accessToken: 'tok',
    targetLanguage: 'zh-CN',
  );

  test('元数据', () {
    expect(source.id, 'ai');
    expect(source.canBeDisabled, isFalse);
    expect(source.requiresNetwork, isTrue);
  });

  test('无 accessToken → 抛 DictionaryAuthRequiredException', () {
    expect(
      () => source.lookup(const DictionaryLookupRequest(word: word)),
      throwsA(isA<DictionaryAuthRequiredException>()),
    );
  });

  test('L3 API 命中 → 返回结果并写 L1+L2', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary', any()),
    ).thenAnswer((_) async {});

    final result = await source.lookup(tokenReq);

    expect(result, isA<AiDictResult>());
    expect((result! as AiDictResult).entry.headword, word);
    verify(() => dao.upsert(any(), 'ai_dictionary', any())).called(1);
  });

  test('L1 内存命中 → 第二次不再调 API', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary', any()),
    ).thenAnswer((_) async {});

    await source.lookup(tokenReq);
    await source.lookup(tokenReq);

    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('clearMemoryCache 后重查不再命中 L1（回到 L2/L3）', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary', any()),
    ).thenAnswer((_) async {});

    await source.lookup(tokenReq); // 写入 L1
    source.clearMemoryCache(); // 清空 L1
    await source.lookup(tokenReq); // L1 落空 → 再次走 L2/L3

    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).called(2);
  });

  test('L2 SQLite 命中 → 不调 API', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => jsonEncode(_entry(word).toJson()));

    final result = await source.lookup(tokenReq);

    expect((result! as AiDictResult).entry.headword, word);
    verifyNever(
      () => api.lookupDictionary(
        any(),
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('后台单请求：忽略调用方 cancelToken（不转发给 API）', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => _entry(word));
    when(
      () => dao.upsert(any(), 'ai_dictionary', any()),
    ).thenAnswer((_) async {});

    // 即便传入一个已取消的 token，请求仍正常完成（AI 忽略它）
    final token = CancelToken()..cancel('popup closed');
    final result = await source.lookup(tokenReq, cancelToken: token);

    expect((result! as AiDictResult).entry.headword, word);
    // 关键：API 不带 cancelToken 调用，无法被调用方中断
    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).called(1);
  });

  test('并发同词复用在途请求 → 只调一次 API', () async {
    final completer = Completer<DictionaryEntry?>();
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) => completer.future);
    when(
      () => dao.upsert(any(), 'ai_dictionary', any()),
    ).thenAnswer((_) async {});

    final f1 = source.lookup(tokenReq);
    final f2 = source.lookup(tokenReq);
    completer.complete(_entry(word));
    final r1 = await f1;
    final r2 = await f2;

    expect((r1! as AiDictResult).entry.headword, word);
    expect((r2! as AiDictResult).entry.headword, word);
    verify(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).called(1);
  });

  test('API 返回 null → 空条目（isEmpty），仍为 AiDictResult', () async {
    when(
      () => dao.getByHash(any(), 'ai_dictionary'),
    ).thenAnswer((_) async => null);
    when(
      () => api.lookupDictionary(
        word,
        accessToken: any(named: 'accessToken'),
        targetLanguage: any(named: 'targetLanguage'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => dao.upsert(any(), 'ai_dictionary', any()),
    ).thenAnswer((_) async {});

    final result = await source.lookup(tokenReq);

    expect(result, isA<AiDictResult>());
    expect((result! as AiDictResult).entry.isEmpty, isTrue);
  });
}
