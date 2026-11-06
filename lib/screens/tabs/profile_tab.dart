// lib/features/pitchiq/tabs/profile_tab.dart
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
import '../../theme/colors.dart';
import '../../models/premium_subscription.dart';
import '../../services/revenue_cat_service.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/vip_paywall_sheet.dart';
// TODO: Verify this import path matches your actual project structure
import '../login_screen.dart'; 

// ----------------------------------------------------------------------------
//  PROFILE TAB – MAIN WIDGET
// ----------------------------------------------------------------------------

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _showUpgradeSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog(context);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PremiumUpgradeSheet(),
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GoalVantageColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: GoalVantageColors.gold.withOpacity(0.3)),
        ),
        title: const Row(
          children: [
            Icon(LucideIcons.lock, color: Colors.amber, size: 20), // Fallback to Colors.amber if gold isn't defined in this scope
            SizedBox(width: 8),
            Text('Login Required'),
          ],
        ),
        content: const Text(
          'You must be logged in to subscribe to GoalVantage Premium and manage your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GoalVantageColors.gold,
              foregroundColor: GoalVantageColors.background,
            ),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out successfully')),
      );
    }
  }

  void _navigateToPage(Widget page) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PremiumSubscription?>(
      stream: _SubscriptionService.instance.watchSubscription(),
      builder: (context, snapshot) {
        final sub = snapshot.data;
        final user = FirebaseAuth.instance.currentUser;

        return Scaffold(
          backgroundColor: GoalVantageColors.background,
          body: Navigator(
            key: _navigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (_) => _ProfileMainView(
                  user: user,
                  subscription: sub,
                  onUpgrade: () => _showUpgradeSheet(context),
                  onSignOut: () => _signOut(context),
                  onNavigate: _navigateToPage,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
//  MAIN PROFILE VIEW
// ----------------------------------------------------------------------------

class _ProfileMainView extends StatelessWidget {
  final User? user;
  final PremiumSubscription? subscription;
  final VoidCallback onUpgrade;
  final VoidCallback onSignOut;
  final void Function(Widget) onNavigate;

  const _ProfileMainView({
    required this.user,
    required this.subscription,
    required this.onUpgrade,
    required this.onSignOut,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final padding = ResponsiveHelper.responsivePadding(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(user, isTablet, context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: padding,
            child: _buildSubscriptionCard(
              context: context,
              sub: subscription,
              onUpgrade: onUpgrade,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: padding,
            child: _buildMenuItems(
              context,
              onNavigate: onNavigate,
              isTablet: isTablet,
              isDesktop: isDesktop,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: padding,
            child: _buildSignOut(context, onSignOut: onSignOut),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHeader(User? user, bool isTablet, BuildContext context) {
    final avatarSize = ResponsiveHelper.scaleFont(context, isTablet ? 80 : 64);
    final nameSize = ResponsiveHelper.scaleFont(context, isTablet ? 28 : 20);
    final emailSize = ResponsiveHelper.scaleFont(context, isTablet ? 14 : 11);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        ResponsiveHelper.scaleFont(context, 20),
        16,
        ResponsiveHelper.scaleFont(context, 24),
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: GoalVantageColors.primary.withOpacity(0.15),
              border: Border.all(color: GoalVantageColors.primary, width: 2),
            ),
            child: Center(
              child: Text(
                (user?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: GoalVantageColors.primary,
                  fontSize: avatarSize * 0.45,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Guest User',
                  style: TextStyle(
                    color: GoalVantageColors.foreground,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'Not signed in',
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: emailSize,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required BuildContext context,
    required PremiumSubscription? sub,
    required VoidCallback onUpgrade,
  }) {
    final isActive = sub?.isActive == true;
    final fontSize = ResponsiveHelper.scaleFont(context, 12);
    final buttonHeight = ResponsiveHelper.scaleFont(context, 48);

    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.scaleFont(context, 20)),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(
          color: isActive ? GoalVantageColors.gold : GoalVantageColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.crown,
                size: ResponsiveHelper.scaleFont(context, 18),
                color: isActive ? GoalVantageColors.gold : GoalVantageColors.foregroundSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'PREMIUM ACTIVE' : 'FREE PLAN',
                style: TextStyle(
                  color: isActive ? GoalVantageColors.gold : GoalVantageColors.foreground,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (isActive && sub != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: GoalVantageColors.positive.withOpacity(0.15),
                    border: Border.all(color: GoalVantageColors.positive.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${sub.daysRemaining}d LEFT',
                    style: TextStyle(
                      color: GoalVantageColors.positive,
                      fontSize: ResponsiveHelper.scaleFont(context, 9),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isActive
                ? 'You have full access to all premium AI predictions, detailed analysis, and exclusive tipster picks.'
                : 'Upgrade to unlock premium AI predictions (80%+ confidence), detailed match analysis, and exclusive tipster access.',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: ResponsiveHelper.scaleFont(context, 12),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive
                    ? GoalVantageColors.background
                    : GoalVantageColors.gold,
                foregroundColor: isActive
                    ? GoalVantageColors.gold
                    : GoalVantageColors.background,
                elevation: 0,
                side: isActive
                    ? BorderSide(color: GoalVantageColors.gold)
                    : BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.crown, size: ResponsiveHelper.scaleFont(context, 14)),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'MANAGE SUBSCRIPTION' : 'UPGRADE TO PREMIUM',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.scaleFont(context, 11),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
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

  Widget _buildMenuItems(
    BuildContext context, {
    required void Function(Widget) onNavigate,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final items = [
      {'icon': LucideIcons.bell, 'label': 'Notification Settings', 'subtitle': 'Push, email, SMS alerts', 'page': const _NotificationSettingsPage()},
      {'icon': LucideIcons.wallet, 'label': 'Payment History', 'subtitle': 'View your payment history', 'page': const _PaymentHistoryPage()},
      {'icon': LucideIcons.shield, 'label': 'Security', 'subtitle': 'Password & 2FA', 'page': const _SecurityPage()},
      {'icon': LucideIcons.helpCircle, 'label': 'Help Center', 'subtitle': 'FAQs & support', 'page': const _HelpCenterPage()},
      {'icon': LucideIcons.fileText, 'label': 'Terms & Privacy', 'subtitle': 'Legal documents', 'page': const _TermsPrivacyPage()},
    ];

    if (isTablet || isDesktop) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isDesktop ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3.5,
        children: items.map((item) => _buildMenuItem(item, onNavigate, context)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(color: GoalVantageColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;
          return InkWell(
            onTap: () => onNavigate(item['page'] as Widget),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isLast ? Colors.transparent : GoalVantageColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: GoalVantageColors.primary.withOpacity(0.12),
                      border: Border.all(color: GoalVantageColors.primary.withOpacity(0.2)),
                    ),
                    child: Icon(item['icon'] as IconData, size: 16, color: GoalVantageColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            color: GoalVantageColors.foreground,
                            fontSize: ResponsiveHelper.scaleFont(context, 13),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle'] as String,
                          style: TextStyle(
                            color: GoalVantageColors.foregroundSecondary,
                            fontSize: ResponsiveHelper.scaleFont(context, 10),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 14, color: GoalVantageColors.foregroundSecondary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(
    Map<String, dynamic> item,
    void Function(Widget) onNavigate,
    BuildContext context,
  ) {
    return InkWell(
      onTap: () => onNavigate(item['page'] as Widget),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GoalVantageColors.card,
          border: Border.all(color: GoalVantageColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: GoalVantageColors.primary.withOpacity(0.12),
                border: Border.all(color: GoalVantageColors.primary.withOpacity(0.2)),
              ),
              child: Icon(item['icon'] as IconData, size: 16, color: GoalVantageColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: GoalVantageColors.foreground,
                      fontSize: ResponsiveHelper.scaleFont(context, 13),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item['subtitle'] as String,
                    style: TextStyle(
                      color: GoalVantageColors.foregroundSecondary,
                      fontSize: ResponsiveHelper.scaleFont(context, 10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 14, color: GoalVantageColors.foregroundSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOut(BuildContext context, {required VoidCallback onSignOut}) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: ResponsiveHelper.scaleFont(context, 48),
          child: OutlinedButton(
            onPressed: onSignOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: GoalVantageColors.negative,
              side: BorderSide(color: GoalVantageColors.negative.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.logOut, size: ResponsiveHelper.scaleFont(context, 14)),
                const SizedBox(width: 8),
                const Text(
                  'SIGN OUT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GoalVantage v1.0.0 · © 2026',
          style: TextStyle(
            color: GoalVantageColors.foregroundSecondary,
            fontSize: ResponsiveHelper.scaleFont(context, 9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ========================================================================
//  SUB-PAGES
// ========================================================================

class _NotificationSettingsPage extends StatefulWidget {
  const _NotificationSettingsPage();

  @override
  State<_NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<_NotificationSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _push = false;
  bool _email = false;
  bool _sms = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();
          
      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          _push = data['push'] ?? false;
          _email = data['email'] ?? false;
          _sms = data['sms'] ?? false;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('notifications')
        .set({key: value}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      appBar: _buildAppBar(context, 'Notification Settings'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: ResponsiveHelper.responsivePadding(context),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: LucideIcons.bell,
                    title: 'Push Notifications',
                    value: _push,
                    onChanged: (v) {
                      setState(() => _push = v);
                      _saveSetting('push', v);
                    },
                  ),
                  _buildSwitchTile(
                    icon: LucideIcons.mail,
                    title: 'Email Alerts',
                    value: _email,
                    onChanged: (v) {
                      setState(() => _email = v);
                      _saveSetting('email', v);
                    },
                  ),
                  _buildSwitchTile(
                    icon: LucideIcons.smartphone,
                    title: 'SMS Alerts',
                    value: _sms,
                    onChanged: (v) {
                      setState(() => _sms = v);
                      _saveSetting('sms', v);
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(color: GoalVantageColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: GoalVantageColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: GoalVantageColors.foreground,
                fontSize: ResponsiveHelper.scaleFont(context, 16),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: GoalVantageColors.positive,
            inactiveThumbColor: GoalVantageColors.foregroundSecondary,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String title) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), // Adjust color as needed
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: GoalVantageColors.foreground,
          fontSize: ResponsiveHelper.scaleFont(context, 18),
          fontWeight: FontWeight.w900,
        ),
      ),
      backgroundColor: GoalVantageColors.background,
      elevation: 0,
    );
  }
}

class _PaymentHistoryPage extends StatelessWidget {
  const _PaymentHistoryPage();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: GoalVantageColors.background,
        appBar: _buildAppBar(context, 'Payment History'),
        body: const Center(child: Text('Please sign in to view payment history.')),
      );
    }

    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      appBar: _buildAppBar(context, 'Payment History'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('payments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading payments',
                style: TextStyle(color: GoalVantageColors.negative),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.wallet, size: 64, color: GoalVantageColors.foregroundSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No payments yet',
                    style: TextStyle(
                      color: GoalVantageColors.foreground,
                      fontSize: ResponsiveHelper.scaleFont(context, 20),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: ResponsiveHelper.responsivePadding(context),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final amount = (data['paidAmount'] ?? 0.0).toDouble();
              final currency = data['paidCurrency'] ?? 'USD';
              final status = data['status'] ?? 'unknown';
              final createdAt = data['createdAt'] as Timestamp?;
              final date = createdAt?.toDate() ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GoalVantageColors.card,
                  border: Border.all(color: GoalVantageColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'successful' ? LucideIcons.checkCircle : LucideIcons.xCircle,
                      color: status == 'successful' ? GoalVantageColors.positive : GoalVantageColors.negative,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$currency ${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: GoalVantageColors.foreground,
                              fontSize: ResponsiveHelper.scaleFont(context, 16),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy · HH:mm').format(date),
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: ResponsiveHelper.scaleFont(context, 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (status == 'successful' ? GoalVantageColors.positive : GoalVantageColors.negative).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'successful' ? GoalVantageColors.positive : GoalVantageColors.negative,
                          fontSize: ResponsiveHelper.scaleFont(context, 10),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String title) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: GoalVantageColors.foreground,
          fontSize: ResponsiveHelper.scaleFont(context, 18),
          fontWeight: FontWeight.w900,
        ),
      ),
      backgroundColor: GoalVantageColors.background,
      elevation: 0,
    );
  }
}

class _SecurityPage extends StatefulWidget {
  const _SecurityPage();

  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GoalVantageColors.card,
          title: Text(
            'Change Password',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: ResponsiveHelper.scaleFont(context, 18),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: GoalVantageColors.foregroundSecondary)),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final current = currentPasswordController.text.trim();
                      final newPass = newPasswordController.text.trim();
                      final confirm = confirmController.text.trim();
                      
                      if (newPass != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                        return;
                      }
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                        return;
                      }
                      
                      setDialogState(() => _isLoading = true);
                      try {
                        final user = _auth.currentUser;
                        if (user == null || user.email == null) throw Exception('Not signed in');
                        
                        final cred = EmailAuthProvider.credential(email: user.email!, password: current);
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(newPass);
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')));
                        }
                      } finally {
                        if (mounted) setDialogState(() => _isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: GoalVantageColors.primary,
                foregroundColor: GoalVantageColors.background,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Security',
          style: TextStyle(
            color: GoalVantageColors.foreground,
            fontSize: ResponsiveHelper.scaleFont(context, 18),
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: GoalVantageColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: ResponsiveHelper.responsivePadding(context),
        child: Column(
          children: [
            _buildSecurityTile(
              icon: LucideIcons.lock,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: _showChangePasswordDialog,
            ),
            _buildSecurityTile(
              icon: LucideIcons.shield,
              title: 'Two‑Factor Authentication',
              subtitle: 'Coming soon',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('2FA will be available soon.')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(color: GoalVantageColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 24, color: GoalVantageColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: GoalVantageColors.foreground,
                      fontSize: ResponsiveHelper.scaleFont(context, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: GoalVantageColors.foregroundSecondary,
                      fontSize: ResponsiveHelper.scaleFont(context, 12),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _HelpCenterPage extends StatelessWidget {
  const _HelpCenterPage();

  final List<Map<String, String>> _faqs = const [
    {'q': 'What is GoalVantage?', 'a': 'GoalVantage is an AI‑powered football prediction platform.'},
    {'q': 'How do I get premium?', 'a': 'Tap the "Upgrade" button in your profile.'},
    {'q': 'How are predictions made?', 'a': 'We use machine learning models trained on historical data.'},
    {'q': 'Can I cancel anytime?', 'a': 'Yes, you can cancel your subscription at any time via your device settings.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: TextStyle(
            color: GoalVantageColors.foreground,
            fontSize: ResponsiveHelper.scaleFont(context, 18),
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: GoalVantageColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: ResponsiveHelper.responsivePadding(context),
        child: ListView.builder(
          itemCount: _faqs.length,
          itemBuilder: (context, index) {
            final item = _faqs[index];
            return Card(
              color: GoalVantageColors.card,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  item['q']!,
                  style: TextStyle(
                    color: GoalVantageColors.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: ResponsiveHelper.scaleFont(context, 15),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      item['a']!,
                      style: TextStyle(
                        color: GoalVantageColors.foregroundSecondary,
                        fontSize: ResponsiveHelper.scaleFont(context, 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TermsPrivacyPage extends StatelessWidget {
  const _TermsPrivacyPage();

  static const String _legalText = '''
GOALVANTAGE – TERMS OF SERVICE & PRIVACY POLICY
Last updated: 21 August 2026

1. INTRODUCTION
Welcome to GoalVantage. By using our mobile application and services, you agree to be bound by these Terms of Service and our Privacy Policy.

2. ACCEPTANCE OF TERMS
By creating an account or using the App, you confirm that you are at least 18 years old and have the legal capacity to enter into this agreement.

3. USER ACCOUNTS
You are solely responsible for maintaining the confidentiality of your login credentials. We reserve the right to suspend or terminate accounts that violate these terms.

4. SUBSCRIPTIONS & PAYMENTS
Premium is billed monthly via the Apple App Store or Google Play Store. Subscription fees are non-refundable except as required by law. You may cancel your subscription at any time through your device's store settings.

5. PREDICTIONS & CONTENT
All predictions are generated by artificial intelligence and are for informational and entertainment purposes only. We do not guarantee accuracy. Betting based on our content is entirely at your own risk.

6. PRIVACY POLICY
We collect account information, usage data, and device information to provide and improve the App. We do not sell your personal data to third parties. Data is retained as long as your account is active.

7. GOVERNING LAW
These Terms shall be governed by the laws of Uganda. Any disputes shall be resolved in the competent courts of Kampala.

For questions, contact us at support@goalvantage.com.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms & Privacy',
          style: TextStyle(
            color: GoalVantageColors.foreground,
            fontSize: ResponsiveHelper.scaleFont(context, 18),
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: GoalVantageColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: ResponsiveHelper.responsivePadding(context),
        child: SingleChildScrollView(
          child: SelectableText(
            _legalText,
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: ResponsiveHelper.scaleFont(context, 14),
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
//  PREMIUM UPGRADE SHEET – Native In-App Purchase
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
      if (mounted) _showSnack('In-app purchases are not available on this device.');
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_productId});

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('⚠️ IAP ERROR: Product ID "$_productId" not found.');
      if (mounted) _showSnack('Product ID not found. Check App Store / Play Console configuration.');
      return;
    }

    if (response.error != null) {
      debugPrint('⚠️ IAP ERROR: ${response.error}');
      if (mounted) _showSnack('Failed to load products: ${response.error?.message}');
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
        debugPrint('⚠️ IAP STREAM ERROR: $error');
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
      if (mounted) _showSnack('Failed to activate subscription: $e');
    }
  }

  void _handleSubscribe() {
    // Double-check login state before triggering IAP
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please log in to subscribe.');
      Navigator.pop(context); // Close sheet
      return;
    }

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
        backgroundColor: GoalVantageColors.card,
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
    final displayPrice = '20'; // Fallback, ideally from _products.first.price
    final displayCurrency = 'USD'; // Fallback
    final platformName = defaultTargetPlatform == TargetPlatform.iOS ? 'APPLE' : 'GOOGLE';

    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.scaleFont(context, 24)),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: const Border(top: BorderSide(color: Colors.amber, width: 2)), // Fallback to Colors.amber if gold isn't defined
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
              Icon(LucideIcons.crown, size: ResponsiveHelper.scaleFont(context, 20), color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'GOALVANTAGE PREMIUM',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: ResponsiveHelper.scaleFont(context, 11),
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
              fontSize: ResponsiveHelper.scaleFont(context, 24),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.scaleFont(context, 16)),
            decoration: BoxDecoration(
              color: GoalVantageColors.card,
              border: Border.all(color: Colors.amber, width: 1.5),
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
                          fontSize: ResponsiveHelper.scaleFont(context, 9),
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
                              fontSize: ResponsiveHelper.scaleFont(context, 32),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/month',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: ResponsiveHelper.scaleFont(context, 12),
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
                Icon(LucideIcons.check, size: ResponsiveHelper.scaleFont(context, 14), color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b,
                    style: TextStyle(
                      color: GoalVantageColors.foreground,
                      fontSize: ResponsiveHelper.scaleFont(context, 13),
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
            height: ResponsiveHelper.scaleFont(context, 52),
            child: ElevatedButton(
              onPressed: _isProcessing || !_isInitialized ? null : _handleSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: GoalVantageColors.background,
                elevation: 0,
                disabledBackgroundColor: Colors.amber.withOpacity(0.5),
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
                          size: ResponsiveHelper.scaleFont(context, 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SUBSCRIBE WITH $platformName PAY',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.scaleFont(context, 13),
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
                fontSize: ResponsiveHelper.scaleFont(context, 10),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
//  SUBSCRIPTION SERVICE – INLINE SINGLETON
// ----------------------------------------------------------------------------

class _SubscriptionService {
  static final _SubscriptionService instance = _SubscriptionService._internal();
  _SubscriptionService._internal();

  Stream<PremiumSubscription?> watchSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc('premium')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return PremiumSubscription.fromMap(doc.data()!);
    });
  }
}










// // lib/features/pitchiq/tabs/profile_tab.dart
// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:intl/intl.dart';
// import 'package:lucide_icons_flutter/lucide_icons.dart';

// import '../../theme/app_colors.dart';
// import '../../models/premium_subscription.dart';
// import '../../theme/colors.dart';
// import '../../utils/responsive_helper.dart';

// // ----------------------------------------------------------------------------
// //  PROFILE TAB – MAIN WIDGET WITH LOCAL NAVIGATOR
// // ----------------------------------------------------------------------------

// class ProfileTab extends StatefulWidget {
//   const ProfileTab({super.key});

//   @override
//   State<ProfileTab> createState() => _ProfileTabState();
// }

// class _ProfileTabState extends State<ProfileTab> {
//   final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

//   void _showUpgradeSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: GoalVantageColors.backgroundSecondary,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => const _PremiumUpgradeSheet(),
//     );
//   }

//   void _signOut(BuildContext context) async {
//     await FirebaseAuth.instance.signOut();
//     if (context.mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Signed out successfully')),
//       );
//     }
//   }

//   void _navigateToPage(Widget page) {
//     _navigatorKey.currentState?.push(
//       MaterialPageRoute(builder: (_) => page),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<PremiumSubscription?>(
//       stream: _SubscriptionService.instance.watchSubscription(),
//       builder: (context, snapshot) {
//         final sub = snapshot.data;
//         final user = FirebaseAuth.instance.currentUser;

//         return Scaffold(
//           backgroundColor: GoalVantageColors.background,
//           body: Navigator(
//             key: _navigatorKey,
//             onGenerateRoute: (settings) {
//               return MaterialPageRoute(
//                 builder: (_) => _ProfileMainView(
//                   user: user,
//                   subscription: sub,
//                   onUpgrade: () => _showUpgradeSheet(context),
//                   onSignOut: () => _signOut(context),
//                   onNavigate: _navigateToPage,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }

// // ----------------------------------------------------------------------------
// //  MAIN PROFILE VIEW
// // ----------------------------------------------------------------------------

// class _ProfileMainView extends StatelessWidget {
//   final User? user;
//   final PremiumSubscription? subscription;
//   final VoidCallback onUpgrade;
//   final VoidCallback onSignOut;
//   final void Function(Widget) onNavigate;

//   const _ProfileMainView({
//     required this.user,
//     required this.subscription,
//     required this.onUpgrade,
//     required this.onSignOut,
//     required this.onNavigate,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isTablet = ResponsiveHelper.isTablet(context);
//     final isDesktop = ResponsiveHelper.isDesktop(context);
//     final padding = ResponsiveHelper.responsivePadding(context);

//     return CustomScrollView(
//       slivers: [
//         SliverToBoxAdapter(child: _buildHeader(user, isTablet, context)),
//         SliverToBoxAdapter(
//           child: Padding(
//             padding: padding,
//             child: _buildSubscriptionCard(
//               context: context,
//               sub: subscription,
//               onUpgrade: onUpgrade,
//             ),
//           ),
//         ),
//         SliverToBoxAdapter(
//           child: Padding(
//             padding: padding,
//             child: _buildMenuItems(
//               context,
//               onNavigate: onNavigate,
//               isTablet: isTablet,
//               isDesktop: isDesktop,
//             ),
//           ),
//         ),
//         SliverToBoxAdapter(
//           child: Padding(
//             padding: padding,
//             child: _buildSignOut(context, onSignOut: onSignOut),
//           ),
//         ),
//         const SliverToBoxAdapter(child: SizedBox(height: 24)),
//       ],
//     );
//   }

//   // ---------------------- Header ----------------------
//   Widget _buildHeader(User? user, bool isTablet, BuildContext context) {
//     final avatarSize = ResponsiveHelper.scaleFont(context, isTablet ? 80 : 64);
//     final nameSize = ResponsiveHelper.scaleFont(context, isTablet ? 28 : 20);
//     final emailSize = ResponsiveHelper.scaleFont(context, isTablet ? 14 : 11);

//     return Container(
//       padding: EdgeInsets.fromLTRB(
//         16,
//         ResponsiveHelper.scaleFont(context, 20),
//         16,
//         ResponsiveHelper.scaleFont(context, 24),
//       ),
//       decoration: BoxDecoration(
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: avatarSize,
//             height: avatarSize,
//             decoration: BoxDecoration(
//               color: GoalVantageColors.primary.withOpacity(0.15),
//               border: Border.all(color: GoalVantageColors.primary, width: 2),
//             ),
//             child: Center(
//               child: Text(
//                 (user?.displayName ?? 'U').substring(0, 1).toUpperCase(),
//                 style: TextStyle(
//                   color: GoalVantageColors.primary,
//                   fontSize: avatarSize * 0.45,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   user?.displayName ?? 'Guest User',
//                   style: TextStyle(
//                     color: GoalVantageColors.foreground,
//                     fontSize: nameSize,
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: -0.5,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   user?.email ?? 'Not signed in',
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: emailSize,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---------------------- Subscription Card ----------------------
//   Widget _buildSubscriptionCard({
//     required BuildContext context,
//     required PremiumSubscription? sub,
//     required VoidCallback onUpgrade,
//   }) {
//     final isActive = sub?.isActive == true;
//     final fontSize = ResponsiveHelper.scaleFont(context, 12);
//     final buttonHeight = ResponsiveHelper.scaleFont(context, 48);

//     return Container(
//       padding: EdgeInsets.all(ResponsiveHelper.scaleFont(context, 20)),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(
//           color: isActive ? GoalVantageColors.gold : GoalVantageColors.border,
//           width: isActive ? 2 : 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 LucideIcons.crown,
//                 size: ResponsiveHelper.scaleFont(context, 18),
//                 color: isActive ? GoalVantageColors.gold : GoalVantageColors.foregroundSecondary,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 isActive ? 'PREMIUM ACTIVE' : 'FREE PLAN',
//                 style: TextStyle(
//                   color: isActive ? GoalVantageColors.gold : GoalVantageColors.foreground,
//                   fontSize: fontSize,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//               const Spacer(),
//               if (isActive)
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: GoalVantageColors.positive.withOpacity(0.15),
//                     border: Border.all(color: GoalVantageColors.positive.withOpacity(0.4)),
//                   ),
//                   child: Text(
//                     '${sub!.daysRemaining}d LEFT',
//                     style: TextStyle(
//                       color: GoalVantageColors.positive,
//                       fontSize: ResponsiveHelper.scaleFont(context, 9),
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.0,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             isActive
//                 ? 'You have full access to all premium AI predictions, detailed analysis, and exclusive tipster picks.'
//                 : 'Upgrade to unlock premium AI predictions (80%+ confidence), detailed match analysis, and exclusive tipster access.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: ResponsiveHelper.scaleFont(context, 12),
//               fontWeight: FontWeight.w500,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: buttonHeight,
//             child: ElevatedButton(
//               onPressed: onUpgrade,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: isActive
//                     ? GoalVantageColors.background
//                     : GoalVantageColors.gold,
//                 foregroundColor: isActive
//                     ? GoalVantageColors.gold
//                     : GoalVantageColors.background,
//                 elevation: 0,
//                 side: isActive
//                     ? BorderSide(color: GoalVantageColors.gold)
//                     : BorderSide.none,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(LucideIcons.crown, size: ResponsiveHelper.scaleFont(context, 14)),
//                   const SizedBox(width: 8),
//                   Text(
//                     isActive ? 'MANAGE SUBSCRIPTION' : 'UPGRADE TO PREMIUM',
//                     style: TextStyle(
//                       fontSize: ResponsiveHelper.scaleFont(context, 11),
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---------------------- Menu Items (Responsive) ----------------------
//   Widget _buildMenuItems(
//       BuildContext context, {
//         required void Function(Widget) onNavigate,
//         required bool isTablet,
//         required bool isDesktop,
//       }) {
//     final items = [
//       {'icon': LucideIcons.bell, 'label': 'Notification Settings', 'subtitle': 'Push, email, SMS alerts', 'page': const _NotificationSettingsPage()},
//       {'icon': LucideIcons.wallet, 'label': 'Payment History', 'subtitle': 'View your payment history', 'page': const _PaymentHistoryPage()},
//       {'icon': LucideIcons.shield, 'label': 'Security', 'subtitle': 'Password & 2FA', 'page': const _SecurityPage()},
//       {'icon': LucideIcons.helpCircle, 'label': 'Help Center', 'subtitle': 'FAQs & support', 'page': const _HelpCenterPage()},
//       {'icon': LucideIcons.fileText, 'label': 'Terms & Privacy', 'subtitle': 'Legal documents', 'page': const _TermsPrivacyPage()},
//     ];

//     if (isTablet || isDesktop) {
//       return GridView.count(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         crossAxisCount: isDesktop ? 3 : 2,
//         mainAxisSpacing: 12,
//         crossAxisSpacing: 12,
//         childAspectRatio: 3.5,
//         children: items.map((item) => _buildMenuItem(item, onNavigate, context)).toList(),
//       );
//     }

//     return Container(
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(color: GoalVantageColors.border),
//       ),
//       child: Column(
//         children: items.asMap().entries.map((entry) {
//           final index = entry.key;
//           final item = entry.value;
//           final isLast = index == items.length - 1;
//           return InkWell(
//             onTap: () => onNavigate(item['page'] as Widget),
//             child: Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 border: Border(
//                   bottom: BorderSide(
//                     color: isLast ? Colors.transparent : GoalVantageColors.border,
//                   ),
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 36,
//                     height: 36,
//                     decoration: BoxDecoration(
//                       color: GoalVantageColors.primary.withOpacity(0.12),
//                       border: Border.all(color: GoalVantageColors.primary.withOpacity(0.2)),
//                     ),
//                     child: Icon(item['icon'] as IconData, size: 16, color: GoalVantageColors.primary),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           item['label'] as String,
//                           style: TextStyle(
//                             color: GoalVantageColors.foreground,
//                             fontSize: ResponsiveHelper.scaleFont(context, 13),
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           item['subtitle'] as String,
//                           style: TextStyle(
//                             color: GoalVantageColors.foregroundSecondary,
//                             fontSize: ResponsiveHelper.scaleFont(context, 10),
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Icon(LucideIcons.chevronRight, size: 14, color: GoalVantageColors.foregroundSecondary),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildMenuItem(
//       Map<String, dynamic> item,
//       void Function(Widget) onNavigate,
//       BuildContext context,
//       ) {
//     return InkWell(
//       onTap: () => onNavigate(item['page'] as Widget),
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: GoalVantageColors.card,
//           border: Border.all(color: GoalVantageColors.border),
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(
//                 color: GoalVantageColors.primary.withOpacity(0.12),
//                 border: Border.all(color: GoalVantageColors.primary.withOpacity(0.2)),
//               ),
//               child: Icon(item['icon'] as IconData, size: 16, color: GoalVantageColors.primary),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     item['label'] as String,
//                     style: TextStyle(
//                       color: GoalVantageColors.foreground,
//                       fontSize: ResponsiveHelper.scaleFont(context, 13),
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                   Text(
//                     item['subtitle'] as String,
//                     style: TextStyle(
//                       color: GoalVantageColors.foregroundSecondary,
//                       fontSize: ResponsiveHelper.scaleFont(context, 10),
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(LucideIcons.chevronRight, size: 14, color: GoalVantageColors.foregroundSecondary),
//           ],
//         ),
//       ),
//     );
//   }

//   // ---------------------- Sign Out ----------------------
//   Widget _buildSignOut(BuildContext context, {required VoidCallback onSignOut}) {
//     return Column(
//       children: [
//         SizedBox(
//           width: double.infinity,
//           height: ResponsiveHelper.scaleFont(context, 48),
//           child: OutlinedButton(
//             onPressed: onSignOut,
//             style: OutlinedButton.styleFrom(
//               foregroundColor: GoalVantageColors.negative,
//               side: BorderSide(color: GoalVantageColors.negative.withOpacity(0.5)),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(LucideIcons.logOut, size: ResponsiveHelper.scaleFont(context, 14)),
//                 const SizedBox(width: 8),
//                 Text(
//                   'SIGN OUT',
//                   style: TextStyle(
//                     fontSize: ResponsiveHelper.scaleFont(context, 11),
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: 1.2,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 16),
//         Text(
//           'GoalVantage v1.0.0 · © 2026',
//           style: TextStyle(
//             color: GoalVantageColors.foregroundSecondary,
//             fontSize: ResponsiveHelper.scaleFont(context, 9),
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ========================================================================
// //  FULLY FUNCTIONAL SUB‑PAGES
// // ========================================================================

// // ------------------------------------------------------------------------
// // 1. NOTIFICATION SETTINGS – reads/writes to Firestore
// // ------------------------------------------------------------------------
// class _NotificationSettingsPage extends StatefulWidget {
//   const _NotificationSettingsPage();

//   @override
//   State<_NotificationSettingsPage> createState() => _NotificationSettingsPageState();
// }

// class _NotificationSettingsPageState extends State<_NotificationSettingsPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   bool _push = false;
//   bool _email = false;
//   bool _sms = false;
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//   }

//   Future<void> _loadSettings() async {
//     final user = _auth.currentUser;
//     if (user == null) return;
//     final doc = await _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('settings')
//         .doc('notifications')
//         .get();
//     if (doc.exists) {
//       final data = doc.data()!;
//       setState(() {
//         _push = data['push'] ?? false;
//         _email = data['email'] ?? false;
//         _sms = data['sms'] ?? false;
//         _loading = false;
//       });
//     } else {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _saveSetting(String key, bool value) async {
//     final user = _auth.currentUser;
//     if (user == null) return;
//     await _firestore
//         .collection('users')
//         .doc(user.uid)
//         .collection('settings')
//         .doc('notifications')
//         .set({key: value}, SetOptions(merge: true));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: GoalVantageColors.background,
//       appBar: _buildAppBar(context, 'Notification Settings'),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : Padding(
//         padding: ResponsiveHelper.responsivePadding(context),
//         child: Column(
//           children: [
//             _buildSwitchTile(
//               icon: LucideIcons.bell,
//               title: 'Push Notifications',
//               value: _push,
//               onChanged: (v) {
//                 setState(() => _push = v);
//                 _saveSetting('push', v);
//               },
//             ),
//             _buildSwitchTile(
//               icon: LucideIcons.mail,
//               title: 'Email Alerts',
//               value: _email,
//               onChanged: (v) {
//                 setState(() => _email = v);
//                 _saveSetting('email', v);
//               },
//             ),
//             _buildSwitchTile(
//               icon: LucideIcons.smartphone,
//               title: 'SMS Alerts',
//               value: _sms,
//               onChanged: (v) {
//                 setState(() => _sms = v);
//                 _saveSetting('sms', v);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSwitchTile({
//     required IconData icon,
//     required String title,
//     required bool value,
//     required ValueChanged<bool> onChanged,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(color: GoalVantageColors.border),
//       ),
//       child: Row(
//         children: [
//           Icon(icon, size: 24, color: GoalVantageColors.primary),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Text(
//               title,
//               style: TextStyle(
//                 color: GoalVantageColors.foreground,
//                 fontSize: ResponsiveHelper.scaleFont(context, 16),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//           Switch(
//             value: value,
//             onChanged: onChanged,
//             activeColor: GoalVantageColors.positive,
//             inactiveThumbColor: GoalVantageColors.foregroundSecondary,
//           ),
//         ],
//       ),
//     );
//   }

//   AppBar _buildAppBar(BuildContext context, String title) {
//     return AppBar(
//       leading: IconButton(
//         icon: Icon(LucideIcons.arrowLeft, color: GoalVantageColors.foreground),
//         onPressed: () => Navigator.pop(context),
//       ),
//       title: Text(
//         title,
//         style: TextStyle(
//           color: GoalVantageColors.foreground,
//           fontSize: ResponsiveHelper.scaleFont(context, 18),
//           fontWeight: FontWeight.w900,
//         ),
//       ),
//       backgroundColor: GoalVantageColors.background,
//       elevation: 0,
//     );
//   }
// }

// // ------------------------------------------------------------------------
// // 2. PAYMENT HISTORY – streams payments from Firestore
// // ------------------------------------------------------------------------
// class _PaymentHistoryPage extends StatelessWidget {
//   const _PaymentHistoryPage();

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       return Scaffold(
//         backgroundColor: GoalVantageColors.background,
//         appBar: _buildAppBar(context, 'Payment History'),
//         body: const Center(child: Text('Please sign in.')),
//       );
//     }

//     return Scaffold(
//       backgroundColor: GoalVantageColors.background,
//       appBar: _buildAppBar(context, 'Payment History'),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .collection('payments')
//             .orderBy('createdAt', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(
//               child: Text(
//                 'Error: ${snapshot.error}',
//                 style: TextStyle(color: GoalVantageColors.negative),
//               ),
//             );
//           }
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           final docs = snapshot.data?.docs ?? [];
//           if (docs.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(LucideIcons.wallet, size: 64, color: GoalVantageColors.foregroundSecondary),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No payments yet',
//                     style: TextStyle(
//                       color: GoalVantageColors.foreground,
//                       fontSize: ResponsiveHelper.scaleFont(context, 20),
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }
//           return ListView.builder(
//             padding: ResponsiveHelper.responsivePadding(context),
//             itemCount: docs.length,
//             itemBuilder: (context, index) {
//               final data = docs[index].data() as Map<String, dynamic>;
//               final amount = data['paidAmount'] ?? 0.0;
//               final currency = data['paidCurrency'] ?? 'UGX';
//               final status = data['status'] ?? 'unknown';
//               final createdAt = data['createdAt'] as Timestamp?;
//               final date = createdAt != null ? createdAt.toDate() : DateTime.now();

//               return Container(
//                 margin: const EdgeInsets.only(bottom: 12),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: GoalVantageColors.card,
//                   border: Border.all(color: GoalVantageColors.border),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       status == 'successful' ? LucideIcons.checkCircle : LucideIcons.xCircle,
//                       color: status == 'successful' ? GoalVantageColors.positive : GoalVantageColors.negative,
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             '${amount.toStringAsFixed(0)} $currency',
//                             style: TextStyle(
//                               color: GoalVantageColors.foreground,
//                               fontSize: ResponsiveHelper.scaleFont(context, 16),
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                           Text(
//                             DateFormat('MMM d, yyyy · HH:mm').format(date),
//                             style: TextStyle(
//                               color: GoalVantageColors.foregroundSecondary,
//                               fontSize: ResponsiveHelper.scaleFont(context, 12),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: status == 'successful'
//                             ? GoalVantageColors.positive.withOpacity(0.15)
//                             : GoalVantageColors.negative.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Text(
//                         status.toUpperCase(),
//                         style: TextStyle(
//                           color: status == 'successful'
//                               ? GoalVantageColors.positive
//                               : GoalVantageColors.negative,
//                           fontSize: ResponsiveHelper.scaleFont(context, 10),
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   AppBar _buildAppBar(BuildContext context, String title) {
//     return AppBar(
//       leading: IconButton(
//         icon: Icon(LucideIcons.arrowLeft, color: GoalVantageColors.foreground),
//         onPressed: () => Navigator.pop(context),
//       ),
//       title: Text(
//         title,
//         style: TextStyle(
//           color: GoalVantageColors.foreground,
//           fontSize: ResponsiveHelper.scaleFont(context, 18),
//           fontWeight: FontWeight.w900,
//         ),
//       ),
//       backgroundColor: GoalVantageColors.background,
//       elevation: 0,
//     );
//   }
// }

// // ------------------------------------------------------------------------
// // 3. SECURITY – change password with current password dialog
// // ------------------------------------------------------------------------
// class _SecurityPage extends StatefulWidget {
//   const _SecurityPage();

//   @override
//   State<_SecurityPage> createState() => _SecurityPageState();
// }

// class _SecurityPageState extends State<_SecurityPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   bool _isLoading = false;

//   void _showChangePasswordDialog() {
//     final currentPasswordController = TextEditingController();
//     final newPasswordController = TextEditingController();
//     final confirmController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(
//           'Change Password',
//           style: TextStyle(
//             color: GoalVantageColors.foreground,
//             fontSize: ResponsiveHelper.scaleFont(context, 18),
//             fontWeight: FontWeight.w900,
//           ),
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: currentPasswordController,
//               obscureText: true,
//               decoration: const InputDecoration(
//                 labelText: 'Current Password',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: newPasswordController,
//               obscureText: true,
//               decoration: const InputDecoration(
//                 labelText: 'New Password',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: confirmController,
//               obscureText: true,
//               decoration: const InputDecoration(
//                 labelText: 'Confirm New Password',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'Cancel',
//               style: TextStyle(color: GoalVantageColors.foregroundSecondary),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: _isLoading
//                 ? null
//                 : () async {
//               final current = currentPasswordController.text.trim();
//               final newPass = newPasswordController.text.trim();
//               final confirm = confirmController.text.trim();
//               if (newPass != confirm) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Passwords do not match')),
//                 );
//                 return;
//               }
//               if (newPass.length < 6) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Password must be at least 6 characters')),
//                 );
//                 return;
//               }
//               setState(() => _isLoading = true);
//               try {
//                 final user = _auth.currentUser;
//                 if (user == null) throw Exception('Not signed in');
//                 final cred = EmailAuthProvider.credential(
//                   email: user.email!,
//                   password: current,
//                 );
//                 await user.reauthenticateWithCredential(cred);
//                 await user.updatePassword(newPass);
//                 if (context.mounted) {
//                   Navigator.pop(context);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Password updated successfully')),
//                   );
//                 }
//               } catch (e) {
//                 if (context.mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Error: $e')),
//                   );
//                 }
//               } finally {
//                 if (mounted) setState(() => _isLoading = false);
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: GoalVantageColors.primary,
//               foregroundColor: GoalVantageColors.primaryForeground,
//             ),
//             child: _isLoading
//                 ? const SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//                 : const Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: GoalVantageColors.background,
//       appBar: AppBar(
//         leading: IconButton(
//           icon: Icon(LucideIcons.arrowLeft, color: GoalVantageColors.foreground),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           'Security',
//           style: TextStyle(
//             color: GoalVantageColors.foreground,
//             fontSize: ResponsiveHelper.scaleFont(context, 18),
//             fontWeight: FontWeight.w900,
//           ),
//         ),
//         backgroundColor: GoalVantageColors.background,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: ResponsiveHelper.responsivePadding(context),
//         child: Column(
//           children: [
//             _buildSecurityTile(
//               icon: LucideIcons.lock,
//               title: 'Change Password',
//               subtitle: 'Update your account password',
//               onTap: _showChangePasswordDialog,
//             ),
//             _buildSecurityTile(
//               icon: LucideIcons.shield,
//               title: 'Two‑Factor Authentication',
//               subtitle: 'Coming soon',
//               onTap: () {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('2FA will be available soon.')),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSecurityTile({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required VoidCallback onTap,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(color: GoalVantageColors.border),
//       ),
//       child: InkWell(
//         onTap: onTap,
//         child: Row(
//           children: [
//             Icon(icon, size: 24, color: GoalVantageColors.primary),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: TextStyle(
//                       color: GoalVantageColors.foreground,
//                       fontSize: ResponsiveHelper.scaleFont(context, 16),
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                   Text(
//                     subtitle,
//                     style: TextStyle(
//                       color: GoalVantageColors.foregroundSecondary,
//                       fontSize: ResponsiveHelper.scaleFont(context, 12),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(LucideIcons.chevronRight, size: 20, color: GoalVantageColors.foregroundSecondary),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ------------------------------------------------------------------------
// // 4. HELP CENTER – expandable FAQ list (static for demo)
// // ------------------------------------------------------------------------
// class _HelpCenterPage extends StatelessWidget {
//   const _HelpCenterPage();

//   final List<Map<String, String>> _faqs = const [
//     {'q': 'What is GoalVantage?', 'a': 'GoalVantage is an AI‑powered football prediction platform.'},
//     {'q': 'How do I get premium?', 'a': 'Tap the "Upgrade" button in your profile.'},
//     {'q': 'How are predictions made?', 'a': 'We use machine learning models trained on historical data.'},
//     {'q': 'Can I cancel anytime?', 'a': 'Yes, you can cancel your subscription at any time via your device settings.'},
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: GoalVantageColors.background,
//       appBar: AppBar(
//         leading: IconButton(
//           icon: Icon(LucideIcons.arrowLeft, color: GoalVantageColors.foreground),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           'Help Center',
//           style: TextStyle(
//             color: GoalVantageColors.foreground,
//             fontSize: ResponsiveHelper.scaleFont(context, 18),
//             fontWeight: FontWeight.w900,
//           ),
//         ),
//         backgroundColor: GoalVantageColors.background,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: ResponsiveHelper.responsivePadding(context),
//         child: ListView.builder(
//           itemCount: _faqs.length,
//           itemBuilder: (context, index) {
//             final item = _faqs[index];
//             return Card(
//               color: GoalVantageColors.card,
//               margin: const EdgeInsets.only(bottom: 12),
//               child: ExpansionTile(
//                 title: Text(
//                   item['q']!,
//                   style: TextStyle(
//                     color: GoalVantageColors.foreground,
//                     fontWeight: FontWeight.w700,
//                     fontSize: ResponsiveHelper.scaleFont(context, 15),
//                   ),
//                 ),
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Text(
//                       item['a']!,
//                       style: TextStyle(
//                         color: GoalVantageColors.foregroundSecondary,
//                         fontSize: ResponsiveHelper.scaleFont(context, 14),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// // ------------------------------------------------------------------------
// // 5. TERMS & PRIVACY – loads from Firestore document
// // ------------------------------------------------------------------------
// class _TermsPrivacyPage extends StatelessWidget {
//   const _TermsPrivacyPage();

//   static const String _legalText = '''
// GOALVANTAGE – TERMS OF SERVICE & PRIVACY POLICY

// Last updated: 21 August 2026

// 1. INTRODUCTION
// Welcome to GoalVantage ("we", "us", "our"). By using our mobile application ("App") and services, you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree, please do not use the App.

// 2. ACCEPTANCE OF TERMS
// By creating an account or using the App, you confirm that you are at least 18 years old and have the legal capacity to enter into this agreement. You are responsible for all activity under your account.

// 3. USER ACCOUNTS
// - You must provide accurate and complete information when registering.
// - You are solely responsible for maintaining the confidentiality of your login credentials.
// - You must notify us immediately of any unauthorised use of your account.
// - We reserve the right to suspend or terminate accounts that violate these terms.

// 4. SUBSCRIPTIONS & PAYMENTS
// - GoalVantage offers a free tier and a premium subscription ("Premium").
// - Premium is billed monthly via the Apple App Store or Google Play Store.
// - Subscription fees are non-refundable except as required by law.
// - You may cancel your subscription at any time through your device's App Store or Play Store settings; cancellation takes effect at the end of the current billing period.
// - We reserve the right to change subscription prices with 30 days' notice.

// 5. PREDICTIONS & CONTENT
// - All predictions, analysis, statistics, and other content are generated by artificial intelligence and are for informational and entertainment purposes only.
// - We do not guarantee the accuracy, completeness, or reliability of any prediction.
// - You acknowledge that betting or making financial decisions based on our content is entirely at your own risk.
// - We are not a licensed financial or gambling advisor; we do not provide financial advice.

// 6. USER CONDUCT
// You agree NOT to:
// - Use the App for any unlawful purpose.
// - Reverse engineer, copy, or distribute any part of the App.
// - Interfere with the security or performance of the App.
// - Harass, abuse, or impersonate others.
// - Post or transmit any malicious code or content.

// 7. INTELLECTUAL PROPERTY
// - All content, logos, trademarks, and software are the exclusive property of GoalVantage or its licensors.
// - You may not reproduce, modify, or create derivative works without our prior written consent.
// - You grant us a non‑exclusive, royalty‑free licence to use, store, and display any content you submit (e.g., feedback, reviews) for the purpose of improving the App.

// 8. DISCLAIMERS
// - THE APP AND ALL CONTENT ARE PROVIDED "AS IS" AND "AS AVAILABLE".
// - WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON‑INFRINGEMENT.
// - WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR‑FREE, OR SECURE.

// 9. LIMITATION OF LIABILITY
// - TO THE MAXIMUM EXTENT PERMITTED BY LAW, GOALVANTAGE AND ITS AFFILIATES SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF PROFITS, DATA, OR USE, ARISING FROM YOUR USE OF THE APP.
// - OUR TOTAL LIABILITY TO YOU SHALL NOT EXCEED THE AMOUNT YOU PAID FOR YOUR PREMIUM SUBSCRIPTION IN THE PAST 12 MONTHS.

// 10. PRIVACY POLICY
// We take your privacy seriously. This section explains how we collect, use, and protect your personal information.

//     10.1 WHAT WE COLLECT
//     - Account information: name, email address, and profile picture (if you provide one).
//     - Payment information: processed securely by the Apple App Store or Google Play Store; we do not store full card details.
//     - Usage data: how you interact with the App, which predictions you view, and device information (OS, device ID, IP address).
//     - Location data: only if you grant permission; used to show relevant leagues.

//     10.2 HOW WE USE YOUR DATA
//     - To provide, maintain, and improve the App.
//     - To process transactions and send you confirmations.
//     - To send you important updates, security alerts, and promotional materials (you may opt out).
//     - To analyse trends and user behaviour to enhance our AI models.

//     10.3 DATA SHARING
//     - We do not sell or rent your personal data to third parties.
//     - We share data with:
//         - Service providers (e.g., Apple App Store / Google Play Store for payments, Firebase for hosting) under strict confidentiality.
//         - Law enforcement if required by law or to protect our rights.
//     - Aggregated, anonymised data may be used for research or marketing.

//     10.4 DATA RETENTION
//     We retain your data as long as your account is active or as needed to provide services. You may request deletion at any time.

//     10.5 SECURITY
//     We implement industry‑standard security measures (encryption, access controls) to protect your data. However, no method of transmission over the internet is 100% secure.

//     10.6 YOUR RIGHTS
//     - Access, correct, or delete your personal data.
//     - Withdraw consent for marketing communications.
//     - Request a copy of your data in a portable format.
//     To exercise these rights, contact us at support@goalvantage.com.

//     10.7 COOKIES & TRACKING
//     We use Firebase Analytics and similar technologies to collect usage data. You can disable tracking in your device settings.

// 11. GOVERNING LAW
// These Terms and your use of the App shall be governed by the laws of Uganda, without regard to its conflict of laws provisions. Any disputes shall be resolved in the competent courts of Kampala.

// 12. CHANGES TO TERMS
// We may update these Terms from time to time. We will notify you via email or an in‑app notice. Your continued use after changes constitutes acceptance.

// 13. CONTACT
// If you have questions or concerns, please contact us at:
// - Email: support@goalvantage.com
// - Address: [Your physical address, optional]

// BY USING GOALVANTAGE, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS AND OUR PRIVACY POLICY.
// ''';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: GoalVantageColors.background,
//       appBar: AppBar(
//         leading: IconButton(
//           icon: Icon(LucideIcons.arrowLeft, color: GoalVantageColors.foreground),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           'Terms & Privacy',
//           style: TextStyle(
//             color: GoalVantageColors.foreground,
//             fontSize: ResponsiveHelper.scaleFont(context, 18),
//             fontWeight: FontWeight.w900,
//           ),
//         ),
//         backgroundColor: GoalVantageColors.background,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: ResponsiveHelper.responsivePadding(context),
//         child: SingleChildScrollView(
//           child: SelectableText(
//             _legalText,
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: ResponsiveHelper.scaleFont(context, 14),
//               height: 1.6,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ----------------------------------------------------------------------------
// //  PREMIUM UPGRADE SHEET – Native In-App Purchase (Apple/Google Pay)
// // ----------------------------------------------------------------------------

// class _PremiumUpgradeSheet extends StatefulWidget {
//   const _PremiumUpgradeSheet();

//   @override
//   State<_PremiumUpgradeSheet> createState() => _PremiumUpgradeSheetState();
// }

// class _PremiumUpgradeSheetState extends State<_PremiumUpgradeSheet> {
//   final InAppPurchase _inAppPurchase = InAppPurchase.instance;
//   late StreamSubscription<List<PurchaseDetails>> _subscription;

//   List<ProductDetails> _products = [];
//   bool _isAvailable = false;
//   bool _isProcessing = false;
//   bool _isInitialized = false;

//   // TODO: Replace with your actual product ID configured in App Store Connect & Google Play Console
//   static const String _productId = 'premium_monthly';

//   @override
//   void initState() {
//     super.initState();
//     _initializeInAppPurchase();
//   }

//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }

//   Future<void> _initializeInAppPurchase() async {
//     _isAvailable = await _inAppPurchase.isAvailable();
//     if (!_isAvailable) {
//       if (mounted) _showSnack('In-app purchases are not available on this device.');
//       return;
//     }

//     final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_productId});

//     if (response.notFoundIDs.isNotEmpty) {
//       if (mounted) _showSnack('Product ID not found. Check App Store / Play Console configuration.');
//       return;
//     }

//     setState(() {
//       _products = response.productDetails;
//       _isInitialized = true;
//     });

//     _subscription = _inAppPurchase.purchaseStream.listen(
//       _listenToPurchaseUpdated,
//       onDone: () => _subscription.cancel(),
//       onError: (error) {
//         if (mounted) _showSnack('Purchase error: $error');
//       },
//     );
//   }

//   Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
//     for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
//       if (purchaseDetails.status == PurchaseStatus.pending) {
//         if (mounted) setState(() => _isProcessing = true);
//       } else {
//         if (purchaseDetails.status == PurchaseStatus.error) {
//           if (mounted) {
//             _showSnack('Purchase failed: ${purchaseDetails.error?.message ?? "Unknown error"}');
//             setState(() => _isProcessing = false);
//           }
//         } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
//           await _activateSubscription(purchaseDetails);
//         }

//         if (purchaseDetails.pendingCompletePurchase) {
//           await _inAppPurchase.completePurchase(purchaseDetails);
//         }

//         if (mounted) setState(() => _isProcessing = false);
//       }
//     }
//   }

//   Future<void> _activateSubscription(PurchaseDetails purchaseDetails) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     final db = FirebaseFirestore.instance;
//     final subscriptionRef = db.collection('users').doc(user.uid).collection('subscriptions').doc('premium');
//     final paymentRef = db.collection('users').doc(user.uid).collection('payments').doc(purchaseDetails.purchaseID ?? 'unknown_tx');

//     final now = DateTime.now();
//     final endDate = now.add(const Duration(days: 30));
//     final serverNow = FieldValue.serverTimestamp();

//     final provider = defaultTargetPlatform == TargetPlatform.iOS ? 'apple_app_store' : 'google_play_store';

//     final subscriptionPayload = {
//       'category': 'premium',
//       'status': 'active',
//       'startDate': Timestamp.fromDate(now),
//       'endDate': Timestamp.fromDate(endDate),
//       'periodDays': 30,
//       'periodLabel': '1 month',
//       'provider': provider,
//       'transactionId': purchaseDetails.purchaseID,
//       'updatedAt': serverNow,
//     };

//     final paymentPayload = {
//       'category': 'premium',
//       'provider': provider,
//       'status': 'successful',
//       'transactionId': purchaseDetails.purchaseID,
//       'createdAt': serverNow,
//       'updatedAt': serverNow,
//     };

//     try {
//       final batch = db.batch();
//       batch.set(subscriptionRef, subscriptionPayload, SetOptions(merge: true));
//       batch.set(paymentRef, paymentPayload);
//       await batch.commit();

//       if (mounted) {
//         await _showPaymentDialog(
//           title: 'Subscription activated',
//           message: 'Your GoalVantage Premium access is active for 1 month.',
//           icon: Icons.check_circle_outline_rounded,
//           color: GoalVantageColors.positive,
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         _showSnack('Failed to activate subscription: $e');
//       }
//     }
//   }

//   void _handleSubscribe() {
//     if (!_isInitialized || _products.isEmpty) {
//       _showSnack('Products not loaded yet. Please try again.');
//       return;
//     }

//     final ProductDetails product = _products.first;
//     final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

//     _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
//   }

//   void _showSnack(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
//     );
//   }

//   Future<void> _showPaymentDialog({
//     required String title,
//     required String message,
//     required IconData icon,
//     required Color color,
//   }) {
//     return showDialog<void>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(icon, color: color, size: 24),
//             const SizedBox(width: 12),
//             Expanded(child: Text(title)),
//           ],
//         ),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final displayPrice = '20';
//     final displayCurrency = 'USD';
//     final platformName = defaultTargetPlatform == TargetPlatform.iOS ? 'APPLE' : 'GOOGLE';

//     return Container(
//       padding: EdgeInsets.all(ResponsiveHelper.scaleFont(context, 24)),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.backgroundSecondary,
//         border: Border(top: BorderSide(color: GoalVantageColors.gold, width: 2)),
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Center(
//             child: Container(
//               width: 40,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: GoalVantageColors.border,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//           ),
//           const SizedBox(height: 24),
//           Row(
//             children: [
//               Icon(LucideIcons.crown, size: ResponsiveHelper.scaleFont(context, 20), color: GoalVantageColors.gold),
//               const SizedBox(width: 8),
//               Text(
//                 'GOALVANTAGE PREMIUM',
//                 style: TextStyle(
//                   color: GoalVantageColors.gold,
//                   fontSize: ResponsiveHelper.scaleFont(context, 11),
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Unlock every prediction.',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: ResponsiveHelper.scaleFont(context, 24),
//               fontWeight: FontWeight.w900,
//               letterSpacing: -0.8,
//             ),
//           ),
//           const SizedBox(height: 20),
//           Container(
//             padding: EdgeInsets.all(ResponsiveHelper.scaleFont(context, 16)),
//             decoration: BoxDecoration(
//               color: GoalVantageColors.card,
//               border: Border.all(color: GoalVantageColors.gold, width: 1.5),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'MONTHLY PLAN',
//                         style: TextStyle(
//                           color: GoalVantageColors.foregroundSecondary,
//                           fontSize: ResponsiveHelper.scaleFont(context, 9),
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: 1.2,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Row(
//                         crossAxisAlignment: CrossAxisAlignment.baseline,
//                         textBaseline: TextBaseline.alphabetic,
//                         children: [
//                           Text(
//                             '$displayCurrency $displayPrice',
//                             style: TextStyle(
//                               color: GoalVantageColors.foreground,
//                               fontSize: ResponsiveHelper.scaleFont(context, 32),
//                               fontWeight: FontWeight.w900,
//                               letterSpacing: -1.0,
//                             ),
//                           ),
//                           const SizedBox(width: 4),
//                           Text(
//                             '/month',
//                             style: TextStyle(
//                               color: GoalVantageColors.foregroundSecondary,
//                               fontSize: ResponsiveHelper.scaleFont(context, 12),
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 // 7-DAY TRIAL BADGE REMOVED HERE
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           ...[
//             'All premium AI predictions (80%+ confidence)',
//             'Detailed match analysis & xG stats',
//             'Injury & suspension alerts',
//             'Exclusive tipster picks',
//             'Cancel anytime via App Store / Play Store',
//           ].map((b) => Padding(
//             padding: const EdgeInsets.only(bottom: 8),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Icon(LucideIcons.check, size: ResponsiveHelper.scaleFont(context, 14), color: GoalVantageColors.gold),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     b,
//                     style: TextStyle(
//                       color: GoalVantageColors.foreground,
//                       fontSize: ResponsiveHelper.scaleFont(context, 13),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           )),
//           const SizedBox(height: 24),
//           SizedBox(
//             width: double.infinity,
//             height: ResponsiveHelper.scaleFont(context, 52),
//             child: ElevatedButton(
//               onPressed: _isProcessing || !_isInitialized ? null : _handleSubscribe,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: GoalVantageColors.gold,
//                 foregroundColor: GoalVantageColors.background,
//                 elevation: 0,
//                 disabledBackgroundColor: GoalVantageColors.gold.withOpacity(0.5),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//               child: _isProcessing
//                   ? const SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation(Colors.black),
//                 ),
//               )
//                   : Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     defaultTargetPlatform == TargetPlatform.iOS ? LucideIcons.apple : LucideIcons.smartphone,
//                     size: ResponsiveHelper.scaleFont(context, 16),
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     'SUBSCRIBE WITH $platformName PAY',
//                     style: TextStyle(
//                       fontSize: ResponsiveHelper.scaleFont(context, 13),
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           Center(
//             child: Text(
//               'Secured by ${platformName == 'APPLE' ? 'App Store' : 'Google Play'} · Cancel anytime · No hidden fees',
//               style: TextStyle(
//                 color: GoalVantageColors.foregroundSecondary,
//                 fontSize: ResponsiveHelper.scaleFont(context, 10),
//                 fontWeight: FontWeight.w500,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
//         ],
//       ),
//     );
//   }
// }

// // ----------------------------------------------------------------------------
// //  SUBSCRIPTION SERVICE – INLINE
// // ----------------------------------------------------------------------------

// class _SubscriptionService {
//   static final _SubscriptionService instance = _SubscriptionService._internal();
//   _SubscriptionService._internal();

//   Stream<PremiumSubscription?> watchSubscription() {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return Stream.value(null);
//     return FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .collection('subscriptions')
//         .doc('premium')
//         .snapshots()
//         .map((doc) {
//       if (!doc.exists) return null;
//       return PremiumSubscription.fromMap(doc.data()!);
//     });
//   }
// }







