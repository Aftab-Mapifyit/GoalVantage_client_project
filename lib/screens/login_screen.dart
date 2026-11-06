import 'package:aura_trades/screens/pitchiq_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_colors.dart';
import '../widgets/core_widgets.dart';
import '../services/auth_service.dart';
import 'goal_vantage_home.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _rememberMe = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------- Firebase error mapping ----------
  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Sign in failed. Please check your credentials and try again.';
    }
  }

  // ---------- Email sign-in ----------
  Future<void> _handleEmailSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Firestore update failed: $e');
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen()));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _firebaseErrorMessage(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Google sign-in ----------
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userCred = await AuthService.signInWithGoogle();

      if (userCred == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'name': user.displayName ?? 'Unnamed',
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Firestore update failed: $e');
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen()));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _firebaseErrorMessage(e.code));
    } on GoogleSignInException catch (e) {
      if (mounted) {
        setState(() => _error = e.description ?? 'Google sign in failed.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Forgot password dialog ----------
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'RESET PASSWORD',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: AppColors.foreground, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'EMAIL ADDRESS',
            labelStyle: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: AppColors.foregroundSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text(
                      'Reset link sent to $email',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.negative,
                    content: Text(
                      'Error: ${(e as FirebaseAuthException).message}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: const Text(
              'SEND',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Build form ----------
  Widget _buildForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand logo
            Center(
              child: InkWell(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen())),
                child: Image.asset(
                  'assets/logo.png',
                  height: 90,
                  // width: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Heading
            Text(
              'SIGN IN',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: AppColors.foreground,
                letterSpacing: -1.5,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Access your bankroll, open bets, and VIP rewards.',
              style: TextStyle(fontSize: 13, color: AppColors.foregroundSecondary, height: 1.4),
            ),
            const SizedBox(height: 36),

            // Email field
            AppTextField(
              label: 'EMAIL ADDRESS',
              hint: 'you@example.com',
              icon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
            ),
            const SizedBox(height: 16),

            // Password label + forgot
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.foregroundSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: _showForgotPasswordDialog,
                  child: Text(
                    'Forgot?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Password field
            _PasswordField(
              controller: _passwordController,
              hint: 'Enter your password',
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: 16),

            // Remember me
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _rememberMe ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: _rememberMe ? AppColors.primary : AppColors.foregroundSecondary,
                        width: 1.5,
                      ),
                    ),
                    child: _rememberMe
                        ? Icon(LucideIcons.check, size: 12, color: AppColors.primaryForeground)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Keep me signed in for 30 days',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.foregroundSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error display
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            // Sign in button
            GradientButton(
              label: 'SIGN IN',
              icon: LucideIcons.arrowRight,
              loading: _isLoading,
              onPressed: _handleEmailSignIn,
            ),
            const SizedBox(height: 16),

            // Google button (moved to bottom)
            GoogleButton(
              onPressed: _handleGoogleSignIn,
              loading: _isLoading,
            ),
            const SizedBox(height: 28),

            // Register link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "New to OnyxBet? ",
                  style: TextStyle(fontSize: 13, color: AppColors.foregroundSecondary),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: Text(
                    'Join now',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Trust signals
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _Trust(icon: LucideIcons.shieldCheck, label: 'Licensed'),
                  SizedBox(width: 20),
                  _Trust(icon: LucideIcons.userCheck, label: '18+ Verified'),
                  SizedBox(width: 20),
                  _Trust(icon: LucideIcons.lock, label: 'Secure Payments'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient glows
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.2),
                    radius: 0.8,
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, 1.0),
                    radius: 0.7,
                    colors: [
                      AppColors.secondary.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Helper widgets ----------

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(LucideIcons.lock, size: 14, color: AppColors.foregroundSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              obscureText: _obscure,
              validator: widget.validator,
              style: TextStyle(fontSize: 14, color: AppColors.foreground, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: AppColors.foregroundSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 14,
              color: AppColors.foregroundSecondary,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negative.withOpacity(0.08),
        border: Border.all(color: AppColors.negative.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.negative),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Trust({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
      ],
    );
  }
}