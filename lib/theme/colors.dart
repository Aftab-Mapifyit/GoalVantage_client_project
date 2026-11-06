// ============================================================================
// GoalVantage COLORS (ThemeExtension with light/dark support)
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


// ============================================================================
// MODELS
// ============================================================================

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
  final String status;
  final bool? isCorrect;

  Prediction.fromMap(Map<String, dynamic> map, String docId)
      : id = docId,
        leagueKey = map['leagueKey'] ?? '',
        leagueName = map['leagueName'] ?? '',
        country = map['country'] ?? '',
        home = map['home'] ?? 'Home',
        away = map['away'] ?? 'Away',
        matchTime = (map['matchTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        predictionType = map['predictionType'] ?? 'Match Result',
        prediction = map['prediction'] ?? '',
        confidence = (map['confidence'] as num?)?.toDouble() ?? 0,
        odds = (map['odds'] as num?)?.toDouble() ?? 0,
        homeForm = List<String>.from(map['homeForm'] ?? []),
        awayForm = List<String>.from(map['awayForm'] ?? []),
        homePosition = (map['homePosition'] as num?)?.toInt() ?? 0,
        awayPosition = (map['awayPosition'] as num?)?.toInt() ?? 0,
        h2hHomeWins = (map['h2hHomeWins'] as num?)?.toInt() ?? 0,
        h2hDraws = (map['h2hDraws'] as num?)?.toInt() ?? 0,
        h2hAwayWins = (map['h2hAwayWins'] as num?)?.toInt() ?? 0,
        isPremium = map['isPremium'] ?? false,
        status = map['status'] ?? 'upcoming',
        isCorrect = map['isCorrect'];
}

class Tipster {
  final String id;
  final String name;
  final double accuracy;
  final int totalPredictions;
  final int correctPredictions;
  final int streak;
  final String specialty;
  final double roi;
  final bool isVerified;
  final bool isPremium;

  Tipster.fromMap(Map<String, dynamic> map, String docId)
      : id = docId,
        name = map['name'] ?? 'Unknown',
        accuracy = (map['accuracy'] as num?)?.toDouble() ?? 0,
        totalPredictions = (map['totalPredictions'] as num?)?.toInt() ?? 0,
        correctPredictions = (map['correctPredictions'] as num?)?.toInt() ?? 0,
        streak = (map['streak'] as num?)?.toInt() ?? 0,
        specialty = map['specialty'] ?? 'General',
        roi = (map['roi'] as num?)?.toDouble() ?? 0,
        isVerified = map['isVerified'] ?? false,
        isPremium = map['isPremium'] ?? false;
}

class PredictionStats {
  final double overallAccuracy;
  final int totalPredictions;
  final int matchesToday;
  final double premiumAccuracy;
  final double freeAccuracy;

  PredictionStats.fromMap(Map<String, dynamic> map)
      : overallAccuracy = (map['overallAccuracy'] as num?)?.toDouble() ?? 0,
        totalPredictions = (map['totalPredictions'] as num?)?.toInt() ?? 0,
        matchesToday = (map['matchesToday'] as num?)?.toInt() ?? 0,
        premiumAccuracy = (map['premiumAccuracy'] as num?)?.toDouble() ?? 0,
        freeAccuracy = (map['freeAccuracy'] as num?)?.toDouble() ?? 0;
}



class GoalVantageColors extends ThemeExtension<GoalVantageColors> {
  // Private instance fields
  final Color _background;
  final Color _backgroundSecondary;
  final Color _card;
  final Color _foreground;
  final Color _foregroundSecondary;
  final Color _primary;
  final Color _primaryForeground;
  final Color _accent;
  final Color _positive;
  final Color _negative;
  final Color _warning;
  final Color _border;
  final Color _gold;

  const GoalVantageColors._({
    required Color background,
    required Color backgroundSecondary,
    required Color card,
    required Color foreground,
    required Color foregroundSecondary,
    required Color primary,
    required Color primaryForeground,
    required Color accent,
    required Color positive,
    required Color negative,
    required Color warning,
    required Color border,
    required Color gold,
  })  : _background = background,
        _backgroundSecondary = backgroundSecondary,
        _card = card,
        _foreground = foreground,
        _foregroundSecondary = foregroundSecondary,
        _primary = primary,
        _primaryForeground = primaryForeground,
        _accent = accent,
        _positive = positive,
        _negative = negative,
        _warning = warning,
        _border = border,
        _gold = gold;

  // Named constructors for palettes
  static const GoalVantageColors dark = GoalVantageColors._(
    background: Color(0xFF0a0e1a),
    backgroundSecondary: Color(0xFF111827),
    card: Color(0xFF1a2035),
    foreground: Color(0xFFe8ecf4),
    foregroundSecondary: Color(0xFF8b95a8),
    primary: Color(0xFF2563eb),
    primaryForeground: Color(0xFFffffff),
    accent: Color(0xFF06b6d4),
    positive: Color(0xFF22c55e),
    negative: Color(0xFFef4444),
    warning: Color(0xFFf59e0b),
    border: Color(0x1Ae8ecf4),
    gold: Color(0xFFd4af37),
  );

  static const GoalVantageColors light = GoalVantageColors._(
    background: Color(0xFFF5F8FC),
    backgroundSecondary: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    foreground: Color(0xFF0B1220),
    foregroundSecondary: Color(0xFF64748B),
    primary: Color(0xFF2563eb),
    primaryForeground: Color(0xFFFFFFFF),
    accent: Color(0xFF0ea5e9),
    positive: Color(0xFF22c55e),
    negative: Color(0xFFef4444),
    warning: Color(0xFFf59e0b),
    border: Color(0x1A0B1220),
    gold: Color(0xFFd4af37),
  );

  // ThemeExtension implementation
  @override
  GoalVantageColors copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? card,
    Color? foreground,
    Color? foregroundSecondary,
    Color? primary,
    Color? primaryForeground,
    Color? accent,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? border,
    Color? gold,
  }) {
    return GoalVantageColors._(
      background: background ?? _background,
      backgroundSecondary: backgroundSecondary ?? _backgroundSecondary,
      card: card ?? _card,
      foreground: foreground ?? _foreground,
      foregroundSecondary: foregroundSecondary ?? _foregroundSecondary,
      primary: primary ?? _primary,
      primaryForeground: primaryForeground ?? _primaryForeground,
      accent: accent ?? _accent,
      positive: positive ?? _positive,
      negative: negative ?? _negative,
      warning: warning ?? _warning,
      border: border ?? _border,
      gold: gold ?? _gold,
    );
  }

  @override
  GoalVantageColors lerp(ThemeExtension<GoalVantageColors>? other, double t) {
    if (other is! GoalVantageColors) return this;
    return GoalVantageColors._(
      background: Color.lerp(_background, other._background, t)!,
      backgroundSecondary: Color.lerp(_backgroundSecondary, other._backgroundSecondary, t)!,
      card: Color.lerp(_card, other._card, t)!,
      foreground: Color.lerp(_foreground, other._foreground, t)!,
      foregroundSecondary: Color.lerp(_foregroundSecondary, other._foregroundSecondary, t)!,
      primary: Color.lerp(_primary, other._primary, t)!,
      primaryForeground: Color.lerp(_primaryForeground, other._primaryForeground, t)!,
      accent: Color.lerp(_accent, other._accent, t)!,
      positive: Color.lerp(_positive, other._positive, t)!,
      negative: Color.lerp(_negative, other._negative, t)!,
      warning: Color.lerp(_warning, other._warning, t)!,
      border: Color.lerp(_border, other._border, t)!,
      gold: Color.lerp(_gold, other._gold, t)!,
    );
  }

  // ==========================================================================
  // Static forwarding getters – so existing code keeps working
  // ==========================================================================

  static GoalVantageColors? _current;
  static GoalVantageColors get current => _current ?? GoalVantageColors.dark;
  static void setCurrent(GoalVantageColors colors) => _current = colors;

  static Color get background => current._background;
  static Color get backgroundSecondary => current._backgroundSecondary;
  static Color get card => current._card;
  static Color get foreground => current._foreground;
  static Color get foregroundSecondary => current._foregroundSecondary;
  static Color get primary => current._primary;
  static Color get primaryForeground => current._primaryForeground;
  static Color get accent => current._accent;
  static Color get positive => current._positive;
  static Color get negative => current._negative;
  static Color get warning => current._warning;
  static Color get border => current._border;
  static Color get gold => current._gold;

  // ==========================================================================
  // Helper to access from BuildContext (optional)
  // ==========================================================================

  static GoalVantageColors of(BuildContext context) =>
      Theme.of(context).extension<GoalVantageColors>()!;
}