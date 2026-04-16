/// 埋点事件名常量
///
/// 集中管理所有事件名和参数名，编译时检查、IDE 自动补全、重命名安全。
/// 命名规范：`<对象>_<动作>`，全部小写下划线连接。
library;

/// 事件名常量
abstract class Events {
  // ── 页面浏览 ──
  /// 页面切换（使用 PostHog 官方 Mobile 保留名，兼容官方 Dashboard 模板）
  static const screenView = r'$screen';

  // ── 学习会话 ──
  /// 进入学习页面（避免 Firebase 保留名 session_start）
  static const learningStart = 'learning_start';

  /// 离开学习页面
  static const learningEnd = 'learning_end';

  // ── 盲听 ──
  /// 开始全文盲听
  static const blindListenStart = 'blind_listen_start';

  /// 盲听一遍完成
  static const blindListenComplete = 'blind_listen_complete';

  /// 盲听后设置难度
  static const blindListenDifficultySet = 'blind_listen_difficulty_set';

  // ── 精听 ──
  /// 开始逐句精听
  static const intensiveListenStart = 'intensive_listen_start';

  /// 精听完成全部句子
  static const intensiveListenComplete = 'intensive_listen_complete';

  // ── 跟读 ──
  /// 开始跟读
  static const listenRepeatStart = 'listen_repeat_start';

  /// 跟读完成全部句子
  static const listenRepeatComplete = 'listen_repeat_complete';

  // ── 复述 ──
  /// 开始段落复述
  static const retellStart = 'retell_start';

  /// 复述完成全部段落
  static const retellComplete = 'retell_complete';

  // ── 难句补练 ──
  /// 开始难句补练
  static const difficultPracticeStart = 'difficult_practice_start';

  /// 难句补练完成
  static const difficultPracticeComplete = 'difficult_practice_complete';

  // ── 学习进度 ──
  /// 首次学习四步骤全部完成
  static const firstLearnComplete = 'first_learn_complete';

  /// 学习阶段推进
  static const stageAdvance = 'stage_advance';

  // ── 内容创建 ──
  /// 创建合集
  static const collectionCreate = 'collection_create';

  /// 上传音频
  static const audioUpload = 'audio_upload';

  // ── AI 功能 ──
  /// 请求翻译
  static const translationRequested = 'translation_requested';

  /// 请求语法解析
  static const analysisRequested = 'analysis_requested';

  /// 请求意群拆分
  static const senseGroupRequested = 'sense_group_requested';

  // ── 字幕 ──
  /// 本地上传字幕成功
  static const subtitleUploaded = 'subtitle_uploaded';

  /// AI 转录任务发起
  static const transcriptionStarted = 'transcription_started';

  /// AI 转录任务完成
  static const transcriptionComplete = 'transcription_complete';

  // ── 复习会话 ──
  /// 收藏句子复习开始
  static const bookmarkReviewStart = 'bookmark_review_start';

  /// 收藏句子复习完成（dispose 时上报，含中途退出）
  static const bookmarkReviewComplete = 'bookmark_review_complete';

  /// 单词卡片复习开始
  static const flashcardStart = 'flashcard_start';

  /// 单词卡片复习完成（全部翻完）
  static const flashcardComplete = 'flashcard_complete';

  // ── 录音完成（三个界面共用，mode 参数区分） ──
  /// 单次录音评估完成
  static const recordingComplete = 'recording_complete';

  // ── 查单词 ──
  /// 用户查询单词
  static const wordLookup = 'word_lookup';

  // ── 设置 ──
  /// 提醒时间修改
  static const reminderUpdated = 'reminder_updated';

  /// 语音识别设置变更
  static const asrSettingChanged = 'asr_setting_changed';

  // ── 统计查看 ──
  /// 查看今日学习时长明细
  static const studyTimeViewed = 'study_time_viewed';
}

/// 事件参数名常量
abstract class EventParams {
  // ── 通用 ──
  static const audioId = 'audio_id';
  static const stage = 'stage';
  static const durationMs = 'duration_ms';

  // ── 页面浏览 ──
  /// PostHog 官方保留属性名，用于填充 Activity 流的 URL/Screen 列
  static const screenName = r'$screen_name';
  static const previousScreen = 'previous_screen';

  // ── 学习会话 ──
  static const isFreePractice = 'is_free_practice';

  // ── 盲听 ──
  static const difficulty = 'difficulty';
  static const passNumber = 'pass_number';

  // ── 精听 ──
  static const totalSentences = 'total_sentences';
  static const difficultCount = 'difficult_count';

  // ── 复述 ──
  static const totalParagraphs = 'total_paragraphs';

  // ── 学习进度 ──
  static const totalDurationMs = 'total_duration_ms';
  static const fromStage = 'from_stage';
  static const toStage = 'to_stage';

  // ── 录音评估 ──
  /// 录音来源界面：listen_repeat / retell / difficult_practice
  static const mode = 'mode';

  /// 录音评分（0.0 ~ 1.0，null 表示识别失败）
  static const score = 'score';

  // ── 查单词 ──
  static const word = 'word';

  // ── 设置 ──
  static const reminderEnabled = 'reminder_enabled';

  /// 格式 HH:mm（仅收藏复习提醒时间）
  static const reminderTime = 'reminder_time';

  static const asrEnabled = 'asr_enabled';

  /// 值：'platform'（系统 ASR）或 'offline'（本地模型）
  static const asrBackend = 'asr_backend';

  // ── 复习会话 ──
  static const totalCards = 'total_cards';
  static const totalSentencesCount = 'total_sentences_count';
}
