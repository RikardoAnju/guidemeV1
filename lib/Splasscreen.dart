import 'package:flutter/material.dart';
import 'package:guide_me/user/home.dart';
import 'admin/adminpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  bool _moveLogo = false;
  bool _showText = false;
  bool _hideSplash = false;

  @override
  void initState() {
    super.initState();

    // Start animation sequence
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _moveLogo = true;
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showText = true;
            });
          }
        });
      }
    });

    // Check authentication and navigate after splash animation
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hideSplash = true;
        });

        _checkAuthAndNavigate();
      }
    });
  }

  // Method to check authentication state and navigate accordingly
  Future<void> _checkAuthAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user is logged in and get their role
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String userRole = prefs.getString('userRole') ?? '';

      Widget destination;

      if (isLoggedIn) {
        // Navigate based on user role
        switch (userRole) {
          case 'admin':
            destination = const AdminPage();
            break;
          case 'owner':
            destination = const HomePage();
            break;
          case 'user':
            destination = const HomePage();
            break;
          default:
            destination = const HomePage();
        }
      } else {
        destination = const HomePage(); // Default for non-logged in users
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder:
                (context, animation, secondaryAnimation) => destination,
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      print('Error during authentication check: $e');
      // If there's an error, default to home page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  Widget buildSplashScreenContent() {
    return Opacity(
      opacity: _hideSplash ? 0.0 : 1.0,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Color(0xFF5ABB4D),
              height: MediaQuery.of(context).size.height * 0.2,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            left:
                _moveLogo
                    ? MediaQuery.of(context).size.width * 0.3
                    : MediaQuery.of(context).size.width * 0.5 - 40,
            top: MediaQuery.of(context).size.height * 0.25,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo5.png', width: 80, height: 80),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _showText ? 1.0 : 0.0,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Guide ME',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cloud animation at the bottom of the screen
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: double.infinity,
              child: CustomPaint(painter: CloudPainter()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: buildSplashScreenContent());
  }
}

class CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.white;
    Path path = Path();

    double width = size.width;
    double height = size.height;
    double baseHeight = height * 0.8; // Start cloud at middle of screen
    double stepWidth = width / 5; // 5 sections for stepped effect
    double stepHeight = height * 0.1; // Height of each step

    path.moveTo(0, baseHeight);

    for (int i = 0; i < 5; i++) {
      double startX = i * stepWidth;
      double currentHeight = baseHeight - (i * stepHeight);

      path.quadraticBezierTo(
        startX + stepWidth / 2,
        currentHeight - stepHeight / 2,
        startX + stepWidth,
        currentHeight,
      );
    }

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
