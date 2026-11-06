import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

Future<void> openPublicProfile(BuildContext context, String identity) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(identity: identity),
      ),
    );

class PublicProfileScreen extends StatefulWidget {
  final String identity;
  PublicProfileScreen({super.key, required this.identity});
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? result;
    final firestore = FirebaseFirestore.instance;
    final target = widget.identity.trim().toLowerCase();
    try {
      final profiles = firestore.collection('public_profiles');
      final direct = await profiles.doc(widget.identity).get();
      result = direct.data();
      if (result == null) {
        final alias = await profiles
            .where('aliases', arrayContains: target)
            .limit(1)
            .get();
        if (alias.docs.isNotEmpty) result = alias.docs.first.data();
      }
    } catch (_) {
      /* Legacy collections remain available during rules rollout. */
    }
    if (result == null) {
      for (final source in [
        'copy_traders',
        'community_members',
        'alpha_wallets',
      ]) {
        try {
          final snapshot = await firestore.collection(source).get();
          for (final document in snapshot.docs) {
            final data = document.data();
            final identities = [
              document.id,
              data['displayName'],
              data['username'],
              data['label'],
              data['address'],
            ].map((value) => value?.toString().toLowerCase());
            if (identities.contains(target)) {
              result = {
                ...data,
                'profileId': document.id,
                'type': source == 'copy_traders'
                    ? 'trader'
                    : source == 'alpha_wallets'
                    ? 'wallet'
                    : 'member',
              };
              break;
            }
          }
          if (result != null) break;
        } catch (_) {}
      }
    }
    if (result == null) {
      try {
        result =
            (await firestore.collection('users').doc(widget.identity).get())
                .data();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _profile = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final p = _profile;
    if (p == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Text(
            'Profile not found',
            style: TextStyle(color: AppColors.foreground),
          ),
        ),
      );
    }
    final name = (p['displayName'] ?? p['username'] ?? 'AuraTrades member')
        .toString();
    final image = (p['imageUrl'] ?? p['photoURL'] ?? '').toString();
    final isTrader = p['type'] == 'trader' || p['type'] == 'wallet';
    final trades = List<Map<String, dynamic>>.from(
      (p['runningTrades'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final performance = List<double>.from(
      (p['performanceData'] as List? ?? [100, 104, 108, 115, 121, 129])
          .map((value) => (value as num).toDouble()),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        title: Text('Public Profile'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: _card(),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.auraGradient,
                    image: image.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(image),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: image.isEmpty
                      ? Center(
                          child: Text(
                            name
                                .substring(0, name.length >= 2 ? 2 : 1)
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (p['verified'] == true || p['isVerified'] == true)
                            Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                LucideIcons.badgeCheck,
                                size: 17,
                                color: AppColors.secondary,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Text(
                        isTrader
                            ? 'Verified on-chain trader'
                            : 'AuraTrades community member',
                        style: TextStyle(
                          color: AppColors.foregroundSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isTrader)
                _metric(
                  'Win Rate',
                  '${((p['winRate'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                  LucideIcons.target,
                ),
              _metric(
                isTrader ? 'Copiers' : 'Reputation',
                '${p[isTrader ? 'copiers' : 'reputation'] ?? 0}',
                LucideIcons.users,
              ),
              if (isTrader) ...[
                _metric(
                  'Strategy',
                  '${p['strategy'] ?? 'Momentum'}',
                  LucideIcons.activity,
                ),
                _metric(
                  'Open Trades',
                  '${trades.length}',
                  LucideIcons.lineChart,
                ),
              ] else ...[
                _metric('Level', '${p['level'] ?? 1}', LucideIcons.award),
                _metric(
                  'Posts',
                  '${p['posts'] ?? 0}',
                  LucideIcons.messageCircle,
                ),
                _metric(
                  'Followers',
                  '${p['followers'] ?? 0}',
                  LucideIcons.users,
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: _card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ABOUT',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  (p['description'] ?? 'AuraTrades community member.')
                      .toString(),
                  style: TextStyle(
                    color: AppColors.foregroundSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isTrader) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: _card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNT GROWTH · 30D',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _GrowthPainter(performance),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: _card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'RUNNING TRADES',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (trades.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Text(
                        'No public positions right now.',
                        style: TextStyle(color: AppColors.foregroundSecondary),
                      ),
                    )
                  else
                    ...trades.map(
                      (trade) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (trade['tokenImageUrl']?.toString().isNotEmpty ??
                                  false)
                              ? NetworkImage(trade['tokenImageUrl'])
                              : null,
                          child:
                              (trade['tokenImageUrl']?.toString().isEmpty ??
                                  true)
                              ? Text('${trade['token'] ?? ''}'.substring(0, 1))
                              : null,
                        ),
                        title: Text(
                          '${trade['token'] ?? trade['symbol']}',
                          style: TextStyle(
                            color: AppColors.foreground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${trade['chain']} · ${trade['dexName']}',
                          style: TextStyle(
                            color: AppColors.foregroundSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Text(
                          'OPEN',
                          style: TextStyle(
                            color: AppColors.positive,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _card() => BoxDecoration(
    color: AppColors.card.withValues(alpha: .72),
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(18),
  );
  Widget _metric(String label, String value, IconData icon) => Container(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    padding: EdgeInsets.all(14),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.foreground,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.foregroundSecondary,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _GrowthPainter extends CustomPainter {
  final List<double> values;
  _GrowthPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        i / (values.length - 1) * size.width,
        size.height - (values[i] - minValue) / range * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.positive
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter oldDelegate) =>
      oldDelegate.values != values;
}
