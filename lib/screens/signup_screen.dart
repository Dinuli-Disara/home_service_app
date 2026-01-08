import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../providers/language_provider.dart';
import '../widgets/location_permission_dialog.dart';
import '../widgets/manual_location_dialog.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';
import '../widgets/servigo_logo.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // Form state
  bool _isLoading = false;
  String _loadingMethod = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';
  String _userType = 'customer'; // Default to customer, user can change

  // Service Provider specific fields
  String? _selectedServiceType;
  final TextEditingController _businessNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set initial user type from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      if (args != null) {
        setState(() {
          _userType = args;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isProvider = _userType == 'provider';
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(height: 10),
                  
                  // Header with Logo
                  Center(
                    child: Column(
                      children: [
                        ServiGoLogo(size: 60, showTagline: false, showIcon: true),
                        SizedBox(height: 16),
                        Text(
                          languageProvider.get('create_account') ?? 'Create Account',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.trustBlue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          languageProvider.get('sign_up_to_access') ?? 'Sign up to access all features',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),

                  // User Type Selection (Same as login page)
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
                          isSelected: _userType == 'customer',
                          onTap: () => setState(() => _userType = 'customer'),
                          color: AppColors.actionOrange,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildUserTypeCard(
                          title: languageProvider.get('Service Provider') ?? 'Service Provider',
                          subtitle: languageProvider.get('I offer services') ?? 'I offer services',
                          icon: Icons.handyman,
                          isSelected: _userType == 'provider',
                          onTap: () => setState(() => _userType = 'provider'),
                          color: AppColors.modernTeal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  // Social Login Buttons (No phone option)
                  Text(
                    languageProvider.get('sign_up_with') ?? 'Sign up with',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Email Sign Up Button
                  _buildSocialButton(
                    icon: Icons.email,
                    text: languageProvider.get('continue_with_email') ?? 'Continue with Email',
                    color: AppColors.trustBlue,
                    isLoading: _isLoading && _loadingMethod == 'email',
                    onPressed: () => _showEmailSignUpForm(),
                  ),
                  SizedBox(height: 12),
                  
                  // Google Sign Up Button
                  _buildSocialButton(
                    icon: Icons.g_mobiledata,
                    text: languageProvider.get('continue_with_google') ?? 'Continue with Google',
                    color: Color(0xFFDB4437),
                    isLoading: _isLoading && _loadingMethod == 'google',
                    onPressed: () => _handleGoogleSignUp(),
                  ),
                  SizedBox(height: 30),
                  
                  // Divider
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
                  SizedBox(height: 30),

                  // Email Sign Up Form (Hidden by default)
                  if (_loadingMethod == 'email' || _formKey.currentState != null) ...[
                    _buildEmailSignUpForm(languageProvider, _userType == 'provider'),
                    SizedBox(height: 30),
                  ],

                  // Already have account link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          languageProvider.get('already_have_account') ?? 'Already have an account? ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.pop(context),
                          child: Text(
                            languageProvider.get('sign_in') ?? 'Sign In',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.vividAzure,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Terms and Privacy
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

  final _formKey = GlobalKey<FormState>();

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 56),
        backgroundColor: isLoading ? color.withOpacity(0.7) : color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  text,
                  style: AppTextStyles.buttonLarge,
                ),
              ],
            ),
    );
  }

  Widget _buildEmailSignUpForm(LanguageProvider languageProvider, bool isProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Error message
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

          // Name field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: languageProvider.get('full_name') ?? 'Full Name',
              prefixIcon: Icon(Icons.person, color: AppColors.textSecondary),
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
            validator: (value) => (value == null || value.isEmpty) 
                ? 'Please enter your name' 
                : null,
          ),
          SizedBox(height: 16),

          // Email field
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
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter email';
              if (!value.contains('@')) return 'Invalid email address';
              return null;
            },
          ),
          SizedBox(height: 16),

          // Phone field (important for providers)
          if (isProvider) ...[
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: languageProvider.get('phone_number') ?? 'Phone Number',
                hintText: '+94771234567',
                prefixIcon: Icon(Icons.phone, color: AppColors.textSecondary),
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
              validator: (value) => (value == null || value.isEmpty) 
                  ? 'Phone number is required for service providers'
                  : null,
            ),
            SizedBox(height: 16),
          ],

          // Service Type Dropdown (for providers only)
          if (isProvider) ...[
            DropdownButtonFormField<String>(
              value: _selectedServiceType,
              decoration: InputDecoration(
                labelText: languageProvider.get('service_type') ?? 'Service Type',
                prefixIcon: Icon(Icons.category, color: AppColors.textSecondary),
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
              items: [
                DropdownMenuItem(
                  value: 'electrician',
                  child: Text('Electrician'),
                ),
                DropdownMenuItem(
                  value: 'plumber',
                  child: Text('Plumber'),
                ),
                DropdownMenuItem(
                  value: 'cleaner',
                  child: Text('Cleaner'),
                ),
                DropdownMenuItem(
                  value: 'carpenter',
                  child: Text('Carpenter'),
                ),
                DropdownMenuItem(
                  value: 'painter',
                  child: Text('Painter'),
                ),
                DropdownMenuItem(
                  value: 'ac_repair',
                  child: Text('AC Repair'),
                ),
                DropdownMenuItem(
                  value: 'handyman',
                  child: Text('Handyman'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedServiceType = value;
                });
              },
              validator: (value) => (value == null) 
                  ? 'Please select your service type'
                  : null,
            ),
            SizedBox(height: 16),

            // Business Name (for providers only - optional)
            TextFormField(
              controller: _businessNameController,
              decoration: InputDecoration(
                labelText: languageProvider.get('business_name') ?? 'Business Name (Optional)',
                prefixIcon: Icon(Icons.business, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],

          // Password field
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
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          SizedBox(height: 16),

          // Confirm Password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: languageProvider.get('confirm_password') ?? 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
            validator: (value) {
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          SizedBox(height: 24),

          // Create Account Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailSignUp,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 56),
                backgroundColor: isProvider ? AppColors.modernTeal : AppColors.actionOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading && _loadingMethod == 'email'
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    languageProvider.get('create_account') ?? 'Create Account',
                    style: AppTextStyles.buttonLarge,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailSignUpForm() {
    setState(() {
      _loadingMethod = 'email';
      _errorMessage = '';
    });
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

  // ==================== EMAIL SIGN UP ====================

  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_userType == 'provider') {
      if (_selectedServiceType == null) {
        setState(() {
          _errorMessage = 'Please select your service type';
        });
        return;
      }
      
      if (_phoneController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Phone number is required for service providers';
        });
        return;
      }
    }
    
    // Get location data before signup
    final locationData = await _getLocationData(context);
    
    if (locationData == null) {
      print('⚠️ Location not provided, continuing without location');
    }

    setState(() {
      _isLoading = true;
      _loadingMethod = 'email';
      _errorMessage = '';
    });
    
    try {
      final user = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        userType: _userType,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text.trim() : null,
      );
      
      if (user != null) {
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isGuest', false);
        await prefs.setString('userId', user.uid);
        await prefs.setString('userName', _nameController.text.trim());
        await prefs.setString('userEmail', _emailController.text.trim());
        await prefs.setString('userType', _userType);
        
        if (_phoneController.text.isNotEmpty) {
          await prefs.setString('userPhone', _phoneController.text.trim());
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

        // Save to Firestore with location
        if (_userType == 'customer') {
          await _userService.saveCustomer(
            userId: user.uid,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.isNotEmpty ? _phoneController.text.trim() : null,
            authMethod: 'email',
            address: locationData?['address'],
            latitude: locationData?['latitude'],
            longitude: locationData?['longitude'],
          );
        } else if (_userType == 'provider') {
          await _userService.saveServiceProvider(
            userId: user.uid,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            serviceType: _selectedServiceType!,
            email: _emailController.text.trim(),
            businessName: _businessNameController.text.isNotEmpty 
                ? _businessNameController.text.trim() 
                : null,
            address: locationData?['address'],
            latitude: locationData?['latitude'],
            longitude: locationData?['longitude'],
          );
        }
        
        // Update user location in Firestore if provided
        if (locationData != null) {
          await _userService.updateUserLocation(
            userId: user.uid,
            address: locationData['address'],
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
          );
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _userType == 'provider'
                ? 'Welcome to ServiGo Provider Network!'
                : 'Welcome to ServiGo!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Navigate based on user type
        await Future.delayed(Duration(milliseconds: 1000));
        
        if (_userType == 'customer') {
          Navigator.pushReplacementNamed(context, '/main-home');
        } else if (_userType == 'provider') {
          Navigator.pushReplacementNamed(context, '/provider-dashboard');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Sign up failed';
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password sign up is not enabled';
          break;
        default:
          errorMessage = e.message ?? 'Sign up failed';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== GOOGLE SIGN UP ====================

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _loadingMethod = 'google';
      _errorMessage = '';
    });
    
    try {
      // First get location data
      final locationData = await _getLocationData(context);
      
      if (locationData == null) {
        print('⚠️ Location not provided, continuing without location');
      }
      
      final userCredential = await _authService.signInWithGoogle(userType: _userType);
      
      if (userCredential != null && userCredential.user != null) {
        final user = userCredential.user!;
        
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isGuest', false);
        await prefs.setString('userId', user.uid);
        await prefs.setString('userName', user.displayName ?? 'User');
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('userType', _userType);
        
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
        
        // Save to Firestore with location
        if (_userType == 'customer') {
          await _userService.saveCustomer(
            userId: user.uid,
            name: user.displayName ?? 'User',
            email: user.email,
            authMethod: 'google',
            address: locationData?['address'],
            latitude: locationData?['latitude'],
            longitude: locationData?['longitude'],
          );
        } else if (_userType == 'provider') {
          // For Google sign-up providers, navigate to complete registration
          _navigateToProviderRegistration(
            user.uid, 
            user.email ?? '', 
            user.displayName ?? 'Provider',
            locationData,
          );
          return;
        }
        
        // Update user location in Firestore if provided
        if (locationData != null) {
          await _userService.updateUserLocation(
            userId: user.uid,
            address: locationData['address'],
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
          );
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ServiGo!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Navigate based on user type
        await Future.delayed(Duration(milliseconds: 1000));
        
        if (_userType == 'customer') {
          Navigator.pushReplacementNamed(context, '/main-home');
        } else if (_userType == 'provider') {
          // Providers from Google sign-up need to complete registration
          _navigateToProviderRegistration(
            user.uid, 
            user.email ?? '', 
            user.displayName ?? 'Provider',
            locationData,
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign up failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMethod = '';
        });
      }
    }
  }

  // ==================== NAVIGATION METHODS ====================

  void _navigateToProviderRegistration(
    String userId, 
    String email, 
    String name,
    Map<String, dynamic>? locationData,
  ) {
    Navigator.pushReplacementNamed(
      context,
      '/provider-registration',
      arguments: {
        'userId': userId,
        'email': email,
        'name': name,
        'isGoogleSignUp': true,
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }
}