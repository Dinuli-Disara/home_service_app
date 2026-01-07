import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../widgets/location_permission_dialog.dart';
import '../widgets/manual_location_dialog.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';
import '../widgets/servigo_logo.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({Key? key}) : super(key: key);

  final Uuid uuid = Uuid();
  final UserService userService = UserService();
  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ServiGo Logo & Branding
              ServiGoLogo(size: 80, showTagline: true, showIcon: true),
              SizedBox(height: 40),
              
              // Welcome Message (with language support)
              Text(
                languageProvider.get('welcome_to_servigo') ?? 'Welcome to ServiGo',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.trustBlue,
                ),
              ),
              SizedBox(height: 8),
              Text(
                languageProvider.get('tagline') ?? 'Find. Book. Fix. Local Services',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 40),
              
              // Phone Login Button - Action Orange
              ElevatedButton(
                onPressed: () => _navigateToPhoneLogin(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  backgroundColor: AppColors.actionOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      languageProvider.get('continue_with_phone') ?? 'Continue with Phone',
                      style: AppTextStyles.buttonLarge,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // Email Login Button - Trust Blue
              ElevatedButton(
                onPressed: () => _navigateToEmailLogin(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  backgroundColor: AppColors.trustBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      languageProvider.get('continue_with_email') ?? 'Continue with Email',
                      style: AppTextStyles.buttonLarge,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // Google Login Button - New from updated version
              ElevatedButton(
                onPressed: () => _signInWithGoogle(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  backgroundColor: AppColors.error, // Using error color (red-like) for Google
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.g_mobiledata, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      languageProvider.get('continue_with_google') ?? 'Continue with Google',
                      style: AppTextStyles.buttonLarge,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // Guest Button - Outlined in Modern Teal
              OutlinedButton(
                onPressed: () => _handleGuestAccess(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  side: BorderSide(color: AppColors.modernTeal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, color: AppColors.modernTeal),
                    SizedBox(width: 12),
                    Text(
                      languageProvider.get('continue_as_guest') ?? 'Continue as Guest',
                      style: AppTextStyles.buttonSecondary.copyWith(
                        color: AppColors.modernTeal,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              
              // Divider with "or"
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.divider,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      languageProvider.get('or') ?? 'or',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.divider,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    languageProvider.get('dont_have_account') ?? "Don't have an account? ",
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: Text(
                      languageProvider.get('sign_up') ?? 'Sign Up',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.vividAzure,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),
              
              // Terms and Privacy notice
              Text(
                languageProvider.get('terms_privacy') ?? 'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods from updated version
  void _navigateToPhoneLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone login coming soon!'),
        backgroundColor: AppColors.vividAzure,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    // TODO: Implement actual phone login navigation
    // Navigator.pushNamed(context, '/phone-login');
  }

  void _navigateToEmailLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email login coming soon!'),
        backgroundColor: AppColors.vividAzure,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    // TODO: Implement actual email login navigation
    // Navigator.pushNamed(context, '/email-login');
  }

  // Google Sign In from updated version
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final userCredential = await authService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        _showLocationDialog(context, userCredential.user!.uid, userCredential.user!.displayName ?? 'User');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign in failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      // Fallback to guest access if Google fails
      _handleGuestAccess(context);
    }
  }

  // Guest access (keeps your current functionality)
  Future<void> _handleGuestAccess(BuildContext context) async {
    print('Guest access selected');

    // Generate unique ID for guest user
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
      onComplete: (Map<String, dynamic>? locationData) async {
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
      
        // Show success message with ServiGo colors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ServiGo! Location saved successfully.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    
      await Future.delayed(Duration(seconds: 1));
      Navigator.pushReplacementNamed(context, '/main-home');
    }
  }
}