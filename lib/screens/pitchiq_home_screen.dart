import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/prediction.dart';
import '../theme/app_colors.dart';
import '../theme/colors.dart' hide Prediction;



// ============================================================================
// GoalVantage HOME SCREEN
// ============================================================================

class OldHomeScreen extends StatefulWidget {
  const OldHomeScreen({super.key});

  @override
  State<OldHomeScreen> createState() => _OldHomeScreenState();
}

class _OldHomeScreenState extends State<OldHomeScreen> {
  List<Prediction> _predictions = [];
  List<Tipster> _tipsters = [];
  PredictionStats? _stats;
  bool _isLoading = true;
  String _activeLeague = 'all';

  StreamSubscription? _predictionsSub;
  StreamSubscription? _tipstersSub;
  StreamSubscription? _statsSub;

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
    _listenToData();
  }

  @override
  void dispose() {
    _predictionsSub?.cancel();
    _tipstersSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  void _listenToData() {
    // Predictions
    _predictionsSub = FirebaseFirestore.instance
        .collection('predictions')
        .orderBy('matchTime')
        .limit(30)
        .snapshots()
        .listen((snapshot) {
      final predictions = snapshot.docs
          .map((doc) => Prediction.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error loading predictions: $e');
      if (mounted) setState(() => _isLoading = false);
    });

    // Tipsters
    _tipstersSub = FirebaseFirestore.instance
        .collection('tipsters')
        .orderBy('accuracy', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      final tipsters = snapshot.docs
          .map((doc) => Tipster.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) setState(() => _tipsters = tipsters);
    });

    // Stats
    _statsSub = FirebaseFirestore.instance
        .collection('prediction_stats')
        .doc('overview')
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        if (mounted) {
          setState(() => _stats = PredictionStats.fromMap(doc.data()!));
        }
      }
    });
  }

  List<Prediction> get _filteredPredictions {
    if (_activeLeague == 'all') return _predictions;
    return _predictions.where((p) => p.leagueKey == _activeLeague).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoalVantageColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildStatsBar()),
            SliverToBoxAdapter(child: _buildLeagueFilter()),
            SliverToBoxAdapter(child: _buildPredictionsSection()),
            SliverToBoxAdapter(child: _buildTipstersSection()),
            SliverToBoxAdapter(child: _buildHowItWorks()),
            SliverToBoxAdapter(child: _buildPremiumCta()),
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
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Image.asset("assets/logo.png", width: 250),
          const SizedBox(height: 24),

          // Heading
          Text(
            'READ THE GAME\nBEFORE IT HAPPENS.',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AI-powered football predictions with form analysis, head-to-head stats, and confidence scores across 6 major leagues.',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // CTA Buttons
          Row(
            children: [
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GoalVantageColors.primary,
                    foregroundColor: GoalVantageColors.primaryForeground,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VIEW PREDICTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.arrowRight, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GoalVantageColors.foreground,
                    side: BorderSide(color: GoalVantageColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(
                    'GO PREMIUM',
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
        ],
      ),
    );
  }

  // ==========================================================================
  // STATS BAR
  // ==========================================================================

  Widget _buildStatsBar() {
    final stats = _stats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              stats?.overallAccuracy != null ? '${stats!.overallAccuracy}%' : '—',
              'ACCURACY',
              GoalVantageColors.accent,
            ),
          ),
          Container(width: 1, height: 40, color: GoalVantageColors.border),
          Expanded(
            child: _statItem(
              stats?.totalPredictions != null ? '${(stats!.totalPredictions / 1000).toStringAsFixed(1)}K' : '—',
              'PREDICTIONS',
              GoalVantageColors.foreground,
            ),
          ),
          Container(width: 1, height: 40, color: GoalVantageColors.border),
          Expanded(
            child: _statItem(
              stats?.matchesToday != null ? '${stats!.matchesToday}' : '—',
              'MATCHES TODAY',
              GoalVantageColors.positive,
            ),
          ),
          Container(width: 1, height: 40, color: GoalVantageColors.border),
          Expanded(
            child: _statItem(
              stats?.premiumAccuracy != null ? '${stats!.premiumAccuracy}%' : '—',
              'PREMIUM ACC',
              GoalVantageColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
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
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LEAGUE FILTER
  // ==========================================================================

  Widget _buildLeagueFilter() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _leagues.length,
        itemBuilder: (context, index) {
          final league = _leagues[index];
          final isActive = _activeLeague == league['key'];

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _activeLeague = league['key']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? GoalVantageColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isActive ? GoalVantageColors.primary : GoalVantageColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    league['label']!,
                    style: TextStyle(
                      color: isActive ? GoalVantageColors.primaryForeground : GoalVantageColors.foregroundSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // PREDICTIONS SECTION
  // ==========================================================================

  Widget _buildPredictionsSection() {
    final predictions = _filteredPredictions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.brain, size: 14, color: GoalVantageColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'AI PREDICTIONS',
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
                'TODAY\'S PICKS',
                style: TextStyle(
                  color: GoalVantageColors.foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (predictions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No predictions available for this league.',
                style: TextStyle(color: GoalVantageColors.foregroundSecondary),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: predictions.take(10).length,
            itemBuilder: (context, index) {
              return _buildPredictionCard(predictions[index]);
            },
          ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPredictionCard(Prediction pred) {
    final confidenceColor = pred.confidence >= 80
        ? GoalVantageColors.positive
        : pred.confidence >= 65
        ? GoalVantageColors.warning
        : GoalVantageColors.foregroundSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(
          color: pred.isPremium ? GoalVantageColors.gold.withOpacity(0.5) : GoalVantageColors.border,
          width: pred.isPremium ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — NOW INCLUDES SUBSCRIBE BUTTON
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: GoalVantageColors.backgroundSecondary,
              border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  pred.leagueName.toUpperCase(),
                  style: TextStyle(
                    color: GoalVantageColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(pred.matchTime),
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (pred.isPremium) ...[
                  Icon(LucideIcons.lock, size: 10, color: GoalVantageColors.gold),
                  const SizedBox(width: 4),
                  Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: GoalVantageColors.gold,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // 👇 SUBSCRIBE BUTTON INTEGRATED HERE
                _buildSubscribeButton(pred),
              ],
            ),
          ),

          // Match info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Teams
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pred.home,
                            style: TextStyle(
                              color: GoalVantageColors.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _formIndicator(pred.homeForm),
                          const SizedBox(height: 4),
                          Text(
                            '#${pred.homePosition}',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GoalVantageColors.background,
                        border: Border.all(color: GoalVantageColors.border),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: GoalVantageColors.foregroundSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            pred.away,
                            style: TextStyle(
                              color: GoalVantageColors.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 4),
                          _formIndicator(pred.awayForm),
                          const SizedBox(height: 4),
                          Text(
                            '#${pred.awayPosition}',
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

                const SizedBox(height: 14),

                // Prediction
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GoalVantageColors.background,
                    border: Border.all(color: GoalVantageColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pred.predictionType.toUpperCase(),
                              style: TextStyle(
                                color: GoalVantageColors.foregroundSecondary,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pred.prediction,
                              style: TextStyle(
                                color: GoalVantageColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'CONFIDENCE',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pred.confidence}%',
                            style: TextStyle(
                              color: confidenceColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ODDS',
                            style: TextStyle(
                              color: GoalVantageColors.foregroundSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pred.odds.toStringAsFixed(2),
                            style: TextStyle(
                              color: GoalVantageColors.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
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
        ],
      ),
    );
  }

  Widget _formIndicator(List<String> form) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: form.map((result) {
        final color = result == 'W'
            ? GoalVantageColors.positive
            : result == 'D'
            ? GoalVantageColors.warning
            : GoalVantageColors.negative;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              result,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);

    if (diff.inDays > 0) {
      return 'In ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return 'In ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'In ${diff.inMinutes}m';
    } else {
      return 'LIVE';
    }
  }

  // ==========================================================================
  // TIPSTERS SECTION
  // ==========================================================================

  Widget _buildTipstersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: GoalVantageColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.trophy, size: 14, color: GoalVantageColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'TOP TIPSTERS',
                    style: TextStyle(
                      color: GoalVantageColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'LEADERBOARD',
                style: TextStyle(
                  color: GoalVantageColors.foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),

        if (_tipsters.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tipsters.length,
            itemBuilder: (context, index) {
              final tipster = _tipsters[index];
              return _buildTipsterRow(tipster, index + 1);
            },
          ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTipsterRow(Tipster tipster, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(
          color: rank <= 3 ? GoalVantageColors.gold.withOpacity(0.3) : GoalVantageColors.border,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank <= 3 ? GoalVantageColors.gold : GoalVantageColors.background,
              border: Border.all(color: GoalVantageColors.border),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3 ? GoalVantageColors.background : GoalVantageColors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tipster.name,
                        style: TextStyle(
                          color: GoalVantageColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tipster.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(LucideIcons.badgeCheck, size: 12, color: GoalVantageColors.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${tipster.specialty} · ROI +${tipster.roi}%',
                  style: TextStyle(
                    color: GoalVantageColors.foregroundSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Accuracy
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tipster.accuracy}%',
                style: TextStyle(
                  color: GoalVantageColors.positive,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'ACCURACY',
                style: TextStyle(
                  color: GoalVantageColors.foregroundSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HOW IT WORKS
  // ==========================================================================

  Widget _buildHowItWorks() {
    final steps = [
      {'icon': LucideIcons.database, 'title': 'Data Collection', 'desc': 'We analyze 50+ data points per match: form, H2H, injuries, weather, and more.'},
      {'icon': LucideIcons.brain, 'title': 'AI Analysis', 'desc': 'Our machine learning models process historical data to identify patterns and probabilities.'},
      {'icon': LucideIcons.target, 'title': 'Prediction', 'desc': 'Each prediction comes with a confidence score and recommended odds threshold.'},
      {'icon': LucideIcons.checkCircle, 'title': 'Verification', 'desc': 'All predictions are tracked and verified. Our accuracy is publicly auditable.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: GoalVantageColors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(LucideIcons.info, size: 14, color: GoalVantageColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'METHODOLOGY',
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
                'HOW GOALVANTAGE WORKS',
                style: TextStyle(
                  color: GoalVantageColors.foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GoalVantageColors.card,
                    border: Border.all(color: GoalVantageColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '0${index + 1}',
                        style: TextStyle(
                          color: GoalVantageColors.primary.withOpacity(0.3),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'] as String,
                              style: TextStyle(
                                color: GoalVantageColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step['desc'] as String,
                              style: TextStyle(
                                color: GoalVantageColors.foregroundSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: GoalVantageColors.primary, width: 1.5),
                        ),
                        child: Icon(step['icon'] as IconData, size: 16, color: GoalVantageColors.primary),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PREMIUM CTA
  // ==========================================================================

  Widget _buildPremiumCta() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(color: GoalVantageColors.gold, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.crown, size: 16, color: GoalVantageColors.gold),
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
            'UNLOCK THE FULL PICTURE.',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Premium members get higher-confidence picks, detailed statistical breakdowns, injury updates, and exclusive tipster access.',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Benefits
          ...[
            'Higher confidence predictions (80%+)',
            'Detailed match analysis & stats',
            'Injury & suspension alerts',
            'Exclusive premium tipsters',
            'Ad-free experience',
          ].map((benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(LucideIcons.check, size: 12, color: GoalVantageColors.gold),
                const SizedBox(width: 8),
                Text(
                  benefit,
                  style: TextStyle(
                    color: GoalVantageColors.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: GoalVantageColors.gold,
                foregroundColor: GoalVantageColors.background,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'START FREE TRIAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, size: 14),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(top: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Column(
        children: [
          Image.asset("assets/logo.png", width: 190),
          const SizedBox(height: 8),
          Text(
            'Read the Game Before It Happens',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 GoalVantage. All rights reserved.',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUBSCRIBE BUTTON (Enhanced — prevents duplicates, shows state)
  // ==========================================================================

  Widget _buildSubscribeButton(Prediction pred) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Not signed in → show plain subscribe button
    if (uid == null) {
      return _subscribeButtonWidget(
        pred,
        isSubscribed: false,
        isLoading: false,
        onTap: () => _promptSignIn(),
      );
    }

    // Use FutureBuilder to check if user is already subscribed to this league
    return FutureBuilder<QuerySnapshot>(
      future: _checkSubscription(uid, pred.leagueKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _subscribeButtonWidget(
            pred,
            isSubscribed: false,
            isLoading: true,
          );
        }

        final isSubscribed = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return _subscribeButtonWidget(
          pred,
          isSubscribed: isSubscribed,
          isLoading: false,
        );
      },
    );
  }

  Widget _subscribeButtonWidget(
      Prediction pred, {
        required bool isSubscribed,
        required bool isLoading,
        VoidCallback? onTap,
      }) {
    final Color bgColor = isSubscribed
        ? GoalVantageColors.positive.withOpacity(0.15)
        : GoalVantageColors.primary.withOpacity(0.12);
    final Color borderColor = isSubscribed
        ? GoalVantageColors.positive.withOpacity(0.4)
        : GoalVantageColors.primary.withOpacity(0.3);
    final Color textColor = isSubscribed
        ? GoalVantageColors.positive
        : GoalVantageColors.primary;
    final IconData icon = isSubscribed ? LucideIcons.bellRing : LucideIcons.bell;
    final String label = isSubscribed ? 'SUBSCRIBED' : 'SUBSCRIBE';

    return InkWell(
      onTap: isLoading
          ? null
          : (onTap ?? () => _toggleSubscribe(pred, isSubscribed)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else
              Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if a subscription already exists for this user + league combo
  Future<QuerySnapshot> _checkSubscription(String uid, String leagueKey) async {
    try {
      return await FirebaseFirestore.instance
          .collection('user_subscriptions')
          .where('uid', isEqualTo: uid)
          .where('type', isEqualTo: 'odds_movement')
          .where('scope', isEqualTo: 'league')
          .where('scopeId', isEqualTo: leagueKey)
          .limit(1)
          .get();
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      // Return empty result on error
      return FirebaseFirestore.instance
          .collection('user_subscriptions')
          .where('uid', isEqualTo: 'nonexistent_user_${DateTime.now().millisecondsSinceEpoch}')
          .limit(1)
          .get();
    }
  }

  Future<void> _toggleSubscribe(Prediction pred, bool isCurrentlySubscribed) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _promptSignIn();
      return;
    }

    try {
      if (isCurrentlySubscribed) {
        // UNSUBSCRIBE — find and delete
        final query = await FirebaseFirestore.instance
            .collection('user_subscriptions')
            .where('uid', isEqualTo: uid)
            .where('type', isEqualTo: 'odds_movement')
            .where('scope', isEqualTo: 'league')
            .where('scopeId', isEqualTo: pred.leagueKey)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoalVantageColors.foregroundSecondary,
              content: Text('Unsubscribed from ${pred.leagueName}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // SUBSCRIBE — create new
        await FirebaseFirestore.instance.collection('user_subscriptions').add({
          'uid': uid,
          'type': 'odds_movement',
          'scope': 'league',
          'scopeId': pred.leagueKey,
          'scopeLabel': pred.leagueName,
          'delivery': ['push', 'in_app'],
          'frequency': 'realtime',
          'filters': {'minOddsChange': 0.10, 'minConfidence': 70},
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'synthetic': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoalVantageColors.positive,
              content: Text('Subscribed to ${pred.leagueName} odds movements'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Force rebuild to update button state
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoalVantageColors.negative,
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _promptSignIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GoalVantageColors.warning,
        content: const Text('Please sign in to subscribe to alerts'),
        action: SnackBarAction(
          label: 'SIGN IN',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Navigate to login screen
            // Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
        ),
      ),
    );
  }
}















// import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:lucide_icons_flutter/lucide_icons.dart';
// import '../theme/app_colors.dart';
//
// // ============================================================================
// // MODELS
// // ============================================================================
//
// class Prediction {
//   final String id;
//   final String leagueKey;
//   final String leagueName;
//   final String country;
//   final String home;
//   final String away;
//   final DateTime matchTime;
//   final String predictionType;
//   final String prediction;
//   final double confidence;
//   final double odds;
//   final List<String> homeForm;
//   final List<String> awayForm;
//   final int homePosition;
//   final int awayPosition;
//   final int h2hHomeWins;
//   final int h2hDraws;
//   final int h2hAwayWins;
//   final bool isPremium;
//   final String status;
//   final bool? isCorrect;
//
//   Prediction.fromMap(Map<String, dynamic> map, String docId)
//       : id = docId,
//         leagueKey = map['leagueKey'] ?? '',
//         leagueName = map['leagueName'] ?? '',
//         country = map['country'] ?? '',
//         home = map['home'] ?? 'Home',
//         away = map['away'] ?? 'Away',
//         matchTime = (map['matchTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
//         predictionType = map['predictionType'] ?? 'Match Result',
//         prediction = map['prediction'] ?? '',
//         confidence = (map['confidence'] as num?)?.toDouble() ?? 0,
//         odds = (map['odds'] as num?)?.toDouble() ?? 0,
//         homeForm = List<String>.from(map['homeForm'] ?? []),
//         awayForm = List<String>.from(map['awayForm'] ?? []),
//         homePosition = (map['homePosition'] as num?)?.toInt() ?? 0,
//         awayPosition = (map['awayPosition'] as num?)?.toInt() ?? 0,
//         h2hHomeWins = (map['h2hHomeWins'] as num?)?.toInt() ?? 0,
//         h2hDraws = (map['h2hDraws'] as num?)?.toInt() ?? 0,
//         h2hAwayWins = (map['h2hAwayWins'] as num?)?.toInt() ?? 0,
//         isPremium = map['isPremium'] ?? false,
//         status = map['status'] ?? 'upcoming',
//         isCorrect = map['isCorrect'];
// }
//
// class Tipster {
//   final String id;
//   final String name;
//   final double accuracy;
//   final int totalPredictions;
//   final int correctPredictions;
//   final int streak;
//   final String specialty;
//   final double roi;
//   final bool isVerified;
//   final bool isPremium;
//
//   Tipster.fromMap(Map<String, dynamic> map, String docId)
//       : id = docId,
//         name = map['name'] ?? 'Unknown',
//         accuracy = (map['accuracy'] as num?)?.toDouble() ?? 0,
//         totalPredictions = (map['totalPredictions'] as num?)?.toInt() ?? 0,
//         correctPredictions = (map['correctPredictions'] as num?)?.toInt() ?? 0,
//         streak = (map['streak'] as num?)?.toInt() ?? 0,
//         specialty = map['specialty'] ?? 'General',
//         roi = (map['roi'] as num?)?.toDouble() ?? 0,
//         isVerified = map['isVerified'] ?? false,
//         isPremium = map['isPremium'] ?? false;
// }
//
// class PredictionStats {
//   final double overallAccuracy;
//   final int totalPredictions;
//   final int matchesToday;
//   final double premiumAccuracy;
//   final double freeAccuracy;
//
//   PredictionStats.fromMap(Map<String, dynamic> map)
//       : overallAccuracy = (map['overallAccuracy'] as num?)?.toDouble() ?? 0,
//         totalPredictions = (map['totalPredictions'] as num?)?.toInt() ?? 0,
//         matchesToday = (map['matchesToday'] as num?)?.toInt() ?? 0,
//         premiumAccuracy = (map['premiumAccuracy'] as num?)?.toDouble() ?? 0,
//         freeAccuracy = (map['freeAccuracy'] as num?)?.toDouble() ?? 0;
// }
//
// // ============================================================================
// // GoalVantage COLORS (ThemeExtension with light/dark support)
// // ============================================================================
//
// class GoalVantageColors extends ThemeExtension<GoalVantageColors> {
//   // Private instance fields
//   final Color _background;
//   final Color _backgroundSecondary;
//   final Color _card;
//   final Color _foreground;
//   final Color _foregroundSecondary;
//   final Color _primary;
//   final Color _primaryForeground;
//   final Color _accent;
//   final Color _positive;
//   final Color _negative;
//   final Color _warning;
//   final Color _border;
//   final Color _gold;
//
//   const GoalVantageColors._({
//     required Color background,
//     required Color backgroundSecondary,
//     required Color card,
//     required Color foreground,
//     required Color foregroundSecondary,
//     required Color primary,
//     required Color primaryForeground,
//     required Color accent,
//     required Color positive,
//     required Color negative,
//     required Color warning,
//     required Color border,
//     required Color gold,
//   })  : _background = background,
//         _backgroundSecondary = backgroundSecondary,
//         _card = card,
//         _foreground = foreground,
//         _foregroundSecondary = foregroundSecondary,
//         _primary = primary,
//         _primaryForeground = primaryForeground,
//         _accent = accent,
//         _positive = positive,
//         _negative = negative,
//         _warning = warning,
//         _border = border,
//         _gold = gold;
//
//   // Named constructors for palettes
//   static const GoalVantageColors dark = GoalVantageColors._(
//     background: Color(0xFF0a0e1a),
//     backgroundSecondary: Color(0xFF111827),
//     card: Color(0xFF1a2035),
//     foreground: Color(0xFFe8ecf4),
//     foregroundSecondary: Color(0xFF8b95a8),
//     primary: Color(0xFF2563eb),
//     primaryForeground: Color(0xFFffffff),
//     accent: Color(0xFF06b6d4),
//     positive: Color(0xFF22c55e),
//     negative: Color(0xFFef4444),
//     warning: Color(0xFFf59e0b),
//     border: Color(0x1Ae8ecf4),
//     gold: Color(0xFFd4af37),
//   );
//
//   static const GoalVantageColors light = GoalVantageColors._(
//     background: Color(0xFFF5F8FC),
//     backgroundSecondary: Color(0xFFFFFFFF),
//     card: Color(0xFFFFFFFF),
//     foreground: Color(0xFF0B1220),
//     foregroundSecondary: Color(0xFF64748B),
//     primary: Color(0xFF2563eb),
//     primaryForeground: Color(0xFFFFFFFF),
//     accent: Color(0xFF0ea5e9),
//     positive: Color(0xFF22c55e),
//     negative: Color(0xFFef4444),
//     warning: Color(0xFFf59e0b),
//     border: Color(0x1A0B1220),
//     gold: Color(0xFFd4af37),
//   );
//
//   // ThemeExtension implementation
//   @override
//   GoalVantageColors copyWith({
//     Color? background,
//     Color? backgroundSecondary,
//     Color? card,
//     Color? foreground,
//     Color? foregroundSecondary,
//     Color? primary,
//     Color? primaryForeground,
//     Color? accent,
//     Color? positive,
//     Color? negative,
//     Color? warning,
//     Color? border,
//     Color? gold,
//   }) {
//     return GoalVantageColors._(
//       background: background ?? _background,
//       backgroundSecondary: backgroundSecondary ?? _backgroundSecondary,
//       card: card ?? _card,
//       foreground: foreground ?? _foreground,
//       foregroundSecondary: foregroundSecondary ?? _foregroundSecondary,
//       primary: primary ?? _primary,
//       primaryForeground: primaryForeground ?? _primaryForeground,
//       accent: accent ?? _accent,
//       positive: positive ?? _positive,
//       negative: negative ?? _negative,
//       warning: warning ?? _warning,
//       border: border ?? _border,
//       gold: gold ?? _gold,
//     );
//   }
//
//   @override
//   GoalVantageColors lerp(ThemeExtension<GoalVantageColors>? other, double t) {
//     if (other is! GoalVantageColors) return this;
//     return GoalVantageColors._(
//       background: Color.lerp(_background, other._background, t)!,
//       backgroundSecondary: Color.lerp(_backgroundSecondary, other._backgroundSecondary, t)!,
//       card: Color.lerp(_card, other._card, t)!,
//       foreground: Color.lerp(_foreground, other._foreground, t)!,
//       foregroundSecondary: Color.lerp(_foregroundSecondary, other._foregroundSecondary, t)!,
//       primary: Color.lerp(_primary, other._primary, t)!,
//       primaryForeground: Color.lerp(_primaryForeground, other._primaryForeground, t)!,
//       accent: Color.lerp(_accent, other._accent, t)!,
//       positive: Color.lerp(_positive, other._positive, t)!,
//       negative: Color.lerp(_negative, other._negative, t)!,
//       warning: Color.lerp(_warning, other._warning, t)!,
//       border: Color.lerp(_border, other._border, t)!,
//       gold: Color.lerp(_gold, other._gold, t)!,
//     );
//   }
//
//   // ==========================================================================
//   // Static forwarding getters – so existing code keeps working
//   // ==========================================================================
//
//   static GoalVantageColors? _current;
//   static GoalVantageColors get current => _current ?? GoalVantageColors.dark;
//   static void setCurrent(GoalVantageColors colors) => _current = colors;
//
//   static Color get background => current._background;
//   static Color get backgroundSecondary => current._backgroundSecondary;
//   static Color get card => current._card;
//   static Color get foreground => current._foreground;
//   static Color get foregroundSecondary => current._foregroundSecondary;
//   static Color get primary => current._primary;
//   static Color get primaryForeground => current._primaryForeground;
//   static Color get accent => current._accent;
//   static Color get positive => current._positive;
//   static Color get negative => current._negative;
//   static Color get warning => current._warning;
//   static Color get border => current._border;
//   static Color get gold => current._gold;
//
//   // ==========================================================================
//   // Helper to access from BuildContext (optional)
//   // ==========================================================================
//
//   static GoalVantageColors of(BuildContext context) =>
//       Theme.of(context).extension<GoalVantageColors>()!;
// }
//
// // ============================================================================
// // GoalVantage HOME SCREEN
// // ============================================================================
//
// class OldHomeScreen extends StatefulWidget {
//   const OldHomeScreen({super.key});
//
//   @override
//   State<OldHomeScreen> createState() => _OldHomeScreenState();
// }
//
// class _OldHomeScreenState extends State<OldHomeScreen> {
//   List<Prediction> _predictions = [];
//   List<Tipster> _tipsters = [];
//   PredictionStats? _stats;
//   bool _isLoading = true;
//   String _activeLeague = 'all';
//
//   StreamSubscription? _predictionsSub;
//   StreamSubscription? _tipstersSub;
//   StreamSubscription? _statsSub;
//
//   final List<Map<String, String>> _leagues = [
//     {'key': 'all', 'label': 'ALL'},
//     {'key': 'epl', 'label': 'EPL'},
//     {'key': 'laliga', 'label': 'LA LIGA'},
//     {'key': 'seriea', 'label': 'SERIE A'},
//     {'key': 'bundesliga', 'label': 'BUNDES'},
//     {'key': 'ligue1', 'label': 'LIGUE 1'},
//     {'key': 'ucl', 'label': 'UCL'},
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _listenToData();
//   }
//
//   @override
//   void dispose() {
//     _predictionsSub?.cancel();
//     _tipstersSub?.cancel();
//     _statsSub?.cancel();
//     super.dispose();
//   }
//
//   void _listenToData() {
//     // Predictions
//     _predictionsSub = FirebaseFirestore.instance
//         .collection('predictions')
//         .orderBy('matchTime')
//         .limit(30)
//         .snapshots()
//         .listen((snapshot) {
//       final predictions = snapshot.docs
//           .map((doc) => Prediction.fromMap(doc.data(), doc.id))
//           .toList();
//
//       if (mounted) {
//         setState(() {
//           _predictions = predictions;
//           _isLoading = false;
//         });
//       }
//     }, onError: (e) {
//       debugPrint('Error loading predictions: $e');
//       if (mounted) setState(() => _isLoading = false);
//     });
//
//     // Tipsters
//     _tipstersSub = FirebaseFirestore.instance
//         .collection('tipsters')
//         .orderBy('accuracy', descending: true)
//         .limit(5)
//         .snapshots()
//         .listen((snapshot) {
//       final tipsters = snapshot.docs
//           .map((doc) => Tipster.fromMap(doc.data(), doc.id))
//           .toList();
//
//       if (mounted) setState(() => _tipsters = tipsters);
//     });
//
//     // Stats
//     _statsSub = FirebaseFirestore.instance
//         .collection('prediction_stats')
//         .doc('overview')
//         .snapshots()
//         .listen((doc) {
//       if (doc.exists) {
//         if (mounted) {
//           setState(() => _stats = PredictionStats.fromMap(doc.data()!));
//         }
//       }
//     });
//   }
//
//   List<Prediction> get _filteredPredictions {
//     if (_activeLeague == 'all') return _predictions;
//     return _predictions.where((p) => p.leagueKey == _activeLeague).toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: GoalVantageColors.background,
//       body: SafeArea(
//         child: CustomScrollView(
//           slivers: [
//             SliverToBoxAdapter(child: _buildHeader()),
//             SliverToBoxAdapter(child: _buildStatsBar()),
//             SliverToBoxAdapter(child: _buildLeagueFilter()),
//             SliverToBoxAdapter(child: _buildPredictionsSection()),
//             SliverToBoxAdapter(child: _buildTipstersSection()),
//             SliverToBoxAdapter(child: _buildHowItWorks()),
//             SliverToBoxAdapter(child: _buildPremiumCta()),
//             SliverToBoxAdapter(child: _buildFooter()),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // HEADER
//   // ==========================================================================
//
//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
//       decoration: BoxDecoration(
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Logo
//           Image.asset("assets/logo.png", width: 250),
//           const SizedBox(height: 24),
//
//           // Heading
//           Text(
//             'READ THE GAME\nBEFORE IT HAPPENS.',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 38,
//               fontWeight: FontWeight.w900,
//               letterSpacing: -1.5,
//               height: 0.95,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'AI-powered football predictions with form analysis, head-to-head stats, and confidence scores across 6 major leagues.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 24),
//
//           // CTA Buttons
//           Row(
//             children: [
//               SizedBox(
//                 height: 48,
//                 child: ElevatedButton(
//                   onPressed: () {},
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: GoalVantageColors.primary,
//                     foregroundColor: GoalVantageColors.primaryForeground,
//                     elevation: 0,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         'VIEW PREDICTIONS',
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w900,
//                           letterSpacing: 1.2,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       const Icon(LucideIcons.arrowRight, size: 14),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               SizedBox(
//                 height: 48,
//                 child: OutlinedButton(
//                   onPressed: () {},
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: GoalVantageColors.foreground,
//                     side: BorderSide(color: GoalVantageColors.border),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//                   ),
//                   child: Text(
//                     'GO PREMIUM',
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // STATS BAR
//   // ==========================================================================
//
//   Widget _buildStatsBar() {
//     final stats = _stats;
//
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.backgroundSecondary,
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: _statItem(
//               stats?.overallAccuracy != null ? '${stats!.overallAccuracy}%' : '—',
//               'ACCURACY',
//               GoalVantageColors.accent,
//             ),
//           ),
//           Container(width: 1, height: 40, color: GoalVantageColors.border),
//           Expanded(
//             child: _statItem(
//               stats?.totalPredictions != null ? '${(stats!.totalPredictions / 1000).toStringAsFixed(1)}K' : '—',
//               'PREDICTIONS',
//               GoalVantageColors.foreground,
//             ),
//           ),
//           Container(width: 1, height: 40, color: GoalVantageColors.border),
//           Expanded(
//             child: _statItem(
//               stats?.matchesToday != null ? '${stats!.matchesToday}' : '—',
//               'MATCHES TODAY',
//               GoalVantageColors.positive,
//             ),
//           ),
//           Container(width: 1, height: 40, color: GoalVantageColors.border),
//           Expanded(
//             child: _statItem(
//               stats?.premiumAccuracy != null ? '${stats!.premiumAccuracy}%' : '—',
//               'PREMIUM ACC',
//               GoalVantageColors.gold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _statItem(String value, String label, Color color) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       child: Column(
//         children: [
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: 20,
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
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // LEAGUE FILTER
//   // ==========================================================================
//
//   Widget _buildLeagueFilter() {
//     return Container(
//       height: 52,
//       decoration: BoxDecoration(
//         color: GoalVantageColors.backgroundSecondary,
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         itemCount: _leagues.length,
//         itemBuilder: (context, index) {
//           final league = _leagues[index];
//           final isActive = _activeLeague == league['key'];
//
//           return Padding(
//             padding: const EdgeInsets.only(right: 6),
//             child: InkWell(
//               onTap: () => setState(() => _activeLeague = league['key']!),
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: isActive ? GoalVantageColors.primary : Colors.transparent,
//                   border: Border.all(
//                     color: isActive ? GoalVantageColors.primary : GoalVantageColors.border,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     league['label']!,
//                     style: TextStyle(
//                       color: isActive ? GoalVantageColors.primaryForeground : GoalVantageColors.foregroundSecondary,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w800,
//                       letterSpacing: 1.0,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // PREDICTIONS SECTION
//   // ==========================================================================
//
//   Widget _buildPredictionsSection() {
//     final predictions = _filteredPredictions;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Icon(LucideIcons.brain, size: 14, color: GoalVantageColors.accent),
//                   const SizedBox(width: 8),
//                   Text(
//                     'AI PREDICTIONS',
//                     style: TextStyle(
//                       color: GoalVantageColors.accent,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.5,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 'TODAY\'S PICKS',
//                 style: TextStyle(
//                   color: GoalVantageColors.foreground,
//                   fontSize: 28,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: -1.0,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         if (_isLoading)
//           const Padding(
//             padding: EdgeInsets.all(32),
//             child: Center(child: CircularProgressIndicator()),
//           )
//         else if (predictions.isEmpty)
//           Padding(
//             padding: const EdgeInsets.all(32),
//             child: Center(
//               child: Text(
//                 'No predictions available for this league.',
//                 style: TextStyle(color: GoalVantageColors.foregroundSecondary),
//               ),
//             ),
//           )
//         else
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             itemCount: predictions.take(10).length,
//             itemBuilder: (context, index) {
//               return _buildPredictionCard(predictions[index]);
//             },
//           ),
//
//         const SizedBox(height: 16),
//       ],
//     );
//   }
//
//   Widget _buildPredictionCard(Prediction pred) {
//     final confidenceColor = pred.confidence >= 80
//         ? GoalVantageColors.positive
//         : pred.confidence >= 65
//         ? GoalVantageColors.warning
//         : GoalVantageColors.foregroundSecondary;
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(
//           color: pred.isPremium ? GoalVantageColors.gold.withOpacity(0.5) : GoalVantageColors.border,
//           width: pred.isPremium ? 1.5 : 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               color: GoalVantageColors.backgroundSecondary,
//               border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//             ),
//             child: Row(
//               children: [
//                 Text(
//                   pred.leagueName.toUpperCase(),
//                   style: TextStyle(
//                     color: GoalVantageColors.accent,
//                     fontSize: 9,
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: 1.2,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   _formatTime(pred.matchTime),
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: 9,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const Spacer(),
//                 if (pred.isPremium) ...[
//                   Icon(LucideIcons.lock, size: 10, color: GoalVantageColors.gold),
//                   const SizedBox(width: 4),
//                   Text(
//                     'PREMIUM',
//                     style: TextStyle(
//                       color: GoalVantageColors.gold,
//                       fontSize: 8,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.0,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//
//           // Match info
//           Padding(
//             padding: const EdgeInsets.all(14),
//             child: Column(
//               children: [
//                 // Teams
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             pred.home,
//                             style: TextStyle(
//                               color: GoalVantageColors.foreground,
//                               fontSize: 14,
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           _formIndicator(pred.homeForm),
//                           const SizedBox(height: 4),
//                           Text(
//                             '#${pred.homePosition}',
//                             style: TextStyle(
//                               color: GoalVantageColors.foregroundSecondary,
//                               fontSize: 10,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: GoalVantageColors.background,
//                         border: Border.all(color: GoalVantageColors.border),
//                       ),
//                       child: Text(
//                         'VS',
//                         style: TextStyle(
//                           color: GoalVantageColors.foregroundSecondary,
//                           fontSize: 10,
//                           fontWeight: FontWeight.w900,
//                           letterSpacing: 1.0,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             pred.away,
//                             style: TextStyle(
//                               color: GoalVantageColors.foreground,
//                               fontSize: 14,
//                               fontWeight: FontWeight.w800,
//                             ),
//                             textAlign: TextAlign.right,
//                           ),
//                           const SizedBox(height: 4),
//                           _formIndicator(pred.awayForm),
//                           const SizedBox(height: 4),
//                           Text(
//                             '#${pred.awayPosition}',
//                             style: TextStyle(
//                               color: GoalVantageColors.foregroundSecondary,
//                               fontSize: 10,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 14),
//
//                 // Prediction
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: GoalVantageColors.background,
//                     border: Border.all(color: GoalVantageColors.border),
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               pred.predictionType.toUpperCase(),
//                               style: TextStyle(
//                                 color: GoalVantageColors.foregroundSecondary,
//                                 fontSize: 8,
//                                 fontWeight: FontWeight.w700,
//                                 letterSpacing: 1.0,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               pred.prediction,
//                               style: TextStyle(
//                                 color: GoalVantageColors.foreground,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w900,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             'CONFIDENCE',
//                             style: TextStyle(
//                               color: GoalVantageColors.foregroundSecondary,
//                               fontSize: 8,
//                               fontWeight: FontWeight.w700,
//                               letterSpacing: 1.0,
//                             ),
//                           ),
//                           const SizedBox(height: 2),
//                           Text(
//                             '${pred.confidence}%',
//                             style: TextStyle(
//                               color: confidenceColor,
//                               fontSize: 18,
//                               fontWeight: FontWeight.w900,
//                               fontFeatures: const [FontFeature.tabularFigures()],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(width: 16),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             'ODDS',
//                             style: TextStyle(
//                               color: GoalVantageColors.foregroundSecondary,
//                               fontSize: 8,
//                               fontWeight: FontWeight.w700,
//                               letterSpacing: 1.0,
//                             ),
//                           ),
//                           const SizedBox(height: 2),
//                           Text(
//                             pred.odds.toStringAsFixed(2),
//                             style: TextStyle(
//                               color: GoalVantageColors.accent,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w900,
//                               fontFeatures: const [FontFeature.tabularFigures()],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//
//
//
//           // Header
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               color: GoalVantageColors.backgroundSecondary,
//               border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//             ),
//             child: Row(
//               children: [
//                 Text(
//                   pred.leagueName.toUpperCase(),
//                   style: TextStyle(
//                     color: GoalVantageColors.accent,
//                     fontSize: 9,
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: 1.2,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   _formatTime(pred.matchTime),
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: 9,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const Spacer(),
//                 if (pred.isPremium) ...[
//                   Icon(LucideIcons.lock, size: 10, color: GoalVantageColors.gold),
//                   const SizedBox(width: 4),
//                   Text(
//                     'PREMIUM',
//                     style: TextStyle(
//                       color: GoalVantageColors.gold,
//                       fontSize: 8,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.0,
//                     ),
//                   ),
//                   const SizedBox(width: 10),  // 👈 Add spacing before subscribe button
//                 ],
//                 // 👇 THIS IS THE ONLY LINE YOU NEED TO ADD
//                 _buildSubscribeButton(pred),
//               ],
//             ),
//           ),
//
//
//         ],
//       ),
//     );
//   }
//
//   Widget _formIndicator(List<String> form) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: form.map((result) {
//         final color = result == 'W'
//             ? GoalVantageColors.positive
//             : result == 'D'
//             ? GoalVantageColors.warning
//             : GoalVantageColors.negative;
//         return Container(
//           width: 16,
//           height: 16,
//           margin: const EdgeInsets.only(right: 3),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             border: Border.all(color: color.withOpacity(0.5)),
//           ),
//           child: Center(
//             child: Text(
//               result,
//               style: TextStyle(
//                 color: color,
//                 fontSize: 8,
//                 fontWeight: FontWeight.w900,
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   String _formatTime(DateTime time) {
//     final now = DateTime.now();
//     final diff = time.difference(now);
//
//     if (diff.inDays > 0) {
//       return 'In ${diff.inDays}d';
//     } else if (diff.inHours > 0) {
//       return 'In ${diff.inHours}h';
//     } else if (diff.inMinutes > 0) {
//       return 'In ${diff.inMinutes}m';
//     } else {
//       return 'LIVE';
//     }
//   }
//
//   // ==========================================================================
//   // TIPSTERS SECTION
//   // ==========================================================================
//
//   Widget _buildTipstersSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             border: Border(top: BorderSide(color: GoalVantageColors.border)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Icon(LucideIcons.trophy, size: 14, color: GoalVantageColors.gold),
//                   const SizedBox(width: 8),
//                   Text(
//                     'TOP TIPSTERS',
//                     style: TextStyle(
//                       color: GoalVantageColors.gold,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.5,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 'LEADERBOARD',
//                 style: TextStyle(
//                   color: GoalVantageColors.foreground,
//                   fontSize: 28,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: -1.0,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         if (_tipsters.isNotEmpty)
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             itemCount: _tipsters.length,
//             itemBuilder: (context, index) {
//               final tipster = _tipsters[index];
//               return _buildTipsterRow(tipster, index + 1);
//             },
//           ),
//
//         const SizedBox(height: 16),
//       ],
//     );
//   }
//
//   Widget _buildTipsterRow(Tipster tipster, int rank) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(
//           color: rank <= 3 ? GoalVantageColors.gold.withOpacity(0.3) : GoalVantageColors.border,
//         ),
//       ),
//       child: Row(
//         children: [
//           // Rank
//           Container(
//             width: 28,
//             height: 28,
//             decoration: BoxDecoration(
//               color: rank <= 3 ? GoalVantageColors.gold : GoalVantageColors.background,
//               border: Border.all(color: GoalVantageColors.border),
//             ),
//             child: Center(
//               child: Text(
//                 '$rank',
//                 style: TextStyle(
//                   color: rank <= 3 ? GoalVantageColors.background : GoalVantageColors.foreground,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           // Info
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Flexible(
//                       child: Text(
//                         tipster.name,
//                         style: TextStyle(
//                           color: GoalVantageColors.foreground,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w800,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     if (tipster.isVerified) ...[
//                       const SizedBox(width: 4),
//                       Icon(LucideIcons.badgeCheck, size: 12, color: GoalVantageColors.accent),
//                     ],
//                   ],
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   '${tipster.specialty} · ROI +${tipster.roi}%',
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Accuracy
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 '${tipster.accuracy}%',
//                 style: TextStyle(
//                   color: GoalVantageColors.positive,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w900,
//                   fontFeatures: const [FontFeature.tabularFigures()],
//                 ),
//               ),
//               Text(
//                 'ACCURACY',
//                 style: TextStyle(
//                   color: GoalVantageColors.foregroundSecondary,
//                   fontSize: 8,
//                   fontWeight: FontWeight.w700,
//                   letterSpacing: 0.8,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // HOW IT WORKS
//   // ==========================================================================
//
//   Widget _buildHowItWorks() {
//     final steps = [
//       {'icon': LucideIcons.database, 'title': 'Data Collection', 'desc': 'We analyze 50+ data points per match: form, H2H, injuries, weather, and more.'},
//       {'icon': LucideIcons.brain, 'title': 'AI Analysis', 'desc': 'Our machine learning models process historical data to identify patterns and probabilities.'},
//       {'icon': LucideIcons.target, 'title': 'Prediction', 'desc': 'Each prediction comes with a confidence score and recommended odds threshold.'},
//       {'icon': LucideIcons.checkCircle, 'title': 'Verification', 'desc': 'All predictions are tracked and verified. Our accuracy is publicly auditable.'},
//     ];
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             border: Border(top: BorderSide(color: GoalVantageColors.border)),
//           ),
//           child: Column(
//             children: [
//               Row(
//                 children: [
//                   Icon(LucideIcons.info, size: 14, color: GoalVantageColors.accent),
//                   const SizedBox(width: 8),
//                   Text(
//                     'METHODOLOGY',
//                     style: TextStyle(
//                       color: GoalVantageColors.accent,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.5,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 'HOW GOALVANTAGE WORKS',
//                 style: TextStyle(
//                   color: GoalVantageColors.foreground,
//                   fontSize: 28,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: -1.0,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: steps.asMap().entries.map((entry) {
//               final index = entry.key;
//               final step = entry.value;
//               return Padding(
//                 padding: const EdgeInsets.only(bottom: 12),
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: GoalVantageColors.card,
//                     border: Border.all(color: GoalVantageColors.border),
//                   ),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '0${index + 1}',
//                         style: TextStyle(
//                           color: GoalVantageColors.primary.withOpacity(0.3),
//                           fontSize: 32,
//                           fontWeight: FontWeight.w900,
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               step['title'] as String,    // <-- fixed cast
//                               style: TextStyle(
//                                 color: GoalVantageColors.foreground,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w800,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               step['desc'] as String,     // <-- fixed cast
//                               style: TextStyle(
//                                 color: GoalVantageColors.foregroundSecondary,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w500,
//                                 height: 1.4,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         width: 36,
//                         height: 36,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: GoalVantageColors.primary, width: 1.5),
//                         ),
//                         child: Icon(step['icon'] as IconData, size: 16, color: GoalVantageColors.primary),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ==========================================================================
//   // PREMIUM CTA
//   // ==========================================================================
//
//   Widget _buildPremiumCta() {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(color: GoalVantageColors.gold, width: 2),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(LucideIcons.crown, size: 16, color: GoalVantageColors.gold),
//               const SizedBox(width: 8),
//               Text(
//                 'GOALVANTAGE PREMIUM',
//                 style: TextStyle(
//                   color: GoalVantageColors.gold,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.5,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'UNLOCK THE FULL PICTURE.',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 24,
//               fontWeight: FontWeight.w900,
//               letterSpacing: -0.8,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'Premium members get higher-confidence picks, detailed statistical breakdowns, injury updates, and exclusive tipster access.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//               height: 1.5,
//             ),
//           ),
//           const SizedBox(height: 16),
//           // Benefits
//           ...[
//             'Higher confidence predictions (80%+)',
//             'Detailed match analysis & stats',
//             'Injury & suspension alerts',
//             'Exclusive premium tipsters',
//             'Ad-free experience',
//           ].map((benefit) => Padding(
//             padding: const EdgeInsets.only(bottom: 6),
//             child: Row(
//               children: [
//                 Icon(LucideIcons.check, size: 12, color: GoalVantageColors.gold),
//                 const SizedBox(width: 8),
//                 Text(
//                   benefit,
//                   style: TextStyle(
//                     color: GoalVantageColors.foreground,
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           )),
//           const SizedBox(height: 20),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton(
//               onPressed: () {},
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: GoalVantageColors.gold,
//                 foregroundColor: GoalVantageColors.background,
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     'START FREE TRIAL',
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w900,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   const Icon(LucideIcons.arrowRight, size: 14),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // FOOTER
//   // ==========================================================================
//
//   Widget _buildFooter() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.backgroundSecondary,
//         border: Border(top: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Column(
//         children: [
//           Image.asset("assets/logo.png", width: 190),
//           const SizedBox(height: 8),
//           Text(
//             'Read the Game Before It Happens',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             '© 2026 GoalVantage. All rights reserved.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 9,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==========================================================================
//   // SUBSCRIBE BUTTON (unchanged)
//   // ==========================================================================
//
//   Widget _buildSubscribeButton(Prediction pred) {
//     return InkWell(
//       onTap: () => _quickSubscribe(pred),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//         decoration: BoxDecoration(
//           color: GoalVantageColors.primary.withOpacity(0.12),
//           border: Border.all(color: GoalVantageColors.primary.withOpacity(0.3)),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(LucideIcons.bell, size: 10, color: GoalVantageColors.primary),
//             const SizedBox(width: 4),
//             Text(
//               'SUBSCRIBE',
//               style: TextStyle(
//                 color: GoalVantageColors.primary,
//                 fontSize: 8,
//                 fontWeight: FontWeight.w900,
//                 letterSpacing: 1.0,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _quickSubscribe(Prediction pred) async {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return;
//
//     final sub = {
//       'uid': uid,
//       'type': 'odds_movement',
//       'scope': 'league',
//       'scopeId': pred.leagueKey,
//       'scopeLabel': pred.leagueName,
//       'delivery': ['push', 'in_app'],
//       'frequency': 'realtime',
//       'filters': {'minOddsChange': 0.10, 'minConfidence': 70},
//       'isActive': true,
//       'createdAt': FieldValue.serverTimestamp(),
//       'synthetic': true,
//     };
//
//     try {
//       await FirebaseFirestore.instance.collection('user_subscriptions').add(sub);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: GoalVantageColors.positive,
//           content: Text('Subscribed to ${pred.leagueName} odds movements'),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: GoalVantageColors.negative,
//           content: Text('Error: $e'),
//         ),
//       );
//     }
//   }
// }