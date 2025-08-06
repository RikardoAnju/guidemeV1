import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KelolahFeedbackPage extends StatefulWidget {
  const KelolahFeedbackPage({super.key});

  @override
  State<KelolahFeedbackPage> createState() => _KelolahFeedbackPageState();
}

class _KelolahFeedbackPageState extends State<KelolahFeedbackPage> {
  List<FeedbackRequest> feedbackRequests = [];
  bool isLoading = true;
  late BuildContext _context;

  @override
  void initState() {
    super.initState();
    _fetchFeedbackRequests();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _context = context;
  }

  Future<void> _fetchFeedbackRequests() async {
    try {
      if (mounted) setState(() => isLoading = true);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('createdAt', descending: true)
          .get();

      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return FeedbackRequest(
          id: doc.id,
          userId: data['userId'] ?? '',
          username: data['username'] ?? 'No Name',
          email: data['email'] ?? '',
          category: data['category'] ?? '',
          message: data['message'] ?? '',
          deviceInfo: data['deviceInfo'] ?? {},
          status: data['status'] ?? 'processing',
          adminReply: data['adminReply'] ?? '',
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate().toString()
              : '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          feedbackRequests = requests;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching feedback: $e');
      if (mounted) setState(() => isLoading = false);
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
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : feedbackRequests.isEmpty
                    ? _buildEmptyState()
                    : _buildFeedbackList(),
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              'Kelola Feedback',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
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
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Tidak ada feedback',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackList() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: feedbackRequests.length,
          physics: BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildFeedbackCard(feedbackRequests[index]),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(FeedbackRequest request) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.category,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(request.status),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow(Icons.person_outline, 'From: ${request.username}'),
            SizedBox(height: 8),
            _buildInfoRow(Icons.email_outlined, request.email),
            SizedBox(height: 8),
            _buildInfoRow(Icons.message_outlined, request.message),
            SizedBox(height: 8),
            _buildInfoRow(Icons.devices_outlined, 'Platform: ${_getPlatformName(request.deviceInfo)}'),
            
            // Show admin reply if exists
            if (request.adminReply.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balasan Admin:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      request.adminReply,
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.visibility,
                  label: 'Lihat',
                  color: Colors.amber[700]!,
                  onTap: () => _showFeedbackDetail(request),
                ),
                SizedBox(width: 12),
                if (request.status != 'resolved' && request.adminReply.isEmpty) ...[
                  _buildActionButton(
                    icon: Icons.message,
                    label: 'Kirim Pesan',
                    color: Colors.blue[700]!,
                    onTap: () => _sendMessage(request),
                  ),
                  SizedBox(width: 12),
                ],
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Hapus',
                  color: Colors.red[700]!,
                  onTap: () => _deleteFeedback(request),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformName(Map<String, dynamic> deviceInfo) {
    if (deviceInfo.isEmpty) return 'Unknown';
    String platform = deviceInfo['platform'] ?? 'Unknown';
    if (platform.contains('windows')) return 'Windows';
    if (platform.contains('android')) return 'Android';
    if (platform.contains('ios')) return 'iOS';
    return platform;
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'processing' ? Colors.orange : 
                 status == 'resolved' ? Colors.green : 
                 status == 'responded' ? Colors.blue : Colors.grey;
    
    String displayText = status == 'processing' ? 'PROSES' :
                        status == 'resolved' ? 'SELESAI' :
                        status == 'responded' ? 'DIBALAS' : status.toUpperCase();
    
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        displayText,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDetail(FeedbackRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12),
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Detail Feedback", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Divider(height: 24),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailCard(request),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -5))],
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  if (request.status != 'resolved' && request.adminReply.isEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendMessage(request);
                        },
                        icon: Icon(Icons.message),
                        label: Text("Kirim Pesan"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsResolved(request),
                      icon: Icon(Icons.check),
                      label: Text("Tandai Selesai"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(FeedbackRequest request) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Icon(Icons.feedback, color: Colors.blue, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text(request.username, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildDetailItem(Icons.person, "Username", request.username),
          _buildDetailItem(Icons.email, "Email", request.email),
          _buildDetailItem(Icons.category, "Category", request.category),
          _buildDetailItem(Icons.message, "Message", request.message),
          _buildDetailItem(Icons.devices, "Platform", _getPlatformName(request.deviceInfo)),
          _buildDetailItem(Icons.access_time, "Created At", _formatDate(request.createdAt)),
          _buildDetailItem(Icons.info_outline, "Status", request.status.toUpperCase()),
          
          // Show admin reply in detail
          if (request.adminReply.isNotEmpty) ...[
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Text(
              'Balasan Admin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[700]),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                request.adminReply,
                style: TextStyle(fontSize: 15, color: Colors.grey[800]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                SizedBox(height: 2),
                Text(value.isNotEmpty ? value : "-", style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return "-";
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  void _sendMessage(FeedbackRequest request) {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: _context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Kirim Pesan ke ${request.username}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Feedback: ${request.category}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Pesan Admin',
                hintText: 'Tulis pesan balasan untuk user...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.trim().isNotEmpty) {
                await _sendAdminMessage(request, messageController.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAdminMessage(FeedbackRequest request, String message) async {
    try {
      // Update feedback dengan balasan admin
      await FirebaseFirestore.instance
          .collection('feedback')
          .doc(request.id)
          .update({
            'adminReply': message,
            'status': 'responded',
            'respondedAt': FieldValue.serverTimestamp(),
          });

      // Kirim notifikasi ke user dengan koleksi notifications_feedback
      await FirebaseFirestore.instance.collection('notifications_feedback').add({
        'userId': request.userId,
        'title': 'Balasan Admin - ${request.category}',
        'message': 'Admin telah membalas feedback Anda: $message',
        'type': 'admin_reply',
        'feedbackId': request.id,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'feedbackCategory': request.category,
          'adminReply': message,
          'originalFeedback': request.message,
          'adminReplyAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
            content: Text('Pesan berhasil dikirim ke ${request.username}'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchFeedbackRequests();
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pesan'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAsResolved(FeedbackRequest request) async {
    try {
      await FirebaseFirestore.instance
          .collection('feedback')
          .doc(request.id)
          .update({
            'status': 'resolved',
            'resolvedAt': FieldValue.serverTimestamp(),
          });

      // Kirim notifikasi resolved ke user dengan koleksi notifications_feedback
      await FirebaseFirestore.instance.collection('notifications_feedback').add({
        'userId': request.userId,
        'title': 'Feedback Diselesaikan - ${request.category}',
        'message': 'Feedback Anda telah diselesaikan oleh admin.',
        'type': 'feedback_resolved',
        'feedbackId': request.id,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'feedbackCategory': request.category,
          'resolvedAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        Navigator.pop(_context);
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
            content: Text('Feedback berhasil ditandai sebagai selesai'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchFeedbackRequests();
      }
    } catch (e) {
      print('Error marking as resolved: $e');
      if (mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(content: Text('Gagal menandai sebagai selesai'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFeedback(FeedbackRequest request) async {
    final confirm = await showDialog<bool>(
      context: _context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Apakah Anda yakin ingin menghapus feedback ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Ya, Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('feedback')
            .doc(request.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(
              content: Text('Feedback berhasil dihapus'),
              backgroundColor: Colors.orange,
            ),
          );
          _fetchFeedbackRequests();
        }
      } catch (e) {
        print('Error deleting feedback: $e');
        if (mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus feedback'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class FeedbackRequest {
  final String id;
  final String userId;
  final String username;
  final String email;
  final String category;
  final String message;
  final Map<String, dynamic> deviceInfo;
  final String status;
  final String adminReply;
  final String createdAt;

  FeedbackRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.category,
    required this.message,
    required this.deviceInfo,
    required this.status,
    required this.adminReply,
    required this.createdAt,
  });
}