import 'dart:io';
import 'package:aura_trades/screens/pitchiq_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../services/subscription_service.dart';
import '../services/revenue_cat_service.dart';
import '../models/premium_subscription.dart';
import '../theme/colors.dart';
import 'tabs/odds_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/performance_tab.dart';
import 'tabs/profile_tab.dart';

class GoalVantageHomeScreen extends StatefulWidget {
  const GoalVantageHomeScreen({super.key});

  @override
  State<GoalVantageHomeScreen> createState() => _GoalVantageHomeScreenState();
}

class _GoalVantageHomeScreenState extends State<GoalVantageHomeScreen> {
  int _currentTab = 0;
  PremiumSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Load subscription once on startup (Android only; iOS uses RevenueCat)
    if (!Platform.isIOS) {
      SubscriptionService.instance.checkExpiry();
    }
  }

  final List<Widget> _tabs = const [
    OddsTab(),
    HistoryTab(),
    PerformanceTab(),
    ProfileTab(),
  ];

  final List<Map<String, dynamic>> _tabConfig = [
    {'icon': LucideIcons.target, 'activeIcon': LucideIcons.target, 'label': 'ODDS'},
    {'icon': LucideIcons.history, 'activeIcon': LucideIcons.history, 'label': 'HISTORY'},
    {'icon': LucideIcons.barChart3, 'activeIcon': LucideIcons.barChart3, 'label': 'PERFORMANCE'},
    {'icon': LucideIcons.user, 'activeIcon': LucideIcons.user, 'label': 'PROFILE'},
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PremiumSubscription?>(
      stream: SubscriptionService.instance.watchSubscription(),
      builder: (context, snapshot) {
        _subscription = snapshot.data;
        var isPremium = _subscription?.isActive == true;
        if (Platform.isIOS && RevenueCatService.instance.isVip) {
          isPremium = true;
        }

        return Scaffold(
          backgroundColor: GoalVantageColors.background,
          body: SafeArea(
            child: IndexedStack(
              index: _currentTab,
              children: _tabs,
            ),
          ),
          bottomNavigationBar: _buildBottomNav(isPremium),
        );
      },
    );
  }

  // ==========================================================================
  // BOTTOM NAVIGATION — Sharp editorial style
  // ==========================================================================

  Widget _buildBottomNav(bool isPremium) {
    return Container(
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(top: BorderSide(color: GoalVantageColors.border, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabConfig.length, (index) {
              final isActive = _currentTab == index;
              final config = _tabConfig[index];

              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentTab = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive
                          ? GoalVantageColors.primary.withOpacity(0.08)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: isActive ? GoalVantageColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isActive ? config['activeIcon'] : config['icon'],
                              size: 20,
                              color: isActive
                                  ? GoalVantageColors.primary
                                  : GoalVantageColors.foregroundSecondary,
                            ),
                            // Premium dot on Odds tab
                            if (index == 0 && isPremium)
                              Positioned(
                                top: -2,
                                right: -4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: GoalVantageColors.gold,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: GoalVantageColors.backgroundSecondary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config['label'] as String,
                          style: TextStyle(
                            color: isActive
                                ? GoalVantageColors.primary
                                : GoalVantageColors.foregroundSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}