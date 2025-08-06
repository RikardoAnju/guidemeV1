import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guide_me/services/notifikasiUser_service.dart';

class NotificationsUserPage extends StatefulWidget {
  final String userId;

  const NotificationsUserPage({super.key, required this.userId});

  @override
  State<NotificationsUserPage> createState() => _NotificationsUserPageState();
}

class _NotificationsUserPageState extends State<NotificationsUserPage> {
  final NotifikasiUserService _service = NotifikasiUserService();
  bool _isLoading = true;

  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color darkGreen = const Color(0xFF1B5E20);
  final Color lightGreen = const Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    // Set loading to false after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _markAsRead(String id, {bool isFeedback = false}) async {
    try {
      // Use the unified method from service
      await _service.markNotificationAsRead(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking notification as read: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      // Updated to use the correct service method
      await _service.markAllNotificationsAsRead(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua notifikasi telah ditandai sebagai dibaca'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking all notifications as read: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id, {bool isFeedback = false}) async {
    try {
      // Use the unified delete method from service
      await _service.deleteNotification(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: StreamBuilder<List<dynamic>>(
        stream: _service.getAllNotificationsStream(widget.userId),
        builder: (ctx, snap) {
          if (_isLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryGreen),
            );
          }

          // Enhanced error handling
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.error.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      // Trigger rebuild
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final list = snap.data ?? [];

          if (list.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final notification = list[i];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2E7D32),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Notifikasi',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.mark_email_read,
                color: primaryGreen,
                size: 20,
              ),
            ),
            tooltip: 'Tandai Semua Dibaca',
            onPressed: _markAllRead,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: lightGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tidak ada notifikasi',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Semua notifikasi akan muncul di sini',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notification) {
    // Determine if it's a feedback notification
    final bool isFeedback = notification is FeedbackNotification;
    
    // Common properties - updated to handle both notification types properly
    final String id = notification.id;
    final String title = notification.title;
    final String message = notification.message;
    final String type = notification.type;
    final bool isRead = notification.isRead;
    final DateTime timestamp = notification.timestamp;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!isRead) _markAsRead(id);
            // TODO: Add navigation based on notification type
            _handleNotificationTap(notification, isFeedback);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead 
                    ? Colors.transparent 
                    : primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFeedback 
                          ? [Colors.blue, Colors.blue.shade700]
                          : [primaryGreen, darkGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getNotificationIcon(type, isFeedback),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: isRead 
                                    ? FontWeight.w500 
                                    : FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isFeedback ? Colors.blue : primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Message
                      Text(
                        message,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Bottom row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getRelativeTime(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Row(
                            children: [
                              // Mark as read button
                              if (!isRead)
                                _buildActionButton(
                                  onTap: () => _markAsRead(id),
                                  icon: Icons.mark_email_read,
                                  label: 'Tandai dibaca',
                                  color: isFeedback ? Colors.blue : primaryGreen,
                                ),
                              const SizedBox(width: 8),
                              // Delete button
                              _buildActionButton(
                                onTap: () => _deleteNotification(id),
                                icon: Icons.delete_outline,
                                label: 'Hapus',
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Handle notification tap based on type
  void _handleNotificationTap(dynamic notification, bool isFeedback) {
    if (isFeedback) {
      // Handle feedback notification tap
      final feedbackNotification = notification as FeedbackNotification;
      // TODO: Navigate to feedback details page
      print('Tapped feedback notification: ${feedbackNotification.feedbackId}');
    } else {
      // Handle general notification tap
      final userNotification = notification as UserNotification;
      switch (userNotification.type.toLowerCase()) {
        case 'destination_approval':
        case 'destination_rejection':
          // TODO: Navigate to destinations page
          print('Navigate to destinations');
          break;
        case 'event_approval':
        case 'event_rejection':
          // TODO: Navigate to events page
          print('Navigate to events');
          break;
        case 'role_approval':
        case 'role_rejection':
          // TODO: Navigate to profile or role management page
          print('Navigate to role management');
          break;
        case 'booking':
          // TODO: Navigate to bookings page
          print('Navigate to bookings');
          break;
        case 'payment':
          // TODO: Navigate to payment history
          print('Navigate to payment history');
          break;
        default:
          print('Default notification tap');
      }
    }
  }

  // Helper method untuk mendapatkan icon notifikasi
  IconData _getNotificationIcon(String type, bool isFeedback) {
    if (isFeedback) {
      return Icons.feedback_outlined;
    }
    
    switch (type.toLowerCase()) {
      case 'destination_approval':
      case 'approved':
        return Icons.check_circle_outline;
      case 'destination_rejection':
      case 'rejected':
        return Icons.cancel_outlined;
      case 'event_approval':
        return Icons.event_available_outlined;
      case 'event_rejection':
        return Icons.event_busy_outlined;
      case 'role_approval':
        return Icons.verified_user_outlined;
      case 'role_rejection':
        return Icons.person_off_outlined;
      case 'booking':
        return Icons.bookmark_outline;
      case 'payment':
        return Icons.payment;
      case 'guide':
        return Icons.person_outline;
      case 'system':
        return Icons.system_update;
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'success':
        return Icons.check_circle_outline;
      case 'error':
        return Icons.error_outline;
      case 'admin_reply':
        return Icons.reply_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  // Helper method untuk mendapatkan relative time
  String _getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    String? label,
    bool isIconOnly = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isIconOnly ? 8 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}