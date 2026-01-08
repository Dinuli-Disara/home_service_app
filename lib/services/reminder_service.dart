import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './notification_service.dart';
import './booking_service.dart';
import './user_service.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final BookingService _bookingService = BookingService();
  final UserService _userService = UserService();
  final Set<String> _scheduledBookings = {};
  static bool _isInitialized = false;
  
  // Schedule reminders for a new booking (for customer)
  Future<void> scheduleCustomerRemindersForBooking(String bookingId) async {
    if (_scheduledBookings.contains('customer_$bookingId')) {
      print('⚠️ Customer reminders already scheduled for booking: $bookingId');
      return;
    }

    try {
      // Get booking details
      final booking = await _bookingService.getBooking(bookingId);
      if (booking == null) {
        print('❌ Booking not found: $bookingId');
        return;
      }
      
      // Get provider details
      final provider = await _getProvider(booking['providerId']);
      if (provider == null) {
        print('❌ Provider not found: ${booking['providerId']}');
        return;
      }
      
      // Get customer details
      final customer = await _getCustomer(booking['userId']);
      if (customer == null) {
        print('❌ Customer not found: ${booking['userId']}');
        return;
      }
      
      // Schedule customer reminders
      final bookingDateTime = _parseBookingDateTime(booking);
      if (bookingDateTime == null) return;
      
      await _notificationService.scheduleCustomerReminders(
        bookingId: bookingId,
        serviceType: booking['serviceType'] ?? 'Service',
        bookingDateTime: bookingDateTime,
        providerName: provider['name'] ?? 'Provider',
        customerName: customer['name'] ?? 'Customer',
      );
      
      _scheduledBookings.add('customer_$bookingId');
      print('✅ Customer reminders scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling customer reminders: $e');
    }
  }
  
  // Schedule provider notifications for a new booking
  Future<void> scheduleProviderNotificationsForBooking(String bookingId) async {
    if (_scheduledBookings.contains('provider_$bookingId')) {
      print('⚠️ Provider notifications already scheduled for booking: $bookingId');
      return;
    }

    try {
      // Get booking details
      final booking = await _bookingService.getBooking(bookingId);
      if (booking == null) {
        print('❌ Booking not found: $bookingId');
        return;
      }
      
      // Get customer details
      final customer = await _getCustomer(booking['userId']);
      if (customer == null) {
        print('❌ Customer not found: ${booking['userId']}');
        return;
      }
      
      // Get provider details
      final provider = await _getProvider(booking['providerId']);
      if (provider == null) {
        print('❌ Provider not found: ${booking['providerId']}');
        return;
      }
      
      // Parse booking date and time
      final bookingDateTime = _parseBookingDateTime(booking);
      if (bookingDateTime == null) return;
      
      // Send immediate notification for new booking
      await _notificationService.sendProviderNewBooking(
        bookingId: bookingId,
        serviceType: booking['serviceType'] ?? 'Service',
        customerName: customer['name'] ?? 'Customer',
        bookingDateTime: bookingDateTime,
        providerName: provider['name'] ?? 'Provider',
      );
      
      // If booking is pending, schedule expiry reminder
      if (booking['status'] == 'pending') {
        await _notificationService.scheduleProviderPendingExpiry(
          bookingId: bookingId,
          serviceType: booking['serviceType'] ?? 'Service',
          bookingDate: bookingDateTime,
          customerName: customer['name'] ?? 'Customer',
          providerName: provider['name'] ?? 'Provider',
        );
      }
      
      // If booking is accepted, schedule service reminders
      if (booking['status'] == 'accepted') {
        await _notificationService.scheduleProviderReminders(
          bookingId: bookingId,
          serviceType: booking['serviceType'] ?? 'Service',
          bookingDateTime: bookingDateTime,
          customerName: customer['name'] ?? 'Customer',
          providerName: provider['name'] ?? 'Provider',
        );
      }
      
      _scheduledBookings.add('provider_$bookingId');
      print('✅ Provider notifications scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling provider notifications: $e');
    }
  }
  
  // Handle booking status change
  Future<void> handleBookingStatusChange({
    required String bookingId,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      // Get booking details
      final booking = await _bookingService.getBooking(bookingId);
      if (booking == null) return;
      
      // Get customer and provider details
      final customer = await _getCustomer(booking['userId']);
      final provider = await _getProvider(booking['providerId']);
      
      final customerName = customer?['name'] ?? 'Customer';
      final providerName = provider?['name'] ?? 'Provider';
      final serviceType = booking['serviceType'] ?? 'Service';
      
      // Send notification to customer
      await _notificationService.sendCustomerStatusUpdate(
        bookingId: bookingId,
        serviceType: serviceType,
        oldStatus: oldStatus,
        newStatus: newStatus,
        providerName: providerName,
        additionalInfo: _getStatusChangeMessage(oldStatus, newStatus),
      );
      
      // Send notification to provider
      await _notificationService.sendProviderStatusUpdate(
        bookingId: bookingId,
        serviceType: serviceType,
        oldStatus: oldStatus,
        newStatus: newStatus,
        customerName: customerName,
        additionalInfo: _getStatusChangeMessage(oldStatus, newStatus),
      );
      
      // Handle reminder cancellations/scheduling based on status change
      await _handleStatusChangeReminders(
        bookingId: bookingId,
        booking: booking,
        oldStatus: oldStatus,
        newStatus: newStatus,
        customerName: customerName,
        providerName: providerName,
      );
      
      print('✅ Status change notifications sent for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error handling booking status change: $e');
    }
  }
  
  // Handle reminder adjustments based on status change
  Future<void> _handleStatusChangeReminders({
    required String bookingId,
    required Map<String, dynamic> booking,
    required String oldStatus,
    required String newStatus,
    required String customerName,
    required String providerName,
  }) async {
    final bookingDateTime = _parseBookingDateTime(booking);
    if (bookingDateTime == null) return;
    
    final serviceType = booking['serviceType'] ?? 'Service';
    
    // If booking is cancelled/rejected/completed, cancel all reminders
    if (['cancelled', 'rejected', 'completed'].contains(newStatus)) {
      await _notificationService.cancelReminders(bookingId);
      _scheduledBookings.removeWhere((id) => id.contains(bookingId));
    }
    
    // If booking changed from pending to accepted
    if (oldStatus == 'pending' && newStatus == 'accepted') {
      // Cancel pending expiry reminder
      await _notificationService.cancelNotificationByPayload('provider_pending_expiry_$bookingId');
      
      // Schedule customer reminders
      await scheduleCustomerRemindersForBooking(bookingId);
      
      // Schedule provider service reminders
      await _notificationService.scheduleProviderReminders(
        bookingId: bookingId,
        serviceType: serviceType,
        bookingDateTime: bookingDateTime,
        customerName: customerName,
        providerName: providerName,
      );
    }
    
    // If booking changed from accepted to cancelled/rejected
    if (oldStatus == 'accepted' && ['cancelled', 'rejected'].contains(newStatus)) {
      // Cancel all scheduled reminders
      await _notificationService.cancelReminders(bookingId);
    }
  }
  
  // Cancel reminders for a booking
  Future<void> cancelRemindersForBooking(String bookingId) async {
    try {
      await _notificationService.cancelReminders(bookingId);
      _scheduledBookings.removeWhere((id) => id.contains(bookingId));
      print('✅ Reminders cancelled for booking: $bookingId');
    } catch (e) {
      print('❌ Error cancelling reminders: $e');
    }
  }
  
  // Check and schedule reminders for all upcoming bookings
  Future<void> scheduleRemindersForAllUpcomingBookings(String userId, String userType) async {
    try {
      final bookings = await _getUpcomingBookings(userId, userType);
      int scheduledCount = 0;
      
      for (final booking in bookings) {
        final bookingId = booking['id'] ?? booking['bookingId'];
        final bookingDateTime = _parseBookingDateTime(booking);
        
        if (bookingId != null && bookingDateTime != null && _shouldScheduleReminder(bookingDateTime)) {
          // Schedule based on user type
          if (userType == NotificationService.ROLE_CUSTOMER) {
            if (!_scheduledBookings.contains('customer_$bookingId')) {
              await scheduleCustomerRemindersForBooking(bookingId);
              _scheduledBookings.add('customer_$bookingId');
              scheduledCount++;
            }
          } else if (userType == NotificationService.ROLE_PROVIDER) {
            if (!_scheduledBookings.contains('provider_$bookingId')) {
              await scheduleProviderNotificationsForBooking(bookingId);
              _scheduledBookings.add('provider_$bookingId');
              scheduledCount++;
            }
          }
        }
      }
      
      print('✅ $scheduledCount reminders scheduled for $userType');
      
    } catch (e) {
      print('❌ Error scheduling reminders for all bookings: $e');
    }
  }
  
  // Helper methods
  Future<Map<String, dynamic>?> _getProvider(String providerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      // Also check users collection if providers are stored there
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(providerId)
          .get();
      
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting provider: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getCustomer(String customerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(customerId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error getting customer: $e');
      return null;
    }
  }
  
  DateTime? _parseBookingDateTime(Map<String, dynamic> booking) {
    try {
      final dateField = booking['date'];
      final timeField = booking['time'];
      
      if (dateField is Timestamp) {
        DateTime date = dateField.toDate();
        
        // Parse time string (assuming format like "14:30")
        if (timeField is String) {
          final timeParts = timeField.split(':');
          if (timeParts.length >= 2) {
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            date = DateTime(
              date.year,
              date.month,
              date.day,
              hour,
              minute,
            );
          }
        }
        
        return date;
      }
      
      return null;
    } catch (e) {
      print('❌ Error parsing booking datetime: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>> _getUpcomingBookings(String userId, String userType) async {
    try {
      final now = Timestamp.now();
      Query query;
      
      if (userType == NotificationService.ROLE_CUSTOMER) {
        query = _firestore
            .collection('bookings')
            .where('userId', isEqualTo: userId)
            .where('status', whereIn: ['pending', 'accepted'])
            .where('date', isGreaterThanOrEqualTo: now);
      } else {
        query = _firestore
            .collection('bookings')
            .where('providerId', isEqualTo: userId)
            .where('status', whereIn: ['pending', 'accepted'])
            .where('date', isGreaterThanOrEqualTo: now);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting upcoming bookings: $e');
      return [];
    }
  }
  
  bool _shouldScheduleReminder(DateTime bookingDateTime) {
    // Only schedule reminders for bookings in the future
    return bookingDateTime.isAfter(DateTime.now());
  }
  
  String _getStatusChangeMessage(String oldStatus, String newStatus) {
    final messages = {
      'pending_accepted': 'Your booking has been confirmed!',
      'pending_rejected': 'The provider is unavailable at this time.',
      'accepted_completed': 'Service completed successfully!',
      'accepted_cancelled': 'Booking has been cancelled.',
      'pending_cancelled': 'Booking request cancelled.',
    };
    
    final key = '${oldStatus}_$newStatus';
    return messages[key] ?? '';
  }
  
  // Initialize reminder service (call on app start)
  Future<void> initialize(String userId, String userType) async {
    if (_isInitialized) {
      print('⚠️ Reminder service already initialized');
      return;
    }

    try {
      // Initialize notification service
      await _notificationService.initialize();
      
      // Schedule reminders for existing bookings
      await scheduleRemindersForAllUpcomingBookings(userId, userType);

      _isInitialized = true;
      print('✅ Reminder service initialized for $userType');
    } catch (e) {
      print('❌ Error initializing reminder service: $e');
    }
  }
  
  // Test function
  Future<void> sendTestReminder() async {
    await _notificationService.sendTestNotification();
  }
  
  Future<void> sendTestCustomerNotification() async {
    await _notificationService.sendTestCustomerNotification();
  }
  
  Future<void> sendTestProviderNotification() async {
    await _notificationService.sendTestProviderNotification();
  }
}