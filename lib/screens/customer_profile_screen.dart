import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({Key? key}) : super(key: key);

  @override
  _CustomerProfileScreenState createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  
  Map<String, dynamic>? _customerData;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isEditing = false;
  File? _profileImage;
  String? _profileImageUrl;
  
  // Editable Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  // Location
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null) {
        // Load customer data
        final data = await _userService.getUserData(userId);
        
        if (data != null) {
          setState(() {
            _customerData = data;
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _emailController.text = data['email'] ?? '';
            _profileImageUrl = data['profileImage'];
            
            // Load address
            final location = data['location'];
            if (location != null) {
              _addressController.text = location['address'] ?? '';
              final coordinates = location['coordinates'];
              if (coordinates != null) {
                _latitude = coordinates['latitude'];
                _longitude = coordinates['longitude'];
              }
            }
          });
          
          // Load customer stats
          final stats = await _userService.getCustomerStats(userId);
          setState(() {
            _stats = stats;
          });
        }
      }
    } catch (e) {
      print('Error loading customer data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        
        // Limit file size (5MB)
        if (fileSize > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image too large. Please select image under 5MB'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        
        setState(() {
          _profileImage = file;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image selected. Click SAVE to upload.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image'),
          backgroundColor: AppColors.error,
        ),
      );
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

      String? profileImageUrl = _profileImageUrl;

      // 1. Upload NEW profile image if selected
      if (_profileImage != null) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  SizedBox(width: 12),
                  Text('Uploading profile image...'),
                ],
              ),
              backgroundColor: AppColors.actionOrange,
              duration: Duration(seconds: 5),
            ),
          );
          
          // Upload image
          profileImageUrl = await _userService.uploadCustomerProfileImage(
            userId: userId,
            imageFile: _profileImage!,
          );
          
          if (profileImageUrl != null) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile image uploaded successfully!'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Image upload error: $e');
          // Continue without image if upload fails
        }
      }

      // 2. Update customer data in Firestore
      print('💾 Updating customer profile in Firestore...');
      final result = await _userService.updateCustomerProfile(
        userId: userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        profileImageUrl: profileImageUrl,
        address: _addressController.text.trim().isNotEmpty 
            ? _addressController.text.trim() 
            : null,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (result['success'] == true) {
        // 3. Update local state
        setState(() {
          _isEditing = false;
          if (_customerData != null) {
            _customerData!['name'] = _nameController.text.trim();
            _customerData!['phone'] = _phoneController.text.trim();
            _customerData!['email'] = _emailController.text.trim();
            
            if (profileImageUrl != null) {
              _customerData!['profileImage'] = profileImageUrl;
              _profileImageUrl = profileImageUrl;
              _profileImage = null;
            }
            
            // Update location
            if (_addressController.text.trim().isNotEmpty) {
              _customerData!['location'] = {
                'address': _addressController.text.trim(),
                'locationType': 'manual',
              };
            }
            
            _customerData!['updatedAt'] = DateTime.now().toString();
          }
        });
        
        // 4. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 5. Refresh data from database
        await Future.delayed(Duration(seconds: 1));
        await _loadCustomerData();
        
      } else {
        throw Exception(result['error'] ?? 'Profile update failed');
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

  Future<void> _updateLocation() async {
    // TODO: Implement location picker/map
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location update feature coming soon!'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      Navigator.pushReplacementNamed(context, '/login');
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
                  // Profile Header
                  _buildProfileHeader(languageProvider),
                  SizedBox(height: 30),
                  
                  // Profile Info
                  _buildProfileInfo(languageProvider),
                  SizedBox(height: 20),
                  
                  // Statistics
                  _buildStatistics(languageProvider),
                  SizedBox(height: 30),
                  
                  // Account Actions
                  _buildAccountActions(languageProvider),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(LanguageProvider languageProvider) {
    final name = _customerData?['name'] ?? 'Customer';
    final email = _customerData?['email'] ?? '';
    final isGuest = _customerData?['userType'] == 'guest';
    
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.actionOrange,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : (_profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null) as ImageProvider?,
                child: _profileImage == null && _profileImageUrl == null
                    ? Icon(
                        Icons.person,
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
            if (isGuest)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    'GUEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
          email,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        if (isGuest)
          Text(
            'Guest accounts have limited features',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.warning,
              fontStyle: FontStyle.italic,
            ),
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
            
            // Address
            _buildEditableField(
              label: languageProvider.get('address') ?? 'Address',
              controller: _addressController,
              icon: Icons.location_on,
              isEditing: _isEditing,
              maxLines: 2,
            ),
            SizedBox(height: 12),
            
            // Update Location Button
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _updateLocation,
                  icon: Icon(Icons.map, size: 20),
                  label: Text('Update Location on Map'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.vividAzure),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
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
                        controller.text.isNotEmpty ? controller.text : 'Not provided',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildStatistics(LanguageProvider languageProvider) {
    final totalBookings = _stats['totalBookings'] ?? 0;
    final completedBookings = _stats['completedBookings'] ?? 0;
    final cancelledBookings = _stats['cancelledBookings'] ?? 0;
    final totalSpent = (_stats['totalSpent'] ?? 0.0).toDouble();
    final favoriteService = _stats['favoriteService'] ?? 'None';
    
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
                  languageProvider.get('my_statistics') ?? 'My Statistics',
                  style: AppTextStyles.heading4,
                ),
                Icon(Icons.analytics, color: AppColors.textSecondary),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Based on your booking history',
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
                  label: languageProvider.get('total_bookings') ?? 'Total Bookings',
                  value: totalBookings.toString(),
                  color: AppColors.trustBlue,
                  icon: Icons.calendar_today,
                ),
                _buildStatCard(
                  label: languageProvider.get('completed') ?? 'Completed',
                  value: completedBookings.toString(),
                  color: AppColors.success,
                  icon: Icons.check_circle,
                ),
                _buildStatCard(
                  label: languageProvider.get('cancelled') ?? 'Cancelled',
                  value: cancelledBookings.toString(),
                  color: AppColors.error,
                  icon: Icons.cancel,
                ),
                _buildStatCard(
                  label: languageProvider.get('total_spent') ?? 'Total Spent',
                  value: 'Rs ${totalSpent.toStringAsFixed(2)}',
                  color: AppColors.actionOrange,
                  icon: Icons.attach_money,
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Favorite Service
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.modernTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.modernTeal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: AppColors.modernTeal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.get('favorite_service') ?? 'Favorite Service',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          favoriteService.toString().toUpperCase(),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.modernTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  Widget _buildAccountActions(LanguageProvider languageProvider) {
    final isGuest = _customerData?['userType'] == 'guest';
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.get('account_actions') ?? 'Account Actions',
              style: AppTextStyles.heading4,
            ),
            SizedBox(height: 16),
            
            // Upgrade Guest to Full Account
            if (isGuest)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement guest upgrade
                    Navigator.pushNamed(context, '/signup');
                  },
                  icon: Icon(Icons.upgrade, size: 20),
                  label: Text('Upgrade to Full Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            
            if (isGuest) SizedBox(height: 12),
            
            // Change Password
            if (!isGuest)
              ListTile(
                leading: Icon(Icons.lock, color: AppColors.textSecondary),
                title: Text(languageProvider.get('change_password') ?? 'Change Password'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement change password
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Change password feature coming soon!'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
              ),
            
            // Privacy Settings
            ListTile(
              leading: Icon(Icons.privacy_tip, color: AppColors.textSecondary),
              title: Text(languageProvider.get('privacy_settings') ?? 'Privacy Settings'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement privacy settings
              },
            ),
            
            Divider(),
            
            // Logout
            ListTile(
              leading: Icon(Icons.logout, color: AppColors.error),
              title: Text(
                languageProvider.get('logout') ?? 'Logout',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: _logout,
            ),
            
            // Delete Account
            ListTile(
              leading: Icon(Icons.delete_forever, color: AppColors.error.withOpacity(0.7)),
              title: Text(
                languageProvider.get('delete_account') ?? 'Delete Account',
                style: TextStyle(color: AppColors.error.withOpacity(0.7)),
              ),
              onTap: () {
                // TODO: Implement delete account
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Account deletion feature coming soon!'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}