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

class KelolaSliderPage extends StatefulWidget {
  const KelolaSliderPage({super.key});

  @override
  State<KelolaSliderPage> createState() => _KelolaSliderPageState();
}

class _KelolaSliderPageState extends State<KelolaSliderPage> {
  // Controllers for modal form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Image data for modal
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // State tracking
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<DocumentSnapshot> _sliders = [];

  // Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Check authentication
  void _checkAuth() {
    if (_auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthRequiredDialog();
      });
    } else {
      _loadSliders();
    }
  }

  // Show auth required dialog
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

  // Load sliders from Firestore
  void _loadSliders() async {
    if (_auth.currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('sliders')
              .orderBy('timestamp', descending: true)
              .get();

      setState(() {
        _sliders = querySnapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading sliders: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Pick image for slider
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

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

  // Upload image to Firebase Storage
  Future<String?> _uploadImageToStorage() async {
    try {
      final filename =
          'slider_${DateTime.now().millisecondsSinceEpoch}_$_selectedImageName';
      final storageRef = FirebaseStorage.instance.ref().child(
        'slider_images/$filename',
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

  // Add new slider
  void _addSlider() async {
    if (_auth.currentUser == null) {
      _showSnackBar('Anda harus login terlebih dahulu', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null && _selectedImageBytes == null) {
      _showSnackBar('Harap pilih gambar terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload image
      final String? imageUrl = await _uploadImageToStorage();
      if (imageUrl == null) {
        throw Exception('Gagal mengupload gambar');
      }

      // Add slider to Firestore
      await FirebaseFirestore.instance.collection('sliders').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
        'createdBy': _auth.currentUser!.uid,
        'createdByEmail': _auth.currentUser!.email,
      });

      // Clear form
      _clearForm();

      // Reload sliders
      _loadSliders();

      // Close modal
      Navigator.of(context).pop();

      _showSnackBar('Slider berhasil ditambahkan!', isError: false);
    } catch (e) {
      _showSnackBar('Gagal menambahkan slider: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Delete slider
  void _deleteSlider(String sliderId, String imageUrl) async {
    if (_auth.currentUser == null) {
      _showSnackBar('Anda harus login terlebih dahulu', isError: true);
      return;
    }

    // Show confirmation dialog
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
                'Hapus Slider',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus slider ini? Tindakan ini tidak dapat dibatalkan.',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('sliders')
            .doc(sliderId)
            .delete();

        // Delete image from Storage
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Ignore storage deletion errors
        }

        // Reload sliders
        _loadSliders();

        _showSnackBar('Slider berhasil dihapus!', isError: false);
      } catch (e) {
        _showSnackBar('Gagal menghapus slider: $e', isError: true);
      }
    }
  }

  // Clear form data
  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  // Show add slider modal
  void _showAddSliderModal() {
    if (_auth.currentUser == null) {
      _showSnackBar('Anda harus login terlebih dahulu', isError: true);
      return;
    }

    _clearForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddSliderModal(),
    );
  }

  // Build add slider modal
  Widget _buildAddSliderModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Modal header
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
                    const Icon(Icons.add_photo_alternate, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Tambah Slider Baru',
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

              // Modal content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image upload section
                        Text(
                          'Gambar Slider',
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
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    (_selectedImage == null &&
                                            _selectedImageBytes == null)
                                        ? Colors.grey.shade300
                                        : const Color(0xFF2E7D32),
                              ),
                            ),
                            child:
                                (_selectedImage != null ||
                                        _selectedImageBytes != null)
                                    ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child:
                                              kIsWeb
                                                  ? Image.memory(
                                                    _selectedImageBytes!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 200,
                                                  )
                                                  : Image.file(
                                                    _selectedImage!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 200,
                                                  ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: IconButton(
                                            icon: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _selectedImage = null;
                                                _selectedImageBytes = null;
                                                _selectedImageName = null;
                                              });
                                              setModalState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 48,
                                          color: Color(0xFF2E7D32),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Tap untuk pilih gambar',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rekomendasi: 1200x600 px',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title field
                        Text(
                          'Judul Slider',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'Masukkan judul slider',
                            prefixIcon: const Icon(
                              Icons.title,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Judul tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Description field
                        Text(
                          'Deskripsi',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Masukkan deskripsi slider',
                            prefixIcon: const Icon(
                              Icons.description,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Deskripsi tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _addSlider,
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
                                      'TAMBAH SLIDER',
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Kelola Slider',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              )
              : _sliders.isEmpty
              ? _buildEmptyState()
              : _buildSliderList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSliderModal,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada slider',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap tombol + untuk menambah slider baru',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Build slider list
  Widget _buildSliderList() {
    return RefreshIndicator(
      onRefresh: () async => _loadSliders(),
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sliders.length,
        itemBuilder: (context, index) {
          final slider = _sliders[index];
          final data = slider.data() as Map<String, dynamic>;

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
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Image.network(
                    data['imageUrl'] ?? '',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
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

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? 'No Title',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteSlider(
                                  slider.id,
                                  data['imageUrl'] ?? '',
                                );
                              }
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            itemBuilder:
                                (context) => [
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
                        data['description'] ?? 'No Description',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                              color:
                                  (data['isActive'] ?? true)
                                      ? Colors.green.shade100
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (data['isActive'] ?? true) ? 'Aktif' : 'Nonaktif',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    (data['isActive'] ?? true)
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimestamp(data['timestamp']),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
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

  // Format timestamp
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Tidak diketahui';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} menit lalu';
      }
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }
}
