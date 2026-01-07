import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;
  bool _isInitialized = false;

  // Initialize notification services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize timezone for scheduled notifications
      tz.initializeTimeZones();
      
      // Firebase Cloud Messaging
      _firebaseMessaging = FirebaseMessaging.instance;
      
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      print('🔔 Notification permission: ${settings.authorizationStatus}');
      
      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      print('🔔 FCM Token: $token');
      
      // Save token for later use
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle when app is terminated
      FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);
      
      // Handle when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      _isInitialized = true;
      print('✅ Notification service initialized');
      
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  // Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings();
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        print('📱 Notification tapped: ${details.payload}');
      },
    );
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground message received: ${message.notification?.title}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'Home Service App',
      body: message.notification?.body ?? 'New notification',
      payload: message.data.toString(),
    );
  }

  // Handle initial message (app terminated)
  void _handleInitialMessage(RemoteMessage? message) {
    if (message != null) {
      print('📱 Initial message: ${message.notification?.title}');
    }
  }

  // Handle message when app is opened from background
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 App opened from notification: ${message.notification?.title}');
    // You can navigate to specific screen based on message data
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'home_service_channel',
      'Home Service Notifications',
      channelDescription: 'Notifications for bookings and reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Schedule a reminder notification
  Future<void> scheduleBookingReminder({
    required String bookingId,
    required String serviceType,
    required DateTime bookingDateTime,
    required String providerName,
    bool isDayBefore = true,
  }) async {
    try {
      final tz.TZDateTime scheduledTime = isDayBefore
          ? _getDayBeforeTime(bookingDateTime)
          : _getHourBeforeTime(bookingDateTime);
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Booking Reminders',
        channelDescription: 'Reminders for upcoming bookings',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.zonedSchedule(
        _generateNotificationId(bookingId, isDayBefore),
        'Booking Reminder',
        'Your $serviceType service with $providerName is ${isDayBefore ? 'tomorrow' : 'in 1 hour'}!',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        //uiLocalNotificationDateInterpretation: 
            //UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'booking_$bookingId',
      );
      
      print('✅ Reminder scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling reminder: $e');
    }
  }

  // Schedule both reminders (1 day before and 1 hour before)
  Future<void> scheduleAllReminders({
    required String bookingId,
    required String serviceType,
    required DateTime bookingDateTime,
    required String providerName,
  }) async {
    // Schedule 1 day before reminder
    await scheduleBookingReminder(
      bookingId: bookingId,
      serviceType: serviceType,
      bookingDateTime: bookingDateTime,
      providerName: providerName,
      isDayBefore: true,
    );
    
    // Schedule 1 hour before reminder
    await scheduleBookingReminder(
      bookingId: bookingId,
      serviceType: serviceType,
      bookingDateTime: bookingDateTime,
      providerName: providerName,
      isDayBefore: false,
    );
  }

  // Cancel all reminders for a booking
  Future<void> cancelReminders(String bookingId) async {
    try {
      // Cancel day-before reminder
      await _localNotifications.cancel(
        _generateNotificationId(bookingId, true),
      );
      
      // Cancel hour-before reminder
      await _localNotifications.cancel(
        _generateNotificationId(bookingId, false),
      );
      
      print('✅ Reminders cancelled for booking: $bookingId');
    } catch (e) {
      print('❌ Error cancelling reminders: $e');
    }
  }

  // Helper methods
  tz.TZDateTime _getDayBeforeTime(DateTime bookingTime) {
    final dayBefore = bookingTime.subtract(Duration(days: 1));
    return tz.TZDateTime.from(dayBefore, tz.local);
  }

  tz.TZDateTime _getHourBeforeTime(DateTime bookingTime) {
    final hourBefore = bookingTime.subtract(Duration(hours: 1));
    return tz.TZDateTime.from(hourBefore, tz.local);
  }

  int _generateNotificationId(String bookingId, bool isDayBefore) {
    // Generate unique ID based on booking ID and reminder type
    final baseId = bookingId.hashCode.abs();
    return isDayBefore ? baseId : baseId + 1;
  }

  // Test notification
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'Test Reminder',
      body: 'This is a test notification from Home Service App',
      payload: 'test',
    );
  }
}