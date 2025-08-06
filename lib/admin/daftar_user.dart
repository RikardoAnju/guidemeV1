import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Add Firebase Storage

class DaftarUserPage extends StatefulWidget {
  const DaftarUserPage({super.key});

  @override
  State<DaftarUserPage> createState() => _DaftarUserPageState();
}

class _DaftarUserPageState extends State<DaftarUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Add Firebase Storage instance
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _updateLastActive(); // Update last active saat halaman dimuat
    _startActiveTimer(); // Update setiap 1 menit
  }

  void _updateLastActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    }
  }

  void _startActiveTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateLastActive());
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hentikan timer saat halaman ditutup
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot snapshot = await _firestore.collection('users').get();

      final List<Map<String, dynamic>> loadedUsers = [];

      for (var doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        
        // Get photoUrl from user data or fetch from Firebase Storage if not available
        String photoUrl = userData['photoUrl'] ?? '';
        
        // If photoUrl is empty, try to get from Firebase Storage using uid
        if (photoUrl.isEmpty) {
          try {
            // Attempt to get the default profile image from Firebase Storage
            final ref = _storage.ref().child('profile_images/${doc.id}.jpg');
            photoUrl = await ref.getDownloadURL();
          } catch (e) {
            // If no image exists, keep photoUrl empty
            // This will show the fallback profile icon
          }
        }
        
        loadedUsers.add({
          'id': doc.id,
          'username': userData['username'] ?? 'Nama tidak tersedia',
          'email': userData['email'] ?? 'Email tidak tersedia',
          'role': userData['role'] ?? 'User',
          'lastActive': userData['lastActive']?.toDate() ?? DateTime.now(),
          'photoUrl': photoUrl,
          'emailVerified': userData['emailVerified'] ?? false,
        });
      }

      setState(() {
        _users = loadedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Gagal memuat data: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terjadi Kesalahan'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;

    return _users.where((user) {
      final String nama = user['username'].toString().toLowerCase();
      final String email = user['email'].toString().toLowerCase();
      final String role = user['role'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return nama.contains(query) || email.contains(query) || role.contains(query);
    }).toList();
  }

  String _getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Belum pernah aktif'; 
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }

  Future<void> _confirmDeleteUser(String userId, String username) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah kamu yakin ingin menghapus pengguna "$username"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Also delete profile image from Firebase Storage if it exists
        try {
          final ref = _storage.ref().child('profile_images/$userId.jpg');
          await ref.delete();
        } catch (e) {
          
        }
        
        // Delete user document
        await _firestore.collection('users').doc(userId).delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User "$username" berhasil dihapus')),
        );
        await _fetchUsers();
      } catch (e) {
        _showErrorDialog('Gagal menghapus user: $e');
      }
    }
  }

  void _showUserProfile(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildUserProfileModal(user),
    );
  }

  Widget _buildProfileImage(String photoUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: photoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green[700],
                  ),
                ),
                errorWidget: (context, url, error) => _buildProfileFallback(size),
                fit: BoxFit.cover,
                width: size,
                height: size,
                fadeInDuration: const Duration(milliseconds: 300),
              )
            : _buildProfileFallback(size),
      ),
    );
  }
  
  // New method for profile fallback with a better design
  Widget _buildProfileFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.green.withOpacity(0.1),
      child: Center(
        child: Text(
          'A', // You could use the first letter of username instead
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileModal(Map<String, dynamic> user) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Profile picture
              Center(
                child: Stack(
                  children: [
                    Hero(
                      tag: 'user-avatar-${user['id']}',
                      child: _buildProfileImage(user['photoUrl'], 120),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E8B57),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // User name
              Center(
                child: Text(
                  user['username'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              
              // User role badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user['role'],
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // User info
              _buildInfoCard(
                'Email',
                user['email'],
                Icons.email_outlined,
                user['emailVerified'] 
                  ? const Icon(Icons.verified, color: Colors.green, size: 18)
                  : const Icon(Icons.warning, color: Colors.amber, size: 18),
              ),
              _buildInfoCard(
                'Terakhir Aktif',
                _getRelativeTime(user['lastActive']),
                Icons.access_time,
                null,
              ),
              _buildInfoCard(
                'ID Pengguna',
                user['id'],
                Icons.badge_outlined,
                null,
              ),
              
              const SizedBox(height: 30),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    'Edit Profil',
                    Icons.edit_outlined,
                    Colors.blue,
                    () {
                      Navigator.pop(context);
                      // Add navigation to edit profile page
                    },
                  ),
                  const SizedBox(width: 15),
                  _buildActionButton(
                    'Hapus',
                    Icons.delete_outline,
                    Colors.red,
                    () {
                      Navigator.pop(context);
                      _confirmDeleteUser(user['id'], user['username']);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Widget? trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF2E8B57)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Search
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E8B57),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Daftar Pengguna',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola semua pengguna dalam sistem',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: _filterUsers,
                      decoration: InputDecoration(
                        hintText: 'Cari pengguna...',
                        prefixIcon: Icon(Icons.search, color: Colors.green[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Filters and count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_filteredUsers.length} Pengguna',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_isLoading)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _fetchUsers,
                        child: const Icon(Icons.refresh, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            // User list
            Expanded(
              child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: const Color(0xFF2E8B57)),
                  )
                : _filteredUsers.isEmpty
                  ? const Center(
                      child: Text('Tidak ada pengguna ditemukan.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _buildUserCard(user);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    // Get the first letter of username for fallback avatar
    final String firstLetter = user['username'].toString().isNotEmpty 
        ? user['username'].toString()[0].toUpperCase() 
        : 'A';
        
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: InkWell(
        onTap: () => _showUserProfile(user),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Hero(
              tag: 'user-avatar-${user['id']}',
              child: user['photoUrl'].isNotEmpty
                ? _buildProfileImage(user['photoUrl'], 48)
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    user['username'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user['emailVerified'])
                  const Icon(Icons.verified, color: Colors.green, size: 16),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  user['email'],
                  style: TextStyle(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user['role'],
                      style: TextStyle(color: Colors.green[800], fontSize: 12),
                    ),
                    Text(
                      'Aktif ${_getRelativeTime(user['lastActive'])}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[700]),
              onSelected: (value) {
                if (value == 'view') {
                  _showUserProfile(user);
                } else if (value == 'delete') {
                  _confirmDeleteUser(user['id'], user['username']);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: Color(0xFF2E8B57), size: 18),
                      SizedBox(width: 8),
                      Text('Lihat Profil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Hapus User', style: TextStyle(color: Colors.red)),
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
}