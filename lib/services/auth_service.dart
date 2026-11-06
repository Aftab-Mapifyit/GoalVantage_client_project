import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 1. Use the singleton instance instead of the removed constructor
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ---------- Onboarding flag ----------
  static bool get hasOnboarded => true; // implement later with SharedPreferences

  // ---------- Email / Password Sign‑In ----------
  static Future<UserCredential> signInWithEmail(
      String email, String password) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow; // let the UI catch it
    } catch (e) {
      rethrow;
    }
  }

  // ---------- Email / Password Sign‑Up ----------
  static Future<UserCredential> signUpWithEmail(
      String name, String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // ---------- Google Sign‑In ----------
  static Future<UserCredential?> signInWithGoogle() async {
    // 2. Ensure the plugin is initialized before use
    await _googleSignIn.initialize();

    try {
      // 3. authenticate() replaces signIn()
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // 4. idToken is available synchronously from the authentication property
      final String? idToken = googleUser.authentication.idToken;

      // 5. accessToken is now retrieved explicitly via the authorizationClient
      final authorization = await googleUser.authorizationClient
          .authorizeScopes(['email', 'profile']);
      final String? accessToken = authorization.accessToken;

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      // 6. Handle user cancellation (authenticate() throws instead of returning null)
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // User cancelled the sign-in
      }
      rethrow;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // ---------- Sign Out ----------
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    // Ensure initialization before signing out of Google
    await _googleSignIn.initialize();
    await _googleSignIn.signOut();
  }

  // ---------- Get current user ----------
  static User? get currentUser => FirebaseAuth.instance.currentUser;

  // ---------- Password reset ----------
  static Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }
}