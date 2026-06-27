// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visible_sources_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$visibleDictionarySourcesHash() =>
    r'c8f05c359f6bde0be1b978546df8f912912611ce';

/// 设置过滤后的可见源列表（顺序沿用注册表）
///
/// Copied from [visibleDictionarySources].
@ProviderFor(visibleDictionarySources)
final visibleDictionarySourcesProvider =
    AutoDisposeProvider<List<DictionarySource>>.internal(
      visibleDictionarySources,
      name: r'visibleDictionarySourcesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visibleDictionarySourcesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VisibleDictionarySourcesRef =
    AutoDisposeProviderRef<List<DictionarySource>>;
String _$resolvedDefaultSourceIdHash() =>
    r'721da550e6e56fa46568d6ab9b2af0bbf6c2764c';

/// 生效的默认源 id（默认源不可见时回退到第一个可见源）
///
/// Copied from [resolvedDefaultSourceId].
@ProviderFor(resolvedDefaultSourceId)
final resolvedDefaultSourceIdProvider = AutoDisposeProvider<String>.internal(
  resolvedDefaultSourceId,
  name: r'resolvedDefaultSourceIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$resolvedDefaultSourceIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ResolvedDefaultSourceIdRef = AutoDisposeProviderRef<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
