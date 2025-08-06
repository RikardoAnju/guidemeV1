import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:guide_me/Login.dart';
import 'payment_eventPage.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  EventDetailPageState createState() => EventDetailPageState();
}

class EventDetailPageState extends State<EventDetailPage> {
  bool _isFavorite = false;
  bool _showFullDescription = false;
  Map<String, dynamic>? eventData;
  bool isLoading = true;
  MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  Future<void> _loadEventData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      setState(() {
        eventData = doc.exists ? doc.data() as Map<String, dynamic> : null;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading event: $e');
      setState(() {
        isLoading = false;
        eventData = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventData == null) {
      return const Scaffold(body: Center(child: Text('Event not found')));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventInfo(),
          
                _buildDescription(),
                _buildMapSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      // Hanya tampilkan tombol pemesanan jika event TIDAK gratis
      floatingActionButton: eventData!['isFree'] == true 
          ? null 
          : FloatingActionButton.extended(
              onPressed: _handleBookingPress,
              label: const Text(
                'Pesan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.bookmark),
              backgroundColor: Colors.green,
            ),
    );
  }

  void _handleBookingPress() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      _showLoginRequiredDialog();
    } else {
      _navigateToPayment(currentUser.uid);
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Diperlukan'),
          content: const Text('Anda tidak bisa melakukan pemesanan, anda harus login terlebih dahulu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin();
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToLogin() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => LoginScreen()),
  );
}

  void _navigateToPayment(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          eventId: widget.eventId,
          eventData: eventData!,
          
          userId: userId, 
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: _buildCircularButton(
        Icons.arrow_back,
        () => Navigator.pop(context),
      ),
      actions: [
        _buildCircularButton(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          () => setState(() => _isFavorite = !_isFavorite),
          color: _isFavorite ? Colors.red : Colors.black,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            _buildEventImage(),
            _buildGradientOverlay(),
            _buildEventTitle(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton(IconData icon, VoidCallback onPressed,
      {Color color = Colors.black}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: IconButton(icon: Icon(icon, color: color), onPressed: onPressed),
    );
  }

  Widget _buildEventImage() {
    return Image.network(
      eventData!['imageUrl'] ?? '',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[300],
        child: Icon(Icons.image, size: 50, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
    );
  }

  Widget _buildEventTitle() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eventData!['namaEvent'] ?? 'Event Name',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${eventData!['tanggalMulai']} - ${eventData!['tanggalSelesai']}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            Icons.location_on,
            eventData!['lokasi'] ?? 'Location not specified',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.access_time,
            '${eventData!['waktuMulai']} - ${eventData!['waktuSelesai']}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.attach_money, _getPriceText()),
          const SizedBox(height: 16),
          _buildCategoryChip(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  String _getPriceText() {
    return eventData!['isFree'] == true
        ? 'Gratis'
        : '${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(eventData!['hargaTiket'] ?? 0)} /tiket';
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Text(
        eventData!['kategori'] ?? 'Event',
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  

 

  Widget _buildDescription() {
    String description = eventData!['deskripsi'] ?? 'No description available';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _showFullDescription
                ? description
                : description.length > 200
                    ? '${description.substring(0, 200)}...'
                    : description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey,
            ),
            textAlign: TextAlign.justify,
          ),
          if (description.length > 200) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(
                () => _showFullDescription = !_showFullDescription,
              ),
              child: Text(
                _showFullDescription ? 'Lihat lebih sedikit' : 'Lihat selengkapnya',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    Map<String, double> coordinates = _getEventCoordinates();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lokasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    coordinates['latitude']!,
                    coordinates['longitude']!,
                  ),
                  initialZoom: 16.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          coordinates['latitude']!,
                          coordinates['longitude']!,
                        ),
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _openMaps,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Buka di Google Maps'),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _getEventCoordinates() {
    if (eventData!['latitude'] != null && eventData!['longitude'] != null) {
      return {
        'latitude': double.tryParse(eventData!['latitude'].toString()) ?? 1.1304,
        'longitude': double.tryParse(eventData!['longitude'].toString()) ?? 104.0530,
      };
    }
    return {'latitude': 1.1304, 'longitude': 104.0530};
  }

  Future<void> _openMaps() async {
    try {
      String? mapsUrl = eventData!['urlMaps']?.toString();
      if (mapsUrl != null && mapsUrl.isNotEmpty) {
        await launchUrl(
          Uri.parse(mapsUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      Map<String, double> coords = _getEventCoordinates();
      final Uri fallbackUri = Uri.parse(
        'geo:${coords['latitude']},${coords['longitude']}',
      );
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showErrorDialog('Tidak dapat membuka aplikasi peta');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


}