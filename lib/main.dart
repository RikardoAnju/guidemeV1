import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guide_me/Splasscreen.dart';

late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  prefs = await SharedPreferences.getInstance();

  await dotenv.load(fileName: "mailersend-proxy/.env");

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
      ),
    );
    print('✅ Firebase initialized successfully.');
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        await prefs.remove('user_role');
        print('👤 User is signed out, cleared role data');
      } else {
        _updateUserRoleCache(user.uid);
        print('👤 Auth state changed for user: ${user.uid}');
      }
    });
    
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
  }

  runApp(const MyApp());
}

// Function update cache user role
Future<void> _updateUserRoleCache(String uid) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
        
    if (userDoc.exists) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'] ?? 'user';
      await prefs.setString('user_role', role);
      print('✅ User role updated in cache: $role');
    }
  } catch (e) {
    print('❌ Error updating user role cache: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      themeMode: ThemeMode.system, // Pakai settingan device
      home: const SplashScreen(),
    );
  }
}

// ========== MailerSend Env Helpers ========== //

String getMailerSendApiKey() {
  final apiKey = dotenv.env['MAILERSEND_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ MAILERSEND_API_KEY tidak ditemukan di .env');
  }
  return apiKey ?? '';
}

String getMailerSendSenderEmail() {
  final sender = dotenv.env['MAILERSEND_SENDER_EMAIL'];
  if (sender == null || sender.isEmpty) {
    print('❌ MAILERSEND_SENDER_EMAIL tidak ditemukan di .env');
  }
  return sender ?? '';
}

// ========== Auth Service ========== //

class AuthService {
  static Future<String?> getCachedUserRole() async {
    return prefs.getString('user_role');
  }
  
  static Future<void> saveUserRole(String role) async {
    await prefs.setString('user_role', role);
  }
  
  static Future<void> clearUserData() async {
    await prefs.remove('user_role');
  }
  
  static Future<String?> verifyUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
          
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'user';
        await saveUserRole(role);
        return role;
      }
      return null;
    } catch (e) {
      print('❌ Error verifying user role: $e');
      return null;
    }
  }
}
