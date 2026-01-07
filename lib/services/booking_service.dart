import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/reminder_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // Schedule reminders for this booking
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final reminderService = ReminderService();
          await reminderService.scheduleRemindersForBooking(bookingId);
          print('✅ Reminders scheduled for booking: $bookingId');
        } catch (e) {
          print('⚠️ Error scheduling reminders: $e');
        }
      });
      
      return {'success': true, 'bookingId': bookingId, 'data': bookingData};
      
    } catch (e) {
      print('❌ Error creating booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get user's bookings
  Stream<List<Map<String, dynamic>>> getUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
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

  // CancelBooking
  Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
}