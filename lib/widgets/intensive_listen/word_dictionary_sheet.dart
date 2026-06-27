/// 词典查询底部弹窗
///
/// 点击单词时弹出。右上角下拉切换数据源（本地 / AI / Cambridge），
/// 内容区按选中源渲染对应结果。标题行的单词、发音、收藏跨源恒定。
/// 本组件是「组装器」：查词逻辑在 [DictionaryLookupController]，
/// 各源渲染在 dictionary/ 视图组件，本文件只负责布局与回调分发。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/sign_in_required_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../providers/dictionary/dictionary_registry.dart';
import '../../providers/dictionary/lookup_controller.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/saved_word_provider.dart';
import '../../services/dictionary/web_dictionary_source.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../animated_bookmark_icon.dart';
import '../common/text_context_menu.dart';
import '../dictionary/dictionary_result_view.dart';
import '../dictionary/source_switcher.dart';

/// 显示词典底部弹窗
///
/// [audioItemId]、[sentenceIndex]、[sentenceText] 为可选来源信息，
/// 用于收藏单词时记录来源。
Future<void> showWordDictionarySheet({
  required BuildContext context,
  required String word,
  String? audioItemId,
  int? sentenceIndex,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // 默认占屏幕 2/3；网页源可经拖拽指示条上拉放大，故 modal 上限放到 92%
    // 以容纳上拉后的高度。文本源仍内部限回 2/3、按内容自适应。
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => WordDictionarySheet(
      word: word,
      audioItemId: audioItemId,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText,
      sentenceStartMs: sentenceStartMs,
      sentenceEndMs: sentenceEndMs,
    ),
  );
}

/// 词典弹窗内容
class WordDictionarySheet extends ConsumerStatefulWidget {
  /// 查询的单词
  final String word;

  /// 来源音频 ID（可选）
  final String? audioItemId;

  /// 来源句子索引（可选）
  final int? sentenceIndex;

  /// 来源句子文本（可选）
  final String? sentenceText;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  const WordDictionarySheet({
    super.key,
    required this.word,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  ConsumerState<WordDictionarySheet> createState() =>
      _WordDictionarySheetState();
}

class _WordDictionarySheetState extends ConsumerState<WordDictionarySheet> {
  /// 弹窗滑入动画是否已结束。
  ///
  /// 滑入期间内容区不套 AnimatedSize/AnimatedSwitcher——否则缓存命中（L2）的
  /// 结果在滑入途中到达时，内容区高度增长动画会与滑入叠加，视觉上「闪烁一下」。
  /// 滑入期间内容直接定型（被滑入运动掩盖），滑入结束后才启用切换源的平滑过渡。
  bool _entered = false;

  /// 监听的弹窗路由滑入动画（用于在滑入结束时刷新启用过渡）
  Animation<double>? _routeAnimation;

  /// 网页源弹窗的当前高度（像素）。仅网页源使用：默认 2/3 屏高，
  /// 用户上拉拖拽指示条可放大、下拉可缩小（夹在 [_minSheetHeight] 与
  /// [_maxSheetHeight] 之间）。文本源不用此值（按内容自适应）。
  double? _sheetHeight;

  /// 网页源弹窗高度下限：屏高 40%
  double get _minSheetHeight => MediaQuery.sizeOf(context).height * 0.4;

  /// 网页源弹窗高度上限：屏高 92%（与 modal constraints 一致）
  double get _maxSheetHeight => MediaQuery.sizeOf(context).height * 0.92;

  /// 网页源弹窗默认高度：屏高 2/3
  double get _defaultSheetHeight => MediaQuery.sizeOf(context).height * 2 / 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anim = ModalRoute.of(context)?.animation;
    if (identical(anim, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = anim;
    if (anim == null || anim.status == AnimationStatus.completed) {
      _entered = true;
    } else {
      anim.addStatusListener(_onRouteAnimationStatus);
    }
  }

  /// 滑入完成后启用内容区过渡并刷新
  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_entered) {
      setState(() => _entered = true);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    super.dispose();
  }

  /// 当前选中源是否为网页词典源
  ///
  /// 网页源内容为固定像素的 WebView，需要弹窗给出明确高度并支持上拉放大；
  /// 文本源（本地/AI）按内容自适应，不走拖拽逻辑。
  bool _isWebSource(String sourceId) =>
      ref.read(dictionarySourcesByIdProvider)[sourceId] is WebDictionarySource;

  /// 拖拽指示条调整网页源弹窗高度：上拉（delta.dy<0）放大，下拉缩小。
  void _onHandleDrag(DragUpdateDetails details) {
    setState(() {
      final base = _sheetHeight ?? _defaultSheetHeight;
      _sheetHeight = (base - details.delta.dy)
          .clamp(_minSheetHeight, _maxSheetHeight)
          .toDouble();
    });
  }

  /// 清洗后的词形（去首尾标点），用于查询与展示
  String get _normalizedWord => widget.word.trim().replaceAll(
    RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'),
    '',
  );

  /// 标题展示词：优先用当前结果的 headword（本地原形/AI 词头），否则用清洗词形
  String _displayWord(DictionaryLookupState state) {
    final cur = state.current;
    if (cur is LookupLoaded) return cur.result.headword;
    return _normalizedWord;
  }

  /// 收藏用 lemma：优先用本地词典返回的原形，否则用清洗词形
  String _lemmaWord(DictionaryLookupState state) {
    final local = state.bySource['local'];
    if (local case LookupLoaded(result: final LocalDictResult r)) {
      return r.entry.word.toLowerCase();
    }
    return _normalizedWord.toLowerCase();
  }

  Future<void> _toggleSave(String lemma, bool currentlySaved) async {
    final notifier = ref.read(savedWordListProvider.notifier);
    if (currentlySaved) {
      await notifier.removeWord(lemma);
    } else {
      await notifier.saveWord(
        word: lemma,
        audioItemId: widget.audioItemId,
        sentenceIndex: widget.sentenceIndex,
        sentenceText: widget.sentenceText,
        sentenceStartMs: widget.sentenceStartMs,
        sentenceEndMs: widget.sentenceEndMs,
      );
    }
  }

  /// AI 源未登录时引导登录，登录成功后重试
  Future<void> _handleSignIn(String word) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.senseGroupSignInRequiredTitle,
      message: l10n.senseGroupSignInRequiredMessage,
    );
    if (ok) {
      ref.read(dictionaryLookupControllerProvider(word).notifier).retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = _normalizedWord;
    final controllerProvider = dictionaryLookupControllerProvider(word);
    final state = ref.watch(controllerProvider);
    final notifier = ref.read(controllerProvider.notifier);

    // 本地词典下载完成后，若当前选中本地源，自动重新查询
    ref.listen(dictionaryProvider, (prev, next) {
      if (next.status == DictionaryStatus.downloaded &&
          state.selectedSourceId == 'local') {
        notifier.retry();
      }
    });

    final lemma = _lemmaWord(state);
    final displayWord = _displayWord(state);
    final isWeb = _isWebSource(state.selectedSourceId);
    // AI 与网页源内容丰富，默认 2/3 屏高且可上拉放大；本地源内容短，按内容自适应。
    final isResizable = isWeb || state.selectedSourceId == 'ai';

    return SafeArea(
      child: SizedBox(
        key: const Key('dict_sheet_sizer'),
        // 可拉伸源用显式高度（默认 2/3，可拖拽指示条调整）；本地源按内容自适应。
        height: isResizable ? (_sheetHeight ?? _defaultSheetHeight) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            12,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示条：可拉伸源（AI/网页）时可上下拖拽调整弹窗高度
              _buildDragHandle(theme, isResizable),
              const SizedBox(height: 12),

            // 数据源选择：整体靠右，AI 快捷按钮紧贴切换器左侧、与其等高
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AiSourceButton(
                    selectedId: state.selectedSourceId,
                    onSelected: notifier.selectSource,
                  ),
                  const SizedBox(width: 8),
                  SourceSwitcher(
                    selectedId: state.selectedSourceId,
                    onSelected: notifier.selectSource,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 标题行：单词 + 发音 + 收藏（跨源恒定）
            _buildTitleRow(theme, displayWord, lemma),
            const SizedBox(height: AppSpacing.s),

              // 内容区：按选中源渲染。
              _buildResultArea(state, word, notifier, isWeb, isResizable),
            ],
          ),
        ),
      ),
    );
  }

  /// 内容区：按源类型决定填充策略。
  /// - 网页源（[isWeb]）：填满弹窗剩余高度且占满宽度，WebView 跟随上拉一起放大；
  /// - AI 源（[isResizable] 且非网页）：填满剩余高度并内部滚动，跟随上拉显示更多；
  /// - 本地源：按内容自适应、限高 2/3 并内部滚动。
  Widget _buildResultArea(
    DictionaryLookupState state,
    String word,
    DictionaryLookupController notifier,
    bool isWeb,
    bool isResizable,
  ) {
    final resultView = DictionaryResultView(
      sourceId: state.selectedSourceId,
      state: state.current,
      word: word,
      onRetry: notifier.retry,
      onSignIn: () => _handleSignIn(word),
    );
    if (isWeb) {
      // 填满剩余高度且占满宽度，交由 WebView 自身渲染滚动
      return Expanded(
        child: SizedBox(width: double.infinity, child: resultView),
      );
    }
    if (isResizable) {
      // AI 源：填满显式高度并在内部滚动
      return Expanded(
        child: SingleChildScrollView(
          child: _buildContent(state.selectedSourceId, resultView),
        ),
      );
    }
    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 2 / 3,
        ),
        child: SingleChildScrollView(
          child: _buildContent(state.selectedSourceId, resultView),
        ),
      ),
    );
  }

  /// 拖拽指示条。[draggable] 为 true（网页源）时包一层竖向拖拽手势，
  /// 上拉放大、下拉缩小弹窗；并扩大可点区域便于抓取。
  Widget _buildDragHandle(ThemeData theme, bool draggable) {
    final bar = Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    if (!draggable) return Center(child: bar);
    return GestureDetector(
      key: const Key('dict_drag_handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onHandleDrag,
      child: Center(
        // 扩大竖向命中区域，便于抓住指示条拖拽
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: bar,
        ),
      ),
    );
  }

  /// 内容区包装：滑入结束前直接返回内容（无过渡，被滑入运动掩盖）；
  /// 滑入结束后套 AnimatedSize + AnimatedSwitcher，使切换数据源时平滑过渡。
  Widget _buildContent(String sourceId, Widget content) {
    if (!_entered) return content;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(sourceId), child: content),
      ),
    );
  }

  /// 标题行：单词（可长按复制）+ TTS + 收藏
  Widget _buildTitleRow(ThemeData theme, String word, String lemma) {
    final isSaved = ref.watch(isWordSavedProvider(lemma)).valueOrNull ?? false;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPressStart: (d) =>
                TextContextMenu.show(context, d.globalPosition, word),
            onSecondaryTapDown: (d) =>
                TextContextMenu.show(context, d.globalPosition, word),
            child: Text(
              word,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => TtsService.instance.speak(word),
          icon: Icon(
            Icons.volume_up,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AnimatedBookmarkIcon(
          isSaved: isSaved,
          onPressed: () => _toggleSave(lemma, isSaved),
        ),
      ],
    );
  }
}
