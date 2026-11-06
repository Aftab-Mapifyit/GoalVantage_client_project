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
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _agreeTerms = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------- Firebase error mapping ----------
  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Something went wrong while creating your account. Please try again.';
    }
  }

  // ---------- Email sign-up ----------
  Future<void> _handleEmailSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreeTerms) {
      setState(() => _error = 'Please agree to the Terms of Service');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.signUpWithEmail(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
            'authProvider': user.providerData.isNotEmpty ? user.providerData.first.providerId : 'email',
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to save user to Firestore: $e');
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

  // ---------- Google sign-up ----------
  Future<void> _handleGoogleSignUp() async {
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
            'createdAt': FieldValue.serverTimestamp(),
            'authProvider': 'google',
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to save user to Firestore: $e');
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoalVantageHomeScreen()));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _firebaseErrorMessage(e.code));
    } on GoogleSignInException catch (e) {
      if (mounted) setState(() => _error = e.description ?? 'Google sign up failed.');
    } catch (e) {
      if (mounted) setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

            // Heading — Sharp editorial style
            Text(
              'JOIN ONYXBET',
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
              'Claim your welcome bonus and start betting the edge.',
              style: TextStyle(fontSize: 13, color: AppColors.foregroundSecondary, height: 1.4),
            ),
            const SizedBox(height: 36),

            // Name field
            AppTextField(
              label: 'FULL NAME',
              hint: 'Alexander Chen',
              icon: LucideIcons.user,
              controller: _nameController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),

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

            // Password field with strength meter
            Text(
              'PASSWORD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.foregroundSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _passwordController,
              hint: 'Min. 8 characters',
              validator: (v) => (v == null || v.length < 8) ? 'Min. 8 characters' : null,
            ),
            const SizedBox(height: 8),
            _PasswordStrengthMeter(password: _passwordController.text),
            const SizedBox(height: 16),

            // Confirm password field
            Text(
              'CONFIRM PASSWORD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.foregroundSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _confirmController,
              hint: 'Re-enter your password',
              validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_confirmController.text.isNotEmpty &&
                _confirmController.text == _passwordController.text) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(LucideIcons.check, size: 10, color: AppColors.positive),
                  const SizedBox(width: 4),
                  Text(
                    'Passwords match',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.positive),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Terms checkbox — Sharp square style
            GestureDetector(
              onTap: () => setState(() => _agreeTerms = !_agreeTerms),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: _agreeTerms ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: _agreeTerms ? AppColors.primary : AppColors.foregroundSecondary,
                        width: 1.5,
                      ),
                    ),
                    child: _agreeTerms
                        ? Icon(LucideIcons.check, size: 12, color: AppColors.primaryForeground)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 11, color: AppColors.foregroundSecondary, height: 1.4),
                        children: [
                          const TextSpan(text: 'I am 18+ and agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.foreground,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error banner
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            // Create account button
            GradientButton(
              label: 'CREATE ACCOUNT',
              icon: LucideIcons.arrowRight,
              loading: _isLoading,
              onPressed: _handleEmailSignUp,
            ),
            const SizedBox(height: 16),

            // Google button (moved to bottom)
            GoogleButton(
              onPressed: _handleGoogleSignUp,
              loading: _isLoading,
            ),
            const SizedBox(height: 28),

            // Sign in link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(fontSize: 13, color: AppColors.foregroundSecondary),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text(
                    'Sign in',
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

            // Trust signals — Sports betting focused
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
          // Ambient glows — subtle emerald + gold
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

// ---------- Password strength meter (sharp editorial style) ----------

class _PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const _PasswordStrengthMeter({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    String label;
    Color color;
    if (score <= 1) {
      label = 'WEAK';
      color = AppColors.negative;
    } else if (score == 2) {
      label = 'FAIR';
      color = AppColors.warning;
    } else if (score == 3) {
      label = 'GOOD';
      color = AppColors.secondary;
    } else {
      label = 'STRONG';
      color = AppColors.positive;
    }

    final bars = 4;
    final filled = (score / 5 * bars).ceil().clamp(0, bars);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(bars, (i) {
            final isFilled = i < filled;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isFilled ? color : AppColors.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ---------- Password field with toggle (sharp edges) ----------

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.hint,
    this.validator,
    this.onChanged,
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
              onChanged: widget.onChanged,
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

// ---------- Error banner (sharp editorial style) ----------

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

// ---------- Trust signal ----------

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
          ),
        ),
      ],
    );
  }
}