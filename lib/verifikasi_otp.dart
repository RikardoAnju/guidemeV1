import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:guide_me/Resetpassword.dart';
import 'package:guide_me/services/email_service.dart';

class VerifikasiOtp extends StatefulWidget {
  final String email;
  final String otp;
  final String userId;
  final String? temporaryResetToken;
  final String resetToken;

  const VerifikasiOtp({
    super.key,
    required this.email,
    required this.userId,
    this.otp = '',
    this.temporaryResetToken,
    required this.resetToken,
  });

  @override
  State<VerifikasiOtp> createState() => _VerifikasiOtpState();
}

class _VerifikasiOtpState extends State<VerifikasiOtp> {
  final TextEditingController _otpController = TextEditingController();
  late String _generatedOtp;
  int _remainingSeconds = 300;
  Timer? _timer;
  bool _isOtpExpired = false;
  bool _isLoading = false;
  bool _isResending = false;
  bool _isOtpComplete = false;

  @override
  void initState() {
    super.initState();
    _generatedOtp = widget.otp;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = 300;
    _isOtpExpired = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isOtpExpired = true;
          _timer?.cancel();
        }
      });
    });
  }

  String _formatTimeRemaining() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF5ABB4D),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarningDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Peringatan!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 10,
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showMessage('Masukkan kode OTP terlebih dahulu', isError: true);
      return;
    }

    if (_otpController.text.length < 6) {
      _showMessage('Kode OTP harus 6 digit', isError: true);
      return;
    }

    if (_isOtpExpired) {
      _showWarningDialog('Kode OTP telah kedaluwarsa. Silakan kirim ulang OTP.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();

      if (!userDoc.exists) {
        _showWarningDialog('Akun tidak ditemukan.');
        setState(() => _isLoading = false);
        return;
      }

      final data = userDoc.data()!;
      final storedOtp = data['otp'] ?? '';
      final expiresAtStr = data['expiresAt'] ?? '';
      final expiresAt = DateTime.tryParse(expiresAtStr) ?? DateTime.now().subtract(const Duration(minutes: 1));

      if (DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _isOtpExpired = true;
          _timer?.cancel();
          _isLoading = false;
        });
        _showWarningDialog('Kode OTP telah kedaluwarsa. Silakan kirim ulang OTP.');
        return;
      }

      if (_otpController.text == storedOtp) {
        _showMessage('Verifikasi OTP berhasil');

        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'otp': FieldValue.delete(),
          'expiresAt': FieldValue.delete(),
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Resetpassword(
              userId: widget.userId,
              email: widget.email,
              resetToken: widget.resetToken,
            ),
          ),
        );
      } else {
        _showWarningDialog('Kode OTP tidak valid. Periksa kembali kode yang Anda masukkan.');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showWarningDialog('Terjadi kesalahan saat verifikasi: ${e.toString()}');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    try {
      final newOtp = _generateSecureOtp();
      final expiryTime = DateTime.now().add(const Duration(minutes: 5));

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'otp': newOtp,
        'expiresAt': expiryTime.toIso8601String(),
      });

      await EmailService.sendOtpEmail(widget.email, newOtp);

      if (!mounted) return;
      setState(() {
        _generatedOtp = newOtp;
        _isOtpExpired = false;
        _remainingSeconds = 300;
        _otpController.clear();
        _isOtpComplete = false;
      });

      _startTimer();
      _showMessage('Kode OTP baru telah dikirim ke ${widget.email}');
    } catch (e) {
      if (mounted) _showWarningDialog('Gagal mengirim ulang OTP: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _generateSecureOtp() {
    final int seed = DateTime.now().millisecondsSinceEpoch;
    final int code = (100000 + (seed % 900000));
    return code.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF5ABB4D);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Stack(
            children: [
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    const Text(
                      "VERIFIKASI OTP",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Masukkan kode OTP yang dikirim ke",
                              style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.email,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            PinCodeTextField(
                              appContext: context,
                              length: 6,
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              animationType: AnimationType.fade,
                              autoDisposeControllers: false,
                              enableActiveFill: true,
                              onChanged: (value) {
                                setState(() {
                                  _isOtpComplete = value.length == 6;
                                });
                              },
                              // Menghilangkan pemanggilan otomatis verifikasi
                              pinTheme: PinTheme(
                                shape: PinCodeFieldShape.box,
                                borderRadius: BorderRadius.circular(8),
                                fieldHeight: 55,
                                fieldWidth: 45,
                                activeFillColor: isDarkMode ? Colors.grey[700] : Colors.white,
                                inactiveFillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                                selectedFillColor: isDarkMode ? Colors.grey[600] : Colors.grey[200],
                                activeColor: primaryColor,
                                inactiveColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                                selectedColor: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: (_isOtpExpired ? Colors.red : primaryColor).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isOtpExpired ? Icons.timer_off : Icons.timer,
                                    size: 18,
                                    color: _isOtpExpired ? Colors.red : primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOtpExpired
                                        ? "Kode OTP telah kedaluwarsa"
                                        : "Berlaku: ${_formatTimeRemaining()}",
                                    style: TextStyle(
                                      color: _isOtpExpired ? Colors.red : primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: (_isLoading || (_isOtpExpired && !_isResending)) ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                                  disabledForegroundColor: Colors.grey[400],
                                  elevation: 5,
                                  shadowColor: primaryColor.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Text("VERIFIKASI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Tidak menerima kode? ",
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: (_isResending || !_isOtpExpired) ? null : _resendOtp,
                                  icon: _isResending
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                                      : Icon(Icons.refresh, size: 16, color: _isOtpExpired ? primaryColor : Colors.grey),
                                  label: Text(
                                    "Kirim Ulang",
                                    style: TextStyle(
                                      color: _isOtpExpired ? primaryColor : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}