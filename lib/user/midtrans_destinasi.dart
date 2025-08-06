import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'home.dart';

class MidtransPage extends StatefulWidget {
  final String orderId;
  final int amount;
  final int ticketQuantity;
  final Map<String, dynamic> destinasiData;
  final String destinasiId;
  final Map<String, dynamic> currentUserData;

  // Tambahan parameter untuk menentukan destinasi
  final Widget? successDestination;
  final Widget? failureDestination;
  final Widget? cancelDestination;

  const MidtransPage({
    super.key,
    required this.orderId,
    required this.amount,
    required this.ticketQuantity,
    required this.destinasiData,
    required this.destinasiId,
    required this.currentUserData,
    // Parameter opsional untuk destinasi khusus
    this.successDestination,
    this.failureDestination,
    this.cancelDestination,
  });

  @override
  MidtransPageState createState() => MidtransPageState();
}

class MidtransPageState extends State<MidtransPage> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _paymentUrl;
  Timer? _statusTimer;
  InAppWebViewController? _webViewController;
  bool _webViewReady = false;
  double _progress = 0;
  bool _paymentProcessed = false;
  bool _isCheckingStatus = false;

 static const String _backendUrl =
    "https://8db2a9074017.ngrok-free.app/generate-snap-token";
static const String _statusCheckUrl =
    "https://8db2a9074017.ngrok-free.app/payment-status";
  Widget _getDestination(String type) {
    switch (type) {
      case 'success':
        return widget.successDestination ?? HomePage();
      case 'failure':
        return widget.failureDestination ?? HomePage();
      case 'cancel':
        return widget.cancelDestination ?? HomePage();
      default:
        return HomePage();
    }
  }

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // Simplified payment status check
  Future<void> checkPaymentStatus(
    String orderId, {
    bool isManualCheck = false,
  }) async {
    if (_paymentProcessed && !isManualCheck) return;

    try {
      final response = await http.post(
        Uri.parse(_statusCheckUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final status = data['status'];
          final transactionStatus = data['transaction_status'];

          // Success statuses
          if (status == 'success' ||
              status == 'capture' ||
              status == 'settlement' ||
              transactionStatus == 'success' ||
              transactionStatus == 'capture' ||
              data['can_navigate_home'] == true) {
            await _handleSuccessPayment();
          }
          // Failed statuses
          else if (status == 'cancel' ||
              status == 'deny' ||
              status == 'expire' ||
              status == 'failure' ||
              transactionStatus == 'cancel' ||
              transactionStatus == 'deny' ||
              transactionStatus == 'expire' ||
              transactionStatus == 'failure') {
            await _handleFailedPayment();
          }
          // Pending status
          else if (isManualCheck &&
              (status == 'pending' || transactionStatus == 'pending')) {
            _showMessage(
              'Pembayaran masih dalam proses. Silakan tunggu beberapa saat lagi.',
              false,
            );
          }
        }
      }
    } catch (e) {
      if (isManualCheck) {
        _showMessage(
          'Gagal memeriksa status pembayaran. Silakan coba lagi.',
          false,
        );
      }
    }
  }

  // Simplified message display
  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Manual status check
  Future<void> _manualStatusCheck() async {
    if (_isCheckingStatus || _paymentProcessed) return;

    setState(() => _isCheckingStatus = true);
    await checkPaymentStatus(widget.orderId, isManualCheck: true);
    if (mounted) setState(() => _isCheckingStatus = false);
  }

  // Handle payment callback
  void _handlePaymentCallback(String url) {
    if (_paymentProcessed) return;

    if (url.contains('finish') ||
        url.contains('success') ||
        url.contains('payment-finish') ||
        url.contains('payment-success')) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_paymentProcessed && mounted) {
          checkPaymentStatus(widget.orderId);
        }
      });
    }
  }

  // Handle successful payment - Updated with flexible destination
  Future<void> _handleSuccessPayment() async {
    if (_paymentProcessed) return;
    _paymentProcessed = true;
    _statusTimer?.cancel();

    try {
      await _updatePaymentStatus('settlement');
    } catch (e) {
      debugPrint('Error updating payment status: $e');
    }

    _navigateToDestination(
      'success',
      'Pembayaran berhasil! Tiket Anda telah dikonfirmasi.',
      true,
    );
  }

  // Handle failed payment - Updated with flexible destination
  Future<void> _handleFailedPayment() async {
    if (_paymentProcessed) return;
    _paymentProcessed = true;
    _statusTimer?.cancel();

    try {
      await _updatePaymentStatus('failed');
    } catch (e) {
      debugPrint('Error updating payment status: $e');
    }

    _navigateToDestination(
      'failure',
      'Pembayaran dibatalkan atau gagal. Silakan coba lagi.',
      false,
    );
  }

  // Enhanced cancel payment method - Updated with flexible destination
  Future<void> _cancelPayment() async {
    if (_paymentProcessed) return;

    debugPrint('Starting payment cancellation...');

    try {
      _paymentProcessed = true;
      _statusTimer?.cancel();

      // Update payment status to cancelled
      try {
        await _updatePaymentStatus('cancel');
        debugPrint('Payment status updated to cancelled');
      } catch (e) {
        debugPrint('Error updating cancelled payment: $e');
        // Continue even if Firebase update fails
      }

      // Navigate to cancel destination
      if (mounted) {
        debugPrint('Navigating to destination after cancellation...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => _getDestination('cancel')),
          (route) => false,
        );

        // Show cancellation message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pembayaran dibatalkan. Anda dapat mencoba lagi kapan saja.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error in _cancelPayment: $e');

      // Force navigation even if there's an error
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => _getDestination('cancel')),
          (route) => false,
        );
      }
    }
  }

  // Update payment status in Firebase
  Future<void> _updatePaymentStatus(String status) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('payments')
          .doc(widget.orderId);

      Map<String, dynamic> paymentData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'transactionStatus': status,
        'isPaid':
            status == 'succes' || status == 'success' || status == 'capture',
        'isCancelled': status == 'cancel',
        'paymentMethod': 'midtrans',
      };

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.update(paymentData);
      } else {
        paymentData.addAll({
          'orderId': widget.orderId,
          'amount': widget.amount,
          'destinasiId': widget.destinasiId,
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'ticketQuantity': widget.ticketQuantity,
          'destinasiData': widget.destinasiData,
        });
        await docRef.set(paymentData);
      }
    } catch (e) {
      debugPrint('Error updating payment status: $e');
    }
  }

  // Initialize payment
  Future<void> _initPayment() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _paymentProcessed = false;
      });

      final snapToken = await _getSnapToken();
      if (snapToken == null) throw 'Gagal mendapatkan token pembayaran';

      setState(() {
        _paymentUrl =
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/$snapToken';
        _isLoading = false;
      });

      // Start status checking
      _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!_paymentProcessed && mounted) {
          checkPaymentStatus(widget.orderId);
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      _setError('Error initializing payment: $e');
    }
  }

  // Navigate to destination with message - Updated method
  void _navigateToDestination(
    String destinationType,
    String message,
    bool isSuccess,
  ) {
    if (!mounted) return;

    final destination = _getDestination(destinationType);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => destination),
      (route) => false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  // Backward compatibility method - kept for error handling
  void _navigateToHome(String message, bool isSuccess) {
    _navigateToDestination('success', message, isSuccess);
  }

  // Get snap token
  Future<String?> _getSnapToken() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final requestBody = {
        'order_id': widget.orderId,
        'gross_amount': widget.amount,
        'customer_details': {
          'first_name': widget.currentUserData['firstName'] ?? 'Customer',
          'email': widget.currentUserData['email'] ?? currentUser.email ?? '',
          'phone': widget.currentUserData['phoneNumber'] ?? '',
        },
        'item_details': [
          {
            'id': widget.destinasiId,
            'price': (widget.destinasiData['hargaTiket'] ?? 0).toInt(),
            'quantity': widget.ticketQuantity,
            'name': widget.destinasiData['namaDestinasi'] ?? 'Destinasi Ticket',
            'category': widget.destinasiData['kategori'] ?? 'Destinasi',
          },
        ],
        'destinasi_details': {
          'destinasi_id': widget.destinasiId,
          'destinasi_name':
              widget.destinasiData['namaDestinasi'] ?? 'Destinasi Ticket',
        },
        'buyer_details': {'user_id': currentUser.uid},
      };

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['snap_token'];
      }

      throw 'Failed to get snap token: ${response.body}';
    } catch (e) {
      throw 'Gagal mendapatkan token pembayaran: $e';
    }
  }

  void _setError(String error) {
    setState(() {
      _errorMessage = error;
      _isLoading = false;
    });
  }

  Future<void> _refreshPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _webViewReady = false;
      _progress = 0;
      _paymentProcessed = false;
    });
    _statusTimer?.cancel();
    await _initPayment();
  }

  // Enhanced cancel dialog - Used by both back button and cancel action
  void _showCancelDialog() {
    if (_paymentProcessed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Batalkan Pembayaran?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin membatalkan pembayaran ini? Transaksi akan dibatalkan dan tidak dapat dikembalikan.',
            style: TextStyle(fontSize: 14),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup modal
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Tidak',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup modal dulu
                Future.delayed(const Duration(milliseconds: 100), () {
                  _cancelPayment(); // Lalu batalkan pembayaran dan ke destinasi
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Ya, Batalkan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Handle back button press - Directly cancel payment if not processed
  Future<bool> _onWillPop() async {
    if (_paymentProcessed) {
      return true; // Allow normal back navigation if payment is completed
    } else {
      await _cancelPayment(); // Directly cancel payment and navigate to destination
      return false; // Prevent default back navigation since we handle it in _cancelPayment
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_paymentProcessed) {
                Navigator.pop(context); // Normal back if payment is done
              } else {
                _cancelPayment(); // Directly cancel payment and navigate to destination
              }
            },
          ),
          actions: [
            if (_webViewReady && !_isLoading && !_paymentProcessed)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshPayment,
                tooltip: 'Muat Ulang',
              ),
            if (_webViewReady && !_isLoading && !_paymentProcessed)
              IconButton(
                icon:
                    _isCheckingStatus
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.refresh_outlined),
                onPressed: _isCheckingStatus ? null : _manualStatusCheck,
                tooltip: 'Cek Status',
              ),
            if (_webViewReady && !_isLoading && !_paymentProcessed)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _showCancelDialog,
                tooltip: 'Batalkan',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) return _buildErrorScreen();
    if (_isLoading) return _buildLoadingScreen();
    if (_paymentUrl != null) return _buildWebViewScreen();
    return _buildLoadingScreen();
  }

  Widget _buildWebViewScreen() {
    return Column(
      children: [
        if (_progress < 1.0)
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_paymentUrl!)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStop: (controller, url) {
              if (!_webViewReady) setState(() => _webViewReady = true);
              _handlePaymentCallback(url.toString());
            },
            onProgressChanged: (controller, progress) {
              setState(() => _progress = progress / 100);
            },
            onReceivedError: (controller, request, error) {
              _setError(
                'Gagal memuat halaman pembayaran: ${error.description}',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Oops! Terjadi Kesalahan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _getDestination('failure'),
                          ),
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    child: const Text('Kembali'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _refreshPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                    child: const Text(
                      'Coba Lagi',
                      style: TextStyle(color: Colors.white),
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

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 24),
          Text(
            'Memuat Halaman Pembayaran',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Mohon tunggu sebentar...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
