import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late SentenceAiApiClient client;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDio = MockDio();
    client = SentenceAiApiClient.withDio(mockDio);
  });

  group('translate', () {
    test('正常响应返回 SentenceTranslation', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/translate',
          data: {'text': 'Hello world'},
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization',
              'Bearer access-token',
            ),
          ),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'translation': '你好世界'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await client.translate(
        'Hello world',
        accessToken: 'access-token',
      );
      expect(result.translation, '你好世界');
    });

    test('服务器错误抛出 DioException', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/translate',
          data: {'text': 'test'},
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(),
          response: Response(statusCode: 500, requestOptions: RequestOptions()),
        ),
      );

      expect(
        () => client.translate('test', accessToken: 'access-token'),
        throwsA(isA<DioException>()),
      );
    });

    test('支持 CancelToken', () async {
      final cancelToken = CancelToken();

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/translate',
          data: {'text': 'test'},
          options: any(named: 'options'),
          cancelToken: cancelToken,
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => client.translate(
          'test',
          accessToken: 'access-token',
          cancelToken: cancelToken,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });
  });

  group('analyze', () {
    test('正常响应返回 SentenceAnalysis', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/analyze',
          data: {'text': 'She has been studying.'},
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization',
              'Bearer access-token',
            ),
          ),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'analysis': {
              'grammar': '现在完成进行时',
              'vocabulary': 'study: 学习',
              'listening': '表示持续进行的动作',
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await client.analyze(
        'She has been studying.',
        accessToken: 'access-token',
      );
      expect(result.grammar, '现在完成进行时');
      expect(result.vocabulary, 'study: 学习');
      expect(result.listening, '表示持续进行的动作');
    });

    test('服务器错误抛出 DioException', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/analyze',
          data: {'text': 'test'},
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => client.analyze('test', accessToken: 'access-token'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('splitSenseGroups', () {
    test('调用 v2 认证接口并发送 Bearer token', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/sense-groups',
          data: {'text': 'Hello world'},
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization',
              'Bearer access-token',
            ),
          ),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'medium': ['Hello world'],
            'fine': ['Hello', 'world'],
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await client.splitSenseGroups(
        'Hello world',
        accessToken: 'access-token',
      );

      expect(result.medium, ['Hello world']);
      expect(result.fine, ['Hello', 'world']);
    });
  });

  group('构造与销毁', () {
    test('普通构造函数创建实例', () {
      final c = SentenceAiApiClient(baseUrl: 'https://test.com');
      expect(c, isNotNull);
      c.dispose();
    });

    test('withDio 构造函数接受自定义 Dio', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://mock.com'));
      final c = SentenceAiApiClient.withDio(dio);
      expect(c, isNotNull);
    });

    test('dispose 调用 Dio.close', () {
      when(
        () => mockDio.close(force: any(named: 'force')),
      ).thenAnswer((_) async {});
      client.dispose();
      verify(() => mockDio.close(force: false)).called(1);
    });
  });
}
