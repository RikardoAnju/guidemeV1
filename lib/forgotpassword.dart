import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guide_me/verifikasi_otp.dart';
import 'package:guide_me/services/email_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  Future<void> _sendOtpEmail() async {
    final email = _emailController.text.trim().toLowerCase();

    if (!_isValidEmail(email)) {
      _showWarningDialog("Masukkan email yang valid.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showWarningDialog("Email tidak ditemukan.");
        return;
      }

      final userDoc = query.docs.first;
      final userId = userDoc.id;

      // Generate OTP dan token
      final otp = (100000 + Random().nextInt(900000)).toString();
      final resetToken = "${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999999)}";
      final expiresAt = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      // Simpan data OTP dan token ke Firestore
      await _firestore.collection('users').doc(userId).update({
        'otp': otp,
        'temporaryResetToken': resetToken,
        'expiresAt': expiresAt,
      });

      // Kirim email OTP
      final success = await EmailService.sendOtpEmail(email, otp);

      if (success) {
        // Navigasi ke halaman verifikasi
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifikasiOtp(
              email: email,
              otp: otp,
              userId: userId,
              resetToken: resetToken,
              temporaryResetToken: resetToken,
            ),
          ),
        );
      } else {
        _showWarningDialog("Gagal mengirim OTP. Coba lagi.");
      }
    } catch (e) {
      _showWarningDialog("Terjadi kesalahan: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Peringatan',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 250,
              decoration: const BoxDecoration(
                color:  Color(0xFF5ABB4D),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 100),
                const Text(
                  "FORGOT PASSWORD",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Masukkan email Anda untuk menerima kode OTP",
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtpEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5ABB4D),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "LANJUTKAN",
                                    style: TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}