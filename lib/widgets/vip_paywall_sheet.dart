import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/revenue_cat_service.dart';

/// ============================================================================
/// VIP PAYWALL BOTTOM SHEET (Apple StoreKit Compliant)
/// ============================================================================
/// Complies with Apple App Store Review Guidelines:
/// - Guideline 3.1.1 (In-App Purchase): Native subscription flow.
/// - Guideline 3.1.2 (Subscribed Services): Clear auto-renew disclosures.
/// - Apple Mandatory Restore Purchases button.
/// - Clickable EULA (Terms of Use) and Privacy Policy.
/// - Entertainment disclaimer for sports prediction apps.
/// ============================================================================
class VipPaywallSheet extends StatefulWidget {
  const VipPaywallSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const VipPaywallSheet(),
    );
  }

  @override
  State<VipPaywallSheet> createState() => _VipPaywallSheetState();
}

class _VipPaywallSheetState extends State<VipPaywallSheet> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Package? _monthlyPackage;

  // Apple standard EULA URL
  static const String _appleEulaUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final offerings = await RevenueCatService.instance.getOfferings();
      if (offerings != null && offerings.current != null) {
        // Look for monthly package or the first package
        _monthlyPackage = offerings.current!.monthly ??
            offerings.current!.availablePackages.firstOrNull;
      }
    } catch (e) {
      debugPrint('Paywall fetch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing) return;

    if (_monthlyPackage == null) {
      _showSnackbar('Subscription package is currently initializing. Please try again in a moment.');
      return;
    }

    setState(() => _isProcessing = true);

    final result = await RevenueCatService.instance.purchasePackage(_monthlyPackage!);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.isSuccess) {
      _showSnackbar('Welcome to VIP! All premium predictions are now unlocked.', isSuccess: true);
      Navigator.pop(context, true);
    } else if (!result.isCancelled) {
      _showSnackbar(result.errorMessage ?? 'Purchase could not be completed. Please try again.');
    }
  }

  Future<void> _handleRestore() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final result = await RevenueCatService.instance.restorePurchases();

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.hasActiveSubscription) {
      _showSnackbar(result.message ?? 'Subscription restored successfully!', isSuccess: true);
      Navigator.pop(context, true);
    } else {
      _showSnackbar(result.message ?? 'No active subscription found to restore.');
    }
  }

  void _showSnackbar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTermsDialog() async {
    try {
      final termsContent = await rootBundle.loadString('assets/legal/terms.txt');
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131826),
          title: const Text(
            'Terms of Service & Privacy Policy',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Text(
                termsContent,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Color(0xFF3B82F6))),
            ),
          ],
        ),
      );
    } catch (e) {
      _launchUrl(_appleEulaUrl);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceString = _monthlyPackage?.storeProduct.priceString ?? '\$24.99';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Title & Restore Purchases Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.crown, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'VIP Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              // Apple Mandatory Restore Button
              TextButton(
                onPressed: _isProcessing ? null : _handleRestore,
                child: const Text(
                  'Restore',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Benefits List
          _buildBenefitItem(LucideIcons.checkCircle2, 'High-Confidence Daily VIP Predictions'),
          _buildBenefitItem(LucideIcons.trendingUp, 'Real-Time Odds Intelligence & Alerts'),
          _buildBenefitItem(LucideIcons.bot, 'Full AI Predictive Algorithm Analytics'),
          _buildBenefitItem(LucideIcons.shieldCheck, 'Access to All European & Worldwide Leagues'),

          const SizedBox(height: 20),

          // Subscription Price Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly VIP Pass',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Auto-renews monthly. Cancel anytime.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                      )
                    : Text(
                        '$priceString / mo',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Subscribe Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Unlock VIP for $priceString / month',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Apple Mandatory Disclosures (Auto-Renewal terms)
          const Text(
            'Payment will be charged to your Apple ID account upon purchase confirmation. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple ID account settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          // Mandatory Sports Prediction Disclaimer
          const Text(
            'Disclaimer: All predictions, analysis, and statistics are for informational and entertainment purposes only. We do not provide financial advice or guarantee outcomes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Clickable Links for Terms of Use (EULA) and Privacy Policy
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _openTermsDialog,
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Text('  •  ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              GestureDetector(
                onTap: () => _launchUrl(_appleEulaUrl),
                child: const Text(
                  'Standard EULA',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Text('  •  ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              GestureDetector(
                onTap: _openTermsDialog,
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
