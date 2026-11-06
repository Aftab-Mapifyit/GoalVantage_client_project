import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Result wrapper for purchase attempts
class PurchaseResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;

  const PurchaseResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.errorMessage,
  });

  factory PurchaseResult.success() => const PurchaseResult(isSuccess: true);
  factory PurchaseResult.cancelled() => const PurchaseResult(isSuccess: false, isCancelled: true);
  factory PurchaseResult.failure(String message) => PurchaseResult(isSuccess: false, errorMessage: message);
}

/// Result wrapper for restore attempts
class RestoreResult {
  final bool isSuccess;
  final bool hasActiveSubscription;
  final String? message;

  const RestoreResult({
    required this.isSuccess,
    required this.hasActiveSubscription,
    this.message,
  });
}

/// ============================================================================
/// REVENUECAT SERVICE (iOS In-App Purchase Architecture)
/// ============================================================================
/// Enterprise-grade, zero-trust subscription management for Apple StoreKit.
///
/// Security Highlights:
/// - Uses ONLY public SDK keys; zero private/secret keys stored on device.
/// - Cryptographic server-to-server receipt validation performed by Apple + RevenueCat.
/// - Bound to Firebase Auth UID to prevent account sharing and receipt theft.
/// - Synchronizes subscription state with Firestore for seamless cross-platform
///   compatibility without modifying Android behavior.
/// ============================================================================
class RevenueCatService {
  RevenueCatService._internal();
  static final RevenueCatService instance = RevenueCatService._internal();

  // ---------------------------------------------------------------------------
  // CONFIGURATION CONSTANTS
  // ---------------------------------------------------------------------------
  /// Public RevenueCat Apple API Key (Safe to store in client code).
  /// Replace with your actual RevenueCat public key from Dashboard -> Project Settings -> API Keys
  static const String appleApiKey = 'appl_PLACEHOLDER_REVENUECAT_PUBLIC_KEY';

  /// Entitlement ID configured in RevenueCat dashboard (e.g. 'vip_access')
  static const String vipEntitlementId = 'vip_access';

  /// Standard Package / Product ID for $25/month subscription
  static const String monthlyProductId = 'vip_monthly_25';

  // ---------------------------------------------------------------------------
  // STATE MANAGEMENT
  // ---------------------------------------------------------------------------
  bool _isConfigured = false;
  final ValueNotifier<bool> isVipNotifier = ValueNotifier<bool>(false);

  /// Synchronous quick check for VIP status
  bool get isVip => isVipNotifier.value;

  /// Check whether RevenueCat is initialized
  bool get isConfigured => _isConfigured;

  // ---------------------------------------------------------------------------
  // INITIALIZATION (Call once on app launch)
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    // Strict platform check: Only run RevenueCat on iOS to keep Android 100% untouched
    if (!Platform.isIOS) {
      debugPrint('ℹ️ RevenueCatService: Skipping initialization (Not iOS device).');
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      } else {
        await Purchases.setLogLevel(LogLevel.error);
      }

      final configuration = PurchasesConfiguration(appleApiKey);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        configuration.appUserID = currentUid;
      }

      await Purchases.configure(configuration);
      _isConfigured = true;
      debugPrint('✅ RevenueCatService: Configured successfully on iOS.');

      // If running with placeholder key, log friendly hint and skip remote calls
      if (appleApiKey.contains('PLACEHOLDER')) {
        debugPrint('ℹ️ RevenueCatService: Running with placeholder key. Connect real Apple Public Key from RevenueCat to enable live purchases.');
        return;
      }

      // Listen to customer info changes in real-time
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

      // Automatically sync RevenueCat whenever Firebase Auth state changes
      FirebaseAuth.instance.authStateChanges().listen((user) {
        syncUser(user?.uid);
      });

      // Initial check
      await checkVipStatus();
    } catch (e) {
      debugPrint('⚠️ RevenueCatService: Init error (Expected before real API key is set): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // USER AUTHENTICATION SYNC
  // ---------------------------------------------------------------------------
  /// Bind the authenticated Firebase User ID to RevenueCat
  Future<void> syncUser(String? uid) async {
    if (!Platform.isIOS || !_isConfigured) return;

    try {
      if (uid != null && uid.isNotEmpty) {
        final logInResult = await Purchases.logIn(uid);
        _onCustomerInfoUpdated(logInResult.customerInfo);
        debugPrint('✅ RevenueCatService: Logged in user $uid');
      } else {
        // Only log out if the current RevenueCat user is not already anonymous
        final isAnonymous = await Purchases.isAnonymous;
        if (!isAnonymous) {
          final customerInfo = await Purchases.logOut();
          _onCustomerInfoUpdated(customerInfo);
          debugPrint('✅ RevenueCatService: Logged out user');
        }
      }
    } catch (e) {
      debugPrint('⚠️ RevenueCatService: syncUser error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ENTITLEMENT CHECK
  // ---------------------------------------------------------------------------
  /// Check current customer entitlements
  Future<bool> checkVipStatus() async {
    if (!Platform.isIOS || !_isConfigured) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _onCustomerInfoUpdated(customerInfo);
      return isVip;
    } catch (e) {
      debugPrint('⚠️ RevenueCatService: checkVipStatus error: $e');
      return false;
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    final hasVip = customerInfo.entitlements.active.containsKey(vipEntitlementId);
    isVipNotifier.value = hasVip;
    debugPrint('ℹ️ RevenueCatService: VIP status updated -> $hasVip');

    // Sync to Firestore for cross-platform availability (without affecting Android)
    if (hasVip) {
      _syncVipToFirestore(customerInfo);
    }
  }

  // ---------------------------------------------------------------------------
  // OFFERINGS / PACKAGES
  // ---------------------------------------------------------------------------
  /// Fetch available offerings configured on RevenueCat
  Future<Offerings?> getOfferings() async {
    if (!Platform.isIOS || !_isConfigured) return null;

    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('⚠️ RevenueCatService: getOfferings error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PURCHASE FLOW
  // ---------------------------------------------------------------------------
  /// Trigger an Apple StoreKit purchase for a given package
  Future<PurchaseResult> purchasePackage(Package package) async {
    if (!Platform.isIOS) {
      return PurchaseResult.failure('In-App Purchases are only available on iOS.');
    }

    if (!_isConfigured) {
      return PurchaseResult.failure('Store is initializing. Please try again shortly.');
    }

    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );

      final hasVip = purchaseResult.customerInfo.entitlements.active.containsKey(vipEntitlementId);
      if (hasVip) {
        isVipNotifier.value = true;
        await _syncVipToFirestore(purchaseResult.customerInfo);
        return PurchaseResult.success();
      } else {
        return PurchaseResult.failure('Payment completed, but VIP entitlement was not unlocked. Please contact support.');
      }
    } on PurchasesErrorCode catch (errorCode) {
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled();
      }
      return PurchaseResult.failure(_mapErrorCodeToMessage(errorCode));
    } catch (e) {
      return PurchaseResult.failure('An unexpected error occurred during purchase: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // RESTORE PURCHASES (Apple Mandatory Requirement)
  // ---------------------------------------------------------------------------
  /// Restore previous purchases for Apple App Store guidelines
  Future<RestoreResult> restorePurchases() async {
    if (!Platform.isIOS) {
      return const RestoreResult(
        isSuccess: false,
        hasActiveSubscription: false,
        message: 'Restore purchases is only available on iOS.',
      );
    }

    if (!_isConfigured) {
      return const RestoreResult(
        isSuccess: false,
        hasActiveSubscription: false,
        message: 'Store is initializing. Please try again in a few moments.',
      );
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final hasVip = customerInfo.entitlements.active.containsKey(vipEntitlementId);
      isVipNotifier.value = hasVip;

      if (hasVip) {
        await _syncVipToFirestore(customerInfo);
        return const RestoreResult(
          isSuccess: true,
          hasActiveSubscription: true,
          message: 'Your VIP subscription has been successfully restored!',
        );
      } else {
        return const RestoreResult(
          isSuccess: true,
          hasActiveSubscription: false,
          message: 'No active VIP subscription was found for this Apple ID.',
        );
      }
    } catch (e) {
      return RestoreResult(
        isSuccess: false,
        hasActiveSubscription: false,
        message: 'Failed to restore purchases: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CROSS-PLATFORM FIRESTORE SYNC
  // ---------------------------------------------------------------------------
  /// Safely mirrors the verified Apple purchase into Firestore so that
  /// if this user logs in on Android, Android will also grant access.
  Future<void> _syncVipToFirestore(CustomerInfo customerInfo) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final entitlement = customerInfo.entitlements.active[vipEntitlementId];
      final expirationDate = entitlement?.expirationDate != null
          ? DateTime.tryParse(entitlement!.expirationDate!)
          : DateTime.now().add(const Duration(days: 30));

      final payload = {
        'category': 'premium',
        'status': 'active',
        'provider': 'apple_app_store',
        'periodDays': 30,
        'periodLabel': '1 month',
        'startDate': Timestamp.fromDate(DateTime.now()),
        'endDate': expirationDate != null ? Timestamp.fromDate(expirationDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      await db
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc('premium')
          .set(payload, SetOptions(merge: true));

      debugPrint('✅ RevenueCatService: Synced Apple subscription to Firestore.');
    } catch (e) {
      debugPrint('⚠️ RevenueCatService: Firestore sync error (non-fatal): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ERROR MESSAGE MAPPER
  // ---------------------------------------------------------------------------
  String _mapErrorCodeToMessage(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment is pending approval from Apple. Access will unlock once confirmed.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'This subscription is currently unavailable in your region or account.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device or account (e.g. Parental Controls).';
      case PurchasesErrorCode.networkError:
        return 'Network connection issue. Please check your internet and try again.';
      case PurchasesErrorCode.storeProblemError:
        return 'Apple App Store is experiencing technical difficulties. Please try again later.';
      default:
        return 'Purchase could not be completed. Please try again.';
    }
  }
}
