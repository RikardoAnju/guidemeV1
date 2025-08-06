import 'package:flutter/material.dart';
import 'package:guide_me/admin/kontroll_event.dart';
import 'kelolah_owner.dart';
import 'package:google_fonts/google_fonts.dart';


import 'kelolah_slider.dart';
import 'kelolah_feedBack.dart';
import 'kontroll_destinasi.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header dengan back button dan judul
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5ABB4D),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5ABB4D).withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Judul di tengah
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Setting',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5ABB4D),
                          letterSpacing: 0.5,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      Text(
                        'Pilih opsi manajemen yang Anda inginkan',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 36),
                
                // Grid menu dengan desain yang lebih modern
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.85,
                  children: [
                    _buildManagementCard(
                      context,
                      'Daftar Owner',
                      Icons.people_alt_rounded,
                      'Lihat dan kelola owner ',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolahOwnerPage())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Kelolah Slider',
                      Icons.assignment_ind_rounded,
                      'Kelola permintaan perubahan role pengguna',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolaSliderPage())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Destinasi',
                      Icons.tips_and_updates,
                      'Kontroll Destinasi',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolaDestinasiPage())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Kontroll Event',
                      Icons.event,
                      'Kontroll Event',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KontrollEventPage ())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Kelolah Feed Back',
                      Icons.groups_rounded,
                      'Kelola Feed Back Pengguna',
                      () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolahFeedbackPage())
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementCard(BuildContext context, String title, IconData icon,
      String description, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5ABB4D).withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF5ABB4D).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: const Color(0xFF5ABB4D),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5ABB4D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}