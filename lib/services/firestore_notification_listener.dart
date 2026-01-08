import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './reminder_service.dart';

class FirestoreNotificationListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReminderService _reminderService = ReminderService();
  StreamSubscription? _bookingSubscription;
  
  // Listen for booking changes for a user (simpler version)
  Future<void> listenForBookingChanges(String userId, String userType) async {
    try {
      // Cancel existing subscription if any
      await _bookingSubscription?.cancel();
      
      Query query;
      
      if (userType == 'customer') {
        query = _firestore
            .collection('bookings')
            .where('userId', isEqualTo: userId);
      } else {
        query = _firestore
            .collection('bookings')
            .where('providerId', isEqualTo: userId);
      }
      
      _bookingSubscription = query.snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          final bookingId = change.doc.id;
          final bookingData = change.doc.data() as Map<String, dynamic>;
          final status = bookingData['status'] as String? ?? 'pending';
          
          switch (change.type) {
            case DocumentChangeType.added:
              _handleNewBooking(bookingId, bookingData, userType);
              break;
              
            case DocumentChangeType.modified:
              // For modified documents, we can't know the old status
              // So we'll just handle based on current status
              _handleBookingUpdate(bookingId, bookingData, userType, status);
              break;
              
            case DocumentChangeType.removed:
              // Booking was deleted - cancel all reminders
              _reminderService.cancelRemindersForBooking(bookingId);
              break;
          }
        }
      });
      
      print('✅ Firestore listener started for $userType: $userId');
      
    } catch (e) {
      print('❌ Error starting Firestore listener: $e');
    }
  }
  
  Future<void> _handleNewBooking(
    String bookingId, 
    Map<String, dynamic> bookingData,
    String userType,
  ) async {
    try {
      print('📱 New booking detected: $bookingId for $userType');
      
      final status = bookingData['status'] as String? ?? 'pending';
      
      if (userType == 'customer') {
        // Customer gets reminders for their own bookings
        await _reminderService.scheduleCustomerRemindersForBooking(bookingId);
        print('📱 Customer reminders scheduled for new booking: $bookingId');
      } else if (userType == 'provider' && status == 'pending') {
        // Provider gets notifications for new pending bookings
        await _reminderService.scheduleProviderNotificationsForBooking(bookingId);
        print('📱 Provider notifications scheduled for new booking: $bookingId');
      }
      
    } catch (e) {
      print('❌ Error handling new booking: $e');
    }
  }
  
  Future<void> _handleBookingUpdate(
    String bookingId, 
    Map<String, dynamic> bookingData,
    String userType,
    String status,
  ) async {
    try {
      print('📱 Booking updated: $bookingId, status: $status');
      
      // Handle based on current status
      switch (status) {
        case 'completed':
        case 'cancelled':
        case 'rejected':
          // Cancel all reminders for completed/cancelled/rejected bookings
          await _reminderService.cancelRemindersForBooking(bookingId);
          print('📱 Reminders cancelled for $bookingId (status: $status)');
          break;
          
        case 'accepted':
          // If accepted, schedule reminders if not already scheduled
          if (userType == 'customer') {
            await _reminderService.scheduleCustomerRemindersForBooking(bookingId);
            print('📱 Customer reminders scheduled for accepted booking: $bookingId');
          } else if (userType == 'provider') {
            // Provider might want to schedule service reminders
            print('📱 Booking accepted - provider should schedule service reminders');
          }
          break;
          
        default:
          // For other statuses, do nothing or log
          print('📱 Booking $bookingId updated to $status');
      }
      
    } catch (e) {
      print('❌ Error handling booking update: $e');
    }
  }
  
  // Stop listening
  Future<void> stopListening() async {
    try {
      await _bookingSubscription?.cancel();
      _bookingSubscription = null;
      print('✅ Firestore listener stopped');
    } catch (e) {
      print('❌ Error stopping listener: $e');
    }
  }
  
  // Check if currently listening
  bool isListening() {
    return _bookingSubscription != null;
  }
  
  void dispose() {
    _bookingSubscription?.cancel();
  }
}