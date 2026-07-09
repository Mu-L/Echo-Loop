/// 套餐折算计算（纯函数，无副作用，可单测）。
///
/// 付费墙年付卡片需要展示「立省 X%」与「≈ 每月价」两个转化提示。
/// 这些都不能硬编码——价格字符串（含币种符号）只能来自平台 SDK，且各地区
/// 币种符号位置、千分位/小数分隔符各异。本文件负责从本地化价格串里**容错地**
/// 解析金额，并据月付/年付价格折算。任何一步解析失败都返回空结果，UI 不展示折算，
/// 绝不显示一个算错的数字。
library;

import '../models/subscription_plan.dart';

/// 年付折算结果。
///
/// [perMonth] 为带币种符号的每月折合价字符串（如 `US$3.33`）；
/// [savePercent] 为相对「月付×12」的节省百分比（取整）。
/// 任一为 null 表示无法可靠计算，UI 应隐藏对应提示。
typedef YearlyValue = ({String? perMonth, int? savePercent});

/// 无折算结果（解析失败 / 数据不足时返回）。
const YearlyValue _empty = (perMonth: null, savePercent: null);

/// 根据月付与年付套餐计算年付的「每月折合价」与「节省百分比」。
///
/// 折扣按用户首年实际支付价计算：年付有付费首期促销时使用促销价，
/// 否则使用普通年付价。仅当价格都能解析为正数、且年付首年价确实比
/// 「月付×12」便宜时才返回有效值，否则返回 [_empty]。
YearlyValue computeYearlyValue(
  SubscriptionPlan monthly,
  SubscriptionPlan yearly,
) {
  final monthlyAmount = _parseAmount(monthly.priceString);
  final effectiveYearlyPrice =
      yearly.introOffer != null && !yearly.introOffer!.isFreeTrial
      ? yearly.introOffer!.priceString
      : yearly.priceString;
  final yearlyAmount = _parseAmount(effectiveYearlyPrice);
  if (monthlyAmount == null || yearlyAmount == null) return _empty;
  if (monthlyAmount <= 0 || yearlyAmount <= 0) return _empty;

  final fullPrice = monthlyAmount * 12;
  if (fullPrice <= yearlyAmount) return _empty; // 年付不便宜，不展示折算

  final savePercent = ((1 - yearlyAmount / fullPrice) * 100).round();
  final perMonthAmount = yearlyAmount / 12;
  final perMonth = _formatLike(effectiveYearlyPrice, perMonthAmount);
  return (perMonth: perMonth, savePercent: savePercent);
}

/// 从本地化价格串中提取数值金额，无法解析返回 null。
///
/// 处理思路：先取出所有数字与分隔符（`. ,`），再根据「最后一个分隔符」判定它是
/// 小数点还是千分位——最后一个分隔符后跟 1~2 位数字视为小数点，其余分隔符按千分位丢弃。
double? _parseAmount(String priceString) {
  final match = RegExp(r'[0-9][0-9.,]*').firstMatch(priceString);
  if (match == null) return null;
  final raw = match.group(0)!;

  final lastSep = raw.lastIndexOf(RegExp(r'[.,]'));
  if (lastSep == -1) return double.tryParse(raw);

  final decimals = raw.length - lastSep - 1;
  final intPart = raw.substring(0, lastSep).replaceAll(RegExp(r'[.,]'), '');
  final fracPart = raw.substring(lastSep + 1);
  // 最后一段超过 2 位，更可能是千分位（如 1,000）而非小数。
  if (decimals > 2) {
    return double.tryParse('$intPart$fracPart');
  }
  return double.tryParse('$intPart.$fracPart');
}

/// 按 [template] 的币种符号与位置，把 [amount] 格式化为同形态的价格串。
///
/// 例：template=`US$39.99`, amount=3.3325 → `US$3.33`；
/// template=`39,99 €`, amount=3.33 → `3.33 €`（保留符号在原侧）。
String _formatLike(String template, double amount) {
  final numberMatch = RegExp(r'[0-9][0-9.,]*').firstMatch(template);
  final value = amount.toStringAsFixed(2);
  if (numberMatch == null) return value;
  final prefix = template.substring(0, numberMatch.start).trim();
  final suffix = template.substring(numberMatch.end).trim();
  // 还原符号与数字的排版：前缀符号紧贴数字，后缀符号空一格（贴合常见币种写法）。
  return [
    if (prefix.isNotEmpty) prefix,
    value,
    if (suffix.isNotEmpty) ' $suffix',
  ].join();
}
