import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class KelolahAddEventPage extends StatefulWidget {
  const KelolahAddEventPage({super.key});

  @override
  State<KelolahAddEventPage> createState() => _KelolahAddEventPageState();
}

class _KelolahAddEventPageState extends State<KelolahAddEventPage> {
  List<EventRequest> eventRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEventRequests();
  }

  Future<void> _fetchEventRequests() async {
    try {
      setState(() => isLoading = true);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('event_requests')
          .get();

      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return EventRequest(
          id: doc.id,
          userId: data['userId'] ?? '',
          username: data['username'] ?? 'No Name',
          kategori: data['kategori'] ?? '',
          email: data['email'] ?? '',
          namaEvent: data['namaEvent'] ?? '',
          lokasi: data['lokasi'] ?? '',
          deskripsi: data['deskripsi'] ?? '',
          tanggalMulai: data['tanggalMulai'] ?? '',
          tanggalSelesai: data['tanggalSelesai'] ?? '',
          waktuMulai: data['waktuMulai'] ?? '',
          waktuSelesai: data['waktuSelesai'] ?? '',
          urlMaps: data['urlMaps'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          isFree: data['isFree'] ?? false,
          hargaTiket: data['hargaTiket'] ?? 0,
          status: data['status'] ?? 'pending',
          timestamp: data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate().toString()
              : '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          eventRequests = requests;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Method untuk membuat notifikasi
  Future<void> _sendNotification({
    required String userId,
    required String eventName,
    required String type, // 'approved' atau 'rejected'
  }) async {
    try {
      String title;
      String message;
      
      if (type == 'approved') {
        title = 'Event Disetujui!';
        message = 'Event "$eventName" Anda telah disetujui dan akan segera ditampilkan di aplikasi.';
      } else {
        title = 'Event Ditolak';
        message = 'Event "$eventName" Anda telah ditolak. Silakan hubungi admin untuk informasi lebih lanjut.';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'eventName': eventName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending notification: $e');
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
                : eventRequests.isEmpty
                    ? _buildEmptyState()
                    : _buildEventList(),
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
              'Kelola Event',
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
            Icon(Icons.event_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Tidak ada permintaan event',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: eventRequests.length,
          physics: BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildEventCard(eventRequests[index]),
        ),
      ),
    );
  }

  Widget _buildEventCard(EventRequest request) {
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
                    request.namaEvent,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(request.status),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow(Icons.person_outline, 'Submitted by: ${request.username}'),
            SizedBox(height: 8),
            _buildInfoRow(Icons.location_on_outlined, request.lokasi),
            SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today_outlined, '${request.tanggalMulai} - ${request.tanggalSelesai}'),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.attach_money,
              request.isFree ? 'Free Event' : 'Harga Tiket: Rp ${request.hargaTiket}',
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.visibility,
                  label: 'Lihat',
                  color: Colors.amber[700]!,
                  onTap: () => _showEventDetail(request),
                ),
                SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Hapus',
                  color: Colors.red[700]!,
                  onTap: () => _deleteEvent(request),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'pending' ? Colors.orange : 
                 status == 'approved' ? Colors.green : Colors.red;
    
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        status.toUpperCase(),
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
            maxLines: 1,
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

  void _showEventDetail(EventRequest request) {
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
                  Text("Detail Event", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                    SizedBox(height: 20),
                    _buildImageCard(request),
                  ],
                ),
              ),
            ),
            
            // Action buttons - Hanya tampil jika status bukan approved
            if (request.status != 'approved')
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -5))],
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveEvent(request),
                        icon: Icon(Icons.check),
                        label: Text("Setujui Event"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectEvent(request),
                        icon: Icon(Icons.close),
                        label: Text("Tolak"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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

  Widget _buildDetailCard(EventRequest request) {
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
                child: Icon(Icons.event, color: Colors.blue, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.namaEvent, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text(request.lokasi, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildDetailItem(Icons.person, "Submitted By", request.username),
          _buildDetailItem(Icons.category, "Category", request.kategori),
          _buildDetailItem(Icons.description, "Deskripsi", request.deskripsi),
          _buildDetailItem(Icons.date_range, "Tanggal", "${request.tanggalMulai} - ${request.tanggalSelesai}"),
          _buildDetailItem(Icons.access_time, "Waktu", "${request.waktuMulai} - ${request.waktuSelesai}"),
          _buildDetailItem(Icons.email, "Email", request.email),
          _buildDetailItem(Icons.attach_money, "Harga", request.isFree ? "Free Event" : "Rp ${request.hargaTiket}"),
          _buildDetailItem(Icons.map_outlined, "Maps URL", request.urlMaps),
          _buildDetailItem(Icons.info_outline, "Status", request.status.toUpperCase(), isLast: true),
        ],
      ),
    );
  }

  Widget _buildImageCard(EventRequest request) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.image, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text("Event Image", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Divider(height: 1),
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: request.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: request.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildImageError(),
                  )
                : _buildNoImage(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 150,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text("Tidak dapat memuat gambar", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImage() {
    return Container(
      height: 150,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text("Tidak ada gambar event", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
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

  Future<void> _approveEvent(EventRequest request) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update status di event_requests
      batch.update(
        FirebaseFirestore.instance.collection('event_requests').doc(request.id),
        {'status': 'approved'},
      );

      // Tambah ke koleksi events
      batch.set(
        FirebaseFirestore.instance.collection('events').doc(),
        {
          'namaEvent': request.namaEvent,
          'deskripsi': request.deskripsi,
          'tanggalMulai': request.tanggalMulai,
          'tanggalSelesai': request.tanggalSelesai,
          'waktuMulai': request.waktuMulai,
          'waktuSelesai': request.waktuSelesai,
          'urlMaps': request.urlMaps,
          'kategori': request.kategori,
          'lokasi': request.lokasi,
          'imageUrl': request.imageUrl,
          'isFree': request.isFree,
          'hargaTiket': request.hargaTiket,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': request.userId,
        },
      );

      await batch.commit();

      // Kirim notifikasi ke pengguna
      await _sendNotification(
        userId: request.userId,
        eventName: request.namaEvent,
        type: 'approved',
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event berhasil disetujui dan notifikasi telah dikirim'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchEventRequests();
    } catch (e) {
      print('Error approving event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyetujui event'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectEvent(EventRequest request) async {
    try {
      // Kirim notifikasi sebelum menghapus
      await _sendNotification(
        userId: request.userId,
        eventName: request.namaEvent,
        type: 'rejected',
      );

      await FirebaseFirestore.instance
          .collection('event_requests')
          .doc(request.id)
          .delete();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event berhasil ditolak dan notifikasi telah dikirim'),
          backgroundColor: Colors.orange,
        ),
      );
      _fetchEventRequests();
    } catch (e) {
      print('Error rejecting event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menolak event'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteEvent(EventRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Apakah Anda yakin ingin menghapus event ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Ya, Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _rejectEvent(request);
    }
  }
}

class EventRequest {
  final String id;
  final String userId;
  final String deskripsi;
  final String tanggalMulai;
  final String tanggalSelesai;
  final String waktuMulai;
  final String waktuSelesai;
  final String urlMaps;
  final String username;
  final String email;
  final String namaEvent;
  final String lokasi;
  final String kategori;
  final String imageUrl;
  final bool isFree;
  final num hargaTiket;
  final String status;
  final String timestamp;

  EventRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.kategori,
    required this.email,
    required this.deskripsi,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.urlMaps,
    required this.namaEvent,
    required this.lokasi,
    required this.imageUrl,
    required this.isFree,
    required this.hargaTiket,
    required this.status,
    required this.timestamp,
  });
}