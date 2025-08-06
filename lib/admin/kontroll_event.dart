import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:guide_me/user/home.dart';

class KontrollEventPage extends StatefulWidget {
  const KontrollEventPage({super.key});

  @override
  State<KontrollEventPage> createState() => KontrollEventPageState();
}

class KontrollEventPageState extends State<KontrollEventPage> {
  // Controllers
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _tanggalMulaiController = TextEditingController();
  final TextEditingController _tanggalSelesaiController =
      TextEditingController();
  final TextEditingController _waktuMulaiController = TextEditingController();
  final TextEditingController _waktuSelesaiController = TextEditingController();
  final TextEditingController _urlMapsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Image data
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // State
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isFree = true;
  String _selectedKategori = 'Konser';
  List<DocumentSnapshot> _events = [];
  String? _editingId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _categories = [
    'Konser',
    'Festival',
    'Pameran',
    'Seminar',
    'Workshop',
    'Olahraga',
    'Kuliner',
    'Budaya',
    'Edukasi',
    'Teknologi',
    'Bisnis',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _lokasiController.dispose();
    _hargaController.dispose();
    _tanggalMulaiController.dispose();
    _tanggalSelesaiController.dispose();
    _waktuMulaiController.dispose();
    _waktuSelesaiController.dispose();
    _urlMapsController.dispose();
    super.dispose();
  }

  void _checkAuth() {
    if (_auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthRequiredDialog();
      });
    } else {
      _loadEvents(); // Changed to _loadEvents
    }
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.security, color: Color(0xFF2E7D32)),
              const SizedBox(width: 12),
              Text(
                'Login Diperlukan',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            'Anda harus login untuk mengakses halaman ini.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              child: Text(
                'Kembali',
                style: GoogleFonts.poppins(color: const Color(0xFF2E7D32)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _loadEvents() async {
    if (_auth.currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      // First, check and delete expired events
      await _checkAndDeleteExpiredEvents();

      // Then load the remaining events
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('events')
              .orderBy('createdAt', descending: true)
              .get();

      setState(() {
        _events = querySnapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading event: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cleanupExpiredEvents() async {
    setState(() => _isLoading = true);

    await _checkAndDeleteExpiredEvents();

    setState(() => _isLoading = false);

    _showSnackBar('Expired events cleaned up!', isError: false);
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImageName = result.files.single.name;

          if (kIsWeb) {
            _selectedImageBytes = result.files.single.bytes!;
          } else {
            _selectedImage = File(result.files.single.path!);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e', isError: true);
    }
  }

  Future<String?> _uploadImageToStorage() async {
    try {
      final filename =
          'event_${DateTime.now().millisecondsSinceEpoch}_$_selectedImageName';
      final storageRef = FirebaseStorage.instance.ref().child(
        'event_images/$filename',
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(
          _selectedImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        uploadTask = storageRef.putFile(_selectedImage!);
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  void _saveEvent() async {
    // Renamed from _saveDestinasi
    if (_auth.currentUser == null) {
      _showSnackBar('Anda harus login terlebih dahulu', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_editingId == null &&
        _selectedImage == null &&
        _selectedImageBytes == null) {
      _showSnackBar('Harap pilih gambar terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      if (_selectedImage != null || _selectedImageBytes != null) {
        imageUrl = await _uploadImageToStorage();
        if (imageUrl == null) throw Exception('Gagal mengupload gambar');
      }

      final data = {
        'namaEvent': _namaController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'lokasi': _lokasiController.text.trim(),
        'kategori': _selectedKategori,
        'isFree': _isFree,
        'hargaTiket': _isFree ? 0 : int.tryParse(_hargaController.text) ?? 0,
        'tanggalMulai': _tanggalMulaiController.text.trim(), // Added
        'tanggalSelesai': _tanggalSelesaiController.text.trim(), // Added
        'waktuMulai': _waktuMulaiController.text.trim(),
        'waktuSelesai': _waktuSelesaiController.text.trim(),
        'urlMaps': _urlMapsController.text.trim(),
        'createdBy': _auth.currentUser!.uid,
      };

      if (imageUrl != null) data['imageUrl'] = imageUrl;

      if (_editingId != null) {
        data['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('events')
            .doc(_editingId)
            .update(data);
        _showSnackBar(
          'Event berhasil diupdate!',
          isError: false,
        ); // Changed text
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('events').add(data);
        _showSnackBar('Event berhasil ditambahkan!', isError: false);
      }

      _clearForm();
      _loadEvents(); // Changed to _loadEvents
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Gagal menyimpan Event: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _startPeriodicCheck() {
    // Check for expired events every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAndDeleteExpiredEvents();
    });
  }

  Future<void> _checkAndDeleteExpiredEvents() async {
    if (_auth.currentUser == null) return;

    try {
      final now = DateTime.now();
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('events').get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tanggalSelesai = data['tanggalSelesai'] as String?;

        if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) {
          try {
            // Parse the date string (assuming DD/MM/YYYY format)
            final dateParts = tanggalSelesai.split('/');
            if (dateParts.length == 3) {
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);

              final eventEndDate = DateTime(year, month, day);

              // Check if event has ended (add 1 day to include the end date)
              if (now.isAfter(eventEndDate.add(const Duration(days: 1)))) {
                // Delete the event
                await FirebaseFirestore.instance
                    .collection('events')
                    .doc(doc.id)
                    .delete();

                // Try to delete the image from storage
                final imageUrl = data['imageUrl'] as String?;
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  try {
                    await FirebaseStorage.instance
                        .refFromURL(imageUrl)
                        .delete();
                  } catch (e) {
                    // Ignore storage deletion errors
                    print('Error deleting image: $e');
                  }
                }

                print('Deleted expired event: ${data['namaEvent']}');
              }
            }
          } catch (e) {
            print('Error parsing date for event ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      print('Error checking expired events: $e');
    }
  }

  void _editEvent(DocumentSnapshot doc) {
    // Renamed from _editDestinasi
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingId = doc.id;
      _namaController.text = data['namaEvent'] ?? '';
      _deskripsiController.text = data['deskripsi'] ?? '';
      _lokasiController.text = data['lokasi'] ?? '';
      _selectedKategori =
          data['kategori'] ??
          'Konser'; // Default to a more event-centric category
      _isFree = data['isFree'] ?? true;
      _hargaController.text = data['hargaTiket']?.toString() ?? '0';
      _tanggalMulaiController.text =
          data['tanggalMulai'] ?? ''; // Corrected field name
      _tanggalSelesaiController.text =
          data['tanggalSelesai'] ?? ''; // Corrected field name
      _waktuMulaiController.text = data['waktuMulai'] ?? '';
      _waktuSelesaiController.text = data['waktuSelesai'] ?? '';
      _urlMapsController.text = data['urlMaps'] ?? '';
    });
    _showEventModal(); // Changed to _showEventModal
  }

  void _deleteEvent(String eventId, String imageUrl) async {
    // Renamed from _deleteDestinasi
    if (_auth.currentUser == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Hapus Event',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus event ini?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Hapus',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .delete();
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Ignore storage deletion errors
        }
        _loadEvents(); // Changed to _loadEvents
        _showSnackBar('Event berhasil dihapus!', isError: false);
      } catch (e) {
        _showSnackBar('Gagal menghapus event: $e', isError: true);
      }
    }
  }

  void _clearForm() {
    _namaController.clear();
    _deskripsiController.clear();
    _lokasiController.clear();
    _hargaController.clear();
    _tanggalMulaiController.clear();
    _tanggalSelesaiController.clear();
    _waktuMulaiController.clear();
    _waktuSelesaiController.clear();
    _urlMapsController.clear();
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _editingId = null;
      _isFree = true;
      _selectedKategori = 'Konser'; // Default to a more event-centric category
    });
  }

  void _showEventModal() {
    // Renamed from _showDestinasiModal
    if (_auth.currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEventModal(),
    );
  }

  Widget _buildEventModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _editingId != null ? Icons.edit : Icons.add_location,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _editingId != null ? 'Edit Event' : 'Tambah Event Baru',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image upload
                        Text(
                          'Gambar Event ',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            await _pickImage();
                            setModalState(() {});
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child:
                                (_selectedImage != null ||
                                        _selectedImageBytes != null)
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child:
                                          kIsWeb
                                              ? Image.memory(
                                                _selectedImageBytes!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 150,
                                              )
                                              : Image.file(
                                                _selectedImage!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 150,
                                              ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 40,
                                          color: Color(0xFF2E7D32),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap untuk pilih gambar',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nama Event
                        _buildTextField(
                          'Nama Event',
                          _namaController,
                          Icons
                              .event, // Changed icon to a more event-related one
                          'Masukkan nama event',
                        ),
                        const SizedBox(height: 16),

                        // Deskripsi
                        _buildTextField(
                          'Deskripsi',
                          _deskripsiController,
                          Icons.description,
                          'Masukkan deskripsi event',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Lokasi
                        _buildTextField(
                          'Lokasi',
                          _lokasiController,
                          Icons.location_on,
                          'Masukkan lokasi event',
                        ),
                        const SizedBox(height: 16),

                        // Kategori
                        Text(
                          'Kategori',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedKategori,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.category,
                              color: Color(0xFF2E7D32),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                          ),
                          items:
                              _categories
                                  .map(
                                    (kategori) => DropdownMenuItem(
                                      value: kategori,
                                      child: Text(kategori),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() => _selectedKategori = value!);
                            setModalState(() => _selectedKategori = value!);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Harga
                        Row(
                          children: [
                            Text(
                              'Gratis',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch(
                              value: _isFree,
                              onChanged: (value) {
                                setState(() => _isFree = value);
                                setModalState(() => _isFree = value);
                              },
                              activeColor: const Color(0xFF2E7D32),
                            ),
                          ],
                        ),
                        if (!_isFree) ...[
                          const SizedBox(height: 8),
                          _buildTextField(
                            'Harga Tiket',
                            _hargaController,
                            Icons.attach_money,
                            'Masukkan harga tiket',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Tanggal dan Waktu
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Tanggal Mulai',
                                _tanggalMulaiController,
                                Icons.calendar_today,
                                'DD/MM/YYYY',
                                keyboardType: TextInputType.datetime,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                'Tanggal Selesai',
                                _tanggalSelesaiController,
                                Icons.calendar_today_outlined,
                                'DD/MM/YYYY',
                                keyboardType: TextInputType.datetime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Waktu Mulai',
                                _waktuMulaiController,
                                Icons.access_time,
                                'HH:MM',
                                keyboardType: TextInputType.datetime,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                'Waktu Selesai',
                                _waktuSelesaiController,
                                Icons.access_time_filled,
                                'HH:MM',
                                keyboardType: TextInputType.datetime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // URL Maps
                        _buildTextField(
                          'URL Maps',
                          _urlMapsController,
                          Icons.map,
                          'Masukkan URL Google Maps',
                        ),
                        const SizedBox(height: 32),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : _saveEvent, // Changed to _saveEvent
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      _editingId != null
                                          ? 'UPDATE EVENT'
                                          : 'TAMBAH EVENT', // Changed text
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label tidak boleh kosong';
            }
            return null;
          },
        ),
      ],
    );
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
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

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
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
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
        title: Text(
          'Kelola Event',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services, color: Color(0xFF2E7D32)),
            onPressed: _cleanupExpiredEvents,
            tooltip: 'Cleanup Expired Events',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              )
              : _events
                  .isEmpty // Renamed from _destinasi
              ? _buildEmptyState()
              : _buildEventList(), // Renamed from _buildDestinasiList
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _clearForm();
          _showEventModal(); // Changed to _showEventModal
        },
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Tambah',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 80,
            color: Colors.grey[400],
          ), // Changed icon
          const SizedBox(height: 16),
          Text(
            'Belum ada event', // Changed text
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap tombol + untuk menambah event baru', // Changed text
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    // Renamed from _buildDestinasiList
    return RefreshIndicator(
      onRefresh: () async => _loadEvents(), // Changed to _loadEvents
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length, // Renamed from _destinasi
        itemBuilder: (context, index) {
          final event = _events[index]; // Renamed from destinasi
          final data = event.data() as Map<String, dynamic>;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Image.network(
                    data['imageUrl'] ?? '',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['namaEvent'] ??
                                  'No Name', // Changed to namaEvent
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editEvent(event); // Changed to _editEvent
                              } else if (value == 'delete') {
                                _deleteEvent(
                                  event.id, // Changed from destinasi.id
                                  data['imageUrl'] ?? '',
                                );
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit_outlined,
                                          color: Color(0xFF2E7D32),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Edit',
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Hapus',
                                          style: GoogleFonts.poppins(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['deskripsi'] ?? 'No Description',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['lokasi'] ?? 'No Location',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['kategori'] ?? 'No Category',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (data['isFree'] ?? true)
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (data['isFree'] ?? true)
                                  ? 'Gratis'
                                  : 'Rp ${data['hargaTiket'] ?? 0}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    (data['isFree'] ?? true)
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
