import 'package:aura_trades/screens/pitchiq_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'goal_vantage_home.dart';
import 'login_screen.dart'; // Ensure this is imported

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    // Wait for the animation, then check auth
    Future.delayed(const Duration(milliseconds: 1800), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen()),
    );
  }

  Future<void> _checkAuthAndNavigate0() async {
    if (!mounted) return;

    // Use authStateChanges().first to wait for Firebase to accurately load the session.
    // This prevents race conditions on Web where currentUser might briefly be null.
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // DEBUG: Uncomment the line below to see who Firebase thinks is logged in
    // print('🔥 DEBUG: Current User is: ${user?.email}');

    if (!mounted) return;

    if (user != null) {
      // 1. User is genuinely logged in (Firebase restored the session)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen()),
      );
    } else if (AuthService.hasOnboarded) {
      // 2. Not logged in, but already onboarded -> Go to Login Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // 3. Not logged in and not onboarded -> Show Onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Image.asset("assets/logo.png", width: 250),
        ),
      ),
    );
  }
}