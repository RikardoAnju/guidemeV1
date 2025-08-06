import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class KelolahRekomendasiDestinasiPage extends StatefulWidget {
  const KelolahRekomendasiDestinasiPage({super.key});

  @override
  State<KelolahRekomendasiDestinasiPage> createState() => _KelolahRekomendasiDestinasiPageState();
}

class _KelolahRekomendasiDestinasiPageState extends State<KelolahRekomendasiDestinasiPage> {
  List<DestinasiRequest> destinasiRequests = [];
  bool isLoading = true;

  bool isNetworkEnabled = false;

  @override
  void initState() {
    super.initState();
    fetchDestinationRequests();
  }

  Future<void> _enableNetwork() async {
    if (!isNetworkEnabled) {
      try {
        await FirebaseFirestore.instance.enableNetwork();
        isNetworkEnabled = true;
      } catch (e) {
        print('Failed to enable network: $e');
      }
    }
  }

  Future<void> fetchDestinationRequests() async {
    try {
      setState(() {
        isLoading = true;
      });

      await _enableNetwork();

      // Use a single instance of FirebaseFirestore to avoid target ID conflicts
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('destinasi_requests').get();

      final List<DestinasiRequest> loadedRequests =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return DestinasiRequest(
              id: doc.id,
              userId: data['userId'] ?? '',
              username: data['username'] ?? 'No Name',
              kategori: data['kategori'] ?? '',
              email: data['email'] ?? '',
              namaDestinasi: data['namaDestinasi'] ?? '',
              lokasi: data['lokasi'] ?? '',
              deskripsi: data['deskripsi'] ?? '',
              jamBuka: data['jamBuka'] ?? '',
              jamTutup: data['jamTutup'] ?? '',
              urlMaps: data['urlMaps'] ?? '',
              imageUrl: data['imageUrl'] ?? '',
              isFree: data['isFree'] ?? false,
              hargaTiket: data['hargaTiket'] ?? 0,
              status: data['status'] ?? 'pending',
              timestamp:
                  data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate().toString()
                      : '',
            );
          }).toList();

      if (mounted) {
        setState(() {
          destinasiRequests = loadedRequests;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching destination requests: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            isLoading
                ? const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
                : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:
                        destinasiRequests.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tidak ada permintaan destinasi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              itemCount: destinasiRequests.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                return _buildDestinationCard(
                                  destinasiRequests[index],
                                );
                              },
                            ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              'Kelola Rekomendasi',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Colors.black.withOpacity(0.8),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 15,
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(DestinasiRequest request) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.namaDestinasi,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    _getStatusText(request.status),
                    style: TextStyle(
                      color: _getStatusColor(request.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.person_outline,
              'Submitted by: ${request.username}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on_outlined, request.lokasi),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.attach_money,
              request.isFree
                  ? 'Free Entry'
                  : 'Harga Tiket: Rp ${request.hargaTiket}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Created: ${request.timestamp}',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionButton(
                  icon: Icons.visibility,
                  label: 'Lihat',
                  color: Colors.amber[700],
                  background: Colors.amber.withOpacity(0.1),
                  onTap: () => _showDestinationDetailModal(request),
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.delete,
                  label: 'Hapus',
                  color: Colors.red[700],
                  background: Colors.red.withOpacity(0.1),
                  onTap: () => _confirmRejectDestination(context, request),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'already_processed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'already_processed':
        return 'Processed';
      default:
        return status;
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color? color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Add confirmation dialog to avoid accidental deletion
  Future<void> _confirmRejectDestination(
    BuildContext context,
    DestinasiRequest request,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: const Text(
              'Apakah Anda yakin ingin menolak dan menghapus rekomendasi destinasi ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Ya, Tolak',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _rejectDestination(request);
    }
  }

  void _showDestinationDetailModal(DestinasiRequest request) {
    final scaffoldContext = context;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalContext).size.height * 0.85,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Detail Destinasi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Content - Scrollable
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Destination basic info Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.green.withOpacity(
                                      0.1,
                                    ),
                                    child: const Icon(
                                      Icons.place,
                                      color: Colors.green,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request.namaDestinasi,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          request.lokasi,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDetailItem(
                                icon: Icons.person,
                                title: "Submitted By",
                                value: request.username,
                              ),
                              _buildDetailItem(
                                icon: Icons.category,
                                title: "Category",
                                value: request.kategori,
                              ),
                              _buildDetailItem(
                                icon: Icons.description,
                                title: "Deskripsi",
                                value: request.deskripsi,
                              ),
                              _buildDetailItem(
                                icon: Icons.schedule_outlined,
                                title: "Jam Buka",
                                value: request.jamBuka,
                              ),
                              _buildDetailItem(
                                icon: Icons.schedule_outlined,
                                title: "Jam Tutup",
                                value: request.jamTutup,
                              ),
                              _buildDetailItem(
                                icon: Icons.email,
                                title: "Email",
                                value: request.email,
                              ),
                              _buildDetailItem(
                                icon: Icons.attach_money,
                                title: "Ticket Price",
                                value:
                                    request.isFree
                                        ? "Free Entry"
                                        : "Rp ${request.hargaTiket}",
                              ),
                              _buildDetailItem(
                                icon: Icons.calendar_today,
                                title: "Submitted at",
                                value: request.timestamp,
                              ),
                              _buildDetailItem(
                                icon: Icons.map_outlined,
                                title: "Maps Url",
                                value: request.urlMaps,
                              ),
                              _buildDetailItem(
                                icon: Icons.info_outline,
                                title: "Status",
                                value: _getStatusText(request.status),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Destination Image Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.image, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Destination Image",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              child:
                                  request.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: request.imageUrl,
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(20.0),
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              height: 150,
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.broken_image,
                                                      size: 40,
                                                      color: Colors.grey[400],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      "Tidak dapat memuat gambar",
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      )
                                      : Container(
                                        height: 150,
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported,
                                                size: 40,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Tidak ada gambar destinasi",
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
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

              // Action buttons - Hanya tampil jika status bukan approved atau rejected
              if (request.status.toLowerCase() != 'approved' && 
                  request.status.toLowerCase() != 'rejected')
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _approveDestination(request);
                              Navigator.pop(modalContext);
                            } catch (e) {
                              Navigator.pop(modalContext);
                              _showErrorSnackbar(
                                scaffoldContext,
                                'Gagal menyetujui rekomendasi: $e',
                              );
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("Setujui Destinasi"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _rejectDestination(request);
                              Navigator.pop(modalContext);
                            } catch (e) {
                              Navigator.pop(modalContext);
                              _showErrorSnackbar(
                                scaffoldContext,
                                'Gagal menolak rekomendasi: $e',
                              );
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text("Tolak"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : "-",
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveDestination(DestinasiRequest request) async {
    if (!mounted) return;

    try {
      await _enableNetwork();

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Update request status
      batch.update(firestore.collection('destinasi_requests').doc(request.id), {
        'status': 'approved',
      });

      // 2. Add to destinasi collection
      batch.set(firestore.collection('destinasi').doc(), {
        'namaDestinasi': request.namaDestinasi,
        'deskripsi': request.deskripsi,
        'jamBuka': request.jamBuka,
        'jamTutup': request.jamTutup,
        'urlMaps': request.urlMaps,
        'kategori': request.kategori,
        'lokasi': request.lokasi,
        'imageUrl': request.imageUrl,
        'isFree': request.isFree,
        'hargaTiket': request.hargaTiket,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': request.userId,
        'rating': 0,
        'ratingCount': 0,
      });

      // 3. Send notification
      batch.set(firestore.collection('notifications').doc(), {
        'userId': request.userId,
        'title': 'Rekomendasi Destinasi Disetujui',
        'message':
            'Rekomendasi destinasi "${request.namaDestinasi}" Anda telah disetujui.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'destination_approval',
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rekomendasi destinasi berhasil disetujui'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        fetchDestinationRequests();
      }
    } catch (e) {
      print('❌ Error approving destination: $e');
      if (mounted) {
        _showErrorSnackbar(context, 'Gagal menyetujui rekomendasi destinasi');
      }
      rethrow;
    }
  }

  Future<void> _rejectDestination(DestinasiRequest request) async {
    if (!mounted) return;

    try {
      await _enableNetwork();

      // Use a WriteBatch for atomicity
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Send notification about rejection
      if (request.userId.isNotEmpty) {
        final notifRef = firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': request.userId,
          'title': 'Rekomendasi Destinasi Ditolak',
          'message':
              'Maaf, rekomendasi destinasi "${request.namaDestinasi}" Anda telah ditolak.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'destination_rejection',
        });
      }

      // 2. Update status to rejected instead of deleting
      batch.update(firestore.collection('destinasi_requests').doc(request.id), {
        'status': 'rejected',
      });

      // Commit the batch
      await batch.commit();

      // Show success message and refresh the destination requests list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rekomendasi destinasi berhasil ditolak'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );

        fetchDestinationRequests();
      }
    } catch (e) {
      print('❌ Error rejecting destination: $e');
      if (mounted) {
        _showErrorSnackbar(context, 'Gagal menolak rekomendasi destinasi');
      }
      rethrow; // Rethrow to handle in the caller
    }
  }
}

class DestinasiRequest {
  final String id;
  final String userId;
  final String deskripsi;
  final String jamBuka;
  final String jamTutup;
  final String urlMaps;
  final String username;
  final String email;
  final String namaDestinasi;
  final String lokasi;
  final String kategori;
  final String imageUrl;
  final bool isFree;
  final num hargaTiket;
  final String status;
  final String timestamp;

  DestinasiRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.kategori,
    required this.email,
    required this.deskripsi,
    required this.jamBuka,
    required this.jamTutup,
    required this.urlMaps,
    required this.namaDestinasi,
    required this.lokasi,
    required this.imageUrl,
    required this.isFree,
    required this.hargaTiket,
    required this.status,
    required this.timestamp,
  });
}
