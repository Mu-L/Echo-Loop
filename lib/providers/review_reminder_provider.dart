import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_tap_router_bridge.dart';
import '../services/review_reminder_service.dart';
import '../services/review_reminder_time_calculator.dart';

/// 通知点击桥接 Provider
final notificationTapRouterBridgeProvider =
    Provider<NotificationTapRouterBridge>((ref) {
      final bridge = NotificationTapRouterBridge();
      ref.onDispose(bridge.dispose);
      return bridge;
    });

/// 提醒时间计算策略 Provider
///
/// 当前默认固定每日 20:00，后续可替换为自适应实现。
final reviewReminderTimeCalculatorProvider =
    Provider<ReviewReminderTimeCalculator>((ref) {
      return const FixedDailyReminderTimeCalculator(hour: 20, minute: 0);
    });

/// 每日复习提醒服务 Provider
final reviewReminderServiceProvider = Provider<ReviewReminderService>((ref) {
  return ReviewReminderService(
    plugin: FlutterLocalNotificationsPlugin(),
    bridge: ref.watch(notificationTapRouterBridgeProvider),
    timeCalculator: ref.watch(reviewReminderTimeCalculatorProvider),
  );
});
