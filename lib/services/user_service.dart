import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== CUSTOMER MANAGEMENT ====================

  // Save customer (regular user who buys services)
  Future<Map<String, dynamic>> saveCustomer({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    required String authMethod,
    String? address,
    double? latitude,
    double? longitude,
    bool isGuest = false,
  }) async {
    try {
      Map<String, dynamic> userData = {
        'userId': userId,
        'name': name ?? (isGuest ? 'Guest User' : 'User'),
        'email': email,
        'phone': phone,
        'profileImage': profileImage,
        'authMethod': authMethod,
        'userType': isGuest ? 'guest' : 'customer',
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };

      // Add location if provided
      if (address != null || (latitude != null && longitude != null)) {
        userData['location'] = _buildLocationData(
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      }

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(userData);
      
      print('✅ Customer saved to Firestore: $userId (${isGuest ? 'guest' : 'customer'})');
      
      return {'success': true, 'userId': userId, 'data': userData};

    } catch (e) {
      print('❌ Error saving customer: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== CUSTOMER PROFILE MANAGEMENT ====================

  // Update customer profile with all fields
  Future<Map<String, dynamic>> updateCustomerProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };

      // Basic info updates
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (profileImageUrl != null) updates['profileImage'] = profileImageUrl;

      // Update location if provided
      if (address != null || (latitude != null && longitude != null)) {
        updates['location'] = _buildLocationData(
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      }

      // Update in users collection
      await _firestore.collection('users').doc(userId).update(updates);

      print('✅ Customer profile updated: $userId');
      return {'success': true, 'updates': updates};
      
    } catch (e) {
      print('❌ Error updating customer profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get customer statistics
  Future<Map<String, dynamic>> getCustomerStats(String customerId) async {
    try {
      // Get booking stats
      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: customerId)
          .get();

      final allBookings = bookingsQuery.docs;
      final totalBookings = allBookings.length;
      final completedBookings = allBookings
          .where((doc) => (doc.data()['status'] as String?) == 'completed')
          .length;
      final cancelledBookings = allBookings
          .where((doc) => (doc.data()['status'] as String?) == 'cancelled')
          .length;
      final pendingBookings = allBookings
          .where((doc) => (doc.data()['status'] as String?) == 'pending')
          .length;

      // Calculate total spent
      double totalSpent = 0.0;
      for (final doc in allBookings) {
        final data = doc.data();
        if (data['status'] == 'completed' && data['totalAmount'] != null) {
          totalSpent += (data['totalAmount'] as num).toDouble();
        }
      }

      return {
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'cancelledBookings': cancelledBookings,
        'pendingBookings': pendingBookings,
        'totalSpent': totalSpent,
        'favoriteService': _getFavoriteService(allBookings),
      };
    } catch (e) {
      print('❌ Error getting customer stats: $e');
      return {
        'totalBookings': 0,
        'completedBookings': 0,
        'cancelledBookings': 0,
        'pendingBookings': 0,
        'totalSpent': 0.0,
        'favoriteService': 'None',
      };
    }
  }

  // Helper to get favorite service from bookings
  String _getFavoriteService(List<QueryDocumentSnapshot> bookings) {
    if (bookings.isEmpty) return 'None';
    
    final serviceCount = <String, int>{};
    for (final doc in bookings) {
      final data = doc.data() as Map<String, dynamic>?;
      final serviceType = data?['serviceType'] as String?;
      if (serviceType != null) {
        serviceCount[serviceType] = (serviceCount[serviceType] ?? 0) + 1;
      }
    }
    
    if (serviceCount.isEmpty) return 'None';
    
    final favorite = serviceCount.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    
    return favorite.key;
  }

  // Get customer's recent bookings
  Future<List<Map<String, dynamic>>> getCustomerBookings({
    required String customerId,
    String status = 'all',
    int limit = 5,
  }) async {
    try {
      Query query = _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      QuerySnapshot snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting customer bookings: $e');
      return [];
    }
  }

  // Upload customer profile image
  Future<String?> uploadCustomerProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      print('🔄 Starting customer image upload for user: $userId');
      
      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg';
      
      // Create reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('customers')
          .child(userId)
          .child('profile_images')
          .child(fileName);
      
      print('📁 Storage path: customers/$userId/profile_images/$fileName');
      
      // Upload file with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toString(),
        },
      );
      
      final uploadTask = storageRef.putFile(imageFile, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('✅ Customer image uploaded successfully: $downloadUrl');
        
        // Cleanup old images
        await _cleanupOldCustomerImages(userId);
        
        return downloadUrl;
      } else {
        print('❌ Upload failed: ${snapshot.state}');
        return null;
      }
      
    } catch (e) {
      print('❌ Error uploading customer profile image: $e');
      return null;
    }
  }

  // Cleanup old customer profile images
  Future<void> _cleanupOldCustomerImages(String userId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('customers')
          .child(userId)
          .child('profile_images');
      
      final listResult = await storageRef.listAll();
      
      // Keep only the last 3 images
      if (listResult.items.length > 3) {
        // Sort by name (which includes timestamp)
        final sortedItems = listResult.items.toList()
          ..sort((a, b) => b.name.compareTo(a.name));
        
        // Delete older images
        for (int i = 3; i < sortedItems.length; i++) {
          await sortedItems[i].delete();
          print('🗑️ Deleted old customer image: ${sortedItems[i].name}');
        }
      }
    } catch (e) {
      print('⚠️ Error cleaning up old customer images: $e');
    }
  }

  // ==================== SERVICE PROVIDER MANAGEMENT ====================

  // Save service provider
  Future<Map<String, dynamic>> saveServiceProvider({
    required String userId,
    required String name,
    required String phone,
    required String serviceType,
    String? email,
    String? profileImage,
    String? businessName,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? serviceAreas,
    double? hourlyRate,
    List<String>? certifications,
    bool isVerified = false,
    double rating = 0.0,
    int totalJobs = 0,
  }) async {
    try {
      Map<String, dynamic> providerData = {
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'profileImage': profileImage,
        'businessName': businessName,
        'description': description,
        'serviceType': serviceType,
        'userType': 'provider',
        'role': 'provider',
        'isVerified': isVerified,
        'rating': rating,
        'totalJobs': totalJobs,
        'hourlyRate': hourlyRate,
        'certifications': certifications ?? [],
        'serviceAreas': serviceAreas ?? [],
        'availability': {
          'isAvailable': true,
          'workingHours': {
            'start': '08:00',
            'end': '18:00',
          },
          'workingDays': [1, 2, 3, 4, 5],
        },
        'stats': {
          'completedJobs': 0,
          'cancelledJobs': 0,
          'earnings': 0.0,
          'responseRate': 100.0,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };

      // Add location if provided
      if (address != null || (latitude != null && longitude != null)) {
        providerData['location'] = _buildLocationData(
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      }

      // Save to providers collection
      await _firestore.collection('providers').doc(userId).set(providerData);
      
      // Also save to users collection
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'userType': 'provider',
        'role': 'provider',
        'serviceType': serviceType,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ Service provider saved: $userId ($serviceType)');
      
      return {'success': true, 'userId': userId, 'data': providerData};

    } catch (e) {
      print('❌ Error saving service provider: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== PROVIDER AVAILABILITY ====================

  // Update provider availability
  Future<Map<String, dynamic>> updateProviderAvailability({
    required String userId,
    bool? isAvailable,
    Map<String, dynamic>? workingHours,
    List<int>? workingDays,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update availability
      if (isAvailable != null) {
        updates['availability.isAvailable'] = isAvailable;
      }

      if (workingHours != null) {
        updates['availability.workingHours'] = workingHours;
      }

      if (workingDays != null) {
        updates['availability.workingDays'] = workingDays;
      }

      // Update in providers collection
      await _firestore.collection('providers').doc(userId).update(updates);
      
      // Also update in users collection for quick access
      if (isAvailable != null) {
        await _firestore.collection('users').doc(userId).update({
          'availability.isAvailable': isAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Provider availability updated: $userId');
      return {'success': true};
      
    } catch (e) {
      print('❌ Error updating provider availability: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get provider availability
  Future<Map<String, dynamic>?> getProviderAvailability(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('providers').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['availability'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting provider availability: $e');
      return null;
    }
  }

  // Update provider stats
  Future<void> updateProviderStats({
    required String providerId,
    double? newRating,
    double? earnings,
    bool completedJob = false,
    bool cancelledJob = false,
  }) async {
    try {
      final docRef = _firestore.collection('providers').doc(providerId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final stats = data['stats'] ?? {};
        
        Map<String, dynamic> updates = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (completedJob) {
          final currentJobs = (stats['completedJobs'] ?? 0) as int;
          updates['stats.completedJobs'] = currentJobs + 1;
          updates['totalJobs'] = (data['totalJobs'] ?? 0) + 1;
        }

        if (cancelledJob) {
          final currentCancelled = (stats['cancelledJobs'] ?? 0) as int;
          updates['stats.cancelledJobs'] = currentCancelled + 1;
        }

        if (earnings != null) {
          final currentEarnings = (stats['earnings'] ?? 0.0) as double;
          updates['stats.earnings'] = currentEarnings + earnings;
        }

        if (newRating != null) {
          final currentRating = (data['rating'] ?? 0.0) as double;
          final currentTotalJobs = (data['totalJobs'] ?? 0) as int;
          
          // Calculate new average rating
          if (currentTotalJobs > 0) {
            final newAverage = ((currentRating * currentTotalJobs) + newRating) / (currentTotalJobs + 1);
            updates['rating'] = newAverage;
          } else {
            updates['rating'] = newRating;
          }
        }

        await docRef.update(updates);
        print('✅ Provider stats updated: $providerId');
      }
    } catch (e) {
      print('❌ Error updating provider stats: $e');
    }
  }

  // Get provider bookings (you'll need to implement booking system)
  Future<List<Map<String, dynamic>>> getProviderBookings({
    required String providerId,
    String status = 'all',
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      QuerySnapshot snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting provider bookings: $e');
      return [];
    }
  }

  // Get provider earnings summary
  Future<Map<String, dynamic>> getProviderEarnings(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final stats = data['stats'] ?? {};
        
        return {
          'totalEarnings': (stats['earnings'] ?? 0.0).toDouble(),
          'completedJobs': stats['completedJobs'] ?? 0,
          'cancelledJobs': stats['cancelledJobs'] ?? 0,
          'responseRate': (stats['responseRate'] ?? 100.0).toDouble(),
        };
      }
      
      return {
        'totalEarnings': 0.0,
        'completedJobs': 0,
        'cancelledJobs': 0,
        'responseRate': 100.0,
      };
    } catch (e) {
      print('❌ Error getting provider earnings: $e');
      return {
        'totalEarnings': 0.0,
        'completedJobs': 0,
        'cancelledJobs': 0,
        'responseRate': 100.0,
      };
    }
  }

  // Update provider service details
  Future<Map<String, dynamic>> updateProviderServiceDetails({
    required String userId,
    String? serviceType,
    List<String>? serviceAreas,
    String? description,
    double? hourlyRate,
    List<String>? certifications,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (serviceType != null) updates['serviceType'] = serviceType;
      if (serviceAreas != null) updates['serviceAreas'] = serviceAreas;
      if (description != null) updates['description'] = description;
      if (hourlyRate != null) updates['hourlyRate'] = hourlyRate;
      if (certifications != null) updates['certifications'] = certifications;

      await _firestore.collection('providers').doc(userId).update(updates);
      
      // Also update in users collection
      if (serviceType != null) {
        await _firestore.collection('users').doc(userId).update({
          'serviceType': serviceType,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Provider service details updated: $userId');
      return {'success': true};
      
    } catch (e) {
      print('❌ Error updating provider service details: $e');
      return {'success': false, 'error': e.toString()};
    }
  }  

  // ==================== PROVIDER PROFILE UPDATE ====================

  // Update provider profile with all fields
  Future<Map<String, dynamic>> updateProviderProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? description,
    String? businessName,
    double? hourlyRate,
    Map<String, dynamic>? workingHours,
    List<int>? workingDays,
    String? profileImageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Basic info updates
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (description != null) updates['description'] = description;
      if (businessName != null) updates['businessName'] = businessName;
      if (hourlyRate != null) updates['hourlyRate'] = hourlyRate;
      if (profileImageUrl != null) updates['profileImage'] = profileImageUrl;

      // Update in providers collection
      await _firestore.collection('providers').doc(userId).update(updates);

      // Also update in users collection for basic info
      Map<String, dynamic> userUpdates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) userUpdates['name'] = name;
      if (email != null) userUpdates['email'] = email;
      if (phone != null) userUpdates['phone'] = phone;
      
      await _firestore.collection('users').doc(userId).update(userUpdates);

      // Update availability if working hours/days provided
      if (workingHours != null || workingDays != null) {
        await updateProviderAvailability(
          userId: userId,
          workingHours: workingHours,
          workingDays: workingDays,
        );
      }

      print('✅ Provider profile updated: $userId');
      return {'success': true, 'updates': updates};
      
    } catch (e) {
      print('❌ Error updating provider profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> uploadProfileImage({
  required String userId,
  required File imageFile,
}) async {
  try {
    print('🔄 Starting image upload for user: $userId');
    
    // Create unique filename with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'profile_$timestamp.jpg';
    
    // Create reference to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('providers')
        .child(userId)
        .child('profile_images')
        .child(fileName);
    
    print('📁 Storage path: providers/$userId/profile_images/$fileName');
    
    // Compress image if needed
    final compressedImage = await _compressImage(imageFile);
    
    // Upload file with metadata
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedBy': userId,
        'uploadedAt': DateTime.now().toString(),
      },
    );
    
    final uploadTask = storageRef.putFile(compressedImage, metadata);
    
    // Monitor upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
    });
    
    // Wait for upload to complete
    final snapshot = await uploadTask;
    
    if (snapshot.state == TaskState.success) {
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ Image uploaded successfully: $downloadUrl');
      
      // Delete old profile images (optional)
      await _cleanupOldProfileImages(userId);
      
      return downloadUrl;
    } else {
      print('❌ Upload failed: ${snapshot.state}');
      return null;
    }
    
  } catch (e) {
    print('❌ Error uploading profile image: $e');
    print('Error details: ${e.toString()}');
    return null;
  }
}

// Helper method to compress image
Future<File> _compressImage(File imageFile) async {
  try {
    // For now, return the original file
    // You can add image compression here if needed
    return imageFile;
  } catch (e) {
    print('❌ Error compressing image: $e');
    return imageFile;
  }
}

// Cleanup old profile images
Future<void> _cleanupOldProfileImages(String userId) async {
  try {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('providers')
        .child(userId)
        .child('profile_images');
    
    final listResult = await storageRef.listAll();
    
    // Keep only the last 3 images
    if (listResult.items.length > 3) {
      // Sort by name (which includes timestamp)
      final sortedItems = listResult.items.toList()
        ..sort((a, b) => b.name.compareTo(a.name));
      
      // Delete older images
      for (int i = 3; i < sortedItems.length; i++) {
        await sortedItems[i].delete();
        print('🗑️ Deleted old image: ${sortedItems[i].name}');
      }
    }
  } catch (e) {
    print('⚠️ Error cleaning up old images: $e');
  }
}

// Update only profile image in Firestore
Future<Map<String, dynamic>> updateProfileImage({
  required String userId,
  required String imageUrl,
}) async {
  try {
    Map<String, dynamic> updates = {
      'profileImage': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Update in providers collection
    await _firestore.collection('providers').doc(userId).update(updates);
    
    // Also update in users collection
    await _firestore.collection('users').doc(userId).update({
      'profileImage': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Profile image updated in Firestore: $userId');
    return {'success': true};
    
  } catch (e) {
    print('❌ Error updating profile image in Firestore: $e');
    return {'success': false, 'error': e.toString()};
  }
}

  // Set provider working hours
  Future<Map<String, dynamic>> setProviderWorkingHours({
    required String providerId,
    required String startTime,
    required String endTime,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'availability.workingHours': {
          'start': startTime,
          'end': endTime,
        },
      };

      await _firestore.collection('providers').doc(providerId).update(updates);
      
      print('✅ Provider working hours updated: $providerId ($startTime - $endTime)');
      
      return {'success': true, 'updates': updates};
      
    } catch (e) {
      print('❌ Error updating working hours: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Set provider working days
  Future<Map<String, dynamic>> setProviderWorkingDays({
    required String providerId,
    required List<int> workingDays,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
        'availability.workingDays': workingDays,
      };

      await _firestore.collection('providers').doc(providerId).update(updates);
      
      print('✅ Provider working days updated: $providerId - $workingDays');
      
      return {'success': true, 'updates': updates};
      
    } catch (e) {
      print('❌ Error updating working days: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== COMMON METHODS ====================

  // Helper to build location data
  Map<String, dynamic> _buildLocationData({
    String? address,
    double? latitude,
    double? longitude,
  }) {
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

    return locationData;
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

      await _firestore.collection('users').doc(userId).update(updates);
      
      print('✅ User location updated: $userId');
      
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
        final data = doc.data() as Map<String, dynamic>;
        
        // If user is a provider, get provider details too
        if (data['userType'] == 'provider') {
          final providerData = await getProviderData(userId);
          if (providerData != null) {
            return {...data, ...providerData};
          }
        }
        
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Get user type
  Future<String?> getUserType(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['userType'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting user type: $e');
      return null;
    }
  }

  // Check if user exists
  Future<bool> checkUserExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking user existence: $e');
      return false;
    }
  }

  // Get provider data
  Future<Map<String, dynamic>?> getProviderData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('providers').doc(userId).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('❌ Error getting provider data: $e');
      return null;
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (email != null && email.isNotEmpty) updates['email'] = email;
      if (phone != null && phone.isNotEmpty) updates['phone'] = phone;
      if (profileImage != null) updates['profileImage'] = profileImage;

      await _firestore.collection('users').doc(userId).update(updates);
      
      print('✅ User profile updated: $userId');
      return {'success': true, 'updates': updates};
      
    } catch (e) {
      print('❌ Error updating user profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update last active
  Future<void> updateLastActive(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating last active: $e');
    }
  }

  // Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking email existence: $e');
      return false;
    }
  }

  // Check if phone exists
  Future<bool> phoneExists(String phone) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking phone existence: $e');
      return false;
    }
  }

  // Get nearby providers
  Future<List<Map<String, dynamic>>> getNearbyProviders({
    required double latitude,
    required double longitude,
    required double radiusInKm,
    String? serviceType,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('providers')
          .where('availability.isAvailable', isEqualTo: true)
          .limit(limit);

      if (serviceType != null && serviceType.isNotEmpty) {
        query = query.where('serviceType', isEqualTo: serviceType);
      }

      QuerySnapshot snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
              'distance': 0.0,
            };
          })
          .toList();
          
    } catch (e) {
      print('❌ Error getting nearby providers: $e');
      return [];
    }
  }

  // Get service categories
  Future<List<String>> getServiceCategories() async {
    return [
      'electrician',
      'plumber',
      'cleaner',
      'carpenter',
      'painter',
      'ac_repair',
      'appliance_repair',
      'gardener',
      'mover',
      'handyman',
    ];
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Delete user
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      print('✅ User deleted: $userId');
      return {'success': true};
    } catch (e) {
      print('❌ Error deleting user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}