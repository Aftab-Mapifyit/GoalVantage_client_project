import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/revenue_cat_service.dart';
import '../widgets/vip_paywall_sheet.dart';
import 'login_screen.dart';

// ============================================================================
// MODELS
// ============================================================================

class UserSettings {
  final String oddsFormat; // 'american', 'decimal', 'fractional'
  final String subscriptionTier; // 'free', 'premium'
  final String? subscriptionExpiry; // e.g., '2026-12-31'
  final String preferredLeagues; // 'all', 'premier_league', 'la_liga', etc.
  final bool showConfidenceScores;
  final bool pushNotifications;
  final bool predictionAlerts;
  final bool emailNotifications;
  final bool promoNotifications;
  final String theme; // 'light', 'dark', 'system'
  final String language;
  final String timezone;
  final bool twoFactorEnabled;

  UserSettings.fromMap(Map<String, dynamic> map)
      : oddsFormat = map['oddsFormat'] ?? 'decimal',
        subscriptionTier = map['subscriptionTier'] ?? 'free',
        subscriptionExpiry = map['subscriptionExpiry'] as String?,
        preferredLeagues = map['preferredLeagues'] ?? 'all',
        showConfidenceScores = map['showConfidenceScores'] ?? true,
        pushNotifications = map['pushNotifications'] ?? true,
        predictionAlerts = map['predictionAlerts'] ?? true,
        emailNotifications = map['emailNotifications'] ?? true,
        promoNotifications = map['promoNotifications'] ?? true,
        theme = map['theme'] ?? 'system',
        language = map['language'] ?? 'English',
        timezone = map['timezone'] ?? 'EST',
        twoFactorEnabled = map['twoFactorEnabled'] ?? false;

  Map<String, dynamic> toMap() => {
    'oddsFormat': oddsFormat,
    'subscriptionTier': subscriptionTier,
    'subscriptionExpiry': subscriptionExpiry,
    'preferredLeagues': preferredLeagues,
    'showConfidenceScores': showConfidenceScores,
    'pushNotifications': pushNotifications,
    'predictionAlerts': predictionAlerts,
    'emailNotifications': emailNotifications,
    'promoNotifications': promoNotifications,
    'theme': theme,
    'language': language,
    'timezone': timezone,
    'twoFactorEnabled': twoFactorEnabled,
  };
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================

class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings? _settings;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _settingsSub;
  String? _uid;

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse('https://wa.me/447537175793');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp. Call +44 7537 175793 instead.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // DATA STREAMS
  // ==========================================================================

  void _loadSettings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    _uid = uid;

    _settingsSub = FirebaseFirestore.instance
        .collection('user_settings')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _settings = UserSettings.fromMap(doc.data()! as Map<String, dynamic>);
            _isLoading = false;
          });
        }
      } else {
        _createDefaultSettings(uid);
      }
    }, onError: (error) {
      debugPrint('Error loading settings: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _createDefaultSettings(String uid) {
    final defaultSettings = UserSettings.fromMap({});
    FirebaseFirestore.instance
        .collection('user_settings')
        .doc(uid)
        .set(defaultSettings.toMap(), SetOptions(merge: true));
  }

  Future<void> _updateSettings(Map<String, dynamic> updates) async {
    if (_uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('user_settings')
          .doc(_uid)
          .update(updates);

      setState(() {
        _settings = UserSettings.fromMap({
          ..._settings?.toMap() ?? {},
          ...updates,
        });
      });

      if (updates.containsKey('pushNotifications') || updates.containsKey('predictionAlerts')) {
        final pushEnabled = updates['pushNotifications'] as bool? ?? _settings?.pushNotifications ?? true;
        final alertsEnabled = updates['predictionAlerts'] as bool? ?? _settings?.predictionAlerts ?? true;
        await NotificationService.instance.setNewOddsEnabled(pushEnabled && alertsEnabled);
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
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
            ? Center(child: CircularProgressIndicator())
            : CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSubscription()),
            SliverToBoxAdapter(child: _buildPredictionPreferences()),
            SliverToBoxAdapter(child: _buildNotifications()),
            SliverToBoxAdapter(child: _buildAppearance()),
            SliverToBoxAdapter(child: _buildSecurity()),
            SliverToBoxAdapter(child: _buildLegalSupport()),
            SliverToBoxAdapter(child: _buildDangerZone()),
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
      padding: EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.settings, size: 14, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'CONFIGURATION',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'GOALVANTAGE',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 0.95,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your subscription, prediction preferences, notifications, and account security.',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUBSCRIPTION & BILLING
  // ==========================================================================

  Widget _buildSubscription() {
    final settings = _settings!;
    final isPremium = settings.subscriptionTier == 'premium';

    return _buildSection(
      icon: LucideIcons.crown,
      title: 'SUBSCRIPTION & BILLING',
      borderColor: isPremium ? AppColors.primary : AppColors.warning,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? 'PREMIUM TIER' : 'FREE TIER',
                    style: TextStyle(
                      color: isPremium ? AppColors.primary : AppColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isPremium
                        ? 'Next billing date: ${settings.subscriptionExpiry ?? 'N/A'}'
                        : 'Upgrade to unlock all premium predictions, advanced stats, and ad-free experience.',
                    style: TextStyle(
                      color: AppColors.foregroundSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              ElevatedButton(
                onPressed: _showUpgradeDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(
                  '\$25 / MONTH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: _showManageSubscriptionDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(
                  'MANAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
          ],
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final result = await RevenueCatService.instance.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message ?? 'Restore completed.'),
                      backgroundColor: result.hasActiveSubscription
                          ? AppColors.primary
                          : const Color(0xFF1E293B),
                    ),
                  );
                }
              },
              icon: Icon(LucideIcons.rotateCcw, size: 13, color: AppColors.foregroundSecondary),
              label: Text(
                'RESTORE PURCHASES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foregroundSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================================
  // PREDICTION PREFERENCES
  // ==========================================================================

  Widget _buildPredictionPreferences() {
    final settings = _settings!;

    return _buildSection(
      icon: LucideIcons.info,
      title: 'PREDICTION PREFERENCES',
      children: [
        _buildDropdownSetting(
          label: 'ODDS FORMAT',
          value: settings.oddsFormat,
          options: ['decimal', 'american', 'fractional'],
          displayNames: ['Decimal (2.50)', 'American (+150)', 'Fractional (3/2)'],
          onChanged: (value) => _updateSettings({'oddsFormat': value}),
        ),
        SizedBox(height: 16),
        _buildDropdownSetting(
          label: 'PREFERRED LEAGUES',
          value: settings.preferredLeagues,
          options: ['all', 'premier_league', 'la_liga', 'bundesliga', 'serie_a', 'champions_league'],
          displayNames: ['All Leagues', 'Premier League', 'La Liga', 'Bundesliga', 'Serie A', 'Champions League'],
          onChanged: (value) => _updateSettings({'preferredLeagues': value}),
        ),
        SizedBox(height: 16),
        _buildToggleSetting(
          label: 'SHOW CONFIDENCE SCORES',
          subtitle: 'Display AI confidence percentage on predictions',
          value: settings.showConfidenceScores,
          onChanged: (value) => _updateSettings({'showConfidenceScores': value}),
        ),
      ],
    );
  }

  // ==========================================================================
  // NOTIFICATIONS
  // ==========================================================================

  Widget _buildNotifications() {
    final settings = _settings!;

    return _buildSection(
      icon: LucideIcons.bell,
      title: 'NOTIFICATIONS',
      children: [
        _buildToggleSetting(
          label: 'PUSH NOTIFICATIONS',
          subtitle: 'Receive alerts on your device',
          value: settings.pushNotifications,
          onChanged: (value) => _updateSettings({'pushNotifications': value}),
        ),
        SizedBox(height: 16),
        _buildToggleSetting(
          label: 'PREDICTION ALERTS',
          subtitle: 'Notify when new high-confidence predictions are posted',
          value: settings.predictionAlerts,
          onChanged: (value) => _updateSettings({'predictionAlerts': value}),
        ),
        SizedBox(height: 16),
        _buildToggleSetting(
          label: 'EMAIL NOTIFICATIONS',
          subtitle: 'Weekly summaries and account updates',
          value: settings.emailNotifications,
          onChanged: (value) => _updateSettings({'emailNotifications': value}),
        ),
        SizedBox(height: 16),
        _buildToggleSetting(
          label: 'PROMOTIONS',
          subtitle: 'Special offers and premium discounts',
          value: settings.promoNotifications,
          onChanged: (value) => _updateSettings({'promoNotifications': value}),
        ),
      ],
    );
  }

  // ==========================================================================
  // APPEARANCE
  // ==========================================================================

  Widget _buildAppearance() {
    final settings = _settings!;

    return _buildSection(
      icon: LucideIcons.palette,
      title: 'APPEARANCE',
      children: [
        _buildDropdownSetting(
          label: 'THEME',
          value: settings.theme,
          options: ['light', 'dark', 'system'],
          displayNames: ['Light Mode', 'Dark Mode', 'System Default'],
          onChanged: (value) => _updateSettings({'theme': value}),
        ),
        SizedBox(height: 16),
        _buildDropdownSetting(
          label: 'LANGUAGE',
          value: settings.language,
          options: ['English', 'Spanish', 'French', 'German', 'Portuguese'],
          displayNames: ['English', 'Español', 'Français', 'Deutsch', 'Português'],
          onChanged: (value) => _updateSettings({'language': value}),
        ),
        SizedBox(height: 16),
        _buildDropdownSetting(
          label: 'TIMEZONE',
          value: settings.timezone,
          options: ['EST', 'CST', 'MST', 'PST', 'GMT', 'CET'],
          displayNames: ['Eastern (EST)', 'Central (CST)', 'Mountain (MST)', 'Pacific (PST)', 'GMT', 'Central European (CET)'],
          onChanged: (value) => _updateSettings({'timezone': value}),
        ),
      ],
    );
  }

  // ==========================================================================
  // SECURITY
  // ==========================================================================

  Widget _buildSecurity() {
    final settings = _settings!;

    return _buildSection(
      icon: LucideIcons.lock,
      title: 'SECURITY',
      children: [
        _buildToggleSetting(
          label: 'TWO-FACTOR AUTHENTICATION',
          subtitle: settings.twoFactorEnabled ? 'Enabled - Account secured' : 'Disabled - Enable for extra security',
          value: settings.twoFactorEnabled,
          onChanged: (value) => _show2FADialog(value),
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'CHANGE PASSWORD',
          subtitle: 'Update your account password',
          icon: LucideIcons.key,
          onTap: _showChangePasswordDialog,
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'LOGIN HISTORY',
          subtitle: 'View recent sign-in activity',
          icon: LucideIcons.history,
          onTap: () {},
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'ACTIVE SESSIONS',
          subtitle: 'Manage devices currently signed in',
          icon: LucideIcons.smartphone,
          onTap: () {},
        ),
      ],
    );
  }

  // ==========================================================================
  // LEGAL & SUPPORT
  // ==========================================================================

  Widget _buildLegalSupport() {
    return _buildSection(
      icon: LucideIcons.fileText,
      title: 'LEGAL & SUPPORT',
      children: [
        _buildActionSetting(
          label: 'TERMS OF SERVICE',
          subtitle: 'Read our terms and conditions',
          icon: LucideIcons.fileText,
          onTap: () {},
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'PRIVACY POLICY',
          subtitle: 'How we handle your data',
          icon: LucideIcons.shield,
          onTap: () {},
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'PREDICTION DISCLAIMER',
          subtitle: 'Predictions are for informational purposes only',
          icon: LucideIcons.info,
          onTap: () {},
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'HELP CENTER',
          subtitle: 'FAQs and support articles',
          icon: LucideIcons.helpCircle,
          onTap: () {},
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'CONTACT SUPPORT',
          subtitle: 'support@goalvantage.com',
          icon: LucideIcons.mail,
          onTap: () {},
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'WHATSAPP SUPPORT',
          subtitle: '+44 7537 175793',
          icon: LucideIcons.messageCircle,
          onTap: _openWhatsAppSupport,
        ),
        SizedBox(height: 16),
        _buildActionSetting(
          label: 'ABOUT GOALVANTAGE',
          subtitle: 'Version 1.0.0 · Football Analytics',
          icon: LucideIcons.info,
          onTap: () {},
        ),
      ],
    );
  }

  // ==========================================================================
  // DANGER ZONE
  // ==========================================================================

  Widget _buildDangerZone() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.negative.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.negative),
              SizedBox(width: 8),
              Text(
                'DANGER ZONE',
                style: TextStyle(
                  color: AppColors.negative,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _handleSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.foreground,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.logOut, size: 14),
                  SizedBox(width: 8),
                  Text(
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
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _showDeleteAccountDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.negative,
                side: BorderSide(color: AppColors.negative.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.trash2, size: 14),
                  SizedBox(width: 8),
                  Text(
                    'DELETE ACCOUNT',
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
        ],
      ),
    );
  }

  // ==========================================================================
  // FOOTER
  // ==========================================================================

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Text(
            'GoalVantage v1.0.0',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Predictions are for informational purposes only · 18+ · Please bet responsibly',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} GoalVantage. All rights reserved.',
            style: TextStyle(
              color: AppColors.foregroundSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? borderColor,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: borderColor ?? AppColors.primary),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: borderColor ?? AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: borderColor ?? AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.foregroundSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => onChanged(!value),
          child: Container(
            width: 44,
            height: 24,
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.border,
            ),
            child: AnimatedAlign(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              duration: Duration(milliseconds: 200),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? AppColors.primaryForeground : AppColors.foregroundSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSetting({
    required String label,
    required String value,
    required List<String> options,
    required List<String> displayNames,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(LucideIcons.chevronDown, size: 14, color: AppColors.foregroundSecondary),
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              dropdownColor: AppColors.backgroundSecondary,
              items: List.generate(options.length, (index) {
                return DropdownMenuItem(
                  value: options[index],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      displayNames[index],
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSetting({
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 16, color: AppColors.foregroundSecondary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.foregroundSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 14, color: AppColors.foregroundSecondary),
        ],
      ),
    );
  }

  // ==========================================================================
  // DIALOGS
  // ==========================================================================

  void _showUpgradeDialog() {
    if (Platform.isIOS) {
      VipPaywallSheet.show(context);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.primary),
        ),
        title: Row(
          children: [
            Icon(LucideIcons.crown, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'UPGRADE TO PREMIUM',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get full access to GoalVantage Premium for \$25/month.',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '• Unlimited high-confidence predictions\n• Advanced statistical models\n• Ad-free experience\n• Priority customer support',
              style: TextStyle(
                color: AppColors.foregroundSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
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
              // TODO: Integrate RevenueCat or Stripe here for actual payment processing
              Navigator.pop(dialogContext);

              // Mock upgrade for UI demonstration
              await _updateSettings({
                'subscriptionTier': 'premium',
                'subscriptionExpiry': '2026-09-25', // 1 month from current date (Aug 2026)
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text('Welcome to GoalVantage Premium!'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: Text(
              'SUBSCRIBE \$25/MO',
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

  void _showManageSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'MANAGE SUBSCRIPTION',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'To cancel or modify your Premium subscription, please visit your account settings in the App Store or Google Play Store, or contact support@goalvantage.com.',
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'CLOSE',
              style: TextStyle(
                color: AppColors.foregroundSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _show2FADialog(bool enable) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          enable ? 'ENABLE 2FA' : 'DISABLE 2FA',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          enable
              ? 'Two-factor authentication adds an extra layer of security to your GoalVantage account.'
              : 'Disabling 2FA will make your account less secure. Are you sure?',
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 13,
            height: 1.4,
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
            onPressed: () {
              _updateSettings({'twoFactorEnabled': enable});
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: enable ? AppColors.primary : AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: Text(
              enable ? 'ENABLE' : 'DISABLE',
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

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'CHANGE PASSWORD',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _passwordField('CURRENT PASSWORD', currentController),
            SizedBox(height: 12),
            _passwordField('NEW PASSWORD', newController),
            SizedBox(height: 12),
            _passwordField('CONFIRM NEW PASSWORD', confirmController),
          ],
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
              if (newController.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.negative,
                    content: Text('Password must be at least 8 characters'),
                  ),
                );
                return;
              }
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.negative,
                    content: Text('Passwords do not match'),
                  ),
                );
                return;
              }
              try {
                await FirebaseAuth.instance.currentUser?.updatePassword(newController.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('Password updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.negative,
                    content: Text('Error: $e'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: Text(
              'UPDATE',
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

  Widget _passwordField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: TextStyle(color: AppColors.foreground),
      decoration: InputDecoration(
        labelText: label,
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
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.negative),
        ),
        title: Text(
          'DELETE ACCOUNT',
          style: TextStyle(
            color: AppColors.negative,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'This action is permanent. All your data, saved predictions, and subscription history will be deleted. Are you absolutely sure?',
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 13,
            height: 1.4,
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
              Navigator.pop(dialogContext);
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                        (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.negative,
                      content: Text('Error deleting account: $e'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: Text(
              'DELETE FOREVER',
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

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
      );
    }
  }
}
