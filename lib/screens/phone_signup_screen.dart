import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class PhoneSignUpScreen extends StatefulWidget {
  const PhoneSignUpScreen({Key? key}) : super(key: key);

  @override
  _PhoneSignUpScreenState createState() => _PhoneSignUpScreenState();
}

class _PhoneSignUpScreenState extends State<PhoneSignUpScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _codeSent = false;
  String? _userType;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userType = ModalRoute.of(context)?.settings.arguments as String?;
    if (_userType == null) _userType = 'customer';
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isProvider = _userType == 'provider';

    return Scaffold(
      appBar: AppBar(
        title: Text(isProvider
          ? languageProvider.get('provider_phone_signup') ?? 'Provider Phone Sign Up'
          : languageProvider.get('phone_signup') ?? 'Phone Sign Up'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isProvider
                ? languageProvider.get('provider_phone_verification') ?? 'Verify your phone to become a provider'
                : languageProvider.get('phone_verification') ?? 'Verify your phone number',
              style: AppTextStyles.heading4,
            ),
            SizedBox(height: 8),
            Text(
              isProvider
                ? languageProvider.get('provider_phone_description') ?? 'We\'ll send a verification code to your phone'
                : languageProvider.get('phone_description') ?? 'We\'ll send a verification code to your phone',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 40),

            if (!_codeSent) ...[
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: languageProvider.get('full_name') ?? 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              SizedBox(height: 16),

              // Phone field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: languageProvider.get('phone_number') ?? 'Phone Number',
                  hintText: '+94771234567',
                  prefixIcon: Icon(Icons.phone),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              SizedBox(height: 24),

              // Send Code Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionOrange,
                    minimumSize: Size(double.infinity, 56),
                  ),
                  child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(languageProvider.get('send_code') ?? 'Send Verification Code'),
                ),
              ),
            ] else ...[
              // Verification Code field
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: languageProvider.get('verification_code') ?? 'Verification Code',
                  prefixIcon: Icon(Icons.sms),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                languageProvider.get('enter_6_digit_code') ?? 'Enter the 6-digit code sent to ${_phoneController.text}',
                style: AppTextStyles.bodySmall,
              ),
              SizedBox(height: 24),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: Size(double.infinity, 56),
                  ),
                  child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(languageProvider.get('verify_code') ?? 'Verify Code'),
                ),
              ),

              SizedBox(height: 16),
              TextButton(
                onPressed: _resendCode,
                child: Text(languageProvider.get('resend_code') ?? 'Resend Code'),
              ),
            ],

            SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter phone number');
      return;
    }
    if (_nameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.sendPhoneVerificationCode(_phoneController.text.trim());
      setState(() => _codeSent = true);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send code: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await _authService.verifyPhoneCode(
        smsCode: _codeController.text.trim(),
        name: _nameController.text.trim(),
        userType: _userType!,
      );

      if (user != null) {
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isGuest', false);
        await prefs.setString('userId', user.uid);
        await prefs.setString('userName', _nameController.text.trim());
        await prefs.setString('userPhone', _phoneController.text.trim());
        await prefs.setString('userType', _userType!);

        // Navigate based on user type
        if (_userType == 'customer') {
          Navigator.pushReplacementNamed(context, '/main-home');
        } else {
          Navigator.pushReplacementNamed(context, '/provider-dashboard');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Verification failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      await _authService.sendPhoneVerificationCode(_phoneController.text.trim());
    } catch (e) {
      setState(() => _errorMessage = 'Failed to resend code');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}