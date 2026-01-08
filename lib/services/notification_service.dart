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

  // Notification types
  static const String TYPE_BOOKING_REMINDER = 'booking_reminder';
  static const String TYPE_STATUS_CHANGE = 'status_change';
  static const String TYPE_PENDING_EXPIRY = 'pending_expiry';
  static const String TYPE_SERVICE_TIME = 'service_time';
  static const String TYPE_NEW_BOOKING = 'new_booking';

  // User roles
  static const String ROLE_CUSTOMER = 'customer';
  static const String ROLE_PROVIDER = 'provider';

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

  // Initialize local notifications plugin with multiple channels
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    // Create notification channels for different types
    const AndroidNotificationChannel bookingChannel = AndroidNotificationChannel(
      'booking_channel',
      'Booking Notifications',
      description: 'Notifications for booking status updates',
      importance: Importance.high,
    );
    
    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Reminder Notifications',
      description: 'Notifications for booking reminders',
      importance: Importance.high,
    );
    
    const AndroidNotificationChannel providerChannel = AndroidNotificationChannel(
      'provider_channel',
      'Provider Notifications',
      description: 'Notifications for service providers',
      importance: Importance.high,
    );
    
    // Create channels for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(bookingChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(providerChannel);

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
        _handleNotificationTap(details.payload);
      },
    );
  }

  // Handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    // Parse payload and navigate accordingly
    print('🔗 Notification payload: $payload');
    
    // You can add navigation logic here based on payload
    // Example: booking_123 or status_update_456
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground message received: ${message.notification?.title}');
    print('📱 Message data: ${message.data}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'Home Service App',
      body: message.notification?.body ?? 'New notification',
      payload: message.data.toString(),
      notificationType: message.data['type'] ?? TYPE_STATUS_CHANGE,
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

  // Show local notification with type-specific channel
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String notificationType = TYPE_STATUS_CHANGE,
  }) async {
    String channelId = 'booking_channel';
    String channelName = 'Booking Notifications';
    
    // Set channel based on notification type
    switch (notificationType) {
      case TYPE_BOOKING_REMINDER:
      case TYPE_SERVICE_TIME:
        channelId = 'reminder_channel';
        channelName = 'Reminder Notifications';
        break;
      case TYPE_PENDING_EXPIRY:
      case TYPE_NEW_BOOKING:
        channelId = 'provider_channel';
        channelName = 'Provider Notifications';
        break;
      default:
        channelId = 'booking_channel';
        channelName = 'Booking Notifications';
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications for home service app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ========== CUSTOMER NOTIFICATIONS ==========

  // Schedule all customer reminders for a booking
  Future<void> scheduleCustomerReminders({
    required String bookingId,
    required String serviceType,
    required DateTime bookingDateTime,
    required String providerName,
    required String customerName,
  }) async {
    try {
      // Schedule 1 day before reminder
      await _scheduleReminder(
        bookingId: bookingId,
        title: 'Booking Reminder',
        body: 'Hi $customerName! Your $serviceType service with $providerName is tomorrow!',
        scheduledTime: _getDayBeforeTime(bookingDateTime),
        notificationType: TYPE_BOOKING_REMINDER,
        payload: 'customer_reminder_day_before_$bookingId',
      );
      
      // Schedule 1 hour before reminder
      await _scheduleReminder(
        bookingId: bookingId,
        title: 'Service Starting Soon',
        body: 'Hi $customerName! Your $serviceType service starts in 1 hour.',
        scheduledTime: _getHourBeforeTime(bookingDateTime),
        notificationType: TYPE_BOOKING_REMINDER,
        payload: 'customer_reminder_hour_before_$bookingId',
      );
      
      // Schedule at exact time
      await _scheduleReminder(
        bookingId: bookingId,
        title: 'Service Time',
        body: 'Your $serviceType service with $providerName is starting now!',
        scheduledTime: _getExactTime(bookingDateTime),
        notificationType: TYPE_SERVICE_TIME,
        payload: 'customer_service_time_$bookingId',
      );
      
      print('✅ Customer reminders scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling customer reminders: $e');
    }
  }

  // Send booking status change notification to customer
  Future<void> sendCustomerStatusUpdate({
    required String bookingId,
    required String serviceType,
    required String oldStatus,
    required String newStatus,
    required String providerName,
    String? additionalInfo,
  }) async {
    final statusMessages = {
      'pending_accepted': 'Your booking has been accepted!',
      'pending_rejected': 'Your booking has been declined',
      'accepted_completed': 'Your service has been completed successfully!',
      'accepted_cancelled': 'Your booking has been cancelled',
      'pending_cancelled': 'Booking request cancelled',
    };

    final key = '${oldStatus}_$newStatus';
    final message = statusMessages[key] ?? 'Booking status updated to $newStatus';
    
    await _showLocalNotification(
      title: 'Booking Status Update',
      body: '$message for $serviceType with $providerName. ${additionalInfo ?? ''}',
      payload: 'customer_status_$bookingId',
      notificationType: TYPE_STATUS_CHANGE,
    );
  }

  // ========== PROVIDER NOTIFICATIONS ==========

  // Send new booking notification to provider
  Future<void> sendProviderNewBooking({
    required String bookingId,
    required String serviceType,
    required String customerName,
    required DateTime bookingDateTime,
    required String providerName,
  }) async {
    final formattedDate = _formatDateTime(bookingDateTime);
    
    await _showLocalNotification(
      title: 'New Booking Request',
      body: 'Hi $providerName! You have a new $serviceType booking from $customerName on $formattedDate',
      payload: 'provider_new_booking_$bookingId',
      notificationType: TYPE_NEW_BOOKING,
    );
  }

  // Schedule pending booking expiry reminder for providers
  Future<void> scheduleProviderPendingExpiry({
    required String bookingId,
    required String serviceType,
    required DateTime bookingDate,
    required String customerName,
    required String providerName,
  }) async {
    try {
      // Schedule 1 day before booking date (if still pending)
      await _scheduleReminder(
        bookingId: bookingId,
        title: 'Pending Booking Expiry',
        body: 'Hi $providerName! You have a pending $serviceType booking from $customerName tomorrow. Please respond soon.',
        scheduledTime: _getDayBeforeTime(bookingDate),
        notificationType: TYPE_PENDING_EXPIRY,
        payload: 'provider_pending_expiry_$bookingId',
      );
      
      print('✅ Provider pending expiry reminder scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling provider expiry reminder: $e');
    }
  }

  // Schedule service reminders for provider
  Future<void> scheduleProviderReminders({
    required String bookingId,
    required String serviceType,
    required DateTime bookingDateTime,
    required String customerName,
    required String providerName,
  }) async {
    try {
      // Schedule 1 day before reminder
      await _scheduleReminder(
        bookingId: bookingId,
        title: 'Service Reminder',
        body: 'Hi $providerName! You have a $serviceType service for $customerName tomorrow.',
        scheduledTime: _getDayBeforeTime(bookingDateTime),
        notificationType: TYPE_BOOKING_REMINDER,
        payload: 'provider_reminder_day_before_$bookingId',
      );
      
      // Schedule 1 hour before reminder
      await _scheduleReminder(
        bookingId: bookingId,
        title: 'Service Starting Soon',
        body: 'Hi $providerName! Your $serviceType service for $customerName starts in 1 hour.',
        scheduledTime: _getHourBeforeTime(bookingDateTime),
        notificationType: TYPE_BOOKING_REMINDER,
        payload: 'provider_reminder_hour_before_$bookingId',
      );
      
      print('✅ Provider reminders scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling provider reminders: $e');
    }
  }

  // Send booking status change notification to provider
  Future<void> sendProviderStatusUpdate({
    required String bookingId,
    required String serviceType,
    required String oldStatus,
    required String newStatus,
    required String customerName,
    String? additionalInfo,
  }) async {
    final statusMessages = {
      'pending_accepted': 'Customer accepted your offer!',
      'pending_rejected': 'Customer declined your offer',
      'accepted_cancelled': 'Customer cancelled the booking',
      'accepted_completed': 'Service marked as completed',
    };

    final key = '${oldStatus}_$newStatus';
    final message = statusMessages[key] ?? 'Booking status updated to $newStatus';
    
    await _showLocalNotification(
      title: 'Booking Update',
      body: '$message for $serviceType with $customerName. ${additionalInfo ?? ''}',
      payload: 'provider_status_$bookingId',
      notificationType: TYPE_STATUS_CHANGE,
    );
  }

  // ========== HELPER METHODS ==========

  // Generic schedule reminder method
  Future<void> _scheduleReminder({
    required String bookingId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String notificationType,
    required String payload,
  }) async {
    try {
      if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        print('⚠️ Cannot schedule reminder in the past: $bookingId');
        return;
      }

      String channelId = 'reminder_channel';
      switch (notificationType) {
        case TYPE_PENDING_EXPIRY:
        case TYPE_NEW_BOOKING:
          channelId = 'provider_channel';
          break;
        case TYPE_STATUS_CHANGE:
          channelId = 'booking_channel';
          break;
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        notificationType == TYPE_BOOKING_REMINDER ? 'Reminder Notifications' : 
          notificationType == TYPE_PENDING_EXPIRY ? 'Provider Notifications' : 'Booking Notifications',
        channelDescription: 'Scheduled notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.zonedSchedule(
        _generateNotificationId(bookingId, title),
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      
      print('✅ Scheduled: $title for $bookingId at $scheduledTime');
      
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  // Cancel all reminders for a booking
  Future<void> cancelReminders(String bookingId) async {
    try {
      // Cancel all variations of this booking ID
      final variations = [
        'customer_reminder_day_before_$bookingId',
        'customer_reminder_hour_before_$bookingId',
        'customer_service_time_$bookingId',
        'provider_pending_expiry_$bookingId',
        'provider_reminder_day_before_$bookingId',
        'provider_reminder_hour_before_$bookingId',
        'customer_status_$bookingId',
        'provider_status_$bookingId',
        'provider_new_booking_$bookingId',
      ];
      
      // Get all pending notifications
      final pendingNotifications = await _localNotifications.pendingNotificationRequests();
      
      for (final notification in pendingNotifications) {
        if (variations.any((variation) => notification.payload?.contains(variation) == true)) {
          await _localNotifications.cancel(notification.id);
        }
      }
      
      print('✅ All reminders cancelled for booking: $bookingId');
    } catch (e) {
      print('❌ Error cancelling reminders: $e');
    }
  }

  // Cancel specific notification by payload
  Future<void> cancelNotificationByPayload(String payloadPattern) async {
    try {
      final pendingNotifications = await _localNotifications.pendingNotificationRequests();
      
      for (final notification in pendingNotifications) {
        if (notification.payload?.contains(payloadPattern) == true) {
          await _localNotifications.cancel(notification.id);
        }
      }
    } catch (e) {
      print('❌ Error cancelling notification: $e');
    }
  }

  // Time helpers
  tz.TZDateTime _getDayBeforeTime(DateTime bookingTime) {
    final dayBefore = bookingTime.subtract(Duration(days: 1));
    return tz.TZDateTime.from(dayBefore, tz.local);
  }

  tz.TZDateTime _getHourBeforeTime(DateTime bookingTime) {
    final hourBefore = bookingTime.subtract(Duration(hours: 1));
    return tz.TZDateTime.from(hourBefore, tz.local);
  }

  tz.TZDateTime _getExactTime(DateTime bookingTime) {
    return tz.TZDateTime.from(bookingTime, tz.local);
  }

  // Format date for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Generate unique notification ID
  int _generateNotificationId(String bookingId, String title) {
    return (bookingId + title).hashCode.abs();
  }

  // Test notifications
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'Test Reminder',
      body: 'This is a test notification from Home Service App',
      payload: 'test',
    );
  }

  Future<void> sendTestCustomerNotification() async {
    await _showLocalNotification(
      title: 'Test Customer Notification',
      body: 'This is a test notification for customers',
      payload: 'test_customer',
      notificationType: TYPE_BOOKING_REMINDER,
    );
  }

  Future<void> sendTestProviderNotification() async {
    await _showLocalNotification(
      title: 'Test Provider Notification',
      body: 'This is a test notification for providers',
      payload: 'test_provider',
      notificationType: TYPE_NEW_BOOKING,
    );
  }
}