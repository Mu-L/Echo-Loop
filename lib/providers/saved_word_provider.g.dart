// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_word_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$savedWordDictEntriesHash() =>
    r'b03f0c8cf56f1fea9824c349a06c1f8b1bd7b8b4';

/// 收藏单词列表的批量字典条目
///
/// 监听 [savedWordListProvider]，当单词列表变化时批量查询所有字典释义。
/// 避免每个列表项独立异步查询导致释义延迟闪烁。
///
/// Copied from [savedWordDictEntries].
@ProviderFor(savedWordDictEntries)
final savedWordDictEntriesProvider =
    AutoDisposeFutureProvider<Map<String, DictEntry>>.internal(
      savedWordDictEntries,
      name: r'savedWordDictEntriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedWordDictEntriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedWordDictEntriesRef =
    AutoDisposeFutureProviderRef<Map<String, DictEntry>>;
String _$isWordSavedHash() => r'5f235a069e004d1666dcd75cef56a1dbde8a9a97';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 监听单个单词是否已收藏
///
/// Copied from [isWordSaved].
@ProviderFor(isWordSaved)
const isWordSavedProvider = IsWordSavedFamily();

/// 监听单个单词是否已收藏
///
/// Copied from [isWordSaved].
class IsWordSavedFamily extends Family<AsyncValue<bool>> {
  /// 监听单个单词是否已收藏
  ///
  /// Copied from [isWordSaved].
  const IsWordSavedFamily();

  /// 监听单个单词是否已收藏
  ///
  /// Copied from [isWordSaved].
  IsWordSavedProvider call(String word) {
    return IsWordSavedProvider(word);
  }

  @override
  IsWordSavedProvider getProviderOverride(
    covariant IsWordSavedProvider provider,
  ) {
    return call(provider.word);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isWordSavedProvider';
}

/// 监听单个单词是否已收藏
///
/// Copied from [isWordSaved].
class IsWordSavedProvider extends AutoDisposeStreamProvider<bool> {
  /// 监听单个单词是否已收藏
  ///
  /// Copied from [isWordSaved].
  IsWordSavedProvider(String word)
    : this._internal(
        (ref) => isWordSaved(ref as IsWordSavedRef, word),
        from: isWordSavedProvider,
        name: r'isWordSavedProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$isWordSavedHash,
        dependencies: IsWordSavedFamily._dependencies,
        allTransitiveDependencies: IsWordSavedFamily._allTransitiveDependencies,
        word: word,
      );

  IsWordSavedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.word,
  }) : super.internal();

  final String word;

  @override
  Override overrideWith(Stream<bool> Function(IsWordSavedRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: IsWordSavedProvider._internal(
        (ref) => create(ref as IsWordSavedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        word: word,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<bool> createElement() {
    return _IsWordSavedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsWordSavedProvider && other.word == word;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, word.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsWordSavedRef on AutoDisposeStreamProviderRef<bool> {
  /// The parameter `word` of this provider.
  String get word;
}

class _IsWordSavedProviderElement extends AutoDisposeStreamProviderElement<bool>
    with IsWordSavedRef {
  _IsWordSavedProviderElement(super.provider);

  @override
  String get word => (origin as IsWordSavedProvider).word;
}

String _$savedWordListHash() => r'928a109ee52d74a4b7b457094304340cc2dce3e0';

/// 收藏单词列表 Provider（流式）
///
/// 监听所有收藏单词的变化，按收藏时间倒序。
///
/// Copied from [SavedWordList].
@ProviderFor(SavedWordList)
final savedWordListProvider =
    StreamNotifierProvider<SavedWordList, List<SavedWord>>.internal(
      SavedWordList.new,
      name: r'savedWordListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedWordListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SavedWordList = StreamNotifier<List<SavedWord>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
