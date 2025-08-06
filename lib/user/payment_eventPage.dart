import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'midtrands_EventPage.dart';

class PaymentPage extends StatefulWidget {
  final String userId;
  final String eventId;
  final Map<String, dynamic> eventData;

  const PaymentPage({
    required this.userId,
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  PaymentPageState createState() => PaymentPageState();
}

class PaymentPageState extends State<PaymentPage> {
  int _ticketQuantity = 1;
  bool _isProcessing = false;
  Map<String, dynamic>? _currentUserData;
  bool _isLoadingUserData = true;

  // Constants
  static const int _maxTicketQuantity = 10;
  static const int _minTicketQuantity = 1;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showAuthError();
        return;
      }

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserData = userDoc.data() as Map<String, dynamic>?;
          _isLoadingUserData = false;
        });
      } else {
        throw Exception('User data not found');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoadingUserData = false);
        _showDialog('Error', 'Gagal memuat data pengguna. Silakan coba lagi.', isError: true);
      }
    }
  }

  void _showAuthError() {
    if (mounted) {
      _showDialog(
        'Authentication Error',
        'Anda harus login terlebih dahulu.',
        isError: true,
        onOk: () => Navigator.pop(context),
      );
    }
  }

  Future<void> _processPayment() async {
    if (!mounted || _currentUserData == null) return;

    // Validate user data
    if (!_validateUserData()) {
      _showDialog(
        'Data Tidak Lengkap',
        'Mohon lengkapi profil Anda terlebih dahulu.',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String orderId = _generateOrderId();
      final bool isFree = widget.eventData['isFree'] == true;
      final double totalAmount = _calculateTotalAmount();

      if (isFree) {
        await _processFreeEvent(orderId);
      } else {
        await _processPaidEvent(orderId, totalAmount.toInt());
      }
    } catch (e) {
      debugPrint('Error in _processPayment: $e');
      if (mounted) {
        _showDialog(
          'Error',
          'Terjadi kesalahan saat memproses pembayaran. Silakan coba lagi.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  bool _validateUserData() {
    if (_currentUserData == null) return false;
    
    final String? email = _currentUserData!['email'];
    final String? firstName = _currentUserData!['firstName'] ?? _currentUserData!['name'];
    
    return email != null && email.isNotEmpty && 
           firstName != null && firstName.isNotEmpty;
  }

  Future<void> _processFreeEvent(String orderId) async {
    try {
      await _savePaymentToFirestore(orderId, 'success', true);
      if (mounted) {
        _showDialog(
          'Berhasil!',
          'Anda telah berhasil terdaftar untuk event gratis ini.\nID Pesanan: $orderId',
          onOk: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        );
      }
    } catch (e) {
      debugPrint('Error processing free event: $e');
      if (mounted) {
        _showDialog(
          'Error',
          'Gagal mendaftarkan ke event gratis. Silakan coba lagi.',
          isError: true,
        );
      }
    }
  }

  Future<void> _processPaidEvent(String orderId, int amount) async {
    try {
      // Save as pending first
      await _savePaymentToFirestore(orderId, 'pending', false);
      
      // Show loading dialog before navigation
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Mempersiapkan pembayaran...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Add a small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Navigate to MidtransPage
        try {
          await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => MidtransPage(
                orderId: orderId,
                amount: amount,
                ticketQuantity: _ticketQuantity,
                eventData: widget.eventData,
                eventId: widget.eventId,
                currentUserData: _currentUserData!,
              ),
            ),
          );

          // Payment result will be handled directly in MidtransPage
          // No need to handle result here
          
        } catch (webViewError) {
          debugPrint('WebView/Navigation error: $webViewError');
          
          if (mounted) {
            // Handle WebView initialization error specifically
            if (webViewError.toString().contains('WebView') || 
                webViewError.toString().contains('webview_flutter')) {
              _showWebViewErrorDialog(orderId);
            } else {
              _showDialog(
                'Error',
                'Gagal membuka halaman pembayaran. Silakan coba lagi.\nError: ${webViewError.toString()}',
                isError: true,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing paid event: $e');
      if (mounted) {
        // Make sure to close any loading dialog
        try {
          Navigator.of(context).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
        } catch (e) {
          debugPrint('Error closing dialogs: $e');
        }
        
        _showDialog(
          'Error',
          'Gagal memulai proses pembayaran. Silakan coba lagi.\nError: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showWebViewErrorDialog(String orderId) {
    _showDialog(
      'WebView Error',
      'Terjadi masalah dengan WebView. Ini mungkin terjadi pada emulator atau perangkat yang tidak mendukung WebView.\n\n'
      'Solusi:\n'
      '1. Coba jalankan di perangkat Android/iOS fisik\n'
      '2. Pastikan Google Play Services terinstall\n'
      '3. Update WebView dari Play Store\n\n'
      'ID Pesanan: $orderId telah disimpan.',
      isError: true,
    );
  }

  Future<void> _savePaymentToFirestore(
    String orderId,
    String status,
    bool isFree,
  ) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || _currentUserData == null) {
        throw Exception('User not authenticated or user data not loaded');
      }

      final String eventName = widget.eventData['namaEvent']?.toString() ?? 'Event';
      final Timestamp now = Timestamp.now();

      final Map<String, dynamic> paymentData = {
        'orderId': orderId,
        'userId': currentUser.uid,
        'eventId': widget.eventId,
        'eventName': eventName,
        'quantity': _ticketQuantity,
        'totalAmount': _calculateTotalAmount(),
        'status': status,
        'isFree': isFree,
        'timestamp': now,
        'createdAt': now,
        'userEmail': _currentUserData!['email'],
        'userName': _currentUserData!['firstName'] ?? _currentUserData!['name'] ?? 'User',
        'eventData': {
          'namaEvent': widget.eventData['namaEvent'],
          'tanggalMulai': widget.eventData['tanggalMulai'],
          'lokasi': widget.eventData['lokasi'],
          'hargaTiket': widget.eventData['hargaTiket'],
        },
      };

      debugPrint('Saving payment to Firestore: $paymentData');

      final paymentRef = FirebaseFirestore.instance
          .collection('payments')
          .doc(orderId);

      await paymentRef.set(paymentData);

      debugPrint('Payment saved successfully with status: $status');
    } catch (e, stack) {
      debugPrint('Error saving payment: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  String _generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'ORDER-${widget.eventId}-$timestamp-$random';
  }

  double _calculateTotalAmount() {
    final bool isFree = widget.eventData['isFree'] == true;
    if (isFree) return 0.0;
    
    final dynamic ticketPriceData = widget.eventData['hargaTiket'];
    final double ticketPrice = ticketPriceData is num ? ticketPriceData.toDouble() : 0.0;
    
    return ticketPrice * _ticketQuantity;
  }

  void _incrementQuantity() {
    if (_ticketQuantity < _maxTicketQuantity) {
      setState(() => _ticketQuantity++);
    }
  }

  void _decrementQuantity() {
    if (_ticketQuantity > _minTicketQuantity) {
      setState(() => _ticketQuantity--);
    }
  }

  void _showDialog(
    String title,
    String message, {
    bool isError = false,
    VoidCallback? onOk,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Pesan Tiket'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bool isFree = widget.eventData['isFree'] == true;
    final double totalAmount = _calculateTotalAmount();
    final double ticketPrice = isFree ? 0.0 : (widget.eventData['hargaTiket'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pesan Tiket'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Event Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.eventData['namaEvent'] ?? 'Event Name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.eventData['tanggalMulai'] ?? 'N/A',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.eventData['lokasi'] ?? 'Location',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quantity Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah Tiket',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _ticketQuantity > _minTicketQuantity
                              ? _decrementQuantity
                              : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(
                            backgroundColor: _ticketQuantity > _minTicketQuantity
                                ? Colors.green
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_ticketQuantity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          onPressed: _ticketQuantity < _maxTicketQuantity
                              ? _incrementQuantity
                              : null,
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: _ticketQuantity < _maxTicketQuantity
                                ? Colors.green
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Maksimal $_maxTicketQuantity tiket per pemesanan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Price Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Harga per tiket:'),
                        Text(
                          isFree ? 'Gratis' : _formatCurrency(ticketPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isFree ? Colors.green : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if (!isFree) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Jumlah:'),
                          Text('$_ticketQuantity tiket'),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isFree ? 'Gratis' : _formatCurrency(totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Memproses...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isFree ? Icons.how_to_reg : Icons.payment),
                          const SizedBox(width: 8),
                          Text(
                            isFree ? 'Daftar Sekarang' : 'Bayar Sekarang',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}