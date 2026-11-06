import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumSubscription {
  final String uid;
  final String planId;
  final String planName;
  final String status; // 'active', 'expired', 'cancelled', 'past_due', 'trial'
  final String flutterwaveSubId;
  final String? flutterwaveTxRef;
  final DateTime startDate;
  final DateTime? expiryDate;
  final DateTime? cancelledAt;
  final double monthlyPrice;
  final String currency;
  final int billingDay;
  final bool isTrial;

  PremiumSubscription({
    required this.uid,
    required this.planId,
    required this.planName,
    required this.status,
    required this.flutterwaveSubId,
    this.flutterwaveTxRef,
    required this.startDate,
    this.expiryDate,
    this.cancelledAt,
    required this.monthlyPrice,
    required this.currency,
    required this.billingDay,
    this.isTrial = false,
  });

  // ==========================================================================
  // COMPUTED PROPERTIES
  // ==========================================================================

  /// Subscription is active if status is 'active' or 'trial' AND not expired
  bool get isActive {
    if (status != 'active' && status != 'trial') return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }

  /// Days remaining until expiry (-1 if no expiry set)
  int get daysRemaining {
    if (expiryDate == null) return -1;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Hours remaining (useful for trial countdowns)
  int get hoursRemaining {
    if (expiryDate == null) return -1;
    final diff = expiryDate!.difference(DateTime.now()).inHours;
    return diff > 0 ? diff : 0;
  }

  /// Is the subscription expiring soon (within 3 days)?
  bool get isExpiringSoon => daysRemaining >= 0 && daysRemaining <= 3;

  /// Formatted price with currency symbol
  String get formattedPrice {
    final symbol = currency == 'NGN' ? '₦' : currency == 'USD' ? '\$' : currency;
    return '$symbol${monthlyPrice.toStringAsFixed(0)}';
  }

  // ==========================================================================
  // SERIALIZATION
  // ==========================================================================

  factory PremiumSubscription.fromMap(Map<String, dynamic> map) {
    return PremiumSubscription(
      uid: map['uid'] ?? '',
      planId: map['planId'] ?? '',
      planName: map['planName'] ?? 'GoalVantage Premium',
      status: map['status'] ?? 'expired',
      flutterwaveSubId: map['flutterwaveSubId'] ?? '',
      flutterwaveTxRef: map['flutterwaveTxRef'],
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      monthlyPrice: (map['monthlyPrice'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] ?? 'NGN',
      billingDay: (map['billingDay'] as num?)?.toInt() ?? 1,
      isTrial: map['isTrial'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'planId': planId,
    'planName': planName,
    'status': status,
    'flutterwaveSubId': flutterwaveSubId,
    'flutterwaveTxRef': flutterwaveTxRef,
    'startDate': Timestamp.fromDate(startDate),
    'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
    'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
    'monthlyPrice': monthlyPrice,
    'currency': currency,
    'billingDay': billingDay,
    'isTrial': isTrial,
  };

  /// Create a copy with updated fields
  PremiumSubscription copyWith({
    String? status,
    DateTime? expiryDate,
    DateTime? cancelledAt,
    bool? isTrial,
  }) {
    return PremiumSubscription(
      uid: uid,
      planId: planId,
      planName: planName,
      status: status ?? this.status,
      flutterwaveSubId: flutterwaveSubId,
      flutterwaveTxRef: flutterwaveTxRef,
      startDate: startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      monthlyPrice: monthlyPrice,
      currency: currency,
      billingDay: billingDay,
      isTrial: isTrial ?? this.isTrial,
    );
  }
}