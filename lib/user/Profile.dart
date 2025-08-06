import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'about.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'home.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:guide_me/services/notification_settings.dart';
import 'package:guide_me/feed_back.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Define green color constants
  final Color primaryGreen = const Color(0xFF5ABB4D); // Sea Green
  final Color lightGreen = const Color(0xFF5ABB4D); // Regular Green

  String username = '';
  String email = '';
  String phoneNumber = '';
  String address = '';
  String gender = '';
  String profileImageUrl = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot =
            await _firestore.collection('users').doc(user.uid).get();
        final data = snapshot.data();

        if (data != null) {
          setState(() {
            username = data['username'] ?? '';
            email = data['email'] ?? user.email ?? '';
            phoneNumber = data['phoneNumber'] ?? '';
            address = data['address'] ?? '';
            gender = data['gender'] ?? '';
            profileImageUrl = data['profileImageUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load profile: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'username': newUsername,
      });
      setState(() => username = newUsername);
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedImage == null) return;

      setState(() => isLoading = true);

      final User? user = _auth.currentUser;
      if (user == null) return;

      String downloadUrl;

      if (kIsWeb) {
        // Web platform image upload
        final bytes = await pickedImage.readAsBytes();
        final imageName = 'profile.jpg';
        final ref = _storage.ref().child('images/${user.uid}/$imageName');
        final uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType:
                'image/${path.extension(pickedImage.name).replaceAll('.', '')}',
          ),
        );
        final snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
      } else {
        // Mobile platform image upload
        final imagePath = pickedImage.path;
        final fileName = 'profile.jpg';
        final ref = _storage.ref().child('images/${user.uid}/$fileName');
        final uploadTask = ref.putFile(File(imagePath));
        final snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
      }

      // Update Firestore with new image URL
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        profileImageUrl = downloadUrl;
        isLoading = false;
      });

      _showSuccessSnackBar('Profile picture updated successfully');
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to update profile picture: ${e.toString()}');
    }
  }

  void _showEditUsernameDialog() {
    TextEditingController controller = TextEditingController(text: username);
    final FocusNode focusNode = FocusNode();
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    Future.delayed(const Duration(milliseconds: 100), () {
      focusNode.requestFocus();
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 5,
            backgroundColor: backgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Username',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'New Username',
                      labelStyle: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, size: 18, color: primaryGreen),
                        onPressed: () => controller.clear(),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: primaryGreen, width: 2),
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      hintText: 'Enter new username',
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) async {
                      final newUsername = controller.text.trim();
                      if (newUsername.isNotEmpty && newUsername != username) {
                        await _updateUsername(newUsername);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
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
                        Icon(Icons.info_outline, size: 18, color: primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Username will be displayed on your profile',
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
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final newUsername = controller.text.trim();
                          if (newUsername.isNotEmpty &&
                              newUsername != username) {
                            Navigator.pop(context);
                            setState(() => isLoading = true);
                            try {
                              await _updateUsername(newUsername);
                              _showSuccessSnackBar(
                                'Username changed to $newUsername',
                              );
                            } catch (e) {
                              _showErrorSnackBar(
                                'Failed to change username: ${e.toString()}',
                              );
                            } finally {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
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
    return Consumer(
      builder: (context, themeProvider, child) {
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
            child:
                isLoading && profileImageUrl.isEmpty
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      ),
                    )
                    : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Top header with back button and profile title
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 16,
                              left: 16,
                              right: 16,
                            ),
                            child: Row(
                              children: [
                                // Improved back button
                                Container(
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
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                    ),
                                    onPressed:
                                        () => Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HomePage(),
                                          ),
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'My Profile',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 48,
                                ), // To balance the layout
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Profile Image
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cardColor,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryGreen.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    image:
                                        profileImageUrl.isNotEmpty
                                            ? DecorationImage(
                                              image: NetworkImage(
                                                profileImageUrl,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                            : const DecorationImage(
                                              image: AssetImage(
                                                'assets/images/logo1.png',
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _updateProfileImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: cardColor,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryGreen.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Username display
                          Text(
                            username.isEmpty ? 'Set your username' : username,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Personal Information Card
                          Container(
                            width: contentWidth,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personal Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildProfileField(
                                    icon: Icons.person_outline,
                                    label: 'Username',
                                    value: username,
                                    isEditable: true,
                                    onEditTap: _showEditUsernameDialog,
                                  ),
                                  _buildProfileField(
                                    icon: Icons.email_outlined,
                                    label: 'Email',
                                    value: email,
                                  ),
                                  _buildProfileField(
                                    icon: Icons.phone_outlined,
                                    label: 'Phone Number',
                                    value: phoneNumber,
                                  ),
                                  _buildProfileField(
                                    icon: Icons.location_on_outlined,
                                    label: 'Address',
                                    value: address,
                                  ),
                                  _buildProfileField(
                                    icon: Icons.badge_outlined,
                                    label: 'Gender',
                                    value: gender,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Settings section
                          Container(
                            width: contentWidth,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  const SizedBox(height: 12),
                                 
                                  _buildActionButton(
                                    icon: Icons.notifications_outlined,
                                    label: 'Notification Settings',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const NotificationSettings(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildActionButton(
                                    icon: Icons.feedback_outlined,
                                    label: 'Send Feedback',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const FeedbackScreen())
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildActionButton(
                                    icon: Icons.info_outline,
                                    label: 'About App',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AboutApp())
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required String value,
    bool isEditable = false,
    VoidCallback? onEditTap,
  }) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            Container(
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, size: 16),
                color: Colors.white,
                onPressed: onEditTap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final primaryColor = color ?? primaryGreen;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(isDarkMode ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            // Improved arrow button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
