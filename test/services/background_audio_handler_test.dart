import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/services/background_audio_handler.dart';

/// just_audio 播放器的最小 mock：仅满足 [EchoLoopAudioHandler] 构造与
/// `_broadcastState` 读取的接口，不做真实播放。
class _MockAudioPlayer extends Mock implements ja.AudioPlayer {}

void main() {
  late _MockAudioPlayer player;
  late EchoLoopAudioHandler handler;

  setUp(() {
    player = _MockAudioPlayer();
    // 构造函数订阅这两个流，给空流即可。
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<ja.PlaybackEvent>.empty());
    when(
      () => player.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    // _broadcastState 读取的瞬时状态。
    when(() => player.playing).thenReturn(false);
    when(() => player.processingState).thenReturn(ja.ProcessingState.idle);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.speed).thenReturn(1.0);
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    handler = EchoLoopAudioHandler(player: player);
  });

  group('skip 回调', () {
    test('未注册时 skipToNext/skipToPrevious 为 no-op，且控制列表不含切句', () async {
      await handler.skipToNext();
      await handler.skipToPrevious();

      // 触发一次广播后读取 controls（未注册回调 → 仅播放/停止）。
      handler.setSkipHandlers(onPrevious: null, onNext: null);
      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls.contains(MediaControl.skipToPrevious), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });

    test('注册后 skipToNext/skipToPrevious 触发对应回调', () async {
      var nextCalls = 0;
      var prevCalls = 0;
      handler.setSkipHandlers(
        onPrevious: () async => prevCalls++,
        onNext: () async => nextCalls++,
      );

      await handler.skipToNext();
      await handler.skipToPrevious();

      expect(nextCalls, 1);
      expect(prevCalls, 1);
    });

    test('注册后控制列表与 systemActions 包含切句', () {
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToPrevious), isTrue);
      expect(state.controls.contains(MediaControl.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToPrevious), isTrue);
    });

    test('清空回调后控制列表恢复为播放/停止', () {
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});
      handler.setSkipHandlers(onPrevious: null, onNext: null);

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });
  });

  group('seek 回调（后退/前进 10 秒）', () {
    test('注册后 rewind/fastForward 触发对应回调', () async {
      var rewindCalls = 0;
      var forwardCalls = 0;
      handler.setSeekHandlers(
        onRewind: () async => rewindCalls++,
        onFastForward: () async => forwardCalls++,
      );

      await handler.rewind();
      await handler.fastForward();

      expect(rewindCalls, 1);
      expect(forwardCalls, 1);
    });

    test('注册后控制列表与 systemActions 含 rewind/fastForward', () {
      handler.setSeekHandlers(
        onRewind: () async {},
        onFastForward: () async {},
      );

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.rewind), isTrue);
      expect(state.controls.contains(MediaControl.fastForward), isTrue);
      expect(state.systemActions.contains(MediaAction.rewind), isTrue);
      expect(state.systemActions.contains(MediaAction.fastForward), isTrue);
      // seek 模式不出现切句按钮。
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls.contains(MediaControl.skipToPrevious), isFalse);
    });

    test('切句回调优先于 seek 回调（互斥）', () {
      handler.setSeekHandlers(
        onRewind: () async {},
        onFastForward: () async {},
      );
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToPrevious), isTrue);
      expect(state.controls.contains(MediaControl.skipToNext), isTrue);
      expect(state.controls.contains(MediaControl.rewind), isFalse);
      expect(state.controls.contains(MediaControl.fastForward), isFalse);
    });

    test('清空 seek 回调后恢复为播放/停止', () {
      handler.setSeekHandlers(
        onRewind: () async {},
        onFastForward: () async {},
      );
      handler.setSeekHandlers(onRewind: null, onFastForward: null);

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.rewind), isFalse);
      expect(state.controls.contains(MediaControl.fastForward), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });

    test('未注册时 rewind/fastForward 为 no-op', () async {
      await handler.rewind();
      await handler.fastForward();
      // 不抛异常即通过。
    });
  });

  group('processingState 映射（锁屏状态）', () {
    test('completed 上报为 ready，避免锁屏进度条卡在结尾', () {
      // just_audio 自然播完后处于 completed、playing 仍为 true（§7.6）。
      when(
        () => player.processingState,
      ).thenReturn(ja.ProcessingState.completed);
      when(() => player.playing).thenReturn(true);

      // 触发一次广播（setSkipHandlers 内部调用 _broadcastState）。
      handler.setSkipHandlers(onPrevious: null, onNext: null);

      final state = handler.playbackState.value;
      // 关键断言：系统永远收不到 completed，否则整篇循环回卷后进度条会被钉在结尾。
      expect(state.processingState, AudioProcessingState.ready);
    });

    test('其余状态按原样映射', () {
      const cases = {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.buffering,
        ja.ProcessingState.ready: AudioProcessingState.ready,
      };
      for (final entry in cases.entries) {
        when(() => player.processingState).thenReturn(entry.key);
        handler.setSkipHandlers(onPrevious: null, onNext: null);
        expect(handler.playbackState.value.processingState, entry.value);
      }
    });
  });

  group('play/pause 命令路由', () {
    test('未注册时 play/pause 直接驱动底层播放器', () async {
      await handler.play();
      await handler.pause();

      verify(() => player.play()).called(1);
      verify(() => player.pause()).called(1);
    });

    test('注册后 play/pause 转交业务回调，不直接碰播放器', () async {
      var playCalls = 0;
      var pauseCalls = 0;
      handler.setTransportHandlers(
        onPlay: () async => playCalls++,
        onPause: () async => pauseCalls++,
      );

      await handler.play();
      await handler.pause();

      expect(playCalls, 1);
      expect(pauseCalls, 1);
      verifyNever(() => player.play());
      verifyNever(() => player.pause());
    });

    test('playPlayer/pausePlayer 始终直接驱动播放器（不经回调）', () async {
      handler.setTransportHandlers(onPlay: () async {}, onPause: () async {});

      await handler.playPlayer();
      await handler.pausePlayer();

      verify(() => player.play()).called(1);
      verify(() => player.pause()).called(1);
    });
  });
}
