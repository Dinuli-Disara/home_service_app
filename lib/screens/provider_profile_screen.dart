import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/user_service.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({Key? key}) : super(key: key);

  @override
  _ProviderProfileScreenState createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();
  
  Map<String, dynamic>? _providerData;
  bool _isLoading = true;
  bool _isEditing = false;
  File? _profileImage;
  String? _profileImageUrl;
  
  // Editable Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  
  // Working Hours
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<bool> _workingDays = List.generate(7, (index) => index < 5); // Mon-Fri by default

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null) {
        final data = await _userService.getProviderData(userId);
        
        if (data != null) {
          setState(() {
            _providerData = data;
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _emailController.text = data['email'] ?? '';
            _descriptionController.text = data['description'] ?? '';
            
            // Handle hourly rate
            final rate = data['hourlyRate'];
            if (rate != null) {
              _hourlyRateController.text = rate is double 
                  ? rate.toStringAsFixed(0) 
                  : rate.toString();
            } else {
              _hourlyRateController.text = '0';
            }
            
            _businessNameController.text = data['businessName'] ?? '';
            _profileImageUrl = data['profileImage'];
            
            // Load working hours
            final availability = data['availability'] ?? {};
            final workingHours = availability['workingHours'] ?? {};
            
            if (workingHours['start'] != null) {
              final startParts = workingHours['start'].split(':');
              _startTime = TimeOfDay(
                hour: int.parse(startParts[0]),
                minute: int.parse(startParts[1]),
              );
            } else {
              _startTime = TimeOfDay(hour: 8, minute: 0);
            }
            
            if (workingHours['end'] != null) {
              final endParts = workingHours['end'].split(':');
              _endTime = TimeOfDay(
                hour: int.parse(endParts[0]),
                minute: int.parse(endParts[1]),
              );
            } else {
              _endTime = TimeOfDay(hour: 18, minute: 0);
            }
            
            // Load working days
            final workingDays = availability['workingDays'] as List<dynamic>?;
            if (workingDays != null) {
              _workingDays = List.generate(7, (index) => workingDays.contains(index + 1));
            } else {
              _workingDays = List.generate(7, (index) => index < 5); // Mon-Fri default
            }
          });
        } else {
          print('No provider data found for user: $userId');
        }
      }
    } catch (e) {
      print('Error loading provider data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile data'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null) {
        throw Exception('User ID not found');
      }

      setState(() {
        _isLoading = true;
      });

      String? profileImageUrl;

      // 1. Upload profile image if selected
      if (_profileImage != null) {
        try {
          profileImageUrl = await _userService.uploadProfileImage(
            userId: userId,
            imageFile: _profileImage!,
          );
          
          if (profileImageUrl == null) {
            throw Exception('Failed to upload profile image');
          }
        } catch (e) {
          print('Image upload error: $e');
          // Continue without image if upload fails
        }
      }

      // 2. Prepare working hours string
      final startTimeStr = _startTime != null 
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : '08:00';
      final endTimeStr = _endTime != null 
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : '18:00';
      
      // 3. Prepare working days list
      final List<int> workingDays = [];
      for (int i = 0; i < _workingDays.length; i++) {
        if (_workingDays[i]) workingDays.add(i + 1); // 1=Monday, 7=Sunday
      }

      // 4. Parse hourly rate
      double? hourlyRate;
      try {
        hourlyRate = double.tryParse(_hourlyRateController.text.trim());
      } catch (e) {
        print('Error parsing hourly rate: $e');
      }

      // 5. Update ALL provider data in Firestore
      final result = await _userService.updateProviderProfile(
        userId: userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        description: _descriptionController.text.trim(),
        businessName: _businessNameController.text.trim(),
        hourlyRate: hourlyRate,
        workingHours: {
          'start': startTimeStr,
          'end': endTimeStr,
        },
        workingDays: workingDays,
        profileImageUrl: profileImageUrl,
      );

      if (result['success'] == true) {
        // 6. Update local state
        setState(() {
          _isEditing = false;
          if (_providerData != null) {
            _providerData!['name'] = _nameController.text.trim();
            _providerData!['phone'] = _phoneController.text.trim();
            _providerData!['email'] = _emailController.text.trim();
            _providerData!['description'] = _descriptionController.text.trim();
            _providerData!['hourlyRate'] = hourlyRate;
            _providerData!['businessName'] = _businessNameController.text.trim();
            
            if (profileImageUrl != null) {
              _providerData!['profileImage'] = profileImageUrl;
              _profileImageUrl = profileImageUrl;
              _profileImage = null;
            }
            
            // Update availability in local data
            _providerData!['availability'] = {
              'workingHours': {'start': startTimeStr, 'end': endTimeStr},
              'workingDays': workingDays,
              'isAvailable': _providerData?['availability']?['isAvailable'] ?? true,
            };
            
            // Update updatedAt timestamp
            _providerData!['updatedAt'] = DateTime.now().toString();
          }
        });
        
        // 7. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 8. Refresh data from database
        await _loadProviderData();
        
      } else {
        throw Exception(result['error'] ?? 'Update failed');
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      print('Error updating profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String _getDayName(int index) {
    switch (index) {
      case 0: return 'Mon';
      case 1: return 'Tue';
      case 2: return 'Wed';
      case 3: return 'Thu';
      case 4: return 'Fri';
      case 5: return 'Sat';
      case 6: return 'Sun';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.get('profile') ?? 'Profile'),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing && !_isLoading)
            TextButton(
              onPressed: _updateProfile,
              child: Text(
                languageProvider.get('save') ?? 'SAVE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  _isEditing ? 'Saving changes...' : 'Loading profile...',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header with Image
                  _buildProfileHeader(languageProvider),
                  SizedBox(height: 30),
                  
                  // Profile Info (Editable)
                  _buildProfileInfo(languageProvider),
                  SizedBox(height: 20),
                  
                  // Working Hours & Days (Editable)
                  if (_isEditing) _buildWorkingSchedule(languageProvider),
                  
                  // Service Details (Partially Editable)
                  _buildServiceDetails(languageProvider),
                  SizedBox(height: 20),
                  
                  // Statistics (Read-only)
                  _buildStats(languageProvider),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(LanguageProvider languageProvider) {
    final name = _providerData?['name'] ?? 'Provider';
    final serviceType = _providerData?['serviceType'] ?? 'Service Provider';
    final rating = (_providerData?['rating'] ?? 0.0).toDouble();
    final totalJobs = _providerData?['totalJobs'] ?? 0;
    final isVerified = _providerData?['isVerified'] ?? false;
    
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.modernTeal,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : (_profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null) as ImageProvider?,
                child: _profileImage == null && _profileImageUrl == null
                    ? Icon(
                        Icons.handyman,
                        size: 50,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.actionOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            if (isVerified)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.verified,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          name,
          style: AppTextStyles.heading3,
        ),
        SizedBox(height: 4),
        Text(
          serviceType.toString().toUpperCase(),
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 20),
            SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: AppTextStyles.label,
            ),
            SizedBox(width: 8),
            Text('•'),
            SizedBox(width: 8),
            Text(
              '$totalJobs jobs',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (_isEditing)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Tap image to change',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textDisabled,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileInfo(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.get('personal_info') ?? 'Personal Information',
                  style: AppTextStyles.heading4,
                ),
                if (_isEditing)
                  Text(
                    'Editable',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            
            // Name
            _buildEditableField(
              label: languageProvider.get('name') ?? 'Name',
              controller: _nameController,
              icon: Icons.person,
              isEditing: _isEditing,
            ),
            SizedBox(height: 12),
            
            // Phone
            _buildEditableField(
              label: languageProvider.get('phone') ?? 'Phone',
              controller: _phoneController,
              icon: Icons.phone,
              isEditing: _isEditing,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12),
            
            // Email
            _buildEditableField(
              label: languageProvider.get('email') ?? 'Email',
              controller: _emailController,
              icon: Icons.email,
              isEditing: _isEditing,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 12),
            
            // Business Name (Optional)
            _buildEditableField(
              label: languageProvider.get('business_name') ?? 'Business Name (Optional)',
              controller: _businessNameController,
              icon: Icons.business,
              isEditing: _isEditing,
            ),
            SizedBox(height: 12),
            
            // Description
            _buildEditableField(
              label: languageProvider.get('description') ?? 'Description',
              controller: _descriptionController,
              icon: Icons.description,
              isEditing: _isEditing,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingSchedule(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.get('working_schedule') ?? 'Working Schedule',
                  style: AppTextStyles.heading4,
                ),
                Text(
                  'Editable',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Working Hours
            Text(
              languageProvider.get('working_hours') ?? 'Working Hours',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectStartTime,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start Time',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _startTime != null 
                                ? _startTime!.format(context)
                                : '08:00',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectEndTime,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'End Time',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _endTime != null 
                                ? _endTime!.format(context)
                                : '18:00',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Working Days
            Text(
              languageProvider.get('working_days') ?? 'Working Days',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                return FilterChip(
                  label: Text(_getDayName(index)),
                  selected: _workingDays[index],
                  onSelected: (selected) {
                    setState(() {
                      _workingDays[index] = selected;
                    });
                  },
                  selectedColor: AppColors.modernTeal.withOpacity(0.2),
                  checkmarkColor: AppColors.modernTeal,
                  labelStyle: TextStyle(
                    color: _workingDays[index] ? AppColors.modernTeal : AppColors.textPrimary,
                    fontWeight: _workingDays[index] ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDetails(LanguageProvider languageProvider) {
    final serviceType = _providerData?['serviceType'] ?? '';
    final hourlyRate = (_providerData?['hourlyRate'] ?? 0).toDouble();
    final serviceAreas = _providerData?['serviceAreas'] as List<dynamic>? ?? [];
    final certifications = _providerData?['certifications'] as List<dynamic>? ?? [];
    final lastActive = _providerData?['lastActive'];
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.get('service_details') ?? 'Service Details',
                  style: AppTextStyles.heading4,
                ),
                if (_isEditing)
                  Text(
                    'Partially Editable',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            
            // Service Type (Read-only)
            _buildReadOnlyField(
              icon: Icons.category,
              label: languageProvider.get('service_type') ?? 'Service Type',
              value: serviceType.toString().toUpperCase(),
              color: AppColors.trustBlue,
            ),
            SizedBox(height: 12),
            
            // Hourly Rate (Editable)
            _buildEditableField(
              label: languageProvider.get('hourly_rate') ?? 'Hourly Rate (Rs)',
              controller: _hourlyRateController,
              icon: Icons.attach_money,
              isEditing: _isEditing,
              keyboardType: TextInputType.number,
              prefixText: 'Rs ',
            ),
            SizedBox(height: 12),
            
            // Service Areas (Read-only - would need separate screen to edit)
            _buildReadOnlyListField(
              icon: Icons.location_on,
              label: languageProvider.get('service_areas') ?? 'Service Areas',
              values: serviceAreas.map((e) => e.toString()).toList(),
              color: AppColors.modernTeal,
            ),
            SizedBox(height: 12),
            
            // Certifications (Read-only - would need separate screen to edit)
            if (certifications.isNotEmpty) ...[
              _buildReadOnlyListField(
                icon: Icons.verified,
                label: languageProvider.get('certifications') ?? 'Certifications',
                values: certifications.map((e) => e.toString()).toList(),
                color: AppColors.trustBlue,
              ),
              SizedBox(height: 12),
            ],
            
            // Last Active (Read-only)
            if (lastActive != null) ...[
              _buildReadOnlyField(
                icon: Icons.access_time,
                label: languageProvider.get('last_active') ?? 'Last Active',
                value: _formatTimestamp(lastActive),
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        isEditing
            ? TextFormField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, size: 20),
                  prefixText: prefixText,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.vividAzure, width: 2),
                  ),
                ),
              )
            : Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.text.isNotEmpty 
                            ? (prefixText != null ? '$prefixText${controller.text}' : controller.text)
                            : 'Not provided',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: AppColors.textDisabled),
        ],
      ),
    );
  }

  Widget _buildReadOnlyListField({
    required IconData icon,
    required String label,
    required List<String> values,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: values.map((value) {
                    return Chip(
                      label: Text(value),
                      backgroundColor: color.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: color,
                        fontSize: 11,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: AppColors.textDisabled),
        ],
      ),
    );
  }

  Widget _buildStats(LanguageProvider languageProvider) {
    final stats = _providerData?['stats'] ?? {};
    final completedJobs = stats['completedJobs'] ?? 0;
    final cancelledJobs = stats['cancelledJobs'] ?? 0;
    final earnings = (stats['earnings'] ?? 0.0).toDouble();
    final responseRate = (stats['responseRate'] ?? 0.0).toDouble();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.get('statistics') ?? 'Statistics',
                  style: AppTextStyles.heading4,
                ),
                Icon(Icons.lock_outline, size: 18, color: AppColors.textDisabled),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Auto-calculated based on your performance',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textDisabled,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  label: languageProvider.get('completed') ?? 'Completed',
                  value: completedJobs.toString(),
                  color: AppColors.success,
                  icon: Icons.check_circle,
                ),
                _buildStatCard(
                  label: languageProvider.get('cancelled') ?? 'Cancelled',
                  value: cancelledJobs.toString(),
                  color: AppColors.error,
                  icon: Icons.cancel,
                ),
                _buildStatCard(
                  label: languageProvider.get('earnings') ?? 'Earnings',
                  value: 'Rs ${earnings.toStringAsFixed(2)}',
                  color: AppColors.actionOrange,
                  icon: Icons.attach_money,
                ),
                _buildStatCard(
                  label: languageProvider.get('response_rate') ?? 'Response Rate',
                  value: '${responseRate.toStringAsFixed(1)}%',
                  color: AppColors.trustBlue,
                  icon: Icons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.heading4.copyWith(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      if (timestamp is DateTime) {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
      } else if (timestamp is String) {
        return timestamp;
      } else {
        return 'Recently';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }
}