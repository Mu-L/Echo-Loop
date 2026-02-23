import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluency/providers/audio_library_provider.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('AudioLibrary.toggleStar', () {
    late ProviderContainer container;

    setUp(() {
      final initialItems = [
        createTestAudioItem(id: 'a1', name: 'Audio 1'),
        createTestAudioItem(id: 'a2', name: 'Audio 2'),
      ];
      container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(
              AudioLibraryState(audioItems: initialItems),
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('toggleStar 将未星标音频切换为星标', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      final stateBefore = container.read(audioLibraryProvider);
      expect(stateBefore.audioItems.first.isStarred, isFalse);

      await notifier.toggleStar('a1');

      final stateAfter = container.read(audioLibraryProvider);
      expect(stateAfter.audioItems.first.isStarred, isTrue);
      // 其他音频不受影响
      expect(stateAfter.audioItems[1].isStarred, isFalse);
    });

    test('toggleStar 将已星标音频切换为未星标', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      // 先星标
      await notifier.toggleStar('a1');
      expect(
        container.read(audioLibraryProvider).audioItems.first.isStarred,
        isTrue,
      );

      // 再取消
      await notifier.toggleStar('a1');
      expect(
        container.read(audioLibraryProvider).audioItems.first.isStarred,
        isFalse,
      );
    });

    test('toggleStar 对不存在的 ID 无操作', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      final stateBefore = container.read(audioLibraryProvider);

      await notifier.toggleStar('non-existent');

      final stateAfter = container.read(audioLibraryProvider);
      expect(stateAfter.audioItems.length, stateBefore.audioItems.length);
    });
  });
}
