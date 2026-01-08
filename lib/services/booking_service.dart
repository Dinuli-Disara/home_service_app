import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/reminder_service.dart';
import '../services/user_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  
  // Create a new booking WITHOUT photo upload
  Future<Map<String, dynamic>> createBooking({
    required String userId,
    required String providerId,
    required String serviceType,
    required DateTime date,
    required String time,
    required String address,
    required String problemDescription,
    List<XFile>? problemPhotos, // Keep but don't upload
    double? estimatedCost,
  }) async {
    try {
      // Generate booking ID
      final bookingId = _firestore.collection('bookings').doc().id;
      
      // Convert photos to base64 strings (limited to small images)
      List<String> photoBase64 = [];
      if (problemPhotos != null && problemPhotos.isNotEmpty) {
        // Limit to 3 photos to keep data small
        final limitedPhotos = problemPhotos.length > 3 
            ? problemPhotos.sublist(0, 3) 
            : problemPhotos;
            
        for (final photo in limitedPhotos) {
          try {
            final bytes = await photo.readAsBytes();
            // Only store if small enough (< 0.5MB)
            if (bytes.length < 500 * 1024) {
              final base64String = base64Encode(bytes);
              photoBase64.add(base64String);
            }
          } catch (e) {
            print('❌ Error converting photo to base64: $e');
          }
        }
      }

      final bookingData = {
        'bookingId': bookingId,
        'userId': userId,
        'providerId': providerId,
        'serviceType': serviceType,
        'date': Timestamp.fromDate(date),
        'time': time,
        'address': address,
        'problemDescription': problemDescription,
        'hasPhotos': photoBase64.isNotEmpty,
        'photoCount': photoBase64.length,
        // Don't store actual photos in Firestore to save space/cost
        'estimatedCost': estimatedCost,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore.collection('bookings').doc(bookingId).set(bookingData);
      
      print('✅ Booking created (no photo storage): $bookingId');

      // Schedule reminders for this booking using the enhanced reminder service
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final reminderService = ReminderService();
          
          // Get user data for notification
          final userData = await _userService.getUserData(userId);
          final userName = userData?['name'] ?? 'Customer';
          
          // Get provider data
          final providerData = await _userService.getUserData(providerId);
          final providerName = providerData?['name'] ?? 'Provider';
          
          // Schedule customer reminders
          await reminderService.scheduleCustomerRemindersForBooking(bookingId);
          
          // Schedule provider notifications
          await reminderService.scheduleProviderNotificationsForBooking(bookingId);
          
          print('✅ All notifications scheduled for booking: $bookingId');
          
        } catch (e) {
          print('⚠️ Error scheduling notifications: $e');
        }
      });
      
      return {'success': true, 'bookingId': bookingId, 'data': bookingData};
      
    } catch (e) {
      print('❌ Error creating booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

   // ==================== UPDATE BOOKING STATUS ====================
  Future<void> updateBookingStatus(
    String bookingId,
    String status,
    String note, {
    double? actualCost,
    String? cancellationReason,
    String? userType = 'customer', // Track who's making the change
  }) async {
    try {
      // Get current booking data
      final booking = await getBooking(bookingId);
      if (booking == null) {
        throw Exception('Booking not found');
      }
      
      final oldStatus = booking['status'] as String? ?? 'pending';
      
      // Don't update if status hasn't changed
      if (oldStatus == status) {
        return;
      }

      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add status-specific fields
      switch (status) {
        case 'accepted':
          updates['acceptedAt'] = FieldValue.serverTimestamp();
          updates['acceptedNote'] = note;
          break;
        case 'completed':
          updates['completedAt'] = FieldValue.serverTimestamp();
          updates['completedNote'] = note;
          if (actualCost != null) {
            updates['actualCost'] = actualCost;
            updates['totalAmount'] = actualCost;
          }
          break;
        case 'cancelled':
          updates['cancelledAt'] = FieldValue.serverTimestamp();
          updates['cancellationNote'] = note;
          if (cancellationReason != null) {
            updates['cancellationReason'] = cancellationReason;
          }
          break;
        case 'rejected':
          updates['rejectedAt'] = FieldValue.serverTimestamp();
          updates['rejectionNote'] = note;
          if (cancellationReason != null) {
            updates['rejectionReason'] = cancellationReason;
          }
          break;
        default:
          updates['statusNote'] = note;
      }

      // Update the booking
      await _firestore.collection('bookings').doc(bookingId).update(updates);
      
      print('✅ Booking status updated: $bookingId -> $status');

      // Handle notifications for status change
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final reminderService = ReminderService();
          await reminderService.handleBookingStatusChange(
            bookingId: bookingId,
            oldStatus: oldStatus,
            newStatus: status,
          );
          print('✅ Status change notifications handled for booking: $bookingId');
        } catch (e) {
          print('⚠️ Error handling status change notifications: $e');
        }
      });

    } catch (e) {
      print('❌ Error updating booking status: $e');
      rethrow;
    }
  }

  // Get user's bookings
  Stream<List<Map<String, dynamic>>> getUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Get provider bookings
  Stream<List<Map<String, dynamic>>> getProviderBookingsStream(String providerId) {
    return _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Get booking by ID
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error getting booking: $e');
      return null;
    }
  }

  // CancelBooking with notification support
  Future<void> cancelBooking(String bookingId, String reason, {String userType = 'customer'}) async {
    try {
      await updateBookingStatus(
        bookingId,
        'cancelled',
        'Booking cancelled',
        cancellationReason: reason,
        userType: userType,
      );
      print('✅ Booking cancelled: $bookingId');
    } catch (e) {
      print('❌ Error cancelling booking: $e');
      rethrow;
    }
  }

  // Get bookings count for home screen
  Future<int> getUpcomingBookingsCount(String userId) async {
    try {
      final now = Timestamp.now();
      
      // Query WITHOUT date filter (no index needed)
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'accepted'])
          .get();
      
      // Filter by date locally
      final upcomingBookings = snapshot.docs.where((doc) {
        final date = doc['date'] as Timestamp?;
        return date != null && date.compareTo(now) >= 0;
      });
      
      return upcomingBookings.length;
    } catch (e) {
      print('❌ Error getting bookings count: $e');
      return 0;
    }
  }

  // ==================== ADDITIONAL HELPER METHODS ====================

  // Get provider's pending bookings count
  Future<int> getProviderPendingCount(String providerId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting provider pending count: $e');
      return 0;
    }
  }

  // Update booking with actual cost and completion details
  Future<void> completeBookingWithCost(
    String bookingId,
    double actualCost, {
    String? completionNote,
  }) async {
    try {
      await updateBookingStatus(
        bookingId,
        'completed',
        completionNote ?? 'Service completed',
        actualCost: actualCost,
        userType: 'provider',
      );
    } catch (e) {
      print('❌ Error completing booking with cost: $e');
      rethrow;
    }
  }

  // Accept booking (convenience method)
  Future<void> acceptBooking(String bookingId, {String? note}) async {
    try {
      await updateBookingStatus(
        bookingId,
        'accepted',
        note ?? 'Booking accepted by provider',
        userType: 'provider',
      );
    } catch (e) {
      print('❌ Error accepting booking: $e');
      rethrow;
    }
  }

  // Reject booking (convenience method)
  Future<void> rejectBooking(String bookingId, {String? reason, String? note}) async {
    try {
      await updateBookingStatus(
        bookingId,
        'rejected',
        note ?? 'Booking rejected by provider',
        cancellationReason: reason,
        userType: 'provider',
      );
    } catch (e) {
      print('❌ Error rejecting booking: $e');
      rethrow;
    }
  }
  
  // Get upcoming bookings for notifications
  Future<List<Map<String, dynamic>>> getUpcomingBookingsForNotifications(String userId, String userType) async {
    try {
      final now = Timestamp.now();
      Query query;
      
      if (userType == 'customer') {
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
      
      final snapshot = await query.get();
      
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
}