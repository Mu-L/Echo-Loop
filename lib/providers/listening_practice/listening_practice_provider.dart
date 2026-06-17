import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/playback_settings.dart';
import '../../models/listening_practice_state.dart';
import '../../services/app_logger.dart';
import '../../services/storage_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../notification_permission_provider.dart';
import 'bookmark_manager.dart';
import 'playback_reducer.dart';
import 'playback_state_storage.dart';
import 'sentence_tracker.dart';

export '../../models/listening_practice_state.dart'
    show PlaylistMode, ListeningPracticeState;

part 'listening_practice_provider.g.dart';

/// 自由练习播放器的状态与业务编排。
///
/// 播放推进采用单一的「事件驱动」模型：底层 [AudioEngine]（多个功能共享的
/// 单实例 just_audio）只在「一句/整段播放完成」时回调 [_onPlayerStateChanged]，
/// 由纯函数 [decideNext] 决定下一步（重播 / 进下一句 / 回卷 / 停止）。
/// 不再有跨多次 await 持有状态的长协程，避免索引乱跳。
///
/// 真相源是 [ListeningPracticeState.currentFullIndex] /
/// [ListeningPracticeState.currentBookmarkIndex]，只在以下入口被修改：
/// 用户显式选句/上下句、连播时位置流推进（仅 gapless 模式）、完成事件归约器。
@Riverpod(keepAlive: true)
class ListeningPractice extends _$ListeningPractice {
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  /// 追踪正在进行的音频加载，避免重复调用时跳过未完成的加载
  Completer<void>? _loadingCompleter;

  /// 当前句已完成播放的次数（含刚结束这次）。进新句时归零。
  int _sentenceRepeatsDone = 0;

  /// 整篇已完成的遍数。换音频/重新起播时归零。
  ///
  /// gapless 模式下每次整篇 completed 即 +1；clip 模式下仅在真正整篇回卷
  /// （走到末尾并回到第 0 句）时 +1。
  int _wholeLoopsDone = 0;

  /// 完成事件归约重入保护：切 clip/seek 期间可能吐出多余 completed 事件，
  /// 该标志确保同一时刻只处理一次推进，避免递归推进。
  bool _advancing = false;

  /// LP 自己发起播放时持有的 AudioEngine sessionId。
  ///
  /// engine 的 position/playerState 流是全局共享的：句子讲解页等组件会旁路
  /// 驱动同一个 engine（`playRangeOnce`），并通过 `newSession()` 顶掉当前 session。
  /// 监听回调只处理「属于 LP 当前播放 session」的事件，外来 session 的事件一律
  /// 忽略——否则讲解页试听单句时，位置流会把 `currentFullIndex` 改成被试听的句子，
  /// 返回后主播放按钮就从那一句（常表现为第一句）重新开始。
  int _playbackSessionId = -1;

  @override
  ListeningPracticeState build() {
    _setupListeners();
    ref.onDispose(_disposeListeners);
    _loadSettings();
    return const ListeningPracticeState();
  }

  // --- 获取 AudioEngine ---
  AudioEngine get _engine => ref.read(audioEngineProvider.notifier);

  void _setupListeners() {
    // defer listener setup to after first build
    Future.microtask(() {
      _positionSub = _engine.absolutePositionStream.listen(_onPositionChanged);
      _playerStateSub = _engine.playerStateStream.listen(_onPlayerStateChanged);
    });
  }

  void _disposeListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
  }

  /// 暂停 stream 监听（学习模式期间调用，避免 LP 接管共享引擎）。
  void suspendListeners() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub = null;
    _playerStateSub = null;
  }

  /// 恢复 stream 监听（退出学习模式时调用）
  void resumeListeners() {
    _setupListeners();
  }

  /// 外部标注后同步书签状态（精听退出时调用）
  Future<void> syncBookmarks() async {
    if (state.currentAudioItem == null) return;
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await BookmarkManager.loadBookmarks(
      state.currentAudioItem!.id,
      dao: bookmarkDao,
    );
    BookmarkManager.updateSentenceBookmarkStatus(
      state.sentences,
      bookmarkedIndices,
    );
    state = state.copyWith(bookmarkedIndices: bookmarkedIndices);
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    state = state.copyWith(settings: settings);
  }

  // ===========================================================================
  // 播放模型辅助：播放列表 / 当前序号 / clip 形态
  // ===========================================================================

  /// 当前播放列表：全文模式=全部句子；收藏模式=收藏句子。
  List<Sentence> get _playable => state.playlistMode == PlaylistMode.bookmarks
      ? state.bookmarkedSentences
      : state.sentences;

  /// 是否使用 clip（逐句）播放形态。
  ///
  /// 单句循环需要逐句精确循环；收藏句不连续也必须逐句 seek。其余（全文 +
  /// 仅整篇循环/不循环）走整段无缝（gapless）播放。
  bool get _isClipMode =>
      state.playlistMode == PlaylistMode.bookmarks ||
      state.settings.loopSentence;

  /// 当前句在播放列表中的序号（0-based）。列表为空返回 null。
  int? get _currentPos {
    final playable = _playable;
    if (playable.isEmpty) return null;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final ci = state.currentBookmarkIndex;
      if (ci == null) return 0;
      final p = playable.indexWhere((s) => s.index == ci);
      return p == -1 ? 0 : p;
    } else {
      final ci = state.currentFullIndex;
      if (ci == null || ci < 0 || ci >= playable.length) return 0;
      return ci;
    }
  }

  // ===========================================================================
  // 引擎事件监听
  // ===========================================================================

  void _onPositionChanged(Duration absolutePosition) {
    _updateCurrentSentence(absolutePosition);
  }

  /// 整段（gapless）播放时由位置流推进当前句高亮。clip 模式下当前句只由
  /// 完成事件归约器修改，这里直接跳过。
  void _updateCurrentSentence(Duration position) {
    if (!_engine.isActiveSession(_playbackSessionId)) return;
    if (_isClipMode) return;
    if (!_engine.isPlaying) return;
    if (state.sentences.isEmpty) return;

    final newIndex = SentenceTracker.findSentenceIndexByPosition(
      state.sentences,
      position,
    );
    if (newIndex != -1 && newIndex != state.currentFullIndex) {
      state = state.copyWith(currentFullIndex: newIndex);
    }
  }

  void _onPlayerStateChanged(ja.PlayerState playerState) {
    if (playerState.processingState == ja.ProcessingState.completed) {
      // 仅处理 LP 自己 session 的完成事件；重入保护避免切 clip 期间递归推进。
      if (_engine.isActiveSession(_playbackSessionId) && !_advancing) {
        _advancing = true;
        unawaited(
          _advanceAfterCompletion().whenComplete(() => _advancing = false),
        );
      }
    }
    // 触发 isPlaying 变化的重建
    state = state.copyWith();
  }

  /// 一句/整段播放完成后的推进：调用纯函数决策，再驱动引擎。
  Future<void> _advanceAfterCompletion() async {
    final sessionId = _playbackSessionId;
    final playable = _playable;
    if (playable.isEmpty) return;
    final pos = _currentPos;
    if (pos == null) return;

    final s = state.settings;
    final isClip = _isClipMode;
    final isLast = pos >= playable.length - 1;

    if (isClip) {
      _sentenceRepeatsDone += 1;
    } else {
      // gapless：每次 completed 即完成一遍整篇。
      _wholeLoopsDone += 1;
    }

    final action = decideNext(
      isClipMode: isClip,
      loopSentence: s.loopSentence,
      sentenceLoopCount: s.sentenceLoopCount,
      sentenceInterval: s.sentenceInterval,
      loopWhole: s.loopWhole,
      wholeLoopCount: s.wholeLoopCount,
      wholeInterval: s.wholeInterval,
      sentenceRepeatsDone: _sentenceRepeatsDone,
      wholeLoopsDone: _wholeLoopsDone,
      currentPos: pos,
      playableCount: playable.length,
    );

    switch (action) {
      case StopPlayback():
        await _engine.stop();
      case ReplayCurrent(:final pauseBefore):
        await _delayInterval(pauseBefore);
        if (!_engine.isActiveSession(sessionId)) return;
        await _playPosition(pos);
      case GoToPosition(:final position, :final pauseBefore):
        await _delayInterval(pauseBefore);
        if (!_engine.isActiveSession(sessionId)) return;
        // clip 模式下，从末尾回卷到第 0 句意味着完成了一遍整篇。
        if (isClip && isLast && position == 0) {
          _wholeLoopsDone += 1;
        }
        _sentenceRepeatsDone = 0;
        await _playPosition(position);
    }
  }

  /// 按给定间隔停顿（来自 reducer 的决策，区分单句/整篇间隔）。
  Future<void> _delayInterval(Duration interval) async {
    if (interval > Duration.zero) {
      await Future.delayed(interval);
    }
  }

  // ===========================================================================
  // 加载音频
  // ===========================================================================

  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    // 同一音频且字幕未变化时跳过。
    if (!forceTranscriptReload &&
        state.currentAudioItem?.id == audioItem.id &&
        state.currentAudioItem?.transcriptPath == audioItem.transcriptPath &&
        state.currentAudioItem?.transcriptSource ==
            audioItem.transcriptSource) {
      if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
        return _loadingCompleter!.future;
      }
      return;
    }

    _loadingCompleter = Completer<void>();
    state = state.copyWith(isLoading: true);

    try {
      await stop();

      state = state.copyWith(
        currentAudioItem: audioItem,
        sentences: [],
        clearCurrentFullIndex: true,
        clearCurrentBookmarkIndex: true,
      );

      try {
        await _engine.loadAudio(audioItem, state.settings.playbackSpeed);
      } catch (e) {
        AppLogger.log('Player', '✗ 音频文件加载失败: $e');
        state = state.copyWith(clearCurrentAudioItem: true);
        rethrow;
      }

      final sentences = await _engine.loadTranscript(audioItem);

      final bookmarkDao = ref.read(bookmarkDaoProvider);
      final storedBookmarks = await BookmarkManager.loadBookmarks(
        audioItem.id,
        dao: bookmarkDao,
      );
      var bookmarkedIndices = Set<int>.from(storedBookmarks);

      final isFirstLoad = storedBookmarks.isEmpty;
      if (isFirstLoad) {
        final autoBookmarks = BookmarkManager.autoAddBracketBookmarks(
          sentences,
        );
        bookmarkedIndices = {...bookmarkedIndices, ...autoBookmarks};

        if (autoBookmarks.isNotEmpty) {
          for (final idx in autoBookmarks) {
            await BookmarkManager.addBookmarkToDb(
              audioItem.id,
              sentences[idx],
              dao: bookmarkDao,
            );
          }
        }
      }

      // 清理 [] 包裹的句子文本
      final cleanedSentences = <Sentence>[];
      for (int i = 0; i < sentences.length; i++) {
        final text = sentences[i].text.trim();
        if (text.startsWith('[') && text.endsWith(']') && text.length > 2) {
          cleanedSentences.add(
            sentences[i].copyWith(
              text: text.substring(1, text.length - 1).trim(),
            ),
          );
        } else {
          cleanedSentences.add(sentences[i]);
        }
      }

      for (var sentence in cleanedSentences) {
        sentence.isBookmarked = bookmarkedIndices.contains(sentence.index);
      }

      state = state.copyWith(
        sentences: cleanedSentences,
        bookmarkedIndices: bookmarkedIndices,
        currentFullIndex: 0,
      );

      await _restorePlaybackState(audioItem);

      if (state.sentences.isNotEmpty && state.currentFullIndex == null) {
        state = state.copyWith(currentFullIndex: 0);
        await _engine.seek(state.sentences[0].startTime);
      }
    } catch (e) {
      AppLogger.log('Player', '✗ loadAudio 失败: $e');
      state = state.copyWith(clearCurrentAudioItem: true);
    } finally {
      state = state.copyWith(isLoading: false);
      if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
        _loadingCompleter!.complete();
      }
    }
  }

  Future<void> _restorePlaybackState(AudioItem audioItem) async {
    final playbackStateDao = ref.read(playbackStateDaoProvider);
    final result = await PlaybackStateStorage.loadPlaybackState(
      audioItem.id,
      dao: playbackStateDao,
    );
    if (result == null) return;

    try {
      if (result.playlistMode != null) {
        state = state.copyWith(playlistMode: result.playlistMode);
      }
      if (result.position != null) {
        await _engine.seek(result.position!);
        // 从恢复位置反推当前句高亮
        final idx = SentenceTracker.findSentenceIndexByPosition(
          state.sentences,
          result.position!,
        );
        if (idx != -1) {
          state = state.copyWith(currentFullIndex: idx);
        }
      }
      AppLogger.log('Player', '✓ 恢复播放状态: ${audioItem.name}');
    } catch (e) {
      AppLogger.log('Player', '⚠ 恢复播放状态失败: $e');
    }
  }

  // ===========================================================================
  // 播放控制
  // ===========================================================================

  /// 主播放按钮：暂停后从精确位置续播（仅 gapless），否则按真相源 index 起播。
  Future<void> play() async {
    if (state.currentAudioItem == null) return;

    if (state.sentences.isEmpty) {
      await _engine.play();
      return;
    }

    _ensureValidIndex();
    if (state.playlistMode == PlaylistMode.bookmarks &&
        state.bookmarkedSentences.isEmpty) {
      return;
    }

    // 暂停后恢复：引擎仍停在 LP 自己的 session、gapless 形态、未播完、且有非零位置
    // → 从精确暂停位置续播。若期间被讲解页等外来 session 顶掉（clip/position 已被
    // 改写或已 stop），认领失效，按真相源 index 重新起播，而非续播被污染的位置。
    // 先校验 session 再读取引擎播放状态，避免无谓触达底层 player。
    if (_engine.isActiveSession(_playbackSessionId) && !_isClipMode) {
      final ps = _engine.audioPlayer.processingState;
      final resumable =
          ps != ja.ProcessingState.completed &&
          ps != ja.ProcessingState.idle &&
          _engine.currentPosition > Duration.zero;
      if (resumable) {
        await _engine.play();
        return;
      }
    }

    await _startCurrent();
  }

  /// 从当前真相源 index 起播（全新 session）。
  Future<void> _startCurrent() async {
    final playable = _playable;
    if (playable.isEmpty) return;

    _advancing = false;
    _sentenceRepeatsDone = 0;
    _wholeLoopsDone = 0;
    _playbackSessionId = _engine.newSession();

    final pos = _currentPos ?? 0;
    await _playPosition(pos);
  }

  /// 播放列表中第 [pos] 条：更新真相源 index 后按 clip/gapless 形态起播。
  Future<void> _playPosition(int pos) async {
    final playable = _playable;
    if (pos < 0 || pos >= playable.length) return;
    final s = playable[pos];

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: s.index,
        lastPlayedBookmarkIndex: s.index,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: s.index,
        lastPlayedFullIndex: s.index,
      );
    }

    if (_isClipMode) {
      await _engine.setClip(s.startTime, s.endTime);
      await _engine.seek(Duration.zero);
      await _engine.play();
    } else {
      await _engine.clearClip();
      await _engine.seek(s.startTime);
      await _engine.play();
    }
  }

  void _ensureValidIndex() {
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(currentBookmarkIndex: bookmarked.first.index);
      }
    } else {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        state = state.copyWith(currentFullIndex: 0);
      }
    }
  }

  Future<void> pause() async {
    await _engine.pause();
    // 引擎 pause 会自增 session 以失效在途回调；LP 仍是这个「已暂停引擎」的拥有者，
    // 故认领当前 session，使随后的 play() 能从精确暂停位置续播。若期间被讲解页等
    // 外来 session 顶掉，认领失效，play() 会按真相源 index 重新起播。
    _playbackSessionId = _engine.currentSessionId;
  }

  Future<void> stop() async {
    await _engine.stop();
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
  }

  /// 离开讲解页返回后，把共享引擎显式对齐回当前句起点。
  ///
  /// 讲解页旁路驱动并 stop 了引擎，会改写 clip/position。返回后调用本方法清除
  /// clip、seek 回当前句起点并认领 session，使主播放按钮从「原来的句子」继续，
  /// 而不依赖对引擎残留位置的启发式判断。
  Future<void> restorePosition() async {
    if (state.currentAudioItem == null) return;
    final pos = _currentPos;
    if (pos == null) return;
    final s = _playable[pos];
    await _engine.clearClip();
    await _engine.seek(s.startTime);
    _playbackSessionId = _engine.currentSessionId;
    _sentenceRepeatsDone = 0;
    _wholeLoopsDone = 0;
  }

  Future<void> seekAbsolute(Duration absolutePosition) async {
    if (state.sentences.isEmpty) {
      await _engine.clearClip();
      await _engine.seek(absolutePosition);
      return;
    }

    final wasPlaying = _engine.isPlaying;
    if (wasPlaying) await pause();

    await _engine.clearClip();
    await _engine.seek(absolutePosition);

    final newIndex = SentenceTracker.findSentenceIndexByPosition(
      state.sentences,
      absolutePosition,
    );
    if (newIndex != -1) {
      if (state.playlistMode == PlaylistMode.bookmarks) {
        if (state.bookmarkedIndices.contains(newIndex)) {
          state = state.copyWith(currentBookmarkIndex: newIndex);
        } else {
          final closest = SentenceTracker.findClosestBookmark(
            state.bookmarkedSentences,
            absolutePosition,
          );
          if (closest != null) {
            state = state.copyWith(currentBookmarkIndex: closest);
          }
        }
      } else {
        state = state.copyWith(currentFullIndex: newIndex);
      }
    }

    if (wasPlaying) {
      if (_isClipMode) {
        // clip 模式：从吸附到的目标句重新起播
        await _startCurrent();
      } else {
        // gapless：从拖动位置继续连续播放
        _advancing = false;
        _sentenceRepeatsDone = 0;
        _wholeLoopsDone = 0;
        _playbackSessionId = _engine.newSession();
        await _engine.play();
      }
    } else {
      // 未播放时，把引擎对齐到目标句起点便于显示
      final pos = _currentPos;
      if (pos != null) {
        await _engine.seek(_playable[pos].startTime);
      }
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(currentFullIndex: index, lastPlayedFullIndex: index);

    if (autoPlay) {
      await _startCurrent();
    } else {
      await _engine.clearClip();
      await _engine.seek(state.sentences[index].startTime);
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(
      currentBookmarkIndex: index,
      lastPlayedBookmarkIndex: index,
    );

    if (autoPlay) {
      await _startCurrent();
    } else {
      await _engine.clearClip();
      await _engine.seek(state.sentences[index].startTime);
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  Future<void> replayCurrentSentence() async {
    if (state.sentences.isEmpty) return;

    final int? lastPlayedIndex = state.playlistMode == PlaylistMode.bookmarks
        ? state.lastPlayedBookmarkIndex
        : state.lastPlayedFullIndex;
    if (lastPlayedIndex == null) return;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(currentBookmarkIndex: lastPlayedIndex);
    } else {
      state = state.copyWith(currentFullIndex: lastPlayedIndex);
    }
    await _startCurrent();
  }

  Future<void> nextSentence() async {
    if (state.sentences.isEmpty) return;

    late int newIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == state.currentBookmarkIndex,
      );
      if (pos == -1) {
        pos = 0;
      } else if (pos >= bookmarked.length - 1) {
        return;
      } else {
        pos++;
      }
      newIndex = bookmarked[pos].index;
    } else {
      if (state.currentFullIndex == null) {
        newIndex = 0;
      } else if (state.currentFullIndex! >= state.sentences.length - 1) {
        return;
      } else {
        newIndex = state.currentFullIndex! + 1;
      }
    }

    await _moveToIndex(newIndex);
  }

  Future<void> previousSentence() async {
    if (state.sentences.isEmpty) return;

    late int newIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == state.currentBookmarkIndex,
      );
      if (pos <= 0) return;
      pos--;
      newIndex = bookmarked[pos].index;
    } else {
      if (state.currentFullIndex == null) {
        newIndex = 0;
      } else if (state.currentFullIndex! <= 0) {
        return;
      } else {
        newIndex = state.currentFullIndex! - 1;
      }
    }

    await _moveToIndex(newIndex);
  }

  /// 上/下一句的公共落地：更新真相源 index，播放中则起播该句，否则对齐引擎。
  Future<void> _moveToIndex(int newIndex) async {
    final wasPlaying = _engine.isPlaying;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: newIndex,
        lastPlayedBookmarkIndex: newIndex,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: newIndex,
        lastPlayedFullIndex: newIndex,
      );
    }

    if (wasPlaying) {
      await _startCurrent();
    } else {
      await _engine.clearClip();
      await _engine.seek(state.sentences[newIndex].startTime);
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  Future<void> toggleBookmark(int index) async {
    final (
      isRemoving,
      indicesToRemove,
      nextIndex,
    ) = BookmarkManager.toggleBookmark(
      index,
      state.sentences,
      state.bookmarkedIndices,
      state.playlistMode == PlaylistMode.bookmarks,
    );

    // 埋点：收藏/取消收藏句子
    if (state.currentAudioItem != null) {
      final item = state.currentAudioItem!;
      final analyticsParams = {
        EventParams.audioId: item.id,
        EventParams.audioName: item.name,
        EventParams.sentenceIndex: index,
        EventParams.action: isRemoving ? 'remove' : 'add',
      };
      if (!isRemoving) {
        await ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkSentenceSaved,
              analyticsParams: analyticsParams,
            );
      } else {
        ref
            .read(analyticsServiceProvider)
            .track(Events.bookmarkToggle, analyticsParams);
      }
    }

    // 价值锚点：只在「添加收藏」时尝试触发通知权限 pre-prompt
    if (!isRemoving) {
      unawaited(
        ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
      );
    }

    final inBookmarksMode = state.playlistMode == PlaylistMode.bookmarks;
    final shouldResume =
        inBookmarksMode && _engine.isPlaying && nextIndex != null;

    if (inBookmarksMode && isRemoving && _engine.isPlaying) {
      await pause();
    }

    var newBookmarks = Set<int>.from(state.bookmarkedIndices);
    var newSentences = List<Sentence>.from(state.sentences);

    if (isRemoving) {
      final toRemove = indicesToRemove.isEmpty ? {index} : indicesToRemove;
      for (final idx in toRemove) {
        newBookmarks.remove(idx);
        if (idx >= 0 && idx < newSentences.length) {
          newSentences[idx] = newSentences[idx].copyWith(isBookmarked: false);
        }
      }

      if (inBookmarksMode) {
        if (nextIndex != null && nextIndex < newSentences.length) {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            currentBookmarkIndex: nextIndex,
          );
        } else {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            clearCurrentBookmarkIndex: true,
          );
          await _engine.clearClip();
          await stop();
        }
      } else {
        state = state.copyWith(
          bookmarkedIndices: newBookmarks,
          sentences: newSentences,
        );
      }
    } else {
      newBookmarks.add(index);
      newSentences[index] = newSentences[index].copyWith(isBookmarked: true);
      state = state.copyWith(
        bookmarkedIndices: newBookmarks,
        sentences: newSentences,
      );
    }

    if (state.currentAudioItem != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      if (isRemoving) {
        await BookmarkManager.removeBookmarksFromDb(
          state.currentAudioItem!.id,
          indicesToRemove,
          dao: bookmarkDao,
        );
      } else {
        await BookmarkManager.addBookmarkToDb(
          state.currentAudioItem!.id,
          state.sentences[index],
          dao: bookmarkDao,
        );
      }
    }

    // 收藏模式下移除当前句后，从下一收藏句继续播放
    if (inBookmarksMode &&
        shouldResume &&
        state.bookmarkedSentences.isNotEmpty) {
      await _startCurrent();
    }
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    final wasPlaying = _engine.isPlaying;
    final wasClip = _isClipMode;

    state = state.copyWith(settings: newSettings);
    await _engine.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);

    // clip/gapless 形态切换（如开/关单句循环、切收藏模式）需要从当前句重新起播；
    // 仅速度/次数/间隔等不改变形态的设置无需打断播放。
    if (wasPlaying && wasClip != _isClipMode) {
      await _startCurrent();
    }
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    if (state.playlistMode == mode) return;

    final wasPlaying = _engine.isPlaying;
    await pause();

    state = state.copyWith(playlistMode: mode);

    if (mode == PlaylistMode.full) {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        if (state.sentences.isNotEmpty) {
          state = state.copyWith(currentFullIndex: 0);
        }
      }
    } else {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) {
        await _engine.clearClip();
        return;
      }
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(currentBookmarkIndex: bookmarked.first.index);
      }
    }

    if (wasPlaying) {
      await _startCurrent();
    } else {
      final pos = _currentPos;
      await _engine.clearClip();
      if (pos != null) {
        await _engine.seek(_playable[pos].startTime);
      }
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  /// 重置播放位置到开头（供外部学习流程调用）
  void resetToBeginning() {
    if (state.sentences.isNotEmpty) {
      state = state.copyWith(currentFullIndex: 0);
    }
  }

  Future<void> saveCurrentPlaybackState() async {
    if (state.currentAudioItem == null) return;

    final playbackStateDao = ref.read(playbackStateDaoProvider);
    await PlaybackStateStorage.savePlaybackState(
      state.currentAudioItem!,
      _engine.audioPlayer,
      state,
      dao: playbackStateDao,
    );
  }
}
