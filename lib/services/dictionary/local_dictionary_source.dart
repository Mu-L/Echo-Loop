/// 本地词典数据源
///
/// 包装现有 [DictionaryService]（离线 SQLite），不可禁用、不需联网。
/// 词典「未下载/下载中/失败」的展示由 `LocalDictResultView` 监听 dictionaryProvider 处理；
/// 本源在词典未就绪时返回 null，由视图层据下载状态显示下载入口。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/dictionary/dictionary_lookup_result.dart';
import '../dictionary_service.dart';
import 'dictionary_source.dart';

/// 本地 SQLite 词典源
class LocalDictionarySource implements DictionarySource {
  final DictionaryService _service;

  LocalDictionarySource(this._service);

  @override
  String get id => 'local';

  @override
  IconData get icon => Icons.menu_book_rounded;

  @override
  bool get canBeDisabled => false;

  @override
  bool get requiresNetwork => false;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    // 词典未就绪：返回 null，视图层据 dictionaryProvider 显示下载/重试入口
    if (!_service.isAvailable) return null;
    final entry = _service.lookup(request.word);
    return entry == null ? null : LocalDictResult(entry);
  }
}
