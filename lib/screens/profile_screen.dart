import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// ============================================================================
// MODELS
// ============================================================================

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? imageUrl;
  final String vipTier;
  final String memberSince;
  final double balance;
  final double totalWagered;
  final double monthlyWagered;
  final int totalBets;
  final double netProfit;
  final double winRate;
  final bool isVerified;
  final bool twoFactorEnabled;
  final Map<String, dynamic> responsibleGambling;

  UserProfile.fromMap(Map<String, dynamic> map, String docId)
      : uid = docId,
        name = map['name'] ?? 'Bettor',
        email = map['email'] ?? '',
        imageUrl = map['imageUrl'],
        vipTier = map['vipTier'] ?? 'rookie',
        memberSince = map['memberSince'] ?? '2026',
        balance = (map['balance'] as num?)?.toDouble() ?? 0,
        totalWagered = (map['totalWagered'] as num?)?.toDouble() ?? 0,
        monthlyWagered = (map['monthlyWagered'] as num?)?.toDouble() ?? 0,
        totalBets = (map['totalBets'] as num?)?.toInt() ?? 0,
        netProfit = (map['netProfit'] as num?)?.toDouble() ?? 0,
        winRate = (map['winRate'] as num?)?.toDouble() ?? 0,
        isVerified = map['isVerified'] ?? false,
        twoFactorEnabled = map['twoFactorEnabled'] ?? false,
        responsibleGambling = map['responsibleGambling'] ?? {};
}

class RecentBet {
  final String id;
  final String type;
  final String matchTitle;
  final double stake;
  final String status;
  final DateTime? placedAt;

  RecentBet.fromMap(Map<String, dynamic> map, String docId)
      : id = docId,
        type = map['type'] ?? 'single',
        matchTitle = map['legs'] != null && (map['legs'] as List).isNotEmpty
            ? (map['legs'][0]['matchTitle'] ?? 'Unknown Match')
            : 'Unknown Match',
        stake = (map['stake'] as num?)?.toDouble() ?? 0,
        status = map['status'] ?? 'open',
        placedAt = (map['createdAt'] as Timestamp?)?.toDate();
}

// ============================================================================
// PROFILE SCREEN
// ============================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<RecentBet> _recentBets = [];
  bool _isLoading = true;
  StreamSubscription? _profileSub;
  StreamSubscription? _betsSub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _betsSub?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // DATA STREAMS
  // ==========================================================================

  void _loadProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Profile stream
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _profile = UserProfile.fromMap(doc.data()!, doc.id);
            _isLoading = false;
          });
        }
      } else {
        // Create default profile if doesn't exist
        _createDefaultProfile(uid);
      }
    }, onError: (error) {
      debugPrint('Error loading profile: $error');
      if (mounted) setState(() => _isLoading = false);
    });

    // Recent bets stream
    _betsSub = FirebaseFirestore.instance
        .collection('user_bets')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      final bets = snapshot.docs
          .map((doc) => RecentBet.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() => _recentBets = bets);
      }
    });
  }

  void _createDefaultProfile(String uid) {
    final user = FirebaseAuth.instance.currentUser;
    final defaultProfile = {
      'name': user?.displayName ?? 'Bettor',
      'email': user?.email ?? '',
      'imageUrl': user?.photoURL,
      'vipTier': 'rookie',
      'memberSince': '2026',
      'balance': 0.0,
      'totalWagered': 0.0,
      'monthlyWagered': 0.0,
      'totalBets': 0,
      'netProfit': 0.0,
      'winRate': 0.0,
      'isVerified': false,
      'twoFactorEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
      'responsibleGambling': {
        'depositLimit': null,
        'lossLimit': null,
        'sessionLimit': null,
        'selfExclusion': false,
      },
    };

    FirebaseFirestore.instance.collection('users').doc(uid).set(defaultProfile, SetOptions(merge: true));
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _formatMoney(double v) {
    final isNeg = v < 0;
    final abs = v.abs();
    final str = abs.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
    return '${isNeg ? '-' : ''}\$$intPart.${parts[1]}';
  }

  Color _getVipColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'elite': return AppColors.secondary;
      case 'pro': return AppColors.primary;
      default: return AppColors.foregroundSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'won': return AppColors.positive;
      case 'lost': return AppColors.negative;
      case 'open': return AppColors.primary;
      case 'pending': return AppColors.warning;
      case 'cashed': return AppColors.secondary;
      default: return AppColors.foregroundSecondary;
    }
  }

  double _getVipProgress() {
    if (_profile == null) return 0;
    final monthly = _profile!.monthlyWagered;
    if (_profile!.vipTier == 'elite') return 1.0;
    if (_profile!.vipTier == 'pro') return (monthly / 10000).clamp(0.0, 1.0);
    return (monthly / 1000).clamp(0.0, 1.0);
  }

  String _getNextTier() {
    if (_profile == null) return 'Pro';
    switch (_profile!.vipTier) {
      case 'elite': return 'Max';
      case 'pro': return 'Elite';
      default: return 'Pro';
    }
  }

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  Future<void> _handleSignOut() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'SIGN OUT',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of OnyxBet?',
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 13,
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
              Navigator.pop(dialogContext);
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: Text(
              'SIGN OUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _profile?.name ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'EDIT NAME',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.foreground),
          decoration: InputDecoration(
            labelText: 'DISPLAY NAME',
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
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && _profile != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_profile!.uid)
                    .update({'name': newName});
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: Text(
              'SAVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
            ? _buildErrorState()
            : CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader()),

            // User card
            SliverToBoxAdapter(child: _buildUserCard()),

            // Stats
            SliverToBoxAdapter(child: _buildStatsGrid()),

            // VIP Progress
            SliverToBoxAdapter(child: _buildVipProgress()),

            // Recent bets
            if (_recentBets.isNotEmpty)
              SliverToBoxAdapter(child: _buildRecentBets()),

            // Account sections
            SliverToBoxAdapter(child: _buildAccountSections()),

            // Responsible gambling
            SliverToBoxAdapter(child: _buildResponsibleGambling()),

            // Sign out
            SliverToBoxAdapter(child: _buildSignOut()),

            // Footer
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.user, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'ACCOUNT',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'MY PROFILE',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 0.95,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // USER CARD
  // ==========================================================================

  Widget _buildUserCard() {
    final profile = _profile!;
    final vipColor = _getVipColor(profile.vipTier);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: profile.vipTier == 'elite' ? AppColors.secondary : AppColors.border,
          width: profile.vipTier == 'elite' ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: vipColor.withOpacity(0.15),
                    border: Border.all(
                      color: vipColor,
                      width: 2,
                    ),
                  ),
                  child: profile.imageUrl != null && profile.imageUrl!.isNotEmpty
                      ? Image.network(
                    profile.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildAvatarFallback(profile.name),
                  )
                      : _buildAvatarFallback(profile.name),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(LucideIcons.badgeCheck, size: 16, color: AppColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: TextStyle(
                          color: AppColors.foregroundSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // VIP badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: vipColor,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  profile.vipTier == 'elite' ? LucideIcons.crown : LucideIcons.trophy,
                                  size: 10,
                                  color: profile.vipTier == 'elite'
                                      ? AppColors.secondaryForeground
                                      : AppColors.primaryForeground,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.vipTier.toUpperCase(),
                                  style: TextStyle(
                                    color: profile.vipTier == 'elite'
                                        ? AppColors.secondaryForeground
                                        : AppColors.primaryForeground,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Member since ${profile.memberSince}',
                            style: TextStyle(
                              color: AppColors.foregroundSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                InkWell(
                  onTap: _showEditNameDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(LucideIcons.pencil, size: 14, color: AppColors.foregroundSecondary),
                  ),
                ),
              ],
            ),

            // Balance display
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVAILABLE BALANCE',
                          style: TextStyle(
                            color: AppColors.foregroundSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatMoney(profile.balance),
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {}, // Navigate to deposit
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: Text(
                        'DEPOSIT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
          color: _getVipColor(_profile?.vipTier ?? 'rookie'),
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ==========================================================================
  // STATS GRID
  // ==========================================================================

  Widget _buildStatsGrid() {
    final profile = _profile!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'BETTING STATS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'TOTAL BETS',
                  '${profile.totalBets}',
                  AppColors.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'WIN RATE',
                  '${profile.winRate.toStringAsFixed(1)}%',
                  profile.winRate >= 50 ? AppColors.positive : AppColors.negative,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'NET P/L',
                  _formatMoney(profile.netProfit),
                  profile.netProfit >= 0 ? AppColors.positive : AppColors.negative,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'WAGERED',
                  _formatMoney(profile.totalWagered),
                  AppColors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // VIP PROGRESS
  // ==========================================================================

  Widget _buildVipProgress() {
    final profile = _profile!;
    final progress = _getVipProgress();
    final nextTier = _getNextTier();
    final currentTier = profile.vipTier;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.crown, size: 14, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'VIP PROGRESS',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentTier.toUpperCase(),
                          style: TextStyle(
                            color: _getVipColor(currentTier),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (nextTier != 'Max')
                          Text(
                            nextTier.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.foregroundSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getVipColor(currentTier),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Monthly wagered
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY WAGERED',
                style: TextStyle(
                  color: AppColors.foregroundSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                _formatMoney(profile.monthlyWagered),
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (nextTier != 'Max') ...[
            const SizedBox(height: 4),
            Text(
              'Reach ${nextTier == 'Elite' ? '\$10,000' : '\$1,000'} monthly to unlock ${nextTier} tier',
              style: TextStyle(
                color: AppColors.foregroundSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // RECENT BETS
  // ==========================================================================

  Widget _buildRecentBets() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'RECENT BETS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {}, // Navigate to My Bets
                child: Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _recentBets.asMap().entries.map((entry) {
                final index = entry.key;
                final bet = entry.value;
                final statusColor = _getStatusColor(bet.status);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border,
                        width: index == _recentBets.length - 1 ? 0 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Type icon
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          bet.type == 'parlay' ? LucideIcons.target : LucideIcons.zap,
                          size: 14,
                          color: AppColors.foregroundSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bet.matchTitle,
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${bet.type.toUpperCase()} · ${_formatMoney(bet.stake)}',
                              style: TextStyle(
                                color: AppColors.foregroundSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          bet.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ACCOUNT SECTIONS
  // ==========================================================================

  Widget _buildAccountSections() {
    final profile = _profile!;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.settings, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'ACCOUNT SETTINGS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Personal Info
          _settingsSection(
            icon: LucideIcons.user,
            title: 'Personal Information',
            subtitle: 'Name, email, phone number',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // Security
          _settingsSection(
            icon: LucideIcons.lock,
            title: 'Security',
            subtitle: profile.twoFactorEnabled ? '2FA enabled' : '2FA not enabled',
            onTap: () {},
            badge: profile.twoFactorEnabled ? 'SECURE' : 'ACTION NEEDED',
            badgeColor: profile.twoFactorEnabled ? AppColors.positive : AppColors.warning,
          ),
          const SizedBox(height: 8),

          // Payment Methods
          _settingsSection(
            icon: LucideIcons.creditCard,
            title: 'Payment Methods',
            subtitle: 'Cards, bank accounts, crypto',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // Verification
          _settingsSection(
            icon: LucideIcons.badgeCheck,
            title: 'Identity Verification',
            subtitle: profile.isVerified ? 'Verified' : 'Not verified',
            onTap: () {},
            badge: profile.isVerified ? 'VERIFIED' : 'REQUIRED',
            badgeColor: profile.isVerified ? AppColors.positive : AppColors.warning,
          ),
          const SizedBox(height: 8),

          // Notifications
          _settingsSection(
            icon: LucideIcons.bell,
            title: 'Notifications',
            subtitle: 'Bet alerts, promotions, results',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // Preferences
          _settingsSection(
            icon: LucideIcons.sliders,
            title: 'Preferences',
            subtitle: 'Odds format, language, theme',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _settingsSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.foregroundSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.foreground).withOpacity(0.12),
                  border: Border.all(color: (badgeColor ?? AppColors.foreground).withOpacity(0.3)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor ?? AppColors.foreground,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.foregroundSecondary),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // RESPONSIBLE GAMBLING
  // ==========================================================================

  Widget _buildResponsibleGambling() {
    final rg = _profile?.responsibleGambling ?? {};
    final hasLimits = rg['depositLimit'] != null || rg['lossLimit'] != null || rg['sessionLimit'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.heart, size: 14, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'RESPONSIBLE GAMBLING',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Set limits, take breaks, and stay in control of your betting.',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Limits status
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEPOSIT LIMIT',
                        style: TextStyle(
                          color: AppColors.foregroundSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rg['depositLimit'] != null ? _formatMoney((rg['depositLimit'] as num).toDouble()) : 'Not set',
                        style: TextStyle(
                          color: rg['depositLimit'] != null ? AppColors.positive : AppColors.foregroundSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOSS LIMIT',
                        style: TextStyle(
                          color: AppColors.foregroundSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rg['lossLimit'] != null ? _formatMoney((rg['lossLimit'] as num).toDouble()) : 'Not set',
                        style: TextStyle(
                          color: rg['lossLimit'] != null ? AppColors.positive : AppColors.foregroundSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SESSION LIMIT',
                        style: TextStyle(
                          color: AppColors.foregroundSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rg['sessionLimit'] != null ? '${rg['sessionLimit']}min' : 'Not set',
                        style: TextStyle(
                          color: rg['sessionLimit'] != null ? AppColors.positive : AppColors.foregroundSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: Text(
                      'SET LIMITS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: Text(
                      'TAKE A BREAK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SIGN OUT
  // ==========================================================================

  Widget _buildSignOut() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _handleSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.negative,
                side: BorderSide(color: AppColors.negative.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.logOut, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'SIGN OUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () {}, // Navigate to delete account
              style: TextButton.styleFrom(
                foregroundColor: AppColors.foregroundSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                'DELETE ACCOUNT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.foregroundSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FOOTER
  // ==========================================================================

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo
          Image.asset("assets/logo.png", height: 52),
          const SizedBox(height: 12),
          Text(
            'Version 1.0.0 · Licensed & Regulated · 18+',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 OnyxBet. All rights reserved.',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ERROR STATE
  // ==========================================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertTriangle, size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              'PROFILE NOT FOUND',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in again to access your profile.',
              style: TextStyle(
                color: AppColors.foregroundSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'SIGN IN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}