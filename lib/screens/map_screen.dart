import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_service_app/services/user_service.dart';
import 'package:home_service_app/constants/app_colors.dart';
import 'package:home_service_app/constants/text_styles.dart';

class MapScreen extends StatefulWidget {
  final String? serviceType;
  final String? serviceName;

  const MapScreen({Key? key, this.serviceType, this.serviceName}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isLoading = true;
  String _errorMessage = '';
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadServiceProviders();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied, we cannot request permissions.';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _moveToCurrentLocation();
        _addUserMarker();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _moveToCurrentLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 14,
          ),
        ),
      );
    }
  }

  void _addUserMarker() {
    if (_currentPosition != null) {
      final marker = Marker(
        markerId: MarkerId('user_location'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Your Location'),
      );

      setState(() {
        _markers.add(marker);
      });

      // Add circle around user location
      final circle = Circle(
        circleId: CircleId('user_radius'),
        center: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        radius: 5000, // 5km radius
        fillColor: AppColors.vividAzure.withOpacity(0.1),
        strokeColor: AppColors.vividAzure.withOpacity(0.3),
        strokeWidth: 1,
      );

      setState(() {
        _circles.add(circle);
      });
    }
  }

  Future<void> _loadServiceProviders() async {
    try {
      Query query = _firestore.collection('providers')
        .where('availability.isAvailable', isEqualTo: true);

      // Filter by service type if provided
      if (widget.serviceType != null && widget.serviceType!.isNotEmpty) {
        query = query.where('serviceType', isEqualTo: widget.serviceType);
      }

      QuerySnapshot snapshot = await query.get();

      List<Marker> providerMarkers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if provider has location data
        if (data['location'] != null) {
          final location = data['location'] as Map<String, dynamic>;
          
          if (location['coordinates'] != null) {
            final coordinates = location['coordinates'] as Map<String, dynamic>;
            final lat = coordinates['latitude'] as double;
            final lng = coordinates['longitude'] as double;
            
            // Get provider details
            final name = data['name'] ?? 'Service Provider';
            final businessName = data['businessName'] ?? '';
            final serviceType = data['serviceType'] ?? 'Service';
            final rating = data['rating'] ?? 0.0;
            final totalJobs = data['totalJobs'] ?? 0;
            final isVerified = data['isVerified'] ?? false;

            // Create marker
            final marker = Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              icon: await _getMarkerIcon(serviceType, isVerified),
              infoWindow: InfoWindow(
                title: businessName.isNotEmpty ? businessName : name,
                snippet: '$serviceType | ⭐ ${rating.toStringAsFixed(1)} | 📞 ${data['phone'] ?? ''}',
                onTap: () {
                  _showProviderDetails(doc.id, data);
                },
              ),
              onTap: () {
                _showProviderDetails(doc.id, data);
              },
            );

            providerMarkers.add(marker);
          }
        }
      }

      setState(() {
        _markers.addAll(providerMarkers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading providers: $e';
        _isLoading = false;
      });
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String serviceType, bool isVerified) async {
    // Default color based on service type
    double hue = BitmapDescriptor.hueOrange;
    
    // Set different colors for different service types
    switch (serviceType) {
      case 'electrician':
        hue = BitmapDescriptor.hueYellow;
        break;
      case 'plumber':
        hue = BitmapDescriptor.hueBlue;
        break;
      case 'cleaner':
        hue = BitmapDescriptor.hueGreen;
        break;
      case 'carpenter':
        hue = BitmapDescriptor.hueRed;
        break;
      case 'ac_repair':
        hue = BitmapDescriptor.hueCyan;
        break;
      case 'painter':
        hue = BitmapDescriptor.hueViolet;
        break;
      case 'gardener':
        hue = BitmapDescriptor.hueRose;
        break;
      default:
        hue = BitmapDescriptor.hueOrange;
    }
    
    // Add verification badge if provider is verified
    if (isVerified) {
      // For verified providers, use a different marker style
      return BitmapDescriptor.defaultMarkerWithHue(hue);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(hue);
    }
  }

  void _showProviderDetails(String providerId, Map<String, dynamic> providerData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ProviderDetailsBottomSheet(
          providerId: providerId,
          providerData: providerData,
          currentPosition: _currentPosition,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.serviceName ?? 'Find Services',
              style: AppTextStyles.heading5.copyWith(color: Colors.white),
            ),
            if (widget.serviceName != null)
              Text(
                'Nearby ${widget.serviceName}s',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.trustBlue,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location, color: Colors.white),
            onPressed: _moveToCurrentLocation,
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.vividAzure),
                  SizedBox(height: 20),
                  Text(
                    'Loading service providers...',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: AppColors.error),
                      SizedBox(height: 20),
                      Text(
                        _errorMessage,
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = '';
                          });
                          _loadServiceProviders();
                        },
                        child: Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.vividAzure,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: _initialCameraPosition,
                      onMapCreated: (controller) {
                        setState(() {
                          _mapController = controller;
                        });
                      },
                      markers: _markers,
                      circles: _circles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: true,
                      onTap: (position) {
                        // Clear selection if tapping on map
                      },
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _moveToCurrentLocation,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.my_location, color: AppColors.vividAzure),
                      ),
                    ),
                    if (_markers.length > 1)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Found ${_markers.length - 1} ${widget.serviceName ?? 'service provider'}${_markers.length - 1 == 1 ? '' : 's'} nearby',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FilterBottomSheet(
          onFilterChanged: (filters) {
            // Apply filters and reload providers
            // You can implement filter logic here
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class ProviderDetailsBottomSheet extends StatelessWidget {
  final String providerId;
  final Map<String, dynamic> providerData;
  final Position? currentPosition;

  const ProviderDetailsBottomSheet({
    Key? key,
    required this.providerId,
    required this.providerData,
    this.currentPosition,
  }) : super(key: key);

  Future<void> _calculateDistance() async {
    if (currentPosition != null && providerData['location'] != null) {
      final location = providerData['location'] as Map<String, dynamic>;
      if (location['coordinates'] != null) {
        final coordinates = location['coordinates'] as Map<String, dynamic>;
        final lat = coordinates['latitude'] as double;
        final lng = coordinates['longitude'] as double;
        
        double distanceInMeters = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          lat,
          lng,
        );
        
        double distanceInKm = distanceInMeters / 1000;
        // You can show this in the UI
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = providerData['name'] ?? 'Service Provider';
    final businessName = providerData['businessName'] ?? '';
    final serviceType = providerData['serviceType'] ?? 'Service';
    final rating = (providerData['rating'] ?? 0.0).toDouble();
    final totalJobs = providerData['totalJobs'] ?? 0;
    final description = providerData['description'] ?? '';
    final phone = providerData['phone'] ?? '';
    final email = providerData['email'] ?? '';
    final hourlyRate = providerData['hourlyRate'] ?? 0.0;
    final isVerified = providerData['isVerified'] ?? false;
    final certifications = providerData['certifications'] as List<dynamic>? ?? [];
    
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.vividAzure.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.vividAzure.withOpacity(0.3)),
                ),
                child: providerData['profileImage'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          providerData['profileImage'],
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 30,
                        color: AppColors.vividAzure,
                      ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          businessName.isNotEmpty ? businessName : name,
                          style: AppTextStyles.heading5.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8),
                        if (isVerified)
                          Icon(Icons.verified, color: AppColors.success, size: 18),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      serviceType,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: AppColors.warning),
                        SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '($totalJobs jobs)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          if (description.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          
          Row(
            children: [
              InfoChip(
                icon: Icons.attach_money,
                text: '₹${hourlyRate.toInt()}/hour',
                color: AppColors.success,
              ),
              SizedBox(width: 8),
              InfoChip(
                icon: Icons.phone,
                text: phone,
                color: AppColors.vividAzure,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          if (certifications.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certifications',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: certifications
                      .map((cert) => Chip(
                            label: Text(
                              cert.toString(),
                              style: AppTextStyles.caption,
                            ),
                            backgroundColor: AppColors.vividAzure.withOpacity(0.1),
                            labelPadding: EdgeInsets.symmetric(horizontal: 8),
                          ))
                      .toList(),
                ),
                SizedBox(height: 16),
              ],
            ),
          
          SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Implement call functionality
                    // You can use url_launcher package to make calls
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.vividAzure),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, size: 20, color: AppColors.vividAzure),
                      SizedBox(width: 8),
                      Text('Call', style: AppTextStyles.buttonSecondary),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/booking',
                      arguments: {
                        'providerId': providerId,
                        'providerName': name,
                        'serviceType': serviceType,
                        'hourlyRate': hourlyRate,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionOrange,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_online, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Book Now', style: AppTextStyles.button),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 10),
          
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/view-provider-profile',
                arguments: {'providerId': providerId},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.vividAzure,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View Full Profile', style: AppTextStyles.buttonSecondary),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const InfoChip({
    Key? key,
    required this.icon,
    required this.text,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onFilterChanged;

  const FilterBottomSheet({Key? key, required this.onFilterChanged}) : super(key: key);

  @override
  _FilterBottomSheetState createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  double _radius = 10.0; // km
  double _minRating = 4.0;
  int _minJobs = 10;
  bool _showVerifiedOnly = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: AppTextStyles.heading5.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: 20),
          
          // Radius filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Radius',
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_radius.toInt()} km',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.vividAzure,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radius,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_radius.toInt()} km',
                activeColor: AppColors.vividAzure,
                inactiveColor: AppColors.vividAzure.withOpacity(0.3),
                onChanged: (value) {
                  setState(() {
                    _radius = value;
                  });
                },
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Rating filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Minimum Rating',
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  ),
                  Text(
                    _minRating.toStringAsFixed(1),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.vividAzure,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _minRating,
                min: 1.0,
                max: 5.0,
                divisions: 8,
                label: _minRating.toStringAsFixed(1),
                activeColor: AppColors.vividAzure,
                inactiveColor: AppColors.vividAzure.withOpacity(0.3),
                onChanged: (value) {
                  setState(() {
                    _minRating = value;
                  });
                },
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Minimum jobs filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Minimum Jobs Completed',
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  ),
                  Text(
                    '$_minJobs',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.vividAzure,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _minJobs.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_minJobs',
                activeColor: AppColors.vividAzure,
                inactiveColor: AppColors.vividAzure.withOpacity(0.3),
                onChanged: (value) {
                  setState(() {
                    _minJobs = value.toInt();
                  });
                },
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Verified only toggle
          SwitchListTile(
            title: Text(
              'Verified Providers Only',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              'Show only verified service providers',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            value: _showVerifiedOnly,
            activeColor: AppColors.success,
            onChanged: (value) {
              setState(() {
                _showVerifiedOnly = value;
              });
            },
          ),
          
          SizedBox(height: 30),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.textDisabled),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Cancel', style: AppTextStyles.buttonSecondary),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final filters = {
                      'radius': _radius,
                      'minRating': _minRating,
                      'minJobs': _minJobs,
                      'verifiedOnly': _showVerifiedOnly,
                    };
                    widget.onFilterChanged(filters);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionOrange,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Apply Filters', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}