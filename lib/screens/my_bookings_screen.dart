import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import '../services/user_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingService _bookingService = BookingService();
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    // This would come from shared preferences or auth
    // For now, we'll use a placeholder
    // You'll need to implement proper user ID retrieval
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Upcoming Bookings
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _userId.isNotEmpty 
                ? _bookingService.getUserBookings(_userId)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              final bookings = snapshot.data!.where((b) => 
                b['status'] == 'pending' || b['status'] == 'accepted'
              ).toList();
              
              if (bookings.isEmpty) {
                return _buildEmptyState('No upcoming bookings');
              }
              
              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  return _buildBookingCard(bookings[index]);
                },
              );
            },
          ),
          
          // Completed Bookings
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _userId.isNotEmpty 
                ? _bookingService.getUserBookings(_userId)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              final bookings = snapshot.data!.where((b) => 
                b['status'] == 'completed'
              ).toList();
              
              if (bookings.isEmpty) {
                return _buildEmptyState('No completed bookings');
              }
              
              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  return _buildBookingCard(bookings[index]);
                },
              );
            },
          ),
          
          // Cancelled Bookings
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _userId.isNotEmpty 
                ? _bookingService.getUserBookings(_userId)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              final bookings = snapshot.data!.where((b) => 
                b['status'] == 'cancelled' || b['status'] == 'rejected'
              ).toList();
              
              if (bookings.isEmpty) {
                return _buildEmptyState('No cancelled bookings');
              }
              
              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  return _buildBookingCard(bookings[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final date = (booking['date'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);
    
    Color statusColor = Colors.orange;
    String statusText = booking['status'];
    
    switch (booking['status']) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusText = 'Accepted';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  booking['serviceType'] ?? 'Service',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'Booking ID: ${booking['bookingId']?.toString().substring(0, 8) ?? 'N/A'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text('$formattedDate at ${booking['time']}'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking['address'] ?? 'No address',
                    style: TextStyle(color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (booking['estimatedCost'] != null)
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Estimated: LKR ${booking['estimatedCost']}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            SizedBox(height: 15),
            
            // Action buttons based on status
            if (booking['status'] == 'pending' || booking['status'] == 'accepted')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelBooking(booking),
                      child: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  if (booking['status'] == 'pending')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _contactProvider(booking),
                        child: Text('Contact'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/map');
            },
            child: Text('Book a Service'),
          ),
        ],
      ),
    );
  }

  void _cancelBooking(Map<String, dynamic> booking) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bookingService.cancelBooking(
                booking['id'],
                'Cancelled by user',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Booking cancelled')),
              );
            },
            child: Text('Yes, Cancel'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _contactProvider(Map<String, dynamic> booking) {
    // TODO: Implement chat/message system
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Contact feature coming soon!')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}