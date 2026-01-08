import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({Key? key}) : super(key: key);

  @override
  _ProviderRegistrationScreenState createState() => _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState extends State<ProviderRegistrationScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  
  // Form state
  bool _isLoading = false;
  String _errorMessage = '';
  String? _selectedServiceType;
  List<String> _selectedServiceAreas = [];
  List<String> _selectedCertifications = [];
  
  // Service categories
  final List<String> _serviceCategories = [
    'electrician',
    'plumber',
    'cleaner',
    'carpenter',
    'painter',
    'ac_repair',
    'appliance_repair',
    'gardener',
    'mover',
    'handyman',
  ];
  
  // Certifications
  final List<String> _certificationOptions = [
    'Licensed',
    'Insured',
    'Background Checked',
    'First Aid Certified',
    '5+ Years Experience',
    '10+ Years Experience',
  ];
  
  // Service areas (districts in Sri Lanka)
  final List<String> _serviceAreaOptions = [
    'Colombo',
    'Gampaha',
    'Kalutara',
    'Kandy',
    'Matale',
    'Nuwara Eliya',
    'Galle',
    'Matara',
    'Hambantota',
    'Jaffna',
    'Kilinochchi',
    'Mannar',
    'Mullaitivu',
    'Vavuniya',
    'Trincomalee',
    'Batticaloa',
    'Ampara',
    'Badulla',
    'Monaragala',
    'Ratnapura',
    'Kegalle',
    'Polonnaruwa',
    'Anuradhapura',
    'Puttalam',
    'Kurunegala',
  ];

  Map<String, dynamic>? _args;
  bool _isGoogleSignUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (_args != null) {
      final name = _args?['name'] as String?;
      final email = _args?['email'] as String?;
      
      if (name != null) _nameController.text = name;
      if (email != null) _phoneController.text = email;
      
      _isGoogleSignUp = _args?['isGoogleSignUp'] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.get('complete_registration') ?? 'Complete Registration'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.handyman,
                      size: 80,
                      color: AppColors.modernTeal,
                    ),
                    SizedBox(height: 10),
                    Text(
                      languageProvider.get('become_service_provider') ?? 'Become a Service Provider',
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      languageProvider.get('complete_profile_to_start') ?? 'Complete your profile to start receiving bookings',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),

              // Error message
              if (_errorMessage.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: languageProvider.get('full_name') ?? 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                validator: (value) => value!.isEmpty ? 'Name is required' : null,
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
                validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
              ),
              SizedBox(height: 16),

              // Service Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedServiceType,
                decoration: InputDecoration(
                  labelText: languageProvider.get('service_type') ?? 'Service Type',
                  prefixIcon: Icon(Icons.category),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: _serviceCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category.replaceAll('_', ' ').toUpperCase(),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedServiceType = value),
                validator: (value) => value == null ? 'Please select service type' : null,
              ),
              SizedBox(height: 16),

              // Business Name (Optional)
              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: languageProvider.get('business_name_optional') ?? 'Business Name (Optional)',
                  prefixIcon: Icon(Icons.business),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: languageProvider.get('description') ?? 'Description',
                  hintText: languageProvider.get('describe_your_service') ?? 'Describe your services and experience...',
                  prefixIcon: Icon(Icons.description),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              SizedBox(height: 16),

              // Hourly Rate
              TextFormField(
                controller: _hourlyRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: languageProvider.get('hourly_rate') ?? 'Hourly Rate (Rs)',
                  prefixIcon: Icon(Icons.attach_money),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Hourly rate is required';
                  if (double.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Service Areas
              Text(
                languageProvider.get('service_areas') ?? 'Service Areas (Select districts)',
                style: AppTextStyles.label,
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _serviceAreaOptions.map((area) {
                  final isSelected = _selectedServiceAreas.contains(area);
                  return FilterChip(
                    label: Text(area),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedServiceAreas.add(area);
                        } else {
                          _selectedServiceAreas.remove(area);
                        }
                      });
                    },
                    selectedColor: AppColors.modernTeal.withOpacity(0.2),
                    checkmarkColor: AppColors.modernTeal,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.modernTeal : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),

              // Certifications
              Text(
                languageProvider.get('certifications') ?? 'Certifications & Qualifications',
                style: AppTextStyles.label,
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _certificationOptions.map((cert) {
                  final isSelected = _selectedCertifications.contains(cert);
                  return FilterChip(
                    label: Text(cert),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCertifications.add(cert);
                        } else {
                          _selectedCertifications.remove(cert);
                        }
                      });
                    },
                    selectedColor: AppColors.trustBlue.withOpacity(0.2),
                    checkmarkColor: AppColors.trustBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.trustBlue : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.modernTeal,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          languageProvider.get('complete_registration') ?? 'Complete Registration',
                          style: AppTextStyles.buttonLarge,
                        ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedServiceType == null) {
      setState(() => _errorMessage = 'Please select service type');
      return;
    }

    if (_selectedServiceAreas.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one service area');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _args?['userId'] ?? prefs.getString('userId');
      
      if (userId == null) {
        throw Exception('User ID not found');
      }

      await _userService.saveServiceProvider(
        userId: userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        serviceType: _selectedServiceType!,
        email: _args?['email'] as String?,
        businessName: _businessNameController.text.trim().isNotEmpty
            ? _businessNameController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        hourlyRate: double.tryParse(_hourlyRateController.text.trim()),
        serviceAreas: _selectedServiceAreas,
        certifications: _selectedCertifications,
        isVerified: false, // Will be verified by admin
      );

      // Save user type locally
      await prefs.setString('userType', 'provider');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration completed successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate to provider dashboard
      await Future.delayed(Duration(milliseconds: 500));
      Navigator.pushReplacementNamed(context, '/provider-dashboard');

    } catch (e) {
      setState(() => _errorMessage = 'Registration failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }
}