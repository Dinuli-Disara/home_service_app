import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/booking_service.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({Key? key}) : super(key: key);

  @override
  _ProviderDashboardScreenState createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _providerData;
  bool _isLoading = true;
  int _selectedIndex = 0;
  
  // Statistics
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _completedBookings = 0;
  double _totalEarnings = 0.0;
  double _rating = 0.0;
  String _providerId = '';
  List<Map<String, dynamic>> _recentBookings = [];
  Map<String, String> _customerNames = {};

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _providerId = prefs.getString('userId') ?? '';
      
      if (_providerId.isEmpty) {
        print('⚠️ No provider ID found');
        setState(() => _isLoading = false);
        return;
      }
      
      print('🔍 Loading data for provider: $_providerId');
      
      // Load provider data
      final data = await _userService.getProviderData(_providerId);
      
      if (data != null) {
        print('✅ Loaded provider data: ${data['name']}');
        setState(() {
          _providerData = data;
          _rating = (data['rating'] ?? 0.0).toDouble();
          _totalEarnings = (data['stats']?['earnings'] ?? 0.0).toDouble();
        });
      } else {
        print('❌ No provider data found');
      }
      
      // Load booking statistics and recent bookings
      await _loadBookingData();
      
    } catch (e) {
      print('❌ Error loading provider data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookingData() async {
    try {
      if (_providerId.isEmpty) return;
      
      print('📊 Loading bookings for provider: $_providerId');
      
      // Get all bookings for this provider from Firestore
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: _providerId)
          .limit(10) // Limit to 10 most recent
          .get();
      
      print('📈 Found ${bookingsSnapshot.docs.length} bookings');
      
      List<Map<String, dynamic>> bookings = [];
      int total = 0;
      int pending = 0;
      int completed = 0;

      // First, collect all unique customer IDs
      final customerIds = <String>{};
      
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final customerId = data['customerId'] as String?;
        if (customerId != null) {
          customerIds.add(customerId);
        }
      }
      
      // Fetch customer names for all customer IDs
      await _fetchCustomerNames(customerIds.toList());
      
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final customerId = data['customerId'] as String?;
        final customerName = customerId != null 
            ? _customerNames[customerId] ?? 'Customer'
            : 'Customer';
        final booking = {
          'id': doc.id,
          ...data,
          'customerName': customerName,
        };
        bookings.add(booking);
        
        total++;
        final status = data['status'] as String?;
        
        if (status == 'pending') {
          pending++;
        } else if (status == 'completed') {
          completed++;
        }
        
        // Debug print each booking
        print('📋 Booking: ${data['customerName'] ?? 'N/A'} - ${data['serviceType'] ?? 'N/A'} - Status: $status');
      }
      
      // Sort manually on the client side by createdAt descending
      bookings.sort((a, b) {
        final aDate = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(0);
        final bDate = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(0);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _recentBookings = bookings.take(3).toList(); // Show only 3 most recent
        _totalBookings = total;
        _pendingBookings = pending;
        _completedBookings = completed;
      });
      
      print('✅ Statistics: Total=$total, Pending=$pending, Completed=$completed');
      
    } catch (e) {
      print('❌ Error loading booking data: $e');
      print('Error details: ${e.toString()}');
    }
  }

  Future<void> _fetchCustomerNames(List<String> customerIds) async {
    try {
      if (customerIds.isEmpty) return;
      
      print('👥 Fetching names for ${customerIds.length} customers');
      
      for (final customerId in customerIds) {
        // Check if we already have this customer's name
        if (_customerNames.containsKey(customerId)) continue;
        
        final userDoc = await _firestore.collection('users').doc(customerId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final customerName = userData['name'] as String?;
          if (customerName != null) {
            _customerNames[customerId] = customerName;
            print('   ✅ Found name for $customerId: $customerName');
          } else {
            _customerNames[customerId] = 'Customer';
            print('   ⚠️ No name found for $customerId, using default');
          }
        } else {
          _customerNames[customerId] = 'Customer';
          print('   ❌ User not found: $customerId');
        }
      }
    } catch (e) {
      print('❌ Error fetching customer names: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.get('provider_dashboard') ?? 'Provider Dashboard',
          style: AppTextStyles.heading5.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.trustBlue,
        elevation: 2,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: Icon(Icons.person_outlined, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/provider-profile');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.vividAzure,
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.modernTeal, AppColors.vividAzure],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.modernTeal.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome,',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontFamily: 'OpenSans',
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _providerData?['name'] ?? 'Provider',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  (_providerData?['serviceType'] ?? 'Service Provider').toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontFamily: 'OpenSans',
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Icon(
                                    Icons.handyman,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.star, size: 16, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text(
                                      _rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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

                    // Availability Status
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_providerData?['availability']?['isAvailable'] ?? true)
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_providerData?['availability']?['isAvailable'] ?? true)
                              ? AppColors.success
                              : AppColors.warning,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            (_providerData?['availability']?['isAvailable'] ?? true)
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            size: 18,
                            color: (_providerData?['availability']?['isAvailable'] ?? true)
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          SizedBox(width: 10),
                          Text(
                            (_providerData?['availability']?['isAvailable'] ?? true)
                                ? 'Available for Work'
                                : 'Currently Busy',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: (_providerData?['availability']?['isAvailable'] ?? true)
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Statistics Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageProvider.get('statistics') ?? 'Statistics',
                          style: AppTextStyles.heading4.copyWith(
                            color: AppColors.trustBlue,
                          ),
                        ),
                        TextButton(
                          onPressed: _viewEarnings,
                          child: Text(
                            'Details',
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
                        _buildStatCard(
                          title: 'Total Bookings',
                          value: _totalBookings.toString(),
                          icon: Icons.calendar_today_outlined,
                          color: AppColors.trustBlue,
                        ),
                        _buildStatCard(
                          title: 'Pending',
                          value: _pendingBookings.toString(),
                          icon: Icons.pending_outlined,
                          color: AppColors.actionOrange,
                        ),
                        _buildStatCard(
                          title: 'Completed',
                          value: _completedBookings.toString(),
                          icon: Icons.check_circle_outlined,
                          color: AppColors.success,
                        ),
                        _buildStatCard(
                          title: 'Earnings',
                          value: 'Rs ${_totalEarnings.toStringAsFixed(2)}',
                          icon: Icons.attach_money_outlined,
                          color: AppColors.vividAzure,
                        ),
                      ],
                    ),
                    SizedBox(height: 25),

                    // Quick Actions
                    Text(
                      languageProvider.get('quick_actions') ?? 'Quick Actions',
                      style: AppTextStyles.heading4.copyWith(
                        color: AppColors.trustBlue,
                      ),
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
                        _buildActionCard(
                          title: 'Set Availability',
                          icon: Icons.access_time_outlined,
                          color: AppColors.modernTeal,
                          onTap: _setAvailability,
                        ),
                        _buildActionCard(
                          title: 'My Services',
                          icon: Icons.handyman_outlined,
                          color: AppColors.trustBlue,
                          onTap: _manageServices,
                        ),
                        _buildActionCard(
                          title: 'View Bookings',
                          icon: Icons.calendar_today_outlined,
                          color: AppColors.actionOrange,
                          onTap: _viewBookings,
                        ),
                        _buildActionCard(
                          title: 'View Earnings',
                          icon: Icons.bar_chart_outlined,
                          color: AppColors.vividAzure,
                          onTap: _viewEarnings,
                        ),
                      ],
                    ),
                    SizedBox(height: 25),

                    // Recent Bookings Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageProvider.get('recent_bookings') ?? 'Recent Bookings',
                          style: AppTextStyles.heading4.copyWith(
                            color: AppColors.trustBlue,
                          ),
                        ),
                        TextButton(
                          onPressed: _viewAllBookings,
                          child: Text(
                            languageProvider.get('see_all') ?? 'See All',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.vividAzure,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    
                    // Recent Bookings List - USING REAL DATA
                    if (_recentBookings.isEmpty)
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 50, color: AppColors.textDisabled),
                            SizedBox(height: 12),
                            Text(
                              'No recent bookings',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Provider ID: $_providerId',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textDisabled,
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadBookingData,
                              child: Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.vividAzure,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _recentBookings.length; i++)
                              Column(
                                children: [
                                  _buildBookingItem(_recentBookings[i]),
                                  if (i < _recentBookings.length - 1)
                                    Divider(height: 1, color: AppColors.divider),
                                ],
                              ),
                          ],
                        ),
                      ),
                    SizedBox(height: 25),

                    // Performance Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.surface, AppColors.cleanWhite],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.actionOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.trending_up_outlined,
                                    color: AppColors.actionOrange,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Performance',
                                  style: AppTextStyles.heading5.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 18, color: AppColors.success),
                                SizedBox(width: 10),
                                Text(
                                  'Total Bookings: $_totalBookings',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 18, color: AppColors.success),
                                SizedBox(width: 10),
                                Text(
                                  'Completed: $_completedBookings',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.star, size: 18, color: AppColors.success),
                                SizedBox(width: 10),
                                Text(
                                  'Rating: ${_rating.toStringAsFixed(1)}/5',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _viewAllBookings,
                              icon: Icon(Icons.analytics_outlined, size: 20),
                              label: Text('View All Bookings'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.trustBlue),
                                minimumSize: Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cleanWhite,
          selectedItemColor: AppColors.actionOrange,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.caption,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: languageProvider.get('dashboard') ?? 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: languageProvider.get('bookings') ?? 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money_outlined),
              activeIcon: Icon(Icons.attach_money),
              label: languageProvider.get('earnings') ?? 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: languageProvider.get('profile') ?? 'Profile',
            ),
          ],
          onTap: (index) {
            setState(() => _selectedIndex = index);
            _handleBottomNavigation(index);
          },
        ),
      ),
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    // Extract data with safe defaults
    final customerName = booking['customerName'] ?? 
                       (booking['customerId'] != null ? 'Customer ${booking['customerId'].toString().substring(0, 8)}' : 'Customer');
    final serviceType = booking['serviceType'] ?? 'Service';
    final time = booking['time'] ?? 'Time not specified';
    final status = booking['status'] ?? 'pending';
    final bookingDate = booking['date'] is Timestamp 
        ? (booking['date'] as Timestamp).toDate()
        : DateTime.now();
    
    final formattedDate = DateFormat('MMM dd, yyyy').format(bookingDate);
    
    Color statusColor = AppColors.actionOrange;
    String statusText = 'Pending';
    
    switch (status) {
      case 'pending':
        statusColor = AppColors.actionOrange;
        statusText = 'Pending';
        break;
      case 'accepted':
        statusColor = AppColors.vividAzure;
        statusText = 'Accepted';
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusText = 'Cancelled';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'Rejected';
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InkWell(
        onTap: () => _viewBookingDetails(booking),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.vividAzure.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.person_outlined,
                size: 24,
                color: AppColors.vividAzure,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.toString(),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$serviceType • $formattedDate, $time',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                statusText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewBookingDetails(Map<String, dynamic> booking) {
    final customerName = booking['customerName'] ?? 
                       (booking['customerId'] != null ? 'Customer ${booking['customerId'].toString().substring(0, 8)}' : 'Customer');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Booking ID: ${booking['id'] ?? 'N/A'}'),
              SizedBox(height: 8),
              Text('Customer:  $customerName'),
              SizedBox(height: 8),
              Text('Service: ${booking['serviceType'] ?? 'N/A'}'),
              SizedBox(height: 8),
              if (booking['date'] is Timestamp)
                Text('Date: ${DateFormat('yyyy-MM-dd').format((booking['date'] as Timestamp).toDate())}')
              else
                Text('Date: N/A'),
              SizedBox(height: 8),
              Text('Time: ${booking['time'] ?? 'N/A'}'),
              SizedBox(height: 8),
              Text('Address: ${booking['address'] ?? 'N/A'}'),
              SizedBox(height: 8),
              Text('Status: ${booking['status'] ?? 'pending'}'),
              if (booking['problemDescription'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
              value,
              style: AppTextStyles.heading5.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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

  // Action Methods
  void _setAvailability() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Availability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Available for Work'),
              value: _providerData?['availability']?['isAvailable'] ?? true,
              onChanged: (value) {
                _updateAvailability(value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateAvailability(bool isAvailable) async {
    try {
      if (_providerId.isEmpty) return;
      
      await _userService.updateProviderAvailability(
        userId: _providerId,
        isAvailable: isAvailable,
      );
      
      setState(() {
        if (_providerData != null) {
          _providerData!['availability'] = {
            ..._providerData!['availability'],
            'isAvailable': isAvailable,
          };
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAvailable 
              ? 'You are now available for work'
              : 'You are now marked as busy'
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error updating availability: $e');
    }
  }

  void _manageServices() {
    Navigator.pushNamed(context, '/provider-services');
  }

  void _viewBookings() {
    Navigator.pushNamed(context, '/provider-bookings');
  }

  void _viewEarnings() {
    Navigator.pushNamed(context, '/provider-earnings');
  }

  void _viewAllBookings() {
    Navigator.pushNamed(context, '/provider-bookings');
  }

  void _handleBottomNavigation(int index) {
    switch (index) {
      case 0:
        // Already on dashboard
        break;
      case 1:
        _viewBookings();
        break;
      case 2:
        _viewEarnings();
        break;
      case 3:
        Navigator.pushNamed(context, '/provider-profile');
        break;
    }
  }
}