import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

import 'app_logger.dart';

const isAiHttp2Supported = true;

void configureAiHttp2Adapter(Dio dio, {required Duration idleTimeout}) {
  final manager = ConnectionManager(
    idleTimeout: idleTimeout,
    onClientCreate: (uri, _) {
      _logConnectStart(uri, idleTimeout);
    },
  );
  dio.httpClientAdapter = _LoggingHttp2Adapter(manager);
}

class _LoggingHttp2Adapter extends Http2Adapter {
  _LoggingHttp2Adapter(super.connectionManager);

  @override
  void close({bool force = false}) {
    AppLogger.log('AI-HTTP2', 'adapter close force=$force');
    _seenOrigins.clear();
    super.close(force: force);
  }
}

final Set<String> _seenOrigins = <String>{};

void _logConnectStart(Uri uri, Duration idleTimeout) {
  final origin = _originOf(uri);
  final message = _seenOrigins.add(origin)
      ? 'connect start'
      : 'reconnect start';
  AppLogger.log(
    'AI-HTTP2',
    '$message $origin idleTimeout=${idleTimeout.inSeconds}s',
  );
}

String _originOf(Uri uri) => '${uri.scheme}://${uri.host}:${uri.port}';
