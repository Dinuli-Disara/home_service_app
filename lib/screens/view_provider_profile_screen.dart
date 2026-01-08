import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_service_app/constants/app_colors.dart';
import 'package:home_service_app/constants/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewProviderProfileScreen extends StatefulWidget {
  final String providerId;

  const ViewProviderProfileScreen({Key? key, required this.providerId}) : super(key: key);

  @override
  _ViewProviderProfileScreenState createState() => _ViewProviderProfileScreenState();
}

class _ViewProviderProfileScreenState extends State<ViewProviderProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _providerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      DocumentSnapshot snapshot = await _firestore
          .collection('providers')
          .doc(widget.providerId)
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        setState(() {
          _providerData = snapshot.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError('Provider not found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading provider: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Safe data extraction methods
  String _getString(String key, {String defaultValue = ''}) {
    if (_providerData == null) return defaultValue;
    final value = _providerData![key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  double _getDouble(String key, {double defaultValue = 0.0}) {
    if (_providerData == null) return defaultValue;
    final value = _providerData![key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _getInt(String key, {int defaultValue = 0}) {
    if (_providerData == null) return defaultValue;
    final value = _providerData![key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  bool _getBool(String key, {bool defaultValue = false}) {
    if (_providerData == null) return defaultValue;
    final value = _providerData![key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  List<dynamic> _getList(String key) {
    if (_providerData == null) return [];
    final value = _providerData![key];
    if (value is List) return value;
    return [];
  }

  Map<String, dynamic> _getMap(String key) {
    if (_providerData == null) return {};
    final value = _providerData![key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  // Helper method for getting boolean from a specific map
  bool _getBoolFromMap(Map<String, dynamic>? map, String key, {bool defaultValue = false}) {
    if (map == null) return defaultValue;
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value == 1;
    return defaultValue;
  }

  // Helper method for getting string from a map
  String _getStringFromMap(Map<String, dynamic>? map, String key, {String defaultValue = ''}) {
    if (map == null) return defaultValue;
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  // Helper method for getting list from a map
  List<dynamic> _getListFromMap(Map<String, dynamic>? map, String key) {
    if (map == null) return [];
    final value = map[key];
    if (value is List) return value;
    return [];
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showError('Phone number not available');
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showError('Could not launch phone app');
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) {
      _showError('Email not available');
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showError('Could not launch email app');
    }
  }

  void _bookProvider() {
    Navigator.pushNamed(
      context,
      '/booking',
      arguments: {
        'providerId': widget.providerId,
        'providerName': _getString('name'),
        'serviceType': _getString('serviceType'),
        'hourlyRate': _getDouble('hourlyRate'),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.vividAzure))
          : _providerData == null
              ? Center(child: Text('Provider not found'))
              : _buildProfileBody(),
    );
  }

  Widget _buildProfileBody() {
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  indicatorColor: AppColors.vividAzure,
                  labelColor: AppColors.vividAzure,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Services'),
                    Tab(text: 'Reviews'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildServicesTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _getString('name', defaultValue: 'Service Provider');
    final businessName = _getString('businessName');
    final serviceType = _getString('serviceType', defaultValue: 'Service');
    final rating = _getDouble('rating');
    final totalJobs = _getInt('totalJobs');
    final isVerified = _getBool('isVerified');
    final profileImageUrl = _getString('profileImage');
    final availability = _getMap('availability');
    final isAvailable = _getBoolFromMap(availability, 'isAvailable', defaultValue: true);

    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.vividAzure.withOpacity(0.8),
                AppColors.trustBlue.withOpacity(0.6),
              ],
            ),
          ),
        ),

        // Content
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 60),

              // Profile Image
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl) as ImageProvider
                        : null,
                    child: profileImageUrl.isEmpty
                        ? Icon(
                            Icons.handyman,
                            size: 50,
                            color: AppColors.vividAzure,
                          )
                        : null,
                  ),
                  if (isVerified)
                    Positioned(
                      bottom: 0,
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

              SizedBox(height: 20),

              // Name and Business
              Text(
                businessName.isNotEmpty ? businessName : name,
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 4),

              Text(
                serviceType.toUpperCase(),
                style: AppTextStyles.body.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              SizedBox(height: 12),

              // Rating and Jobs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: AppTextStyles.label.copyWith(color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '$totalJobs jobs completed',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Availability Status
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.success.withOpacity(0.9)
                      : AppColors.error.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      isAvailable ? 'Available Now' : 'Currently Unavailable',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    color: AppColors.success,
                    onPressed: () => _makePhoneCall(_getString('phone')),
                  ),
                  SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.message,
                    label: 'Message',
                    color: AppColors.vividAzure,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Messaging feature coming soon!')),
                      );
                    },
                  ),
                  SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.book_online,
                    label: 'Book',
                    color: AppColors.actionOrange,
                    onPressed: _bookProvider,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final description = _getString('description');
    final experienceYears = _getInt('experienceYears');
    final hourlyRate = _getDouble('hourlyRate');
    final address = _getString('address');
    final phone = _getString('phone');
    final email = _getString('email');
    final certifications = _getList('certifications');
    final availability = _getMap('availability');
    final stats = _getMap('stats');

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (description.isNotEmpty) ...[
            _buildSectionTitle('About'),
            SizedBox(height: 8),
            Text(
              description,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
          ],

          // Basic Info
          _buildSectionTitle('Basic Information'),
          SizedBox(height: 12),
          _buildInfoRow('Experience', '$experienceYears years'),
          SizedBox(height: 8),
          _buildInfoRow('Hourly Rate', '₹${hourlyRate.toInt()}/hour'),
          SizedBox(height: 8),
          _buildInfoRow('Address', address.isNotEmpty ? address : 'Not specified'),
          SizedBox(height: 8),
          _buildInfoRow('Phone', phone.isNotEmpty ? phone : 'Not provided'),
          SizedBox(height: 8),
          _buildInfoRow('Email', email.isNotEmpty ? email : 'Not provided'),

          // Availability
          if (availability.isNotEmpty) ...[
            SizedBox(height: 24),
            _buildSectionTitle('Availability'),
            SizedBox(height: 12),
            _buildAvailabilityInfo(availability),
          ],

          // Certifications
          if (certifications.isNotEmpty) ...[
            SizedBox(height: 24),
            _buildSectionTitle('Certifications & Licenses'),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: certifications.map((cert) {
                return Chip(
                  label: Text(cert.toString()),
                  backgroundColor: AppColors.trustBlue.withOpacity(0.1),
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.trustBlue,
                  ),
                );
              }).toList(),
            ),
          ],

          // Statistics
          SizedBox(height: 24),
          _buildSectionTitle('Performance Statistics'),
          SizedBox(height: 12),
          _buildStatsGrid(stats),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    final services = _getList('services');
    final hourlyRate = _getDouble('hourlyRate');

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rate Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hourly Rate',
                        style: AppTextStyles.heading5,
                      ),
                      Text(
                        '₹${hourlyRate.toInt()}/hour',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.vividAzure,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This rate includes labor and basic materials. Additional charges may apply for special materials or complex work.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Services List
          if (services.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.list, size: 60, color: AppColors.textDisabled),
                  SizedBox(height: 16),
                  Text(
                    'No services listed yet',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Offered Services',
              style: AppTextStyles.heading4,
            ),
            SizedBox(height: 12),
            ...services.asMap().entries.map((entry) {
              final index = entry.key;
              final service = entry.value;
              final serviceName = service is Map ? service['name'] ?? service.toString() : service.toString();
              final serviceDescription = service is Map ? service['description'] ?? '' : '';

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.vividAzure.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getServiceIcon(serviceName),
                      color: AppColors.vividAzure,
                    ),
                  ),
                  title: Text(
                    serviceName,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: serviceDescription.isNotEmpty
                      ? Text(
                          serviceDescription,
                          style: AppTextStyles.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    final reviews = _getList('reviews');
    final rating = _getDouble('rating');

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Rating
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Overall Rating',
                    style: AppTextStyles.heading5,
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 40, color: Colors.amber),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: AppTextStyles.heading2.copyWith(
                              fontSize: 36,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${reviews.length} reviews',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Reviews List
          if (reviews.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.reviews, size: 60, color: AppColors.textDisabled),
                  SizedBox(height: 16),
                  Text(
                    'No reviews yet',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Be the first to review this provider!',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Reviews',
                  style: AppTextStyles.heading4,
                ),
                SizedBox(height: 12),
                ...reviews.asMap().entries.map((entry) {
                  final index = entry.key;
                  final review = entry.value;
                  
                  Map<String, dynamic> reviewData;
                  if (review is Map<String, dynamic>) {
                    reviewData = review;
                  } else if (review is Map) {
                    reviewData = Map<String, dynamic>.from(review);
                  } else {
                    reviewData = {
                      'rating': 5.0,
                      'comment': review.toString(),
                      'customerName': 'Anonymous',
                      'date': 'Recently'
                    };
                  }

                  final reviewRating = reviewData['rating'] is double 
                      ? reviewData['rating'] as double
                      : (reviewData['rating'] is int 
                          ? (reviewData['rating'] as int).toDouble()
                          : double.tryParse(reviewData['rating'].toString()) ?? 5.0);

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reviewData['customerName']?.toString() ?? 'Anonymous',
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                reviewData['date']?.toString() ?? '',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                Icons.star,
                                size: 16,
                                color: starIndex < reviewRating.toInt()
                                    ? Colors.amber
                                    : Colors.grey[300],
                              );
                            }),
                          ),
                          SizedBox(height: 12),
                          Text(
                            reviewData['comment']?.toString() ?? '',
                            style: AppTextStyles.body.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.heading4.copyWith(
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityInfo(Map<String, dynamic> availability) {
    // Safely get workingHours as a map
    final workingHours = availability['workingHours'];
    Map<String, dynamic> workingHoursMap = {};
    
    if (workingHours is Map<String, dynamic>) {
      workingHoursMap = workingHours;
    } else if (workingHours is Map) {
      try {
        workingHoursMap = Map<String, dynamic>.from(workingHours);
      } catch (e) {
        workingHoursMap = {};
      }
    }

    // Safely get workingDays as a list
    final workingDays = availability['workingDays'];
    List<dynamic> workingDaysList = [];
    
    if (workingDays is List) {
      workingDaysList = workingDays;
    }

    final startTime = _getStringFromMap(workingHoursMap, 'start', defaultValue: '08:00');
    final endTime = _getStringFromMap(workingHoursMap, 'end', defaultValue: '18:00');

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final workingDayNames = workingDaysList.map((day) {
      final dayNum = day is int ? day : int.tryParse(day.toString()) ?? 1;
      final index = dayNum - 1;
      return index >= 0 && index < 7 ? dayNames[index] : '';
    }).where((name) => name.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Working Hours', '$startTime - $endTime'),
        SizedBox(height: 8),
        _buildInfoRow(
          'Working Days',
          workingDayNames.isNotEmpty ? workingDayNames.join(', ') : 'Not specified',
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final completedJobs = _getIntFromMap(stats, 'completedJobs');
    final responseRate = _getDoubleFromMap(stats, 'responseRate');
    final cancellationRate = _getDoubleFromMap(stats, 'cancellationRate');
    final avgRating = _getDoubleFromMap(stats, 'avgRating', defaultValue: _getDouble('rating'));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          icon: Icons.check_circle,
          value: completedJobs.toString(),
          label: 'Jobs Completed',
          color: AppColors.success,
        ),
        _buildStatCard(
          icon: Icons.timer,
          value: '${responseRate.toStringAsFixed(0)}%',
          label: 'Response Rate',
          color: AppColors.vividAzure,
        ),
        _buildStatCard(
          icon: Icons.cancel,
          value: '${cancellationRate.toStringAsFixed(0)}%',
          label: 'Cancellation Rate',
          color: AppColors.error,
        ),
        _buildStatCard(
          icon: Icons.star,
          value: avgRating.toStringAsFixed(1),
          label: 'Avg. Rating',
          color: Colors.amber,
        ),
      ],
    );
  }

  // Helper methods for getting data from maps
  int _getIntFromMap(Map<String, dynamic>? map, String key, {int defaultValue = 0}) {
    if (map == null) return defaultValue;
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  double _getDoubleFromMap(Map<String, dynamic>? map, String key, {double defaultValue = 0.0}) {
    if (map == null) return defaultValue;
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading4.copyWith(
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final lowerName = serviceName.toLowerCase();
    if (lowerName.contains('plumb')) return Icons.plumbing;
    if (lowerName.contains('electr')) return Icons.electrical_services;
    if (lowerName.contains('clean')) return Icons.cleaning_services;
    if (lowerName.contains('repair')) return Icons.build;
    if (lowerName.contains('install')) return Icons.construction;
    if (lowerName.contains('paint')) return Icons.format_paint;
    if (lowerName.contains('garden')) return Icons.nature;
    if (lowerName.contains('ac')) return Icons.ac_unit;
    if (lowerName.contains('carpent')) return Icons.carpenter;
    return Icons.handyman;
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}