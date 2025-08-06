import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:guide_me/admin/setting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guide_me/user/home.dart';
import 'package:guide_me/admin/manajemen_pegguna.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifikasi_widget.dart';
import 'laporan.dart';
import '../services/notifikasiadmin_service.dart';
import 'package:badges/badges.dart' as badges;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  Map<String, int> userCounts = {};
  int touchedIndex = -1;

  late AnimationController _animationController;
  bool _isDrawerOpen = false;
  String? userRole;
  bool isLoadingRole = true;
  bool isLoggedIn = true;
  int _selectedNavIndex = 0;

  // Add notification count variable
  int _notificationCount = 0;

  // Create notification widget instance
  final NotificationsPage notificationWidget = NotificationsPage();

  final NotificationService _notificationService = NotificationService();

  final List<Color> _barColors = [
    Color(0xFF5ABB4D),
    Colors.blueAccent.shade700,
    Colors.purpleAccent.shade700,
    Colors.orangeAccent.shade700,
    Colors.redAccent.shade700,
  ];

  final Color _backgroundColor = Color(0xFFF8F9FA);
  final Color _cardBackgroundColor = Color(0xFFFFFFFF);
  final Color _primaryGreen = Color(0xFF5ABB4D);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Inisialisasi login dan data pengguna

    _checkUserRole();
    fetchUserData();

    // Inisialisasi notifikasi
    _notificationService.initNotificationListeners();
    _fetchNotificationCount();

    // Inisialisasi animasi
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  // Add method to fetch notification count
  Future<void> _fetchNotificationCount() async {
    try {
      // Get current user
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('admin_notifications')
              .where('isRead', isEqualTo: false)
              .get();

      // Update state with notification count
      if (mounted) {
        setState(() {
          _notificationCount = snapshot.docs.length;
        });
      }

      // Set up listener for real-time updates - gunakan nama koleksi yang sama
      FirebaseFirestore.instance
          .collection(
            'admin_notifications',
          ) // Ubah dari 'notifications' ke 'admin_notifications'
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                _notificationCount = snapshot.docs.length;
              });
            }
          });
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  Future<String?> getUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'];
      }
    }
    return null;
  }

  Future<void> _checkUserRole() async {
    setState(() => isLoadingRole = true);
    String? role = await getUserRole();
    if (mounted) {
      setState(() {
        userRole = role;
        isLoadingRole = false;
      });
    }
  }

  Future<void> fetchUserData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      Map<String, int> counts = {};
      for (var doc in snapshot.docs) {
        if (doc.data().containsKey('createdAt')) {
          Timestamp createdAt = doc['createdAt'];
          DateTime date = createdAt.toDate();
          String key = DateFormat('MMM yyyy').format(date);

          counts[key] = (counts[key] ?? 0) + 1;
        }
      }

      final sortedKeys =
          counts.keys.toList()..sort(
            (a, b) => DateFormat(
              'MMM yyyy',
            ).parse(a).compareTo(DateFormat('MMM yyyy').parse(b)),
          );

      if (mounted) {
        setState(() {
          userCounts = {for (var k in sortedKeys) k: counts[k]!};
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  // Called when drawer is opened
  void _onDrawerChanged(bool isOpened) {
    if (isOpened) {
      _animationController.forward();
      setState(() {
        _isDrawerOpen = true;
      });
    } else {
      _animationController.reverse();
      setState(() {
        _isDrawerOpen = false;
      });
    }
  }

  // Navigate to notification page instead of showing modal
  void _navigateToNotificationsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
  }

  Color getBarColor(int index) {
    return _barColors[index % _barColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Admin page content
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _backgroundColor,

        drawer: Drawer(
          backgroundColor: Color(0xFFF8F9FA),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 40, bottom: 20),
                color: Color(0xFFF8F9FA),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: _primaryGreen,
                      child: const Text(
                        'A',
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  color: Color(0xFFF8F9FA),
                  child: Column(
                    children: [
                      _buildDrawerItem(
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        isActive: true,
                        onTap: () {
                          _scaffoldKey.currentState?.closeDrawer();
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.people,
                        title: 'Manajemen Pengguna',
                        onTap: () {
                          _scaffoldKey.currentState?.closeDrawer();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KelolaUserPage(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        icon: Icons.analytics,
                        title: 'Laporan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentReportPage(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.settings,
                        title: 'Pengaturan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingPage(),
                            ),
                          );
                          _scaffoldKey.currentState?.closeDrawer();
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        onTap: () async {
                          _scaffoldKey.currentState?.closeDrawer();

                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: Text('Konfirmasi Logout'),
                                  content: Text(
                                    'Apakah Anda yakin ingin keluar?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () =>
                                              Navigator.of(context).pop(false),
                                      child: Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(true),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                          );

                          if (shouldLogout == true) {
                            // 1. Sign out dari Firebase
                            await FirebaseAuth.instance.signOut();

                            // 2. Hapus role/login status
                            final prefs = await SharedPreferences.getInstance();
                            await prefs
                                .clear(); // atau hanya hapus 'role' dan 'uid'

                            // 3. Navigasi ke halaman login
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomePage(),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        onDrawerChanged: _onDrawerChanged,

        // Keep bottom navigation bar
       

        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Menu button
                    GestureDetector(
                      onTap: _toggleDrawer,
                      child: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _animationController,
                        color: Colors.black87,
                        size: 26,
                      ),
                    ),

                    //notifikasi
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications,
                            color: Colors.black87,
                            size: 26,
                          ),
                          onPressed: _navigateToNotificationsPage,
                        ),
                        if (_notificationCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  _notificationCount > 99
                                      ? '99+'
                                      : '$_notificationCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Card untuk grafik
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child:
                      userCounts.isEmpty
                          ? Center(
                            child: CircularProgressIndicator(
                              color: _primaryGreen,
                            ),
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Jumlah Pengguna per Bulan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Ubah bagian BarChart dalam kode asli Anda
                              Expanded(
                                child: BarChart(
                                  BarChartData(
                                    maxY:
                                        (userCounts.values.isEmpty
                                            ? 0
                                            : (userCounts.values.toList()
                                                  ..sort())
                                                .last) *
                                        1.2,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        tooltipBorder: const BorderSide(
                                          color: Colors.black,
                                        ),
                                        tooltipRoundedRadius: 8,
                                        getTooltipItem: (
                                          group,
                                          groupIndex,
                                          rod,
                                          rodIndex,
                                        ) {
                                          if (group.x < 0 ||
                                              group.x >= userCounts.length) {
                                            return null;
                                          }
                                          return BarTooltipItem(
                                            '${userCounts.values.elementAt(group.x)} pengguna',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                      touchCallback: (
                                        FlTouchEvent event,
                                        barTouchResponse,
                                      ) {
                                        setState(() {
                                          if (barTouchResponse?.spot != null &&
                                              event is! FlTapUpEvent &&
                                              event is! FlPanEndEvent) {
                                            touchedIndex =
                                                barTouchResponse!
                                                    .spot!
                                                    .touchedBarGroupIndex;
                                          } else {
                                            touchedIndex = -1;
                                          }
                                        });
                                      },
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawHorizontalLine: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey[300],
                                          strokeWidth: 1,
                                          dashArray: [
                                            5,
                                            5,
                                          ], // Garis putus-putus seperti pada gambar referensi
                                        );
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, _) {
                                            int index = value.toInt();
                                            if (index < 0 ||
                                                index >= userCounts.length) {
                                              return const SizedBox();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                userCounts.keys.elementAt(
                                                  index,
                                                ), // Tetap menggunakan label bulan-tahun asli
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0) {
                                              return const SizedBox();
                                            }
                                            return Text(
                                              value.toInt().toString(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    barGroups:
                                        userCounts.isEmpty
                                            ? []
                                            : userCounts.entries
                                                .toList()
                                                .asMap()
                                                .entries
                                                .map(
                                                  (entry) => BarChartGroupData(
                                                    x: entry.key,
                                                    barRods: [
                                                      BarChartRodData(
                                                        toY:
                                                            entry.value.value
                                                                .toDouble(),
                                                        color:
                                                            touchedIndex ==
                                                                    entry.key
                                                                ? _primaryGreen
                                                                : _primaryGreen
                                                                    .withOpacity(
                                                                      0.6,
                                                                    ), // Menggunakan warna 5ABB4D
                                                        width: 22,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              0,
                                                            ), // Tanpa border radius sesuai gambar
                                                      ),
                                                    ],
                                                  ),
                                                )
                                                .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ),

              _buildInfoCard(
                'Total Pengguna',
                userCounts.isEmpty
                    ? '0'
                    : userCounts.values
                        .fold(0, (sum, count) => sum + count)
                        .toString(),
                Icons.people,
                Colors.blue,
              ),

              _buildInfoCard(
                'Pengguna Baru Bulan Ini',
                userCounts.isEmpty ? '0' : userCounts.values.last.toString(),
                Icons.person_add,
                Colors.orange,
              ),

              _buildInfoCard(
                'Rata-rata Pengguna per Bulan',
                userCounts.isEmpty
                    ? '0'
                    : (userCounts.values.fold(0, (sum, count) => sum + count) /
                            userCounts.length)
                        .toStringAsFixed(1),
                Icons.analytics,
                Colors.purple,
              ),

              // Add a new card for notification count
              _buildInfoCard(
                'Notifikasi Belum Dibaca',
                _notificationCount.toString(),
                Icons.notifications_active,
                Colors.red,
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
      },
      child: SizedBox(
        width: 60,
        height: 56,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    Color? textColor,
    Color? iconColor,
  }) {
    return Container(
      color: isActive ? Color(0xFFE8F5E9) : Color(0xFFF8F9FA),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? (isActive ? _primaryGreen : Colors.grey[600]),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor ?? (isActive ? _primaryGreen : Colors.black87),
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
    );
  }
}
