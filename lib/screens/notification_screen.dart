import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../constants/app_colors.dart';
import '../constants/text_styles.dart';
import '../services/reminder_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ReminderService _reminderService = ReminderService();
  String _userId = '';
  String _userType = 'customer';
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('userId') ?? '';
        _userType = prefs.getString('userType') ?? 'customer';
      });
      
      // Load notifications from Firestore
      await _loadNotifications();
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      // In a real app, you would fetch notifications from Firestore
      // For now, we'll use simulated data
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        _notifications = _getSampleNotifications();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getSampleNotifications() {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    
    if (_userType == 'customer') {
      return [
        {
          'id': '1',
          'title': 'Booking Accepted',
          'message': 'Your Electrician service with John Doe has been accepted for tomorrow at 2:00 PM',
          'type': 'status_change',
          'timestamp': now.subtract(Duration(hours: 2)),
          'isRead': false,
          'bookingId': 'booking_123',
        },
        {
          'id': '2',
          'title': 'Service Reminder',
          'message': 'Your Plumber service is scheduled for tomorrow at 10:00 AM',
          'type': 'booking_reminder',
          'timestamp': yesterday,
          'isRead': true,
          'bookingId': 'booking_456',
        },
        {
          'id': '3',
          'title': 'Service Starting Soon',
          'message': 'Your Cleaner service starts in 1 hour',
          'type': 'booking_reminder',
          'timestamp': now.subtract(Duration(minutes: 30)),
          'isRead': false,
          'bookingId': 'booking_789',
        },
      ];
    } else {
      return [
        {
          'id': '1',
          'title': 'New Booking Request',
          'message': 'Jane Smith booked Electrician service for tomorrow at 2:00 PM',
          'type': 'new_booking',
          'timestamp': now.subtract(Duration(hours: 1)),
          'isRead': false,
          'bookingId': 'booking_123',
        },
        {
          'id': '2',
          'title': 'Pending Booking Expiry',
          'message': 'You have a pending booking from Mike Johnson that expires tomorrow',
          'type': 'pending_expiry',
          'timestamp': yesterday,
          'isRead': true,
          'bookingId': 'booking_456',
        },
        {
          'id': '3',
          'title': 'Service Reminder',
          'message': 'You have a Plumber service for Sarah Williams tomorrow at 10:00 AM',
          'type': 'booking_reminder',
          'timestamp': now.subtract(Duration(hours: 3)),
          'isRead': false,
          'bookingId': 'booking_789',
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTextStyles.heading5.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.trustBlue,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingState()
          : _notifications.isEmpty 
              ? _buildEmptyState()
              : _buildNotificationsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_userType == 'customer') {
            await _reminderService.sendTestCustomerNotification();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Test customer notification sent!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            await _reminderService.sendTestProviderNotification();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Test provider notification sent!'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        },
        backgroundColor: AppColors.vividAzure,
        child: Icon(Icons.notifications_none),
        tooltip: 'Send Test Notification',
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.vividAzure),
          SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: AppColors.textDisabled,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: AppTextStyles.heading5.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _userType == 'customer'
                ? 'You\'ll see booking updates and reminders here'
                : 'You\'ll see new bookings and service reminders here',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to bookings
              Navigator.pushNamed(
                context,
                _userType == 'customer' ? '/my-bookings' : '/provider-bookings',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.vividAzure,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              _userType == 'customer' ? 'View Bookings' : 'View Services',
              style: AppTextStyles.button,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification, index);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final type = notification['type'] ?? 'general';
    final isRead = notification['isRead'] ?? false;
    final timestamp = notification['timestamp'] as DateTime;
    
    Color iconColor = AppColors.textSecondary;
    IconData icon = Icons.notifications_none;
    Color backgroundColor = isRead ? AppColors.surface : AppColors.cleanWhite;
    
    // Set icon and color based on notification type
    switch (type) {
      case 'booking_reminder':
        iconColor = AppColors.vividAzure;
        icon = Icons.calendar_today;
        if (!isRead) backgroundColor = AppColors.vividAzure.withOpacity(0.05);
        break;
      case 'status_change':
        iconColor = AppColors.trustBlue;
        icon = Icons.info_outline;
        if (!isRead) backgroundColor = AppColors.trustBlue.withOpacity(0.05);
        break;
      case 'pending_expiry':
        iconColor = AppColors.warning;
        icon = Icons.timer_outlined;
        if (!isRead) backgroundColor = AppColors.warning.withOpacity(0.05);
        break;
      case 'new_booking':
        iconColor = AppColors.success;
        icon = Icons.add_circle_outline;
        if (!isRead) backgroundColor = AppColors.success.withOpacity(0.05);
        break;
      case 'service_time':
        iconColor = AppColors.actionOrange;
        icon = Icons.access_time;
        if (!isRead) backgroundColor = AppColors.actionOrange.withOpacity(0.05);
        break;
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: isRead ? 0 : 2,
      color: backgroundColor,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: AppTextStyles.body.copyWith(
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              notification['message'] ?? '',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, hh:mm a').format(timestamp),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
        trailing: isRead 
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.vividAzure,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _handleNotificationTap(notification),
        onLongPress: () => _showNotificationOptions(notification),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read
    setState(() {
      _notifications = _notifications.map((n) {
        if (n['id'] == notification['id']) {
          return {...n, 'isRead': true};
        }
        return n;
      }).toList();
    });
    
    // Navigate based on notification type
    final bookingId = notification['bookingId'];
    if (bookingId != null) {
      Navigator.pushNamed(
        context,
        '/booking-details',
        arguments: {'bookingId': bookingId},
      );
    }
  }

  void _showNotificationOptions(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.mark_email_read, color: AppColors.vividAzure),
              title: Text('Mark as read'),
              onTap: () {
                Navigator.pop(context);
                _markAsRead(notification['id']);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteNotification(notification['id']);
              },
            ),
          ],
        );
      },
    );
  }

  void _markAsRead(String notificationId) {
    setState(() {
      _notifications = _notifications.map((n) {
        if (n['id'] == notificationId) {
          return {...n, 'isRead': true};
        }
        return n;
      }).toList();
    });
  }

  void _deleteNotification(String notificationId) {
    setState(() {
      _notifications.removeWhere((n) => n['id'] == notificationId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification deleted'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Notifications'),
        content: Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _notifications.clear();
              });
            },
            child: Text('Clear All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}