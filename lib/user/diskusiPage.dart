import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:guide_me/admin/adminpage.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:path/path.dart' as p;
import 'home.dart';

class DiscussPage extends StatefulWidget {
  final String? userRole;

  const DiscussPage({Key? key, this.userRole}) : super(key: key);

  @override
  State<DiscussPage> createState() => _DiscussPageState();
}

class _DiscussPageState extends State<DiscussPage> {
  final TextEditingController _postController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? currentUserId;
  String? currentUserName;
  String? currentUserProfileImageUrl;

  bool _isLoading = false;
  // Fix: Declare _isCommentLoading
  bool _isCommentLoading = false;
  String _sortBy = 'timestamp';

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedGifUrl;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => currentUserId = user.uid);

      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            currentUserName =
                userData?['username'] ?? user.email?.split('@')[0] ?? user.uid;
            currentUserProfileImageUrl = userData?['profileImageUrl'];
          });
        } else {
          setState(() {
            currentUserName = user.email?.split('@')[0] ?? user.uid;
            currentUserProfileImageUrl = null;
          });
        }
      } catch (e) {
        setState(() {
          currentUserName = user.email?.split('@')[0] ?? user.uid;
          currentUserProfileImageUrl = null;
        });
      }
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

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Akses Dibatasi',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Silakan login untuk berinteraksi di forum.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(color: const Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
    );
  }

  void _createPost() async {
    if (currentUserId == null) {
      _showLoginDialog();
      return;
    }

    if (_postController.text.trim().isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null &&
        _selectedGifUrl == null) {
      return;
    }

    setState(() => _isLoading = true);

    String? imageUrl;
    if (_selectedImage != null || _selectedImageBytes != null) {
      imageUrl = await _uploadImage(_selectedImage, _selectedImageBytes);
    }

    try {
      await _firestore.collection('forum_posts').add({
        'content': _postController.text.trim(),
        'userId': currentUserId,
        'username': currentUserName ?? 'Anonymous',
        'profileImageUrl': currentUserProfileImageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'gifUrl': _selectedGifUrl,
        'likedBy': [],
        'commentCount': 0,
      });

      _showSnackBar('Postingan berhasil dikirim!', isError: false);
      _clearInputs();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearInputs() {
    setState(() {
      _postController.clear();
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedGifUrl = null;
    });
  }

  void _toggleLikePost(String postId, List<dynamic> likedBy) async {
    if (currentUserId == null) {
      _showLoginDialog();
      return;
    }

    final postRef = _firestore.collection('forum_posts').doc(postId);
    final isLiked = likedBy.contains(currentUserId);

    try {
      await postRef.update({
        'likedBy':
            isLiked
                ? FieldValue.arrayRemove([currentUserId])
                : FieldValue.arrayUnion([currentUserId]),
      });
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _showCommentsDialog(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              color: const Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Komentar',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        // Fix: Pass scrollController and remove duplicate call
                        child: _buildCommentsList(postId, scrollController),
                      ),
                      // Remove the duplicate _buildCommentsList(postId) call here
                      _buildCommentInput(
                        postId,
                      ), // Add this line to include the comment input
                    ],
                  ),
                ),
          ),
    );
  }

  void _addComment(String postId) async {
    if (currentUserId == null) {
      _showLoginDialog();
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isCommentLoading = true);

    try {
      // Tambah komentar ke subcollection
      await _firestore
          .collection('forum_posts')
          .doc(postId)
          .collection('comments')
          .add({
            'content': _commentController.text.trim(),
            'userId': currentUserId,
            'username': currentUserName ?? 'Anonymous',
            'profileImageUrl': currentUserProfileImageUrl,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Update comment count di post utama
      await _firestore.collection('forum_posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      _commentController.clear();
      _showSnackBar('Komentar berhasil ditambahkan!', isError: false);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isCommentLoading = false);
    }
  }

  Widget _buildCommentsList(String postId, ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('forum_posts')
              .doc(postId)
              .collection('comments')
              .orderBy('timestamp', descending: false)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        final comments = snapshot.data?.docs ?? [];

        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Belum ada komentar',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Jadilah yang pertama berkomentar!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            var commentData = comments[index].data() as Map<String, dynamic>;
            return _buildCommentItem(commentData, comments[index].id, postId);
          },
        );
      },
    );
  }

  // ========== METHOD UNTUK MENAMPILKAN ITEM KOMENTAR ==========
  Widget _buildCommentItem(
    Map<String, dynamic> commentData,
    String commentId,
    String postId,
  ) {
    String timeAgo = '';
    if (commentData['timestamp'] != null) {
      DateTime timestamp = (commentData['timestamp'] as Timestamp).toDate();
      timeAgo = _getTimeAgo(timestamp);
    }
    bool isMyComment = currentUserId == commentData['userId'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2E7D32),
            backgroundImage:
                commentData['profileImageUrl'] != null
                    ? NetworkImage(commentData['profileImageUrl'])
                    : null,
            child:
                commentData['profileImageUrl'] == null
                    ? Text(
                      (commentData['username'] ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    Colors.grey.shade100, // Memberi latar belakang abu-abu muda
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        commentData['username'] ?? 'Anonymous',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87, // Username berwarna hitam
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600], // Waktu tetap abu-abu
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (isMyComment)
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteComment(postId, commentId);
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Hapus',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    commentData['content'].toString(),
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== METHOD UNTUK INPUT KOMENTAR ==========
  Widget _buildCommentInput(String postId) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2E7D32),
            backgroundImage:
                currentUserProfileImageUrl != null
                    ? NetworkImage(currentUserProfileImageUrl!)
                    : null,
            child:
                currentUserProfileImageUrl == null
                    ? Text(
                      (currentUserName ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: null,
              maxLength: 200,
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    currentUserId == null
                        ? 'Login untuk berkomentar...'
                        : 'Tulis komentar...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                counterText: '',
                enabled: currentUserId != null,
              ),
              onSubmitted:
                  currentUserId == null ? null : (_) => _addComment(postId),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed:
                currentUserId == null || _isCommentLoading
                    ? null
                    : () => _addComment(postId),
            icon:
                _isCommentLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2E7D32),
                      ),
                    )
                    : const Icon(Icons.send_rounded),
            color: const Color(0xFF2E7D32),
            style: IconButton.styleFrom(
              backgroundColor:
                  currentUserId == null
                      ? Colors.grey[200]
                      : const Color(0xFFE8F5E9),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteComment(String postId, String commentId) async {
    try {
      // Hapus komentar
      await _firestore
          .collection('forum_posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Update comment count
      await _firestore.collection('forum_posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });

      _showSnackBar('Komentar berhasil dihapus!', isError: false);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final Duration difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) return '${difference.inDays} hari yang lalu';
    if (difference.inHours > 0) return '${difference.inHours} jam yang lalu';
    if (difference.inMinutes > 0)
      return '${difference.inMinutes} menit yang lalu';
    return 'Baru saja';
  }

  Query _getPostsQuery() {
    switch (_sortBy) {
      case 'timestamp_lama':
        return _firestore
            .collection('forum_posts')
            .orderBy('timestamp', descending: false);
      case 'likedBy':
        // Order by the size of the likedBy array (more likes first)
        // This requires a custom solution or a field that stores the like count.
        // For simplicity, if 'likedBy' is intended to sort by popularity,
        // you might want to add a 'likesCount' field to your forum_posts collection
        // and increment/decrement it when likes are added/removed.
        // Assuming 'likedBy' sorting attempts to sort by the number of likes,
        // but direct sorting by array length isn't natively supported in Firestore.
        // A common workaround is to maintain a separate 'likeCount' field.
        // For now, it will default to 'timestamp' if 'likedBy' is selected without a proper 'likesCount' field.
        return _firestore
            .collection('forum_posts')
            .orderBy(
              'commentCount',
              descending: true,
            ); // Or 'likesCount' if you implement it
      default:
        return _firestore
            .collection('forum_posts')
            .orderBy('timestamp', descending: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        if (UniversalPlatform.isWeb) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
            _selectedGifUrl = null;
          });
        } else {
          setState(() {
            _selectedImage = File(picked.path);
            _selectedImageBytes = null;
            _selectedGifUrl = null;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Gagal memilih gambar: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deletePost(String postId, Map<String, dynamic> postData) async {
    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          ),
    );

    try {
      // 1. Hapus gambar dari Firebase Storage jika ada
      final imageUrl = postData['imageUrl'];
      final gifUrl = postData['gifUrl'];
      if (imageUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Abaikan jika file tidak ditemukan, mungkin sudah terhapus
          debugPrint("Error deleting storage file for imageUrl: $e");
        }
      }
      if (gifUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(gifUrl).delete();
        } catch (e) {
          // Abaikan jika file tidak ditemukan
          debugPrint("Error deleting storage file for gifUrl: $e");
        }
      }

      // 2. Hapus semua komentar di subcollection
      final commentsSnapshot =
          await _firestore
              .collection('forum_posts')
              .doc(postId)
              .collection('comments')
              .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 3. Hapus dokumen post utama
      await _firestore.collection('forum_posts').doc(postId).delete();

      // Tutup dialog loading
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar('Postingan berhasil dihapus!', isError: false);
    } catch (e) {
      // Tutup dialog loading
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar(
        'Gagal menghapus postingan: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showDeleteConfirmationDialog(
    String postId,
    Map<String, dynamic> postData,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Konfirmasi Hapus',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus postingan ini? Tindakan ini tidak dapat diurungkan.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Tutup dialog konfirmasi
                  _deletePost(postId, postData);
                },
                child: Text(
                  'Hapus',
                  style: GoogleFonts.poppins(color: Colors.red.shade800),
                ),
              ),
            ],
          ),
    );
  }

  Future<String?> _uploadImage(File? imageFile, Uint8List? imageBytes) async {
    if (imageFile == null && imageBytes == null) return null;

    try {
      String fileName =
          DateTime.now().millisecondsSinceEpoch.toString() +
          (imageFile != null ? p.extension(imageFile.path) : '.png');
      Reference storageRef = FirebaseStorage.instance.ref().child(
        'post_images/$fileName',
      );

      if (imageFile != null) {
        await storageRef.putFile(imageFile);
      } else if (imageBytes != null) {
        await storageRef.putData(imageBytes);
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      _showSnackBar('Gagal mengunggah gambar: ${e.toString()}', isError: true);
      return null;
    }
  }

  Future<void> _pickGif() async {
    try {
      GiphyGif? gif = await GiphyGet.getGif(
        context: context,
        apiKey: "fRv0FYUCeGLferKRiqjh7zKiqN1GJ0SA",
        lang: "id",
      );
      if (gif != null) {
        setState(() {
          _selectedGifUrl = gif.images?.original?.url;
          _selectedImage = null;
          _selectedImageBytes = null;
        });
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil GIF: ${e.toString()}', isError: true);
    }
  }

  Future<void> _pickSticker() async {
    try {
      GiphyGif? sticker = await GiphyGet.getGif(
        context: context,
        apiKey: "fRv0FYUCeGLferKRiqjh7zKiqN1GJ0SA",
        lang: "id",
        tabColor: Colors.teal,
      );
      if (sticker != null) {
        setState(() {
          _selectedGifUrl = sticker.images?.original?.url;
          _selectedImage = null;
          _selectedImageBytes = null;
        });
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil Sticker: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- HEADER MANUAL (PENGGANTI APPBAR) ---
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: Row(
                  children: [
                    // Tombol Kembali
                    Container(
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
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                        onPressed: () {
                          if (widget.userRole == 'admin') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminPage(),
                              ),
                            );
                          } else {
                            // Jika user biasa atau guest, kembali ke HomePage
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomePage(),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    // Judul Halaman
                    Expanded(
                      child: Center(
                        child: Text(
                          'Forum Diskusi',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    // Spacer agar judul tetap di tengah
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // ---------------------------------------------

              // Konten lainnya (input postingan, daftar postingan, dll.)
              _buildPostInputSection(),
              _buildSortSection(),
              _buildPostsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostInputSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, color: Color(0xFF2E7D32)),
                const SizedBox(width: 12),
                Text(
                  'Buat Postingan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _postController,
                  maxLines: 4,
                  maxLength: 500,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Apa yang ingin Anda diskusikan?',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.black87,
                    ), // Diubah
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E7D32),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (_selectedImage != null ||
                    _selectedImageBytes != null ||
                    _selectedGifUrl != null)
                  _buildSelectedMedia(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMediaButton(
                      Icons.image_outlined,
                      'Gambar',
                      _pickImage,
                    ),
                    const SizedBox(width: 8),
                    _buildMediaButton(Icons.gif_box_outlined, 'GIF', _pickGif),
                    const SizedBox(width: 8),
                    _buildMediaButton(
                      Icons.sticky_note_2_outlined,
                      'Sticker',
                      _pickSticker,
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(
                                'Kirim',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
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
  }

  Widget _buildMediaButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF2E7D32)),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE8F5E9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildSelectedMedia() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 80,
      width: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                _selectedGifUrl != null
                    ? Image.network(
                      _selectedGifUrl!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    )
                    : _selectedImage != null
                    ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    )
                    : Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _clearInputs,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Diskusi Terbaru',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              _buildSortButton('timestamp', 'Terbaru'),
              const SizedBox(width: 8),
              _buildSortButton('timestamp_lama', 'Terlama'),
              const SizedBox(width: 8),
              _buildSortButton('likedBy', 'Populer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String sortValue, String label) {
    final bool isSelected = _sortBy == sortValue;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = sortValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPostsQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final QuerySnapshot? postsSnapshot = snapshot.data;

        if (postsSnapshot == null || postsSnapshot.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.forum_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Belum ada diskusi',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mulai diskusi pertama Anda!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: postsSnapshot.docs.length,
          itemBuilder:
              (context, index) => _buildPostItem(postsSnapshot.docs[index]),
        );
      },
    );
  }

  Widget _buildPostItem(DocumentSnapshot post) {
    var postData = post.data() as Map<String, dynamic>?;
    if (postData == null) return const SizedBox.shrink();

    List<dynamic> likedBy = postData['likedBy'] ?? [];
    bool isLiked = currentUserId != null && likedBy.contains(currentUserId);
    // Cek apakah postingan ini milik user yang sedang login
    bool isMyPost = currentUserId == postData['userId'];

    String timeAgo = '';
    if (postData['timestamp'] != null) {
      DateTime timestamp = (postData['timestamp'] as Timestamp).toDate();
      timeAgo = _getTimeAgo(timestamp);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Align to top
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2E7D32),
                  backgroundImage:
                      postData['profileImageUrl'] != null
                          ? NetworkImage(postData['profileImageUrl'])
                          : null,
                  child:
                      postData['profileImageUrl'] == null
                          ? Text(
                            (postData['username'] ?? 'A')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postData['username'] ?? 'Anonymous',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // --- TOMBOL HAPUS (POPUP MENU) ---
                if (isMyPost)
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton<String>(
                      color: Colors.white, // <--- TAMBAHKAN BARIS INI
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmationDialog(post.id, postData);
                        }
                      },
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              padding: EdgeInsets.zero,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                color: Colors.grey.withOpacity(
                                  0.1,
                                ), // Warna latar belakang merah muda
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hapus Postingan',
                                      style: GoogleFonts.poppins(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (postData['content'] != null &&
                postData['content'].toString().isNotEmpty)
              Text(
                postData['content'].toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            if (postData['imageUrl'] != null || postData['gifUrl'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    postData['imageUrl'] ?? postData['gifUrl'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => const SizedBox(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap:
                      currentUserId == null
                          ? _showLoginDialog
                          : () => _toggleLikePost(post.id, likedBy),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color:
                              isLiked
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${likedBy.length}',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _showCommentsDialog(post.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          // Use the 'commentCount' from postData
                          '${postData['commentCount'] ?? 0} Balas',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _commentController.dispose(); // Dispose the comment controller too
    super.dispose();
  }
}