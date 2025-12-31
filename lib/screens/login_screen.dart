import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../widgets/location_permission_dialog.dart';
import '../widgets/manual_location_dialog.dart';
import '../services/user_service.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({Key? key}) : super(key: key);

  final Uuid uuid = Uuid();
  final UserService userService = UserService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login / Guest Access'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or App Name
            Text(
              'Home Service App',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 40),
            
            // Phone Login Button
            ElevatedButton(
              onPressed: () => _handleLogin(context, 'phone'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
              child: Text(
                'Login with Phone',
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 15),
            
            // Email Login Button
            ElevatedButton(
              onPressed: () => _handleLogin(context, 'email'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Login with Email',
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 15),
            
            // Guest Button
            OutlinedButton(
              onPressed: () => _handleGuestAccess(context),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Continue as Guest',
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 30),
            
            // Sign up text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? "),
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to sign up
                    print('Sign up pressed');
                  },
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin(BuildContext context, String method) {
    print('$method login pressed');
    // TODO: Implement actual login
    // TEMP values until real login is implemented

    // Generate a temporary user ID for testing
    final tempUserId = 'user_${uuid.v4()}'; // Use the uuid instance
    final tempUserName = 'User';
    // After successful login, show location dialog
    _showLocationDialog(context, tempUserId, tempUserName);
  }

  void _handleGuestAccess(BuildContext context) async {
    print('Guest access selected');

    //Generate unique ID for guest user
    final guestUserId = 'guest_${uuid.v4()}';
    
    // Save guest mode preference locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGuest', true);
    await prefs.setString('userId', guestUserId);
    await prefs.setString('userName', 'Guest User');
    
    // Show location dialog
    _showLocationDialog(context, guestUserId, 'Guest User');
  }

  void _showLocationDialog(BuildContext context, String userId, String userName) async {
    // Show location permission dialog
    await LocationPermissionDialog.show(
      context: context,
      onComplete: (Map<String, dynamic>? locationData) async { // Add type
        if (locationData == null) {
          // User cancelled
          return;
        }
      
        if (locationData['type'] == 'manual') {
          // Show manual location dialog
          final Map<String, dynamic>? manualLocationData = await ManualLocationDialog.show(
            context: context,
          );
        
          if (manualLocationData != null) {
            await _saveLocationAndNavigate(
              context, 
              userId, 
              userName, 
              manualLocationData
            );
          }
        } else if (locationData['type'] == 'gps') {
          // GPS location obtained
          await _saveLocationAndNavigate(
            context, 
            userId, 
            userName, 
            locationData
          );
        }
      },
    );
  }

  Future<void> _saveLocationAndNavigate(
    BuildContext context, 
    String userId, 
    String userName, 
    Map<String, dynamic> locationData
  ) async {
    try {
      // Save to SharedPreferences (local)
      final prefs = await SharedPreferences.getInstance();
    
      // Format location for display
      String displayLocation = '';
      if (locationData['type'] == 'gps') {
        displayLocation = 'GPS: ${locationData['latitude']}, ${locationData['longitude']}';
      } else if (locationData['type'] == 'manual') {
        displayLocation = locationData['address'] ?? 'Manual Location';
      }
    
      await prefs.setString('userLocation', displayLocation);
      await prefs.setString('userId', userId);
      await prefs.setString('userName', userName);
      await prefs.setString('locationType', locationData['type'] ?? 'unknown');

      // Save to Firebase Firestore (database)
      final result = await userService.saveGuestUser(
        userId: userId,
        name: userName,
        address: locationData['address'],
        latitude: locationData['latitude'],
        longitude: locationData['longitude'],
      );

      if (result['success'] == true) {
        print('✅ User successfully saved to database!');
        print('👤 User ID: $userId');
        print('📍 Location: $displayLocation');
      
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome! Location saved successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print('⚠️ User saved locally but Firebase failed: ${result['error']}');
        // Still proceed, just log the error
      }

      // Navigate to home screen after a brief delay
      await Future.delayed(Duration(milliseconds: 1500));
      Navigator.pushReplacementNamed(context, '/main-home');
    
    } catch (e) {
      print('❌ Error in save and navigate: $e');
    
      // Show error but still navigate
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location. Continuing anyway.'),
          backgroundColor: Colors.orange,
        ),
      );
    
      await Future.delayed(Duration(seconds: 1));
      Navigator.pushReplacementNamed(context, '/main-home');
    }
  }
}