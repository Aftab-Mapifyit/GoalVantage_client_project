// lib/features/pitchiq/tabs/performance_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../models/prediction.dart';
import '../../theme/colors.dart' hide Prediction;

class PerformanceTab extends StatefulWidget {
  const PerformanceTab({super.key});

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  List<Prediction> _allPredictions = [];
  bool _isLoading = true;
  String? _loadError;
  String _period = 'weekly'; // 'weekly', 'monthly'
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _listenToPredictions();
  }

  /// Listen to ALL predictions and filter later by `isCorrect != null`
  void _listenToPredictions() {
    FirebaseFirestore.instance
        .collection('predictions')
        .snapshots()
        .listen((snapshot) {
      final predictions = snapshot.docs
          .map((doc) => Prediction.fromMap(doc.data(), doc.id))
          .toList();
      if (mounted) {
        setState(() {
          _allPredictions = predictions;
          _isLoading = false;
          _loadError = null;
          _lastUpdated = DateTime.now();
        });
      }
    }, onError: (e) {
      debugPrint('Error loading performance data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    });
  }

  /// Safely parse matchTime from Timestamp or DateTime
  DateTime? _parseDate(dynamic time) {
    if (time == null) return null;
    try {
      return time is Timestamp ? time.toDate() : (time as DateTime);
    } catch (e) {
      return null;
    }
  }

  /// Returns only predictions that are settled and within the time period.
  List<Prediction> get _settledPredictions {
    final now = DateTime.now();
    final cutoff = _period == 'weekly'
        ? now.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month, 1);

    return _allPredictions.where((p) {
      if (p.isCorrect == null) return false;
      final matchDate = _parseDate(p.matchTime);
      return matchDate != null && matchDate.isAfter(cutoff);
    }).toList();
  }

  Map<String, dynamic> get _stats {
    final list = _settledPredictions;
    final total = list.length;
    final won = list.where((p) => p.isCorrect == true).length;
    final lost = list.where((p) => p.isCorrect == false).length;

    final winRate = total > 0 ? (won / total) * 100 : 0.0;

    // ROI calculation based on a standardized flat stake for transparency
    const flatStake = 100.0;
    double totalStaked = 0;
    double totalReturns = 0;
    int betsWithOdds = 0;

    for (final p in list) {
      totalStaked += flatStake;
      if (p.isCorrect == true) {
        final odds = p.odds ?? 1.5;
        if (p.odds != null) betsWithOdds++;
        totalReturns += flatStake * odds;
      }
    }

    final roi = totalStaked > 0 ? ((totalReturns - totalStaked) / totalStaked) * 100 : 0.0;
    final profit = totalReturns - totalStaked;

    // Best winning streak
    int bestStreak = 0;
    int currentStreak = 0;
    for (final p in list.reversed) {
      if (p.isCorrect == true) {
        currentStreak++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    // League breakdown
    final leagueStats = <String, Map<String, int>>{};
    for (final p in list) {
      final league = (p.leagueName ?? p.leagueKey ?? 'Other').toString();
      leagueStats.putIfAbsent(league, () => {'total': 0, 'won': 0});
      leagueStats[league]!['total'] = leagueStats[league]!['total']! + 1;
      if (p.isCorrect == true) {
        leagueStats[league]!['won'] = leagueStats[league]!['won']! + 1;
      }
    }

    return {
      'total': total,
      'won': won,
      'lost': lost,
      'winRate': winRate,
      'roi': roi,
      'bestStreak': bestStreak,
      'profit': profit,
      'betsWithOdds': betsWithOdds,
      'leagueStats': leagueStats,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load performance data.\n$_loadError',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GoalVantageColors.negative,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final stats = _stats;
    final settledCount = stats['total'] as int;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildPeriodToggle()),
        if (settledCount == 0)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyStateWidget(),
          )
        else
          SliverList(
            delegate: SliverChildListDelegate([
              _buildMainStats(stats),
              if ((stats['leagueStats'] as Map).isNotEmpty)
                _buildLeagueBreakdown(stats),
              const SizedBox(height: 16),
              _buildFooter(stats),
              const SizedBox(height: 24),
            ]),
          ),
      ],
    );
  }

  // ---------------------- UI Components ----------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
              "assets/logo.png",
              width: 150,
              errorBuilder: (_, __, ___) => const Text(
                  'GoalVantage',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              )
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.barChart3, size: 14, color: GoalVantageColors.accent),
              const SizedBox(width: 8),
              Text(
                'PERFORMANCE ANALYTICS',
                style: TextStyle(
                  color: GoalVantageColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GoalVantageColors.positive.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: GoalVantageColors.positive.withOpacity(0.3)),
                ),
                child: Text(
                  'VERIFIED',
                  style: TextStyle(
                    color: GoalVantageColors.positive,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'OUR TRACK RECORD',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real win rates and simulated ROI based on settled predictions with verified odds.',
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

  Widget _buildPeriodToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Row(
        children: [
          _periodButton('weekly', 'THIS WEEK'),
          const SizedBox(width: 8),
          _periodButton('monthly', 'THIS MONTH'),
        ],
      ),
    );
  }

  Widget _periodButton(String key, String label) {
    final isActive = _period == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _period = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? GoalVantageColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? GoalVantageColors.primary : GoalVantageColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : GoalVantageColors.foregroundSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStats(Map<String, dynamic> stats) {
    final winRate = stats['winRate'] as double;
    final roi = stats['roi'] as double;
    final profit = stats['profit'] as double;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Win Rate Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GoalVantageColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GoalVantageColors.positive.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: GoalVantageColors.positive.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'WIN RATE',
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${winRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: GoalVantageColors.positive,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                // Modern Progress Bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: GoalVantageColors.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (winRate / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: GoalVantageColors.positive,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _miniStat('${stats['won']}', 'WON', GoalVantageColors.positive),
                    Container(
                      height: 24,
                      width: 1,
                      color: GoalVantageColors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    _miniStat('${stats['lost']}', 'LOST', GoalVantageColors.negative),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on ${stats['total']} settled picks',
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Secondary Stats Grid
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: LucideIcons.trendingUp,
                  label: 'SIMULATED ROI',
                  value: '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(1)}%',
                  color: roi >= 0 ? GoalVantageColors.positive : GoalVantageColors.negative,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: LucideIcons.dollarSign,
                  label: 'NET PROFIT',
                  value: '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)} USD',
                  color: profit >= 0 ? GoalVantageColors.positive : GoalVantageColors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: LucideIcons.flame,
                  label: 'BEST STREAK',
                  value: '${stats['bestStreak']}',
                  color: GoalVantageColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: LucideIcons.target,
                  label: 'TOTAL SETTLED',
                  value: '${stats['total']}',
                  color: GoalVantageColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
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
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GoalVantageColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueBreakdown(Map<String, dynamic> stats) {
    final leagueStats = stats['leagueStats'] as Map<String, Map<String, int>>;
    final entries = leagueStats.entries.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEAGUE BREAKDOWN',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: GoalVantageColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GoalVantageColors.border),
            ),
            child: Column(
              children: entries.asMap().entries.map((mapEntry) {
                final index = mapEntry.key;
                final entry = mapEntry.value;
                final league = entry.key;
                final total = entry.value['total'] ?? 0;
                final won = entry.value['won'] ?? 0;
                final rate = total > 0 ? (won / total) * 100 : 0.0;

                final isLast = index == entries.length - 1;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(bottom: BorderSide(color: GoalVantageColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              league.toUpperCase(),
                              style: TextStyle(
                                color: GoalVantageColors.foreground,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$won / $total picks won',
                              style: TextStyle(
                                color: GoalVantageColors.foregroundSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 60,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: GoalVantageColors.background,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (rate / 100).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: rate >= 60
                                    ? GoalVantageColors.positive
                                    : rate >= 45
                                    ? GoalVantageColors.warning
                                    : GoalVantageColors.negative,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 45,
                        child: Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: rate >= 60
                                ? GoalVantageColors.positive
                                : rate >= 45
                                ? GoalVantageColors.warning
                                : GoalVantageColors.negative,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          textAlign: TextAlign.right,
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

  Widget _buildFooter(Map<String, dynamic> stats) {
    final oddsCount = stats['betsWithOdds'] as int;
    final total = stats['total'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (oddsCount < total)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GoalVantageColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GoalVantageColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 14, color: GoalVantageColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${total - oddsCount} picks had no odds recorded. A default 1.5 was used for ROI simulation.',
                      style: TextStyle(
                        color: GoalVantageColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (oddsCount < total) const SizedBox(height: 12),
          Text(
            'Last updated: ${_formatLastUpdated(_lastUpdated)}',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
}

// Extracted to a const-friendly widget to avoid SliverFillRemaining layout issues
class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.barChart3, size: 48, color: GoalVantageColors.foregroundSecondary),
            const SizedBox(height: 16),
            Text(
              'NO SETTLED PICKS IN THIS PERIOD',
              style: TextStyle(
                color: GoalVantageColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try switching to "THIS MONTH" or wait for current predictions to settle.',
              style: TextStyle(
                color: GoalVantageColors.foregroundSecondary,
                fontSize: 12,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}





// // lib/features/pitchiq/tabs/performance_tab.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons.dart';
// import '../../theme/app_colors.dart';
// import '../../models/prediction.dart';
// import '../../theme/colors.dart' hide Prediction;
//
// class PerformanceTab extends StatefulWidget {
//   const PerformanceTab({super.key});
//
//   @override
//   State<PerformanceTab> createState() => _PerformanceTabState();
// }
//
// class _PerformanceTabState extends State<PerformanceTab> {
//   List<Prediction> _allPredictions = [];
//   bool _isLoading = true;
//   String _period = 'weekly'; // 'weekly', 'monthly'
//   DateTime? _lastUpdated;
//
//   @override
//   void initState() {
//     super.initState();
//     _listenToPredictions();
//   }
//
//   /// Listen to ALL predictions (no status filter) and filter later by `isCorrect != null`
//   void _listenToPredictions() {
//     FirebaseFirestore.instance
//         .collection('predictions')
//         .snapshots()
//         .listen((snapshot) {
//       final predictions = snapshot.docs
//           .map((doc) => Prediction.fromMap(doc.data(), doc.id))
//           .toList();
//       if (mounted) {
//         setState(() {
//           _allPredictions = predictions;
//           _isLoading = false;
//           _lastUpdated = DateTime.now();
//         });
//       }
//     }, onError: (e) {
//       if (mounted) setState(() => _isLoading = false);
//     });
//   }
//
//   /// Returns only predictions that are settled (have a result) and within the time period.
//   List<Prediction> get _settledPredictions {
//     final now = DateTime.now();
//     final cutoff = _period == 'weekly'
//         ? now.subtract(const Duration(days: 7))
//         : DateTime(now.year, now.month, 1);
//
//     return _allPredictions.where((p) {
//       // Must have a result (settled)
//       if (p.isCorrect == null) return false;
//       // Must be within the selected time window
//       return p.matchTime.isAfter(cutoff);
//     }).toList();
//   }
//
//   Map<String, dynamic> get _stats {
//     final list = _settledPredictions;
//     final total = list.length;
//     final won = list.where((p) => p.isCorrect == true).length;
//     final lost = list.where((p) => p.isCorrect == false).length;
//
//     // Win rate
//     final winRate = total > 0 ? (won / total) * 100 : 0.0;
//
//     // ROI calculation – now with better odds handling
//     const flatStake = 100.0;
//     double totalStaked = 0;
//     double totalReturns = 0;
//     int betsWithOdds = 0;
//
//     for (final p in list) {
//       totalStaked += flatStake;
//       if (p.isCorrect == true) {
//         // Use odds if available, otherwise default to 1.5 (a reasonable fallback)
//         final odds = p.odds ?? 1.5;
//         if (p.odds != null) betsWithOdds++;
//         totalReturns += flatStake * odds;
//       }
//     }
//
//     final roi = totalStaked > 0 ? ((totalReturns - totalStaked) / totalStaked) * 100 : 0.0;
//     final profit = totalReturns - totalStaked;
//
//     // Best winning streak
//     int bestStreak = 0;
//     int currentStreak = 0;
//     for (final p in list.reversed) {
//       if (p.isCorrect == true) {
//         currentStreak++;
//         if (currentStreak > bestStreak) bestStreak = currentStreak;
//       } else {
//         currentStreak = 0;
//       }
//     }
//
//     // League breakdown
//     final leagueStats = <String, Map<String, int>>{};
//     for (final p in list) {
//       final league = (p.leagueName ?? p.leagueKey ?? 'Other').toString();
//       leagueStats.putIfAbsent(league, () => {'total': 0, 'won': 0});
//       leagueStats[league]!['total'] = leagueStats[league]!['total']! + 1;
//       if (p.isCorrect == true) {
//         leagueStats[league]!['won'] = leagueStats[league]!['won']! + 1;
//       }
//     }
//
//     return {
//       'total': total,
//       'won': won,
//       'lost': lost,
//       'winRate': winRate,
//       'roi': roi,
//       'bestStreak': bestStreak,
//       'profit': profit,
//       'betsWithOdds': betsWithOdds,
//       'leagueStats': leagueStats,
//     };
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     final stats = _stats;
//     final settledCount = stats['total'] as int;
//
//     return CustomScrollView(
//       slivers: [
//         SliverToBoxAdapter(child: _buildHeader()),
//         SliverToBoxAdapter(child: _buildPeriodToggle()),
//         if (settledCount == 0)
//           SliverFillRemaining(child: _buildEmptyState())
//         else
//           SliverList(
//             delegate: SliverChildListDelegate([
//               _buildMainStats(stats),
//               if ((stats['leagueStats'] as Map).isNotEmpty)
//                 _buildLeagueBreakdown(stats),
//               const SizedBox(height: 16),
//               _buildFooter(stats),
//             ]),
//           ),
//       ],
//     );
//   }
//
//   // ---------------------- UI Components ----------------------
//
//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
//       decoration: BoxDecoration(
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Image.asset("assets/logo.png", width: 250),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(LucideIcons.barChart3, size: 14, color: GoalVantageColors.accent),
//               const SizedBox(width: 8),
//               Text(
//                 'PERFORMANCE ANALYTICS',
//                 style: TextStyle(
//                   color: GoalVantageColors.accent,
//                   fontSize: 10,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'OUR TRACK RECORD',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 28,
//               fontWeight: FontWeight.w900,
//               letterSpacing: -1.0,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Real win rates and ROI based on settled predictions with verified odds.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//               height: 1.4,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPeriodToggle() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.backgroundSecondary,
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Row(
//         children: [
//           _periodButton('weekly', 'THIS WEEK'),
//           const SizedBox(width: 8),
//           _periodButton('monthly', 'THIS MONTH'),
//         ],
//       ),
//     );
//   }
//
//   Widget _periodButton(String key, String label) {
//     final isActive = _period == key;
//     return Expanded(
//       child: InkWell(
//         onTap: () => setState(() => _period = key),
//         child: Container(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           decoration: BoxDecoration(
//             color: isActive ? GoalVantageColors.primary : Colors.transparent,
//             border: Border.all(
//               color: isActive ? GoalVantageColors.primary : GoalVantageColors.border,
//             ),
//           ),
//           child: Center(
//             child: Text(
//               label,
//               style: TextStyle(
//                 color: isActive
//                     ? GoalVantageColors.primaryForeground
//                     : GoalVantageColors.foregroundSecondary,
//                 fontSize: 11,
//                 fontWeight: FontWeight.w900,
//                 letterSpacing: 1.0,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(LucideIcons.barChart3, size: 48, color: GoalVantageColors.foregroundSecondary.withOpacity(0.4)),
//           const SizedBox(height: 16),
//           Text(
//             'NO SETTLED PICKS IN THIS PERIOD',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 16,
//               fontWeight: FontWeight.w900,
//               letterSpacing: 1.0,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Try switching to "THIS MONTH" or wait for predictions to settle.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 12,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMainStats(Map<String, dynamic> stats) {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Win rate
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: GoalVantageColors.card,
//               border: Border.all(color: GoalVantageColors.primary, width: 1.5),
//             ),
//             child: Column(
//               children: [
//                 Text(
//                   'WIN RATE',
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: 1.5,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   '${(stats['winRate'] as double).toStringAsFixed(1)}%',
//                   style: TextStyle(
//                     color: GoalVantageColors.positive,
//                     fontSize: 56,
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: -2.0,
//                     fontFeatures: const [FontFeature.tabularFigures()],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Container(
//                   height: 6,
//                   decoration: BoxDecoration(
//                     color: GoalVantageColors.background,
//                   ),
//                   child: FractionallySizedBox(
//                     alignment: Alignment.centerLeft,
//                     widthFactor: ((stats['winRate'] as double) / 100).clamp(0.0, 1.0),
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: GoalVantageColors.positive,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     _miniStat('${stats['won']}', 'WON', GoalVantageColors.positive),
//                     const SizedBox(width: 24),
//                     _miniStat('${stats['lost']}', 'LOST', GoalVantageColors.negative),
//                   ],
//                 ),
//                 // Show total settled count for clarity
//                 const SizedBox(height: 8),
//                 Text(
//                   'Based on ${stats['total']} settled picks',
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 12),
//
//           // ROI, Profit, Best Streak, Total Picks
//           Row(
//             children: [
//               Expanded(
//                 child: _statCard(
//                   icon: LucideIcons.trendingUp,
//                   label: 'ROI',
//                   value: '${(stats['roi'] as double) >= 0 ? '+' : ''}${(stats['roi'] as double).toStringAsFixed(1)}%',
//                   color: (stats['roi'] as double) >= 0
//                       ? GoalVantageColors.positive
//                       : GoalVantageColors.negative,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: _statCard(
//                   icon: LucideIcons.dollarSign,
//                   label: 'PROFIT',
//                   value: '${(stats['profit'] as double) >= 0 ? '+' : ''}${(stats['profit'] as double).toStringAsFixed(0)} USD',
//                   color: (stats['profit'] as double) >= 0
//                       ? GoalVantageColors.positive
//                       : GoalVantageColors.negative,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: _statCard(
//                   icon: LucideIcons.flame,
//                   label: 'BEST STREAK',
//                   value: '${stats['bestStreak']}',
//                   color: GoalVantageColors.gold,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: _statCard(
//                   icon: LucideIcons.target,
//                   label: 'TOTAL SETTLED',
//                   value: '${stats['total']}',
//                   color: GoalVantageColors.accent,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _miniStat(String value, String label, Color color) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: TextStyle(
//             color: color,
//             fontSize: 16,
//             fontWeight: FontWeight.w900,
//             fontFeatures: const [FontFeature.tabularFigures()],
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           label,
//           style: TextStyle(
//             color: GoalVantageColors.foregroundSecondary,
//             fontSize: 8,
//             fontWeight: FontWeight.w800,
//             letterSpacing: 1.0,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _statCard({
//     required IconData icon,
//     required String label,
//     required String value,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(color: GoalVantageColors.border),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, size: 16, color: color),
//           const SizedBox(height: 10),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: 18,
//               fontWeight: FontWeight.w900,
//               fontFeatures: const [FontFeature.tabularFigures()],
//               letterSpacing: -0.5,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             label,
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 8,
//               fontWeight: FontWeight.w800,
//               letterSpacing: 1.0,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLeagueBreakdown(Map<String, dynamic> stats) {
//     final leagueStats = stats['leagueStats'] as Map<String, Map<String, int>>;
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'LEAGUE BREAKDOWN',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 10,
//               fontWeight: FontWeight.w900,
//               letterSpacing: 1.5,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Container(
//             decoration: BoxDecoration(
//               color: GoalVantageColors.card,
//               border: Border.all(color: GoalVantageColors.border),
//             ),
//             child: Column(
//               children: leagueStats.entries.map((entry) {
//                 final league = entry.key;
//                 final total = entry.value['total'] ?? 0;
//                 final won = entry.value['won'] ?? 0;
//                 final rate = total > 0 ? (won / total) * 100 : 0.0;
//
//                 return Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     border: Border(
//                       bottom: BorderSide(color: GoalVantageColors.border),
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               league.toUpperCase(),
//                               style: TextStyle(
//                                 color: GoalVantageColors.foreground,
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w800,
//                                 letterSpacing: 0.8,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               '$won/$total picks won',
//                               style: TextStyle(
//                                 color: GoalVantageColors.foregroundSecondary,
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       SizedBox(
//                         width: 80,
//                         child: Container(
//                           height: 4,
//                           decoration: BoxDecoration(
//                             color: GoalVantageColors.background,
//                           ),
//                           child: FractionallySizedBox(
//                             alignment: Alignment.centerLeft,
//                             widthFactor: (rate / 100).clamp(0.0, 1.0),
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 color: rate >= 60
//                                     ? GoalVantageColors.positive
//                                     : rate >= 45
//                                     ? GoalVantageColors.warning
//                                     : GoalVantageColors.negative,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       SizedBox(
//                         width: 50,
//                         child: Text(
//                           '${rate.toStringAsFixed(0)}%',
//                           style: TextStyle(
//                             color: rate >= 60
//                                 ? GoalVantageColors.positive
//                                 : rate >= 45
//                                 ? GoalVantageColors.warning
//                                 : GoalVantageColors.negative,
//                             fontSize: 12,
//                             fontWeight: FontWeight.w900,
//                             fontFeatures: const [FontFeature.tabularFigures()],
//                           ),
//                           textAlign: TextAlign.right,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFooter(Map<String, dynamic> stats) {
//     final oddsCount = stats['betsWithOdds'] as int;
//     final total = stats['total'] as int;
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Column(
//         children: [
//           if (oddsCount < total)
//             Text(
//               '⚠️ ${total - oddsCount} picks had no odds — used default 1.5 for ROI.',
//               style: TextStyle(
//                 color: GoalVantageColors.warning,
//                 fontSize: 11,
//                 fontWeight: FontWeight.w600,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           const SizedBox(height: 8),
//           Text(
//             'Last updated: ${_formatLastUpdated(_lastUpdated)}',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 10,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _formatLastUpdated(DateTime? time) {
//     if (time == null) return 'just now';
//     final diff = DateTime.now().difference(time);
//     if (diff.inSeconds < 60) return 'just now';
//     if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
//     if (diff.inHours < 24) return '${diff.inHours}h ago';
//     return '${diff.inDays}d ago';
//   }
// }
//
//
//
//
//
