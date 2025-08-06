import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class KelolahRoleRequestsPage extends StatefulWidget {
  const KelolahRoleRequestsPage({super.key});

  @override
  State<KelolahRoleRequestsPage> createState() => _KelolahRoleRequestsPageState();
}

class _KelolahRoleRequestsPageState extends State<KelolahRoleRequestsPage> {
  List<RoleRequest> roleRequests = [];
  bool isLoading = true;
  bool isNetworkEnabled = false;

  @override
  void initState() {
    super.initState();
    fetchRoleRequests();
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

  Future<void> fetchRoleRequests() async {
    try {
      setState(() {
        isLoading = true;
      });

      await _enableNetwork();

      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('role_requests').get();

      final List<RoleRequest> loadedRequests = snapshot.docs.map((doc) {
        final data = doc.data();
        return RoleRequest(
          id: doc.id,
          userId: data['userId'] ?? '',
          username: data['username'] ?? 'No Name',
          email: data['email'] ?? '',
          role: data['role'] ?? '',
          destinationName: data['destinationName'] ?? '',
          description: data['description'] ?? '',
          mapsUrl: data['mapsUrl'] ?? '',
          ktpUrl: data['ktpUrl'] ?? '',
          bankName: data['bankName'] ?? '',
          accountNumber: data['accountNumber'] ?? '',
          status: data['status'] ?? 'pending',
          timestamp: data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate().toString()
              : '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          roleRequests = loadedRequests;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching role requests: $e');
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
                      child: roleRequests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_alt_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tidak ada permintaan role',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: roleRequests.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                return _buildRoleRequestCard(
                                  roleRequests[index],
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
              'Kelola Role Requests',
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

  Widget _buildRoleRequestCard(RoleRequest request) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.destinationName,
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
              'Requested by: ${request.username}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.work_outline,
              'Role: ${request.role}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.account_balance,
              'Bank: ${request.bankName} - ${request.accountNumber}',
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
                  onTap: () => _showRoleRequestDetailModal(request),
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.delete,
                  label: 'Hapus',
                  color: Colors.red[700],
                  background: Colors.red.withOpacity(0.1),
                  onTap: () => _confirmRejectRoleRequest(context, request),
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
      case 'processed':
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
      case 'processed':
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

  Future<void> _confirmRejectRoleRequest(
    BuildContext context,
    RoleRequest request,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text(
          'Apakah Anda yakin ingin menolak dan menghapus permintaan role ini?',
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
      await _rejectRoleRequest(request);
    }
  }

  void _showRoleRequestDetailModal(RoleRequest request) {
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
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Detail Role Request",
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
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                    backgroundColor: Colors.green.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.person_add,
                                      color: Colors.green,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request.destinationName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Role: ${request.role}',
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
                                title: "Requested By",
                                value: request.username,
                              ),
                              _buildDetailItem(
                                icon: Icons.email,
                                title: "Email",
                                value: request.email,
                              ),
                              _buildDetailItem(
                                icon: Icons.work,
                                title: "Role",
                                value: request.role,
                              ),
                              _buildDetailItem(
                                icon: Icons.business,
                                title: "Destination Name",
                                value: request.destinationName,
                              ),
                              _buildDetailItem(
                                icon: Icons.description,
                                title: "Description",
                                value: request.description,
                              ),
                              _buildDetailItem(
                                icon: Icons.account_balance,
                                title: "Bank Name",
                                value: request.bankName,
                              ),
                              _buildDetailItem(
                                icon: Icons.credit_card,
                                title: "Account Number",
                                value: request.accountNumber,
                              ),
                              _buildDetailItem(
                                icon: Icons.map_outlined,
                                title: "Maps URL",
                                value: request.mapsUrl,
                              ),
                              _buildDetailItem(
                                icon: Icons.calendar_today,
                                title: "Submitted at",
                                value: request.timestamp,
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
                                    "KTP Image",
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
                              child: request.ktpUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: request.ktpUrl,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        height: 150,
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                size: 40,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Tidak dapat memuat gambar KTP",
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
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Tidak ada gambar KTP",
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
              // Hide buttons if already approved or rejected
            if (['pending', 'processed'].contains(request.status.toLowerCase()))
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
                            Navigator.pop(modalContext);
                            await _approveRoleRequest(request);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("Setujui Role"),
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
                            Navigator.pop(modalContext);
                            await _rejectRoleRequest(request);
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

  void _showSuccessSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
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

  Future<void> _approveRoleRequest(RoleRequest request) async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Memproses persetujuan...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _enableNetwork();
      final firestore = FirebaseFirestore.instance;

      // Create owner data
      final ownerData = {
        'userId': request.userId,
        'username': request.username,
        'email': request.email,
        'destinationName': request.destinationName,
        'description': request.description,
        'mapsUrl': request.mapsUrl,
        'ktpUrl': request.ktpUrl,
        'bankName': request.bankName,
        'accountNumber': request.accountNumber,
        'approvedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Execute all operations in a batch
      final batch = firestore.batch();

      // 1. Add to owners collection
      final ownerRef = firestore.collection('owners').doc();
      batch.set(ownerRef, ownerData);

      // 2. Update user role
      final userRef = firestore.collection('users').doc(request.userId);
      batch.update(userRef, {
        'role': 'owner',
        'roleApprovedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update request status
      final requestRef = firestore.collection('role_requests').doc(request.id);
      batch.update(requestRef, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      // 4. Send notification
      final notifRef = firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': request.userId,
        'title': 'Permintaan Owner Disetujui',
        'message': 'Selamat! Permintaan owner untuk "${request.destinationName}" telah disetujui.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'owner_approval',
      });

      await batch.commit();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      _showSuccessSnackbar(context, 'Permintaan owner berhasil disetujui');

      // Refresh the list
      fetchRoleRequests();
    } catch (e) {
      print('❌ Error approving role request: $e');
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error message
      _showErrorSnackbar(context, 'Gagal menyetujui permintaan: ${e.toString()}');
    }
  }

  Future<void> _rejectRoleRequest(RoleRequest request) async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Memproses penolakan...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _enableNetwork();
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Send notification
      final notifRef = firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': request.userId,
        'title': 'Permintaan Owner Ditolak',
        'message': 'Maaf, permintaan owner untuk "${request.destinationName}" telah ditolak.',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'owner_rejection',
      });

      // 2. Delete the request
      final requestRef = firestore.collection('role_requests').doc(request.id);
      batch.delete(requestRef);

      await batch.commit();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      _showSuccessSnackbar(context, 'Permintaan owner berhasil ditolak');

      // Refresh the list
      fetchRoleRequests();
    } catch (e) {
      print('❌ Error rejecting role request: $e');
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error message
      _showErrorSnackbar(context, 'Gagal menolak permintaan: ${e.toString()}');
    }
  }
}

class RoleRequest {
  final String id;
  final String userId;
  final String username;
  final String email;
  final String role;
  final String destinationName;
  final String description;
  final String mapsUrl;
  final String ktpUrl;
  final String bankName;
  final String accountNumber;
  final String status;
  final String timestamp;

  RoleRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.destinationName,
    required this.description,
    required this.mapsUrl,
    required this.ktpUrl,
    required this.bankName,
    required this.accountNumber,
    required this.status,
    required this.timestamp,
  });
}