import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/premium_subscription.dart';

/// ============================================================================
/// SUBSCRIPTION SERVICE
/// ============================================================================
/// Handles all premium subscription logic with Flutterwave integration.
///
/// Features:
/// - Real-time subscription stream
/// - Free trial activation
/// - Flutterwave payment verification
/// - Subscription cancellation & resumption
/// - Auto-expiry checking
/// - Payment history tracking
///
/// Usage:
/// ```dart
/// // Watch subscription in real-time
/// StreamBuilder(
///   stream: SubscriptionService.instance.watchSubscription(),
///   builder: (context, snapshot) { ... },
/// )
///
/// // Quick synchronous check
/// if (SubscriptionService.instance.isPremium) { ... }
///
/// // Verify payment after Flutterwave charge
/// await SubscriptionService.instance.verifyAndActivate(
///   transactionId: response.transactionId!,
///   txRef: response.txRef!,
/// );
/// ```
/// ============================================================================

class SubscriptionService {
  // ==========================================================================
  // SINGLETON
  // ==========================================================================

  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  // ==========================================================================
  // CONFIGURATION
  // ⚠️ Replace these with your actual Flutterwave credentials
  // ⚠️ In production, move to environment variables / .env file
  // ==========================================================================

  /// Public test key placeholder (legacy)
  static const String publicKey = '';

  /// Secret key placeholder (legacy)
  static const String _secretKey = '';

  /// Payment Plan ID (create in Dashboard → Payment Plans)
  /// Create a plan: "GoalVantage Premium Monthly" at ₦2,500
  static const String monthlyPlanId = 'YOUR_FLUTTERWAVE_PLAN_ID';

  /// Monthly subscription price
  static const double monthlyPrice = 2500.00;

  /// Currency
  static const String currency = 'NGN';

  /// Free trial duration in days
  static const int trialDays = 7;

  /// Flutterwave API base URL
  static const String _baseUrl = 'https://api.flutterwave.com/v3';

  // Cached subscription for quick synchronous access
  PremiumSubscription? _cachedSub;

  // ==========================================================================
  // PUBLIC GETTERS
  // ==========================================================================

  /// Quick synchronous check — only reliable after stream has emitted once
  bool get isPremium => _cachedSub?.isActive ?? false;

  /// Current cached subscription (may be null)
  PremiumSubscription? get current => _cachedSub;

  /// Is user currently on a free trial?
  bool get isOnTrial => _cachedSub?.isTrial == true && _cachedSub?.isActive == true;

  // ==========================================================================
  // STREAM — Real-time subscription status
  // ==========================================================================

  /// Watch the user's subscription in real-time.
  /// Returns null if user is not signed in or has no subscription.
  Stream<PremiumSubscription?> watchSubscription() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('premium_subscriptions')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        _cachedSub = null;
        return null;
      }
      final sub = PremiumSubscription.fromMap(doc.data()!);
      _cachedSub = sub;
      return sub;
    });
  }

  /// One-time fetch (for non-reactive contexts like initial load)
  Future<PremiumSubscription?> getSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('premium_subscriptions')
          .doc(uid)
          .get();

      if (!doc.exists) {
        _cachedSub = null;
        return null;
      }

      final sub = PremiumSubscription.fromMap(doc.data()!);
      _cachedSub = sub;
      return sub;
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      return null;
    }
  }

  // ==========================================================================
  // START FREE TRIAL (No payment required)
  // ==========================================================================

  /// Activate a free trial without payment.
  /// Returns true if trial was successfully started.
  Future<bool> startFreeTrial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      // Check if user already had a trial
      final existing = await getSubscription();
      if (existing != null && (existing.isTrial || existing.status == 'active')) {
        debugPrint('User already has/had a trial or active subscription');
        return false;
      }

      final now = DateTime.now();
      final expiry = now.add(Duration(days: trialDays));

      final subscription = PremiumSubscription(
        uid: uid,
        planId: 'trial',
        planName: 'GoalVantage Premium Trial',
        status: 'trial',
        flutterwaveSubId: '',
        startDate: now,
        expiryDate: expiry,
        monthlyPrice: 0,
        currency: currency,
        billingDay: now.day,
        isTrial: true,
      );

      await FirebaseFirestore.instance
          .collection('premium_subscriptions')
          .doc(uid)
          .set(subscription.toMap());

      // Log trial start
      await FirebaseFirestore.instance.collection('payment_history').add({
        'uid': uid,
        'transactionId': 'trial_${now.millisecondsSinceEpoch}',
        'txRef': 'trial_${uid}_${now.millisecondsSinceEpoch}',
        'amount': 0,
        'currency': currency,
        'planId': 'trial',
        'status': 'trial_started',
        'processedAt': FieldValue.serverTimestamp(),
      });

      _cachedSub = subscription;
      return true;
    } catch (e) {
      debugPrint('Error starting trial: $e');
      return false;
    }
  }

  // ==========================================================================
  // VERIFY PAYMENT & ACTIVATE SUBSCRIPTION
  // Call this after Flutterwave returns a successful charge response
  // ==========================================================================

  /// Verifies the payment with Flutterwave server and activates subscription.
  /// Returns true if subscription was successfully activated.
  Future<bool> verifyAndActivate({
    required String transactionId,
    required String txRef,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      // 1. Verify with Flutterwave server-to-server
      final verifyUrl = '$_baseUrl/transactions/$transactionId/verify';
      final response = await http.get(
        Uri.parse(verifyUrl),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Verification failed: ${response.body}');
        return false;
      }

      final body = jsonDecode(response.body);
      final data = body['data'];
      final status = data['status'];
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final txCurrency = data['currency'];
      final subId = data['plan']?['id']?.toString() ?? '';

      // 2. Validate payment status
      if (status != 'successful') {
        debugPrint('Payment not successful: $status');
        return false;
      }

      // 3. Validate amount (prevent tampering)
      if (amount < monthlyPrice) {
        debugPrint('Insufficient amount: $amount < $monthlyPrice');
        return false;
      }

      // 4. Validate currency
      if (txCurrency != currency) {
        debugPrint('Currency mismatch: $txCurrency != $currency');
        return false;
      }

      // 5. Calculate expiry (30 days from now)
      final now = DateTime.now();
      DateTime finalExpiry = now.add(const Duration(days: 30));

      // 6. Check if user had an active subscription (extend instead of replace)
      final existing = await getSubscription();
      if (existing != null &&
          existing.isActive &&
          existing.expiryDate != null &&
          existing.expiryDate!.isAfter(now)) {
        // Extend from current expiry (renewal scenario)
        finalExpiry = existing.expiryDate!.add(const Duration(days: 30));
      }

      // 7. Write subscription to Firestore
      final subscription = PremiumSubscription(
        uid: uid,
        planId: monthlyPlanId,
        planName: 'GoalVantage Premium',
        status: 'active',
        flutterwaveSubId: subId,
        flutterwaveTxRef: txRef,
        startDate: existing?.startDate ?? now,
        expiryDate: finalExpiry,
        monthlyPrice: monthlyPrice,
        currency: currency,
        billingDay: now.day,
        isTrial: false,
      );

      await FirebaseFirestore.instance
          .collection('premium_subscriptions')
          .doc(uid)
          .set(subscription.toMap());

      // 8. Log transaction for audit trail
      await FirebaseFirestore.instance.collection('payment_history').add({
        'uid': uid,
        'transactionId': transactionId,
        'txRef': txRef,
        'amount': amount,
        'currency': txCurrency,
        'planId': monthlyPlanId,
        'status': 'successful',
        'processedAt': FieldValue.serverTimestamp(),
      });

      _cachedSub = subscription;
      return true;
    } catch (e) {
      debugPrint('Verify & activate error: $e');
      return false;
    }
  }

  // ==========================================================================
  // CANCEL SUBSCRIPTION
  // ==========================================================================

  /// Cancels the subscription. User keeps access until current period ends.
  Future<bool> cancelSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final sub = _cachedSub ?? await getSubscription();
    if (sub == null) return false;

    try {
      // 1. Cancel on Flutterwave (if it's a real paid subscription)
      if (sub.flutterwaveSubId.isNotEmpty && !sub.isTrial) {
        try {
          await http.post(
            Uri.parse('$_baseUrl/subscriptions/${sub.flutterwaveSubId}/cancel'),
            headers: {'Authorization': 'Bearer $_secretKey'},
          );
        } catch (e) {
          debugPrint('Flutterwave cancel failed (continuing): $e');
          // Continue anyway — local cancellation still works
        }
      }

      // 2. Update Firestore — keep access until current period ends
      await FirebaseFirestore.instance
          .collection('premium_subscriptions')
          .doc(uid)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // 3. Log cancellation
      await FirebaseFirestore.instance.collection('payment_history').add({
        'uid': uid,
        'transactionId': 'cancel_${DateTime.now().millisecondsSinceEpoch}',
        'txRef': sub.flutterwaveTxRef ?? '',
        'amount': 0,
        'currency': currency,
        'planId': sub.planId,
        'status': 'cancelled',
        'processedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Cancel error: $e');
      return false;
    }
  }

  // ==========================================================================
  // RESUME SUBSCRIPTION (after cancelling, before expiry)
  // ==========================================================================

  /// Resumes a cancelled subscription if still within the paid period.
  Future<bool> resumeSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final sub = _cachedSub ?? await getSubscription();
    if (sub == null) return false;

    // Can only resume if not yet expired
    if (sub.expiryDate != null && sub.expiryDate!.isBefore(DateTime.now())) {
      debugPrint('Cannot resume — subscription already expired');
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('premium_subscriptions')
          .doc(uid)
          .update({
        'status': 'active',
        'cancelledAt': FieldValue.delete(),
      });

      _cachedSub = sub.copyWith(status: 'active');
      return true;
    } catch (e) {
      debugPrint('Resume error: $e');
      return false;
    }
  }

  // ==========================================================================
  // EXPIRY CHECK — Call on app startup
  // ==========================================================================

  /// Checks if subscription has expired and updates status automatically.
  /// Call this in initState() of your main screen.
  Future<void> checkExpiry() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('premium_subscriptions')
          .doc(uid)
          .get();

      if (!doc.exists) return;

      final sub = PremiumSubscription.fromMap(doc.data()!);

      // Auto-expire if past expiry date
      if ((sub.status == 'active' || sub.status == 'trial') &&
          sub.expiryDate != null &&
          sub.expiryDate!.isBefore(DateTime.now())) {
        await doc.reference.update({'status': 'expired'});
        _cachedSub = sub.copyWith(status: 'expired');
        debugPrint('Subscription auto-expired');
      }
    } catch (e) {
      debugPrint('Expiry check error: $e');
    }
  }

  // ==========================================================================
  // PAYMENT HISTORY
  // ==========================================================================

  /// Stream of user's payment history (for Payment History screen)
  Stream<List<Map<String, dynamic>>> watchPaymentHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('payment_history')
        .where('uid', isEqualTo: uid)
        .orderBy('processedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ==========================================================================
  // GENERATE TRANSACTION REFERENCE
  // ==========================================================================

  /// Generates a unique transaction reference for Flutterwave
  String generateTxRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'gv_premium_${uid}_$timestamp';
  }

  // ==========================================================================
  // SIGN OUT CLEANUP
  // ==========================================================================

  /// Clears cached subscription. Call on sign out.
  void clearCache() {
    _cachedSub = null;
  }

  // ==========================================================================
  // DEBUG HELPER — Force set subscription (testing only)
  // ==========================================================================

  /// ⚠️ FOR TESTING ONLY — Do not use in production
  Future<void> debugForceActivate({int days = 30}) async {
    if (!kDebugMode) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final subscription = PremiumSubscription(
      uid: uid,
      planId: 'debug',
      planName: 'Debug Premium',
      status: 'active',
      flutterwaveSubId: 'debug',
      startDate: now,
      expiryDate: now.add(Duration(days: days)),
      monthlyPrice: monthlyPrice,
      currency: currency,
      billingDay: now.day,
    );

    await FirebaseFirestore.instance
        .collection('premium_subscriptions')
        .doc(uid)
        .set(subscription.toMap());

    _cachedSub = subscription;
    debugPrint('⚠️ DEBUG: Forced premium activation for $days days');
  }
}