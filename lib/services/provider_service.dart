import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class ProviderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register a new service provider
  Future<Map<String, dynamic>> registerProvider({
    required String userId,
    required String name,
    required String serviceType,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    int experience = 0,
    double hourlyRate = 0.0,
    List<String> workingDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    String phone = '',
    List<String>? images,
  }) async {
    try {
      // Create geo point for location-based queries
      final geoPoint = GeoPoint(latitude, longitude);
      
      /*final geoFirePoint = GeoFirePoint(
        position: LatLng(latitude, longitude),  // Use LatLng from the package
        geohash: '',  // Will be calculated automatically
      );*/

      final providerData = {
        'providerId': userId,
        'userId': userId,
        'name': name,
        'serviceType': serviceType,
        'description': description,
        'location': {
          'address': address,
          'coordinates': GeoPoint(latitude, longitude),
          'latitude': latitude,
          'longitude': longitude,
        },
        'experience': experience,
        'hourlyRate': hourlyRate,
        'workingDays': workingDays,
        'phone': phone,
        'images': images ?? [],
        'rating': 0.0,
        'totalReviews': 0,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('providers').doc(userId).set(providerData);
      
      print('✅ Provider registered: $name');
      return {'success': true, 'providerId': userId};
      
    } catch (e) {
      print('❌ Error registering provider: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get nearby providers using manual calculation (simpler approach)
  Future<List<Map<String, dynamic>>> getNearbyProviders({
    required double centerLat,
    required double centerLng,
    double radiusKm = 10.0,
    String? serviceType,
    int limit = 50,
  }) async {
    try {
      // Start building query
      Query query = _firestore.collection('providers');
      
      // Add service type filter if specified
      if (serviceType != null && serviceType.isNotEmpty) {
        query = query.where('serviceType', isEqualTo: serviceType);
      }
      
      // Add availability filter
      query = query.where('isAvailable', isEqualTo: true);
      
      // Limit results for performance
      query = query.limit(limit);
      
      final snapshot = await query.get();
      
      // Filter by distance manually
      final List<Map<String, dynamic>> nearbyProviders = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['location'];
        
        if (location != null && location['coordinates'] is GeoPoint) {
          final geoPoint = location['coordinates'] as GeoPoint;
          final distance = calculateDistance(
            centerLat, centerLng,
            geoPoint.latitude, geoPoint.longitude,
          );
          
          if (distance <= radiusKm) {
            data['id'] = doc.id;
            data['distance'] = distance; // Add distance to result
            nearbyProviders.add(data);
          }
        }
      }
      
      // Sort by distance (closest first)
      nearbyProviders.sort((a, b) {
        final distA = a['distance'] ?? double.infinity;
        final distB = b['distance'] ?? double.infinity;
        return distA.compareTo(distB);
      });
      
      return nearbyProviders;
      
    } catch (e) {
      print('❌ Error getting nearby providers: $e');
      return [];
    }
  }

  // Get all providers (simpler version)
  Future<List<Map<String, dynamic>>> getAllProviders({
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('providers')
          .where('isAvailable', isEqualTo: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting providers: $e');
      return [];
    }
  }

  // Get provider by ID
  Future<Map<String, dynamic>?> getProvider(String providerId) async {
    try {
      final doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Error getting provider: $e');
      return null;
    }
  }

  // Calculate distance between two points (in km) - Haversine formula
  double calculateDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const earthRadius = 6371; // Earth's radius in km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
  
  // Update provider availability
  Future<void> updateAvailability(String providerId, bool isAvailable) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating availability: $e');
      rethrow;
    }
  }
  
  // Update provider rating
  Future<void> updateRating(String providerId, double newRating) async {
    try {
      final doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentRating = data['rating'] ?? 0.0;
        final totalReviews = data['totalReviews'] ?? 0;
        
        final newTotalReviews = totalReviews + 1;
        final updatedRating = ((currentRating * totalReviews) + newRating) / newTotalReviews;
        
        await _firestore.collection('providers').doc(providerId).update({
          'rating': updatedRating,
          'totalReviews': newTotalReviews,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating rating: $e');
      rethrow;
    }
  }
}
