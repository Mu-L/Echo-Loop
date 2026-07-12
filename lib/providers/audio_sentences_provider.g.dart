// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_sentences_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioSentencesHash() => r'8b1e4ea41b12398926a1840c16ecfbffd1a26c98';

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

/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
///
/// Copied from [audioSentences].
@ProviderFor(audioSentences)
const audioSentencesProvider = AudioSentencesFamily();

/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
///
/// Copied from [audioSentences].
class AudioSentencesFamily extends Family<AsyncValue<List<Sentence>>> {
  /// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
  ///
  /// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
  /// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
  ///
  /// Copied from [audioSentences].
  const AudioSentencesFamily();

  /// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
  ///
  /// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
  /// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
  ///
  /// Copied from [audioSentences].
  AudioSentencesProvider call(String audioItemId) {
    return AudioSentencesProvider(audioItemId);
  }

  @override
  AudioSentencesProvider getProviderOverride(
    covariant AudioSentencesProvider provider,
  ) {
    return call(provider.audioItemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'audioSentencesProvider';
}

/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
///
/// Copied from [audioSentences].
class AudioSentencesProvider extends AutoDisposeFutureProvider<List<Sentence>> {
  /// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
  ///
  /// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
  /// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
  ///
  /// Copied from [audioSentences].
  AudioSentencesProvider(String audioItemId)
    : this._internal(
        (ref) => audioSentences(ref as AudioSentencesRef, audioItemId),
        from: audioSentencesProvider,
        name: r'audioSentencesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$audioSentencesHash,
        dependencies: AudioSentencesFamily._dependencies,
        allTransitiveDependencies:
            AudioSentencesFamily._allTransitiveDependencies,
        audioItemId: audioItemId,
      );

  AudioSentencesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.audioItemId,
  }) : super.internal();

  final String audioItemId;

  @override
  Override overrideWith(
    FutureOr<List<Sentence>> Function(AudioSentencesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AudioSentencesProvider._internal(
        (ref) => create(ref as AudioSentencesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        audioItemId: audioItemId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Sentence>> createElement() {
    return _AudioSentencesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioSentencesProvider && other.audioItemId == audioItemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, audioItemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AudioSentencesRef on AutoDisposeFutureProviderRef<List<Sentence>> {
  /// The parameter `audioItemId` of this provider.
  String get audioItemId;
}

class _AudioSentencesProviderElement
    extends AutoDisposeFutureProviderElement<List<Sentence>>
    with AudioSentencesRef {
  _AudioSentencesProviderElement(super.provider);

  @override
  String get audioItemId => (origin as AudioSentencesProvider).audioItemId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
