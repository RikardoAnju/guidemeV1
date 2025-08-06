import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  

  final Color primaryGreen = const Color(0xFF5ABB4D); // Sea Green
  final Color lightGreen = const Color(0xFF5ABB4D); // Regular Green
  
  bool isLoading = false;
  bool pushNotificationsEnabled = true;
  bool inAppNotificationsEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }
  
  Future<void> _loadNotificationSettings() async {
    setState(() => isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _firestore.collection('users').doc(user.uid).get();
        final data = snapshot.data();
        
        if (data != null && data.containsKey('notificationSettings')) {
          setState(() {
            pushNotificationsEnabled = data['notificationSettings']['pushEnabled'] ?? true;
            inAppNotificationsEnabled = data['notificationSettings']['inAppEnabled'] ?? true;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memuat pengaturan notifikasi: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _updateNotificationSetting({
    required String settingType,
    required bool value,
  }) async {
    setState(() => isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'notificationSettings.$settingType': value,
        });
        
        if (settingType == 'pushEnabled') {
          setState(() => pushNotificationsEnabled = value);
        } else if (settingType == 'inAppEnabled') {
          setState(() => inAppNotificationsEnabled = value);
        }
        
        _showSuccessSnackBar('Pengaturan notifikasi berhasil diperbarui');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memperbarui pengaturan: ${e.toString()}');
      // Revert the UI state if the update failed
      if (settingType == 'pushEnabled') {
        setState(() => pushNotificationsEnabled = !value);
      } else if (settingType == 'inAppEnabled') {
        setState(() => inAppNotificationsEnabled = !value);
      }
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Size screenSize = MediaQuery.of(context).size;
    final contentWidth = screenSize.width > 600 ? 600.0 : screenSize.width * 0.92;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button (arrow back)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(12),
                elevation: 3,
                shadowColor: primaryGreen.withOpacity(0.5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            
            // Title in the center
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Pengaturan Notifikasi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: isLoading
                ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Notification settings explanation
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryGreen.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: primaryGreen),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Atur bagaimana Anda ingin menerima notifikasi dari aplikasi. Matikan untuk menonaktifkan jenis notifikasi.',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Push notifications toggle
                        Container(
                          width: contentWidth,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode 
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifikasi Push',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildNotificationToggle(
                                  title: 'Aktifkan Notifikasi Push',
                                  description: 'Terima notifikasi meskipun tidak sedang menggunakan aplikasi',
                                  icon: Icons.notifications_active_outlined,
                                  value: pushNotificationsEnabled,
                                  onChanged: (value) {
                                    _updateNotificationSetting(
                                      settingType: 'pushEnabled',
                                      value: value,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // In-app notifications toggle
                        Container(
                          width: contentWidth,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode 
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifikasi Dalam Aplikasi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildNotificationToggle(
                                  title: 'Aktifkan Notifikasi Dalam Aplikasi',
                                  description: 'Terima notifikasi saat menggunakan aplikasi',
                                  icon: Icons.mark_email_unread_outlined,
                                  value: inAppNotificationsEnabled,
                                  onChanged: (value) {
                                    _updateNotificationSetting(
                                      settingType: 'inAppEnabled',
                                      value: value,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Additional notification settings explanation
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Anda juga dapat mengonfigurasi izin notifikasi di pengaturan perangkat Anda.',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotificationToggle({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black12 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryGreen.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                // Update the local state immediately for responsive UI
                if (title.contains('Notifikasi Push')) {
                  pushNotificationsEnabled = newValue;
                } else if (title.contains('Dalam Aplikasi')) {
                  inAppNotificationsEnabled = newValue;
                }
              });
              
              // Call the handler to update the backend
              onChanged(newValue);
            },
            activeColor: primaryGreen,
            activeTrackColor: primaryGreen.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}