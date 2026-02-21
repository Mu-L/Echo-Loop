import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/app_database.dart' as db;
import '../database/providers.dart';
import '../models/collection.dart';
import 'audio_library_provider.dart';

part 'collection_provider.g.dart';

enum CollectionSortType { nameAsc, nameDesc, dateAsc, dateDesc }

enum CollectionViewMode { grid, list }

class CollectionState {
  final List<Collection> rawCollections;
  final bool isLoading;
  final CollectionViewMode viewMode;
  final CollectionSortType sortType;

  /// 缓存每个合集的音频 ID 列表（从 junction 表加载）
  final Map<String, List<String>> audioIdsMap;

  const CollectionState({
    this.rawCollections = const [],
    this.isLoading = false,
    this.viewMode = CollectionViewMode.list,
    this.sortType = CollectionSortType.dateDesc,
    this.audioIdsMap = const {},
  });

  bool get isEmpty => rawCollections.isEmpty;

  /// 获取合集的音频 ID 列表
  List<String> getAudioIds(String collectionId) {
    return audioIdsMap[collectionId] ?? [];
  }

  /// 获取合集的音频数量
  int getAudioCount(String collectionId) {
    return audioIdsMap[collectionId]?.length ?? 0;
  }

  List<Collection> get collections {
    final sorted = List<Collection>.from(rawCollections);
    switch (sortType) {
      case CollectionSortType.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case CollectionSortType.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
      case CollectionSortType.dateAsc:
        sorted.sort((a, b) => a.createdDate.compareTo(b.createdDate));
      case CollectionSortType.dateDesc:
        sorted.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    }
    return sorted;
  }

  CollectionState copyWith({
    List<Collection>? rawCollections,
    bool? isLoading,
    CollectionViewMode? viewMode,
    CollectionSortType? sortType,
    Map<String, List<String>>? audioIdsMap,
  }) {
    return CollectionState(
      rawCollections: rawCollections ?? this.rawCollections,
      isLoading: isLoading ?? this.isLoading,
      viewMode: viewMode ?? this.viewMode,
      sortType: sortType ?? this.sortType,
      audioIdsMap: audioIdsMap ?? this.audioIdsMap,
    );
  }
}

@Riverpod(keepAlive: true)
class CollectionList extends _$CollectionList {
  @override
  CollectionState build() {
    return const CollectionState();
  }

  Future<void> loadCollections() async {
    state = state.copyWith(isLoading: true);

    final dao = ref.read(collectionDaoProvider);
    final dbCollections = await dao.getAllActive();

    final collections = dbCollections
        .map(
          (row) => Collection(
            id: row.id,
            name: row.name,
            createdDate: row.createdDate,
            isStarred: row.isStarred,
          ),
        )
        .toList();

    // 加载每个合集的音频 ID 列表
    final audioIdsMap = <String, List<String>>{};
    for (final c in collections) {
      audioIdsMap[c.id] = await dao.getAudioIds(c.id);
    }

    state = state.copyWith(
      rawCollections: collections,
      isLoading: false,
      audioIdsMap: audioIdsMap,
    );

    // 清理合集中引用了已不存在的音频 ID
    await _cleanupStaleAudioIds();
  }

  /// 清理合集中引用了已不存在的音频 ID
  Future<void> _cleanupStaleAudioIds() async {
    final libraryNotifier = ref.read(audioLibraryProvider.notifier);
    final collectionDao = ref.read(collectionDaoProvider);

    for (final collection in state.rawCollections) {
      final audioIds = await collectionDao.getAudioIds(collection.id);
      final invalidIds = audioIds
          .where((id) => libraryNotifier.getItemById(id) == null)
          .toList();

      for (final invalidId in invalidIds) {
        await collectionDao.removeAudio(collection.id, invalidId);
      }
    }
  }

  Future<void> createCollection(String name) async {
    final now = DateTime.now();
    final collection = Collection(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: now,
    );
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
    );
    await _upsertCollection(collection);
  }

  Future<void> deleteCollection(String id) async {
    state = state.copyWith(
      rawCollections: state.rawCollections.where((c) => c.id != id).toList(),
    );
    final dao = ref.read(collectionDaoProvider);
    await dao.hardDelete(id);
  }

  Future<void> renameCollection(String id, String newName) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(name: newName);
      state = state.copyWith(rawCollections: collections);
      await _upsertCollection(collections[index]);
    }
  }

  Future<void> toggleStar(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isStarred: !collections[index].isStarred,
      );
      state = state.copyWith(rawCollections: collections);
      await _upsertCollection(collections[index]);
    }
  }

  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    final dao = ref.read(collectionDaoProvider);
    await dao.addAudio(collectionId, audioId);

    // 更新缓存
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[collectionId] ?? []);
    if (!ids.contains(audioId)) {
      ids.add(audioId);
      newMap[collectionId] = ids;
      state = state.copyWith(audioIdsMap: newMap);
    }
  }

  Future<void> removeAudioFromCollection(
    String collectionId,
    String audioId,
  ) async {
    final dao = ref.read(collectionDaoProvider);
    await dao.removeAudio(collectionId, audioId);

    // 更新缓存
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[collectionId] ?? []);
    ids.remove(audioId);
    newMap[collectionId] = ids;
    state = state.copyWith(audioIdsMap: newMap);
  }

  /// 从所有合集中移除指定音频的引用（当音频从音频库删除时调用）
  /// CASCADE 已自动清理 junction 表，此方法仅更新内存缓存
  Future<void> removeAudioFromAllCollections(String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    for (final key in newMap.keys) {
      newMap[key] = List<String>.from(newMap[key]!)..remove(audioId);
    }
    state = state.copyWith(audioIdsMap: newMap);
  }

  /// 获取合集中的音频 ID 列表
  Future<List<String>> getAudioIdsForCollection(String collectionId) async {
    final dao = ref.read(collectionDaoProvider);
    return dao.getAudioIds(collectionId);
  }

  /// 获取合集中的音频数量
  Future<int> getAudioCountForCollection(String collectionId) async {
    final dao = ref.read(collectionDaoProvider);
    return dao.getAudioCount(collectionId);
  }

  Collection? getCollectionById(String id) {
    try {
      return state.rawCollections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == CollectionViewMode.grid
          ? CollectionViewMode.list
          : CollectionViewMode.grid,
    );
  }

  void setSortType(CollectionSortType type) {
    state = state.copyWith(sortType: type);
  }

  /// 将 Collection 模型写入 Drift 数据库
  Future<void> _upsertCollection(Collection collection) async {
    final dao = ref.read(collectionDaoProvider);
    await dao.upsert(
      db.CollectionsCompanion(
        id: Value(collection.id),
        name: Value(collection.name),
        createdDate: Value(collection.createdDate),
        isStarred: Value(collection.isStarred),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
