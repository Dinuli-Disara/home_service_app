import 'dart:async';
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

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginCompleted;
  LoginScreen({Key? key, this.onLoginCompleted}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Uuid uuid = Uuid();
  final UserService userService = UserService();
  final AuthService authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  String? _selectedUserType; // 'customer' or 'provider'

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  
                  // ServiGo Logo & Branding
                  ServiGoLogo(size: 80, showTagline: true, showIcon: true),
                  SizedBox(height: 40),
                  
                  // Welcome Message
                  Text(
                    languageProvider.get('Welcome To Servigo') ?? 'Welcome To ServiGo',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.trustBlue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    languageProvider.get('Sign In To Continue') ?? 'Sign In To Continue',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 40),
                  
                  // User Type Selection
                  Text(
                    languageProvider.get('Select User Type') ?? 'Select User Type',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildUserTypeCard(
                          title: languageProvider.get('Customer') ?? 'Customer',
                          subtitle: languageProvider.get('I need services') ?? 'I need services',
                          icon: Icons.person,
                          isSelected: _selectedUserType == 'customer',
                          onTap: () => setState(() => _selectedUserType = 'customer'),
                          color: AppColors.actionOrange,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildUserTypeCard(
                          title: languageProvider.get('Service Provider') ?? 'Service Provider',
                          subtitle: languageProvider.get('I offer services') ?? 'I offer services',
                          icon: Icons.handyman,
                          isSelected: _selectedUserType == 'provider',
                          onTap: () => setState(() => _selectedUserType = 'provider'),
                          color: AppColors.modernTeal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  
                  // Only show login form if user type is selected
                  if (_selectedUserType != null) ...[
                    // Error Message
                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                    
                    // Email/Username Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: languageProvider.get('email_address') ?? 'Email Address',
                        prefixIcon: Icon(Icons.email, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.vividAzure, width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: languageProvider.get('password') ?? 'Password',
                        prefixIcon: Icon(Icons.lock, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.vividAzure, width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                        },
                        child: Text(
                          languageProvider.get('forgot_password') ?? 'Forgot Password?',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.vividAzure,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 56),
                          backgroundColor: _selectedUserType == 'customer' 
                              ? AppColors.actionOrange 
                              : AppColors.modernTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                languageProvider.get('sign_in') ?? 'Sign In',
                                style: AppTextStyles.buttonLarge,
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // OR Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.divider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            languageProvider.get('or') ?? 'or',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.divider)),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Continue as Guest Button (Only for customers)
                  if (_selectedUserType == 'customer' || _selectedUserType == null) ...[
                    OutlinedButton(
                      onPressed: _isLoading ? null : _handleGuestAccess,
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
                    SizedBox(height: 24),
                  ],
                  
                  // Google Sign In Button
                  if (_selectedUserType == 'customer' || _selectedUserType == null) ...[
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 56),
                        backgroundColor: AppColors.error,
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
                  ],
                  
                  // Sign Up Link with user type
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
                        onTap: _isLoading ? null : () {
                          Navigator.pushNamed(
                            context, 
                            '/signup',
                            arguments: _selectedUserType ?? 'customer',
                          );
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
                  SizedBox(height: 30),
                  
                  // Terms and Privacy notice
                  Text(
                    languageProvider.get('terms_privacy') ?? 'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textDisabled,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? color : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== LOCATION METHODS ====================

  Future<Map<String, dynamic>?> _getLocationData(BuildContext context) async {
    Completer<Map<String, dynamic>?> completer = Completer();
    
    await LocationPermissionDialog.show(
      context: context,
      onComplete: (Map<String, dynamic>? locationData) async {
        if (locationData == null) {
          completer.complete(null);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        
        // Save location type
        await prefs.setString('locationType', locationData['type'] ?? 'unknown');
        await prefs.setBool('locationPermissionAsked', true);
        
        // If location is from GPS
        if (locationData['type'] == 'gps' && 
            locationData['latitude'] != null && 
            locationData['longitude'] != null) {
          final result = {
            'type': 'gps',
            'latitude': locationData['latitude'],
            'longitude': locationData['longitude'],
          };
          
          // Save to SharedPreferences
          await prefs.setDouble('latitude', locationData['latitude']);
          await prefs.setDouble('longitude', locationData['longitude']);
          await prefs.setString('userLocation', 
              'GPS: ${locationData['latitude']}, ${locationData['longitude']}');
          
          completer.complete(result);
        }
        
        // If manual location needed
        else if (locationData['type'] == 'manual') {
          final Map<String, dynamic>? manualLocationData = 
              await ManualLocationDialog.show(context: context);
          
          if (manualLocationData != null) {
            final result = {
              'type': 'manual',
              'address': manualLocationData['address'],
              'latitude': manualLocationData['latitude'],
              'longitude': manualLocationData['longitude'],
            };
            
            // Save to SharedPreferences
            await prefs.setString('userLocation', 
                manualLocationData['address'] ?? 'Manual Location');
            if (manualLocationData['latitude'] != null && 
                manualLocationData['longitude'] != null) {
              await prefs.setDouble('latitude', manualLocationData['latitude']);
              await prefs.setDouble('longitude', manualLocationData['longitude']);
            }
            
            completer.complete(result);
          } else {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      },
    );
    
    return completer.future;
  }

  // ==================== LOGIN METHODS ====================

  Future<void> _handleLogin() async {
    if (_selectedUserType == null) {
      setState(() {
        _errorMessage = 'Please select user type (Customer or Service Provider)';
      });
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // First get location data
      final locationData = await _getLocationData(context);
      
      if (locationData == null) {
        // User cancelled location, but we can still proceed
        print('⚠️ Location not provided, continuing without location');
      }
      
      // Now proceed with login
      final user = await authService.loginWithEmail(email, password);
      
      if (user != null) {
        // Get user type from Firestore
        final userType = await userService.getUserType(user.uid);
        
        if (userType == null) {
          // New user - save with selected type AND LOCATION
          if (_selectedUserType == 'customer') {
            await userService.saveCustomer(
              userId: user.uid,
              name: user.displayName ?? 'Customer',
              email: user.email,
              authMethod: 'email',
              address: locationData?['address'],
              latitude: locationData?['latitude'],
              longitude: locationData?['longitude'],
            );
          } else if (_selectedUserType == 'provider') {
            // Navigate to provider registration WITH LOCATION
            _navigateToProviderRegistration(
              user.uid, 
              user.email ?? '',
              locationData,
            );
            return;
          }
        } else if (userType != _selectedUserType) {
          // User type mismatch
          setState(() {
            _errorMessage = 'This account is registered as a ${userType == 'customer' ? 'Customer' : 'Service Provider'}. Please select the correct user type.';
          });
          return;
        }
        
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isGuest', false);
        await prefs.setString('userId', user.uid);
        await prefs.setString('userName', user.displayName ?? 'User');
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('userType', _selectedUserType!);
        
        // Save login completion status
        await prefs.setBool('login_completed', true);
        
        // Call the callback if provided
        if (widget.onLoginCompleted != null) {
          widget.onLoginCompleted!();
        }
        
        // Save location data locally if available
        if (locationData != null) {
          await prefs.setString('locationType', locationData['type'] ?? 'unknown');
          if (locationData['address'] != null) {
            await prefs.setString('userLocation', locationData['address']!);
          }
          if (locationData['latitude'] != null && locationData['longitude'] != null) {
            await prefs.setDouble('latitude', locationData['latitude']!);
            await prefs.setDouble('longitude', locationData['longitude']!);
          }
        }
        
        // Update user location in Firestore if provided
        if (locationData != null) {
          await userService.updateUserLocation(
            userId: user.uid,
            address: locationData['address'],
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
          );
        }
        
        // Navigate based on user type
        _navigateToHome(user.uid);
      }
    } catch (e) {
      String errorMessage = 'Login failed';
      
      if (e.toString().contains('wrong-password') || 
          e.toString().contains('user-not-found')) {
        errorMessage = 'Invalid email or password';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many attempts. Please try again later';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==================== GUEST ACCESS ====================

  Future<void> _handleGuestAccess() async {
    setState(() {
      _isLoading = true;
      _selectedUserType = 'customer'; // Guest is always customer
    });

    try {
      // First get location data
      final locationData = await _getLocationData(context);
      
      // Generate unique ID for guest user
      final guestUserId = 'guest_${uuid.v4()}';
      
      // Save to Firestore WITH LOCATION
      await userService.saveCustomer(
        userId: guestUserId,
        name: 'Guest Customer',
        authMethod: 'guest',
        isGuest: true,
        address: locationData?['address'],
        latitude: locationData?['latitude'],
        longitude: locationData?['longitude'],
      );
      
      // Save guest mode preference locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', true);
      await prefs.setString('userId', guestUserId);
      await prefs.setString('userName', 'Guest Customer');
      await prefs.setString('userType', 'customer');
      
      // Save login completion status
      await prefs.setBool('login_completed', true);
      
      // Call the callback if provided
      if (widget.onLoginCompleted != null) {
        widget.onLoginCompleted!();
      }
      
      // Save location data locally if available
      if (locationData != null) {
        await prefs.setString('locationType', locationData['type'] ?? 'unknown');
        if (locationData['address'] != null) {
          await prefs.setString('userLocation', locationData['address']!);
        }
        if (locationData['latitude'] != null && locationData['longitude'] != null) {
          await prefs.setDouble('latitude', locationData['latitude']!);
          await prefs.setDouble('longitude', locationData['longitude']!);
        }
      }
      
      // Show success message
      _showSuccessSnackbar('Welcome Guest! Location saved successfully.');
      
      // Navigate to home (guest is always customer)
      await Future.delayed(Duration(milliseconds: 1000));
      Navigator.pushReplacementNamed(context, '/main-home');
      
    } catch (e) {
      _showErrorSnackbar('Guest access failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==================== GOOGLE SIGN IN ====================

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _selectedUserType = 'customer'; // Default for Google sign-in
    });

    try {
      // First get location data
      final locationData = await _getLocationData(context);
      
      final userCredential = await authService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        await _handleGoogleSignInComplete(
          userCredential.user!.uid,
          userCredential.user!.displayName ?? 'Google User',
          userCredential.user!.email,
          locationData,
        );
      }
    } catch (e) {
      _showErrorSnackbar('Google sign in failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignInComplete(
    String userId,
    String userName,
    String? userEmail,
    Map<String, dynamic>? locationData,
  ) async {
    try {
      // Check if user exists
      final userType = await userService.getUserType(userId);
      
      if (userType == null) {
        // New Google user - ask for user type
        await _showUserTypeDialogForGoogle(userId, userName, userEmail, locationData);
      } else {
        // Existing user - save location if provided
        if (locationData != null) {
          await userService.updateUserLocation(
            userId: userId,
            address: locationData['address'],
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
          );
        }
        
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isGuest', false);
        await prefs.setString('userId', userId);
        await prefs.setString('userName', userName);
        await prefs.setString('userEmail', userEmail ?? '');
        await prefs.setString('userType', userType);
        
        // Save login completion status
        await prefs.setBool('login_completed', true);
        
        // Call the callback if provided
        if (widget.onLoginCompleted != null) {
          widget.onLoginCompleted!();
        }
        
        // Save location data locally if available
        if (locationData != null) {
          await prefs.setString('locationType', locationData['type'] ?? 'unknown');
          if (locationData['address'] != null) {
            await prefs.setString('userLocation', locationData['address']!);
          }
          if (locationData['latitude'] != null && locationData['longitude'] != null) {
            await prefs.setDouble('latitude', locationData['latitude']!);
            await prefs.setDouble('longitude', locationData['longitude']!);
          }
        }
        
        // Navigate based on existing user type
        if (userType == 'customer') {
          Navigator.pushReplacementNamed(context, '/main-home');
        } else {
          Navigator.pushReplacementNamed(context, '/provider-dashboard');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error handling Google sign-in: $e');
    }
  }

  Future<void> _showUserTypeDialogForGoogle(
    String userId,
    String userName,
    String? userEmail,
    Map<String, dynamic>? locationData,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Account Type'),
          content: Text('Please select how you want to use ServiGo:'),
          actions: <Widget>[
            TextButton(
              child: Text('Customer'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveGoogleUserAsCustomer(userId, userName, userEmail, locationData);
              },
            ),
            TextButton(
              child: Text('Service Provider'),
              onPressed: () async {
                Navigator.of(context).pop();
                _navigateToProviderRegistration(
                  userId,
                  userEmail ?? '',
                  locationData,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveGoogleUserAsCustomer(
    String userId,
    String userName,
    String? userEmail,
    Map<String, dynamic>? locationData,
  ) async {
    try {
      await userService.saveCustomer(
        userId: userId,
        name: userName,
        email: userEmail,
        authMethod: 'google',
        address: locationData?['address'],
        latitude: locationData?['latitude'],
        longitude: locationData?['longitude'],
      );
      
      // Save user data locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', false);
      await prefs.setString('userId', userId);
      await prefs.setString('userName', userName);
      await prefs.setString('userEmail', userEmail ?? '');
      await prefs.setString('userType', 'customer');
      
      // Save login completion status
      await prefs.setBool('login_completed', true);
      
      // Call the callback if provided
      if (widget.onLoginCompleted != null) {
        widget.onLoginCompleted!();
      }
      
      // Save location data locally if available
      if (locationData != null) {
        await prefs.setString('locationType', locationData['type'] ?? 'unknown');
        if (locationData['address'] != null) {
          await prefs.setString('userLocation', locationData['address']!);
        }
        if (locationData['latitude'] != null && locationData['longitude'] != null) {
          await prefs.setDouble('latitude', locationData['latitude']!);
          await prefs.setDouble('longitude', locationData['longitude']!);
        }
      }
      
      _showSuccessSnackbar('Welcome to ServiGo!');
      Navigator.pushReplacementNamed(context, '/main-home');
    } catch (e) {
      _showErrorSnackbar('Error saving Google user: $e');
    }
  }

  // ==================== NAVIGATION METHODS ====================

  void _navigateToHome(String userId) {
    if (_selectedUserType == 'customer') {
      Navigator.pushReplacementNamed(context, '/main-home');
    } else if (_selectedUserType == 'provider') {
      Navigator.pushReplacementNamed(context, '/provider-dashboard');
    }
  }

  void _navigateToProviderRegistration(
    String userId, 
    String email,
    Map<String, dynamic>? locationData,
  ) {
    Navigator.pushReplacementNamed(
      context,
      '/provider-registration',
      arguments: {
        'userId': userId,
        'email': email,
        'isNew': true,
        'locationData': locationData,
      },
    );
  }

  // ==================== HELPER METHODS ====================

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}