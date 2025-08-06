import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapViewPage extends StatefulWidget {
  final String ownerName;
  final LatLng location;

  const MapViewPage({
    super.key,
    required this.ownerName,
    required this.location,
  });

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _recenterMap() {
    _mapController.move(widget.location, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove default AppBar to create custom header
      body: Stack(
        children: [
          // Map Widget
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.location,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Base Map Layer with place names (using Google-style tiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.guideme',
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('Tile loading error: $error');
                },
                tileDisplay: const TileDisplay.fadeIn(),
                maxZoom: 18,
              ),
              
              // Alternative: Use Google-style tiles (requires API key in production)
              // TileLayer(
              //   urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              //   userAgentPackageName: 'com.example.guideme',
              //   maxZoom: 20,
              // ),

              // Marker Layer
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.location,
                    width: 80.0,
                    height: 80.0,
                    alignment: Alignment.topCenter,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                  ),
                ],
              ),

              // Attribution Layer
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ),

          // Custom Header with Back Button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Custom Back Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  Expanded(
                    child: Text(
                      'Lokasi ${widget.ownerName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Refresh Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.black87,
                        size: 20,
                      ),
                      onPressed: _recenterMap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Location Info Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E8B57).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF2E8B57),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.ownerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${widget.location.latitude.toStringAsFixed(6)}, '
                          'Lng: ${widget.location.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Directions Button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E8B57),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.directions,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        _openDirections();
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            right: 16,
            bottom: 120,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.my_location,
                  color: Color(0xFF2E8B57),
                  size: 24,
                ),
                onPressed: _recenterMap,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDirections() async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${widget.location.latitude},${widget.location.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Alternative version with Google Maps style tiles (if you have API access)
class GoogleStyleMapViewPage extends StatefulWidget {
  final String ownerName;
  final LatLng location;

  const GoogleStyleMapViewPage({
    super.key,
    required this.ownerName,
    required this.location,
  });

  @override
  State<GoogleStyleMapViewPage> createState() => _GoogleStyleMapViewPageState();
}

class _GoogleStyleMapViewPageState extends State<GoogleStyleMapViewPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _recenterMap() {
    _mapController.move(widget.location, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.location,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 20.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Google Maps style tiles (shows place names and roads clearly)
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.guideme',
                maxZoom: 20,
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('Google tile loading error: $error');
                },
              ),
              
              // Marker Layer
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.location,
                    width: 80.0,
                    height: 80.0,
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 32.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Custom Header (same as above)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Lokasi ${widget.ownerName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}