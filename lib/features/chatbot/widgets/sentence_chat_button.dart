/// 句子级 AI 助手入口按钮（AppBar action）。
///
/// 句子详情页与各学习任务页（逐句精听/难句跟读/难句复习/收藏复习）共用的
/// 单一入口来源：显隐开关、图标、ChatbotConfig 组装都集中在此，避免多处复制。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../remote_config/remote_config.dart';
import '../../remote_config/remote_config_providers.dart';
import '../chatbot_flags.dart';
import '../chatbot_sheet.dart';
import '../models/chatbot_config.dart';

/// AI 聊天入口显示规则：编译期开关负责硬停，远程开关负责运行期全球隐藏。
@visibleForTesting
bool shouldShowAiChatAssistantEntry({
  required bool chatbotEnabled,
  required bool remoteEnabled,
}) {
  return chatbotEnabled && remoteEnabled;
}

/// 句子 AI 助手入口按钮。
///
/// 开关关闭或 [sentenceText] 为空（句子未就绪）时自隐藏（渲染空 widget），
/// 调用方无需判空。点击时先执行 [onBeforeOpen]（任务页用来暂停自动推进，
/// 语义同各页设置按钮），再以 bottom sheet 打开 chatbot。
class SentenceChatButton extends ConsumerWidget {
  /// 当前句子文本；会话按句子内容归属（相同句子跨页面复用同一会话）。
  final String sentenceText;

  /// 打开面板前回调（可选）：任务页在此暂停自动推进/等待用户。
  final VoidCallback? onBeforeOpen;

  const SentenceChatButton({
    super.key,
    required this.sentenceText,
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 发布开关：编译期开关保留硬停能力，remote config 支持全球动态隐藏入口。
    final show = shouldShowAiChatAssistantEntry(
      chatbotEnabled: kChatbotEnabled,
      remoteEnabled: ref.watch(
        remoteFeatureEnabledProvider(RemoteFeature.aiChatAssistant),
      ),
    );
    if (!show || sentenceText.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    // 右侧留白：让 action 按钮不贴相邻控件/屏幕右缘，与左侧图标边距对称。
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        // 渐变多色图标，保留原始配色不做 colorFilter 染色。
        icon: SvgPicture.asset(
          'assets/icon/chat/use-ai-chat.svg',
          width: 24,
          height: 24,
        ),
        tooltip: l10n.chatOpenTooltip,
        onPressed: () {
          onBeforeOpen?.call();
          showChatbotSheet(
            context: context,
            config: ChatbotConfig(
              // 会话按句子内容归属：相同句子无论出现在哪都复用同一会话
              // （context 只传 sentenceText，位置无关）。用完整 text 而非
              // hashCode，避免 hash 碰撞导致不同句子串会话；sessionId 仅内存 key，长度无妨。
              sessionId: 'sentence:$sentenceText',
              endpoint: '/api/v1/stream/chat/sentence',
              context: {'sentence': sentenceText},
              title: l10n.chatSentenceTitle,
              inputPlaceholder: l10n.chatInputPlaceholder,
              contextSummary: sentenceText,
            ),
          );
        },
      ),
    );
  }
}
