import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../utils/breakpoints.dart';
import 'responsive.dart';

// ============================================================================
// NAV ITEM DEFINITIONS — OnyxBet Sports Betting
// ============================================================================

class NavItem {
  final IconData icon;
  final String label;
  final int index;
  NavItem(this.index, this.icon, this.label);
}

// Primary navigation — sports betting focused
List<NavItem> kPrimaryNav = [
  NavItem(0, LucideIcons.home, 'Sportsbook'),
  NavItem(1, LucideIcons.flame, 'Live'),
  NavItem(2, LucideIcons.target, 'Parlays'),
  NavItem(3, LucideIcons.gift, 'Promotions'),
  NavItem(4, LucideIcons.trophy, 'Leaderboard'),
  NavItem(5, LucideIcons.crown, 'VIP Club'),
  NavItem(6, LucideIcons.wallet, 'My Bets'),
];

// Secondary navigation — account & support
List<NavItem> kSecondaryNav = [
  NavItem(7, LucideIcons.user, 'Profile'),
  NavItem(8, LucideIcons.settings, 'Settings'),
  NavItem(9, LucideIcons.helpCircle, 'Help'),
  NavItem(10, LucideIcons.fileText, 'Legal'),
];

// ============================================================================
// APP SHELL
// ============================================================================

class AppShell extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Widget child;
  final String? title;

  AppShell({
    super.key,
    required this.index,
    required this.onChanged,
    required this.child,
    this.title,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Collapsed by default on large screens
  bool _railExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size) {
        final isExpanded = size.isExpanded;

        if (isExpanded) {
          // LARGE SCREENS: permanent collapsed rail + content
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(context, isExpanded: true),
            body: Row(
              children: [
                _buildPermanentRail(),
                Container(width: 1, color: AppColors.border),
                Expanded(child: widget.child),
              ],
            ),
          );
        }

        // SMALL SCREENS: drawer + bottom nav
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(context, isExpanded: false),
          drawer: _buildDrawer(context),
          bottomNavigationBar: _buildBottomNav(context),
          body: widget.child,
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // APP BAR — Sharp editorial sportsbook header
  // --------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(
      BuildContext context, {
        required bool isExpanded,
      }) {
    final appBarTitle =
        widget.title ??
            (widget.index < kPrimaryNav.length
                ? kPrimaryNav[widget.index].label.toUpperCase()
                : 'ONYXBET');

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(
            LucideIcons.menu,
            size: 20,
            color: AppColors.foreground,
          ),
          onPressed: () {
            if (isExpanded) {
              setState(() => _railExpanded = !_railExpanded);
            } else {
              Scaffold.of(ctx).openDrawer();
            }
          },
        ),
      ),
      title: isExpanded
          ? Text(
        appBarTitle,
        style: TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      )
          : Image.asset("assets/logo.png", height: 52),
      centerTitle: !isExpanded,
      actions: [
        // Live indicator — pulsing red dot
        Container(
          margin: EdgeInsets.only(right: 8),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.negative,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  color: AppColors.negative,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            LucideIcons.search,
            size: 19,
            color: AppColors.foregroundSecondary,
          ),
          onPressed: () {},
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                LucideIcons.bell,
                size: 19,
                color: AppColors.foregroundSecondary,
              ),
              onPressed: () {},
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.positive,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PERMANENT RAIL (large screens) — Sharp editorial scoreboard style
  // --------------------------------------------------------------------------
  Widget _buildPermanentRail() {
    double collapsedWidth = 72;
    double expandedWidth = 260;

    return AnimatedContainer(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _railExpanded ? expandedWidth : collapsedWidth,
      color: AppColors.backgroundSecondary,
      child: Column(
        children: [
          // Header: logo
          Container(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: _railExpanded
                ? Image.asset("assets/logo.png", height: 36)
                : Image.asset("assets/favicon.png", width: 40, height: 40),
          ),
          Divider(height: 1, color: AppColors.border),

          // Nav items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              children: [
                if (_railExpanded) _railSectionLabel('BETTING'),
                ...kPrimaryNav.map(
                      (item) => _RailTile(
                    item: item,
                    active: widget.index == item.index,
                    expanded: _railExpanded,
                    onTap: () => widget.onChanged(item.index),
                  ),
                ),
                SizedBox(height: 16),
                if (_railExpanded) _railSectionLabel('ACCOUNT'),
                if (!_railExpanded)
                  Divider(height: 12, color: AppColors.border),
                ...kSecondaryNav.map(
                      (item) => _RailTile(
                    item: item,
                    active: widget.index == item.index,
                    expanded: _railExpanded,
                    onTap: () => widget.onChanged(item.index),
                  ),
                ),
              ],
            ),
          ),

          // Bottom: VIP status / user
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _railExpanded
                ? _buildUserPanelExpanded()
                : _buildUserPanelCollapsed(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPanelExpanded() {
    return Row(
      children: [
        // Avatar with gold ring (VIP indicator)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            border: Border.all(color: AppColors.secondary, width: 2),
          ),
          child: Center(
            child: Text(
              'OB',
              style: TextStyle(
                color: AppColors.primaryForeground,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alexander Chen',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(LucideIcons.crown, size: 10, color: AppColors.secondary),
                  SizedBox(width: 4),
                  Text(
                    'VIP ELITE',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(
          LucideIcons.logOut,
          size: 15,
          color: AppColors.foregroundSecondary,
        ),
      ],
    );
  }

  Widget _buildUserPanelCollapsed() {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border.all(color: AppColors.secondary, width: 2),
        ),
        child: Center(
          child: Text(
            'OB',
            style: TextStyle(
              color: AppColors.primaryForeground,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _railSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.foregroundSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DRAWER (compact)
  // --------------------------------------------------------------------------
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset("assets/logo.png", height: 36),
                  SizedBox(height: 12),
                  // Bankroll display
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.wallet,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BANKROLL',
                                style: TextStyle(
                                  color: AppColors.foregroundSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '\$1,247.50',
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                          ),
                          child: Text(
                            'DEPOSIT',
                            style: TextStyle(
                              color: AppColors.primaryForeground,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _drawerSectionLabel('BETTING'),
                ...kPrimaryNav.map(
                      (item) => _DrawerTile(
                    item: item,
                    active: widget.index == item.index,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onChanged(item.index);
                    },
                  ),
                ),
                SizedBox(height: 16),
                _drawerSectionLabel('ACCOUNT'),
                ...kSecondaryNav.map(
                      (item) => _DrawerTile(
                    item: item,
                    active: widget.index == item.index,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onChanged(item.index);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Footer: VIP status
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    border: Border.all(color: AppColors.secondary, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      'OB',
                      style: TextStyle(
                        color: AppColors.primaryForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alexander Chen',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'VIP ELITE · Since 2024',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.logOut,
                  size: 16,
                  color: AppColors.foregroundSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.foregroundSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BOTTOM NAV — Sharp square tabs, 5 key betting actions
  // --------------------------------------------------------------------------
  Widget _buildBottomNav(BuildContext context) {
    // Sportsbook, Live, Parlays, My Bets, Profile
    final bottomItems = [
      kPrimaryNav[0], // Sportsbook
      kPrimaryNav[1], // Live
      kPrimaryNav[2], // Parlays
      kPrimaryNav[6], // My Bets
      kSecondaryNav[0], // Profile
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: bottomItems.map((item) {
              final active = widget.index == item.index;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onChanged(item.index),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: active ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: active
                                ? AppColors.primaryForeground
                                : AppColors.foregroundSecondary,
                          ),
                          SizedBox(height: 4),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? AppColors.primaryForeground
                                  : AppColors.foregroundSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RAIL TILE — Sharp editorial square tile
// ============================================================================

class _RailTile extends StatelessWidget {
  final NavItem item;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;
  _RailTile({
    required this.item,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              border: Border(
                left: active
                    ? BorderSide(color: AppColors.secondary, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: expanded
                ? Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active
                      ? AppColors.primaryForeground
                      : AppColors.foregroundSecondary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: active
                          ? AppColors.primaryForeground
                          : AppColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (active)
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.primaryForeground,
                  ),
              ],
            )
                : Center(
              child: Icon(
                item.icon,
                size: 18,
                color: active
                    ? AppColors.primaryForeground
                    : AppColors.foregroundSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DRAWER TILE — Sharp editorial square tile
// ============================================================================

class _DrawerTile extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  _DrawerTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              border: Border(
                left: active
                    ? BorderSide(color: AppColors.secondary, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active
                      ? AppColors.primaryForeground
                      : AppColors.foregroundSecondary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: active
                          ? AppColors.primaryForeground
                          : AppColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (active)
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.primaryForeground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}