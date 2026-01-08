import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/booking_service.dart';
import '../services/user_service.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingService _bookingService = BookingService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _userId = '';
  Map<String, String> _providerNames = {};
  List<Map<String, dynamic>> _allBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (userId.isEmpty) {
        print('⚠️ No user ID found');
        setState(() => _isLoading = false);
        return;
      }
      
      setState(() => _userId = userId);
      print('📋 Loading bookings for user: $userId');
      
      await _loadAllBookings();
      
    } catch (e) {
      print('❌ Error loading user ID: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllBookings() async {
    try {
      if (_userId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      
      print('📊 Loading ALL bookings for user: $_userId');
      
      // SIMPLE QUERY - NO ORDERING to avoid index requirement
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: _userId)
          .get();
      
      print('📈 Found ${bookingsSnapshot.docs.length} bookings');
      
      _allBookings = [];
      final providerIds = <String>{};
      
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final providerId = data['providerId'] as String?;
        if (providerId != null) {
          providerIds.add(providerId);
        }
        
        _allBookings.add({
          'id': doc.id,
          ...data,
          'rating': data['rating'],
          'review': data['review'],
          'reported': data['reported'] ?? false,
          'reviewedAt': data['reviewedAt'],
          'reportedAt': data['reportedAt'],
        });
      }
      
      // Fetch provider names
      await _fetchProviderNames(providerIds.toList());
      
      // Add provider names to bookings
      for (var booking in _allBookings) {
        final providerId = booking['providerId'] as String?;
        if (providerId != null && _providerNames.containsKey(providerId)) {
          booking['providerName'] = _providerNames[providerId];
        } else {
          booking['providerName'] = 'Provider';
        }
      }
      
      // Sort by date descending LOCALLY (not in query)
      _allBookings.sort((a, b) {
        final aDate = _getBookingDate(a);
        final bDate = _getBookingDate(b);
        return bDate.compareTo(aDate); // Descending
      });
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      print('❌ Error loading bookings: $e');
      print('Error details: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  DateTime _getBookingDate(Map<String, dynamic> booking) {
    if (booking['date'] is Timestamp) {
      return (booking['date'] as Timestamp).toDate();
    } else if (booking['createdAt'] is Timestamp) {
      return (booking['createdAt'] as Timestamp).toDate();
    }
    return DateTime(0);
  }

  Future<void> _fetchProviderNames(List<String> providerIds) async {
    try {
      if (providerIds.isEmpty) return;
      
      print('👷 Fetching names for ${providerIds.length} providers');
      
      for (final providerId in providerIds) {
        if (_providerNames.containsKey(providerId)) continue;
        
        try {
          // Try providers collection first
          final providerDoc = await _firestore.collection('providers').doc(providerId).get();
          if (providerDoc.exists) {
            final providerData = providerDoc.data() as Map<String, dynamic>;
            final providerName = providerData['name'] as String?;
            _providerNames[providerId] = providerName ?? 'Provider';
          } else {
            // Fallback to users collection
            final userDoc = await _firestore.collection('users').doc(providerId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final providerName = userData['name'] as String?;
              _providerNames[providerId] = providerName ?? 'Provider';
            } else {
              _providerNames[providerId] = 'Provider';
            }
          }
        } catch (e) {
          print('❌ Error fetching provider $providerId: $e');
          _providerNames[providerId] = 'Provider';
        }
      }
    } catch (e) {
      print('❌ Error fetching provider names: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredBookings(int tabIndex) {
    if (_allBookings.isEmpty) return [];
    
    switch (tabIndex) {
      case 0: // Upcoming (pending or accepted)
        return _allBookings.where((b) => 
          b['status'] == 'pending' || b['status'] == 'accepted'
        ).toList();
      case 1: // Completed
        return _allBookings.where((b) => 
          b['status'] == 'completed'
        ).toList();
      case 2: // Cancelled
        return _allBookings.where((b) => 
          b['status'] == 'cancelled' || b['status'] == 'rejected'
        ).toList();
      default:
        return _allBookings;
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.actionOrange,
          labelColor: AppColors.actionOrange,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.vividAzure))
          : _buildMainContent(),
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
          currentIndex: 1,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cleanWhite,
          selectedItemColor: AppColors.actionOrange,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/');
                break;
              case 1:
                // Already on bookings
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/messages');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/customer-profile');
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
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat),
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

  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildBookingsList(0),
        _buildBookingsList(1),
        _buildBookingsList(2),
      ],
    );
  }

  Widget _buildBookingsList(int tabIndex) {
    final filteredBookings = _getFilteredBookings(tabIndex);
    
    if (filteredBookings.isEmpty) {
      return _buildEmptyState(_getEmptyStateMessage(tabIndex), '/map');
    }
    
    return RefreshIndicator(
      onRefresh: _loadAllBookings,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          final providerName = booking['providerName'] ?? 'Provider';
          final isCompleted = tabIndex == 1;
          
          return _buildBookingCard(
            booking, 
            providerName: providerName, 
            isCompleted: isCompleted,
          );
        },
      ),
    );
  }

  String _getEmptyStateMessage(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'No upcoming bookings';
      case 1: return 'No completed bookings';
      case 2: return 'No cancelled bookings';
      default: return 'No bookings yet';
    }
  }

  Widget _buildBookingCard(
    Map<String, dynamic> booking, {
    required String providerName,
    required bool isCompleted,
  }) {
    final date = _getBookingDate(booking);
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);
    final status = booking['status'] ?? 'pending';
    
    Color statusColor = AppColors.actionOrange;
    String statusText = 'Pending';
    IconData statusIcon = Icons.pending_outlined;
    
    switch (status) {
      case 'pending':
        statusColor = AppColors.actionOrange;
        statusText = 'Waiting for provider';
        statusIcon = Icons.pending_outlined;
        break;
      case 'accepted':
        statusColor = AppColors.vividAzure;
        statusText = 'Accepted by provider';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusText = 'Completed';
        statusIcon = Icons.done_all_outlined;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'Rejected by provider';
        statusIcon = Icons.block_outlined;
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
            // Header with service type and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking['serviceType'] ?? 'Service',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Provider Name
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'Provider: $providerName',
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
                  '$formattedDate at ${booking['time'] ?? "Time not specified"}',
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
                    booking['address'] ?? 'No address',
                    style: TextStyle(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Cost Information
            if (booking['actualCost'] != null || booking['estimatedCost'] != null)
              Row(
                children: [
                  Icon(Icons.attach_money_outlined, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    booking['actualCost'] != null
                        ? 'Paid: Rs ${booking['actualCost']}'
                        : 'Estimated: Rs ${booking['estimatedCost']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            
            SizedBox(height: 12),
            
            // Problem Description (if available)
            if (booking['problemDescription'] != null && booking['problemDescription'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  SizedBox(height: 12),
                ],
              ),
            
            // Action buttons based on status
            _buildActionButtons(booking, providerName, isCompleted),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    Map<String, dynamic> booking, 
    String providerName,
    bool isCompleted
  ) {
    final status = booking['status'] as String? ?? 'pending';
    final hasRating = booking['rating'] != null;
    final hasReview = booking['review'] != null;
    final isRated = hasRating || hasReview;
    
    switch (status) {
      case 'pending':
      case 'accepted':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _contactProvider(booking, providerName),
                icon: Icon(Icons.chat_outlined, size: 18),
                label: Text('Message Provider'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.trustBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancelBooking(booking),
                icon: Icon(Icons.cancel_outlined, size: 18),
                label: Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
        
      case 'completed':
        return Column(
          children: [
            // Check if already rated - show rating button only if not rated
            if (!isRated)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _rateProvider(booking, providerName),
                    icon: Icon(Icons.star_outline, size: 18),
                    label: Text('Rate & Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionOrange,
                      minimumSize: Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _contactProvider(booking, providerName),
                    icon: Icon(Icons.chat_outlined, size: 18),
                    label: Text('Contact'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.trustBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: booking['reported'] == true
                        ? null // Disable if already reported
                        : () => _reportProvider(booking, providerName),
                    icon: Icon(
                      booking['reported'] == true 
                          ? Icons.flag 
                          : Icons.flag_outlined, 
                      size: 18
                    ),
                    label: Text(
                      booking['reported'] == true ? 'Reported' : 'Report'
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: booking['reported'] == true 
                            ? AppColors.textDisabled 
                            : AppColors.error
                      ),
                      foregroundColor: booking['reported'] == true
                          ? AppColors.textDisabled
                          : AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Show existing rating if available
            if (isRated)
              Column(
                children: [
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Review:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (booking['rating'] != null)
                          Row(
                            children: [
                              for (int i = 0; i < 5; i++)
                                Icon(
                                  i < (booking['rating'] as int) 
                                      ? Icons.star 
                                      : Icons.star_border,
                                  size: 16,
                                  color: AppColors.actionOrange,
                                ),
                              SizedBox(width: 8),
                              Text(
                                '${booking['rating']}/5',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        if (booking['review'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              booking['review'].toString(),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        if (booking['reviewedAt'] != null && booking['reviewedAt'] is Timestamp)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Reviewed on: ${DateFormat('MMM dd, yyyy').format((booking['reviewedAt'] as Timestamp).toDate())}',
                              style: TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
        
      default: // cancelled/rejected
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _bookAgain(booking),
                icon: Icon(Icons.replay_outlined, size: 18),
                label: Text('Book Again'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.vividAzure),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildEmptyState(String message, String navigateTo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, navigateTo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionOrange,
              minimumSize: Size(200, 44),
            ),
            child: Text('Book a Service'),
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
        await _bookingService.cancelBooking(
          booking['id'],
          'Cancelled by customer',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Refresh the list
        await _loadAllBookings();
        
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

  Future<void> _rateProvider(Map<String, dynamic> booking, String providerName) async {
    // Check if already rated
    if (booking['rating'] != null || booking['review'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already rated this service'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    double rating = 5.0;
    TextEditingController reviewController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Rate $providerName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How was your experience?'),
                  SizedBox(height: 16),
                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: () {
                            setState(() => rating = i.toDouble());
                          },
                          icon: Icon(
                            i <= rating ? Icons.star : Icons.star_border,
                            size: 32,
                            color: AppColors.actionOrange,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('${rating.toInt()}/5 stars'),
                  SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Your review (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Share your experience...',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your review will help other customers',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (rating > 0) {
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: Text('Submit Review'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      try {
        // Save rating to booking
        await _firestore.collection('bookings').doc(booking['id']).update({
          'rating': rating.toInt(),
          'review': reviewController.text.isNotEmpty ? reviewController.text : null,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update provider's overall rating
        await _userService.updateProviderStats(
          providerId: booking['providerId'],
          newRating: rating,
        );
        
        // Refresh the bookings list
        await _loadAllBookings();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: AppColors.success,
          ),
        );
        
      } catch (e) {
        print('❌ Error submitting review: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reportProvider(Map<String, dynamic> booking, String providerName) async {
    // Check if already reported
    if (booking['reported'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already reported this booking'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    String selectedIssue = '';
    TextEditingController detailsController = TextEditingController();
    
    final issues = [
      'Poor quality service',
      'Unprofessional behavior',
      'Late arrival',
      'Overcharging',
      'Safety concerns',
      'Other issue',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Report $providerName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please select the issue:'),
                  SizedBox(height: 12),
                  ...issues.map((issue) => RadioListTile<String>(
                    title: Text(issue),
                    value: issue,
                    groupValue: selectedIssue,
                    onChanged: (value) {
                      setState(() => selectedIssue = value!);
                    },
                  )).toList(),
                  SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Additional details',
                      border: OutlineInputBorder(),
                      hintText: 'Please provide more information...',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Reports are confidential and will be reviewed by our team',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedIssue.isNotEmpty 
                    ? () => Navigator.pop(context, true)
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Submit Report'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      try {
        // 1. Mark booking as reported
        await _firestore.collection('bookings').doc(booking['id']).update({
          'reported': true,
          'reportedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // 2. Save report to Firestore reports collection
        await _firestore.collection('reports').add({
          'bookingId': booking['id'],
          'providerId': booking['providerId'],
          'providerName': providerName,
          'customerId': _userId,
          'customerName': booking['customerName'] ?? 'Customer',
          'serviceType': booking['serviceType'],
          'issue': selectedIssue,
          'details': detailsController.text,
          'reportedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'bookingDate': booking['date'],
          'bookingTime': booking['time'],
        });
        
        // 3. Refresh the bookings list
        await _loadAllBookings();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted successfully. Our team will review it.'),
            backgroundColor: AppColors.success,
          ),
        );
        
      } catch (e) {
        print('❌ Error submitting report: $e');
        print('Error details: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _contactProvider(Map<String, dynamic> booking, String providerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Messaging feature coming soon!'),
        backgroundColor: AppColors.vividAzure,
      ),
    );
  }

  void _bookAgain(Map<String, dynamic> booking) {
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {
        'serviceType': booking['serviceType'],
        'serviceName': booking['serviceType'],
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}