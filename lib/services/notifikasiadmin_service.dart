import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guide_me/notifikasi_model.dart'; 

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _adminNotificationsCollection = 'admin_notifications';
  final String _processedRequestsCollection = 'processed_requests';

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _listenersInitialized = false;
  
  // In-memory cache untuk tracking request yang sudah diproses
  final Set<String> _processedRequests = {};

  // Helper method untuk safely convert timestamp
  DateTime _safeTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now();
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    if (timestamp is DateTime) {
      return timestamp;
    }
    // Fallback ke current time jika tidak bisa convert
    return DateTime.now();
  }

  // Stream notifikasi untuk UI
  Stream<List<AdminNotification>> getNotificationsStream() {
    return _firestore
        .collection(_adminNotificationsCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminNotification.fromFirestore(doc))
            .toList());
  }

  Future<int> getUnreadCount() async {
    try {
      final snapshot = await _firestore
          .collection(_adminNotificationsCollection)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_adminNotificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_adminNotificationsCollection)
          .where('isRead', isEqualTo: false)
          .get();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<String> _getUsernameFromUserId(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['name'] ??
            data?['username'] ??
            data?['displayName'] ??
            data?['email'] ??
            'Pengguna';
      }
    } catch (e) {
      print('Error getting username: $e');
    }
    return 'Pengguna';
  }

  // Simplified: Mark request as processed - hanya satu fungsi untuk semua jenis
  Future<void> _markRequestAsProcessed(String referenceId) async {
    try {
      await _firestore
          .collection(_processedRequestsCollection)
          .doc(referenceId)
          .set({
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      _processedRequests.add(referenceId);
    } catch (e) {
      print('Error marking request as processed: $e');
    }
  }

  // Simplified: Check if request is processed
  Future<bool> _isRequestProcessed(String referenceId) async {
    try {
      // Check in-memory cache first
      if (_processedRequests.contains(referenceId)) {
        return true;
      }
      
      // Check database
      final doc = await _firestore
          .collection(_processedRequestsCollection)
          .doc(referenceId)
          .get();
          
      if (doc.exists) {
        _processedRequests.add(referenceId);
        return true;
      }
      
      // Check admin_notifications as backup
      final check = await _firestore
          .collection(_adminNotificationsCollection)
          .where('referenceId', isEqualTo: referenceId)
          .get();
          
      if (check.docs.isNotEmpty) {
        _processedRequests.add(referenceId);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking if request is processed: $e');
      return false;
    }
  }

  // Simplified: Update original request status hanya sekali
  Future<void> _updateOriginalRequestStatus(String referenceId, String type) async {
  try {
    String? collection;

    switch (type) {
      case 'role_requests':
        collection = 'role_requests';
        break;
      case 'destinasi_requests':
        collection = 'destinasi_requests';
        break;
      case 'event_requests':
        collection = 'event_requests';
        break;
      case 'feedback':
        collection = 'feedback';
        break;
      default:
        return;
    }

    await _firestore.collection(collection).doc(referenceId).update({
      'status': 'processed',
    });
  } catch (e) {
    print('Error updating original request status: $e');
  }
}

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    String? userId,
    String? referenceId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Check if already processed
      if (referenceId != null && await _isRequestProcessed(referenceId)) {
        print('Request already processed, ignoring: $referenceId');
        return;
      }

      String? username;
      String updatedMessage = message;

      if (userId != null) {
        username = await _getUsernameFromUserId(userId);
        if (message.contains(userId)) {
          updatedMessage = updatedMessage.replaceAll(userId, username);
        }
        if (message.startsWith('User ') || message.startsWith('user ')) {
          updatedMessage = '$username${message.substring(5)}';
        }
      }

      final notification = AdminNotification(
        id: '',
        title: title,
        message: updatedMessage,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        userId: userId,
        username: username,
        referenceId: referenceId,
        additionalData: additionalData,
      );

      final docRef = await _firestore
          .collection(_adminNotificationsCollection)
          .add(notification.toFirestore());
          
      // Mark as processed dan update status sekali saja
      if (referenceId != null) {
        await _markRequestAsProcessed(referenceId);
        await _updateOriginalRequestStatus(referenceId, type);
      }
      
      print('Notification added with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  Stream<List<AdminNotification>> listenForRoleRequests() {
    return _firestore
        .collection('role_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<AdminNotification> notifications = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final requestId = doc.id;
        
        // Skip jika sudah diproses
        if (await _isRequestProcessed(requestId)) {
          continue;
        }

        final userId = data['userId'] as String?;
        final role = data['role'] ?? 'tidak diketahui';

        String username = 'Pengguna';
        if (userId != null) {
          final storedUsername = data['username'] ?? '';
          username = storedUsername.isNotEmpty
              ? storedUsername
              : await _getUsernameFromUserId(userId);
        }

        // Safe timestamp conversion
        final timestamp = _safeTimestampToDateTime(data['timestamp']);

        notifications.add(AdminNotification(
          id: doc.id,
          title: 'Permintaan Peran Baru',
          message: '$username meminta peran $role',
          timestamp: timestamp,
          type: 'role_requests',
          isRead: false,
          userId: userId,
          username: username,
          referenceId: requestId,
        ));
      }

      return notifications;
    });
  }

  Stream<List<AdminNotification>> listenForDestinationRecommendations() {
    return _firestore
        .collection('destinasi_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<AdminNotification> notifications = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final recommendationId = doc.id;
        
        // Skip jika sudah diproses
        if (await _isRequestProcessed(recommendationId)) {
          continue;
        }

        final userId = data['userId'] as String?;
        final destination = data['namaDestinasi'] ?? '-';

        String username = 'Pengguna';
        if (userId != null) {
          final storedUsername = data['username'] ?? '';
          username = storedUsername.isNotEmpty
              ? storedUsername
              : await _getUsernameFromUserId(userId);
        }

        // Safe timestamp conversion
        final timestamp = _safeTimestampToDateTime(data['timestamp']);

        notifications.add(AdminNotification(
          id: doc.id,
          title: 'Rekomendasi Destinasi Baru',
          message: '$username merekomendasikan destinasi $destination',
          timestamp: timestamp,
          type: 'destinasi_requests',
          isRead: false,
          userId: userId,
          username: username,
          referenceId: recommendationId,
        ));
      }

      return notifications;
    });
  }

  // Fungsi baru untuk event requests
  Stream<List<AdminNotification>> listenForEventRequests() {
    return _firestore
        .collection('event_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<AdminNotification> notifications = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final eventRequestId = doc.id;
        
        // Skip jika sudah diproses
        if (await _isRequestProcessed(eventRequestId)) {
          continue;
        }

        final userId = data['userId'] as String?;
        final eventName = data['namaEvent'] ?? data['nama'] ?? '-';

        String username = 'Pengguna';
        if (userId != null) {
          final storedUsername = data['username'] ?? '';
          username = storedUsername.isNotEmpty
              ? storedUsername
              : await _getUsernameFromUserId(userId);
        }

        // Safe timestamp conversion
        final timestamp = _safeTimestampToDateTime(data['timestamp']);

        notifications.add(AdminNotification(
          id: doc.id,
          title: 'Permintaan Event Baru',
          message: '$username mengajukan event $eventName',
          timestamp: timestamp,
          type: 'event_requests',
          isRead: false,
          userId: userId,
          username: username,
          referenceId: eventRequestId,
        ));
      }

      return notifications;
    });
  }

  Stream<List<AdminNotification>> listenForFeedBackUser() {
    return _firestore
        .collection('feedback')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<AdminNotification> notifications = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final feedbackId = doc.id;
        
        // Skip jika sudah diproses
        if (await _isRequestProcessed(feedbackId)) {
          continue;
        }

        final userId = data['userId'] as String?;
        final category = data['category'] ?? 'feedback';
        final message = data['message'] ?? '';
        final email = data['email'] ?? '';

        String username = 'Pengguna';
        if (userId != null) {
          final storedUsername = data['username'] ?? '';
          username = storedUsername.isNotEmpty
              ? storedUsername
              : await _getUsernameFromUserId(userId);
        }

        // Safe timestamp conversion - gunakan createdAt bukan timestamp
        final timestamp = _safeTimestampToDateTime(data['createdAt']);

        // Buat pesan yang lebih informatif
        String feedbackMessage = '';
        if (category == 'Laporan Bug') {
          feedbackMessage = '$username melaporkan bug: ${message.length > 50 ? message.substring(0, 50) + '...' : message}';
        } else {
          feedbackMessage = '$username memberikan $category: ${message.length > 50 ? message.substring(0, 50) + '...' : message}';
        }

        notifications.add(AdminNotification(
          id: doc.id,
          title: 'Feedback - $category',
          message: feedbackMessage,
          timestamp: timestamp,
          type: 'feedback',
          isRead: false,
          userId: userId,
          username: username,
          referenceId: feedbackId,
          additionalData: {
            'category': category,
            'message': message,
            'email': email,
            'deviceInfo': data['deviceInfo'],
          },
        ));
      }

      return notifications;
    });
  }

  Stream<List<AdminNotification>> listenForNewUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docChanges
          .where((change) => change.type == DocumentChangeType.added)
          .map((change) {
            final data = change.doc.data()!;
            if (data['notificationProcessed'] == true) return null;

            final username = data['name'] ??
                data['username'] ??
                data['displayName'] ??
                data['email'] ??
                'Pengguna Baru';

            // Safe timestamp conversion
            final timestamp = _safeTimestampToDateTime(data['createdAt']);

            return AdminNotification(
              id: change.doc.id,
              title: 'Pengguna Baru Terdaftar',
              message: '$username telah mendaftar',
              timestamp: timestamp,
              type: 'user_registration',
              isRead: false,
              userId: change.doc.id,
              username: username,
            );
          })
          .where((e) => e != null)
          .cast<AdminNotification>()
          .toList();
    });
  }

  Future<void> processAndSaveNotifications(List<AdminNotification> notifications) async {
    if (notifications.isEmpty) return;

    for (var notification in notifications) {
      try {
        // Skip jika sudah diproses
        if (notification.referenceId != null && 
            await _isRequestProcessed(notification.referenceId!)) {
          continue;
        }

        // Save notification
        final docRef = await _firestore
            .collection(_adminNotificationsCollection)
            .add(notification.toFirestore());
            
        print('Saved notification with ID: ${docRef.id}');

        // Mark as processed dan update status sekali saja
        if (notification.referenceId != null) {
          await _markRequestAsProcessed(notification.referenceId!);
          await _updateOriginalRequestStatus(notification.referenceId!, notification.type);
        }

        // Handle user registration
        if (notification.type == 'user_registration' && notification.userId != null) {
          await _firestore
              .collection('users')
              .doc(notification.userId)
              .update({'notificationProcessed': true});
        }
      } catch (e) {
        print('Error saving notification: $e');
      }
    }
  }

  // Simplified: Sync processed requests
  Future<void> _syncProcessedRequests() async {
    try {
      _processedRequests.clear();
      
      // Sync dari processed_requests collection
      final processedDocs = await _firestore
          .collection(_processedRequestsCollection)
          .get();
      
      for (var doc in processedDocs.docs) {
        _processedRequests.add(doc.id);
      }
      
      // Sync dari admin_notifications dengan referenceId
      final notifications = await _firestore
          .collection(_adminNotificationsCollection)
          .get();
      
      for (var doc in notifications.docs) {
        final data = doc.data();
        final referenceId = data['referenceId'];
        if (referenceId != null) {
          _processedRequests.add(referenceId);
        }
      }
      
      print('Synced ${_processedRequests.length} processed requests');
    } catch (e) {
      print('Error syncing processed requests: $e');
    }
  }

  void initNotificationListeners() {
    if (_listenersInitialized) {
      print('Listeners already initialized.');
      return;
    }

    _listenersInitialized = true;
    print('Initializing notification listeners');
    
    _syncProcessedRequests().then((_) {
      listenForRoleRequests().listen(processAndSaveNotifications);
      listenForDestinationRecommendations().listen(processAndSaveNotifications);
      listenForEventRequests().listen(processAndSaveNotifications); 
      listenForFeedBackUser().listen(processAndSaveNotifications);
      listenForNewUsers().listen(processAndSaveNotifications);
    });
  }

  Future<void> removeDuplicateNotifications() async {
    try {
      final snapshot = await _firestore.collection(_adminNotificationsCollection).get();
      final Map<String, DocumentReference> seen = {};
      final List<DocumentReference> duplicates = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final key = '${data['referenceId'] ?? ''}:${data['type'] ?? ''}';

        if (key.trim().isEmpty) continue;

        if (seen.containsKey(key)) {
          duplicates.add(doc.reference);
        } else {
          seen[key] = doc.reference;
        }
      }

      // Batch delete duplicates
      for (int i = 0; i < duplicates.length; i += 400) {
        final batch = _firestore.batch();
        final end = (i + 400 < duplicates.length) ? i + 400 : duplicates.length;
        for (int j = i; j < end; j++) {
          batch.delete(duplicates[j]);
        }
        await batch.commit();
      }

      print('Removed ${duplicates.length} duplicate notifications.');
    } catch (e) {
      print('Error removing duplicates: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_adminNotificationsCollection)
          .doc(notificationId)
          .get();
      
      if (!docSnapshot.exists) {
        print('Notification not found.');
        return;
      }

      final data = docSnapshot.data()!;
      final referenceId = data['referenceId'];
      
      // Delete notification
      await _firestore
          .collection(_adminNotificationsCollection)
          .doc(notificationId)
          .delete();
          
      // Mark as processed jika ada referenceId
      if (referenceId != null) {
        await _markRequestAsProcessed(referenceId);
        await _updateOriginalRequestStatus(referenceId, data['type']);
      }
      
      print('Notification deleted successfully.');
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Simplified cleanup function
  Future<void> cleanUpAllPendingRequests() async {
    try {
      print('Starting cleanup of all pending requests...');
      
      // Get semua pending requests termasuk event_requests
      final collections = ['role_requests', 'destinasi_requests', 'event_requests', 'feedback'];
      int totalCleaned = 0;
      
      for (String collection in collections) {
        final pendingRequests = await _firestore
            .collection(collection)
            .where('status', isEqualTo: 'pending')
            .get();
            
        for (var doc in pendingRequests.docs) {
          await _firestore.collection(collection)
              .doc(doc.id)
              .update({'status': 'processed'});
          
          await _markRequestAsProcessed(doc.id);
          totalCleaned++;
        }
      }
      
      print('Cleaned up $totalCleaned pending requests');
      await _syncProcessedRequests();
    } catch (e) {
      print('Error in cleanup: $e');
    }
  }
}