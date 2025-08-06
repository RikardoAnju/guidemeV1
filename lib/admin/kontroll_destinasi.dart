import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guide_me/user/home.dart';

class KelolaDestinasiPage extends StatefulWidget {
  const KelolaDestinasiPage({super.key});

  @override
  State<KelolaDestinasiPage> createState() => _KelolaDestinasiPageState();
}

class _KelolaDestinasiPageState extends State<KelolaDestinasiPage> {
  // Controllers
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _jamBukaController = TextEditingController();
  final TextEditingController _jamTutupController = TextEditingController();
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
  String _selectedKategori = 'Pantai';
  List<DocumentSnapshot> _destinasi = [];
  String? _editingId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    'Candi',
    'Lainnya'
  ];
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _lokasiController.dispose();
    _hargaController.dispose();
    _jamBukaController.dispose();
    _jamTutupController.dispose();
    _urlMapsController.dispose();
    super.dispose();
  }

  void _checkAuth() {
    if (_auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthRequiredDialog();
      });
    } else {
      _loadDestinasi();
    }
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.security, color: Color(0xFF2E7D32)),
              const SizedBox(width: 12),
              Text('Login Diperlukan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text('Anda harus login untuk mengakses halaman ini.', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
              },
              child: Text('Kembali', style: GoogleFonts.poppins(color: const Color(0xFF2E7D32))),
            ),
          ],
        );
      },
    );
  }

  void _loadDestinasi() async {
    if (_auth.currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('destinasi')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _destinasi = querySnapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading destinasi: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null) {
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
      final filename = 'destinasi_${DateTime.now().millisecondsSinceEpoch}_$_selectedImageName';
      final storageRef = FirebaseStorage.instance.ref().child('destinasi_images/$filename');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(_selectedImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        uploadTask = storageRef.putFile(_selectedImage!);
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  void _saveDestinasi() async {
    if (_auth.currentUser == null) {
      _showSnackBar('Anda harus login terlebih dahulu', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_editingId == null && _selectedImage == null && _selectedImageBytes == null) {
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
        'namaDestinasi': _namaController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'lokasi': _lokasiController.text.trim(),
        'kategori': _selectedKategori,
        'isFree': _isFree,
        'hargaTiket': _isFree ? 0 : int.tryParse(_hargaController.text) ?? 0,
        'jamBuka': _jamBukaController.text.trim(),
        'jamTutup': _jamTutupController.text.trim(),
        'urlMaps': _urlMapsController.text.trim(),
        'rating': 0,
        'ratingCount': 0,
        'createdBy': _auth.currentUser!.uid,
      };

      if (imageUrl != null) data['imageUrl'] = imageUrl;

      if (_editingId != null) {
        data['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('destinasi').doc(_editingId).update(data);
        _showSnackBar('Destinasi berhasil diupdate!', isError: false);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('destinasi').add(data);
        _showSnackBar('Destinasi berhasil ditambahkan!', isError: false);
      }

      _clearForm();
      _loadDestinasi();
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Gagal menyimpan destinasi: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _editDestinasi(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingId = doc.id;
      _namaController.text = data['namaDestinasi'] ?? '';
      _deskripsiController.text = data['deskripsi'] ?? '';
      _lokasiController.text = data['lokasi'] ?? '';
      _selectedKategori = data['kategori'] ?? 'Pantai';
      _isFree = data['isFree'] ?? true;
      _hargaController.text = data['hargaTiket']?.toString() ?? '0';
      _jamBukaController.text = data['jamBuka'] ?? '';
      _jamTutupController.text = data['jamTutup'] ?? '';
      _urlMapsController.text = data['urlMaps'] ?? '';
    });
    _showDestinasiModal();
  }

  void _deleteDestinasi(String destinasiId, String imageUrl) async {
    if (_auth.currentUser == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Text('Hapus Destinasi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text('Apakah Anda yakin ingin menghapus destinasi ini?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('destinasi').doc(destinasiId).delete();
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Ignore storage deletion errors
        }
        _loadDestinasi();
        _showSnackBar('Destinasi berhasil dihapus!', isError: false);
      } catch (e) {
        _showSnackBar('Gagal menghapus destinasi: $e', isError: true);
      }
    }
  }

  void _clearForm() {
    _namaController.clear();
    _deskripsiController.clear();
    _lokasiController.clear();
    _hargaController.clear();
    _jamBukaController.clear();
    _jamTutupController.clear();
    _urlMapsController.clear();
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _editingId = null;
      _isFree = true;
      _selectedKategori = 'Pantai';
    });
  }

  void _showDestinasiModal() {
    if (_auth.currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDestinasiModal(),
    );
  }

  Widget _buildDestinasiModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(_editingId != null ? Icons.edit : Icons.add_location, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      _editingId != null ? 'Edit Destinasi' : 'Tambah Destinasi Baru',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white)),
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
                        Text('Gambar Destinasi', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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
                            child: (_selectedImage != null || _selectedImageBytes != null)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: kIsWeb
                                        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover, width: double.infinity, height: 150)
                                        : Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity, height: 150),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo_rounded, size: 40, color: Color(0xFF2E7D32)),
                                      const SizedBox(height: 8),
                                      Text('Tap untuk pilih gambar', style: GoogleFonts.poppins(color: Colors.grey[600])),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nama Destinasi
                        _buildTextField('Nama Destinasi', _namaController, Icons.place, 'Masukkan nama destinasi'),
                        const SizedBox(height: 16),

                        // Deskripsi
                        _buildTextField('Deskripsi', _deskripsiController, Icons.description, 'Masukkan deskripsi destinasi', maxLines: 3),
                        const SizedBox(height: 16),

                        // Lokasi
                        _buildTextField('Lokasi', _lokasiController, Icons.location_on, 'Masukkan lokasi destinasi'),
                        const SizedBox(height: 16),

                        // Kategori
                        Text('Kategori', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedKategori,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.category, color: Color(0xFF2E7D32)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                            ),
                          ),
                          items: _categories.map((kategori) => DropdownMenuItem(value: kategori, child: Text(kategori))).toList(),
                          onChanged: (value) {
                            setState(() => _selectedKategori = value!);
                            setModalState(() => _selectedKategori = value!);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Harga
                        Row(
                          children: [
                            Text('Gratis', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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
                          _buildTextField('Harga Tiket', _hargaController, Icons.attach_money, 'Masukkan harga tiket', keyboardType: TextInputType.number),
                        ],
                        const SizedBox(height: 16),

                        // Jam Operasional
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Jam Buka', _jamBukaController, Icons.access_time, '08:00')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Jam Tutup', _jamTutupController, Icons.access_time_filled, '17:00')),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // URL Maps
                        _buildTextField('URL Maps', _urlMapsController, Icons.map, 'Masukkan URL Google Maps'),
                        const SizedBox(height: 32),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _saveDestinasi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    _editingId != null ? 'UPDATE DESTINASI' : 'TAMBAH DESTINASI',
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, String hint, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))));
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E7D32), size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Kelola Destinasi', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _destinasi.isEmpty
              ? _buildEmptyState()
              : _buildDestinasiList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _clearForm();
          _showDestinasiModal();
        },
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Tambah', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
          Icon(Icons.place_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Belum ada destinasi', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Tap tombol + untuk menambah destinasi baru', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDestinasiList() {
    return RefreshIndicator(
      onRefresh: () async => _loadDestinasi(),
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _destinasi.length,
        itemBuilder: (context, index) {
          final destinasi = _destinasi[index];
          final data = destinasi.data() as Map<String, dynamic>;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  child: Image.network(
                    data['imageUrl'] ?? '',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
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
                            child: Text(data['namaDestinasi'] ?? 'No Name', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editDestinasi(destinasi);
                              } else if (value == 'delete') {
                                _deleteDestinasi(destinasi.id, data['imageUrl'] ?? '');
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, color: Color(0xFF2E7D32)),
                                    const SizedBox(width: 8),
                                    Text('Edit', style: GoogleFonts.poppins()),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text('Hapus', style: GoogleFonts.poppins(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(data['deskripsi'] ?? 'No Description', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(child: Text(data['lokasi'] ?? 'No Location', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Text(data['kategori'] ?? 'No Category', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade700)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (data['isFree'] ?? true) ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (data['isFree'] ?? true) ? 'Gratis' : 'Rp ${data['hargaTiket'] ?? 0}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: (data['isFree'] ?? true) ? Colors.green.shade700 : Colors.orange.shade700,
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