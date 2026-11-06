import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class LivePortfolioService extends ChangeNotifier {
  LivePortfolioService._();
  static final LivePortfolioService instance = LivePortfolioService._();

  final GetStorage _cache = GetStorage('market_cache');
  StreamSubscription? _userSub;
  StreamSubscription? _copiesSub;
  StreamSubscription? _positionsSub;
  Timer? _timer;
  String? _uid;
  bool _refreshing = false;
  double balance = 0;
  double copyPnl = 0;
  double spotPnl = 0;
  List<Map<String, dynamic>> activeCopies = [];
  List<Map<String, dynamic>> openPositions = [];
  Map<String, double> _prices = {};

  double get totalPnl => copyPnl + spotPnl;
  double get equity => balance + totalPnl;

  String _key(Map<String, dynamic> item) =>
      '${item['chain'] ?? ''}:${item['pairAddress'] ?? ''}'.toLowerCase();

  void start() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _uid == user.uid) return;
    _uid = user.uid;
    final cached = _cache.read<Map>('portfolio_pair_prices');
    if (cached != null) {
      _prices = cached.map(
            (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
    }
    _userSub?.cancel();
    _copiesSub?.cancel();
    _positionsSub?.cancel();
    _timer?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      balance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0;
      _calculate();
    });
    _copiesSub = FirebaseFirestore.instance
        .collection('copy_active_copies')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      activeCopies = snapshot.docs
          .map((document) => {'id': document.id, ...document.data()})
          .where(
            (item) => item['status'] == null || item['status'] == 'ACTIVE',
      )
          .toList();
      _calculate();
      unawaited(refresh());
    });
    _positionsSub = FirebaseFirestore.instance
        .collection('trade_user_positions')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      openPositions = snapshot.docs
          .map((document) => {'id': document.id, ...document.data()})
          .where((item) => item['status'] == 'OPEN')
          .toList();
      _calculate();
      unawaited(refresh());
    });
    _timer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final instruments = [...activeCopies, ...openPositions].where(
            (item) =>
        (item['chain']?.toString().isNotEmpty ?? false) &&
            (item['pairAddress']?.toString().isNotEmpty ?? false),
      );
      final unique = <String, Map<String, dynamic>>{
        for (final item in instruments) _key(item): item,
      };
      final results = await Future.wait(
        unique.entries.map((entry) async {
          try {
            final item = entry.value;
            final uri = Uri.parse(
              'https://api.dexscreener.com/latest/dex/pairs/${Uri.encodeComponent(item['chain'].toString().toLowerCase())}/${Uri.encodeComponent(item['pairAddress'].toString())}',
            );
            final response = await http
                .get(uri)
                .timeout(const Duration(seconds: 12));
            if (response.statusCode != 200) return null;
            final payload = jsonDecode(response.body) as Map<String, dynamic>;
            final pairs =
                (payload['pairs'] as List?)?.cast<Map<String, dynamic>>() ??
                    const [];
            final pair = pairs.cast<Map<String, dynamic>?>().firstWhere(
                  (candidate) =>
              candidate?['pairAddress']?.toString().toLowerCase() ==
                  item['pairAddress'].toString().toLowerCase(),
              orElse: () => pairs.isEmpty ? null : pairs.first,
            );
            final price = double.tryParse(pair?['priceUsd']?.toString() ?? '');
            return price != null && price > 0
                ? MapEntry(entry.key, price)
                : null;
          } catch (_) {
            return null;
          }
        }),
      );
      for (final result in results) {
        if (result != null) _prices[result.key] = result.value;
      }
      await _cache.write('portfolio_pair_prices', _prices);
      _calculate();
    } finally {
      _refreshing = false;
    }
  }

  double? livePrice(Map<String, dynamic> item) => _prices[_key(item)];

  void _calculate() {
    copyPnl = activeCopies.fold(0, (sum, item) {
      final current = livePrice(item);
      final entry = (item['entryPrice'] as num?)?.toDouble() ?? 0;
      final amount = (item['copiedAmount'] as num?)?.toDouble() ?? 0;
      return sum +
          (current != null && entry > 0
              ? amount * ((current - entry) / entry)
              : 0);
    });
    spotPnl = openPositions.fold(0, (sum, item) {
      final current = livePrice(item);
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
      final invested = (item['totalInvested'] as num?)?.toDouble() ?? 0;
      return sum + (current != null ? quantity * current - invested : 0);
    });
    notifyListeners();
  }
}