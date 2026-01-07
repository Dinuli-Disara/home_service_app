import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './notification_service.dart';
import './booking_service.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final BookingService _bookingService = BookingService();
  final Set<String> _scheduledBookings = {};
  static bool _isInitialized = false;
  
  // Schedule reminders for a new booking
  Future<void> scheduleRemindersForBooking(String bookingId) async {
     if (_scheduledBookings.contains(bookingId)) {
      print('⚠️ Reminders already scheduled for booking: $bookingId');
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
      
      // Schedule reminders
      final bookingDateTime = _parseBookingDateTime(booking);
      if (bookingDateTime == null) return;
      
      await _notificationService.scheduleAllReminders(
        bookingId: bookingId,
        serviceType: booking['serviceType'] ?? 'Service',
        bookingDateTime: bookingDateTime,
        providerName: provider['name'] ?? 'Provider',
      );
      
      print('✅ Reminders scheduled for booking: $bookingId');
      
    } catch (e) {
      print('❌ Error scheduling reminders: $e');
    }
  }
  
  // Cancel reminders for a booking
  Future<void> cancelRemindersForBooking(String bookingId) async {
    try {
      await _notificationService.cancelReminders(bookingId);
      _scheduledBookings.remove(bookingId);
      print('✅ Reminders cancelled for booking: $bookingId');
    } catch (e) {
      print('❌ Error cancelling reminders: $e');
    }
  }
  
  // Check and schedule reminders for all upcoming bookings
  Future<void> scheduleRemindersForAllUpcomingBookings(String userId) async {
    try {
      final bookings = await _getUpcomingBookings(userId);
      int scheduledCount = 0;
      
      for (final booking in bookings) {
        final bookingId = booking['bookingId'];
        final bookingDateTime = _parseBookingDateTime(booking);
        
        if (bookingId != null && bookingDateTime != null && _shouldScheduleReminder(bookingDateTime)) {
          // Check if reminders should be scheduled
          if (!_scheduledBookings.contains(bookingId)) {
            await scheduleRemindersForBooking(bookingId);
            _scheduledBookings.add(bookingId);
            scheduledCount++;
          }
        }
      }
      
      print('✅ Reminders scheduled for all upcoming bookings');
      
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
      return null;
    } catch (e) {
      print('❌ Error getting provider: $e');
      return null;
    }
  }
  
  DateTime? _parseBookingDateTime(Map<String, dynamic> booking) {
    try {
      final dateField = booking['date'];
      if (dateField is Timestamp) {
        return dateField.toDate();
      }
      
      // If time is stored separately, combine with date
      final date = booking['date'] as String?;
      final time = booking['time'] as String?;
      
      if (date != null && time != null) {
        // Parse date and time strings
        // You'll need to implement this based on your date format
        return DateTime.now().add(Duration(days: 1)); // Placeholder
      }
      
      return null;
    } catch (e) {
      print('❌ Error parsing booking datetime: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>> _getUpcomingBookings(String userId) async {
    try {
      final now = Timestamp.now();
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'accepted'])
          .where('date', isGreaterThanOrEqualTo: now)
          .get();
      
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
  
  // Initialize reminder service (call on app start)
  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      print('⚠️ Reminder service already initialized');
      return;
    }

    try {
      // Initialize notification service
      await _notificationService.initialize();
      
      // Schedule reminders for existing bookings
      await scheduleRemindersForAllUpcomingBookings(userId);

      _isInitialized = true;
      print('✅ Reminder service initialized');
    } catch (e) {
      print('❌ Error initializing reminder service: $e');
    }
  }
  
  // Test function
  Future<void> sendTestReminder() async {
    await _notificationService.sendTestNotification();
  }
}