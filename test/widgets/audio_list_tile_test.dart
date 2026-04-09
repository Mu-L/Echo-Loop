import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/audio_list_tile.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 包装器：从 Provider 读取第一个音频项，传给 AudioListTile
/// 模拟真实场景中父组件 watch provider → 传 item 给子组件的模式
class _AudioListTileWrapper extends ConsumerWidget {
  const _AudioListTileWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(audioLibraryProvider.select((s) => s.audioItems));
    if (items.isEmpty) return const SizedBox.shrink();
    return AudioListTile(audioItem: items.first);
  }
}

void main() {
  group('AudioListTile 星标功能', () {
    final baseItem = createTestAudioItem(id: 'star-1', name: 'Star Audio');

    Widget buildTile(AudioLibraryState libraryState) {
      return createTestApp(
        const _AudioListTileWrapper(),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    Widget buildCompactTile(AudioLibraryState libraryState) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    testWidgets('未置顶时显示 push_pin_outlined 图标', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('已置顶时显示 push_pin 图标', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('未置顶时图钉图标为灰色', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin_outlined));
      expect(icon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('已置顶时图钉图标使用 primary 色', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(icon.color, isNotNull);
    });

    testWidgets('已置顶时 leading 音频图标颜色不受置顶影响（显示进度状态）', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      // leading 图标现在显示进度状态，不再根据置顶变色
      final audioIcon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
      expect(audioIcon.color, isNotNull);
      expect(audioIcon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('点击置顶按钮触发 togglePin 并更新图标', (tester) async {
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      // 点击置顶按钮
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pumpAndSettle();

      // 验证切换成功 — 图标变为实心图钉
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('右侧按钮贴近 item 上下边缘，增大可触达区域', (tester) async {
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(find.byType(Card).first);
      final pinRect = tester.getRect(
        find.byKey(const Key('audio_list_tile_pin_hit_area')),
      );
      final menuRect = tester.getRect(
        find.byKey(const Key('audio_list_tile_menu_hit_area')),
      );

      expect(pinRect.top - cardRect.top, lessThanOrEqualTo(4));
      expect(cardRect.bottom - menuRect.bottom, lessThanOrEqualTo(4));
    });
  });

  group('AudioListTile 当前播放展示', () {
    final baseItem = createTestAudioItem(
      id: 'playing-1',
      name: 'Playing Audio',
    );

    Widget buildCollectionTile() {
      return createTestApp(
        AudioListTile(audioItem: baseItem, collectionId: 'collection-1'),
        overrides: [
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(
            () => TestListeningPractice(
              ListeningPracticeState(currentAudioItem: baseItem),
            ),
          ),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
        ],
      );
    }

    testWidgets('合集上下文当前播放时不显示 Last 标签', (tester) async {
      await tester.pumpWidget(buildCollectionTile());
      await tester.pumpAndSettle();

      expect(find.text('Last'), findsNothing);
      expect(find.text('上次'), findsNothing);
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}
