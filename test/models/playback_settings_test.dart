import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/playback_settings.dart';

void main() {
  group('PlaybackSettings', () {
    group('默认值正确性', () {
      test('所有默认值符合预期', () {
        const settings = PlaybackSettings();

        expect(settings.loopWhole, isFalse);
        expect(settings.wholeLoopCount, 3);
        expect(settings.wholeInterval, const Duration(seconds: 3));
        expect(settings.loopSentence, isFalse);
        expect(settings.sentenceLoopCount, 3);
        expect(settings.sentenceInterval, const Duration(seconds: 2));
        expect(settings.playbackSpeed, 1.0);
        expect(settings.singleSentenceMode, isFalse);
        expect(settings.showTranscript, isTrue);
        expect(settings.isInfiniteWhole, isFalse);
        expect(settings.isInfiniteSentence, isFalse);
      });
    });

    group('toJson / fromJson 往返序列化', () {
      test('完整字段往返一致', () {
        const settings = PlaybackSettings(
          loopWhole: true,
          wholeLoopCount: 5,
          wholeInterval: Duration(seconds: 4),
          loopSentence: true,
          sentenceLoopCount: 2,
          sentenceInterval: Duration(seconds: 1),
          playbackSpeed: 1.5,
          singleSentenceMode: true,
          showTranscript: false,
        );
        final restored = PlaybackSettings.fromJson(settings.toJson());

        expect(restored.loopWhole, settings.loopWhole);
        expect(restored.wholeLoopCount, settings.wholeLoopCount);
        expect(restored.wholeInterval, settings.wholeInterval);
        expect(restored.loopSentence, settings.loopSentence);
        expect(restored.sentenceLoopCount, settings.sentenceLoopCount);
        expect(restored.sentenceInterval, settings.sentenceInterval);
        expect(restored.playbackSpeed, settings.playbackSpeed);
        expect(restored.singleSentenceMode, settings.singleSentenceMode);
        expect(restored.showTranscript, settings.showTranscript);
      });

      test('间隔以毫秒序列化', () {
        const settings = PlaybackSettings(
          wholeInterval: Duration(seconds: 5),
          sentenceInterval: Duration(seconds: 3),
        );
        final json = settings.toJson();
        expect(json['wholeInterval'], 5000);
        expect(json['sentenceInterval'], 3000);
      });

      test('无限循环往返一致', () {
        const settings = PlaybackSettings(
          loopWhole: true,
          wholeLoopCount: 0,
          loopSentence: true,
          sentenceLoopCount: 0,
        );
        final restored = PlaybackSettings.fromJson(settings.toJson());
        expect(restored.isInfiniteWhole, isTrue);
        expect(restored.isInfiniteSentence, isTrue);
      });
    });

    group('旧字段迁移', () {
      test('旧 repeatMode=one 迁移为单句循环', () {
        final settings = PlaybackSettings.fromJson({
          'repeatMode': 'one',
          'loopCount': 5,
          'pauseInterval': 4000,
        });
        expect(settings.loopSentence, isTrue);
        expect(settings.sentenceLoopCount, 5);
        expect(settings.sentenceInterval, const Duration(seconds: 4));
        expect(settings.loopWhole, isFalse);
      });

      test('旧 repeatMode=all 迁移为整篇循环（∞）', () {
        final settings = PlaybackSettings.fromJson({'repeatMode': 'all'});
        expect(settings.loopWhole, isTrue);
        expect(settings.wholeLoopCount, 0);
        expect(settings.isInfiniteWhole, isTrue);
        expect(settings.loopSentence, isFalse);
      });

      test('旧 repeatMode=off 迁移为两者皆关', () {
        final settings = PlaybackSettings.fromJson({'repeatMode': 'off'});
        expect(settings.loopWhole, isFalse);
        expect(settings.loopSentence, isFalse);
      });

      test('更旧 loopEnabled=true 迁移为单句循环', () {
        final settings = PlaybackSettings.fromJson({'loopEnabled': true});
        expect(settings.loopSentence, isTrue);
        expect(settings.loopWhole, isFalse);
      });

      test('更旧 loopAudioEnabled=true 迁移为整篇循环', () {
        final settings = PlaybackSettings.fromJson({'loopAudioEnabled': true});
        expect(settings.loopWhole, isTrue);
        expect(settings.loopSentence, isFalse);
      });

      test('单句循环优先于整段循环', () {
        final settings = PlaybackSettings.fromJson({
          'loopEnabled': true,
          'loopAudioEnabled': true,
        });
        expect(settings.loopSentence, isTrue);
        expect(settings.loopWhole, isFalse);
      });

      test('迁移时旧 loopCount 超范围截断到 10', () {
        final settings = PlaybackSettings.fromJson({
          'repeatMode': 'one',
          'loopCount': 18,
        });
        expect(settings.sentenceLoopCount, 10);
      });

      test('新 schema 字段优先于旧字段', () {
        final settings = PlaybackSettings.fromJson({
          'loopWhole': true,
          'wholeLoopCount': 4,
          'repeatMode': 'one',
          'loopEnabled': true,
        });
        expect(settings.loopWhole, isTrue);
        expect(settings.wholeLoopCount, 4);
        expect(settings.loopSentence, isFalse);
      });
    });

    group('fromJson 范围校验', () {
      test('次数 = 0 视为无限（∞）', () {
        final settings = PlaybackSettings.fromJson({
          'loopSentence': true,
          'sentenceLoopCount': 0,
        });
        expect(settings.sentenceLoopCount, 0);
        expect(settings.isInfiniteSentence, isTrue);
      });

      test('次数 > 10 截断为 10', () {
        final settings = PlaybackSettings.fromJson({
          'loopWhole': true,
          'wholeLoopCount': 100,
        });
        expect(settings.wholeLoopCount, 10);
      });

      test('次数为负重置为默认 3', () {
        final settings = PlaybackSettings.fromJson({
          'loopSentence': true,
          'sentenceLoopCount': -5,
        });
        expect(settings.sentenceLoopCount, 3);
      });

      test('次数非 int 类型使用默认 3', () {
        final settings = PlaybackSettings.fromJson({
          'loopWhole': true,
          'wholeLoopCount': 'abc',
        });
        expect(settings.wholeLoopCount, 3);
      });

      test('间隔负值截断为 0', () {
        final settings = PlaybackSettings.fromJson({
          'loopSentence': true,
          'sentenceInterval': -1000,
        });
        expect(settings.sentenceInterval, Duration.zero);
      });

      test('间隔 > 10 秒截断为 10 秒', () {
        final settings = PlaybackSettings.fromJson({
          'loopWhole': true,
          'wholeInterval': 60000,
        });
        expect(settings.wholeInterval, const Duration(seconds: 10));
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        const settings = PlaybackSettings();
        final copied = settings.copyWith(
          loopSentence: true,
          playbackSpeed: 2.0,
        );

        expect(copied.loopSentence, isTrue);
        expect(copied.playbackSpeed, 2.0);
        // 未修改字段保持原值
        expect(copied.sentenceLoopCount, 3);
        expect(copied.loopWhole, isFalse);
        expect(copied.showTranscript, isTrue);
      });
    });
  });
}
