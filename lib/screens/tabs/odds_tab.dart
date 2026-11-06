// lib/features/pitchiq/tabs/odds_tab.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../models/prediction.dart';
import '../../theme/colors.dart' hide Prediction;
import '../../services/revenue_cat_service.dart';
import '../../widgets/vip_paywall_sheet.dart';
import '../login_screen.dart';

class OddsTab extends StatefulWidget {
  const OddsTab({super.key});

  @override
  State<OddsTab> createState() => _OddsTabState();
}

class _OddsTabState extends State<OddsTab> {
  List<Prediction> _predictions = [];
  bool _isLoading = true;
  String? _loadError;
  String _activeLeague = 'all';
  String _viewMode = 'all'; // 'all', 'free', 'premium'
  DateTime? _lastUpdated;

  final List<Map<String, String>> _leagues = [
    {'key': 'all', 'label': 'ALL'},
    {'key': 'epl', 'label': 'EPL'},
    {'key': 'laliga', 'label': 'LA LIGA'},
    {'key': 'seriea', 'label': 'SERIE A'},
    {'key': 'bundesliga', 'label': 'BUNDES'},
    {'key': 'ligue1', 'label': 'LIGUE 1'},
    {'key': 'ucl', 'label': 'UCL'},
  ];

  @override
  void initState() {
    super.initState();
    _listenToPredictions();
  }

  void _listenToPredictions() {
    FirebaseFirestore.instance
        .collection('predictions')
        .orderBy('matchTime')
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final predictions = snapshot.docs
          .map((doc) => Prediction.fromMap(doc.data(), doc.id))
          .toList();
      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isLoading = false;
          _loadError = null;
          _lastUpdated = DateTime.now();
        });
      }
    }, onError: (e) {
      debugPrint('Error loading predictions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    });
  }

  List<Prediction> get _filteredPredictions {
    var list = _predictions;
    final now = DateTime.now();

    // 1. Filter out expired matches (only show active/upcoming odds)
    list = list.where((p) {
      final matchDate = p.matchTime is Timestamp
          ? (p.matchTime as Timestamp).toDate()
          : (p.matchTime is DateTime ? p.matchTime as DateTime : null);
      return matchDate != null && matchDate.isAfter(now);
    }).toList();

    // 2. Filter by league
    if (_activeLeague != 'all') {
      list = list.where((p) => p.leagueKey == _activeLeague).toList();
    }

    // 3. Filter by view mode (free/premium)
    if (_viewMode == 'free') {
      list = list.where((p) => !p.isPremium).toList();
    } else if (_viewMode == 'premium') {
      list = list.where((p) => p.isPremium).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // FIX: Explicitly type the stream as DocumentSnapshot? to allow null values safely
    final Stream<DocumentSnapshot?> subscriptionStream = user != null
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('premium')
        .snapshots()
        : Stream<DocumentSnapshot?>.value(null);

    return StreamBuilder<DocumentSnapshot?>(
      stream: subscriptionStream,
      builder: (context, snapshot) {
        bool isPremium = false;
        if (user != null && snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final endDate = data?['endDate'] as Timestamp?;
          isPremium = data?['status'] == 'active' &&
              endDate != null &&
              endDate.toDate().isAfter(DateTime.now());
        }

        // On iOS, also check verified RevenueCat entitlement
        if (Platform.isIOS && RevenueCatService.instance.isVip) {
          isPremium = true;
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isPremium)),
            SliverToBoxAdapter(child: _buildViewModeToggle()),
            if (_isLoading)
              SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_loadError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildLoadError(),
              )
            else if (_filteredPredictions.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildPredictionCard(
                      _filteredPredictions[index],
                      isPremium,
                    ),
                    childCount: _filteredPredictions.length,
                  ),
                ),
              ),
            if (!_isLoading && _filteredPredictions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: Text(
                      'Last updated: ${_formatLastUpdated(_lastUpdated)}',
                      style: TextStyle(
                        color: GoalVantageColors.foregroundSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatLastUpdated(DateTime? time) {
    if (time == null) return 'just now';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showUpgradeSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    // On iOS: Use Apple StoreKit compliant Paywall sheet
    if (Platform.isIOS) {
      VipPaywallSheet.show(context);
      return;
    }

    // On Android: Keep existing Google Play sheet untouched
    showModalBottomSheet(
      context: context,
      backgroundColor: GoalVantageColors.backgroundSecondary,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PremiumUpgradeSheet(),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GoalVantageColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: GoalVantageColors.gold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(LucideIcons.lock, color: GoalVantageColors.gold, size: 20),
            SizedBox(width: 8),
            Text('Login Required'),
          ],
        ),
        content: Text(
          'You must be logged in to subscribe to GoalVantage Premium and unlock exclusive predictions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigator.pop(context);
              // TODO: Replace with your actual login screen navigation
              // Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
              // _showSnack('Please navigate to the Login screen to continue.');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GoalVantageColors.gold,
              foregroundColor: GoalVantageColors.background,
            ),
            child: Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------- UI COMPONENTS ----------------------

  Widget _buildHeader(bool isPremium) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                  "assets/logo.png",
                  width: 150,
                  errorBuilder: (_, __, ___) => Text(
                      'GoalVantage',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                  )
              ),
              SizedBox(height: 8),
              Text(
                'AI PREDICTIONS',
                style: TextStyle(
                  color: GoalVantageColors.foregroundSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Today\'s Top Picks',
                style: TextStyle(
                  color: GoalVantageColors.foreground,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
          if (!isPremium)
            GestureDetector(
              onTap: _showUpgradeSheet,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: GoalVantageColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GoalVantageColors.gold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.crown, size: 14, color: GoalVantageColors.gold),
                    SizedBox(width: 6),
                    Text(
                      'Upgrade',
                      style: TextStyle(
                        color: GoalVantageColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildToggleButton('all', 'ALL'),
          _buildToggleButton('free', 'FREE'),
          _buildToggleButton('premium', 'PREMIUM'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String value, String label) {
    final isActive = _viewMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = value),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? GoalVantageColors.foreground : GoalVantageColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? GoalVantageColors.foreground : GoalVantageColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? GoalVantageColors.background : GoalVantageColors.foregroundSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.calendarOff, size: 48, color: GoalVantageColors.foregroundSecondary),
          SizedBox(height: 16),
          Text(
            'No active matches found',
            style: TextStyle(color: GoalVantageColors.foreground, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for new AI predictions.',
            style: TextStyle(color: GoalVantageColors.foregroundSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Could not load odds.\n$_loadError',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: GoalVantageColors.negative,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionCard(Prediction prediction, bool isPremium) {
    final isLocked = prediction.isPremium && !isPremium;

    final matchDate = prediction.matchTime is Timestamp
        ? (prediction.matchTime as Timestamp).toDate()
        : prediction.matchTime ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(matchDate);
    final dateStr = DateFormat('MMM d').format(matchDate);

    final homeTeam = prediction.home;
    final awayTeam = prediction.away;
    final leagueName = prediction.leagueName.isNotEmpty
      ? prediction.leagueName
      : prediction.leagueKey;

    final oddsText = prediction.odds != null
        ? prediction.odds!.toStringAsFixed(2)
        : '—';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked ? GoalVantageColors.gold.withOpacity(0.3) : GoalVantageColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GoalVantageColors.foreground.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    leagueName.toUpperCase(),
                    style: TextStyle(
                      color: GoalVantageColors.foregroundSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 12, color: GoalVantageColors.foregroundSecondary),
                    SizedBox(width: 4),
                    Text(
                      '$dateStr · $timeStr',
                      style: TextStyle(
                        color: GoalVantageColors.foregroundSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildTeamWithForm(homeTeam.toString(), prediction.homeForm, prediction.homePosition),
                SizedBox(height: 10),
                _buildTeamWithForm(awayTeam.toString(), prediction.awayForm, prediction.awayPosition),
              ],
            ),
          ),

          if (prediction.h2hHomeWins != null || prediction.h2hAwayWins != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildH2hChip('${prediction.h2hHomeWins ?? 0}W', GoalVantageColors.positive),
                  SizedBox(width: 8),
                  _buildH2hChip('${prediction.h2hDraws ?? 0}D', GoalVantageColors.warning),
                  SizedBox(width: 8),
                  _buildH2hChip('${prediction.h2hAwayWins ?? 0}L', GoalVantageColors.negative),
                ],
              ),
            ),

          // Prediction content (Teaser for locked, Full details for unlocked)
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLocked
                  ? GoalVantageColors.gold.withOpacity(0.05)
                  : GoalVantageColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GoalVantageColors.gold.withOpacity(0.3),
              ),
            ),
            child: isLocked
                ? GestureDetector(
              onTap: _showUpgradeSheet,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.lock, size: 24, color: GoalVantageColors.gold),
                  SizedBox(height: 8),
                  Text(
                    'PREMIUM PREDICTION LOCKED',
                    style: TextStyle(
                      color: GoalVantageColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to unlock this ${prediction.odds != null ? "${prediction.odds!.toStringAsFixed(2)} odds" : "high-confidence"} pick',
                    style: TextStyle(
                      color: GoalVantageColors.foregroundSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (prediction.predictionType ?? 'Prediction').toString().toUpperCase(),
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            (prediction.prediction ?? 'AI Pick').toString(),
                            style: TextStyle(
                              color: GoalVantageColors.foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GoalVantageColors.positive.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${prediction.confidence ?? 85}%',
                            style: TextStyle(
                              color: GoalVantageColors.positive,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Odds $oddsText',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (prediction.confidence ?? 85) / 100,
                    minHeight: 4,
                    backgroundColor: GoalVantageColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      GoalVantageColors.positive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamWithForm(String teamName, List<dynamic>? form, int? position) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: GoalVantageColors.foreground.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.shield,
            size: 18,
            color: GoalVantageColors.foregroundSecondary,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            teamName,
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (position != null)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              '${position}${_ordinalSuffix(position)}',
              style: TextStyle(
                color: GoalVantageColors.foregroundSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (form != null && form.isNotEmpty)
          ...form.map((result) {
            final color = result == 'W'
                ? GoalVantageColors.positive
                : result == 'D'
                ? GoalVantageColors.warning
                : GoalVantageColors.negative;
            return Container(
              margin: EdgeInsets.only(left: 4),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                result.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildH2hChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}




// ----------------------------------------------------------------------------
// PREMIUM UPGRADE SHEET
// ----------------------------------------------------------------------------

class _PremiumUpgradeSheet extends StatefulWidget {
  const _PremiumUpgradeSheet();

  @override
  State<_PremiumUpgradeSheet> createState() => _PremiumUpgradeSheetState();
}

class _PremiumUpgradeSheetState extends State<_PremiumUpgradeSheet> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isProcessing = false;
  bool _isInitialized = false;

  // TODO: Replace with your EXACT product ID configured in App Store Connect & Google Play Console
  static const String _productId = 'premium_monthly';

  @override
  void initState() {
    super.initState();
    _initializeInAppPurchase();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initializeInAppPurchase() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      if (mounted) {
        _showSnack('In-app purchases are not available on this device (e.g., emulator).');
      }
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_productId});

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('⚠️ IN-APP PURCHASE ERROR: Product ID "$_productId" not found.');
      debugPrint('Check Play Console: 1) App uploaded to testing track, 2) Tester email added to License Testing, 3) Product is Active.');
      if (mounted) {
        _showSnack('Product ID not found. Check Play Console setup (see debug logs).');
      }
      return;
    }

    if (response.error != null) {
      debugPrint('⚠️ IN-APP PURCHASE ERROR: ${response.error}');
      if (mounted) {
        _showSnack('Failed to load products: ${response.error?.message}');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _isInitialized = true;
      });
    }

    _subscription = _inAppPurchase.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('⚠️ IN-APP PURCHASE STREAM ERROR: $error');
        if (mounted) _showSnack('Purchase error: $error');
      },
    );
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isProcessing = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (mounted) {
            _showSnack('Purchase failed: ${purchaseDetails.error?.message ?? "Unknown error"}');
            setState(() => _isProcessing = false);
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          await _activateSubscription(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _activateSubscription(PurchaseDetails purchaseDetails) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be logged in to activate a subscription.');
      return;
    }

    final db = FirebaseFirestore.instance;
    final subscriptionRef = db.collection('users').doc(user.uid).collection('subscriptions').doc('premium');
    final paymentRef = db.collection('users').doc(user.uid).collection('payments').doc(purchaseDetails.purchaseID ?? 'unknown_tx');

    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 30));
    final serverNow = FieldValue.serverTimestamp();

    final provider = defaultTargetPlatform == TargetPlatform.iOS ? 'apple_app_store' : 'google_play_store';

    final subscriptionPayload = {
      'category': 'premium',
      'status': 'active',
      'startDate': Timestamp.fromDate(now),
      'endDate': Timestamp.fromDate(endDate),
      'periodDays': 30,
      'periodLabel': '1 month',
      'provider': provider,
      'transactionId': purchaseDetails.purchaseID,
      'updatedAt': serverNow,
    };

    final paymentPayload = {
      'category': 'premium',
      'provider': provider,
      'status': 'successful',
      'transactionId': purchaseDetails.purchaseID,
      'createdAt': serverNow,
      'updatedAt': serverNow,
    };

    try {
      final batch = db.batch();
      batch.set(subscriptionRef, subscriptionPayload, SetOptions(merge: true));
      batch.set(paymentRef, paymentPayload);
      await batch.commit();

      if (mounted) {
        await _showPaymentDialog(
          title: 'Subscription activated',
          message: 'Your GoalVantage Premium access is active for 1 month.',
          icon: Icons.check_circle_outline_rounded,
          color: GoalVantageColors.positive,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error activating subscription in Firestore: $e');
      if (mounted) {
        _showSnack('Failed to activate subscription: $e');
      }
    }
  }

  // NEW: Centralized press handler that shows a toast instead of disabling the button
  void _handleSubscribePress() {
    if (_isProcessing) return;

    if (!_isAvailable) {
      _showSnack('In-app purchases are not available. Please use a physical device with Google Play.');
      return;
    }

    if (!_isInitialized || _products.isEmpty) {
      _showSnack('Products not loaded. Check debug console for Play Console setup errors.');
      return;
    }

    // If everything is ready, proceed with purchase
    _handleSubscribe();
  }

  void _handleSubscribe() {
    final ProductDetails product = _products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: GoalVantageColors.negative,
      ),
    );
  }

  Future<void> _showPaymentDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _products.isNotEmpty ? _products.first : null;
    final displayPrice = product?.price ?? '25';
    final displayCurrency = product?.currencyCode ?? 'USD';
    final platformName = defaultTargetPlatform == TargetPlatform.iOS ? 'APPLE' : 'GOOGLE';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(top: BorderSide(color: GoalVantageColors.gold, width: 2)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GoalVantageColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(LucideIcons.crown, size: 20, color: GoalVantageColors.gold),
              const SizedBox(width: 8),
              Text(
                'GOALVANTAGE PREMIUM',
                style: TextStyle(
                  color: GoalVantageColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock every prediction.',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GoalVantageColors.card,
              border: Border.all(color: GoalVantageColors.gold, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTHLY PLAN',
                        style: TextStyle(
                          color: GoalVantageColors.foregroundSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$displayCurrency $displayPrice',
                            style: TextStyle(
                              color: GoalVantageColors.foreground,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/month',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...[
            'All premium AI predictions (80%+ confidence)',
            'Detailed match analysis & xG stats',
            'Injury & suspension alerts',
            'Exclusive tipster picks',
            'Cancel anytime via App Store / Play Store',
          ].map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.check, size: 14, color: GoalVantageColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b,
                    style: TextStyle(
                      color: GoalVantageColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              // CHANGED: Always clickable unless processing, triggers toast if not ready
              onPressed: _isProcessing ? null : _handleSubscribePress,
              style: ElevatedButton.styleFrom(
                backgroundColor: GoalVantageColors.gold,
                foregroundColor: GoalVantageColors.background,
                elevation: 0,
                // Removed disabledBackgroundColor so it stays gold even if not initialized
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    defaultTargetPlatform == TargetPlatform.iOS ? LucideIcons.apple : LucideIcons.smartphone,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SUBSCRIBE WITH $platformName PAY',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Secured by ${platformName == 'APPLE' ? 'App Store' : 'Google Play'} · Cancel anytime · No hidden fees',
              style: TextStyle(
                color: GoalVantageColors.foregroundSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
        ],
      ),
    );
  }
}




// ----------------------------------------------------------------------------
// PREMIUM UPGRADE SHEET
// ----------------------------------------------------------------------------

class _PremiumUpgradeSheet2 extends StatefulWidget {
  _PremiumUpgradeSheet2();

  @override
  State<_PremiumUpgradeSheet2> createState() => _PremiumUpgradeSheetState2();
}

class _PremiumUpgradeSheetState2 extends State<_PremiumUpgradeSheet2> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isProcessing = false;
  bool _isInitialized = false;

  static String _productId = 'premium_monthly';

  @override
  void initState() {
    super.initState();
    _initializeInAppPurchase();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initializeInAppPurchase() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        _showSnack('In-app purchases are not available on this device.');
      }
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_productId});

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('⚠️ IN-APP PURCHASE ERROR: Product ID "$_productId" not found.');
      debugPrint('Check Play Console: 1) App uploaded to testing track, 2) Tester email added to License Testing, 3) Product is Active.');
      if (mounted) {
        _showSnack('Product ID not found. Check Play Console setup (see debug logs).');
      }
      return;
    }

    if (response.error != null) {
      debugPrint('⚠️ IN-APP PURCHASE ERROR: ${response.error}');
      if (mounted) {
        _showSnack('Failed to load products: ${response.error?.message}');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _isInitialized = true;
      });
    }

    _subscription = _inAppPurchase.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('⚠️ IN-APP PURCHASE STREAM ERROR: $error');
        if (mounted) _showSnack('Purchase error: $error');
      },
    );
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isProcessing = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (mounted) {
            _showSnack('Purchase failed: ${purchaseDetails.error?.message ?? "Unknown error"}');
            setState(() => _isProcessing = false);
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          await _activateSubscription(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _activateSubscription(PurchaseDetails purchaseDetails) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be logged in to activate a subscription.');
      return;
    }

    final db = FirebaseFirestore.instance;
    final subscriptionRef = db.collection('users').doc(user.uid).collection('subscriptions').doc('premium');
    final paymentRef = db.collection('users').doc(user.uid).collection('payments').doc(purchaseDetails.purchaseID ?? 'unknown_tx');

    final now = DateTime.now();
    final endDate = now.add(Duration(days: 30));
    final serverNow = FieldValue.serverTimestamp();

    final provider = defaultTargetPlatform == TargetPlatform.iOS ? 'apple_app_store' : 'google_play_store';

    final subscriptionPayload = {
      'category': 'premium',
      'status': 'active',
      'startDate': Timestamp.fromDate(now),
      'endDate': Timestamp.fromDate(endDate),
      'periodDays': 30,
      'periodLabel': '1 month',
      'provider': provider,
      'transactionId': purchaseDetails.purchaseID,
      'updatedAt': serverNow,
    };

    final paymentPayload = {
      'category': 'premium',
      'provider': provider,
      'status': 'successful',
      'transactionId': purchaseDetails.purchaseID,
      'createdAt': serverNow,
      'updatedAt': serverNow,
    };

    try {
      final batch = db.batch();
      batch.set(subscriptionRef, subscriptionPayload, SetOptions(merge: true));
      batch.set(paymentRef, paymentPayload);
      await batch.commit();

      if (mounted) {
        await _showPaymentDialog(
          title: 'Subscription activated',
          message: 'Your GoalVantage Premium access is active for 1 month.',
          icon: Icons.check_circle_outline_rounded,
          color: GoalVantageColors.positive,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error activating subscription in Firestore: $e');
      if (mounted) {
        _showSnack('Failed to activate subscription: $e');
      }
    }
  }

  void _handleSubscribe() {
    if (!_isInitialized || _products.isEmpty) {
      _showSnack('Products not loaded yet. Please try again.');
      return;
    }

    final ProductDetails product = _products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showPaymentDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _products.isNotEmpty ? _products.first : null;
    final displayPrice = product?.price ?? '25';
    final displayCurrency = product?.currencyCode ?? 'USD';
    final platformName = defaultTargetPlatform == TargetPlatform.iOS ? 'APPLE' : 'GOOGLE';

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(top: BorderSide(color: GoalVantageColors.gold, width: 2)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GoalVantageColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Icon(LucideIcons.crown, size: 20, color: GoalVantageColors.gold),
              SizedBox(width: 8),
              Text(
                'GOALVANTAGE PREMIUM',
                style: TextStyle(
                  color: GoalVantageColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Unlock every prediction.',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GoalVantageColors.card,
              border: Border.all(color: GoalVantageColors.gold, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTHLY PLAN',
                        style: TextStyle(
                          color: GoalVantageColors.foregroundSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$displayCurrency $displayPrice',
                            style: TextStyle(
                              color: GoalVantageColors.foreground,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '/month',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          ...[
            'All premium AI predictions (80%+ confidence)',
            'Detailed match analysis & xG stats',
            'Injury & suspension alerts',
            'Exclusive tipster picks',
            'Cancel anytime via App Store / Play Store',
          ].map((b) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.check, size: 14, color: GoalVantageColors.gold),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b,
                    style: TextStyle(
                      color: GoalVantageColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing || !_isInitialized ? null : _handleSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: GoalVantageColors.gold,
                foregroundColor: GoalVantageColors.background,
                elevation: 0,
                disabledBackgroundColor: GoalVantageColors.gold.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isProcessing
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    defaultTargetPlatform == TargetPlatform.iOS ? LucideIcons.apple : LucideIcons.smartphone,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SUBSCRIBE WITH $platformName PAY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Secured by ${platformName == 'APPLE' ? 'App Store' : 'Google Play'} · Cancel anytime · No hidden fees',
              style: TextStyle(
                color: GoalVantageColors.foregroundSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
        ],
      ),
    );
  }
}





