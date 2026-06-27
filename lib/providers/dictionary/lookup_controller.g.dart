// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dictionaryLookupContextHash() =>
    r'43f7097e39da82a4cf96c1f62fedbbea7a1e7fa1';

/// 查词请求上下文（鉴权 + 目标语言），收敛为单一 provider 便于测试覆盖
///
/// Copied from [dictionaryLookupContext].
@ProviderFor(dictionaryLookupContext)
final dictionaryLookupContextProvider =
    AutoDisposeProvider<DictionaryLookupContext>.internal(
      dictionaryLookupContext,
      name: r'dictionaryLookupContextProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dictionaryLookupContextHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictionaryLookupContextRef =
    AutoDisposeProviderRef<DictionaryLookupContext>;
String _$dictionaryLookupControllerHash() =>
    r'5d43e6a224b2f1b72c35524316702bac0b3d95d3';

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

abstract class _$DictionaryLookupController
    extends BuildlessAutoDisposeNotifier<DictionaryLookupState> {
  late final String word;

  DictionaryLookupState build(String word);
}

/// 查词会话 controller（family by word，autoDispose）
///
/// Copied from [DictionaryLookupController].
@ProviderFor(DictionaryLookupController)
const dictionaryLookupControllerProvider = DictionaryLookupControllerFamily();

/// 查词会话 controller（family by word，autoDispose）
///
/// Copied from [DictionaryLookupController].
class DictionaryLookupControllerFamily extends Family<DictionaryLookupState> {
  /// 查词会话 controller（family by word，autoDispose）
  ///
  /// Copied from [DictionaryLookupController].
  const DictionaryLookupControllerFamily();

  /// 查词会话 controller（family by word，autoDispose）
  ///
  /// Copied from [DictionaryLookupController].
  DictionaryLookupControllerProvider call(String word) {
    return DictionaryLookupControllerProvider(word);
  }

  @override
  DictionaryLookupControllerProvider getProviderOverride(
    covariant DictionaryLookupControllerProvider provider,
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
  String? get name => r'dictionaryLookupControllerProvider';
}

/// 查词会话 controller（family by word，autoDispose）
///
/// Copied from [DictionaryLookupController].
class DictionaryLookupControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          DictionaryLookupController,
          DictionaryLookupState
        > {
  /// 查词会话 controller（family by word，autoDispose）
  ///
  /// Copied from [DictionaryLookupController].
  DictionaryLookupControllerProvider(String word)
    : this._internal(
        () => DictionaryLookupController()..word = word,
        from: dictionaryLookupControllerProvider,
        name: r'dictionaryLookupControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dictionaryLookupControllerHash,
        dependencies: DictionaryLookupControllerFamily._dependencies,
        allTransitiveDependencies:
            DictionaryLookupControllerFamily._allTransitiveDependencies,
        word: word,
      );

  DictionaryLookupControllerProvider._internal(
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
  DictionaryLookupState runNotifierBuild(
    covariant DictionaryLookupController notifier,
  ) {
    return notifier.build(word);
  }

  @override
  Override overrideWith(DictionaryLookupController Function() create) {
    return ProviderOverride(
      origin: this,
      override: DictionaryLookupControllerProvider._internal(
        () => create()..word = word,
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
  AutoDisposeNotifierProviderElement<
    DictionaryLookupController,
    DictionaryLookupState
  >
  createElement() {
    return _DictionaryLookupControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DictionaryLookupControllerProvider && other.word == word;
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
mixin DictionaryLookupControllerRef
    on AutoDisposeNotifierProviderRef<DictionaryLookupState> {
  /// The parameter `word` of this provider.
  String get word;
}

class _DictionaryLookupControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          DictionaryLookupController,
          DictionaryLookupState
        >
    with DictionaryLookupControllerRef {
  _DictionaryLookupControllerProviderElement(super.provider);

  @override
  String get word => (origin as DictionaryLookupControllerProvider).word;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
