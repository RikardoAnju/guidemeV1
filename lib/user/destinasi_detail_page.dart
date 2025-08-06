import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'payment_destinasiPage.dart';
import 'package:guide_me/Login.dart';

class DestinasiDetailPage extends StatefulWidget {
  final String destinasiId;
  const DestinasiDetailPage({super.key, required this.destinasiId});

  @override
  DestinasiDetailPageState createState() => DestinasiDetailPageState();
}

class DestinasiDetailPageState extends State<DestinasiDetailPage> {
  bool _showFullDescription = false;
  Map<String, dynamic>? destinasiData;
  bool isLoading = true;
  MapController mapController = MapController();

  // Rating variables
  double averageRating = 0.0;
  int totalRatings = 0;
  Map<int, int> ratingBreakdown = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  List<Map<String, dynamic>> reviews = [];
  TextEditingController commentController = TextEditingController();
  double userRating = 0.0;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    _loadDestinasiData();
  }

  Future<void> _loadDestinasiData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('destinasi')
          .doc(widget.destinasiId)
          .get();

      if (mounted) {
        setState(() {
          destinasiData = doc.exists ? doc.data() as Map<String, dynamic> : null;
          isLoading = false;
        });
        
        if (destinasiData != null) {
          await _loadAndCalculateRatings();
        }
      }
    } catch (e) {
      debugPrint('Error loading destinasi: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          destinasiData = null;
        });
      }
    }
  }

  Future<void> _loadAndCalculateRatings() async {
    try {
      QuerySnapshot ratingsSnapshot = await FirebaseFirestore.instance
          .collection('destinasi')
          .doc(widget.destinasiId)
          .collection('ratings')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> reviewList = [];
      Map<int, int> breakdown = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double totalScore = 0.0;
      int count = 0;

      for (var doc in ratingsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        int rating = data['rating'] ?? 0;
        
        // Calculate ratings
        if (rating >= 1 && rating <= 5) {
          breakdown[rating] = breakdown[rating]! + 1;
          totalScore += rating;
          count++;
        }
        
        // Get user info for reviews
        String userName = data['userName'] ?? 'Anonim';
        String? profileImageUrl;
        
        if (data['userId'] != null) {
          try {
            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['userId'])
                .get();
            
            if (userDoc.exists) {
              var userData = userDoc.data() as Map<String, dynamic>;
              profileImageUrl = userData['profileImageUrl'];
              userName = userData['name'] ?? userData['displayName'] ?? userName;
            }
          } catch (e) {
            debugPrint('Error fetching user data: $e');
          }
        }

        reviewList.add({
          'id': doc.id,
          'rating': rating,
          'comment': data['comment'] ?? '',
          'userName': userName,
          'profileImageUrl': profileImageUrl,
          'timestamp': data['timestamp'],
        });
      }

      double newAverageRating = count > 0 ? totalScore / count : 0.0;

      // Update main destinasi document with calculated values
      await FirebaseFirestore.instance
          .collection('destinasi')
          .doc(widget.destinasiId)
          .update({
        'rating': double.parse(newAverageRating.toStringAsFixed(1)),
        'ratingCount': count,
      });

      if (mounted) {
        setState(() {
          reviews = reviewList;
          ratingBreakdown = breakdown;
          averageRating = newAverageRating;
          totalRatings = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading ratings: $e');
    }
  }

  Future<void> _submitRating() async {
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    if (userRating == 0) {
      _showSnackBar('Silakan pilih rating terlebih dahulu');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('destinasi')
          .doc(widget.destinasiId)
          .collection('ratings')
          .add({
        'userId': currentUser!.uid,
        'userName': currentUser!.displayName ?? currentUser!.email ?? 'Anonim',
        'rating': userRating.toInt(),
        'comment': commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        userRating = 0.0;
        commentController.clear();
      });

      _showSnackBar('Rating berhasil ditambahkan!');
      await _loadAndCalculateRatings(); // Reload and recalculate everything
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      _showSnackBar('Error: Gagal menambahkan rating');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Diperlukan'),
        content: const Text('Anda harus login terlebih dahulu untuk memberikan rating dan ulasan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              ).then((_) => setState(() => currentUser = FirebaseAuth.instance.currentUser));
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (destinasiData == null) {
      return const Scaffold(body: Center(child: Text('Destinasi tidak ditemukan')));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDestinasiInfo(),
                _buildDescription(),
                _buildRatingSection(),
                _buildAddRatingSection(),
                _buildReviewsList(),
                _buildMapSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: destinasiData!['isFree'] == true
          ? null
          : FloatingActionButton.extended(
              onPressed: _handleBookingPress,
              label: const Text('Pesan Tiket', style: TextStyle(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.confirmation_number),
              backgroundColor: Colors.green,
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Image.network(
              destinasiData!['imageUrl'] ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: Icon(Icons.image, size: 50, color: Colors.grey[600]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destinasiData!['namaDestinasi'] ?? 'Nama Destinasi',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${destinasiData!['jamBuka']} - ${destinasiData!['jamTutup']}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinasiInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(Icons.location_on, destinasiData!['lokasi'] ?? 'Lokasi tidak tersedia'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.access_time, 'Buka: ${destinasiData!['jamBuka']} - ${destinasiData!['jamTutup']}'),
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
        Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600]))),
      ],
    );
  }

  String _getPriceText() {
    return destinasiData!['isFree'] == true
        ? 'Gratis'
        : '${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(destinasiData!['hargaTiket'] ?? 0)} /tiket';
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        destinasiData!['kategori'] ?? 'Destinasi Wisata',
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }

  Widget _buildDescription() {
    String description = destinasiData!['deskripsi'] ?? 'Tidak ada deskripsi tersedia';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deskripsi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            _showFullDescription || description.length <= 200
                ? description
                : '${description.substring(0, 200)}...',
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
            textAlign: TextAlign.justify,
          ),
          if (description.length > 200) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showFullDescription = !_showFullDescription),
              child: Text(
                _showFullDescription ? 'Lihat lebih sedikit' : 'Lihat selengkapnya',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rating dan Ulasan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStarRating(averageRating, size: 24),
                    const SizedBox(height: 4),
                    Text('$totalRatings ulasan', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            int stars = 5 - index;
            int count = ratingBreakdown[stars] ?? 0;
            double percentage = totalRatings > 0 ? count / totalRatings : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text('$stars', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 30, child: Text('$count', style: const TextStyle(fontSize: 12), textAlign: TextAlign.end)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAddRatingSection() {
    bool isLoggedIn = currentUser != null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLoggedIn ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLoggedIn ? 'Berikan Rating' : 'Login untuk Memberikan Rating',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Rating: '),
              ...List.generate(5, (index) => GestureDetector(
                onTap: isLoggedIn 
                    ? () => setState(() => userRating = index + 1.0)
                    : _showLoginRequiredDialog,
                child: Icon(
                  Icons.star,
                  size: 32,
                  color: index < userRating 
                      ? Colors.amber 
                      : (isLoggedIn ? Colors.grey[300] : Colors.grey[400]),
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            enabled: isLoggedIn,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isLoggedIn ? 'Tulis komentar Anda...' : 'Login untuk memberikan komentar',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              fillColor: isLoggedIn ? Colors.white : Colors.grey[200],
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoggedIn ? _submitRating : _showLoginRequiredDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLoggedIn ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: Text(isLoggedIn ? 'Kirim Rating' : 'Login untuk Rating'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Belum ada ulasan', style: TextStyle(color: Colors.grey))),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ulasan Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) => _buildReviewItem(reviews[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: review['profileImageUrl']?.toString().isNotEmpty == true
                    ? NetworkImage(review['profileImageUrl'])
                    : null,
                backgroundColor: Colors.blue,
                child: review['profileImageUrl']?.toString().isEmpty != false
                    ? Text(
                        review['userName'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['userName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      _formatTimestamp(review['timestamp']),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildStarRating(review['rating'].toDouble(), size: 16),
            ],
          ),
          if (review['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(review['comment'], style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: size,
      )),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('dd MMM yyyy').format(timestamp.toDate());
  }

  Widget _buildMapSection() {
    Map<String, double> coordinates = _getDestinasiCoordinates();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lokasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: LatLng(coordinates['latitude']!, coordinates['longitude']!),
                  initialZoom: 16.0,
                ),
                children: [
                  TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(coordinates['latitude']!, coordinates['longitude']!),
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.location_on, size: 30, color: Colors.white),
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

  Map<String, double> _getDestinasiCoordinates() {
    return {
      'latitude': double.tryParse(destinasiData!['latitude']?.toString() ?? '') ?? 1.1304,
      'longitude': double.tryParse(destinasiData!['longitude']?.toString() ?? '') ?? 104.0530,
    };
  }

  Future<void> _openMaps() async {
    try {
      String? mapsUrl = destinasiData!['urlMaps']?.toString();
      if (mapsUrl?.isNotEmpty == true) {
        await launchUrl(Uri.parse(mapsUrl!), mode: LaunchMode.externalApplication);
        return;
      }

      Map<String, double> coords = _getDestinasiCoordinates();
      await launchUrl(
        Uri.parse('geo:${coords['latitude']},${coords['longitude']}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _showSnackBar('Tidak dapat membuka aplikasi peta');
    }
  }

  void _handleBookingPress() {
    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showLoginRequiredDialog();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentDestinasiPage(
            destinasiId: widget.destinasiId,
            destinasiData: destinasiData!,
            userId: currentUser!.uid,
          ),
        ),
      );
    }
  }
}