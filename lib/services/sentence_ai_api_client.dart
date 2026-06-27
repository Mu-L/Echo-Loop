/// AI 句子翻译/解析 API 客户端
///
/// 封装与后端 `/api/v1/ai/` 的通信，用于获取句子的翻译和语法解析。
/// 基于 Dio，receiveTimeout 设为 60 秒以适应 LLM 响应延迟。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/geo_interceptor.dart';
import '../config/api_config.dart';
import 'api_log_interceptor.dart';
import '../models/sentence_ai_result.dart';
import '../models/sense_group_result.dart';
import '../models/dictionary/dictionary_entry.dart';

part 'sentence_ai_api_client.g.dart';

/// AI 句子翻译/解析 API 客户端
class SentenceAiApiClient {
  final Dio _dio;

  SentenceAiApiClient({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ) {
    // 异步添加 GeoInterceptor（SharedPreferences 在 main() 中已初始化，几乎同步返回）
    SharedPreferences.getInstance().then(
      (prefs) => _dio.interceptors.add(GeoInterceptor(prefs)),
    );
    _dio.interceptors.add(ApiLogInterceptor(tag: 'AI-API'));
  }

  /// 用于测试的构造函数，允许注入 Dio 实例
  SentenceAiApiClient.withDio(this._dio);

  /// 翻译句子
  ///
  /// 调用后端 AI 翻译接口，返回目标语言的翻译结果。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  Future<SentenceTranslation> translate(
    String text, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/translate',
      data: {
        'text': text,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      cancelToken: cancelToken,
    );
    return SentenceTranslation.fromJson(response.data!);
  }

  /// 解析句子
  ///
  /// 调用后端 AI 解析接口，返回语法、词汇和听力分析。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  Future<SentenceAnalysis> analyze(
    String text, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/analyze',
      data: {
        'text': text,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      cancelToken: cancelToken,
    );
    return SentenceAnalysis.fromJson(response.data!);
  }

  /// AI 词典释义
  ///
  /// 调用后端 `POST /api/v2/ai/dictionary`（需登录态），返回结构化词典条目。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  /// 响应缺少 `analysis` 字段时返回 null。
  Future<DictionaryEntry?> lookupDictionary(
    String word, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/dictionary',
      data: {
        'word': word,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      cancelToken: cancelToken,
    );
    final analysis = response.data?['analysis'];
    if (analysis is! Map<String, dynamic>) return null;
    return DictionaryEntry.fromJson(analysis);
  }

  /// 拆分意群
  ///
  /// 调用后端 AI 意群拆分接口，返回意群列表（含中文翻译）。
  Future<SenseGroupResult> splitSenseGroups(
    String text, {
    required String accessToken,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/sense-groups',
      data: {'text': text},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      cancelToken: cancelToken,
    );
    return SenseGroupResult.fromJson(response.data!);
  }

  /// 释放资源
  void dispose() => _dio.close();
}

/// AI API 客户端单例 Provider
@Riverpod(keepAlive: true)
SentenceAiApiClient sentenceAiApiClient(Ref ref) {
  final client = SentenceAiApiClient(baseUrl: apiBaseUrl);
  ref.onDispose(client.dispose);
  return client;
}
