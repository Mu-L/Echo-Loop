/// 意群拼接校验（客户端最终校验）
///
/// 与后端 `apps/app/app/api/v2/ai/sense-groups/validate-chunks.ts` 两段式一致：
/// - 快路径：`chunks.join('') == original`（chunk 用前导空格表达原文真实间距，直接 concat 还原）。
/// - 慢路径：剥掉所有空白和标点后比较字母数字内容（覆盖空格/标点漂移、trim 后的旧风格）。
///
/// 流式场景下无法在发帧前校验，故在流结束拿到完整结果时调用：校验失败则不落本地缓存
/// （允许重试重生成），镜像后端 onComplete「不合法不入库」语义。
library;

/// 剥掉所有空白与标点（Unicode 标点类 \p{P}），仅保留字母数字等内容字符。
final _wpPattern = RegExp(r'[\s\p{P}]', unicode: true);

String _stripWp(String s) => s.replaceAll(_wpPattern, '');

/// 校验意群 [chunks] 拼接是否能还原原句 [original]。
///
/// 空列表直接失败；快路径精确相等或慢路径剥空白+标点后相等均视为通过。
bool validateSenseGroupChunks(List<String> chunks, String original) {
  if (chunks.isEmpty) return false;
  final joined = chunks.join();
  if (joined == original) return true;
  return _stripWp(joined) == _stripWp(original);
}
