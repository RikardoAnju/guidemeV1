import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Koleksi users di Firestore
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Mendapatkan semua user
  Future<List<UserModel>> getAllUsers() async {
    try {
      final QuerySnapshot snapshot = await _usersCollection.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

  // Mendapatkan user berdasarkan ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final DocumentSnapshot doc = await _usersCollection.doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromFirestore(data, doc.id);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      rethrow;
    }
  }

  // Membuat user baru
  Future<void> createUser(UserModel user) async {
    try {
      // Membuat akun baru di Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: user.email,
        password: 'password123', // Password sementara, sebaiknya digenerate secara random
      );
      
      // Membuat dokumen user di Firestore
      await _usersCollection.doc(userCredential.user!.uid).set(user.toMap());
      
      // Kirim email verifikasi
      await userCredential.user!.sendEmailVerification();
      
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Memperbarui user
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(userId).update(data);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Menghapus user
  Future<void> deleteUser(String userId) async {
    try {
      // Mendapatkan referensi user dari Auth
      User? user = await _auth.currentUser;
      
      // Menghapus dari Firestore
      await _usersCollection.doc(userId).delete();
      
      // Jika administrator menghapus dirinya sendiri
      if (user != null && user.uid == userId) {
        await user.delete();
      } else {
        // Fitur untuk menghapus user dari Auth memerlukan Cloud Function
        // karena admin hanya bisa menghapus dirinya sendiri di client-side
        // Solusi lengkap butuh Cloud Function untuk menghapus user dari Auth
      }
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  // Mengubah status user
  Future<void> changeUserStatus(String userId, String newStatus) async {
    try {
      await _usersCollection.doc(userId).update({
        'status': newStatus,
      });
    } catch (e) {
      print('Error changing user status: $e');
      rethrow;
    }
  }

  // Mengubah role user
  Future<void> changeUserRole(String userId, String newRole) async {
    try {
      await _usersCollection.doc(userId).update({
        'role': newRole,
      });
    } catch (e) {
      print('Error changing user role: $e');
      rethrow;
    }
  }

  // Mencari user berdasarkan query
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      // Firestore tidak mendukung pencarian teks penuh
      // Ini adalah implementasi sederhana menggunakan where
      final QuerySnapshot snapshot = await _usersCollection
          .where('nama', isGreaterThanOrEqualTo: query)
          .where('nama', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      final List<UserModel> users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromFirestore(data, doc.id);
      }).toList();
      
      // Juga cari berdasarkan email
      final QuerySnapshot emailSnapshot = await _usersCollection
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      final List<UserModel> emailUsers = emailSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromFirestore(data, doc.id);
      }).toList();
      
      // Gabungkan hasil dan hapus duplikat
      final Set<String> uniqueIds = {};
      final List<UserModel> result = [];
      
      for (var user in [...users, ...emailUsers]) {
        if (!uniqueIds.contains(user.id)) {
          uniqueIds.add(user.id);
          result.add(user);
        }
      }
      
      return result;
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }

  // Update waktu terakhir aktif
  Future<void> updateLastActive(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last active: $e');
      // Non-critical error, jadi tidak rethrow
    }
  }
}