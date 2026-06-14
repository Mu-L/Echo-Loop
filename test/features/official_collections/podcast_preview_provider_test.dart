import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/official_collections/data/official_catalog_service.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';
import 'package:echo_loop/features/official_collections/providers/podcast_preview_provider.dart';
import 'package:echo_loop/features/official_collections/screens/official_podcast_list_screen.dart';
import 'package:echo_loop/features/official_collections/screens/official_podcast_preview_screen.dart';
import 'package:echo_loop/features/podcast/podcast_feed_parser.dart';
import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/features/podcast/podcast_url_resolver.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import 'fixtures/catalog_fixtures.dart';

class _FakeCatalogService extends OfficialCatalogService {
  final CatalogSnapshot snapshot;

  _FakeCatalogService(this.snapshot)
    : super.withDio(dio: Dio(), resolveDir: () async => Directory.systemTemp);

  @override
  CatalogSnapshot get cached => snapshot;

  @override
  bool get hasInitialized => true;
}

class _FakeDio extends Fake implements Dio {
  Object? error;
  String body;

  _FakeDio({required this.body, this.error});

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final e = error;
    if (e != null) throw e;
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  const rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>6 Minute English</title>
    <description>Short lessons</description>
    <item>
      <guid>ep-1</guid>
      <title>Episode One</title>
      <description>Episode summary</description>
      <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
      <pubDate>Mon, 02 Jan 2006 15:04:05 +0000</pubDate>
      <itunes:duration>06:00</itunes:duration>
    </item>
  </channel>
</rss>''';

  test('PodcastPreviewService 使用 RSS URL 拉取并解析 episode', () async {
    final dio = _FakeDio(body: rss);
    final service = PodcastPreviewService(
      dio: dio,
      resolver: PodcastUrlResolver(dio: dio),
      parser: PodcastFeedParser(),
    );

    final data = await service.fetch(makeCatalogPodcast());

    expect(data.meta.title, '6 Minute English');
    expect(data.episodes, hasLength(1));
    expect(data.episodes.single.title, 'Episode One');
    expect(data.episodes.single.durationSeconds, 360);
  });

  test('PodcastPreviewService 将网络错误映射为 preview exception', () async {
    final dio = _FakeDio(
      body: '',
      error: DioException(
        requestOptions: RequestOptions(path: 'https://example.com/rss'),
        type: DioExceptionType.connectionError,
      ),
    );
    final service = PodcastPreviewService(
      dio: dio,
      resolver: PodcastUrlResolver(dio: dio),
      parser: PodcastFeedParser(),
    );

    await expectLater(
      service.fetch(makeCatalogPodcast()),
      throwsA(
        isA<PodcastPreviewException>().having(
          (e) => e.kind,
          'kind',
          PodcastPreviewErrorKind.network,
        ),
      ),
    );
  });

  testWidgets('未订阅时点击 episode 提示先添加播客', (tester) async {
    final snapshot = makeSnapshot(
      collections: const [],
      podcastCatalogs: [makeCatalogPodcast(id: 'podcast-1')],
    );

    await tester.pumpWidget(
      createTestApp(
        const OfficialPodcastPreviewScreen(podcastId: 'podcast-1'),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          podcastPreviewProvider('podcast-1').overrideWith(
            (ref) async => const PodcastPreviewData(
              meta: PodcastFeedMeta(
                title: '6 Minute English',
                feedUrl: 'https://example.com/rss',
                description: 'Short lessons',
              ),
              episodes: [
                PodcastEpisode(
                  guid: 'ep-1',
                  title: 'Episode One',
                  enclosureUrl: 'https://example.com/ep1.mp3',
                  enclosureType: 'audio/mpeg',
                  description: 'Episode summary',
                  durationSeconds: 360,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Episode One'));
    await tester.pumpAndSettle();

    expect(find.text('Add Podcast First'), findsOneWidget);
    expect(
      find.textContaining('Add this podcast to My Collections'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('预览页 episode 标题比描述文字更突出', (tester) async {
    final snapshot = makeSnapshot(
      collections: const [],
      podcastCatalogs: [makeCatalogPodcast(id: 'podcast-1')],
    );

    await tester.pumpWidget(
      createTestApp(
        const OfficialPodcastPreviewScreen(podcastId: 'podcast-1'),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          podcastPreviewProvider('podcast-1').overrideWith(
            (ref) async => const PodcastPreviewData(
              meta: PodcastFeedMeta(
                title: '6 Minute English',
                feedUrl: 'https://example.com/rss',
              ),
              episodes: [
                PodcastEpisode(
                  guid: 'ep-1',
                  title: 'Episode One',
                  enclosureUrl: 'https://example.com/ep1.mp3',
                  enclosureType: 'audio/mpeg',
                  description: 'Episode summary',
                  durationSeconds: 360,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.text('Episode One')));
    final title = tester.widget<Text>(find.text('Episode One'));
    final description = tester.widget<Text>(find.text('Episode summary'));

    expect(title.style?.fontWeight, FontWeight.w700);
    expect(title.style?.color, theme.colorScheme.onSurface);
    expect(description.style?.color, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('预览页更多详情复用 Podcast 详情弹窗样式', (tester) async {
    final snapshot = makeSnapshot(
      collections: const [],
      podcastCatalogs: [
        makeCatalogPodcast(
          id: 'podcast-1',
          description: '<p>Catalog description should be replaced.</p>',
        ),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        const OfficialPodcastPreviewScreen(podcastId: 'podcast-1'),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          podcastPreviewProvider('podcast-1').overrideWith(
            (ref) async => const PodcastPreviewData(
              meta: PodcastFeedMeta(
                title: '6 Minute English',
                feedUrl: 'https://podcasts.files.bbci.co.uk/p02pc9tn.rss',
                author: 'BBC Learning English',
                description: 'Learn and practise useful English.',
                imageUrl: 'https://example.com/cover.jpg',
              ),
              episodes: [
                PodcastEpisode(
                  guid: 'ep-1',
                  title: 'Episode One',
                  enclosureUrl: 'https://example.com/ep1.mp3',
                  enclosureType: 'audio/mpeg',
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('BBC Learning English'), findsOneWidget);
    expect(
      find.text('Learn and practise useful English.'),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Apple Podcasts'), findsOneWidget);
    expect(find.text('RSS URL'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsWidgets);
    expect(find.textContaining('<p>'), findsNothing);
  });

  testWidgets('精选播客列表页渲染卡片不会触发无限高度布局错误', (tester) async {
    final snapshot = makeSnapshot(
      collections: const [],
      podcastCatalogs: [
        makeCatalogPodcast(
          id: 'podcast-1',
          title: '6 Minute English',
          description:
              'Short BBC lessons that introduce everyday English vocabulary.',
        ),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        const OfficialPodcastListScreen(),
        overrides: [
          officialCatalogServiceProvider.overrideWithValue(
            _FakeCatalogService(snapshot),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('6 Minute English'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
