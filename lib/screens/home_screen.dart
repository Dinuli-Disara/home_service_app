import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/location_permission_dialog.dart';
import '../widgets/manual_location_dialog.dart';
import '../services/user_service.dart';
import '../services/firebase_test.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDatabaseConnected = false;
  String _databaseStatus = 'Checking...';
  String _userName = 'Guest';
  String _userLocation = 'Location not set';
  String _userId = '';
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkDatabaseStatus();
    _syncWithDatabase(); // Sync with database
 
  }

  Future<void> _checkDatabaseStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
    
      if (userId.isNotEmpty) {
        final userData = await _userService.getUserData(userId);
      
        setState(() {
          if (userData != null) {
            _isDatabaseConnected = true;
            _databaseStatus = 'Connected ✅';
          
            // Update from database if available
            if (userData['location'] != null) {
              final location = userData['location'];
              if (location['address'] != null) {
                _userLocation = location['address'];
              } else if (location['coordinates'] != null) {
                final coords = location['coordinates'];
                _userLocation = 'GPS: ${coords['latitude']}, ${coords['longitude']}';
              }
            }
          
            if (userData['name'] != null) {
              _userName = userData['name'];
            }
          } else {
            _isDatabaseConnected = false;
            _databaseStatus = 'Not in database ⚠️';
          }
        });
      }
    } catch (e) {
      setState(() {
        _databaseStatus = 'Error: $e';
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Guest';
      _userLocation = prefs.getString('userLocation') ?? 'Location not set';
      _userId = prefs.getString('userId') ?? '';
    });
  }

  Future<void> _syncWithDatabase() async {
    if (_userId.isNotEmpty && !_userId.startsWith('guest_')) {
      // For registered users, get latest data from database
      final userData = await _userService.getUserData(_userId);
      if (userData != null) {
        setState(() {
          _userLocation = userData['location'] ?? _userLocation;
          _userName = userData['name'] ?? _userName;
        });
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userLocation', _userLocation);
      }
    }
  }

  Future<void> _changeLocation(BuildContext context) async {
    await LocationPermissionDialog.show(
      context: context,
      onComplete: (Map<String, dynamic>? result) async { // Add type annotation
        if (result == null) {
          return; // User cancelled
        }
      
        if (result['type'] == 'manual') {
          // Show manual location dialog
          final Map<String, dynamic>? manualLocation = await ManualLocationDialog.show(
            context: context,
          );
        
          if (manualLocation != null) {
            await _updateLocation(manualLocation);
          }
        } else if (result['type'] == 'gps') {
          // GPS location obtained
          await _updateLocation(result);
        }
      },
    );
  }

  Future<void> _updateLocation(Map<String, dynamic> locationData) async {
    final prefs = await SharedPreferences.getInstance();
  
    // Format location for display
    String displayLocation = '';
    if (locationData['type'] == 'gps') {
      displayLocation = 'GPS: ${locationData['latitude']}, ${locationData['longitude']}';
    } else if (locationData['type'] == 'manual') {
      displayLocation = locationData['address'] ?? 'Manual Location';
    }
  
    // Save to local storage
    await prefs.setString('userLocation', displayLocation);
  
    // Also update in database if user ID exists
    if (_userId.isNotEmpty) {
      await _userService.updateUserLocation(
        userId: _userId,
        address: locationData['address'],
        latitude: locationData['latitude'],
        longitude: locationData['longitude'],
      );
    }
  
    setState(() {
      _userLocation = displayLocation;
    });
  
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location updated successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Service App'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // TODO: Notifications screen
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              // TODO: Profile screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $_userName!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userLocation,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              //Show Location dialog again to change Location
                              await _changeLocation(context);
                            },
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              FirebaseTest test = FirebaseTest();
                              await test.testConnection();
                            },
                            child: Text('Test Firebase Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isDatabaseConnected ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isDatabaseConnected ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isDatabaseConnected ? Icons.cloud_done : Icons.cloud_off,
                      size: 16,
                      color: _isDatabaseConnected ? Colors.green : Colors.orange,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Database: $_databaseStatus',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDatabaseConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search for services...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) {
                  // TODO: Search functionality
                },
              ),
              SizedBox(height: 25),
              
              // Service Categories
              Text(
                'Service Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 15),
              
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 0.9,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildServiceCard(Icons.electrical_services, 'Electrician'),
                  _buildServiceCard(Icons.plumbing, 'Plumber'),
                  _buildServiceCard(Icons.cleaning_services, 'Cleaner'),
                  _buildServiceCard(Icons.carpenter, 'Carpenter'),
                  _buildServiceCard(Icons.air, 'AC Repair'),
                  _buildServiceCard(Icons.water_damage, 'Painter'),
                ],
              ),
              SizedBox(height: 25),
              
              // Upcoming Bookings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Bookings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: View all bookings
                    },
                    child: Text('View All'),
                  ),
                ],
              ),
              SizedBox(height: 10),
              
              // Empty bookings placeholder
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'No upcoming bookings',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Book a service
                      },
                      child: Text('Book a Service'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Messages',
          ),
        ],
        onTap: (index) {
          // TODO: Navigation
        },
      ),
    );
  }

  Widget _buildServiceCard(IconData icon, String title) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          print('$title tapped');
          // TODO: Navigate to service providers
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}