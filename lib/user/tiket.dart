import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart';

class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  // User data
  String _userId = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadUserTickets();
  }

  // Load user tickets from payments collection
  Future<void> _loadUserTickets() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _userId = currentUser.uid);

      // Query payments collection for current user's paid tickets
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('payments')
              .where('userId', isEqualTo: currentUser.uid)
              .where('is_paid', isEqualTo: true)
              .where('transactionStatus', isEqualTo: 'settlement')
              .get();

      List<Map<String, dynamic>> tickets = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['documentId'] = doc.id; // Add document ID for updates
        tickets.add(data);
      }

      // Sort by createdAt in descending order (newest first)
      tickets.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading tickets: $e', isError: true);
    }
  }

  // Use ticket - update status to "digunakan" and save to tiket collection
  // Use ticket - update status to "digunakan" and save to tiket collection
  void _useTicket(String documentId, Map<String, dynamic> ticketData) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Konfirmasi Penggunaan Tiket',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Apakah Anda yakin ingin menggunakan tiket untuk ${_getDestinationName(ticketData)}? Tiket yang sudah digunakan tidak dapat digunakan lagi.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'BATAL',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'GUNAKAN',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        _showSnackBar('User not authenticated', isError: true);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final usedAt = FieldValue.serverTimestamp();

      // 1. Update ticket status in payments collection
      final paymentRef = FirebaseFirestore.instance
          .collection('payments')
          .doc(documentId);

      batch.update(paymentRef, {
        'status': 'digunakan',
        'used_at': usedAt,
        'updatedAt': usedAt,
      });

      // 2. Add ticket data to tiket collection
      final tiketRef =
          FirebaseFirestore.instance
              .collection('tiket')
              .doc(); // Auto-generate document ID

      // FIXED: Properly separate event and destinasi data
      final eventData = ticketData['eventData'] as Map<String, dynamic>?;
      final destinasiData =
          ticketData['destinasiData'] as Map<String, dynamic>?;

      // FIXED: Assign correct names based on ticket type
      String eventName = '';
      String destinasiName = '';

      if (eventData != null && eventData.isNotEmpty) {
        // This is an event ticket
        eventName = eventData['namaEvent']?.toString() ?? '';
        destinasiName = ''; // No destinasi for event tickets
      } else if (destinasiData != null && destinasiData.isNotEmpty) {
        // This is a destinasi ticket
        destinasiName = destinasiData['namaDestinasi']?.toString() ?? '';
        eventName = ''; // No event for destinasi tickets
      }

      final tiketData = {
        'payment_id': documentId,
        'order_id': ticketData['orderId'] ?? '',
        'user_id': ticketData['userId'] ?? currentUser.uid,
        'user_email': ticketData['userEmail'] ?? currentUser.email,
        'user_name': ticketData['userName'] ?? '',
        'destinasi_name':
            destinasiName, // FIXED: Only set if it's a destinasi ticket
        'event_name': eventName, // FIXED: Only set if it's an event ticket
        'quantity': ticketData['quantity'] ?? 1,
        'total_amount': ticketData['totalAmount'] ?? 0,
        'payment_method': ticketData['paymentMethod'] ?? '',
        'transaction_details': ticketData['transaction_details'] ?? {},
        'used_at': usedAt,
        'created_at': usedAt,
        'status': 'digunakan',
      };

      // FIXED: Only add event_data if it's actually an event ticket
      if (eventData != null && eventData.isNotEmpty) {
        tiketData['event_data'] = eventData;
      }

      // FIXED: Only add destinasi_data if it's actually a destinasi ticket
      if (destinasiData != null && destinasiData.isNotEmpty) {
        tiketData['destinasi_data'] = destinasiData;
      }

      batch.set(tiketRef, tiketData);

      // Execute batch write
      await batch.commit();

      // Reload tickets to reflect changes
      await _loadUserTickets();

      _showSnackBar('Tiket berhasil digunakan dan disimpan!', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error menggunakan tiket: $e', isError: true);
    }
  }

  // Helper method to get destination name from various possible locations
  String _getDestinationName(Map<String, dynamic> ticketData) {
    // Try eventData first
    final eventData = ticketData['eventData'] as Map<String, dynamic>?;
    if (eventData != null && eventData['namaEvent'] != null) {
      return eventData['namaEvent'].toString();
    }

    // Try destinasiData
    final destinasiData = ticketData['destinasiData'] as Map<String, dynamic>?;
    if (destinasiData != null && destinasiData['namaDestinasi'] != null) {
      return destinasiData['namaDestinasi'].toString();
    }

    // Try eventName or destinasiName at root level
    if (ticketData['eventName'] != null) {
      return ticketData['eventName'].toString();
    }
    if (ticketData['destinasiName'] != null) {
      return ticketData['destinasiName'].toString();
    }

    return 'Unknown Destination';
  }

  // Helper method to get location
  String _getLocation(Map<String, dynamic> ticketData) {
    final eventData = ticketData['eventData'] as Map<String, dynamic>?;
    if (eventData != null && eventData['lokasi'] != null) {
      return eventData['lokasi'].toString();
    }

    final destinasiData = ticketData['destinasiData'] as Map<String, dynamic>?;
    if (destinasiData != null && destinasiData['lokasi'] != null) {
      return destinasiData['lokasi'].toString();
    }

    return 'N/A';
  }

  // Helper method to get ticket type
  String _getTicketType(Map<String, dynamic> ticketData) {
    if (ticketData['eventData'] != null) {
      return 'Event';
    } else if (ticketData['destinasiData'] != null) {
      return 'Destinasi';
    }
    return 'Tiket';
  }

  // Show SnackBar
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

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

  // Format currency
  String _formatCurrency(dynamic amount) {
    int value = 0;
    if (amount is int) {
      value = amount;
    } else if (amount is String) {
      value = int.tryParse(amount.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    } else if (amount is double) {
      value = amount.toInt();
    }
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // FIXED: Helper method to get purchase date
  String _getPurchaseDate(Map<String, dynamic> ticketData) {
    // Try different possible date fields in order of preference
    final possibleDateFields = ['createdAt', 'paid_at', 'timestamp', 'updated_at'];
    
    for (String field in possibleDateFields) {
      if (ticketData[field] != null) {
        return _formatDate(ticketData[field]);
      }
    }
    
    return 'N/A';
  }

  // Format date
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is String) {
      try {
        date = DateTime.parse(timestamp);
      } catch (e) {
        return 'N/A';
      }
    } else {
      return 'N/A';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
        ),
        title: Text(
          'Tiket Saya',
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
              : _tickets.isEmpty
              ? _buildEmptyState()
              : _buildTicketList(),
    );
  }

  // Build empty state when no tickets
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: Colors.grey[400],
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Belum Ada Tiket',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Anda belum memiliki tiket apapun. Yuk jelajahi destinasi menarik dan beli tiket pertama Anda!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'JELAJAHI DESTINASI',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build ticket list
  Widget _buildTicketList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total ${_tickets.length} tiket ditemukan',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ticket cards
          ...List.generate(_tickets.length, (index) {
            final ticket = _tickets[index];
            return _buildTicketCard(ticket);
          }),
        ],
      ),
    );
  }

  // Build individual ticket card
  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final isUsed = ticket['status'] == 'digunakan';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Ticket header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUsed ? Colors.grey[100] : const Color(0xFF2E7D32),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.confirmation_number,
                  color: isUsed ? Colors.grey[600] : Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDestinationName(ticket),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isUsed ? Colors.grey[600] : Colors.white,
                        ),
                      ),
                      Text(
                        _getTicketType(ticket),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              isUsed
                                  ? Colors.grey[500]
                                  : Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isUsed
                            ? Colors.grey[300]
                            : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUsed ? 'DIGUNAKAN' : 'AKTIF',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isUsed ? Colors.grey[600] : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ticket details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID
                _buildDetailRow(
                  'Order ID',
                  ticket['orderId']?.toString() ?? 'N/A',
                  Icons.receipt_long,
                ),
                const SizedBox(height: 12),

                // Customer name
                _buildDetailRow(
                  'Nama Pemesan',
                  ticket['userName']?.toString() ?? 'N/A',
                  Icons.person,
                ),
                const SizedBox(height: 12),

                // Location
                _buildDetailRow(
                  'Lokasi',
                  _getLocation(ticket),
                  Icons.location_on,
                ),
                const SizedBox(height: 12),

                // Quantity
                _buildDetailRow(
                  'Jumlah Tiket',
                  '${ticket['quantity'] ?? 1} tiket',
                  Icons.confirmation_number_outlined,
                ),
                const SizedBox(height: 12),

                // Price
                _buildDetailRow(
                  'Total Harga',
                  _formatCurrency(ticket['totalAmount']),
                  Icons.attach_money,
                ),
                const SizedBox(height: 12),

                // Payment Method
                _buildDetailRow(
                  'Metode Pembayaran',
                  ticket['paymentMethod']?.toString().toUpperCase() ?? 'N/A',
                  Icons.payment,
                ),
                const SizedBox(height: 12),

                // FIXED: Purchase date - now uses the new method
                _buildDetailRow(
                  'Tanggal Pembelian',
                  _getPurchaseDate(ticket),
                  Icons.access_time,
                ),

                // Used date (if used)
                if (isUsed && ticket['used_at'] != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Tanggal Digunakan',
                    _formatDate(ticket['used_at']),
                    Icons.check_circle,
                  ),
                ],

                const SizedBox(height: 20),

                // Use ticket button
                if (!isUsed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _useTicket(ticket['documentId'], ticket),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'GUNAKAN TIKET',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TIKET SUDAH DIGUNAKAN',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build detail row
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}