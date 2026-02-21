import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/providers/collection_provider.dart';

void main() {
  group('CollectionState', () {
    final now = DateTime(2026, 1, 15);

    Collection createCollection({
      required String id,
      required String name,
      DateTime? createdDate,
      bool isStarred = false,
    }) {
      return Collection(
        id: id,
        name: name,
        createdDate: createdDate ?? now,
        isStarred: isStarred,
      );
    }

    group('默认值', () {
      test('所有默认值符合预期', () {
        const state = CollectionState();

        expect(state.rawCollections, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.viewMode, CollectionViewMode.list);
        expect(state.sortType, CollectionSortType.dateDesc);
        expect(state.isEmpty, isTrue);
      });
    });

    group('isEmpty', () {
      test('有合集时返回 false', () {
        final state = CollectionState(
          rawCollections: [createCollection(id: '1', name: '测试')],
        );
        expect(state.isEmpty, isFalse);
      });
    });

    group('collections getter 排序', () {
      late List<Collection> rawCollections;

      setUp(() {
        rawCollections = [
          createCollection(
            id: '1',
            name: 'B集',
            createdDate: DateTime(2026, 1, 10),
          ),
          createCollection(
            id: '2',
            name: 'A集',
            createdDate: DateTime(2026, 1, 15),
          ),
          createCollection(
            id: '3',
            name: 'C集',
            createdDate: DateTime(2026, 1, 12),
          ),
        ];
      });

      test('nameAsc 按名称升序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.nameAsc,
        );
        final sorted = state.collections;
        expect(sorted[0].name, 'A集');
        expect(sorted[1].name, 'B集');
        expect(sorted[2].name, 'C集');
      });

      test('nameDesc 按名称降序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.nameDesc,
        );
        final sorted = state.collections;
        expect(sorted[0].name, 'C集');
        expect(sorted[1].name, 'B集');
        expect(sorted[2].name, 'A集');
      });

      test('dateAsc 按日期升序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.dateAsc,
        );
        final sorted = state.collections;
        expect(sorted[0].id, '1'); // 1月10日
        expect(sorted[1].id, '3'); // 1月12日
        expect(sorted[2].id, '2'); // 1月15日
      });

      test('dateDesc 按日期降序', () {
        final state = CollectionState(
          rawCollections: rawCollections,
          sortType: CollectionSortType.dateDesc,
        );
        final sorted = state.collections;
        expect(sorted[0].id, '2'); // 1月15日
        expect(sorted[1].id, '3'); // 1月12日
        expect(sorted[2].id, '1'); // 1月10日
      });

    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        const state = CollectionState();
        final copied = state.copyWith(
          isLoading: true,
          sortType: CollectionSortType.nameAsc,
        );

        expect(copied.isLoading, isTrue);
        expect(copied.sortType, CollectionSortType.nameAsc);
        expect(copied.viewMode, CollectionViewMode.list);
      });
    });
  });
}
