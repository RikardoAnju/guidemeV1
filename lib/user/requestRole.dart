import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart';

class RequestRolePage extends StatefulWidget {
  const RequestRolePage({super.key});

  @override
  State<RequestRolePage> createState() => _RequestRolePageState();
}

class _RequestRolePageState extends State<RequestRolePage> {
  // Form controllers
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _destinationNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _mapsUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // User data
  String _username = '';
  String _email = '';
  String _userId = '';

  // Bank selection
  String? _selectedBank;
  final List<String> _bankOptions = [
    'BCA',
    'BNI',
    'BRI',
    'Mandiri',
    'CIMB Niaga',
    'Danamon',
    'Permata Bank',
    'Bank Syariah Indonesia',
    'Bank Mega',
    'OCBC NISP',
  ];

  // KTP image data
  File? _ktpImage;
  Uint8List? _ktpBytes;
  String? _ktpFileName;

  // State tracking
  bool _isLoading = false;
  bool _hasPendingRequest = false;
  String? _pendingRequestId;
  String? _requestStatus; // Menambahkan status request

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkExistingRequests();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _destinationNameController.dispose();
    _descriptionController.dispose();
    _mapsUrlController.dispose();
    super.dispose();
  }

  // Improved Google Maps URL validation
  bool _isValidGoogleMapsUrl(String url) {
    if (url.isEmpty) return false;
    
    // Convert to lowercase for case-insensitive matching
    String lowerUrl = url.toLowerCase();
    
    // Check for various Google Maps URL patterns
    return lowerUrl.contains('google.com/maps') ||
           lowerUrl.contains('maps.google.com') ||
           lowerUrl.contains('goo.gl/maps') ||
           lowerUrl.contains('maps.app.goo.gl');
  }

  // Load current user data
  void _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final data = doc.data();

      if (data != null) {
        setState(() {
          _username = data['username'] ?? '';
          _email = data['email'] ?? '';
          _userId = currentUser.uid;
        });
      }
    }
  }

  // Check if user already has a pending or processed request
  void _checkExistingRequests() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Query untuk mencari request dengan status pending atau processed
      final querySnapshot = await FirebaseFirestore.instance
          .collection('role_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // Filter secara manual untuk status pending atau processed
      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        return status == 'pending' || status == 'processed';
      }).toList();

      if (filteredDocs.isNotEmpty) {
        final latestDoc = filteredDocs.first;
        final status = latestDoc.data()['status'] as String;
        
        setState(() {
          _hasPendingRequest = true;
          _pendingRequestId = latestDoc.id;
          _requestStatus = status;
        });
      }
    } catch (e) {
      _showSnackBar('Error checking existing requests: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Pick KTP image
  Future<void> _pickKTPImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _ktpFileName = result.files.single.name;
          if (kIsWeb) {
            _ktpBytes = result.files.single.bytes!;
          } else {
            _ktpImage = File(result.files.single.path!);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e', isError: true);
    }
  }

  // Upload KTP to Firebase Storage
  Future<String?> _uploadKTPToStorage() async {
    try {
      final filename = 'ktp_${DateTime.now().millisecondsSinceEpoch}_$_ktpFileName';
      final storageRef = FirebaseStorage.instance.ref().child('ktp_images/$filename');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(
          _ktpBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        uploadTask = storageRef.putFile(_ktpImage!);
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  // Submit the request
  void _submitRequest() async {
    // Check for pending or processed request
    if (_hasPendingRequest) {
      String message = '';
      if (_requestStatus == 'pending') {
        message = 'Anda sudah memiliki permintaan role yang sedang ditinjau.';
      } else if (_requestStatus == 'processed') {
        message = 'Anda sudah memiliki permintaan role yang sedang diproses.';
      }
      
      _showSnackBar(message, isError: true);
      return;
    }

    // Validate form and KTP
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBank == null) {
      _showSnackBar('Harap pilih bank terlebih dahulu', isError: true);
      return;
    }

    if (_ktpImage == null && _ktpBytes == null) {
      _showSnackBar('Harap upload foto KTP terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload KTP image
      final String? ktpDownloadUrl = await _uploadKTPToStorage();
      if (ktpDownloadUrl == null) {
        throw Exception('Gagal mengupload gambar KTP');
      }

      // Add role request to Firestore
      final docRef = await FirebaseFirestore.instance.collection('role_requests').add({
        'role': 'owner',
        'username': _username,
        'email': _email,
        'bankName': _selectedBank,
        'accountNumber': _accountNumberController.text.trim(),
        'destinationName': _destinationNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'mapsUrl': _mapsUrlController.text.trim(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'ktpUrl': ktpDownloadUrl,
        'userId': _userId,
      });

      setState(() {
        _isLoading = false;
        _hasPendingRequest = true;
        _pendingRequestId = docRef.id;
        _requestStatus = 'pending';
      });

      _showSnackBar(
        'Permintaan berhasil dikirim! Kami akan memproses dalam 1-3 hari kerja.',
        isError: false,
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Gagal mengirim permintaan: $e', isError: true);
    }
  }

  // Show SnackBar
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
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
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E7D32), size: 20),
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
        ),
        title: Text(
          'Request Role',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _hasPendingRequest
              ? _buildPendingRequestView()
              : _buildRequestForm(),
    );
  }

  // Build the pending request view
  Widget _buildPendingRequestView() {
    // Menentukan ikon, warna, dan pesan berdasarkan status
    IconData statusIcon;
    Color statusColor;
    String statusTitle;
    String statusDescription;

    if (_requestStatus == 'pending') {
      statusIcon = Icons.access_time_filled_rounded;
      statusColor = const Color(0xFFFBC02D);
      statusTitle = 'Permintaan Sedang Ditinjau';
      statusDescription = 'Anda sudah memiliki permintaan role yang sedang dalam proses peninjauan. Silakan tunggu hingga admin meninjau permintaan Anda.';
    } else if (_requestStatus == 'processed') {
      statusIcon = Icons.hourglass_bottom_rounded;
      statusColor = const Color(0xFFFF9800);
      statusTitle = 'Permintaan Sedang Diproses';
      statusDescription = 'Permintaan Anda sedang dalam proses verifikasi dan implementasi. Tim kami sedang menyelesaikan tahap akhir.';
    } else {
      // Default case
      statusIcon = Icons.info_outline;
      statusColor = Colors.blue;
      statusTitle = 'Permintaan Ditemukan';
      statusDescription = 'Status permintaan Anda sedang dalam pemrosesan.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    statusTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusDescription,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _requestStatus == 'pending' 
                                ? 'Proses peninjauan biasanya membutuhkan waktu 1-3 hari kerja.'
                                : 'Proses implementasi biasanya membutuhkan waktu 1-2 hari kerja.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'KEMBALI KE BERANDA',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the request form
  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _buildHeaderCard(),
            const SizedBox(height: 24),
            
            // Bank and Account information
            _buildFormSection(
              title: 'Informasi Bank & Rekening',
              icon: Icons.account_balance_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBankDropdown(),
                  const SizedBox(height: 16),
                  if (_selectedBank != null) ...[
                    _buildTextField(
                      controller: _accountNumberController,
                      label: 'Nomor Rekening $_selectedBank',
                      hint: 'Contoh: 1234567890',
                      icon: Icons.account_balance_wallet,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nomor rekening tidak boleh kosong';
                        }
                        if (value.length < 5) {
                          return 'Nomor rekening terlalu pendek';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Destination information
            _buildFormSection(
              title: 'Informasi Destinasi',
              icon: Icons.place_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _destinationNameController,
                    label: 'Nama Destinasi',
                    hint: 'Masukkan nama destinasi wisata',
                    icon: Icons.place_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nama destinasi tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Deskripsi Singkat',
                    hint: 'Jelaskan tentang destinasi wisata Anda',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Deskripsi tidak boleh kosong';
                      }
                      if (value.length < 20) {
                        return 'Deskripsi terlalu pendek (min 20 karakter)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _mapsUrlController,
                    label: 'URL Google Maps',
                    hint: 'Contoh: www.google.com/maps/place/Top+100+Swalayan...',
                    icon: Icons.map_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'URL Google Maps tidak boleh kosong';
                      }
                      if (!_isValidGoogleMapsUrl(value)) {
                        return 'Harap masukkan URL Google Maps yang valid';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // KTP upload section
            _buildFormSection(
              title: 'Upload Foto KTP',
              icon: Icons.badge_outlined,
              child: InkWell(
                onTap: _pickKTPImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_ktpImage == null && _ktpBytes == null)
                          ? Colors.grey.shade300
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                  child: (_ktpImage != null || _ktpBytes != null)
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.memory(_ktpBytes!, fit: BoxFit.cover, width: double.infinity)
                                  : Image.file(_ktpImage!, fit: BoxFit.cover, width: double.infinity),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _ktpImage = null;
                                    _ktpBytes = null;
                                    _ktpFileName = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_rounded, size: 36, color: Color(0xFF2E7D32)),
                            const SizedBox(height: 12),
                            Text(
                              'Tap untuk upload foto KTP',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            
            if (_ktpFileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File: $_ktpFileName',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF2E7D32),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 32),
            
            // Terms and conditions notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFAED581)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dengan mengirim permintaan ini, Anda menyetujui bahwa data yang diberikan akan digunakan untuk proses verifikasi.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF558B2F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'KIRIM PERMINTAAN',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build bank dropdown
  Widget _buildBankDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Bank',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBank,
          decoration: InputDecoration(
            hintText: 'Pilih bank Anda',
            prefixIcon: const Icon(Icons.account_balance, color: Color(0xFF2E7D32)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
          ),
          items: _bankOptions.map((bank) {
            return DropdownMenuItem(
              value: bank,
              child: Text(bank),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBank = value;
              // Clear account number when bank changes
              _accountNumberController.clear();
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Harap pilih bank terlebih dahulu';
            }
            return null;
          },
        ),
      ],
    );
  }

  // Build header card
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Role Owner',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan lengkapi data berikut untuk mengajukan permintaan role Owner. Permintaan akan diproses dalam 1-3 hari kerja.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // Build form section with title
  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2E7D32)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // Build text field with label
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
          ),
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }
}