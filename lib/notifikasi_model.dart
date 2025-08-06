import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Model notifikasi admin
class AdminNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type;
  final bool isRead;
  final String? userId;
  final String? referenceId;
  final String? username;
  final Map<String, dynamic>? additionalData;

  AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.userId,
    this.referenceId,
    this.username,
    this.additionalData,
  });

  /// Parsing dari Firestore
  factory AdminNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String rawMessage = data['message'] ?? '';
    final userId = data['userId'] as String?;
    final username = data['username'] ?? 'Pengguna';

    String formattedMessage = rawMessage;

    if (userId != null && rawMessage.contains(userId)) {
      formattedMessage = rawMessage.replaceAll(userId, username);
    }

    if (formattedMessage.startsWith('User ') && userId != null) {
      formattedMessage = formattedMessage.replaceFirst('User $userId', username);
    }

    return AdminNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: formattedMessage,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'system',
      isRead: data['isRead'] ?? false,
      userId: userId,
      referenceId: data['referenceId'],
      username: username,
      additionalData: data['additionalData'],
    );
  }

  /// Konversi ke Firestore
  Map<String, dynamic> toFirestore() {
    String displayMessage = message;
    if (username != null && userId != null && displayMessage.contains(userId!)) {
      displayMessage = displayMessage.replaceAll(userId!, username!);
    }

    return {
      'title': title,
      'message': displayMessage,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'isRead': isRead,
      'userId': userId,
      'username': username,
      'referenceId': referenceId,
      'additionalData': additionalData,
    };
  }

  /// Ikon berdasarkan tipe
  IconData getIcon() {
    switch (type) {
      case 'role_request':
        return Icons.person_add;
      case 'destination_recommendation':
        return Icons.place;
      case 'user_registration':
        return Icons.person;
      case 'system_update':
        return Icons.system_update;
      default:
        return Icons.notifications;
    }
  }

  /// Warna berdasarkan tipe
  Color getColor() {
    switch (type) {
      case 'role_request':
        return Colors.blue;
      case 'destination_recommendation':
        return Colors.green;
      case 'user_registration':
        return Colors.purple;
      case 'system_update':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Waktu relatif
  String getRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'Baru saja';
    if (difference.inMinutes < 60) return '${difference.inMinutes} menit yang lalu';
    if (difference.inHours < 24) return '${difference.inHours} jam yang lalu';
    if (difference.inDays < 7) return '${difference.inDays} hari yang lalu';
    
    return DateFormat('dd MMM yyyy').format(timestamp);
  }

  /// Nama tampilan fallback
  String getDisplayName() => username ?? 'Pengguna';

  /// Salin dengan perubahan
  AdminNotification copyWith({
    String? title,
    String? message,
    DateTime? timestamp,
    String? type,
    bool? isRead,
    String? userId,
    String? username,
    String? referenceId,
    Map<String, dynamic>? additionalData,
  }) {
    return AdminNotification(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      referenceId: referenceId ?? this.referenceId,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}
