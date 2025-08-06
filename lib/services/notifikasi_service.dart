import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();

  // Inisialisasi notifikasi
  Future<void> initialize() async {
    // Konfigurasi untuk Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    // Konfigurasi untuk iOS
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Minta izin untuk push notifications
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  
  // Fungsi untuk mengirim notifikasi
  Future<void> sendNotification(String userId, String title, String message, bool isPush) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData != null && userData.containsKey('notificationSettings')) {
        final settings = userData['notificationSettings'];
        
        if (isPush && settings['pushEnabled'] == true) {
          // Kirim push notification ke perangkat
          await _sendPushNotification(userId, title, message);
        } else if (!isPush && settings['inAppEnabled'] == true) {
          // Simpan notifikasi in-app di database
          await _saveInAppNotification(userId, title, message);
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
  
  // Mengirim push notification menggunakan FCM token
  Future<void> _sendPushNotification(String userId, String title, String message) async {
    try {
      // Dapatkan FCM token pengguna dari Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData != null && userData.containsKey('fcmToken')) {
        final String fcmToken = userData['fcmToken'];
        
       
        await _showLocalNotification(title, message);
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }
  
  // Menyimpan notifikasi in-app ke Firestore
  Future<void> _saveInAppNotification(String userId, String title, String message) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error saving in-app notification: $e');
    }
  }
  
  // Menampilkan notifikasi lokal menggunakan flutter_local_notifications
  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'guide_me_channel',
      'Guide Me Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      0, // ID notifikasi
      title,
      body,
      platformChannelSpecifics,
    );
  }
  
  // Mendapatkan daftar notifikasi in-app untuk pengguna tertentu
  Stream<QuerySnapshot> getInAppNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  
  // Menandai notifikasi sebagai sudah dibaca
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}