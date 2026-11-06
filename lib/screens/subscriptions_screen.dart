import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

// ============================================================================
// MODELS
// ============================================================================

class Subscription {
  final String id;
  final String type;
  final String scope;
  final String scopeId;
  final String scopeLabel;
  final List<String> delivery;
  final String frequency;
  final Map<String, dynamic> filters;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastTriggered;

  Subscription.fromMap(Map<String, dynamic> map, String docId)
      : id = docId,
        type = map['type'] ?? 'odds_movement',
        scope = map['scope'] ?? 'all',
        scopeId = map['scopeId'] ?? 'all',
        scopeLabel = map['scopeLabel'] ?? 'All',
        delivery = List<String>.from(map['delivery'] ?? []),
        frequency = map['frequency'] ?? 'realtime',
        filters = Map<String, dynamic>.from(map['filters'] ?? {}),
        isActive = map['isActive'] ?? true,
        createdAt = (map['createdAt'] as Timestamp?)?.toDate(),
        lastTriggered = (map['lastTriggered'] as Timestamp?)?.toDate();

  Map<String, dynamic> toMap() => {
    'type': type,
    'scope': scope,
    'scopeId': scopeId,
    'scopeLabel': scopeLabel,
    'delivery': delivery,
    'frequency': frequency,
    'filters': filters,
    'isActive': isActive,
  };
}

class SubscriptionEvent {
  final String id;
  final String subscriptionId;
  final String type;
  final String scopeLabel;
  final Map<String, dynamic> payload;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  SubscriptionEvent.fromMap(Map<String, dynamic> map, String docId)
      : id = docId,
        subscriptionId = map['subscriptionId'] ?? '',
        type = map['type'] ?? '',
        scopeLabel = map['scopeLabel'] ?? '',
        payload = Map<String, dynamic>.from(map['payload'] ?? {}),
        deliveredAt = (map['deliveredAt'] as Timestamp?)?.toDate(),
        readAt = (map['readAt'] as Timestamp?)?.toDate();

  bool get isRead => readAt != null;
}

class SubscriptionPreset {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String type;
  final int subscribers;

  SubscriptionPreset.fromMap(Map<String, dynamic> map, String docId)
      : id = docId,
        name = map['name'] ?? '',
        description = map['description'] ?? '',
        icon = map['icon'] ?? 'bell',
        type = map['type'] ?? '',
        subscribers = (map['subscribers'] as num?)?.toInt() ?? 0;
}

// ============================================================================
// PITCHIQ COLORS
// ============================================================================

class GoalVantageColors {
  static const Color background = Color(0xFF0a0e1a);
  static const Color backgroundSecondary = Color(0xFF111827);
  static const Color card = Color(0xFF1a2035);
  static const Color foreground = Color(0xFFe8ecf4);
  static const Color foregroundSecondary = Color(0xFF8b95a8);
  static const Color primary = Color(0xFF2563eb);
  static const Color primaryForeground = Color(0xFFffffff);
  static const Color accent = Color(0xFF06b6d4);
  static const Color positive = Color(0xFF22c55e);
  static const Color negative = Color(0xFFef4444);
  static const Color warning = Color(0xFFf59e0b);
  static const Color border = Color(0x1Ae8ecf4);
  static const Color gold = Color(0xFFd4af37);
}

// ============================================================================
// SUBSCRIPTIONS SCREEN
// ============================================================================

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Subscription> _subscriptions = [];
  List<SubscriptionEvent> _events = [];
  List<SubscriptionPreset> _presets = [];
  bool _isLoading = true;
  String? _uid;

  StreamSubscription? _subsSub;
  StreamSubscription? _eventsSub;
  StreamSubscription? _presetsSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _listenToData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subsSub?.cancel();
    _eventsSub?.cancel();
    _presetsSub?.cancel();
    super.dispose();
  }

  void _listenToData() {
    if (_uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    _subsSub = FirebaseFirestore.instance
        .collection('user_subscriptions')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final subs = snapshot.docs
          .map((doc) => Subscription.fromMap(doc.data(), doc.id))
          .toList();
      if (mounted) setState(() => _subscriptions = subs);
    });

    _eventsSub = FirebaseFirestore.instance
        .collection('subscription_events')
        .where('uid', isEqualTo: _uid)
        .orderBy('deliveredAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final events = snapshot.docs
          .map((doc) => SubscriptionEvent.fromMap(doc.data(), doc.id))
          .toList();
      if (mounted) setState(() {
        _events = events;
        _isLoading = false;
      });
    });

    _presetsSub = FirebaseFirestore.instance
        .collection('subscription_presets')
        .orderBy('subscribers', descending: true)
        .snapshots()
        .listen((snapshot) {
      final presets = snapshot.docs
          .map((doc) => SubscriptionPreset.fromMap(doc.data(), doc.id))
          .toList();
      if (mounted) setState(() => _presets = presets);
    });
  }

  int get _unreadCount => _events.where((e) => !e.isRead).length;
  int get _activeCount => _subscriptions.where((s) => s.isActive).length;

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  Future<void> _toggleSubscription(Subscription sub) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_subscriptions')
          .doc(sub.id)
          .update({'isActive': !sub.isActive});
    } catch (e) {
      _showError('Failed to update subscription');
    }
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_subscriptions')
          .doc(sub.id)
          .delete();
    } catch (e) {
      _showError('Failed to delete subscription');
    }
  }

  Future<void> _markEventRead(SubscriptionEvent event) async {
    if (event.isRead) return;
    try {
      await FirebaseFirestore.instance
          .collection('subscription_events')
          .doc(event.id)
          .update({'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Error marking event read: $e');
    }
  }

  Future<void> _markAllRead() async {
    final unread = _events.where((e) => !e.isRead).toList();
    final batch = FirebaseFirestore.instance.batch();
    for (final event in unread) {
      batch.update(
        FirebaseFirestore.instance.collection('subscription_events').doc(event.id),
        {'readAt': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
  }

  Future<void> _subscribeToPreset(SubscriptionPreset preset) async {
    if (_uid == null) return;

    final newSub = {
      'uid': _uid,
      'type': preset.type,
      'scope': 'all',
      'scopeId': 'all',
      'scopeLabel': preset.name,
      'delivery': ['push', 'in_app'],
      'frequency': 'realtime',
      'filters': {},
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'synthetic': true,
    };

    try {
      await FirebaseFirestore.instance.collection('user_subscriptions').add(newSub);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoalVantageColors.positive,
          content: Text('Subscribed to ${preset.name}'),
        ),
      );
    } catch (e) {
      _showError('Failed to subscribe');
    }
  }

  void _showCreateSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GoalVantageColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) => const _CreateSubscriptionSheet(),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GoalVantageColors.negative,
        content: Text(message),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildStatsStrip()),
            SliverToBoxAdapter(child: _buildTabs()),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAlertsList(),
                  _buildSubscriptionsList(),
                  _buildPresetsList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSubscriptionSheet,
        backgroundColor: GoalVantageColors.primary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
        shape: const RoundedRectangleBorder(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bell, size: 14, color: GoalVantageColors.accent),
              const SizedBox(width: 8),
              Text(
                'SUBSCRIPTIONS',
                style: TextStyle(
                  color: GoalVantageColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'STAY AHEAD\nOF THE GAME.',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Subscribe to odds movements, match results, and AI predictions. Get notified when it matters.',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem('$_activeCount', 'ACTIVE', GoalVantageColors.positive),
          ),
          Container(width: 1, height: 32, color: GoalVantageColors.border),
          Expanded(
            child: _statItem('$_unreadCount', 'UNREAD', GoalVantageColors.warning),
          ),
          Container(width: 1, height: 32, color: GoalVantageColors.border),
          Expanded(
            child: _statItem('${_subscriptions.length}', 'TOTAL', GoalVantageColors.foreground),
          ),
          Container(width: 1, height: 32, color: GoalVantageColors.border),
          Expanded(
            child: _statItem('${_presets.length}', 'PRESETS', GoalVantageColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: GoalVantageColors.foregroundSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: GoalVantageColors.primary,
        indicatorWeight: 3,
        labelColor: GoalVantageColors.foreground,
        unselectedLabelColor: GoalVantageColors.foregroundSecondary,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ALERTS'),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: GoalVantageColors.negative),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'MY SUBSCRIPTIONS'),
          const Tab(text: 'DISCOVER'),
        ],
      ),
    );
  }

  // ==========================================================================
  // ALERTS LIST
  // ==========================================================================

  Widget _buildAlertsList() {
    if (_events.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.bellOff,
        title: 'NO ALERTS YET',
        subtitle: 'Subscribe to leagues, teams, or tipsters to start receiving alerts.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mark all read button
        if (_unreadCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: GoalVantageColors.card,
                  border: Border.all(color: GoalVantageColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.checkCheck, size: 12, color: GoalVantageColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'MARK ALL AS READ',
                      style: TextStyle(
                        color: GoalVantageColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ..._events.map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildEventCard(SubscriptionEvent event) {
    final icon = _getEventIcon(event.type);
    final color = _getEventColor(event.type);

    return InkWell(
      onTap: () => _markEventRead(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GoalVantageColors.card,
          border: Border.all(
            color: event.isRead ? GoalVantageColors.border : color.withOpacity(0.5),
            width: event.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getEventTitle(event),
                          style: TextStyle(
                            color: GoalVantageColors.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!event.isRead)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: GoalVantageColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getEventDescription(event),
                    style: TextStyle(
                      color: GoalVantageColors.foregroundSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        event.scopeLabel.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(event.deliveredAt),
                        style: TextStyle(
                          color: GoalVantageColors.foregroundSecondary,
                          fontSize: 9,
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
    );
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'odds_movement': return LucideIcons.trendingDown;
      case 'match_result': return LucideIcons.trophy;
      case 'prediction_alert': return LucideIcons.target;
      case 'tipster_update': return LucideIcons.userCheck;
      case 'team_news': return LucideIcons.newspaper;
      default: return LucideIcons.bell;
    }
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'odds_movement': return GoalVantageColors.warning;
      case 'match_result': return GoalVantageColors.positive;
      case 'prediction_alert': return GoalVantageColors.accent;
      case 'tipster_update': return GoalVantageColors.gold;
      case 'team_news': return GoalVantageColors.primary;
      default: return GoalVantageColors.foregroundSecondary;
    }
  }

  String _getEventTitle(SubscriptionEvent event) {
    final p = event.payload;
    switch (event.type) {
      case 'odds_movement':
        final oldOdds = (p['oldOdds'] as num?)?.toStringAsFixed(2) ?? '?';
        final newOdds = (p['newOdds'] as num?)?.toStringAsFixed(2) ?? '?';
        return 'Odds Drop: $oldOdds → $newOdds';
      case 'match_result':
        final home = p['home'] ?? '?';
        final away = p['away'] ?? '?';
        final hs = p['homeScore'] ?? 0;
        final as = p['awayScore'] ?? 0;
        return '$home $hs-$as $away';
      case 'prediction_alert':
        return p['prediction'] ?? 'New Prediction';
      case 'tipster_update':
        return '${p['tipsterName'] ?? 'Tipster'} posted ${(p['newPredictions'] as num?)?.toInt() ?? 0} picks';
      case 'team_news':
        return p['headline'] ?? 'Team News';
      default:
        return 'Alert';
    }
  }

  String _getEventDescription(SubscriptionEvent event) {
    final p = event.payload;
    switch (event.type) {
      case 'odds_movement':
        final home = p['home'] ?? '';
        final away = p['away'] ?? '';
        return '$home vs $away · ${(p['league'] ?? '').toString().toUpperCase()}';
      case 'match_result':
        return 'Final score · ${event.scopeLabel}';
      case 'prediction_alert':
        final conf = (p['confidence'] as num?)?.toStringAsFixed(0) ?? '?';
        final odds = (p['odds'] as num?)?.toStringAsFixed(2) ?? '?';
        return 'Confidence: $conf% · Odds: $odds · by ${p['tipster'] ?? 'AI'}';
      case 'tipster_update':
        return 'Accuracy: ${(p['accuracy'] as num?)?.toStringAsFixed(1) ?? '?'}%';
      case 'team_news':
        return '${p['team'] ?? ''} · ${(p['newsType'] ?? '').toString().toUpperCase()}';
      default:
        return '';
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '—';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ==========================================================================
  // SUBSCRIPTIONS LIST
  // ==========================================================================

  Widget _buildSubscriptionsList() {
    if (_subscriptions.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.bellOff,
        title: 'NO SUBSCRIPTIONS',
        subtitle: 'Discover popular presets or create your own custom subscription.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _subscriptions.map((sub) => _buildSubscriptionCard(sub)).toList(),
    );
  }

  Widget _buildSubscriptionCard(Subscription sub) {
    final color = _getEventColor(sub.type);
    final icon = _getEventIcon(sub.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(
          color: sub.isActive ? color.withOpacity(0.3) : GoalVantageColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTypeLabel(sub.type),
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub.scopeLabel,
                        style: TextStyle(
                          color: GoalVantageColors.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _buildFilterSummary(sub),
                        style: TextStyle(
                          color: GoalVantageColors.foregroundSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle
                InkWell(
                  onTap: () => _toggleSubscription(sub),
                  child: Container(
                    width: 44,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: sub.isActive ? GoalVantageColors.positive : GoalVantageColors.border,
                    ),
                    child: AnimatedAlign(
                      alignment: sub.isActive ? Alignment.centerRight : Alignment.centerLeft,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: GoalVantageColors.backgroundSecondary,
              border: Border(top: BorderSide(color: GoalVantageColors.border)),
            ),
            child: Row(
              children: [
                // Delivery icons
                ...sub.delivery.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    _getDeliveryIcon(d),
                    size: 11,
                    color: GoalVantageColors.foregroundSecondary,
                  ),
                )),
                const Spacer(),
                Text(
                  sub.frequency.toUpperCase(),
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _confirmDelete(sub),
                  child: Icon(LucideIcons.trash2, size: 12, color: GoalVantageColors.negative),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeliveryIcon(String delivery) {
    switch (delivery) {
      case 'push': return LucideIcons.bell;
      case 'email': return LucideIcons.mail;
      case 'sms': return LucideIcons.messageSquare;
      case 'in_app': return LucideIcons.inbox;
      default: return LucideIcons.bell;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'odds_movement': return 'ODDS MOVEMENT';
      case 'match_result': return 'MATCH RESULT';
      case 'prediction_alert': return 'PREDICTION';
      case 'tipster_update': return 'TIPSTER';
      case 'team_news': return 'TEAM NEWS';
      default: return type.toUpperCase();
    }
  }

  String _buildFilterSummary(Subscription sub) {
    final parts = <String>[];
    if (sub.filters['minOddsChange'] != null) {
      final pct = ((sub.filters['minOddsChange'] as num) * 100).toStringAsFixed(0);
      parts.add('$pct%+ odds change');
    }
    if (sub.filters['minConfidence'] != null) {
      parts.add('${sub.filters['minConfidence']}%+ confidence');
    }
    if (sub.filters['premiumOnly'] == true) {
      parts.add('Premium only');
    }
    if (sub.filters['verifiedOnly'] == true) {
      parts.add('Verified tipsters');
    }
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }

  void _confirmDelete(Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GoalVantageColors.card,
        shape: const RoundedRectangleBorder(),
        title: Text(
          'DELETE SUBSCRIPTION',
          style: TextStyle(
            color: GoalVantageColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Are you sure you want to stop receiving alerts for ${sub.scopeLabel}?',
          style: TextStyle(color: GoalVantageColors.foregroundSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: GoalVantageColors.foregroundSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSubscription(sub);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GoalVantageColors.negative,
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PRESETS LIST
  // ==========================================================================

  Widget _buildPresetsList() {
    if (_presets.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.sparkles,
        title: 'NO PRESETS',
        subtitle: 'Popular subscription presets will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'POPULAR PRESETS',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ..._presets.map((preset) => _buildPresetCard(preset)),
      ],
    );
  }

  Widget _buildPresetCard(SubscriptionPreset preset) {
    final color = _getEventColor(preset.type);
    final icon = _getEventIcon(preset.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(color: GoalVantageColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    color: GoalVantageColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.description,
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.users, size: 10, color: GoalVantageColors.foregroundSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatNumber(preset.subscribers)} subscribers',
                      style: TextStyle(
                        color: GoalVantageColors.foregroundSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _subscribeToPreset(preset),
              style: ElevatedButton.styleFrom(
                backgroundColor: GoalVantageColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.plus, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'SUBSCRIBE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: GoalVantageColors.foregroundSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: GoalVantageColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: GoalVantageColors.foregroundSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CREATE SUBSCRIPTION SHEET
// ============================================================================

class _CreateSubscriptionSheet extends StatefulWidget {
  const _CreateSubscriptionSheet();

  @override
  State<_CreateSubscriptionSheet> createState() => _CreateSubscriptionSheetState();
}

class _CreateSubscriptionSheetState extends State<_CreateSubscriptionSheet> {
  String _selectedType = 'odds_movement';
  String _selectedScope = 'league';
  String _selectedScopeId = 'epl';
  String _selectedFrequency = 'realtime';
  final Set<String> _selectedDelivery = {'push', 'in_app'};

  double _minOddsChange = 0.10;
  double _minConfidence = 70;
  bool _premiumOnly = false;
  bool _verifiedOnly = false;

  final List<Map<String, String>> _types = [
    {'key': 'odds_movement', 'label': 'Odds Movement', 'icon': 'trendingDown'},
    {'key': 'match_result', 'label': 'Match Result', 'icon': 'trophy'},
    {'key': 'prediction_alert', 'label': 'Prediction', 'icon': 'target'},
    {'key': 'tipster_update', 'label': 'Tipster Update', 'icon': 'userCheck'},
    {'key': 'team_news', 'label': 'Team News', 'icon': 'newspaper'},
  ];

  final List<Map<String, String>> _scopes = [
    {'key': 'all', 'label': 'All Matches'},
    {'key': 'league', 'label': 'League'},
    {'key': 'team', 'label': 'Team'},
  ];

  final List<Map<String, String>> _leagues = [
    {'key': 'epl', 'label': 'Premier League'},
    {'key': 'laliga', 'label': 'La Liga'},
    {'key': 'seriea', 'label': 'Serie A'},
    {'key': 'bundesliga', 'label': 'Bundesliga'},
    {'key': 'ligue1', 'label': 'Ligue 1'},
    {'key': 'ucl', 'label': 'Champions League'},
  ];

  final List<Map<String, String>> _teams = [
    {'key': 'Arsenal', 'label': 'Arsenal'},
    {'key': 'Manchester City', 'label': 'Manchester City'},
    {'key': 'Liverpool', 'label': 'Liverpool'},
    {'key': 'Real Madrid', 'label': 'Real Madrid'},
    {'key': 'Barcelona', 'label': 'Barcelona'},
    {'key': 'Bayern Munich', 'label': 'Bayern Munich'},
    {'key': 'PSG', 'label': 'PSG'},
    {'key': 'Inter Milan', 'label': 'Inter Milan'},
  ];

  final List<Map<String, String>> _frequencies = [
    {'key': 'realtime', 'label': 'Real-time'},
    {'key': 'hourly', 'label': 'Hourly Digest'},
    {'key': 'daily', 'label': 'Daily Digest'},
  ];

  IconData _getIcon(String name) {
    switch (name) {
      case 'trendingDown': return LucideIcons.trendingDown;
      case 'trophy': return LucideIcons.trophy;
      case 'target': return LucideIcons.target;
      case 'userCheck': return LucideIcons.userCheck;
      case 'newspaper': return LucideIcons.newspaper;
      default: return LucideIcons.bell;
    }
  }

  Future<void> _createSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final filters = <String, dynamic>{};
    if (_selectedType == 'odds_movement') {
      filters['minOddsChange'] = _minOddsChange;
    }
    if (['prediction_alert', 'odds_movement'].contains(_selectedType)) {
      filters['minConfidence'] = _minConfidence;
    }
    if (_premiumOnly) filters['premiumOnly'] = true;
    if (_verifiedOnly) filters['verifiedOnly'] = true;

    final scopeId = _selectedScope == 'all' ? 'all' : _selectedScopeId;
    final scopeLabel = _selectedScope == 'all'
        ? 'All Matches'
        : _selectedScope == 'league'
        ? _leagues.firstWhere((l) => l['key'] == _selectedScopeId)['label']!
        : _teams.firstWhere((t) => t['key'] == _selectedScopeId, orElse: () => {'label': _selectedScopeId})['label']!;

    final newSub = {
      'uid': uid,
      'type': _selectedType,
      'scope': _selectedScope,
      'scopeId': scopeId,
      'scopeLabel': scopeLabel,
      'delivery': _selectedDelivery.toList(),
      'frequency': _selectedFrequency,
      'filters': filters,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'synthetic': true,
    };

    try {
      await FirebaseFirestore.instance.collection('user_subscriptions').add(newSub);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoalVantageColors.positive,
            content: const Text('Subscription created'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoalVantageColors.negative,
          content: Text('Error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(top: BorderSide(color: GoalVantageColors.border, width: 2)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GoalVantageColors.border,
                ),
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(LucideIcons.plus, size: 16, color: GoalVantageColors.primary),
                const SizedBox(width: 8),
                Text(
                  'NEW SUBSCRIPTION',
                  style: TextStyle(
                    color: GoalVantageColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Icon(LucideIcons.x, size: 18, color: GoalVantageColors.foregroundSecondary),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Type selector
                _sectionLabel('ALERT TYPE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((t) {
                    final selected = _selectedType == t['key'];
                    return InkWell(
                      onTap: () => setState(() => _selectedType = t['key']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? GoalVantageColors.primary : Colors.transparent,
                          border: Border.all(
                            color: selected ? GoalVantageColors.primary : GoalVantageColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIcon(t['icon']!),
                              size: 12,
                              color: selected ? Colors.white : GoalVantageColors.foregroundSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t['label']!,
                              style: TextStyle(
                                color: selected ? Colors.white : GoalVantageColors.foreground,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Scope
                _sectionLabel('SCOPE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _scopes.map((s) {
                    final selected = _selectedScope == s['key'];
                    return InkWell(
                      onTap: () => setState(() => _selectedScope = s['key']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? GoalVantageColors.primary : Colors.transparent,
                          border: Border.all(
                            color: selected ? GoalVantageColors.primary : GoalVantageColors.border,
                          ),
                        ),
                        child: Text(
                          s['label']!,
                          style: TextStyle(
                            color: selected ? Colors.white : GoalVantageColors.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Scope target
                if (_selectedScope == 'league') ...[
                  const SizedBox(height: 16),
                  _sectionLabel('LEAGUE'),
                  const SizedBox(height: 8),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: GoalVantageColors.background,
                      border: Border.all(color: GoalVantageColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedScopeId,
                        isExpanded: true,
                        icon: Icon(LucideIcons.chevronDown, size: 14, color: GoalVantageColors.foregroundSecondary),
                        dropdownColor: GoalVantageColors.backgroundSecondary,
                        style: TextStyle(color: GoalVantageColors.foreground, fontSize: 12, fontWeight: FontWeight.w700),
                        items: _leagues.map((l) => DropdownMenuItem(
                          value: l['key'],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(l['label']!),
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedScopeId = v!),
                      ),
                    ),
                  ),
                ] else if (_selectedScope == 'team') ...[
                  const SizedBox(height: 16),
                  _sectionLabel('TEAM'),
                  const SizedBox(height: 8),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: GoalVantageColors.background,
                      border: Border.all(color: GoalVantageColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _teams.any((t) => t['key'] == _selectedScopeId) ? _selectedScopeId : _teams.first['key'],
                        isExpanded: true,
                        icon: Icon(LucideIcons.chevronDown, size: 14, color: GoalVantageColors.foregroundSecondary),
                        dropdownColor: GoalVantageColors.backgroundSecondary,
                        style: TextStyle(color: GoalVantageColors.foreground, fontSize: 12, fontWeight: FontWeight.w700),
                        items: _teams.map((t) => DropdownMenuItem(
                          value: t['key'],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(t['label']!),
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedScopeId = v!),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Frequency
                _sectionLabel('FREQUENCY'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _frequencies.map((f) {
                    final selected = _selectedFrequency == f['key'];
                    return InkWell(
                      onTap: () => setState(() => _selectedFrequency = f['key']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? GoalVantageColors.primary : Colors.transparent,
                          border: Border.all(
                            color: selected ? GoalVantageColors.primary : GoalVantageColors.border,
                          ),
                        ),
                        child: Text(
                          f['label']!,
                          style: TextStyle(
                            color: selected ? Colors.white : GoalVantageColors.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Delivery
                _sectionLabel('DELIVERY METHOD'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _deliveryChip('push', LucideIcons.bell, 'Push'),
                    _deliveryChip('email', LucideIcons.mail, 'Email'),
                    _deliveryChip('sms', LucideIcons.messageSquare, 'SMS'),
                    _deliveryChip('in_app', LucideIcons.inbox, 'In-App'),
                  ],
                ),
                const SizedBox(height: 20),

                // Filters
                if (_selectedType == 'odds_movement') ...[
                  _sectionLabel('MINIMUM ODDS CHANGE'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _minOddsChange,
                          min: 0.05,
                          max: 0.30,
                          divisions: 5,
                          activeColor: GoalVantageColors.primary,
                          inactiveColor: GoalVantageColors.border,
                          onChanged: (v) => setState(() => _minOddsChange = v),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: GoalVantageColors.background,
                          border: Border.all(color: GoalVantageColors.border),
                        ),
                        child: Text(
                          '${(_minOddsChange * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: GoalVantageColors.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (['prediction_alert', 'odds_movement'].contains(_selectedType)) ...[
                  _sectionLabel('MINIMUM CONFIDENCE'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _minConfidence,
                          min: 50,
                          max: 95,
                          divisions: 9,
                          activeColor: GoalVantageColors.primary,
                          inactiveColor: GoalVantageColors.border,
                          onChanged: (v) => setState(() => _minConfidence = v),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: GoalVantageColors.background,
                          border: Border.all(color: GoalVantageColors.border),
                        ),
                        child: Text(
                          '${_minConfidence.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: GoalVantageColors.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedType == 'prediction_alert') ...[
                  _toggleOption(
                    label: 'Premium predictions only',
                    value: _premiumOnly,
                    onChanged: (v) => setState(() => _premiumOnly = v),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_selectedType == 'tipster_update') ...[
                  _toggleOption(
                    label: 'Verified tipsters only',
                    value: _verifiedOnly,
                    onChanged: (v) => setState(() => _verifiedOnly = v),
                  ),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 20),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _createSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GoalVantageColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CREATE SUBSCRIPTION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.check, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: GoalVantageColors.foregroundSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _deliveryChip(String key, IconData icon, String label) {
    final selected = _selectedDelivery.contains(key);
    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selectedDelivery.remove(key);
        } else {
          _selectedDelivery.add(key);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GoalVantageColors.primary : Colors.transparent,
          border: Border.all(
            color: selected ? GoalVantageColors.primary : GoalVantageColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? Colors.white : GoalVantageColors.foregroundSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : GoalVantageColors.foreground,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: GoalVantageColors.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 22,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? GoalVantageColors.primary : GoalVantageColors.border,
            ),
            child: AnimatedAlign(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}