import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Model notifikasi user
class NotificationModelUser {
  final String id;
  final String message;
  final bool read;
  final DateTime timestamp;
  final String title;
  final String type;
  final String userId;
  final Map<String, dynamic>? additionalData;

  NotificationModelUser({
    required this.id,
    required this.message,
    required this.read,
    required this.timestamp,
    required this.title,
    required this.type,
    required this.userId,
    this.additionalData,
  });

  /// Parsing dari Firestore dengan error handling yang lebih baik
  factory NotificationModelUser.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
        throw Exception('Document data is null');
      }

      return NotificationModelUser(
        id: doc.id,
        message: data['message']?.toString() ?? '',
        read: data['read'] ?? false,
        timestamp: _safeTimestampToDateTime(data['timestamp']),
        title: data['title']?.toString() ?? '',
        type: data['type']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        additionalData: data['additionalData'] as Map<String, dynamic>?,
      );
    } catch (e) {
      // Fallback untuk data yang rusak
      return NotificationModelUser(
        id: doc.id,
        message: 'Error parsing notification',
        read: false,
        timestamp: DateTime.now(),
        title: 'Error',
        type: 'error',
        userId: '',
        additionalData: null,
      );
    }
  }

  /// Parsing dari Map dengan error handling
  factory NotificationModelUser.fromMap(Map<String, dynamic> data, String id) {
    try {
      return NotificationModelUser(
        id: id,
        message: data['message']?.toString() ?? '',
        read: data['read'] ?? false,
        timestamp: _safeTimestampToDateTime(data['timestamp']),
        title: data['title']?.toString() ?? '',
        type: data['type']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        additionalData: data['additionalData'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return NotificationModelUser(
        id: id,
        message: 'Error parsing notification',
        read: false,
        timestamp: DateTime.now(),
        title: 'Error',
        type: 'error',
        userId: '',
        additionalData: null,
      );
    }
  }

  /// Konversi timestamp yang aman dengan lebih banyak handling
  static DateTime _safeTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now();
    }
    
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      if (timestamp is DateTime) {
        return timestamp;
      }
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
    }
    
    return DateTime.now();
  }

  /// Konversi ke Firestore dengan validasi
  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'read': read,
      'timestamp': Timestamp.fromDate(timestamp),
      'title': title,
      'type': type,
      'userId': userId,
      'additionalData': additionalData,
    };
  }

  /// Konversi ke Map biasa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'read': read,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'type': type,
      'userId': userId,
      'additionalData': additionalData,
    };
  }

  /// Ikon berdasarkan tipe notifikasi
  IconData getIcon() {
    switch (type.toLowerCase()) {
      case 'role_request':
        return Icons.person_add;
      case 'destination_recommendation':
        return Icons.place;
      case 'user_registration':
        return Icons.person;
      case 'system_update':
        return Icons.system_update;
      case 'message':
        return Icons.message;
      case 'feedback':
        return Icons.feedback;
      case 'announcement':
        return Icons.announcement;
      case 'reminder':
        return Icons.schedule;
      case 'achievement':
        return Icons.emoji_events;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  /// Warna berdasarkan tipe notifikasi
  Color getColor() {
    switch (type.toLowerCase()) {
      case 'role_request':
        return Colors.blue;
      case 'destination_recommendation':
        return Colors.green;
      case 'user_registration':
        return Colors.purple;
      case 'system_update':
        return Colors.orange;
      case 'message':
        return Colors.blue;
      case 'feedback':
        return Colors.teal;
      case 'announcement':
        return Colors.indigo;
      case 'reminder':
        return Colors.amber;
      case 'achievement':
        return Colors.yellow;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'success':
        return Colors.green;
      case 'info':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  /// Warna latar belakang berdasarkan status read
  Color getBackgroundColor() {
    if (read) {
      return Colors.grey.shade50;
    } else {
      return getColor().withOpacity(0.1);
    }
  }

  String getRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'Baru saja';
    if (difference.inMinutes < 60)
      return '${difference.inMinutes} menit yang lalu';
    if (difference.inHours < 24) return '${difference.inHours} jam yang lalu';
    if (difference.inDays < 7) return '${difference.inDays} hari yang lalu';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()} minggu yang lalu';
    if (difference.inDays < 365)
      return '${(difference.inDays / 30).floor()} bulan yang lalu';

    return DateFormat('dd MMM yyyy').format(timestamp);
  }

  /// Format tanggal lengkap
  String getFormattedDate() {
    return DateFormat('dd MMMM yyyy, HH:mm').format(timestamp);
  }

  /// Format tanggal singkat
  String getShortDate() {
    return DateFormat('dd/MM/yyyy').format(timestamp);
  }

  /// Format waktu saja
  String getTime() {
    return DateFormat('HH:mm').format(timestamp);
  }

  /// Status read sebagai string
  String getReadStatus() {
    return read ? 'Sudah dibaca' : 'Belum dibaca';
  }

  /// Prioritas notifikasi berdasarkan tipe
  int getPriority() {
    switch (type.toLowerCase()) {
      case 'error':
        return 1;
      case 'warning':
        return 2;
      case 'role_request':
        return 3;
      case 'announcement':
        return 4;
      case 'message':
        return 5;
      case 'reminder':
        return 6;
      case 'feedback':
        return 7;
      case 'achievement':
        return 8;
      case 'success':
        return 9;
      case 'info':
        return 10;
      default:
        return 99;
    }
  }

  /// Cek apakah notifikasi penting
  bool isImportant() {
    return [
      'error',
      'warning',
      'role_request',
      'announcement',
    ].contains(type.toLowerCase());
  }

  /// Cek apakah notifikasi sudah lama (lebih dari 7 hari)
  bool isOld() {
    return DateTime.now().difference(timestamp).inDays > 7;
  }

  /// Cek apakah notifikasi baru (kurang dari 1 jam)
  bool isNew() {
    return DateTime.now().difference(timestamp).inHours < 1;
  }

  /// Judul dengan fallback
  String getDisplayTitle() {
    if (title.isNotEmpty) return title;

    switch (type.toLowerCase()) {
      case 'role_request':
        return 'Permintaan Peran';
      case 'destination_recommendation':
        return 'Rekomendasi Destinasi';
      case 'user_registration':
        return 'Registrasi Pengguna';
      case 'system_update':
        return 'Pembaruan Sistem';
      case 'message':
        return 'Pesan';
      case 'feedback':
        return 'Feedback';
      case 'announcement':
        return 'Pengumuman';
      case 'reminder':
        return 'Pengingat';
      case 'achievement':
        return 'Pencapaian';
      case 'warning':
        return 'Peringatan';
      case 'error':
        return 'Error';
      case 'success':
        return 'Berhasil';
      case 'info':
        return 'Informasi';
      default:
        return 'Notifikasi';
    }
  }

  /// Validasi data notifikasi
  bool isValid() {
    return id.isNotEmpty && 
           userId.isNotEmpty && 
           type.isNotEmpty &&
           message.isNotEmpty;
  }

  /// Salin dengan perubahan
  NotificationModelUser copyWith({
    String? id,
    String? message,
    bool? read,
    DateTime? timestamp,
    String? title,
    String? type,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) {
    return NotificationModelUser(
      id: id ?? this.id,
      message: message ?? this.message,
      read: read ?? this.read,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  /// Perbandingan equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModelUser &&
        other.id == id &&
        other.message == message &&
        other.read == read &&
        other.timestamp == timestamp &&
        other.title == title &&
        other.type == type &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        message.hashCode ^
        read.hashCode ^
        timestamp.hashCode ^
        title.hashCode ^
        type.hashCode ^
        userId.hashCode;
  }

  @override
  String toString() {
    return 'NotificationUser('
        'id: $id, '
        'title: $title, '
        'message: $message, '
        'type: $type, '
        'read: $read, '
        'timestamp: $timestamp, '
        'userId: $userId'
        ')';
  }
}