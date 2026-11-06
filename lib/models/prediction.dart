import 'package:cloud_firestore/cloud_firestore.dart';

class Prediction {
  final String id;
  final String leagueKey;
  final String leagueName;
  final String country;
  final String home;
  final String away;
  final DateTime matchTime;
  final String predictionType;
  final String prediction;
  final double confidence;
  final double odds;
  final List<String> homeForm;
  final List<String> awayForm;
  final int homePosition;
  final int awayPosition;
  final int h2hHomeWins;
  final int h2hDraws;
  final int h2hAwayWins;
  final bool isPremium;
  final String status; // 'upcoming', 'live', 'settled'
  final bool? isCorrect; // null = pending, true = won, false = lost
  final String? result;        // actual match result, e.g., "2-1"
  final String? tipsterName;
  final DateTime? settledAt;

  Prediction({
    required this.id,
    required this.leagueKey,
    required this.leagueName,
    required this.country,
    required this.home,
    required this.away,
    required this.matchTime,
    required this.predictionType,
    required this.prediction,
    required this.confidence,
    required this.odds,
    required this.homeForm,
    required this.awayForm,
    required this.homePosition,
    required this.awayPosition,
    required this.h2hHomeWins,
    required this.h2hDraws,
    required this.h2hAwayWins,
    required this.isPremium,
    required this.status,
    this.isCorrect,
    this.result,
    this.tipsterName,
    this.settledAt,
  });

  factory Prediction.fromMap(Map<String, dynamic> map, String docId) {
    return Prediction(
      id: docId,
      leagueKey: _stringValue(map['leagueKey']),
      leagueName: _stringValue(map['leagueName']),
      country: _stringValue(map['country']),
      home: _stringValue(map['home'], fallback: 'Home'),
      away: _stringValue(map['away'], fallback: 'Away'),
      matchTime: _dateValue(map['matchTime']) ?? DateTime.now(),
      predictionType: _stringValue(map['predictionType'], fallback: 'Match Result'),
      prediction: _stringValue(map['prediction']),
      confidence: _numberValue(map['confidence']),
      odds: _numberValue(map['odds']),
      homeForm: _stringList(map['homeForm']),
      awayForm: _stringList(map['awayForm']),
      homePosition: _numberValue(map['homePosition']).toInt(),
      awayPosition: _numberValue(map['awayPosition']).toInt(),
      h2hHomeWins: _numberValue(map['h2hHomeWins']).toInt(),
      h2hDraws: _numberValue(map['h2hDraws']).toInt(),
      h2hAwayWins: _numberValue(map['h2hAwayWins']).toInt(),
      isPremium: map['isPremium'] == true,
      status: _stringValue(map['status'], fallback: 'upcoming'),
      isCorrect: map['isCorrect'] is bool ? map['isCorrect'] as bool : null,
      result: map['result']?.toString(),
      tipsterName: map['tipsterName']?.toString(),
      settledAt: _dateValue(map['settledAt']),
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    return value?.toString() ?? fallback;
  }

  static double _numberValue(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return [];
    return value.map((item) => item.toString()).toList();
  }

  Map<String, dynamic> toMap() => {
    'leagueKey': leagueKey,
    'leagueName': leagueName,
    'country': country,
    'home': home,
    'away': away,
    'matchTime': Timestamp.fromDate(matchTime),
    'predictionType': predictionType,
    'prediction': prediction,
    'confidence': confidence,
    'odds': odds,
    'homeForm': homeForm,
    'awayForm': awayForm,
    'homePosition': homePosition,
    'awayPosition': awayPosition,
    'h2hHomeWins': h2hHomeWins,
    'h2hDraws': h2hDraws,
    'h2hAwayWins': h2hAwayWins,
    'isPremium': isPremium,
    'status': status,
    'isCorrect': isCorrect,
    'result': result,
    'tipsterName': tipsterName,
    'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
  };

// Remove the dummy getters below – they are not needed
// Object? get homeTeam => null;
// Object? get awayTeam => null;
// Object? get league => null;
}