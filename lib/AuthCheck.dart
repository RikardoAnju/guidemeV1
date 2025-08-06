import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guide_me/Login.dart';
import 'package:guide_me/admin/adminpage.dart';
import 'package:guide_me/user/home.dart';
import 'main.dart'; 


class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  AuthCheckState createState() => AuthCheckState();
}

class AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    checkAuth();
  }
  
  Future<void> checkAuth() async {
    try {
      // Tunggu lebih lama untuk memastikan Firebase sepenuhnya terinisialisasi
      await Future.delayed(const Duration(seconds: 1));
      
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        try {
          // Reload user untuk memastikan status terbaru
          await user.reload();
          user = FirebaseAuth.instance.currentUser;
          
          // Verifikasi email
          if (!user!.emailVerified) {
            await FirebaseAuth.instance.signOut();
            await AuthService.clearUserData(); // Hapus data saat logout
            
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _navigateToLogin();
            }
            return;
          }
          
          // Coba ambil role dari SharedPreferences terlebih dahulu
          String? cachedRole = await AuthService.getCachedUserRole();
          
          // Jika ada cache role, gunakan itu dulu untuk navigasi cepat
          if (cachedRole != null) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Navigasi sesuai role yang di-cache
              if (cachedRole == 'admin') {
                _navigateToAdmin();
              } else {
                _navigateToHome();
              }
              
              // Verifikasi role dari server di background
              _verifyAndUpdateIfNeeded(user.uid, cachedRole);
              return;
            }
          }
          
          // Jika tidak ada cache, ambil dari Firestore
          String? serverRole = await AuthService.verifyUserRole(user.uid);
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            if (serverRole != null) {
              if (serverRole == 'admin') {
                _navigateToAdmin();
              } else {
                _navigateToHome();
              }
            } else {
              _navigateToLogin();
            }
          }
        } catch (e) {
          print("Error during auth check: $e");
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _navigateToLogin();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _navigateToLogin();
        }
      }
    } catch (e) {
      print("Critical error in checkAuth: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _navigateToLogin();
      }
    }
  }
  
  // Metode untuk verifikasi dan update role jika diperlukan
  Future<void> _verifyAndUpdateIfNeeded(String uid, String cachedRole) async {
    String? serverRole = await AuthService.verifyUserRole(uid);
    
    if (serverRole != null && serverRole != cachedRole && mounted) {
      // Jika role di server berbeda dengan yang di cache, navigasi ulang
      if (serverRole == 'admin' && cachedRole != 'admin') {
        _navigateToAdmin();
      } else if (serverRole != 'admin' && cachedRole == 'admin') {
        _navigateToHome();
      }
    }
  }

  // Metode navigasi yang konsisten untuk ke AdminPage
  void _navigateToAdmin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminPage()),
      (route) => false, // Hapus semua route sebelumnya dari stack
    );
  }

  // Metode navigasi yang konsisten untuk ke HomePage
  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false, // Hapus semua route sebelumnya dari stack
    );
  }

  // Metode navigasi yang konsisten untuk ke LoginScreen
  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Hapus semua route sebelumnya dari stack
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green),
            )
          : Container(), // Ini tidak akan terlihat karena kita selalu navigate
    );
  }
}