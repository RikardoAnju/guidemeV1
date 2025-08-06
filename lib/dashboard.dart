import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const DashboardPage({super.key, required this.scaffoldKey});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<Color> _barColors = [
    Colors.greenAccent.shade700,
    Colors.blueAccent.shade700,
    Colors.purpleAccent.shade700,
    Colors.orangeAccent.shade700,
    Colors.redAccent.shade700,
  ];

  // Background colors
  final Color backgroundColor = Colors.grey[300]!;
  final Color _cardBackgroundColor = Colors.grey[200]!;

  // State variables
  Map<String, int> userCounts = {};
  int touchedIndex = -1;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      Map<String, int> counts = {};
      for (var doc in snapshot.docs) {
        if (doc.data().containsKey('createdAt')) {
          Timestamp createdAt = doc['createdAt'];
          String key = DateFormat('MMM yyyy').format(createdAt.toDate());
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
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Color _getBarColor(int index) => _barColors[index % _barColors.length];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartCard(),
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Padding(
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
            isLoading || userCounts.isEmpty
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.green),
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
                    Expanded(child: _buildBarChart()),
                  ],
                ),
      ),
    );
  }

  Widget _buildBarChart() {
    final double maxY =
        userCounts.values.isEmpty
            ? 0
            : (userCounts.values.toList()..sort()).last * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBorder: const BorderSide(color: Colors.black),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (group.x < 0 || group.x >= userCounts.length) {
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
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              if (barTouchResponse?.spot != null &&
                  event is! FlTapUpEvent &&
                  event is! FlPanEndEvent) {
                touchedIndex = barTouchResponse!.spot!.touchedBarGroupIndex;
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
            return FlLine(color: Colors.grey[300], strokeWidth: 1);
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
                if (index < 0 || index >= userCounts.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    userCounts.keys.elementAt(index),
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
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
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
                            toY: entry.value.value.toDouble(),
                            color:
                                touchedIndex == entry.key
                                    ? Colors.green
                                    : _getBarColor(entry.key),
                            width: 22,
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY,
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
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
}