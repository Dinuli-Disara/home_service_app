import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/booking_service.dart';
import '../services/user_service.dart';
import '../services/reminder_service.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({Key? key}) : super(key: key);

  @override
  _ProviderBookingsScreenState createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen> with SingleTickerProviderStateMixin{
  final BookingService _bookingService = BookingService();
  final ReminderService _reminderService = ReminderService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _providerId = '';
  String _userType = 'provider';
  int _selectedTab = 0;
  List<Map<String, dynamic>> _bookings = [];
  Map<String, String> _customerNames = {};
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProviderData();

    // Initialize notifications
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isNotEmpty) {
        await _reminderService.initialize(userId, 'provider');
      }
    } catch (e) {
      print('⚠️ Error initializing notifications: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();  // DISPOSE THE CONTROLLER
    super.dispose();
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
      
      await _loadBookings();
      
    } catch (e) {
      print('❌ Error loading provider data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBookings() async {
    try {
      if (_providerId.isEmpty) return;
      
      print('📊 Loading bookings for provider: $_providerId');
      
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: _providerId)
          .get();
      
      print('📈 Found ${bookingsSnapshot.docs.length} bookings');
      
      // Collect customer IDs
      final customerIds = <String>{};
      _bookings = [];
      
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final customerId = data['customerId'] as String?;
        if (customerId != null) {
          customerIds.add(customerId);
        }
        
        _bookings.add({
          'id': doc.id,
          ...data,
        });
      }
      
      // Fetch customer names
      await _fetchCustomerNames(customerIds.toList());
      
      // Add customer names to bookings
      for (var booking in _bookings) {
        final customerId = booking['customerId'] as String?;
        if (customerId != null && _customerNames.containsKey(customerId)) {
          booking['customerName'] = _customerNames[customerId];
          booking['customerName'] = 'Customer';
        }
      }
      
      // Sort by createdAt descending
      _bookings.sort((a, b) {
        final aDate = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(0);
        final bDate = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(0);
        return bDate.compareTo(aDate);
      });
      
      setState(() {});
      
    } catch (e) {
      print('❌ Error loading bookings: $e');
    }
  }

  Future<void> _fetchCustomerNames(List<String> customerIds) async {
    try {
      if (customerIds.isEmpty) return;
      
      for (final customerId in customerIds) {
        if (_customerNames.containsKey(customerId)) continue;
        
        final userDoc = await _firestore.collection('users').doc(customerId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final customerName = userData['name'] as String?;
          _customerNames[customerId] = customerName ?? 'Customer';
        } else {
          _customerNames[customerId] = 'Customer';
        }
      }
    } catch (e) {
      print('❌ Error fetching customer names: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredBookings() {
    switch (_selectedTab) {
      case 0: // Pending
        return _bookings.where((b) => b['status'] == 'pending').toList();
      case 1: // Accepted/Confirmed
        return _bookings.where((b) => b['status'] == 'accepted').toList();
      case 2: // Completed
        return _bookings.where((b) => b['status'] == 'completed').toList();
      case 3: // All
        return _bookings;
      default:
        return _bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Bookings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.trustBlue,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(  // MOVE TABBAR TO APPBAR
          controller: _tabController,
          indicatorColor: AppColors.actionOrange,
          labelColor: AppColors.actionOrange,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
          onTap: (index) {
            setState(() => _selectedTab = index);
          },
        ),
      ),
      
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.vividAzure),
            )
          : TabBarView(  // USE TabBarView INSTEAD
              controller: _tabController,
              children: [
                _buildBookingsListForTab(0),
                _buildBookingsListForTab(1),
                _buildBookingsListForTab(2),
                _buildBookingsListForTab(3),
              ],
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
          currentIndex: 1, // Bookings tab is active
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cleanWhite,
          selectedItemColor: AppColors.actionOrange,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/provider-dashboard');
                break;
              case 1:
                // Already on bookings
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/messages');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/provider-profile');
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined),
              activeIcon: Icon(Icons.message),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsListForTab(int tabIndex) {
    final filteredBookings = _getFilteredBookingsForTab(tabIndex);
    
    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: 16),
            Text(
              _getEmptyStateMessageForTab(tabIndex),
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(filteredBookings[index]);
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredBookingsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // Pending
        return _bookings.where((b) => b['status'] == 'pending').toList();
      case 1: // Accepted/Confirmed
        return _bookings.where((b) => b['status'] == 'accepted').toList();
      case 2: // Completed
        return _bookings.where((b) => b['status'] == 'completed').toList();
      case 3: // All
        return _bookings;
      default:
        return _bookings;
    }
  }

  String _getEmptyStateMessageForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'No pending bookings';
      case 1: return 'No confirmed bookings';
      case 2: return 'No completed bookings';
      case 3: return 'No bookings yet';
      default: return 'No bookings';
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final customerName = booking['customerName'] ?? 'Customer';
    final serviceType = booking['serviceType'] ?? 'Service';
    final time = booking['time'] ?? 'Time not specified';
    final status = booking['status'] ?? 'pending';
    final date = booking['date'] is Timestamp 
        ? (booking['date'] as Timestamp).toDate()
        : DateTime.now();
    final formattedDate = DateFormat('dd MMMyyyy').format(date);
    
    Color statusColor = AppColors.actionOrange;
    String statusText = 'Pending';
    
    switch (status) {
      case 'pending':
        statusColor = AppColors.actionOrange;
        statusText = 'Pending';
        break;
      case 'accepted':
        statusColor = AppColors.vividAzure;
        statusText = 'Confirmed';
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

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Service Info
            Row(
              children: [
                Icon(Icons.handyman_outlined, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  serviceType,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Date & Time
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  '$formattedDate at $time',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Address
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking['address'] ?? 'No address provided',
                    style: TextStyle(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Problem Description (if available)
            if (booking['problemDescription'] != null && booking['problemDescription'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Description:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    booking['problemDescription'].toString(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            
            SizedBox(height: 12),
            
            // Estimated Cost (if available)
            if (booking['estimatedCost'] != null)
              Row(
                children: [
                  Icon(Icons.attach_money_outlined, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Estimated: Rs ${booking['estimatedCost']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            
            SizedBox(height: 16),
            
            // Action Buttons based on status
            _buildActionButtons(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'pending';
    
    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _acceptBooking(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Accept',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectBooking(booking),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ],
        );
        
      case 'accepted':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _completeBooking(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.vividAzure,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Mark as Completed',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _cancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ],
        );
        
      case 'completed':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _contactCustomer(booking),
                icon: Icon(Icons.chat_outlined, size: 18),
                label: Text('Contact Customer'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.trustBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
        
      default:
        return SizedBox.shrink();
    }
  }

  Future<void> _acceptBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Accept Booking'),
        content: Text('Are you sure you want to accept this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text('Yes, Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _bookingService.updateBookingStatus(
          booking['id'],
          'accepted',
          'Booking accepted by provider',
        );
        
        // Update provider stats
        await _userService.updateProviderStats(
          providerId: _providerId,
          completedJob: false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking accepted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        
        await _loadBookings(); // Refresh list
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Booking'),
        content: Text('Are you sure you want to reject this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Yes, Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _bookingService.updateBookingStatus(
          booking['id'],
          'rejected',
          'Booking rejected by provider',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking rejected'),
            backgroundColor: AppColors.error,
          ),
        );
        
        await _loadBookings(); // Refresh list
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeBooking(Map<String, dynamic> booking) async {
    // Ask for actual cost if not provided
    final actualCost = await _showCompleteDialog(booking);
    
    if (actualCost != null) {
      try {
        await _bookingService.updateBookingStatus(
          booking['id'],
          'completed',
          'Service completed by provider',
          actualCost: actualCost,
        );
        
        // Update provider stats with earnings
        await _userService.updateProviderStats(
          providerId: _providerId,
          completedJob: true,
          earnings: actualCost,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking marked as completed'),
            backgroundColor: AppColors.success,
          ),
        );
        
        await _loadBookings(); // Refresh list
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<double?> _showCompleteDialog(Map<String, dynamic> booking) async {
    final estimatedCost = booking['estimatedCost'] as num?;
    TextEditingController costController = TextEditingController(
      text: estimatedCost?.toString() ?? '',
    );

    return await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter the actual service cost:'),
            SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Actual Cost (Rs)',
                border: OutlineInputBorder(),
                prefixText: 'Rs ',
              ),
            ),
            if (estimatedCost != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Estimated: Rs $estimatedCost',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final cost = double.tryParse(costController.text);
              if (cost != null && cost > 0) {
                Navigator.pop(context, cost);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid cost')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text('Mark Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _bookingService.updateBookingStatus(
          booking['id'],
          'cancelled',
          'Booking cancelled by provider',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: AppColors.error,
          ),
        );
        
        await _loadBookings(); // Refresh list
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _contactCustomer(Map<String, dynamic> booking) {
    // TODO: Implement chat system
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat feature coming soon!'),
        backgroundColor: AppColors.vividAzure,
      ),
    );
  }
}