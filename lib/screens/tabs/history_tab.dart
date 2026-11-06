// lib/features/pitchiq/tabs/history_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../models/prediction.dart';
import '../../theme/colors.dart' hide Prediction;

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Prediction> _history = [];
  bool _isLoading = true;
  String? _loadError;
  String _statusFilter = 'all'; // 'all', 'correct', 'wrong', 'pending'
  DateTime? _lastUpdated;

  final List<Map<String, String>> _filters = [
    {'key': 'all', 'label': 'ALL'},
    {'key': 'correct', 'label': 'WON'},
    {'key': 'wrong', 'label': 'LOST'},
    {'key': 'pending', 'label': 'PENDING'},
  ];

  @override
  void initState() {
    super.initState();
    _listenToHistory();
  }

  void _listenToHistory() {
    // Fetches ALL settled predictions (both Free and Premium) to build public trust
    FirebaseFirestore.instance
        .collection('predictions')
        .where('status', isEqualTo: 'settled')
        .orderBy('matchTime', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      final history = snapshot.docs
          .map((doc) => Prediction.fromMap(doc.data(), doc.id))
          .toList();
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
          _loadError = null;
          _lastUpdated = DateTime.now();
        });
      }
    }, onError: (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    });
  }

  List<Prediction> get _filteredHistory {
    if (_statusFilter == 'all') return _history;
    if (_statusFilter == 'pending') {
      return _history.where((p) => p.isCorrect == null).toList();
    }
    if (_statusFilter == 'correct') {
      return _history.where((p) => p.isCorrect == true).toList();
    }
    return _history.where((p) => p.isCorrect == false).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildFilterTabs()),
        if (_isLoading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildLoadError(),
          )
        else if (_filteredHistory.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildHistoryCard(_filteredHistory[index]),
                childCount: _filteredHistory.length,
              ),
            ),
          ),
        if (!_isLoading && _filteredHistory.isNotEmpty)
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
  }

  String _formatLastUpdated(DateTime? time) {
    if (time == null) return 'just now';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ---------------------- UI Components ----------------------

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Column(
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
          SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.history, size: 14, color: GoalVantageColors.accent),
              SizedBox(width: 8),
              Text(
                'PUBLIC TRACK RECORD',
                style: TextStyle(
                  color: GoalVantageColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          SizedBox(height: 12),
          Text(
            'PAST PREDICTIONS',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Every prediction we\'ve made, with verified results and final odds. Visible to everyone.',
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

  Widget _buildFilterTabs() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GoalVantageColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
      ),
      child: Row(
        children: _filters.map((filter) {
          final isActive = _statusFilter == filter['key'];
          final count = filter['key'] == 'all'
              ? _history.length
              : filter['key'] == 'pending'
              ? _history.where((p) => p.isCorrect == null).length
              : filter['key'] == 'correct'
              ? _history.where((p) => p.isCorrect == true).length
              : _history.where((p) => p.isCorrect == false).length;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => setState(() => _statusFilter = filter['key']!),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? GoalVantageColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isActive ? GoalVantageColors.primary : GoalVantageColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isActive ? Colors.white : GoalVantageColors.foregroundSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: isActive ? Colors.white.withOpacity(0.8) : GoalVantageColors.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
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
    );
  }

  Widget _buildHistoryCard(Prediction pred) {
    final resultColor = pred.isCorrect == true
        ? GoalVantageColors.positive
        : pred.isCorrect == false
        ? GoalVantageColors.negative
        : GoalVantageColors.warning;

    final resultLabel = pred.isCorrect == true
        ? 'WON'
        : pred.isCorrect == false
        ? 'LOST'
        : 'PENDING';

    // Safe string conversions
    final leagueName = (pred.leagueName.isNotEmpty ? pred.leagueName : pred.leagueKey).toUpperCase();
    final homeTeam = pred.home;
    final awayTeam = pred.away;
    final predType = pred.predictionType;
    final predPick = pred.prediction;

    // Odds formatting
    final oddsText = pred.odds.toStringAsFixed(2);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GoalVantageColors.card,
        border: Border.all(
          color: pred.isCorrect != null
              ? resultColor.withOpacity(0.3)
              : GoalVantageColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                leagueName,
                style: TextStyle(
                  color: GoalVantageColors.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(width: 8),
              Text(
                _formatDate(pred.matchTime),
                style: TextStyle(
                  color: GoalVantageColors.foregroundSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.15),
                  border: Border.all(color: resultColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pred.isCorrect == true
                          ? LucideIcons.checkCircle
                          : pred.isCorrect == false
                          ? LucideIcons.xCircle
                          : LucideIcons.clock,
                      size: 9,
                      color: resultColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      resultLabel,
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Match
          Text(
            '$homeTeam vs $awayTeam',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),

          // Prediction details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$predType: $predPick',
                      style: TextStyle(
                        color: GoalVantageColors.foregroundSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    // Display odds and confidence
                    Row(
                      children: [
                        Text(
                          'Odds: $oddsText',
                          style: TextStyle(
                            color: GoalVantageColors.foregroundSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Confidence: ${pred.confidence}%',
                          style: TextStyle(
                            color: GoalVantageColors.foregroundSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (pred.result != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Actual result: ${pred.result}',
                          style: TextStyle(
                            color: GoalVantageColors.foregroundSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (pred.isPremium)
                Icon(LucideIcons.crown, size: 12, color: GoalVantageColors.gold),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic matchTime) {
    if (matchTime == null) return 'Unknown Date';
    try {
      final date = matchTime is Timestamp ? matchTime.toDate() : (matchTime as DateTime);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (e) {
      return 'Unknown Date';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.history, size: 48, color: GoalVantageColors.foregroundSecondary),
          SizedBox(height: 16),
          Text(
            'NO HISTORY YET',
            style: TextStyle(
              color: GoalVantageColors.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Settled predictions will appear here.',
            style: TextStyle(
              color: GoalVantageColors.foregroundSecondary,
              fontSize: 12,
            ),
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
          'Could not load prediction history.\n$_loadError',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: GoalVantageColors.negative,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}












// // lib/features/pitchiq/tabs/history_tab.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:lucide_icons_flutter/lucide_icons.dart';
// import '../../theme/app_colors.dart';
// import '../../models/prediction.dart';
// import '../../theme/colors.dart' hide Prediction;
//
// class HistoryTab extends StatefulWidget {
//   HistoryTab({super.key});
//
//   @override
//   State<HistoryTab> createState() => _HistoryTabState();
// }
//
// class _HistoryTabState extends State<HistoryTab> {
//   List<Prediction> _history = [];
//   bool _isLoading = true;
//   String _statusFilter = 'all'; // 'all', 'correct', 'wrong', 'pending'
//   DateTime? _lastUpdated;
//
//   final List<Map<String, String>> _filters = [
//     {'key': 'all', 'label': 'ALL'},
//     {'key': 'correct', 'label': 'WON'},
//     {'key': 'wrong', 'label': 'LOST'},
//     {'key': 'pending', 'label': 'PENDING'},
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _listenToHistory();
//   }
//
//   void _listenToHistory() {
//     FirebaseFirestore.instance
//         .collection('predictions')
//         .where('status', isEqualTo: 'settled')
//         .orderBy('matchTime', descending: true)
//         .limit(100)
//         .snapshots()
//         .listen((snapshot) {
//       final history = snapshot.docs
//           .map((doc) => Prediction.fromMap(doc.data(), doc.id))
//           .toList();
//       if (mounted) {
//         setState(() {
//           _history = history;
//           _isLoading = false;
//           _lastUpdated = DateTime.now();
//         });
//       }
//     }, onError: (e) {
//       if (mounted) setState(() => _isLoading = false);
//     });
//   }
//
//   List<Prediction> get _filteredHistory {
//     if (_statusFilter == 'all') return _history;
//     if (_statusFilter == 'pending') {
//       return _history.where((p) => p.isCorrect == null).toList();
//     }
//     if (_statusFilter == 'correct') {
//       return _history.where((p) => p.isCorrect == true).toList();
//     }
//     return _history.where((p) => p.isCorrect == false).toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return CustomScrollView(
//       slivers: [
//         SliverToBoxAdapter(child: _buildHeader()),
//         SliverToBoxAdapter(child: _buildFilterTabs()),
//         if (_isLoading)
//           SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
//         else if (_filteredHistory.isEmpty)
//           SliverFillRemaining(child: _buildEmptyState())
//         else
//           SliverPadding(
//             padding: EdgeInsets.all(16),
//             sliver: SliverList(
//               delegate: SliverChildBuilderDelegate(
//                     (context, index) => _buildHistoryCard(_filteredHistory[index]),
//                 childCount: _filteredHistory.length,
//               ),
//             ),
//           ),
//         // Last updated footer (optional)
//         if (!_isLoading && _filteredHistory.isNotEmpty)
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: EdgeInsets.only(bottom: 24),
//               child: Center(
//                 child: Text(
//                   'Last updated: ${_formatLastUpdated(_lastUpdated)}',
//                   style: TextStyle(
//                     color: GoalVantageColors.foregroundSecondary,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
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
//
//   // ---------------------- UI Components ----------------------
//
//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
//       decoration: BoxDecoration(
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Image.asset("assets/logo.png", width: 250),
//           SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(LucideIcons.history, size: 14, color: GoalVantageColors.accent),
//               SizedBox(width: 8),
//               Text(
//                 'PREDICTION HISTORY',
//                 style: TextStyle(
//                   color: GoalVantageColors.accent,
//                   fontSize: 10,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.5,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           Text(
//             'PAST PICKS',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 28,
//               fontWeight: FontWeight.w900,
//               letterSpacing: -1.0,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Every prediction we\'ve made, with verified results and final odds.',
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
//   Widget _buildFilterTabs() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.backgroundSecondary,
//         border: Border(bottom: BorderSide(color: GoalVantageColors.border)),
//       ),
//       child: Row(
//         children: _filters.map((filter) {
//           final isActive = _statusFilter == filter['key'];
//           final count = filter['key'] == 'all'
//               ? _history.length
//               : filter['key'] == 'pending'
//               ? _history.where((p) => p.isCorrect == null).length
//               : filter['key'] == 'correct'
//               ? _history.where((p) => p.isCorrect == true).length
//               : _history.where((p) => p.isCorrect == false).length;
//
//           return Expanded(
//             child: Padding(
//               padding: EdgeInsets.symmetric(horizontal: 3),
//               child: InkWell(
//                 onTap: () => setState(() => _statusFilter = filter['key']!),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(vertical: 10),
//                   decoration: BoxDecoration(
//                     color: isActive ? GoalVantageColors.primary : Colors.transparent,
//                     border: Border.all(
//                       color: isActive ? GoalVantageColors.primary : GoalVantageColors.border,
//                     ),
//                   ),
//                   child: Column(
//                     children: [
//                       Text(
//                         filter['label']!,
//                         style: TextStyle(
//                           color: isActive
//                               ? GoalVantageColors.primaryForeground
//                               : GoalVantageColors.foregroundSecondary,
//                           fontSize: 10,
//                           fontWeight: FontWeight.w900,
//                           letterSpacing: 0.8,
//                         ),
//                       ),
//                       SizedBox(height: 2),
//                       Text(
//                         '$count',
//                         style: TextStyle(
//                           color: isActive
//                               ? GoalVantageColors.primaryForeground.withOpacity(0.8)
//                               : GoalVantageColors.foreground,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w800,
//                           fontFeatures: [FontFeature.tabularFigures()],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildHistoryCard(Prediction pred) {
//     final resultColor = pred.isCorrect == true
//         ? GoalVantageColors.positive
//         : pred.isCorrect == false
//         ? GoalVantageColors.negative
//         : GoalVantageColors.warning;
//
//     final resultLabel = pred.isCorrect == true
//         ? 'WON'
//         : pred.isCorrect == false
//         ? 'LOST'
//         : 'PENDING';
//
//     // Safe string conversions
//     final leagueName = (pred.leagueName ?? pred.leagueKey ?? 'LEAGUE').toString().toUpperCase();
//     final homeTeam = (pred.home).toString();
//     final awayTeam = (pred.away).toString();
//     final predType = (pred.predictionType ?? 'Prediction').toString();
//     final predPick = (pred.prediction ?? 'AI Pick').toString();
//
//     // Odds formatting
//     final oddsText = pred.odds != null
//         ? pred.odds!.toStringAsFixed(2)
//         : '—';
//
//     return Container(
//       margin: EdgeInsets.only(bottom: 10),
//       padding: EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: GoalVantageColors.card,
//         border: Border.all(
//           color: pred.isCorrect != null
//               ? resultColor.withOpacity(0.3)
//               : GoalVantageColors.border,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header row
//           Row(
//             children: [
//               Text(
//                 leagueName,
//                 style: TextStyle(
//                   color: GoalVantageColors.accent,
//                   fontSize: 9,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//               SizedBox(width: 8),
//               Text(
//                 _formatDate(pred.matchTime),
//                 style: TextStyle(
//                   color: GoalVantageColors.foregroundSecondary,
//                   fontSize: 9,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               Spacer(),
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: resultColor.withOpacity(0.15),
//                   border: Border.all(color: resultColor.withOpacity(0.4)),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       pred.isCorrect == true
//                           ? LucideIcons.checkCircle
//                           : pred.isCorrect == false
//                           ? LucideIcons.xCircle
//                           : LucideIcons.clock,
//                       size: 9,
//                       color: resultColor,
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       resultLabel,
//                       style: TextStyle(
//                         color: resultColor,
//                         fontSize: 8,
//                         fontWeight: FontWeight.w900,
//                         letterSpacing: 1.0,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//
//           // Match
//           Text(
//             '$homeTeam vs $awayTeam',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 13,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           SizedBox(height: 6),
//
//           // Prediction details
//           Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       '$predType: $predPick',
//                       style: TextStyle(
//                         color: GoalVantageColors.foregroundSecondary,
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     SizedBox(height: 2),
//                     // Display odds and confidence
//                     Row(
//                       children: [
//                         Text(
//                           'Odds: $oddsText',
//                           style: TextStyle(
//                             color: GoalVantageColors.foregroundSecondary,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Text(
//                           'Confidence: ${pred.confidence ?? 0}%',
//                           style: TextStyle(
//                             color: GoalVantageColors.foregroundSecondary,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (pred.result != null)
//                       Padding(
//                         padding: EdgeInsets.only(top: 4),
//                         child: Text(
//                           'Actual result: ${pred.result}',
//                           style: TextStyle(
//                             color: GoalVantageColors.foregroundSecondary,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               if (pred.isPremium)
//                 Icon(LucideIcons.crown, size: 12, color: GoalVantageColors.gold),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _formatDate(DateTime date) {
//     final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
//     return '${months[date.month - 1]} ${date.day}';
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(LucideIcons.history, size: 48, color: GoalVantageColors.foregroundSecondary.withOpacity(0.4)),
//           SizedBox(height: 16),
//           Text(
//             'NO HISTORY YET',
//             style: TextStyle(
//               color: GoalVantageColors.foreground,
//               fontSize: 16,
//               fontWeight: FontWeight.w900,
//               letterSpacing: 1.0,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Settled predictions will appear here.',
//             style: TextStyle(
//               color: GoalVantageColors.foregroundSecondary,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
//
//
