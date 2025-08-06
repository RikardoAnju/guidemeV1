import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutApp extends StatefulWidget {
  const AboutApp({super.key});

  @override
  State<AboutApp> createState() => _AboutAppState();
}

class _AboutAppState extends State<AboutApp> {
  final Color primaryGreen = const Color(0xFF5ABB4D); 
  final Color lightGreen = const Color(0xFF5ABB4D); 

  String appVersion = '1.1';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        appVersion = 'Informasi versi tidak tersedia';
        isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka $url'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Size screenSize = MediaQuery.of(context).size;
    final contentWidth =
        screenSize.width > 600 ? 600.0 : screenSize.width * 0.92;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Back Button
                  Material(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 3,
                    shadowColor: primaryGreen.withOpacity(0.5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        height: 40,
                        width: 40,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tentang Aplikasi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child:
                  isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryGreen,
                          ),
                        ),
                      )
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                               
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: primaryGreen, // Warna latar
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryGreen.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      15,
                                    ), // Biar gambar agak masuk ke dalam
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.asset(
                                        'assets/images/logo5.png', // Gambar lokal kamu
                                        fit:
                                            BoxFit
                                                .contain, // Penting! Jangan cover supaya tidak terpotong
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // App Name
                                Text(
                                  'Guide Me',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // App Version
                                Text(
                                  'Versi $appVersion',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // App Description Card
                                Container(
                                  width: contentWidth,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            isDarkMode
                                                ? Colors.black.withOpacity(0.3)
                                                : Colors.grey.withOpacity(0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: primaryGreen,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Tentang',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: primaryGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Guide Me adalah aplikasi pendamping perjalanan pribadi Anda yang dirancang untuk membantu menemukan tempat baru, merencanakan perjalanan, dan menjelajahi wilayah yang belum dikenal dengan mudah.',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Misi kami adalah menjadikan perjalanan mudah diakses, menyenangkan, dan bermanfaat bagi semua orang, baik saat menjelajahi kota Anda sendiri maupun saat berpetualang di seluruh dunia.',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Features Card
                                Container(
                                  width: contentWidth,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            isDarkMode
                                                ? Colors.black.withOpacity(0.3)
                                                : Colors.grey.withOpacity(0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star_outline,
                                              color: primaryGreen,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Fitur Utama',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: primaryGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFeatureItem(
                                          icon: Icons.location_on_outlined,
                                          title: 'Penemuan Lokasi',
                                          description:
                                              'Temukan tempat menarik di sekitar atau di tujuan Anda',
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFeatureItem(
                                          icon: Icons.map_outlined,
                                          title: 'Peta Interaktif',
                                          description:
                                              'Jelajahi peta detail dengan penanda dan rute kustom',
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFeatureItem(
                                          icon: Icons.calendar_today_outlined,
                                          title: 'Perencanaan Perjalanan',
                                          description:
                                              'Buat dan kelola itinerari perjalanan Anda',
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFeatureItem(
                                          icon: Icons.bookmark_border,
                                          title: 'Penanda',
                                          description:
                                              'Simpan tempat favorit Anda untuk kunjungan di masa depan',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Contact Information
                                Container(
                                  width: contentWidth,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            isDarkMode
                                                ? Colors.black.withOpacity(0.3)
                                                : Colors.grey.withOpacity(0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.contact_support_outlined,
                                              color: primaryGreen,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Kontak & Dukungan',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: primaryGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildContactItem(
                                          icon: Icons.email_outlined,
                                          title: 'Email Dukungan',
                                          info: 'vinskaco@gmail.com',
                                          onTap:
                                              () => _launchURL(
                                                'mailto:vinskaco@gmail.com', 
                                              ),
                                        ),

                                        const SizedBox(height: 16),
                                        _buildContactItem(
                                          icon: Icons.public,
                                          title: 'Situs Web',
                                          info: 'www.guideme-app.com',
                                          onTap:
                                              () => _launchURL(
                                                'https://www.guideme-app.com',
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildContactItem(
                                          icon: Icons.policy_outlined,
                                          title: 'Kebijakan Privasi',
                                          info: 'Lihat kebijakan privasi kami',
                                          onTap:
                                              () => _launchURL(
                                                'https://www.guideme-app.com/privacy',
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildContactItem(
                                          icon: Icons.description_outlined,
                                          title: 'Ketentuan Layanan',
                                          info: 'Lihat ketentuan layanan kami',
                                          onTap:
                                              () => _launchURL(
                                                'https://www.guideme-app.com/terms',
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // Copyright
                                Text(
                                  '© ${DateTime.now().year} Guide Me. Hak cipta dilindungi.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor.withOpacity(0.5),
                                  ),
                                ),

                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryGreen, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String info,
    required VoidCallback onTap,
  }) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black12 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryGreen.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info,
                    style: TextStyle(fontSize: 14, color: subtitleColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: primaryGreen, size: 16),
          ],
        ),
      ),
    );
  }
}
