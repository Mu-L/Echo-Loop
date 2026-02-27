import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_io/io.dart' as io;

import 'notification_tap_router_bridge.dart';
import 'review_reminder_time_calculator.dart';

const int kDailyReviewSummaryNotificationId = 1001;
const String _reviewChannelId = 'daily_review_summary';
const String _reviewChannelName = 'Daily Review Reminder';
const String _reviewChannelDescription =
    'Daily summary reminder for review tasks';
const String _openStudyPayload = 'open_study_tasks';

/// 后台点击回调占位（系统可能在后台 isolate 触发）。
@pragma('vm:entry-point')
void reviewReminderBackgroundNotificationTap(NotificationResponse response) {}

/// 每日复习提醒服务
class ReviewReminderService {
  ReviewReminderService({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationTapRouterBridge bridge,
    required ReviewReminderTimeCalculator timeCalculator,
  }) : _plugin = plugin,
       _bridge = bridge,
       _timeCalculator = timeCalculator;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTapRouterBridge _bridge;
  final ReviewReminderTimeCalculator _timeCalculator;

  bool _initialized = false;
  bool _timezoneReady = false;

  bool get _supportsSystemNotification {
    if (kIsWeb) return false;
    return io.Platform.isIOS || io.Platform.isAndroid || io.Platform.isMacOS;
  }

  Future<void> init() async {
    if (_initialized) return;
    if (!_supportsSystemNotification) return;

    try {
      await _ensureTimezoneReady();

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            reviewReminderBackgroundNotificationTap,
      );

      await _requestPermissions();
      _initialized = true;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      _handlePayload(payload);
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable on this runtime');
    } catch (e) {
      debugPrint('ReviewReminderService.init error: $e');
    }
  }

  Future<void> syncDailyReminder({required int pendingTaskCount}) async {
    if (!_supportsSystemNotification) return;

    await init();
    if (!_initialized) return;

    if (pendingTaskCount <= 0) {
      await cancelDailyReminder();
      return;
    }

    final now = DateTime.now();
    final next = _timeCalculator.nextTriggerAt(now);
    final nextTz = tz.TZDateTime.from(next, tz.local);

    try {
      await _plugin.cancel(kDailyReviewSummaryNotificationId);
      await _plugin.zonedSchedule(
        kDailyReviewSummaryNotificationId,
        'Fluency',
        'You have $pendingTaskCount study task(s) waiting.',
        nextTz,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _reviewChannelId,
            _reviewChannelName,
            channelDescription: _reviewChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _openStudyPayload,
      );
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during schedule');
    } catch (e) {
      debugPrint('ReviewReminderService.syncDailyReminder error: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!_supportsSystemNotification) return;
    try {
      await _plugin.cancel(kDailyReviewSummaryNotificationId);
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during cancel');
    } catch (e) {
      debugPrint('ReviewReminderService.cancelDailyReminder error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _ensureTimezoneReady() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      debugPrint('ReviewReminderService: fallback timezone due to $e');
    }
    _timezoneReady = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handlePayload(String? payload) {
    if (payload == _openStudyPayload) {
      _bridge.emit(NotificationIntent.openStudyTasks);
    }
  }
}
