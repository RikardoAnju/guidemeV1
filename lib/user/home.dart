import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guide_me/user/galeri.dart';
import 'package:guide_me/user/notifikasiUser.dart';
import 'diskusiPage.dart';
import 'package:guide_me/Login.dart';
import 'daftar_destinasi.dart';
import 'requestRole.dart';
import 'tambah_destinasi.dart';
import 'daftar_event.dart';
import 'Profile.dart';
import 'destinasi_detail_page.dart';
import 'add_event.dart';

import 'package:badges/badges.dart' as badges;
import 'detail_event.dart';
import 'tiket.dart';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEEEEEE),
        canvasColor: const Color(0xFFEEEEEE),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: const HomePage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfileScreen(),
        // Add other routes as needed
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const Color grayColor = Color(0xFFEEEEEE);
  static const Color primaryColor = Color(0xFF5ABB4D);

  late AnimationController _animationController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? userRole;
  bool _isLoggedIn = FirebaseAuth.instance.currentUser != null;
  String? _userName;
  int _currentCarouselIndex = 0;
  String _selectedDestinationCategory = 'All';
  String _selectedEventCategory = 'All';
  String _searchQuery = '';
  Timer? _timer;
  Map<String, int> userCounts = {};
  int touchedIndex = -1;
  int _selectedNavIndex = 0;
  int _notificationCount = 0;

  List<Map<String, dynamic>> _carouselItems = [];
  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _events = [];
  bool _isLoadingDestinations = true;
  bool _isLoadingEvents = true;

  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  final List<Map<String, dynamic>> _destinationCategories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded},
    {'name': 'Wisata Alam', 'icon': Icons.nature_people_rounded},
    {'name': 'Wisata Budaya', 'icon': Icons.museum_rounded},
    {'name': 'Wisata Religi', 'icon': Icons.mosque_rounded},
    {'name': 'Wisata Kuliner', 'icon': Icons.restaurant_rounded},
    {'name': 'Wisata Sejarah', 'icon': Icons.account_balance_rounded},
    {'name': 'Wisata Edukasi', 'icon': Icons.school_rounded},
    {'name': 'Wisata Petualangan', 'icon': Icons.hiking_rounded},
    {'name': 'Taman Hiburan', 'icon': Icons.celebration_rounded},
    {'name': 'Pantai', 'icon': Icons.beach_access},
    {'name': 'Gunung', 'icon': Icons.terrain_rounded},
    {'name': 'Air Terjun', 'icon': Icons.water_drop_rounded},
    {'name': 'Museum', 'icon': Icons.museum_outlined},
  ];

  final List<Map<String, dynamic>> _eventCategories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded},
    {'name': 'Konser', 'icon': Icons.music_note_rounded},
    {'name': 'Festival', 'icon': Icons.celebration_rounded},
    {'name': 'Pameran', 'icon': Icons.art_track_rounded},
    {'name': 'Seminar', 'icon': Icons.record_voice_over_rounded},
    {'name': 'Workshop', 'icon': Icons.handyman_rounded},
    {'name': 'Olahraga', 'icon': Icons.sports_soccer_rounded},
    {'name': 'Kuliner', 'icon': Icons.restaurant_rounded},
    {'name': 'Budaya', 'icon': Icons.museum_rounded},
    {'name': 'Edukasi', 'icon': Icons.school_rounded},
    {'name': 'Teknologi', 'icon': Icons.devices_rounded},
    {'name': 'Bisnis', 'icon': Icons.business_center_rounded},
  ];

  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _initializeData();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _fetchNotificationCount();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _showSearchResults = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;
      _updateSearchResults();
    });
  }

  void _onSearchFocusChanged() {
    setState(() {
      _showSearchResults = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;
      if (!_searchFocusNode.hasFocus && _searchQuery.isEmpty) {
        _searchResults.clear();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchResults = false;
      _searchResults.clear();
      _searchQuery = '';
    });
  }

  Future<void> _fetchNotificationCount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fungsi untuk menghitung total notifikasi
      Future<int> getTotalNotificationCount() async {
        final snapshot1 = await FirebaseFirestore.instance
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .get();

        final snapshot2 = await FirebaseFirestore.instance
            .collection('notifications_feedback')
            .where('isRead', isEqualTo: false)
            .get();

        return snapshot1.docs.length + snapshot2.docs.length;
      }

      // Hitung initial count
      int initialCount = await getTotalNotificationCount();
      if (mounted) {
        setState(() {
          _notificationCount = initialCount;
        });
      }

      // Listen untuk perubahan di collection 'notifications'
      FirebaseFirestore.instance
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot1) async {
        if (mounted) {
          // Hitung ulang total dari kedua collection
          int totalCount = await getTotalNotificationCount();
          setState(() {
            _notificationCount = totalCount;
          });
        }
      });

      FirebaseFirestore.instance
          .collection('notifications_feedback')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot2) async {
        if (mounted) {
          int totalCount = await getTotalNotificationCount();
          setState(() {
            _notificationCount = totalCount;
          });
        }
      });
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  void _handleSearchResultTap(Map<String, dynamic> item) {
    print('=== DEBUG SEARCH TAP ===');
    print('Full item data: $item');

    final String? id = item['id'] as String?;
    final String? type = item['type'] as String?;

    // Validasi yang lebih ketat
    if (id == null || id.isEmpty || id.trim().isEmpty) {
      _showErrorSnackBar('ID item tidak valid atau kosong');
      print('ERROR: ID is null or empty - $id');
      return;
    }

    if (type == null || type.isEmpty) {
      _showErrorSnackBar('Tipe item tidak dikenali');
      print('ERROR: Type is null or empty - $type');
      return;
    }

    // Clear search state
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchResults = false;
      _searchResults.clear();
      _searchQuery = '';
    });

    // Navigasi dengan error handling yang lebih baik
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        if (type.toLowerCase() == 'destination') {
          print('Navigating to DestinasiDetailPage with ID: $id');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DestinasiDetailPage(destinasiId: id),
            ),
          ).catchError((error) {
            print('Navigation error to DestinasiDetailPage: $error');
            _showErrorSnackBar('Gagal membuka halaman destinasi');
          });
        } else if (type.toLowerCase() == 'event') {
          print('Navigating to EventDetailPage with ID: $id');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailPage(eventId: id),
            ),
          ).catchError((error) {
            print('Navigation error to EventDetailPage: $error');
            _showErrorSnackBar('Gagal membuka halaman event');
          });
        } else {
          _showErrorSnackBar('Tipe item tidak dikenali: $type');
          print('ERROR: Unknown type - $type');
        }
      } catch (e) {
        print('ERROR during navigation: $e');
        _showErrorSnackBar('Gagal membuka halaman detail: $e');
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _updateSearchResults() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults.clear();
        _showSearchResults = false;
      });
      return;
    }

    List<Map<String, dynamic>> tempResults = [];

    // Proses destinasi dengan validasi yang lebih ketat
    for (var dest in _destinations) {
      try {
        // Validasi field wajib
        if (dest['id'] == null ||
            dest['namaDestinasi'] == null ||
            dest['namaDestinasi'].toString().trim().isEmpty) {
          print('Skipping destination with invalid data: $dest');
          continue;
        }

        final String id = dest['id'].toString().trim();
        final String name = dest['namaDestinasi'].toString().toLowerCase();
        final String category =
            (dest['kategori'] ?? '').toString().toLowerCase();
        final String location = (dest['lokasi'] ?? '').toString().toLowerCase();

        // Pastikan ID tidak kosong setelah trim
        if (id.isEmpty) {
          print('Skipping destination with empty ID after trim');
          continue;
        }

        if (name.contains(_searchQuery) ||
            category.contains(_searchQuery) ||
            location.contains(_searchQuery)) {
          tempResults.add({
            'id': id, // Gunakan ID yang sudah di-trim
            'name': dest['namaDestinasi'].toString().trim(),
            'type': 'destination',
            'category': dest['kategori']?.toString() ?? 'Umum',
            'location': dest['lokasi']?.toString() ?? 'Lokasi tidak tersedia',
          });
          print('Added destination to search: $id - ${dest['namaDestinasi']}');
        }
      } catch (e) {
        print('Error processing destination for search: $e');
        print('Problematic destination data: $dest');
        continue;
      }
    }

    // Proses event dengan validasi yang lebih ketat
    for (var event in _events) {
      try {
        // Validasi field wajib
        if (event['id'] == null ||
            event['namaEvent'] == null ||
            event['namaEvent'].toString().trim().isEmpty) {
          print('Skipping event with invalid data: $event');
          continue;
        }

        final String id = event['id'].toString().trim();
        final String name = event['namaEvent'].toString().toLowerCase();
        final String category =
            (event['kategori'] ?? '').toString().toLowerCase();

        // Pastikan ID tidak kosong setelah trim
        if (id.isEmpty) {
          print('Skipping event with empty ID after trim');
          continue;
        }

        if (name.contains(_searchQuery) || category.contains(_searchQuery)) {
          tempResults.add({
            'id': id, // Gunakan ID yang sudah di-trim
            'name': event['namaEvent'].toString().trim(),
            'type': 'event',
            'category': event['kategori']?.toString() ?? 'Umum',
          });
          print('Added event to search: $id - ${event['namaEvent']}');
        }
      } catch (e) {
        print('Error processing event for search: $e');
        print('Problematic event data: $event');
        continue;
      }
    }

    // Batasi hasil maksimal 10
    if (tempResults.length > 10) {
      tempResults = tempResults.take(10).toList();
    }

    print('Search results count: ${tempResults.length}');
    for (var result in tempResults) {
      print(
          'Result: ${result['name']}, ID: ${result['id']}, Type: ${result['type']}');
    }

    setState(() {
      _searchResults = tempResults;
      _showSearchResults = _searchFocusNode.hasFocus &&
          _searchResults.isNotEmpty &&
          _searchQuery.isNotEmpty;
    });
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _checkUserRole(),
      _checkLoginStatus(),
      _fetchUserName(),
      fetchCarouselItems(),
      _fetchDestinations(),
      _fetchEvents(),
    ]);
    _updateLastActive();
    _startActiveTimer();
  }

  Future<void> _fetchDestinations() async {
    try {
      print('=== FETCHING DESTINATIONS ===');
      final snapshot = await FirebaseFirestore.instance
          .collection('destinasi')
          .orderBy('rating', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _destinations = snapshot.docs
              .map((doc) {
                final data = doc.data();

                // PERBAIKAN: Pastikan ID tersimpan dengan benar
                final String documentId = doc.id.trim();
                if (documentId.isEmpty) {
                  print('WARNING: Empty document ID found for destination');
                }

                data['id'] = documentId;
                data['namaDestinasi'] =
                    data['namaDestinasi']?.toString().trim() ??
                        'Nama tidak tersedia';
                data['kategori'] =
                    data['kategori']?.toString().trim() ?? 'Umum';
                data['lokasi'] = data['lokasi']?.toString().trim() ??
                    'Lokasi tidak tersedia';

                // Validasi rating
                final dynamic ratingValue = data['rating'];
                double rating = 0.0;

                if (ratingValue != null) {
                  if (ratingValue is num) {
                    rating = ratingValue.toDouble();
                  } else if (ratingValue is String) {
                    rating = double.tryParse(ratingValue) ?? 0.0;
                  }
                }

                rating = rating.clamp(0.0, 5.0);
                data['rating'] = rating;
                data['imageUrl'] = data['imageUrl']?.toString() ?? '';

                print(
                    'Fetched Destination: ${data['namaDestinasi']}, ID: $documentId, Rating: $rating');

                // Validasi data sebelum ditambahkan
                if (documentId.isNotEmpty &&
                    data['namaDestinasi'].toString().isNotEmpty) {
                  return data;
                } else {
                  print(
                      'WARNING: Invalid destination data skipped - ID: $documentId, Name: ${data['namaDestinasi']}');
                  return null;
                }
              })
              .where((data) => data != null)
              .cast<Map<String, dynamic>>()
              .toList();

          _isLoadingDestinations = false;
        });

        _updateSearchResults();
        print('Total valid destinations loaded: ${_destinations.length}');
      }
    } catch (e) {
      print('Error fetching destinations: $e');
      if (mounted) {
        setState(() => _isLoadingDestinations = false);
        _showErrorSnackBar('Gagal memuat data destinasi: $e');
      }
    }
  }

  Future<void> _fetchEvents() async {
    try {
      print('=== FETCHING EVENTS ===');
      final snapshot =
          await FirebaseFirestore.instance.collection('events').get();

      if (mounted) {
        setState(() {
          _events = snapshot.docs
              .map((doc) {
                final data = doc.data();

                // PERBAIKAN: Pastikan ID tersimpan dengan benar
                final String documentId = doc.id.trim();
                if (documentId.isEmpty) {
                  print('WARNING: Empty document ID found for event');
                }

                data['id'] = documentId;
                data['namaEvent'] = data['namaEvent']?.toString().trim() ??
                    'Event tidak tersedia';
                data['kategori'] =
                    data['kategori']?.toString().trim() ?? 'Umum';
                data['imageUrl'] = data['imageUrl']?.toString() ?? '';

                print('Fetched Event: ${data['namaEvent']}, ID: $documentId');

                // Validasi data sebelum ditambahkan
                if (documentId.isNotEmpty &&
                    data['namaEvent'].toString().isNotEmpty) {
                  return data;
                } else {
                  print(
                      'WARNING: Invalid event data skipped - ID: $documentId, Name: ${data['namaEvent']}');
                  return null;
                }
              })
              .where((data) => data != null)
              .cast<Map<String, dynamic>>()
              .toList();

          _isLoadingEvents = false;
        });

        _updateSearchResults();
        print('Total valid events loaded: ${_events.length}');
      }
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        setState(() => _isLoadingEvents = false);
        _showErrorSnackBar('Gagal memuat data event: $e');
      }
    }
  }

  Future<void> fetchCarouselItems() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('sliders').get();
      if (mounted) {
        setState(() {
          _carouselItems = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      print('Error fetching carousel items: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredDestinations({
    required bool isPopular,
  }) {
    var filtered = _destinations.where((dest) {
      final String? category = dest['kategori'];
      final bool matchesCategory = _selectedDestinationCategory == 'All' ||
          category == _selectedDestinationCategory;
      return matchesCategory;
    }).toList();

    if (isPopular) {
      // PERBAIKAN: Filter hanya rating 4.0-5.0 untuk wisata populler
      filtered = filtered.where((dest) {
        final double rating = (dest['rating'] as num).toDouble();
        return rating >= 4.0 && rating <= 5.0;
      }).toList();

      // Sort berdasarkan rating tertinggi
      filtered.sort(
        (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
      );

      return filtered;
    } else {
      filtered = filtered.where((dest) {
        final double rating = (dest['rating'] as num).toDouble();
        return rating < 4.0;
      }).toList();

      filtered.sort(
        (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
      );

      return filtered;
    }
  }

  List<Map<String, dynamic>> _getFilteredEvents() {
    return _events.where((event) {
      final String? category = event['kategori'];
      final bool matchesCategory =
          _selectedEventCategory == 'All' || category == _selectedEventCategory;
      return matchesCategory;
    }).toList();
  }

  void _onScroll() {}

  Future<void> _checkUserRole() async {
    if (!mounted) return;
    String? role = await getUserRole();
    if (mounted) {
      setState(() => userRole = role);
    }
  }

  void _updateLastActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'lastActive': FieldValue.serverTimestamp()},
      );
    }
  }

  void _startActiveTimer() {
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateLastActive(),
    );
  }

  Future<void> _fetchUserName() async {
    if (!mounted) return;
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _userName = doc['username']);
      }
    }
  }

  Future<String?> getUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        return doc['role'];
      }
    }
    return null;
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    User? user = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() => _isLoggedIn = user != null);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      _animationController.reverse();
    } else {
      _scaffoldKey.currentState?.openDrawer();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: grayColor,
      onDrawerChanged: (isOpen) {
        if (!isOpen) _animationController.reverse();
      },
      drawer: _buildDrawer(),
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavBar(
        userRole: userRole,
        isLoggedIn: _isLoggedIn, // Pass login status
      ),
    );
  }

  Widget _buildDrawer() {
    final drawerItems = <Map<String, dynamic>>[
      {
        'icon': Icons.map,
        'title': 'Destinasi',
        'action': () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DaftarDestinasiPage(),
            ),
          );
        },
      },
      {
        'icon': Icons.chat,
        'title': 'Forum Diskusi',
        'action': () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DiscussPage()),
          );
        },
      },
      {
        'icon': Icons.event,
        'title': 'Event',
        'action': () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DaftarEventPage()),
          );
        },
      },
      {
        'icon': Icons.image,
        'title': 'Galeri',
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GaleriPage()),
          );
        },
      },
    ];

    if (_isLoggedIn && userRole != "owner") {
      drawerItems.addAll([
        {
          'icon': Icons.tips_and_updates,
          'title': 'Tambah Destinasi',
          'action': () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TambahDestinasiPage()),
            );
          },
        },
        {
          'icon': Icons.admin_panel_settings,
          'title': 'Request Role',
          'action': () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RequestRolePage()),
            );
          },
        },
      ]);
    }

    if (userRole == "owner") {
      drawerItems.add({
        'icon': Icons.calendar_today,
        'title': 'Add Event',
        'action': () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TambahEventPage()),
          );
        },
      });
    }

    drawerItems.add({
      'icon': _isLoggedIn ? Icons.logout : Icons.login,
      'title': _isLoggedIn ? "Keluar" : "Masuk",
      'action': () async {
        Navigator.pop(context);
        if (_isLoggedIn) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() {
              userRole = null;
              _userName = null;
              _isLoggedIn = false;
            });
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      },
    });

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.5,
      child: Drawer(
        backgroundColor: grayColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/logo1.png',
                    width: 123,
                    height: 120,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            ...drawerItems
                .map(
                  (item) => ListTile(
                    leading: Icon(
                      item['icon'] as IconData,
                      color: Colors.black87,
                    ),
                    title: Text(
                      item['title'] as String,
                      style: GoogleFonts.poppins(color: Colors.black87),
                    ),
                    onTap: (item['action'] as VoidCallback),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return GestureDetector(
      onTap: () {
        if (_showSearchResults) {
          _clearSearch();
        }
      },
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor: grayColor,
                floating: true,
                pinned: true,
                snap: false,
                elevation: 0,
                leading: IconButton(
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.menu_close,
                    progress: _animationController,
                    color: Colors.black,
                  ),
                  onPressed: _toggleDrawer,
                ),
                titleSpacing: 0,
                title: _buildSearchBar(),
                actions: [
                  badges.Badge(
                    badgeContent: Text(
                      _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    showBadge: _notificationCount > 0,
                    position: badges.BadgePosition.topEnd(top: -2, end: -2),
                    badgeStyle: badges.BadgeStyle(
                      badgeColor: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.all(4),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        final userId =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NotificationsUserPage(userId: userId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 5),
                  _buildWelcomeSection(),
                  const SizedBox(height: 20),
                  _buildCarousel(),
                  _buildDestinationCategoriesSection(),
                  _buildEventCategoriesSection(),
                  _buildDestinationSection(
                    title: "Tempat Wisata Batam Terpopuler",
                    icon: Icons.star,
                    isPopular: true,
                  ),
                  _buildDestinationSection(
                    title: "Tempat Wisata Lainnya",
                    icon: Icons.location_on,
                    isPopular: false,
                  ),
                  _buildEventSection(title: "Event Terkini", icon: Icons.event),
                  const SizedBox(height: 16),
                ]),
              ),
            ],
          ),
          // Position the search results dynamically
          if (_showSearchResults)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  kToolbarHeight, // Adjusted top
              left: 16,
              right: 16,
              child: _buildSearchResults(),
            ),
        ],
      ),
    );
  }

  // The _buildSearchBar method now only contains the TextField.
  // It's wrapped in a flexible space in the SliverAppBar.
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: "Search destinations or events...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: _clearSearch,
              )
            : null,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.search_off, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Tidak ada hasil untuk "$_searchQuery"',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final double maxResultsHeight = MediaQuery.of(context).size.height * 0.4;

    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: BoxConstraints(maxHeight: maxResultsHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Hasil pencarian untuk "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_searchResults.length} hasil',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item['type'] == 'destination'
                            ? Colors.blue[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['type'] == 'destination'
                            ? Icons.location_on
                            : Icons.event,
                        color: item['type'] == 'destination'
                            ? Colors.blue[600]
                            : Colors.orange[600],
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item['type'] == 'destination'
                          ? '${item['category'] as String} • ${item['location'] as String}'
                          : '${item['category'] as String} • Event',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    onTap: () {
                      print('Search result tapped: ${item['name']}');

                      // PERBAIKAN: Validasi data sebelum navigasi
                      if (_validateSearchItem(item)) {
                        _handleSearchResultTap(item);
                      } else {
                        _showErrorSnackBar(
                            'Data item tidak valid untuk navigasi');
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateSearchItem(Map<String, dynamic> item) {
    final String? id = item['id'];
    final String? type = item['type'];
    final String? name = item['name'];

    if (id == null || id.trim().isEmpty) {
      print('Invalid search item: ID is null or empty');
      return false;
    }

    if (type == null || type.trim().isEmpty) {
      print('Invalid search item: Type is null or empty');
      return false;
    }

    if (name == null || name.trim().isEmpty) {
      print('Invalid search item: Name is null or empty');
      return false;
    }

    if (type != 'destination' && type != 'event') {
      print('Invalid search item: Unknown type - $type');
      return false;
    }

    return true;
  }

  Widget _buildWelcomeSection() {
    if (!_isLoggedIn || _userName == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
      color: grayColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hello, $_userName",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Welcome to GuideME",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF808080),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    return Container(
      color: grayColor,
      child: Column(
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: _carouselItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : CarouselSlider(
                      options: CarouselOptions(
                        height: 220.0,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 3),
                        viewportFraction: 1.0,
                        onPageChanged: (index, reason) {
                          if (mounted) {
                            setState(() => _currentCarouselIndex = index);
                          }
                        },
                      ),
                      items: _carouselItems
                          .map((item) => _buildCarouselItem(item))
                          .toList(),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _carouselItems.asMap().entries.map((entry) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentCarouselIndex == entry.key
                      ? primaryColor
                      : Colors.grey.withOpacity(0.5),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> item) {
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: item['imageUrl'] != null &&
                    (item['imageUrl'] as String).isNotEmpty
                ? Image.network(
                    item['imageUrl'] as String,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(),
                          ),
                  )
                : Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? 'No Title',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['description'] ?? 'No Description',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
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

  Widget _buildDestinationCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
          child: Text(
            "Kategori Destinasi",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _destinationCategories.length,
            itemBuilder: (context, index) => _buildCategoryItem(
              _destinationCategories[index],
              isForDestination: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
          child: Text(
            "Kategori Event",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _eventCategories.length,
            itemBuilder: (context, index) => _buildCategoryItem(
              _eventCategories[index],
              isForDestination: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
    Map<String, dynamic> category, {
    required bool isForDestination,
  }) {
    final isSelected = isForDestination
        ? _selectedDestinationCategory == category['name']
        : _selectedEventCategory == category['name'];

    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() {
            if (isForDestination) {
              _selectedDestinationCategory = category['name'] as String;
            } else {
              _selectedEventCategory = category['name'] as String;
            }
          });
        }
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? primaryColor.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset:
                        isSelected ? const Offset(0, 3) : const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                category['icon'] as IconData,
                color:
                    isSelected ? Colors.white : primaryColor.withOpacity(0.8),
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category['name'] as String,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationSection({
    required String title,
    required IconData icon,
    required bool isPopular,
  }) {
    if (_isLoadingDestinations) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final destinations = _getFilteredDestinations(isPopular: isPopular);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          color: grayColor,
          child: Row(
            children: [
              Icon(icon, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // PERBAIKAN: Tambahkan indikator rating untuk wisata populer
              if (isPopular) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: destinations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPopular
                            ? Icons.star_border
                            : Icons.location_on_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPopular
                            ? "Belum ada destinasi dengan rating 4.0-5.0"
                            : "Belum ada destinasi lainnya",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 16),
                      child: DestinationCard(
                        id: destination['id'] as String,
                        title: destination['namaDestinasi'] as String,
                        image: destination['imageUrl'] as String,
                        rating: (destination['rating'] as num).toDouble(),
                        location: destination['lokasi'] as String,
                        kategori: destination['kategori'] as String,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventSection({required String title, required IconData icon}) {
    if (_isLoadingEvents) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final events = _getFilteredEvents();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          color: grayColor,
          child: Row(
            children: [
              Icon(icon, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: events.isEmpty
              ? Center(
                  child: Text(
                    "No events found.",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 16),
                      child: EventCard(
                        id: event['id'] as String,
                        title: event['namaEvent'] as String,
                        image: event['imageUrl'] as String,
                        category: event['kategori'] as String,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DestinationCard extends StatelessWidget {
  final String id;
  final String title;
  final String image;
  final double rating;
  final String kategori;
  final String location;

  const DestinationCard({
    super.key,
    required this.id,
    required this.title,
    required this.image,
    required this.kategori,
    required this.rating,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DestinasiDetailPage(destinasiId: id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String id;
  final String title;
  final String image;
  final String category;

  const EventCard({
    super.key,
    required this.id,
    required this.title,
    required this.image,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailPage(eventId: id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends StatefulWidget {
  final String? userRole;
  final bool isLoggedIn; // Add isLoggedIn parameter
  const CustomBottomNavBar({
    super.key,
    this.userRole,
    required this.isLoggedIn,
  });
  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    final currentWidgetType = context.widget.runtimeType;

    if (currentWidgetType == HomePage) {
      _selectedIndex = 1;
    } else if (currentWidgetType == ProfileScreen) {
      _selectedIndex = 2;
    } else if (currentWidgetType == TicketPage) {
      _selectedIndex = 0;
    } else {
      _selectedIndex = 1;
    }

    return Container(
      height: 60,
      margin: const EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: 50, // Menaikkan navbar lebih tinggi agar tidak nabrak navigation bar sistem
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF5ABB4D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context,
            Icons.confirmation_number,
            0,
            TicketPage(),
            widget.isLoggedIn,
          ),
          _buildNavItem(context, Icons.home, 1, HomePage(), widget.isLoggedIn),
          _buildNavItem(
            context,
            Icons.person,
            2,
            ProfileScreen(),
            widget.isLoggedIn,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    int index,
    Widget destinationPage,
    bool isLoggedIn, // Receive isLoggedIn
  ) {
    final bool isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () {
        if (destinationPage is ProfileScreen && !isLoggedIn) {
          // Show alert dialog if not logged in and trying to access profile
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Login Required'),
                content: const Text(
                  'Anda belum login. Silakan login terlebih dahulu untuk mengakses fitur ini.',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                  ),
                  TextButton(
                    child: const Text('Login'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        } else if (context.widget.runtimeType != destinationPage.runtimeType) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => destinationPage),
          );
        }
      },
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}