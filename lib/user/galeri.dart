import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'destinasi_detail_page.dart';
import 'detail_event.dart';

class GaleriPage extends StatefulWidget {
  const GaleriPage({super.key});

  @override
  GaleriPageState createState() => GaleriPageState();
}

class GaleriPageState extends State<GaleriPage> {
  Stream<List<DocumentSnapshot>> getCombinedStream() {
    final destinasiStream = FirebaseFirestore.instance
        .collection('destinasi')
        .snapshots()
        .map((snapshot) => snapshot.docs);

    final eventsStream = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .map((snapshot) => snapshot.docs);

    return Rx.combineLatest2<List<DocumentSnapshot>, List<DocumentSnapshot>,
        List<DocumentSnapshot>>(
      destinasiStream,
      eventsStream,
      (destinasi, events) => [...destinasi, ...events],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Galeri',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<DocumentSnapshot>>(
                stream: getCombinedStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.place, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada Isi Galeri',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final combinedData = snapshot.data!.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['namaDestinasi'] ?? data['namaEvent'] ?? '';
                    return title.isNotEmpty && title != 'Tanpa Nama';
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: GridView.count(
                      physics: const AlwaysScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                      children: combinedData.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['namaDestinasi'] ?? data['namaEvent'] ?? '';
                        final imageUrl = data['imageUrl'] ?? '';
                        final location = data['lokasi'] ?? data['location'] ?? '';
                        final id = doc.id;
                        final path = doc.reference.path;
                        final collectionName = path.contains('destinasi') ? 'destinasi' : 'events';

                        return _buildDestinasiCard(title, imageUrl, location, id, collectionName);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
              )
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2E7D32),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Galeri',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildDestinasiCard(
    String title,
    String imageUrl,
    String location,
    String id,
    String collectionName,
  ) {
    return GestureDetector(
      onTap: () {
        if (collectionName == 'destinasi') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DestinasiDetailPage(destinasiId: id),
            ),
          );
        } else if (collectionName == 'events') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailPage(eventId: id),
            ),
          );
        }
      },
      child: Hero(
        tag: '$collectionName-$id',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: const Color(0xFF2E7D32),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => _buildImageError(),
                      )
                    : _buildImageError(),
                _buildGradientOverlay(),
                _buildTitleLocation(title, location),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('Gambar tidak dapat dimuat',
              style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleLocation(String title, String location) {
    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 12, color: Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location.isNotEmpty ? location : 'Lokasi tidak tersedia',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
