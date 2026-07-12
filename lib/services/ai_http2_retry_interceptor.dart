/// AI API HTTP/2 连接层重试拦截器。
///
/// `dio_http2_adapter` 的 `ConnectionManager` 会复用 HTTP/2 连接池。服务端发
/// GOAWAY 或关闭空闲连接后存在空档，可能派发到一条已失效的连接 → 请求以
/// [DioExceptionType.connectionError]（或建连阶段的 [DioExceptionType.connectionTimeout]）
/// 失败，而 adapter 本身不会重试该请求。
///
/// 这类失败发生在「请求尚未被服务器处理」阶段（连接建立/复用即失败，无字节送达），
/// 因此重试永远安全，与请求是否幂等无关——这是业界处理 HTTP/2 连接复用竞态的标准做法。
///
/// 只重试连接层错误：业务/额度错误（402/5xx）因流式请求用 `validateStatus: (_) => true`
/// 根本不产生 DioException、不触发 [onError]，故不会被误重试；已取消的请求也不重试。
library;

import 'package:dio/dio.dart';

import 'app_logger.dart';

/// 重试计数在 [RequestOptions.extra] 中的键。
const _retryCountKey = 'ai_h2_retry';

/// 对 AI API 的 HTTP/2 连接层瞬断做有限次自动重试。
class AiHttp2RetryInterceptor extends Interceptor {
  /// [dio] 为本拦截器挂载的实例，重试时经它重新发起请求（重跑完整拦截器链）。
  /// [maxRetries] 为最大重试次数，默认 1。
  AiHttp2RetryInterceptor(this._dio, {this.maxRetries = 1});

  final Dio _dio;
  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final attempt = (options.extra[_retryCountKey] as int? ?? 0) + 1;
    options.extra[_retryCountKey] = attempt;

    AppLogger.log(
      'AI-HTTP2',
      '连接层瞬断重试 $attempt/$maxRetries ${options.method} ${options.uri} '
          '(${err.type.name})',
    );

    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  /// 是否可重试：仅连接层错误、未取消、且未达重试上限。
  bool _shouldRetry(DioException err) {
    if (err.type != DioExceptionType.connectionError &&
        err.type != DioExceptionType.connectionTimeout) {
      return false;
    }
    if (err.requestOptions.cancelToken?.isCancelled ?? false) {
      return false;
    }
    final count = err.requestOptions.extra[_retryCountKey] as int? ?? 0;
    return count < maxRetries;
  }
}
