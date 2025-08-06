import 'package:flutter/material.dart';
import 'daftar_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guide_me/admin/kelola_permintaan_rekomendasi_destinasi.dart';
import 'package:guide_me/admin/kelolah_request_role.dart';
import 'kelolah_add_event.dart';
import 'kelolah_feedBack.dart';

class KelolaUserPage extends StatelessWidget {
  const KelolaUserPage({super.key});

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
                        'Manajemen Pengguna',
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
                      'Daftar Pengguna',
                      Icons.people_alt_rounded,
                      'Lihat dan kelola semua pengguna sistem',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DaftarUserPage())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Request Role',
                      Icons.assignment_ind_rounded,
                      'Kelola permintaan perubahan role pengguna',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolahRoleRequestsPage())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Request Destinasi',
                      Icons.tips_and_updates,
                      'Kelola Permintaan Rekomendasi Destinasi',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolahRekomendasiDestinasiPage())
                        );
                      },
                    ),
                    _buildManagementCard(
                      context,
                      'Add Event',
                      Icons.event,
                      'Kelolah Permintaan Event',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KelolahAddEventPage())
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