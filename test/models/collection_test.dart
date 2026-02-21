import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/collection.dart';

void main() {
  group('Collection', () {
    final now = DateTime(2026, 1, 15);

    Collection createSample() {
      return Collection(
        id: 'col-1',
        name: '我的合集',
        createdDate: now,
        isStarred: true,
      );
    }

    group('fromJson', () {
      test('完整字段解析', () {
        final json = {
          'id': 'col-1',
          'name': '我的合集',
          'createdDate': now.toIso8601String(),
          'isStarred': true,
          'audioItemIds': ['a1', 'a2'], // 旧格式兼容
        };
        final col = Collection.fromJson(json);

        expect(col.id, 'col-1');
        expect(col.name, '我的合集');
        expect(col.createdDate, now);
        expect(col.isStarred, true);
      });

      test('处理缺失可选字段', () {
        final json = {
          'id': 'col-1',
          'name': '测试',
          'createdDate': now.toIso8601String(),
        };
        final col = Collection.fromJson(json);

        expect(col.isStarred, isFalse);
      });
    });

    group('audioItemIdsFromJson（迁移用）', () {
      test('提取旧格式中的 audioItemIds', () {
        final json = {
          'id': 'col-1',
          'name': '测试',
          'createdDate': now.toIso8601String(),
          'audioItemIds': ['a1', 'a2', 'a3'],
        };
        expect(Collection.audioItemIdsFromJson(json), ['a1', 'a2', 'a3']);
      });

      test('缺失 audioItemIds 返回空列表', () {
        final json = {
          'id': 'col-1',
          'name': '测试',
          'createdDate': now.toIso8601String(),
        };
        expect(Collection.audioItemIdsFromJson(json), isEmpty);
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        final col = createSample();
        final copied = col.copyWith(name: '新合集', isStarred: false);

        expect(copied.name, '新合集');
        expect(copied.isStarred, isFalse);
        expect(copied.id, col.id);
      });
    });
  });
}
