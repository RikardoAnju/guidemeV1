import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart';
// import 'package:url_launcher/url_launcher.dart'; // Hapus ini jika sudah tidak dipakai
import 'map_view_page.dart';

class KelolahOwnerPage extends StatefulWidget {
  const KelolahOwnerPage({super.key});

  @override
  State<KelolahOwnerPage> createState() => _KelolahOwnerPageState();
}

class _KelolahOwnerPageState extends State<KelolahOwnerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _owners = [];
  String _searchQuery = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchOwners();
    _updateLastActive();
    _startActiveTimer();
  }

  void _updateLastActive() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docSnapshot =
            await _firestore.collection('owners').doc(user.uid).get();
        if (docSnapshot.exists) {
          await _firestore.collection('owners').doc(user.uid).update({
            'approvedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  void _startActiveTimer() {
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateLastActive(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOwners() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot snapshot =
          await _firestore.collection('owners').get();
      final List<Map<String, dynamic>> loadedOwners = [];

      for (var doc in snapshot.docs) {
        final ownerData = doc.data() as Map<String, dynamic>;
        String photoUrl = '';
        try {
          final ref = _storage.ref().child('profile_images/${doc.id}.jpg');
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          // Tidak ada gambar profil
        }

        loadedOwners.add({
          'id': doc.id,
          'userId': ownerData['userId'] ?? doc.id,
          'username': ownerData['username'] ?? 'Nama tidak tersedia',
          'email': ownerData['email'] ?? 'Email tidak tersedia',
          'accountNumber': ownerData['accountNumber'] ?? 'Tidak tersedia',
          'bankName': ownerData['bankName'] ?? 'Tidak tersedia',
          'destinationName': ownerData['destinationName'] ?? 'Tidak tersedia',
          'description': ownerData['description'] ?? 'Tidak ada deskripsi',
          'ktpUrl': ownerData['ktpUrl'] ?? '',
          'mapsUrl': ownerData['mapsUrl'] ?? '',
          'isActive': ownerData['isActive'] ?? false,
          'approvedAt': ownerData['approvedAt']?.toDate() ?? DateTime.now(),
          'createdAt': ownerData['createdAt']?.toDate() ?? DateTime.now(),
          'photoUrl': photoUrl,
          'role': 'Owner',
        });
      }

      setState(() {
        _owners = loadedOwners;
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
      builder:
          (ctx) => AlertDialog(
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
    if (_searchQuery.isEmpty) return _owners;

    return _owners.where((user) {
      final String nama = user['username'].toString().toLowerCase();
      final String email = user['email'].toString().toLowerCase();
      final String bankName = user['bankName'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return nama.contains(query) ||
          email.contains(query) ||
          bankName.contains(query);
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

  Future<void> _confirmDeleteOwner(String ownerId, String username) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Hapus'),
            content: Text(
              'Apakah kamu yakin ingin menghapus owner "$username"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        try {
          final ref = _storage.ref().child('profile_images/$ownerId.jpg');
          await ref.delete();
        } catch (e) {
          // Gambar tidak ada, lanjutkan
        }

        try {
          final ownerData = _owners.firstWhere(
            (owner) => owner['id'] == ownerId,
          );
          if (ownerData['ktpUrl'].isNotEmpty) {
            final ref = FirebaseStorage.instance.refFromURL(
              ownerData['ktpUrl'],
            );
            await ref.delete();
          }
        } catch (e) {
          // Gambar KTP tidak ada atau error, lanjutkan
        }

        await _firestore.collection('owners').doc(ownerId).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Owner "$username" berhasil dihapus')),
        );
        await _fetchOwners();
      } catch (e) {
        _showErrorDialog('Gagal menghapus owner: $e');
      }
    }
  }

  Future<void> _confirmConvertToUser(
    String ownerId,
    String username,
    Map<String, dynamic> ownerData,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Ubah Role'),
            content: Text(
              'Apakah kamu yakin ingin mengubah "$username" dari Owner menjadi User? Data owner akan dipindahkan ke koleksi users.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Ubah ke User',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(ownerId).set({
          'username': ownerData['username'],
          'email': ownerData['email'],
          'role': 'User',
          'emailVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'photoUrl': ownerData['photoUrl'],
        });

        try {
          if (ownerData['ktpUrl'].isNotEmpty) {
            final ref = FirebaseStorage.instance.refFromURL(
              ownerData['ktpUrl'],
            );
            await ref.delete();
          }
        } catch (e) {
          // Gambar KTP tidak ada atau error, lanjutkan
        }

        await _firestore.collection('owners').doc(ownerId).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Owner "$username" berhasil diubah menjadi User'),
          ),
        );
        await _fetchOwners();
      } catch (e) {
        _showErrorDialog('Gagal mengubah role: $e');
      }
    }
  }

  LatLng? _parseGoogleMapsUrl(String url) {
    final RegExp regex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)(?:,\d+z)?');
    final match = regex.firstMatch(url);

    if (match != null && match.groupCount >= 2) {
      try {
        final double latitude = double.parse(match.group(1)!);
        final double longitude = double.parse(match.group(2)!);
        return LatLng(latitude, longitude);
      } catch (e) {
        print('Error parsing coordinates from URL: $e');
        return null;
      }
    }
    return null;
  }

  // --- Fungsi baru untuk menampilkan KTP dalam modal ---
  void _showKtpImageModal(String ktpUrl, String username) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade100,
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header dengan desain hijau
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade500],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.credit_card,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kartu Tanda Penduduk',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                username,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content area
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                        maxWidth: MediaQuery.of(ctx).size.width * 0.9,
                      ),
                      padding: const EdgeInsets.all(20),
                      child:
                          ktpUrl.isNotEmpty
                              ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Hint text untuk zoom
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.zoom_in,
                                          size: 16,
                                          color: Colors.green.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Pinch untuk zoom, tap untuk tutup',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Zoomable image
                                  Flexible(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: InteractiveViewer(
                                          panEnabled: true,
                                          scaleEnabled: true,
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child: GestureDetector(
                                            onTap:
                                                () => Navigator.of(ctx).pop(),
                                            child: CachedNetworkImage(
                                              imageUrl: ktpUrl,
                                              placeholder:
                                                  (context, url) => Container(
                                                    height: 200,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        CircularProgressIndicator(
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(
                                                                Colors
                                                                    .green
                                                                    .shade600,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        Text(
                                                          'Memuat gambar KTP...',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .green
                                                                    .shade600,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
                                                    height: 200,
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors.red.shade200,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Colors
                                                                    .red
                                                                    .shade100,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  50,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            color:
                                                                Colors
                                                                    .red
                                                                    .shade600,
                                                            size: 32,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        Text(
                                                          'Gagal memuat gambar KTP',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .red
                                                                    .shade700,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 20,
                                                              ),
                                                          child: Text(
                                                            'URL: $ktpUrl',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color:
                                                                  Colors
                                                                      .red
                                                                      .shade500,
                                                            ),
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey.shade600,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'URL KTP tidak tersedia',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ),

                  // Footer dengan action buttons
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                          label: const Text('Tutup'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green.shade600,
                            backgroundColor: Colors.green.shade50,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: BorderSide(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
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
    );
  }
  // --- Akhir fungsi baru ---

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
        child:
            photoUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  placeholder:
                      (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green[700],
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => _buildProfileFallback(size),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  fadeInDuration: const Duration(milliseconds: 300),
                )
                : _buildProfileFallback(size),
      ),
    );
  }

  Widget _buildProfileFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.green.withOpacity(0.1),
      child: Center(
        child: Text(
          'O',
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
      initialChildSize: 0.8,
      minChildSize: 0.6,
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
                          Icons.store,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user['role'],
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoCard(
                'Email',
                user['email'],
                Icons.email_outlined,
                null,
              ),
              _buildInfoCard(
                'Bank',
                user['bankName'],
                Icons.account_balance,
                null,
              ),
              _buildInfoCard(
                'No. Rekening',
                user['accountNumber'],
                Icons.credit_card,
                null,
              ),
              _buildInfoCard(
                'Nama Penerima',
                user['destinationName'],
                Icons.person_outline,
                null,
              ),
              _buildInfoCard(
                'Status',
                user['isActive'] ? 'Aktif' : 'Non-Aktif',
                Icons.toggle_on,
                user['isActive']
                    ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    )
                    : const Icon(Icons.cancel, color: Colors.red, size: 18),
              ),
              _buildInfoCard(
                'Disetujui',
                _getRelativeTime(user['approvedAt']),
                Icons.access_time,
                null,
              ),
              if (user['description'].isNotEmpty)
                _buildInfoCard(
                  'Deskripsi',
                  user['description'],
                  Icons.description_outlined,
                  null,
                ),
              if (user['ktpUrl'].isNotEmpty)
                _buildInfoCard(
                  'KTP',
                  'Lihat KTP',
                  Icons.badge_outlined,
                  GestureDetector(
                    onTap: () {
                      // Panggil fungsi untuk menampilkan KTP dalam modal
                      _showKtpImageModal(user['ktpUrl'], user['username']);
                    },
                    child: const Icon(
                      Icons.open_in_new,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                ),
              if (user['mapsUrl'].isNotEmpty)
                _buildInfoCard(
                  'Lokasi',
                  'Lihat Maps',
                  Icons.location_on_outlined,
                  GestureDetector(
                    onTap: () {
                      final LatLng? location = _parseGoogleMapsUrl(
                        user['mapsUrl'],
                      );
                      if (location != null) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => MapViewPage(
                                  ownerName: user['username'],
                                  location: location,
                                ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tidak dapat menemukan lokasi pada URL Maps.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Icon(
                      Icons.open_in_new,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    'Ubah ke User',
                    Icons.person_outline,
                    Colors.blue,
                    () {
                      Navigator.pop(context);
                      _confirmConvertToUser(user['id'], user['username'], user);
                    },
                  ),
                  const SizedBox(width: 15),
                  _buildActionButton(
                    'Hapus',
                    Icons.delete_outline,
                    Colors.red,
                    () {
                      Navigator.pop(context);
                      _confirmDeleteOwner(user['id'], user['username']);
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

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Widget? trailing,
  ) {
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
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
                    'Daftar Owner',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola semua owner dalam sistem',
                    style: TextStyle(fontSize: 15, color: Colors.green[600]),
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
                        hintText: 'Cari owner...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.green[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_filteredUsers.length} Owner',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                        onTap: _fetchOwners,
                        child: const Icon(Icons.refresh, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF2E8B57),
                        ),
                      )
                      : _filteredUsers.isEmpty
                      ? const Center(child: Text('Tidak ada owner ditemukan.'))
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
    final String firstLetter =
        user['username'].toString().isNotEmpty
            ? user['username'].toString()[0].toUpperCase()
            : 'O';

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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Hero(
              tag: 'user-avatar-${user['id']}',
              child:
                  user['photoUrl'].isNotEmpty
                      ? _buildProfileImage(user['photoUrl'], 48)
                      : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            firstLetter,
                            style: TextStyle(
                              color: Colors.orange[800],
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user['isActive'])
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
                      '${user['bankName']} - ${user['accountNumber']}',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user['isActive'] ? 'Aktif' : 'Non-Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            user['isActive']
                                ? Colors.green[600]
                                : Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
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
                } else if (value == 'convert') {
                  _confirmConvertToUser(user['id'], user['username'], user);
                } else if (value == 'delete') {
                  _confirmDeleteOwner(user['id'], user['username']);
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            color: Color(0xFF2E8B57),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text('Lihat Profil'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'convert',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Colors.blue,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Ubah ke User',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Hapus Owner',
                            style: TextStyle(color: Colors.red),
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
}
