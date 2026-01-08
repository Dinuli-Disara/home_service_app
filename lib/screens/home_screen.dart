import 'package:flutter/material.dart';
import 'package:home_service_app/services/booking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/location_permission_dialog.dart';
import '../widgets/manual_location_dialog.dart';
import '../services/user_service.dart';
import '../services/firebase_test.dart';
import '../services/booking_service.dart';
import '../providers/language_provider.dart';
import '../services/reminder_service.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';
import '../widgets/servigo_logo.dart';

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
  final BookingService _bookingService = BookingService();
  int _currentIndex =0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // Home - already here
        break;
      case 1: // Bookings
        Navigator.pushNamed(context, '/my-bookings');
        // Reset index to 0 after navigation
        Future.delayed(Duration(milliseconds: 300), () {
          setState(() {
            _currentIndex = 0;
          });
        });
        break;
      case 2: // Messages
        Navigator.pushNamed(context, '/messages');
        // Reset index to 0 after navigation
        Future.delayed(Duration(milliseconds: 300), () {
          setState(() {
            _currentIndex = 0;
          });
        });
        break;
      case 3: // Profile
        Navigator.pushNamed(context, '/customer-profile');
        // Reset index to 0 after navigation
        Future.delayed(Duration(milliseconds: 300), () {
          setState(() {
            _currentIndex = 0;
          });
        });
        break;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.actionOrange.withOpacity(0.9);
      case 'accepted':
        return AppColors.vividAzure;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textDisabled;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  void _viewBookingDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Service: ${booking['serviceType']}'),
              SizedBox(height: 10),
              Text('Date: ${DateFormat('yyyy-MM-dd').format((booking['date'] as Timestamp).toDate())}'),
              SizedBox(height: 10),
              Text('Time: ${booking['time']}'),
              SizedBox(height: 10),
              Text('Address: ${booking['address']}'),
              SizedBox(height: 10),
              Text('Status: ${_getStatusText(booking['status'])}'),
              if (booking['problemDescription'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(booking['problemDescription']),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (booking['status'] == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelBooking(booking);
              },
              child: Text('Cancel Booking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }

  void _cancelBooking(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement cancel booking
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Booking cancellation feature coming soon!'),
                  backgroundColor: AppColors.vividAzure,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: Text('Yes, Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

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
      onComplete: (Map<String, dynamic>? result) async {
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
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToServiceProviders(String serviceType, String serviceName) async {
    // Check if location is set
    if (_userLocation == 'Location not set' || _userLocation.isEmpty) {
      // Show dialog to set location first
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Location Required'),
          content: Text('Please set your location first to find nearby $serviceName.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _changeLocation(context);
              },
              child: Text('Set Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionOrange,
              ),
            ),
          ],
        ),
      );
      return;
    }
  
    // Navigate to map with service filter
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {
        'serviceType': serviceType,
        'serviceName': serviceName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: ServiGoAppBarLogo(),
        backgroundColor: AppColors.trustBlue,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
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
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.trustBlue, AppColors.vividAzure],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.trustBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  fontFamily: 'OpenSans',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 20, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _userLocation,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontFamily: 'OpenSans',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                            onPressed: () async {
                              await _changeLocation(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Service Categories
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Popular Services',
                    style: AppTextStyles.heading4.copyWith(
                      color: AppColors.trustBlue,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: View all services
                    },
                    child: Text(
                      'See All',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.vividAzure,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildServiceCard(Icons.electrical_services, 'Electrician', 'electrician', AppColors.vividAzure),
                  _buildServiceCard(Icons.plumbing, 'Plumber', 'plumber', AppColors.modernTeal),
                  _buildServiceCard(Icons.cleaning_services, 'Cleaner', 'cleaner', AppColors.actionOrange),
                  _buildServiceCard(Icons.carpenter, 'Carpenter', 'carpenter', AppColors.trustBlue),
                  _buildServiceCard(Icons.ac_unit, 'AC Repair', 'ac_repair', AppColors.vividAzure),
                  _buildServiceCard(Icons.water_damage, 'Painter', 'painter', AppColors.modernTeal),
                  _buildServiceCard(Icons.grass, 'Gardener', 'gardener', AppColors.actionOrange),
                  _buildServiceCard(Icons.security, 'Security', 'security', AppColors.trustBlue),
                  _buildServiceCard(Icons.more_horiz, 'Other', 'other', AppColors.vividAzure),
                ],
              ),
              SizedBox(height: 25),
            ],
          ),
        ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cleanWhite,
          selectedItemColor: AppColors.actionOrange,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.caption,
          onTap: _onTabTapped,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(IconData icon, String title, String serviceType, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _navigateToServiceProviders(serviceType, title);
        },
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}