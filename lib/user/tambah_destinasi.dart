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

class TambahDestinasiPage extends StatefulWidget {
  const TambahDestinasiPage({super.key});

  @override
  State<TambahDestinasiPage> createState() => TambahDestinasiPageState();
}

class TambahDestinasiPageState extends State<TambahDestinasiPage> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    'nama': TextEditingController(),
    'lokasi': TextEditingController(),
    'deskripsi': TextEditingController(),
    'harga': TextEditingController(),
    'urlMaps': TextEditingController(),
    'jamBuka': TextEditingController(),
    'jamTutup': TextEditingController(),
  };

  // Categories list
  final List<String> _categories = [
    'Wisata Alam',
    'Wisata Budaya',
    'Wisata Religi',
    'Wisata Kuliner',
    'Wisata Sejarah',
    'Wisata Edukasi',
    'Wisata Petualangan',
    'Taman Hiburan',
    'Pantai',
    'Gunung',
    'Air Terjun',
    'Museum',
  ];

  // State variables
  String _username = '';
  String _email = '';
  String _userId = '';
  bool _isLoading = false;
  bool _hasActiveRequest = false;
  bool _isDestinasiFree = false;
  String? _requestStatus;
  String? _selectedCategory;

  // Image data
  File? _destinasiImage;
  Uint8List? _destinasiBytes;
  String? _destinasiFileName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkActiveRequests();
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  // Load user data
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _username = data['username'] ?? '';
          _email = data['email'] ?? '';
          _userId = user.uid;
        });
      }
    }
  }

  // Check active requests
  Future<void> _checkActiveRequests() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('destinasi_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'processed'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _hasActiveRequest = true;
          _requestStatus = doc['status'];
        });
      }
    } catch (e) {
      _showSnackBar('Error checking requests: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Validators
  bool _isValidMapsUrl(String url) {
    if (url.isEmpty) return false;
    final validPatterns = [
      r'https://www\.google\.com/maps',
      r'https://maps\.google\.com',
      r'https://goo\.gl/maps',
      r'https://maps\.app\.goo\.gl'
    ];
    return validPatterns.any((pattern) => RegExp(pattern).hasMatch(url));
  }

  bool _isValidTimeFormat(String time) {
    return RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(time);
  }

  // Pick image
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null) {
        setState(() {
          _destinasiFileName = result.files.single.name;
          if (kIsWeb) {
            _destinasiBytes = result.files.single.bytes!;
          } else {
            _destinasiImage = File(result.files.single.path!);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e', isError: true);
    }
  }

  // Upload image
  Future<String?> _uploadImageToStorage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final filename = 'destinasi_${DateTime.now().millisecondsSinceEpoch}_$_destinasiFileName';
      final storageRef = FirebaseStorage.instance.ref().child('destinasi_images/$filename');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': user.uid, 'uploadTime': DateTime.now().toString()},
      );

      UploadTask uploadTask = kIsWeb 
          ? storageRef.putData(_destinasiBytes!, metadata)
          : storageRef.putFile(_destinasiImage!, metadata);

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  // Submit request
  Future<void> _submitRequest() async {
    if (_hasActiveRequest) {
      _showSnackBar('Anda sudah memiliki permintaan yang sedang diproses.', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnackBar('Harap pilih kategori destinasi', isError: true);
      return;
    }
    if (_destinasiImage == null && _destinasiBytes == null) {
      _showSnackBar('Harap upload foto destinasi', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Anda perlu login terlebih dahulu', isError: true);
        return;
      }

      // Double check for existing requests
      final existingRequest = await FirebaseFirestore.instance
          .collection('destinasi_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'processed'])
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        setState(() {
          _hasActiveRequest = true;
          _requestStatus = existingRequest.docs.first['status'];
        });
        _showSnackBar('Anda sudah memiliki permintaan yang sedang diproses.', isError: true);
        return;
      }

      final imageUrl = await _uploadImageToStorage();
      if (imageUrl == null) throw Exception('Gagal mengupload gambar');

      final hargaTiket = _isDestinasiFree ? 0.0 : double.tryParse(_controllers['harga']!.text.trim()) ?? 0.0;

      await FirebaseFirestore.instance.collection('destinasi_requests').add({
        'namaDestinasi': _controllers['nama']!.text.trim(),
        'lokasi': _controllers['lokasi']!.text.trim(),
        'deskripsi': _controllers['deskripsi']!.text.trim(),
        'kategori': _selectedCategory,
        'hargaTiket': hargaTiket,
        'isFree': _isDestinasiFree,
        'urlMaps': _controllers['urlMaps']!.text.trim(),
        'jamBuka': _controllers['jamBuka']!.text.trim(),
        'jamTutup': _controllers['jamTutup']!.text.trim(),
        'status': 'pending',
         'timestamp': DateTime.now(),
        'imageUrl': imageUrl,
        'userId': _userId,
        'username': _username,
        'email': _email,
      });

      setState(() {
        _hasActiveRequest = true;
        _requestStatus = 'pending';
      });

      _showSnackBar('Permintaan berhasil dikirim! Akan diproses dalam 1-3 hari kerja.', isError: false);
      
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      });
    } catch (e) {
      _showSnackBar('Gagal mengirim permintaan: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _hasActiveRequest
              ? _buildActiveRequestView()
              : _buildRequestForm(),
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E7D32), size: 20),
        ),
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage())),
      ),
      title: Text(
        'Tambah Destinasi',
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      centerTitle: true,
    );
  }

  Widget _buildActiveRequestView() {
    final isProcessing = _requestStatus == 'processed';
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isProcessing ? Icons.settings : Icons.access_time_filled_rounded,
                color: isProcessing ? const Color(0xFFFF9800) : const Color(0xFFFBC02D),
                size: 60,
              ),
              const SizedBox(height: 24),
              Text(
                isProcessing ? 'Permintaan Sedang Diproses' : 'Permintaan Sedang Ditinjau',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Anda sudah memiliki permintaan yang sedang diproses. Silakan tunggu hingga proses selesai.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54, height: 1.5),
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
                        'Proses peninjauan biasanya membutuhkan waktu 1-3 hari kerja.',
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2E7D32)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('KEMBALI KE BERANDA', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 24),
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildOperationalSection(),
            const SizedBox(height: 24),
            _buildImageUploadSection(),
            const SizedBox(height: 24),
            _buildTermsNotice(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

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
            'Tambah Destinasi Wisata',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Lengkapi data berikut untuk mengajukan destinasi wisata baru. Permintaan akan diproses dalam 1-3 hari kerja.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildFormSection(
      title: 'Informasi Dasar',
      icon: Icons.place_outlined,
      children: [
        _buildTextField('nama', 'Nama Destinasi', 'Masukkan nama destinasi', Icons.tour_outlined),
        _buildTextField('lokasi', 'Lokasi', 'Masukkan alamat lengkap', Icons.location_on_outlined),
        _buildCategoryDropdown(),
        _buildTextField('urlMaps', 'URL Google Maps', 'https://www.google.com/maps/...', Icons.map_outlined),
        _buildTextField('deskripsi', 'Deskripsi', 'Jelaskan tentang destinasi wisata', Icons.description_outlined, maxLines: 3),
      ],
    );
  }

Widget _buildOperationalSection() {
  return _buildFormSection(
    title: 'Informasi Operasional',
    icon: Icons.schedule_outlined,
    children: [
      Row(
        children: [
          Expanded(child: _buildTimeField('jamBuka', 'Jam Buka', Icons.access_time)),
          const SizedBox(width: 16),
          Expanded(child: _buildTimeField('jamTutup', 'Jam Tutup', Icons.access_time_filled)),
        ],
      ),
      _buildFreeCheckbox(),
      if (!_isDestinasiFree)
        _buildTextField('harga', 'Harga Tiket (Rp)', 'Contoh: 25000', Icons.monetization_on_outlined),
    ],
  );
}

Widget _buildTimeField(String key, String label, IconData icon) {
  return TextFormField(
    controller: _controllers[key],
    decoration: InputDecoration(
      labelText: label,
      hintText: 'Pilih waktu',
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      suffixIcon: IconButton(
        icon: const Icon(Icons.access_time),
        onPressed: () => _selectTime(context, key),
      ),
    ),
    readOnly: true,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Mohon pilih $label';
      }
      return null;
    },
  );
}

Future<void> _selectTime(BuildContext context, String key) async {
  TimeOfDay? selectedTime = await showTimePicker(
    context: context,
    initialTime: _parseTimeFromController(key) ?? TimeOfDay.now(),
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );

  if (selectedTime != null) {
    String formattedTime = _formatTime(selectedTime);
    _controllers[key]?.text = formattedTime;
    
    // Validasi logika jam buka dan tutup
    _validateOperatingHours();
  }
}

String _formatTime(TimeOfDay time) {
  String hour = time.hour.toString().padLeft(2, '0');
  String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay? _parseTimeFromController(String key) {
  String? timeText = _controllers[key]?.text;
  if (timeText == null || timeText.isEmpty) return null;
  
  try {
    List<String> parts = timeText.split(':');
    if (parts.length == 2) {
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
  } catch (e) {
    return null;
  }
  return null;
}

void _validateOperatingHours() {
  String? jamBuka = _controllers['jamBuka']?.text;
  String? jamTutup = _controllers['jamTutup']?.text;
  
  if (jamBuka != null && jamTutup != null && 
      jamBuka.isNotEmpty && jamTutup.isNotEmpty) {
    
    TimeOfDay? bukaTime = _parseTimeFromController('jamBuka');
    TimeOfDay? tutupTime = _parseTimeFromController('jamTutup');
    
    if (bukaTime != null && tutupTime != null) {
      // Konversi ke menit untuk perbandingan
      int bukaMinutes = bukaTime.hour * 60 + bukaTime.minute;
      int tutupMinutes = tutupTime.hour * 60 + tutupTime.minute;
      
      if (bukaMinutes >= tutupMinutes) {
        // Tampilkan peringatan jika jam buka >= jam tutup
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jam tutup harus lebih dari jam buka'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

// Alternative: Dropdown time selection (jika prefer dropdown)
Widget _buildTimeDropdownField(String key, String label, IconData icon) {
  return DropdownButtonFormField<String>(
    value: _controllers[key]?.text.isNotEmpty == true ? _controllers[key]?.text : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    items: _generateTimeOptions(),
    onChanged: (String? value) {
      if (value != null) {
        _controllers[key]?.text = value;
        _validateOperatingHours();
      }
    },
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Mohon pilih $label';
      }
      return null;
    },
  );
}

List<DropdownMenuItem<String>> _generateTimeOptions() {
  List<DropdownMenuItem<String>> items = [];
  
  // Generate jam dari 00:00 sampai 23:30 dengan interval 30 menit
  for (int hour = 0; hour < 24; hour++) {
    for (int minute = 0; minute < 60; minute += 30) {
      String timeString = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      items.add(
        DropdownMenuItem<String>(
          value: timeString,
          child: Text(timeString),
        ),
      );
    }
  }
  
  return items;
}

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kategori Destinasi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            hintText: 'Pilih kategori destinasi',
            prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF2E7D32)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          validator: (value) => value == null ? 'Harap pilih kategori destinasi' : null,
        ),
      ],
    );
  }

  Widget _buildFreeCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isDestinasiFree,
          activeColor: const Color(0xFF2E7D32),
          onChanged: (value) {
            setState(() {
              _isDestinasiFree = value ?? false;
              if (_isDestinasiFree) _controllers['harga']!.clear();
            });
          },
        ),
        Text(
          'Destinasi Gratis (Tidak Berbayar)',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return _buildFormSection(
      title: 'Upload Foto Destinasi',
      icon: Icons.image_outlined,
      children: [
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_destinasiImage == null && _destinasiBytes == null) 
                    ? Colors.grey.shade300 
                    : const Color(0xFF2E7D32),
              ),
            ),
            child: _buildImagePreview(),
          ),
        ),
        if (_destinasiFileName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'File: $_destinasiFileName',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF2E7D32)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTermsNotice() {
    return Container(
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
              'Dengan mengirim permintaan ini, Anda menyetujui bahwa data yang diberikan akan digunakan untuk proses verifikasi destinasi.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF558B2F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
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
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
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
                Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 16), 
                child: child,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label, String hint, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controllers[key]!,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
          ),
          maxLines: maxLines,
          validator: (value) => _getValidator(key, value),
        ),
      ],
    );
  }

  String? _getValidator(String key, String? value) {
    if (value?.isEmpty == true) return '${_getFieldLabel(key)} tidak boleh kosong';
    
    switch (key) {
      case 'urlMaps':
        return !_isValidMapsUrl(value!) ? 'URL harus berupa link Google Maps yang valid' : null;
      case 'deskripsi':
        return value!.length < 20 ? 'Deskripsi terlalu pendek (min 20 karakter)' : null;
      case 'jamBuka':
      case 'jamTutup':
        return !_isValidTimeFormat(value!) ? 'Format: HH:MM (contoh: 08:00)' : null;
      case 'harga':
        if (!_isDestinasiFree && double.tryParse(value!) == null) {
          return 'Harga tiket harus berupa angka';
        }
        return null;
      default:
        return null;
    }
  }

  String _getFieldLabel(String key) {
    final labels = {
      'nama': 'Nama destinasi',
      'lokasi': 'Lokasi',
      'deskripsi': 'Deskripsi',
      'harga': 'Harga tiket',
      'urlMaps': 'URL Maps',
      'jamBuka': 'Jam buka',
      'jamTutup': 'Jam tutup',
    };
    return labels[key] ?? key;
  }

  Widget _buildImagePreview() {
    if (_destinasiImage != null || _destinasiBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.memory(_destinasiBytes!, fit: BoxFit.cover, width: double.infinity)
                : Image.file(_destinasiImage!, fit: BoxFit.cover, width: double.infinity),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _destinasiImage = null;
                  _destinasiBytes = null;
                  _destinasiFileName = null;
                });
              },
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_a_photo_rounded, size: 36, color: Color(0xFF2E7D32)),
        const SizedBox(height: 12),
        Text(
          'Tap untuk upload foto destinasi',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
        ),
      ],
    );
  }
}