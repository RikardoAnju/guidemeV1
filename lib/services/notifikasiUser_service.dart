import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; 

class UserNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String userId;
  final bool isRead;
  final DateTime timestamp;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalData;

  UserNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    required this.isRead,
    required this.timestamp,
    required this.createdAt,
    this.additionalData,
  });

  factory UserNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? '',
      userId: data['userId'] ?? '',
      isRead: data['isRead'] ?? data['read'] ?? false,
      timestamp: _safeTimestampToDateTime(data['timestamp']),
      createdAt: _safeTimestampToDateTime(data['createdAt']),
      additionalData: data,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'userId': userId,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      ...?additionalData,
    };
  }

  static DateTime _safeTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }
}

class FeedbackNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String userId;
  final String feedbackId;
  final String feedbackCategory;
  final String adminReply;
  final bool isRead;
  final DateTime timestamp;
  final DateTime createdAt;

  FeedbackNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    required this.feedbackId,
    required this.feedbackCategory,
    required this.adminReply,
    required this.isRead,
    required this.timestamp,
    required this.createdAt,
  });

  factory FeedbackNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle nested data structure from your Firestore
    final nestedData = data['data'] as Map<String, dynamic>? ?? {};
    
    return FeedbackNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? '',
      userId: data['userId'] ?? '',
      feedbackId: data['feedbackId'] ?? nestedData['feedbackId'] ?? '',
      feedbackCategory: data['feedbackCategory'] ?? nestedData['feedbackCategory'] ?? '',
      adminReply: data['adminReply'] ?? nestedData['adminReply'] ?? '',
      isRead: data['isRead'] ?? false,
      timestamp: UserNotification._safeTimestampToDateTime(data['timestamp']),
      createdAt: UserNotification._safeTimestampToDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'userId': userId,
      'feedbackId': feedbackId,
      'feedbackCategory': feedbackCategory,
      'adminReply': adminReply,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class NotifikasiUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _notificationsCollection = 'notifications';
  final String _feedbackNotificationsCollection = 'notifications_feedback';

  // Singleton pattern
  static final NotifikasiUserService _instance = NotifikasiUserService._internal();
  factory NotifikasiUserService() => _instance;
  NotifikasiUserService._internal();

  // ==================== GENERAL NOTIFICATIONS ====================

  // SOLUTION 1: Stream notifikasi dengan sorting di memory (recommended for small datasets)
  Stream<List<UserNotification>> getUserNotificationsStream(String userId) {
    try {
      return _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          // Remove orderBy to avoid index requirement
          .snapshots()
          .map((snapshot) {
            final notifications = snapshot.docs
                .map((doc) => UserNotification.fromFirestore(doc))
                .toList();
            
            // Sort in memory by createdAt (descending)
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications;
          })
          .handleError((error) {
            print('Error in getUserNotificationsStream: $error');
            return <UserNotification>[];
          });
    } catch (e) {
      print('Error setting up getUserNotificationsStream: $e');
      return Stream.value(<UserNotification>[]);
    }
  }

  // SOLUTION 2: Stream with index (requires creating the index first)
  Stream<List<UserNotification>> getUserNotificationsStreamWithIndex(String userId) {
    try {
      // This will work ONLY after you create the composite index
      // Go to: https://console.firebase.google.com/project/microlearning-ea3cc/firestore/indexes
      // And create a composite index for:
      // Collection: notifications
      // Fields: userId (Ascending), createdAt (Descending)
      
      return _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => UserNotification.fromFirestore(doc))
              .toList())
          .handleError((error) {
            print('Error in getUserNotificationsStreamWithIndex: $error');
            // Fallback to non-indexed version
            return getUserNotificationsStream(userId).first;
          });
    } catch (e) {
      print('Error setting up getUserNotificationsStreamWithIndex: $e');
      return getUserNotificationsStream(userId);
    }
  }

  // SOLUTION 3: Paginated stream (for large datasets)
  Stream<List<UserNotification>> getUserNotificationsPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    try {
      Query query = _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      return query
          .snapshots()
          .map((snapshot) {
            final notifications = snapshot.docs
                .map((doc) => UserNotification.fromFirestore(doc))
                .toList();
            
            // Sort in memory
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications;
          });
    } catch (e) {
      print('Error in getUserNotificationsPaginated: $e');
      return Stream.value(<UserNotification>[]);
    }
  }

  // Get notifications without real-time updates (fallback tanpa index)
  Future<List<UserNotification>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      final notifications = snapshot.docs
          .map((doc) => UserNotification.fromFirestore(doc))
          .toList();
      
      // Sort in memory by createdAt
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return notifications;
    } catch (e) {
      print('Error getting user notifications: $e');
      return [];
    }
  }

  // ==================== FEEDBACK NOTIFICATIONS ====================

  // Stream feedback notifications untuk user tertentu (with in-memory sorting)
  Stream<List<FeedbackNotification>> getFeedbackNotificationsStream(String userId) {
    try {
      return _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          // Remove orderBy to avoid index requirement
          .snapshots()
          .map((snapshot) {
            final notifications = snapshot.docs
                .map((doc) => FeedbackNotification.fromFirestore(doc))
                .toList();
            
            // Sort in memory by createdAt (descending)
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications;
          })
          .handleError((error) {
            print('Error in getFeedbackNotificationsStream: $error');
            return <FeedbackNotification>[];
          });
    } catch (e) {
      print('Error setting up getFeedbackNotificationsStream: $e');
      return Stream.value(<FeedbackNotification>[]);
    }
  }

  // Stream feedback notifications with index (requires creating the index first)
  Stream<List<FeedbackNotification>> getFeedbackNotificationsStreamWithIndex(String userId) {
    try {
      return _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => FeedbackNotification.fromFirestore(doc))
              .toList())
          .handleError((error) {
            print('Error in getFeedbackNotificationsStreamWithIndex: $error');
            return getFeedbackNotificationsStream(userId).first;
          });
    } catch (e) {
      print('Error setting up getFeedbackNotificationsStreamWithIndex: $e');
      return getFeedbackNotificationsStream(userId);
    }
  }

  // Get feedback notifications without real-time updates (fallback tanpa index)
  Future<List<FeedbackNotification>> getFeedbackNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      final notifications = snapshot.docs
          .map((doc) => FeedbackNotification.fromFirestore(doc))
          .toList();
      
      // Sort in memory by createdAt
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return notifications;
    } catch (e) {
      print('Error getting feedback notifications: $e');
      return [];
    }
  }

  // ==================== COMBINED FUNCTIONS ====================

  // Get combined notifications from both collections
  Future<List<dynamic>> getAllNotifications(String userId) async {
    try {
      // Get notifications from both collections in parallel
      final results = await Future.wait([
        getUserNotifications(userId),
        getFeedbackNotifications(userId),
      ]);
      
      final notifications = results[0] as List<UserNotification>;
      final feedbackNotifications = results[1] as List<FeedbackNotification>;

      // Combine and sort by createdAt
      final combined = <dynamic>[...notifications, ...feedbackNotifications];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return combined;
    } catch (e) {
      print('Error getting all notifications: $e');
      return [];
    }
  }

  // IMPROVED: Stream combined notifications using StreamController
  Stream<List<dynamic>> getAllNotificationsStream(String userId) async* {
    try {
      // Use StreamController to combine multiple streams
      final controller = StreamController<List<dynamic>>();
      
      // Listen to both streams
      final subscription1 = getUserNotificationsStream(userId).listen(null);
      final subscription2 = getFeedbackNotificationsStream(userId).listen(null);
      
      // Combine the streams
      subscription1.onData((notifications) async {
        try {
          final feedbackNotifications = await getFeedbackNotifications(userId);
          final combined = <dynamic>[...notifications, ...feedbackNotifications];
          combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (!controller.isClosed) controller.add(combined);
        } catch (e) {
          print('Error combining notifications in stream: $e');
          if (!controller.isClosed) controller.add(notifications);
        }
      });

      subscription2.onData((feedbackNotifications) async {
        try {
          final notifications = await getUserNotifications(userId);
          final combined = <dynamic>[...notifications, ...feedbackNotifications];
          combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (!controller.isClosed) controller.add(combined);
        } catch (e) {
          print('Error combining feedback notifications in stream: $e');
          if (!controller.isClosed) controller.add(feedbackNotifications);
        }
      });

      // Handle errors
      subscription1.onError((error) {
        print('Error in general notifications stream: $error');
      });

      subscription2.onError((error) {
        print('Error in feedback notifications stream: $error');
      });

      // Clean up when done
      controller.onCancel = () {
        subscription1.cancel();
        subscription2.cancel();
      };

      yield* controller.stream;
    } catch (e) {
      print('Error setting up combined stream: $e');
      yield <dynamic>[];
    }
  }

  // ALTERNATIVE: Simple combined stream (recommended)
  Stream<List<dynamic>> getAllNotificationsStreamSimple(String userId) async* {
    try {
      await for (final notifications in getUserNotificationsStream(userId)) {
        try {
          // Get feedback notifications as Future to avoid nested streams
          final feedbackNotifications = await getFeedbackNotifications(userId);
          final combined = <dynamic>[...notifications, ...feedbackNotifications];
          combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yield combined;
        } catch (e) {
          print('Error in combined stream: $e');
          yield notifications; // Return just general notifications on error
        }
      }
    } catch (e) {
      print('Error setting up combined stream: $e');
      yield <dynamic>[];
    }
  }

  // ==================== READ STATUS FUNCTIONS ====================

  // Get unread count dari kedua koleksi
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final results = await Future.wait([
        getUnreadNotificationsCount(userId),
        getUnreadFeedbackNotificationsCount(userId),
      ]);
      return results[0] + results[1];
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }

  // Get unread count untuk notifikasi umum
  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return 0;
    }
  }

  // Get unread count untuk feedback notifications
  Future<int> getUnreadFeedbackNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread feedback notifications count: $e');
      return 0;
    }
  }

  // Mark notification as read (auto-detect collection)
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('Attempting to mark notification as read: $notificationId');
      
      final now = Timestamp.fromDate(DateTime.now());
      
      // Try general notifications first
      final generalDocSnapshot = await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .get();
      
      if (generalDocSnapshot.exists) {
        await _firestore
            .collection(_notificationsCollection)
            .doc(notificationId)
            .update({
              'isRead': true,
              'timestamp': now,
            });
        print('Successfully marked general notification as read: $notificationId');
        return;
      }
      
      // Try feedback notifications
      final feedbackDocSnapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .doc(notificationId)
          .get();
      
      if (feedbackDocSnapshot.exists) {
        await _firestore
            .collection(_feedbackNotificationsCollection)
            .doc(notificationId)
            .update({
              'isRead': true,
              'timestamp': now,
            });
        print('Successfully marked feedback notification as read: $notificationId');
        return;
      }
      
      print('Notification not found in any collection: $notificationId');
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read (both collections)
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final now = Timestamp.fromDate(DateTime.now());
      
      // Mark general notifications as read
      final notificationsSnapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (var doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'timestamp': now,
        });
      }
      
      // Mark feedback notifications as read
      final feedbackSnapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (var doc in feedbackSnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'timestamp': now,
        });
      }
      
      await batch.commit();
      print('All notifications marked as read for user: $userId');
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // ==================== ADD NOTIFICATION FUNCTIONS ====================

  // Add general notification
  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    required String userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final now = DateTime.now();
      final notification = UserNotification(
        id: '',
        title: title,
        message: message,
        type: type,
        userId: userId,
        isRead: false,
        timestamp: now,
        createdAt: now,
        additionalData: additionalData,
      );

      final docRef = await _firestore
          .collection(_notificationsCollection)
          .add(notification.toFirestore());
          
      print('Notification added with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  // Add feedback notification (admin reply)
  Future<void> addFeedbackNotification({
    required String userId,
    required String feedbackId,
    required String feedbackCategory,
    required String adminReply,
  }) async {
    try {
      final now = DateTime.now();
      final notification = FeedbackNotification(
        id: '',
        title: 'Balasan Admin - $feedbackCategory',
        message: 'Admin telah membalas feedback Anda: $adminReply',
        type: 'admin_reply',
        userId: userId,
        feedbackId: feedbackId,
        feedbackCategory: feedbackCategory,
        adminReply: adminReply,
        isRead: false,
        timestamp: now,
        createdAt: now,
      );

      final docRef = await _firestore
          .collection(_feedbackNotificationsCollection)
          .add(notification.toFirestore());
          
      print('Feedback notification added with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding feedback notification: $e');
    }
  }

  // Specific notification types
  Future<void> addEventApprovalNotification({
    required String userId,
    required String eventName,
  }) async {
    await addNotification(
      title: 'Event Disetujui!',
      message: 'Event "$eventName" Anda telah disetujui dan akan segera ditampilkan di aplikasi.',
      type: 'approved',
      userId: userId,
      additionalData: {'eventName': eventName},
    );
  }

  Future<void> addEventRejectionNotification({
    required String userId,
    required String eventName,
  }) async {
    await addNotification(
      title: 'Event Ditolak',
      message: 'Maaf, event "$eventName" Anda telah ditolak.',
      type: 'rejected',
      userId: userId,
      additionalData: {'eventName': eventName},
    );
  }

  // Add destination rejection notification
  Future<void> addDestinationRejectionNotification({
    required String userId,
    required String destinationName,
  }) async {
    await addNotification(
      title: 'Rekomendasi Destinasi Ditolak',
      message: 'Maaf, rekomendasi destinasi "$destinationName" Anda telah ditolak.',
      type: 'destination_rejection',
      userId: userId,
      additionalData: {'destinationName': destinationName},
    );
  }

  // Add destination approval notification
  Future<void> addDestinationApprovalNotification({
    required String userId,
    required String destinationName,
  }) async {
    await addNotification(
      title: 'Rekomendasi Destinasi Disetujui',
      message: 'Selamat! Rekomendasi destinasi "$destinationName" Anda telah disetujui.',
      type: 'destination_approval',
      userId: userId,
      additionalData: {'destinationName': destinationName},
    );
  }

  // Add role rejection notification
  Future<void> addRoleRejectionNotification({
    required String userId,
    required String roleName,
  }) async {
    await addNotification(
      title: 'Permintaan Peran Ditolak',
      message: 'Maaf, permintaan peran "$roleName" Anda telah ditolak.',
      type: 'role_rejection',
      userId: userId,
      additionalData: {'roleName': roleName},
    );
  }

  // Add role approval notification
  Future<void> addRoleApprovalNotification({
    required String userId,
    required String roleName,
  }) async {
    await addNotification(
      title: 'Permintaan Peran Disetujui',
      message: 'Selamat! Permintaan peran "$roleName" Anda telah disetujui.',
      type: 'role_approval',
      userId: userId,
      additionalData: {'roleName': roleName},
    );
  }

  // ==================== DELETE FUNCTIONS ====================

  // Delete notification (auto-detect collection)
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Try general notifications first
      final generalDoc = await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .get();
      
      if (generalDoc.exists) {
        await _firestore.collection(_notificationsCollection).doc(notificationId).delete();
        print('General notification deleted successfully: $notificationId');
        return;
      }
      
      // Try feedback notifications
      final feedbackDoc = await _firestore
          .collection(_feedbackNotificationsCollection)
          .doc(notificationId)
          .get();
      
      if (feedbackDoc.exists) {
        await _firestore.collection(_feedbackNotificationsCollection).doc(notificationId).delete();
        print('Feedback notification deleted successfully: $notificationId');
        return;
      }
      
      print('Notification not found: $notificationId');
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete all notifications for user (both collections)
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete from notifications collection
      final notificationsSnapshot = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete from feedback notifications collection
      final feedbackSnapshot = await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in feedbackSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('All notifications deleted for user: $userId');
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  // ==================== UTILITY FUNCTIONS ====================

  // Check if composite indexes exist (for debugging)
  Future<bool> checkIndexesExist() async {
    try {
      // Try to perform the problematic queries
      await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: 'test')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      await _firestore
          .collection(_feedbackNotificationsCollection)
          .where('userId', isEqualTo: 'test')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      return true;
    } catch (e) {
      print('Composite indexes not found: $e');
      return false;
    }
  }
}