import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class Resetpassword extends StatefulWidget {
  final String email;
  final String userId;
  final String resetToken;

  const Resetpassword({
    super.key,
    required this.email,
    required this.userId,
    required this.resetToken,
  });

  @override
  ResetpasswordState createState() => ResetpasswordState();
}

class ResetpasswordState extends State<Resetpassword> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Password validation variables
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    debugPrint("Reset Password initialized with:");
    debugPrint("Email: ${widget.email}");
    debugPrint("UserId: ${widget.userId}");
    debugPrint("ResetToken: ${widget.resetToken}");
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    if (!mounted) return;
    final password = _passwordController.text;
    setState(() {
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasMinLength = password.length >= 6;
    });
  }

  bool _isPasswordValid() {
    return _hasUpperCase && _hasLowerCase && _hasNumber && _hasMinLength;
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isPasswordValid()) {
      _showErrorDialog(
        "Password Tidak Valid",
        "Password harus memiliki minimal 6 karakter, huruf besar, huruf kecil, dan angka!",
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog(
        "Konfirmasi Gagal",
        "Password dan konfirmasi password tidak cocok!",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("Sending reset password request to: https://8db2a9074017.ngrok-free.app/reset-password");
      debugPrint("Request body: ${jsonEncode({
        'email': widget.email,
        'newPassword': '[HIDDEN]',
        'userId': widget.userId,
        'resetToken': widget.resetToken,
      })}");

      final response = await http.post(
        Uri.parse('https://8db2a9074017.ngrok-free.app/reset-password'), 
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': widget.email,
          'newPassword': _passwordController.text,
          'userId': widget.userId,
          'resetToken': widget.resetToken,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout', const Duration(seconds: 30));
        },
      );

      setState(() => _isLoading = false);

      debugPrint("Response status code: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['success'] == true || responseData['status'] == 'success') {
            await _updateUserPasswordStatus(true);
            _showSuccessDialog();
          } else {
            _showErrorDialog(
              "Reset Gagal", 
              responseData['message'] ?? "Reset password gagal. Coba lagi."
            );
            await _updateUserPasswordStatus(false);
          }
        } catch (e) {
          // If response is not JSON, assume success if status 200
          await _updateUserPasswordStatus(true);
          _showSuccessDialog();
        }
      } else if (response.statusCode == 400) {
        try {
          final responseData = jsonDecode(response.body);
          _showErrorDialog(
            "Data Tidak Valid", 
            responseData['message'] ?? "Data yang dikirim tidak valid."
          );
        } catch (e) {
          _showErrorDialog("Data Tidak Valid", "Request tidak valid.");
        }
        await _updateUserPasswordStatus(false);
      } else if (response.statusCode == 401) {
        _showErrorDialog(
          "Token Tidak Valid", 
          "Token reset password tidak valid atau sudah kedaluwarsa."
        );
        await _updateUserPasswordStatus(false);
      } else if (response.statusCode == 404) {
        _showErrorDialog(
          "User Tidak Ditemukan", 
          "Email tidak terdaftar dalam sistem."
        );
        await _updateUserPasswordStatus(false);
      } else if (response.statusCode >= 500) {
        _showErrorDialog(
          "Server Error", 
          "Terjadi masalah pada server. Coba lagi nanti."
        );
      } else {
        _showErrorDialog(
          "Gagal", 
          "Reset password gagal. Status: ${response.statusCode}"
        );
        await _updateUserPasswordStatus(false);
      }
    } on TimeoutException catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Timeout error: $e");
      _showErrorDialog(
        "Timeout", 
        "Koneksi timeout. Periksa jaringan internet Anda dan coba lagi."
      );
    } on SocketException catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Socket error: $e");
      _showErrorDialog(
        "Koneksi Error", 
        "Tidak dapat terhubung ke server. Periksa koneksi internet Anda."
      );
    } on FormatException catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Format error: $e");
      _showErrorDialog(
        "Response Error", 
        "Respons server tidak valid."
      );
    } on HttpException catch (e) {
      setState(() => _isLoading = false);
      debugPrint("HTTP error: $e");
      _showErrorDialog(
        "HTTP Error", 
        "Terjadi kesalahan HTTP: ${e.message}"
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("General error: $e");
      _showErrorDialog(
        "Error", 
        "Terjadi kesalahan tidak terduga. Coba lagi nanti."
      );
    }
  }

  Future<void> _updateUserPasswordStatus(bool success) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(widget.userId);
      await userRef.set({
        'passwordReset': true,
        'lastPasswordUpdate': FieldValue.serverTimestamp(),
        'passwordResetSuccess': success,
        'resetAttemptEmail': widget.email,
      }, SetOptions(merge: true));
      
      debugPrint("User password status updated: success=$success");
    } catch (e) {
      debugPrint("Error updating user data: $e");
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Color(0xFF5ABB4D))),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF5ABB4D), size: 80),
                  const SizedBox(height: 10),
                  const Text(
                    "Password berhasil diubah",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Silahkan login dengan password baru Anda",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5ABB4D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "LOGIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF5ABB4D),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 200,
                decoration: const BoxDecoration(
                  color: Color(0xFF5ABB4D),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 50),
                  const Text(
                    "RESET PASSWORD",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Email info display
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5ABB4D).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF5ABB4D).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.email,
                                    color: Color(0xFF5ABB4D),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Reset password untuk: ${widget.email}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5ABB4D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              validator: (value) => (value == null || value.isEmpty)
                                  ? "Password tidak boleh kosong"
                                  : null,
                              decoration: InputDecoration(
                                labelText: "Password Baru",
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF5ABB4D),
                                    width: 2,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Password harus memenuhi kriteria berikut:",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRequirementRow(_hasMinLength, "Minimal 6 karakter"),
                                  _buildRequirementRow(_hasUpperCase, "Minimal satu huruf besar (A-Z)"),
                                  _buildRequirementRow(_hasLowerCase, "Minimal satu huruf kecil (a-z)"),
                                  _buildRequirementRow(_hasNumber, "Minimal satu angka (0-9)"),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Konfirmasi password tidak boleh kosong";
                                }
                                if (value != _passwordController.text) {
                                  return "Password tidak cocok";
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: "Konfirmasi Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF5ABB4D), width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5ABB4D),
                                  disabledBackgroundColor: const Color(0xFF5ABB4D).withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "UBAH PASSWORD",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow(bool isMet, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? const Color(0xFF5ABB4D) : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? const Color(0xFF5ABB4D) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}