import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notifikasi_model.dart';
import 'services/notifikasiadmin_service.dart';

class NotificationsPage extends StatefulWidget {
  final String userId;

  const NotificationsPage({super.key, this.userId = 'ADM001'});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  late final Stream<List<AdminNotification>> _stream;
  bool _isLoading = true;

  // Warna tema hijau - konsisten dengan tambah destinasi
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color darkGreen = const Color(0xFF1B5E20);
  final Color lightGreen = const Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _service.initNotificationListeners();
    _stream = _service.getNotificationsStream();

    _stream.first.then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _markAsRead(String id) async {
    await _service.markAsRead(id);
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
  }

  Future<void> _deleteNotification(String id) async {
    await _service.deleteNotification(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Sama dengan tambah destinasi
      appBar: _buildAppBar(),
      body: StreamBuilder<List<AdminNotification>>(
        stream: _stream,
        builder: (ctx, snap) {
          if (_isLoading) {
            return Center(
              child: CircularProgressIndicator(color: primaryGreen),
            );
          }

          final list = snap.data ?? [];

          if (list.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24), // Konsisten dengan tambah destinasi
            itemCount: list.length,
            itemBuilder: (_, i) {
              final n = list[i];
              return _buildNotificationCard(n);
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
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

  Widget _buildNotificationCard(AdminNotification n) {
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
            if (!n.isRead) _markAsRead(n.id);
            // TODO: navigasi sesuai tipe
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: n.isRead 
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
                      colors: [primaryGreen, darkGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    n.getIcon(),
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
                              n.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: n.isRead 
                                    ? FontWeight.w500 
                                    : FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!n.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Message
                      Text(
                        n.message,
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
                            n.getRelativeTime(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Row(
                            children: [
                              // Mark as read button
                              if (!n.isRead)
                                _buildActionButton(
                                  onTap: () => _markAsRead(n.id),
                                  icon: Icons.mark_email_read,
                                  label: 'Tandai dibaca',
                                  color: primaryGreen,
                                ),
                              if (!n.isRead) const SizedBox(width: 8),
                              // Delete button
                              _buildActionButton(
                                onTap: () => _deleteNotification(n.id),
                                icon: Icons.delete_outline,
                                color: Colors.red,
                                isIconOnly: true,
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