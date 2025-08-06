import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ambil user yang sedang login
  Future<User?> getCurrentUser() async {
    return _firebaseAuth.currentUser;
  }

  // Ambil role user berdasarkan UID dari Firestore
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()!.containsKey('role')) {
        return doc['role'];
      }
      return 'guest';
    } catch (e) {
      print('Error getting user role: $e');
      return 'guest';
    }
  }
}
