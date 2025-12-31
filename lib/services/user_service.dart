import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save guest user to Firestore
  Future<Map<String, dynamic>> saveGuestUser({
    required String userId,
    required String name,
    String? address, // Human-readable address
    double? latitude,
    double? longitude,
  }) async {
    try {
      Map<String, dynamic> locationData = {};
    
      if (address != null) {
        locationData['address'] = address;
      }
    
      if (latitude != null && longitude != null) {
        locationData['coordinates'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
        locationData['geoPoint'] = GeoPoint(latitude, longitude);
        locationData['locationType'] = 'gps';
      } else if (address != null) {
        locationData['locationType'] = 'manual';
      }

      //User data structure
      Map<String, dynamic> userData = {
        'userId': userId,
        'name': name,
        'email': null,
        'phone': null,
        'role': 'user',
        'userType': 'guest',
        'location': locationData.isNotEmpty ? locationData: null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(userData);
      
      print('✅ Guest user saved to Firestore: $userId');
      print('📊 User data: ${userData.toString()}');
      
      return {'success': true, 'userId': userId, 'data': userData};

    } catch (e) {
      print('❌ Error saving guest user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

   // Update user location
  Future<Map<String, dynamic>> updateUserLocation({
    required String userId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };

      // Prepare location updates
      Map<String, dynamic> locationUpdates = {};
      
      if (address != null) {
        locationUpdates['address'] = address;
      }
      
      if (latitude != null && longitude != null) {
        locationUpdates['coordinates'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
        locationUpdates['geoPoint'] = GeoPoint(latitude, longitude);
        locationUpdates['locationType'] = 'gps';
      } else if (address != null) {
        locationUpdates['locationType'] = 'manual';
      }

      if (locationUpdates.isNotEmpty) {
        updates['location'] = locationUpdates;
      }

      // Update in Firestore
      await _firestore.collection('users').doc(userId).update(updates);
      
      print('✅ User location updated: $userId');
      print('📍 Location data: ${locationUpdates.toString()}');
      
      return {'success': true, 'updates': updates};
      
    } catch (e) {
      print('❌ Error updating user location: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        print('✅ User data retrieved: ${doc.data()}');
        return doc.data() as Map<String, dynamic>;
      } else {
        print('⚠️ User document not found: $userId');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Check if user exists
  Future<bool> userExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking user existence: $e');
      return false;
    }
  }
}