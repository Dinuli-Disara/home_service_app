import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/provider_service.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;
  
  const MapScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _selectedService;
  String? _serviceName;
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  final ProviderService _providerService = ProviderService();
  
  // Different icons for different services
  final Map<String, BitmapDescriptor> _serviceIcons = {};

  @override
  void initState() {
    super.initState();

    if (widget.arguments != null) {
      _selectedService = widget.arguments!['serviceType'];
      _serviceName = widget.arguments!['serviceName'];
    }
    _loadIcons();
    _getUserLocation();
  }

  // Load custom markers for different services
  Future<void> _loadIcons() async {
    // Default icon
    final BitmapDescriptor defaultIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration.empty,
      'assets/map_pin.png', // You'll need to add this asset
    );
    
    // You can create different icons for different services
    _serviceIcons['default'] = defaultIcon;
    // Add more service-specific icons here
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      );
      
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      
      _loadNearbyProviders();
    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyProviders() async {
    if (_userLocation == null) return;
    
    setState(() {
      _isLoading = true;
      _markers.clear();
    });

    try {
      // For now, get all providers (we'll implement geo query later)
      final providers = await _providerService.getAllProviders();
      
      // Add user marker
      _markers.add(
        Marker(
          markerId: MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      );

      // Add provider markers
      for (var provider in providers) {
        final location = provider['location'];
        if (location != null && location['coordinates'] != null) {
          final coords = location['coordinates'];
          final latLng = LatLng(coords['latitude'], coords['longitude']);
          
          _markers.add(
            Marker(
              markerId: MarkerId(provider['providerId']),
              position: latLng,
              icon: _serviceIcons['default'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: provider['name'],
                snippet: '${provider['serviceType']} • Rating: ${provider['rating']}',
              ),
              onTap: () {
                _showProviderDetails(provider);
              },
            ),
          );
        }
      }
      
    } catch (e) {
      print('❌ Error loading providers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProviderDetails(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ProviderDetailsSheet(provider: provider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Service Providers'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Open filter dialog
            },
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.pushNamed(context, '/provider-list');
            },
          ),
        ],
      ),
      body: _isLoading && _userLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _userLocation ?? LatLng(6.9271, 79.8612), // Default to Colombo
                zoom: 12.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerMapOnUser,
        child: Icon(Icons.my_location),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _centerMapOnUser() {
    if (_mapController != null && _userLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_userLocation!),
      );
    }
  }
}

// Provider Details Bottom Sheet
class ProviderDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> provider;

  const ProviderDetailsSheet({Key? key, required this.provider}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.person, color: Colors.blue),
                radius: 25,
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider['name'] ?? 'Provider',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      provider['serviceType'] ?? 'Service',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text('${provider['rating'] ?? 0.0} ⭐'),
                backgroundColor: Colors.amber[50],
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Details
          _buildDetailRow(Icons.location_on, provider['location']?['address'] ?? 'No address'),
          _buildDetailRow(Icons.work, '${provider['experience'] ?? 0} years experience'),
          _buildDetailRow(Icons.access_time, 'Available: ${(provider['workingDays'] as List?)?.join(', ') ?? 'Weekdays'}'),
          _buildDetailRow(Icons.attach_money, 'LKR ${provider['hourlyRate'] ?? 0}/hour'),
          
          SizedBox(height: 20),
          
          // Description
          if (provider['description'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  provider['description'],
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          
          SizedBox(height: 25),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Open chat
                  },
                  child: Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/book-service',
                      arguments: provider,
                    );
                  },
                  child: Text('Book Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}