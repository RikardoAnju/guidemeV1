import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String _selectedCategory = 'Saran';
  final List<String> _categories = [
    'Saran',
    'Laporan Bug',
    'Permintaan Fitur',
    'Lainnya'
  ];

  // Define green color constants from ProfileScreen
  final Color primaryGreen =const Color(0xFF5ABB4D); // Sea Green
  final Color lightGreen = const Color(0xFF5ABB4D); // Regular Green

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Anda harus login untuk mengirim umpan balik');
        return;
      }

      // Get user info to attach to feedback
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Anonim';

     
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'username': username,
        'email': user.email,
        'category': _selectedCategory,
        'message': _feedbackController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', 
        'deviceInfo': {
          'platform': Theme.of(context).platform.toString(),
        }
      });

      _showSuccessSnackBar('Terima kasih atas umpan balik Anda!');
      
   
      _feedbackController.clear();
      
    
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      _showErrorSnackBar('Gagal mengirim feedback: ${e.toString()}');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Size screenSize = MediaQuery.of(context).size;
    final contentWidth = screenSize.width > 600 ? 600.0 : screenSize.width * 0.92;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            
            // Title in center
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Feedback',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        
                        // Header image and info
                        Icon(
                          Icons.feedback_outlined,
                          size: 70,
                          color: primaryGreen,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'Kami menghargai feedback anda',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Pendapat Anda membantu kami meningkatkan aplikasi ini. Silakan bagikan pengalaman, saran, atau laporkan masalah.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Feedback category dropdown
                        Container(
                          width: contentWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kategori ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: primaryGreen.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedCategory,
                                      icon: Icon(Icons.arrow_drop_down, color: primaryGreen),
                                      iconSize: 24,
                                      elevation: 16,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                      dropdownColor: cardColor,
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedCategory = newValue;
                                          });
                                        }
                                      },
                                      items: _categories.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Feedback input area
                        Container(
                          width: contentWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Feedback  Anda',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _feedbackController,
                                  decoration: InputDecoration(
                                    hintText: 'Ceritakan pendapat Anda...',
                                    hintStyle: TextStyle(
                                      color: textColor.withOpacity(0.5),
                                    ),
                                    filled: true,
                                    fillColor: isDarkMode
                                        ? Colors.grey.shade800.withOpacity(0.3)
                                        : Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.red.shade400,
                                        width: 1,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.red.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(20),
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                  maxLines: 6,
                                  minLines: 6,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Mohon masukkan feedback anda';
                                    }
                                    if (value.trim().length < 10) {
                                      return ' minimal 10 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Info box
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryGreen.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: primaryGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'feedback Anda akan dikirim ke tim kami untuk ditinjau',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: primaryGreen,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Submit button
                        Container(
                          width: contentWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitFeedback,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: primaryGreen.withOpacity(0.5),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Kirim feedback',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
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
}