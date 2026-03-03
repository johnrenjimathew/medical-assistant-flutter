import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart'; 
import 'package:medicine_reminder/main.dart';
import 'package:medicine_reminder/screens/reminder_alert_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  String? _pendingLaunchPayload;

  Future<void> init() async {
    debugPrint('[NotificationService] Initializing...');
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    tzdata.initializeTimeZones();
    
    try {
      final dynamic rawResult = await FlutterTimezone.getLocalTimezone();
      String timeZoneName = rawResult.toString().trim();
      final match = RegExp(r'([A-Za-z_]+(?:/[A-Za-z_]+)+)')
          .firstMatch(timeZoneName);
      if (match != null) {
        timeZoneName = match.group(1)!;
      }

      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Timezone successfully set to: $timeZoneName');
    } catch (e) {
      debugPrint('Error setting timezone: $e');
      debugPrint('Fallback to UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('app_icon');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);
    
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification Tapped! Payload: ${response.payload}');
        _handleNotificationPayload(response.payload);
      },
    );

    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleNotificationPayload(launchDetails?.notificationResponse?.payload);
    }
    
    await _notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  }

  void flushPendingLaunchPayload() {
    if (_pendingLaunchPayload == null) return;
    final payload = _pendingLaunchPayload!;
    _pendingLaunchPayload = null;
    _handleNotificationPayload(payload);
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length < 4) return;

    final medicineId = parts.first;
    final time = parts.last;
    final dosage = parts[parts.length - 2];
    final medicineName = parts.sublist(1, parts.length - 2).join('|');

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingLaunchPayload = payload;
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReminderAlertScreen(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          time: time,
        ),
      ),
    );
  }

  Future<void> requestExactAlarmPermission() async {
    debugPrint('[NotificationService] Requesting Exact Alarm Permission...');
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {

    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
      scheduledTime,
      tz.local,
    );

    print(' Scheduling ID: $id');
    print('   Raw Time: $scheduledTime');
    print('   Converted TZ Time: $tzScheduledTime');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medicine_channel_final_wake',      
      'Medicine Alerts',
      channelDescription: 'High priority alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      
      // CRITICAL FLAGS FOR SCHEDULING:
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      platformChannelSpecifics,
      
      androidScheduleMode: AndroidScheduleMode.alarmClock, 
      
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          
      payload: payload,
    );

    print('Successfully passed to Android Alarm Manager');
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    print('[NotificationService] Cancelled notification ID: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
