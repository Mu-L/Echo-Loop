/// App 版本更新检查服务
///
/// iOS 通过 App Store Lookup API（`itunes.apple.com/lookup`）查询当前
/// App Store 实际可下载的版本，确保审核期间不会误提示 iOS 用户更新。
/// 其他平台从远程静态 JSON（`version.json`）获取版本信息。
/// 使用独立 Dio 实例（不复用 AI API 的 Dio），所有异常静默返回 null。
library;

import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/api_config.dart';
import '../models/app_update_info.dart';

/// App Store Lookup API endpoint。
const _iosLookupBase = 'https://itunes.apple.com/lookup';

/// App 版本更新检查器
///
/// 版本检查 URL 基于 [apiBaseUrl]（通过 `--dart-define=API_BASE_URL` 配置），
/// 本地开发时访问 `http://localhost:3000/version.json`，
/// 生产环境访问 `https://www.echo-loop.top/version.json`。
///
/// iOS 单独走 App Store Lookup API，[bundleId] 必填。
class AppUpdateChecker {
  final Dio _dio;
  final String _url;
  final String? _bundleId;
  final bool _useIosLookup;

  /// 使用默认配置创建检查器
  ///
  /// [bundleId] 用于 iOS App Store Lookup（其他平台忽略此参数）。
  AppUpdateChecker({String? bundleId})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      _url = '$apiBaseUrl/version.json',
      _bundleId = bundleId,
      _useIosLookup = !kIsWeb && Platform.isIOS;

  /// 用于测试的构造函数，允许注入 Dio 实例和配置
  ///
  /// [useIosLookup] 强制走 iOS Lookup 路径（host 测试机 Platform.isIOS=false，
  /// 测试时需显式开启）。
  AppUpdateChecker.withDio(
    this._dio, {
    String url = '',
    String? bundleId,
    bool useIosLookup = false,
  }) : _url = url,
       _bundleId = bundleId,
       _useIosLookup = useIosLookup;

  /// 检查远程版本信息
  ///
  /// iOS：查 App Store Lookup API（返回 App Store 实际可下载版本）。
  /// 其他平台：拉取远程 version.json。
  /// 失败时返回 null（网络错误、JSON 解析失败等均静默处理）。
  Future<AppUpdateInfo?> check() async {
    if (_useIosLookup) {
      return _checkIosLookup();
    }
    return _checkVersionJson();
  }

  /// iOS：从 App Store Lookup API 解析版本信息
  ///
  /// Lookup API 返回的 `version` 字段总是 App Store 当前可下载的版本，
  /// 不会包含审核中的 build，因此天然解决"提示有但下载不到"的问题。
  /// Lookup API 不提供 minimumVersion，回退为 `0.0.0`（不触发强制更新）。
  Future<AppUpdateInfo?> _checkIosLookup() async {
    final bundleId = _bundleId;
    if (bundleId == null || bundleId.isEmpty) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _iosLookupBase,
        queryParameters: {'bundleId': bundleId},
      );
      final data = response.data;
      if (data == null) return null;
      final results = data['results'];
      if (results is! List || results.isEmpty) return null;
      final entry = results.first;
      if (entry is! Map) return null;
      final version = entry['version'];
      if (version is! String || version.isEmpty) return null;
      final trackUrl = entry['trackViewUrl'];
      final releaseNotes = entry['releaseNotes'];
      final downloadUrl = trackUrl is String && trackUrl.isNotEmpty
          ? trackUrl
          : 'https://apps.apple.com/app/id6760324074';
      final notes = releaseNotes is String && releaseNotes.isNotEmpty
          ? {'en': releaseNotes, 'zh': releaseNotes}
          : <String, String>{};
      return AppUpdateInfo(
        latestVersion: version,
        minimumVersion: '0.0.0',
        releaseNotes: notes,
        downloadUrl: {'ios': downloadUrl, 'fallback': downloadUrl},
      );
    } catch (_) {
      return null;
    }
  }

  /// 非 iOS 平台：拉取远程 version.json
  Future<AppUpdateInfo?> _checkVersionJson() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_url);
      if (response.data == null) return null;
      return AppUpdateInfo.fromJson(response.data!);
    } catch (_) {
      return null;
    }
  }

  /// 释放资源
  void dispose() => _dio.close();
}
