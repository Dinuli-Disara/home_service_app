import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionDialog {
  static Future<void> show({
    required BuildContext context,
    required Function(Map<String, dynamic>?) onComplete,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (BuildContext dialogContext) {
        return _LocationPermissionDialogContent(
          onComplete: onComplete,
        );
      },
    );
  }
}

class _LocationPermissionDialogContent extends StatefulWidget {
  final Function(Map<String, dynamic>?) onComplete;

  const _LocationPermissionDialogContent({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  _LocationPermissionDialogContentState createState() =>
      _LocationPermissionDialogContentState();
}

class _LocationPermissionDialogContentState
    extends State<_LocationPermissionDialogContent> {
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue),
          SizedBox(width: 10),
          Text('Location Access'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To find service providers near you, we need access to your location.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 15),
            
            // Error message
            if (_errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[800], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        // Manual Entry Button
        TextButton(
          onPressed: _isLoading ? null : () => _handleManualEntry(),
          child: Text('ENTER MANUALLY'),
        ),
        
        // Allow Button
        ElevatedButton(
          onPressed: _isLoading ? null : _requestLocationPermission,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('ALLOW LOCATION'),
        ),
      ],
    );
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them in settings.';
          _isLoading = false;
        });
        return;
      }

      // Request permission
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission denied. Please allow access or enter manually.';
          _isLoading = false;
        });
      } else if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied. Please allow access or enter manually.';
          _isLoading = false;
        });
      } else if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission permanently denied. Please enable in app settings.';
          _isLoading = false;
        });
      } else {
        // Permission granted - get current location
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 10, // in meters
          ),
        );

        // Return structured data
        final locationData = {
          'type': 'gps',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': null, // We don't have address from GPS
        };
      
        print('📍 GPS Location obtained: ${position.latitude}, ${position.longitude}');
      
        Navigator.of(context).pop(locationData);
        widget.onComplete(locationData);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Update _handleManualEntry:
  void _handleManualEntry() {
    final manualData = {'type': 'manual'};
    Navigator.of(context).pop(manualData);
    widget.onComplete(manualData);
  }
}