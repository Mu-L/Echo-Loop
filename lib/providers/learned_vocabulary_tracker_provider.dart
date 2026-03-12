import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../services/learned_vocabulary_tracker.dart';
import 'study_stats_provider.dart';

/// 已学习词形追踪器 Provider
///
/// 统一管理异步批量写库和统计刷新。
final learnedVocabularyTrackerProvider = Provider<LearnedVocabularyTracker>((
  ref,
) {
  final dao = ref.watch(learnedWordFormDaoProvider);
  final tracker = LearnedVocabularyTracker(
    persistWordForms: dao.insertIfAbsentAll,
    onStatsUpdated: () {
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    },
    onError: (error, stackTrace) {
      debugPrint('LearnedVocabularyTracker flush failed: $error');
    },
  );

  ref.onDispose(() {
    unawaited(tracker.dispose());
  });

  return tracker;
});
