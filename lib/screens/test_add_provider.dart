import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_service_app/constants/app_colors.dart';
import 'package:home_service_app/constants/text_styles.dart';

class TestAddProviderScreen extends StatefulWidget {
  @override
  _TestAddProviderScreenState createState() => _TestAddProviderScreenState();
}

class _TestAddProviderScreenState extends State<TestAddProviderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isAdding = false;
  String _status = '';

  // Test providers with different locations in a city
  final List<Map<String, dynamic>> _testProviders = [
    {
      'userId': 'test_provider_1',
      'name': 'John Electrician',
      'serviceType': 'electrician',
      'businessName': 'John\'s Electrical Services',
      'phone': '+1234567890',
      'rating': 4.5,
      'totalJobs': 50,
      'isVerified': true,
      'availability': {'isAvailable': true},
      'location': {
        'coordinates': {
          'latitude': 37.7749,  // San Francisco coordinates
          'longitude': -122.4194,
        },
        'address': '123 Main St, San Francisco',
        'geoPoint': {'latitude': 37.7749, 'longitude': -122.4194},
      },
    },
    {
      'userId': 'test_provider_2',
      'name': 'Mike Plumber',
      'serviceType': 'plumber',
      'businessName': 'Mike Plumbing Co.',
      'phone': '+1234567891',
      'rating': 4.2,
      'totalJobs': 30,
      'isVerified': false,
      'availability': {'isAvailable': true},
      'location': {
        'coordinates': {
          'latitude': 37.7750,
          'longitude': -122.4184,
        },
        'address': '456 Market St, San Francisco',
        'geoPoint': {'latitude': 37.7750, 'longitude': -122.4184},
      },
    },
    {
      'userId': 'test_provider_3',
      'name': 'Alice Cleaner',
      'serviceType': 'cleaner',
      'businessName': 'Alice Cleaning Services',
      'phone': '+1234567892',
      'rating': 4.8,
      'totalJobs': 100,
      'isVerified': true,
      'availability': {'isAvailable': true},
      'location': {
        'coordinates': {
          'latitude': 37.7739,
          'longitude': -122.4204,
        },
        'address': '789 Pine St, San Francisco',
        'geoPoint': {'latitude': 37.7739, 'longitude': -122.4204},
      },
    },
  ];

  Future<void> _addTestProviders() async {
    setState(() {
      _isAdding = true;
      _status = 'Adding test providers...';
    });

    try {
      for (var provider in _testProviders) {
        await _firestore.collection('providers').doc(provider['userId']).set(provider);
        
        // Also add to users collection
        await _firestore.collection('users').doc(provider['userId']).set({
          'userId': provider['userId'],
          'name': provider['name'],
          'userType': 'provider',
          'serviceType': provider['serviceType'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Added provider: ${provider['name']}');
      }

      setState(() {
        _status = '✅ Test providers added successfully!';
      });

      await Future.delayed(Duration(seconds: 2));
      Navigator.pop(context);

    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  Future<void> _checkExistingProviders() async {
    setState(() {
      _status = 'Checking existing providers...';
    });

    try {
      final snapshot = await _firestore.collection('providers').limit(10).get();
      
      if (snapshot.docs.isEmpty) {
        setState(() {
          _status = 'No providers found in database. Ready to add test data.';
        });
      } else {
        String info = 'Found ${snapshot.docs.length} providers:\n\n';
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          info += '• ${data['name']} (${data['serviceType'] ?? 'N/A'})\n';
          info += '  Location: ${data.containsKey('location') ? 'Yes' : 'No'}\n\n';
        }
        
        setState(() {
          _status = info;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error checking providers: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkExistingProviders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Providers'),
        backgroundColor: AppColors.trustBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Test Providers with Location',
              style: AppTextStyles.heading4.copyWith(color: AppColors.textPrimary),
            ),
            SizedBox(height: 20),
            
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _status,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            if (!_isAdding)
              ElevatedButton(
                onPressed: _addTestProviders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.actionOrange,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Add Test Providers', style: AppTextStyles.button),
              ),
            
            SizedBox(height: 10),
            
            OutlinedButton(
              onPressed: _checkExistingProviders,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.vividAzure),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Refresh Status', style: AppTextStyles.buttonSecondary),
            ),
          ],
        ),
      ),
    );
  }
}