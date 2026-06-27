// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_registry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localDictionarySourceHash() =>
    r'7f19433abfbaec7bb6923e1b2c0be267a480c811';

/// 本地词典源
///
/// Copied from [localDictionarySource].
@ProviderFor(localDictionarySource)
final localDictionarySourceProvider = Provider<LocalDictionarySource>.internal(
  localDictionarySource,
  name: r'localDictionarySourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localDictionarySourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalDictionarySourceRef = ProviderRef<LocalDictionarySource>;
String _$aiDictionarySourceHash() =>
    r'219e794f0e8acedb4ea21898e42b6872614a52ba';

/// AI 词典源
///
/// 依赖延迟解析（lookup 时才读），避免枚举注册表即初始化数据库/网络栈。
///
/// Copied from [aiDictionarySource].
@ProviderFor(aiDictionarySource)
final aiDictionarySourceProvider = Provider<AiDictionarySource>.internal(
  aiDictionarySource,
  name: r'aiDictionarySourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$aiDictionarySourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AiDictionarySourceRef = ProviderRef<AiDictionarySource>;
String _$webDictionarySourcesHash() =>
    r'2d51291451c037ca1136580e5ed1375f3175b35c';

/// 网页词典源列表（由 [kWebDictConfigs] 配置生成：Cambridge / Oxford / ...）
///
/// Copied from [webDictionarySources].
@ProviderFor(webDictionarySources)
final webDictionarySourcesProvider =
    Provider<List<WebDictionarySource>>.internal(
      webDictionarySources,
      name: r'webDictionarySourcesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$webDictionarySourcesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WebDictionarySourcesRef = ProviderRef<List<WebDictionarySource>>;
String _$dictionarySourcesHash() => r'11248e4d2910146de80f1a65cf9a4e23048a91a4';

/// 全部数据源（顺序即默认排列/回退优先级）
///
/// Copied from [dictionarySources].
@ProviderFor(dictionarySources)
final dictionarySourcesProvider = Provider<List<DictionarySource>>.internal(
  dictionarySources,
  name: r'dictionarySourcesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dictionarySourcesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictionarySourcesRef = ProviderRef<List<DictionarySource>>;
String _$dictionarySourcesByIdHash() =>
    r'f6213e9ba90e3d004c98be7d6307aaff32d12dfd';

/// id → source 查找表
///
/// Copied from [dictionarySourcesById].
@ProviderFor(dictionarySourcesById)
final dictionarySourcesByIdProvider =
    Provider<Map<String, DictionarySource>>.internal(
      dictionarySourcesById,
      name: r'dictionarySourcesByIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dictionarySourcesByIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictionarySourcesByIdRef = ProviderRef<Map<String, DictionarySource>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
