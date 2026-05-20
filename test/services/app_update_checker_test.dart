import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/app_update_checker.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AppUpdateChecker checker;

  setUp(() {
    mockDio = MockDio();
    checker = AppUpdateChecker.withDio(mockDio);
  });

  group('AppUpdateChecker.check', () {
    test('成功解析有效 JSON', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '1.1.0',
            'minimumVersion': '1.0.0',
            'releaseNotes': {'en': 'Bug fixes'},
            'downloadUrl': {'fallback': 'https://example.com'},
          },
        ),
      );

      final result = await checker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.1.0');
      expect(result.minimumVersion, '1.0.0');
    });

    test('网络错误返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('响应数据为 null 返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: null,
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('JSON 格式错误返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: <String, dynamic>{'invalid': true},
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('DNS 解析失败返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.unknown,
          error: 'Failed host lookup',
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });
  });

  group('AppUpdateChecker.check iOS Lookup API', () {
    late AppUpdateChecker iosChecker;

    setUp(() {
      iosChecker = AppUpdateChecker.withDio(
        mockDio,
        bundleId: 'top.echo-loop',
        useIosLookup: true,
      );
    });

    test('成功解析 Lookup API 响应', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'resultCount': 1,
            'results': [
              {
                'version': '1.0.12',
                'trackViewUrl': 'https://apps.apple.com/app/id6760324074',
                'releaseNotes': 'Bug fixes and improvements',
              },
            ],
          },
        ),
      );

      final result = await iosChecker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.12');
      // Lookup API 不提供 minimumVersion，回退为 0.0.0
      expect(result.minimumVersion, '0.0.0');
      // trackViewUrl 同时作为 ios 和 fallback
      expect(
        result.downloadUrl['ios'],
        'https://apps.apple.com/app/id6760324074',
      );
      expect(
        result.downloadUrl['fallback'],
        'https://apps.apple.com/app/id6760324074',
      );
      // releaseNotes 单语字符串同时映射给 en 和 zh
      expect(result.releaseNotes['en'], 'Bug fixes and improvements');
      expect(result.releaseNotes['zh'], 'Bug fixes and improvements');
    });

    test('results 为空数组返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'resultCount': 0, 'results': []},
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('缺少 version 字段返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'results': [
              {'trackViewUrl': 'https://apps.apple.com/x'},
            ],
          },
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('网络错误返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('bundleId 为空返回 null', () async {
      final emptyChecker = AppUpdateChecker.withDio(
        mockDio,
        bundleId: '',
        useIosLookup: true,
      );

      final result = await emptyChecker.check();
      expect(result, isNull);
      verifyNever(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });

    test('releaseNotes 缺失时降级为空 Map', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'results': [
              {
                'version': '1.0.12',
                'trackViewUrl': 'https://apps.apple.com/x',
              },
            ],
          },
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.releaseNotes, isEmpty);
    });

    test('trackViewUrl 缺失时使用默认 App Store 链接', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'results': [
              {'version': '1.0.12'},
            ],
          },
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.downloadUrl['ios'], contains('apps.apple.com'));
    });
  });
}
