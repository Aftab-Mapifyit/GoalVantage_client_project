import 'package:flutter/material.dart';

/// OnyxBet design tokens with light/dark support.
///
/// Static getters like [AppColors.foreground] automatically reflect
/// the current theme. No widget changes needed.
class AppColors extends ThemeExtension<AppColors> {
  // ===========================================================================
  // Private instance fields (to avoid conflict with static getters)
  // ===========================================================================

  final Color _background;
  final Color _backgroundSecondary;
  final Color _card;
  final Color _cardHover;
  final Color _border;

  final Color _foreground;
  final Color _foregroundSecondary;

  final Color _primary;
  final Color _primaryForeground;
  final Color _secondary;
  final Color _secondaryForeground;
  final Color _primaryGlow;
  final Color _secondaryGlow;

  final Color _positive;
  final Color _negative;
  final Color _positiveSurface;
  final Color _negativeSurface;
  final Color _positiveBorder;
  final Color _negativeBorder;
  final Color _warning;
  final Color _info;

  final Color _auraSurface;
  final Color _auraBorder;
  final Color _auraText;

  final Color _confidenceHigh;
  final Color _confidenceMedium;
  final Color _confidenceLow;

  final Color _chartPrimary;
  final Color _chartSecondary;
  final Color _chartProbability;
  final Color _chartExpected;
  final Color _chartNeutral;

  final Color _selection;
  final Color _focusRing;
  final Color _disabled;

  // ===========================================================================
  // Constructor with private fields
  // ===========================================================================

  const AppColors({
    required Color background,
    required Color backgroundSecondary,
    required Color card,
    required Color cardHover,
    required Color border,
    required Color foreground,
    required Color foregroundSecondary,
    required Color primary,
    required Color primaryForeground,
    required Color secondary,
    required Color secondaryForeground,
    required Color primaryGlow,
    required Color secondaryGlow,
    required Color positive,
    required Color negative,
    required Color positiveSurface,
    required Color negativeSurface,
    required Color positiveBorder,
    required Color negativeBorder,
    required Color auraSurface,
    required Color auraBorder,
    required Color auraText,
    required Color confidenceHigh,
    required Color confidenceMedium,
    required Color confidenceLow,
    required Color warning,
    required Color info,
    required Color chartPrimary,
    required Color chartSecondary,
    required Color chartProbability,
    required Color chartExpected,
    required Color chartNeutral,
    required Color selection,
    required Color focusRing,
    required Color disabled,
  })  : _background = background,
        _backgroundSecondary = backgroundSecondary,
        _card = card,
        _cardHover = cardHover,
        _border = border,
        _foreground = foreground,
        _foregroundSecondary = foregroundSecondary,
        _primary = primary,
        _primaryForeground = primaryForeground,
        _secondary = secondary,
        _secondaryForeground = secondaryForeground,
        _primaryGlow = primaryGlow,
        _secondaryGlow = secondaryGlow,
        _positive = positive,
        _negative = negative,
        _positiveSurface = positiveSurface,
        _negativeSurface = negativeSurface,
        _positiveBorder = positiveBorder,
        _negativeBorder = negativeBorder,
        _auraSurface = auraSurface,
        _auraBorder = auraBorder,
        _auraText = auraText,
        _confidenceHigh = confidenceHigh,
        _confidenceMedium = confidenceMedium,
        _confidenceLow = confidenceLow,
        _warning = warning,
        _info = info,
        _chartPrimary = chartPrimary,
        _chartSecondary = chartSecondary,
        _chartProbability = chartProbability,
        _chartExpected = chartExpected,
        _chartNeutral = chartNeutral,
        _selection = selection,
        _focusRing = focusRing,
        _disabled = disabled;

  // ===========================================================================
  // ThemeExtension implementation (using private fields)
  // ===========================================================================

  @override
  AppColors copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? card,
    Color? cardHover,
    Color? border,
    Color? foreground,
    Color? foregroundSecondary,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? primaryGlow,
    Color? secondaryGlow,
    Color? positive,
    Color? negative,
    Color? positiveSurface,
    Color? negativeSurface,
    Color? positiveBorder,
    Color? negativeBorder,
    Color? auraSurface,
    Color? auraBorder,
    Color? auraText,
    Color? confidenceHigh,
    Color? confidenceMedium,
    Color? confidenceLow,
    Color? warning,
    Color? info,
    Color? chartPrimary,
    Color? chartSecondary,
    Color? chartProbability,
    Color? chartExpected,
    Color? chartNeutral,
    Color? selection,
    Color? focusRing,
    Color? disabled,
  }) {
    return AppColors(
      background: background ?? _background,
      backgroundSecondary: backgroundSecondary ?? _backgroundSecondary,
      card: card ?? _card,
      cardHover: cardHover ?? _cardHover,
      border: border ?? _border,
      foreground: foreground ?? _foreground,
      foregroundSecondary: foregroundSecondary ?? _foregroundSecondary,
      primary: primary ?? _primary,
      primaryForeground: primaryForeground ?? _primaryForeground,
      secondary: secondary ?? _secondary,
      secondaryForeground: secondaryForeground ?? _secondaryForeground,
      primaryGlow: primaryGlow ?? _primaryGlow,
      secondaryGlow: secondaryGlow ?? _secondaryGlow,
      positive: positive ?? _positive,
      negative: negative ?? _negative,
      positiveSurface: positiveSurface ?? _positiveSurface,
      negativeSurface: negativeSurface ?? _negativeSurface,
      positiveBorder: positiveBorder ?? _positiveBorder,
      negativeBorder: negativeBorder ?? _negativeBorder,
      auraSurface: auraSurface ?? _auraSurface,
      auraBorder: auraBorder ?? _auraBorder,
      auraText: auraText ?? _auraText,
      confidenceHigh: confidenceHigh ?? _confidenceHigh,
      confidenceMedium: confidenceMedium ?? _confidenceMedium,
      confidenceLow: confidenceLow ?? _confidenceLow,
      warning: warning ?? _warning,
      info: info ?? _info,
      chartPrimary: chartPrimary ?? _chartPrimary,
      chartSecondary: chartSecondary ?? _chartSecondary,
      chartProbability: chartProbability ?? _chartProbability,
      chartExpected: chartExpected ?? _chartExpected,
      chartNeutral: chartNeutral ?? _chartNeutral,
      selection: selection ?? _selection,
      focusRing: focusRing ?? _focusRing,
      disabled: disabled ?? _disabled,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(_background, other._background, t)!,
      backgroundSecondary: Color.lerp(_backgroundSecondary, other._backgroundSecondary, t)!,
      card: Color.lerp(_card, other._card, t)!,
      cardHover: Color.lerp(_cardHover, other._cardHover, t)!,
      border: Color.lerp(_border, other._border, t)!,
      foreground: Color.lerp(_foreground, other._foreground, t)!,
      foregroundSecondary: Color.lerp(_foregroundSecondary, other._foregroundSecondary, t)!,
      primary: Color.lerp(_primary, other._primary, t)!,
      primaryForeground: Color.lerp(_primaryForeground, other._primaryForeground, t)!,
      secondary: Color.lerp(_secondary, other._secondary, t)!,
      secondaryForeground: Color.lerp(_secondaryForeground, other._secondaryForeground, t)!,
      primaryGlow: Color.lerp(_primaryGlow, other._primaryGlow, t)!,
      secondaryGlow: Color.lerp(_secondaryGlow, other._secondaryGlow, t)!,
      positive: Color.lerp(_positive, other._positive, t)!,
      negative: Color.lerp(_negative, other._negative, t)!,
      positiveSurface: Color.lerp(_positiveSurface, other._positiveSurface, t)!,
      negativeSurface: Color.lerp(_negativeSurface, other._negativeSurface, t)!,
      positiveBorder: Color.lerp(_positiveBorder, other._positiveBorder, t)!,
      negativeBorder: Color.lerp(_negativeBorder, other._negativeBorder, t)!,
      auraSurface: Color.lerp(_auraSurface, other._auraSurface, t)!,
      auraBorder: Color.lerp(_auraBorder, other._auraBorder, t)!,
      auraText: Color.lerp(_auraText, other._auraText, t)!,
      confidenceHigh: Color.lerp(_confidenceHigh, other._confidenceHigh, t)!,
      confidenceMedium: Color.lerp(_confidenceMedium, other._confidenceMedium, t)!,
      confidenceLow: Color.lerp(_confidenceLow, other._confidenceLow, t)!,
      warning: Color.lerp(_warning, other._warning, t)!,
      info: Color.lerp(_info, other._info, t)!,
      chartPrimary: Color.lerp(_chartPrimary, other._chartPrimary, t)!,
      chartSecondary: Color.lerp(_chartSecondary, other._chartSecondary, t)!,
      chartProbability: Color.lerp(_chartProbability, other._chartProbability, t)!,
      chartExpected: Color.lerp(_chartExpected, other._chartExpected, t)!,
      chartNeutral: Color.lerp(_chartNeutral, other._chartNeutral, t)!,
      selection: Color.lerp(_selection, other._selection, t)!,
      focusRing: Color.lerp(_focusRing, other._focusRing, t)!,
      disabled: Color.lerp(_disabled, other._disabled, t)!,
    );
  }

  // ===========================================================================
  // Static palettes (now using named parameters for private fields)
  // ===========================================================================

  static const AppColors dark = AppColors(
    background: Color(0xFF050B18),
    backgroundSecondary: Color(0xFF08101F),
    card: Color(0xD90B1220),
    cardHover: Color(0xF2141F32),
    border: Color(0x1A94A3B8),
    foreground: Color(0xFFF8FAFC),
    foregroundSecondary: Color(0xFF94A3B8),
    primary: Color(0xFF155EEF),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF00D9FF),
    secondaryForeground: Color(0xFF03101C),
    primaryGlow: Color(0x33155EEF),
    secondaryGlow: Color(0x1F00D9FF),
    positive: Color(0xFF27D7A0),
    negative: Color(0xFFFF4D6D),
    positiveSurface: Color(0x1A27D7A0),
    negativeSurface: Color(0x1AFF4D6D),
    positiveBorder: Color(0x3327D7A0),
    negativeBorder: Color(0x33FF4D6D),
    auraSurface: Color(0x1F00D9FF),
    auraBorder: Color(0x3300D9FF),
    auraText: Color(0xFF7DEBFF),
    confidenceHigh: Color(0xFF00D9FF),
    confidenceMedium: Color(0xFF5B8CFF),
    confidenceLow: Color(0xFF64748B),
    warning: Color(0xFFFFB547),
    info: Color(0xFF00D9FF),
    chartPrimary: Color(0xFF155EEF),
    chartSecondary: Color(0xFF00D9FF),
    chartProbability: Color(0xFF5B8CFF),
    chartExpected: Color(0xFF27D7A0),
    chartNeutral: Color(0xFF64748B),
    selection: Color(0x4D155EEF),
    focusRing: Color(0xFF00D9FF),
    disabled: Color(0x66F8FAFC),
  );

  static const AppColors light = AppColors(
    background: Color(0xFFF5F8FC),
    backgroundSecondary: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardHover: Color(0xFFE8EDF5),
    border: Color(0x1A0B1220),
    foreground: Color(0xFF0B1220),
    foregroundSecondary: Color(0xFF64748B),
    primary: Color(0xFF155EEF),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF009FC2),
    secondaryForeground: Color(0xFFFFFFFF),
    primaryGlow: Color(0x33155EEF),
    secondaryGlow: Color(0x1F00D9FF),
    positive: Color(0xFF27D7A0),
    negative: Color(0xFFFF4D6D),
    positiveSurface: Color(0x1A27D7A0),
    negativeSurface: Color(0x1AFF4D6D),
    positiveBorder: Color(0x3327D7A0),
    negativeBorder: Color(0x33FF4D6D),
    auraSurface: Color(0x1F00D9FF),
    auraBorder: Color(0x3300D9FF),
    auraText: Color(0xFF009FC2),
    confidenceHigh: Color(0xFF009FC2),
    confidenceMedium: Color(0xFF5B8CFF),
    confidenceLow: Color(0xFF94A3B8),
    warning: Color(0xFFFFB547),
    info: Color(0xFF009FC2),
    chartPrimary: Color(0xFF155EEF),
    chartSecondary: Color(0xFF009FC2),
    chartProbability: Color(0xFF5B8CFF),
    chartExpected: Color(0xFF27D7A0),
    chartNeutral: Color(0xFF94A3B8),
    selection: Color(0x4D155EEF),
    focusRing: Color(0xFF009FC2),
    disabled: Color(0x660B1220),
  );

  // ===========================================================================
  // Static forwarding getters – these make AppColors.background work
  // ===========================================================================

  static AppColors? _current;
  static AppColors get current => _current ?? AppColors.dark;
  static void setCurrent(AppColors colors) => _current = colors;

  static Color get background => current._background;
  static Color get backgroundSecondary => current._backgroundSecondary;
  static Color get card => current._card;
  static Color get cardHover => current._cardHover;
  static Color get border => current._border;
  static Color get foreground => current._foreground;
  static Color get foregroundSecondary => current._foregroundSecondary;
  static Color get primary => current._primary;
  static Color get primaryForeground => current._primaryForeground;
  static Color get secondary => current._secondary;
  static Color get secondaryForeground => current._secondaryForeground;
  static Color get primaryGlow => current._primaryGlow;
  static Color get secondaryGlow => current._secondaryGlow;
  static Color get positive => current._positive;
  static Color get negative => current._negative;
  static Color get positiveSurface => current._positiveSurface;
  static Color get negativeSurface => current._negativeSurface;
  static Color get positiveBorder => current._positiveBorder;
  static Color get negativeBorder => current._negativeBorder;
  static Color get warning => current._warning;
  static Color get info => current._info;
  static Color get auraSurface => current._auraSurface;
  static Color get auraBorder => current._auraBorder;
  static Color get auraText => current._auraText;
  static Color get confidenceHigh => current._confidenceHigh;
  static Color get confidenceMedium => current._confidenceMedium;
  static Color get confidenceLow => current._confidenceLow;
  static Color get chartPrimary => current._chartPrimary;
  static Color get chartSecondary => current._chartSecondary;
  static Color get chartProbability => current._chartProbability;
  static Color get chartExpected => current._chartExpected;
  static Color get chartNeutral => current._chartNeutral;
  static Color get selection => current._selection;
  static Color get focusRing => current._focusRing;
  static Color get disabled => current._disabled;

  // ===========================================================================
  // Static shadow forwarding – AppColors.cardShadow() still works
  // ===========================================================================

  static List<BoxShadow> cardShadow({bool hover = false}) =>
      current._cardShadow(hover: hover);
  static List<BoxShadow> primaryButtonShadow({bool hover = false}) =>
      current._primaryButtonShadow(hover: hover);
  static List<BoxShadow> secondaryButtonShadow({bool hover = false}) =>
      current._secondaryButtonShadow(hover: hover);

  // ===========================================================================
  // Private instance shadow methods (used by static forwards)
  // ===========================================================================

  List<BoxShadow> _cardShadow({bool hover = false}) {
    return hover
        ? [
      const BoxShadow(
        color: Color(0x80000000),
        blurRadius: 25,
        offset: Offset(0, 20),
      ),
      BoxShadow(
        color: _primary.withOpacity(0.12),
        blurRadius: 24,
      ),
    ]
        : const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ];
  }

  List<BoxShadow> _primaryButtonShadow({bool hover = false}) {
    return hover
        ? [
      BoxShadow(
        color: _primary.withOpacity(0.35),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: _secondary.withOpacity(0.20),
        blurRadius: 20,
      ),
    ]
        : [
      BoxShadow(
        color: _primary.withOpacity(0.25),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  List<BoxShadow> _secondaryButtonShadow({bool hover = false}) {
    return hover
        ? [
      BoxShadow(
        color: _secondary.withOpacity(0.33),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: _primary.withOpacity(0.20),
        blurRadius: 20,
      ),
    ]
        : [
      BoxShadow(
        color: _secondary.withOpacity(0.20),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // ===========================================================================
  // Gradients & ambient background (unchanged)
  // ===========================================================================

  static const LinearGradient auraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF155EEF), Color(0xFF0B8FFF), Color(0xFF00D9FF)],
    stops: [0.0, 0.50, 1.0],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF155EEF), Color(0xFF1749B8)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B8E6), Color(0xFF00D9FF)],
  );

  static const List<BoxDecoration> ambientBackground = [
    BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.75, -0.85),
        radius: 0.95,
        colors: [Color(0x0D155EEF), Colors.transparent],
        stops: [0.0, 0.60],
      ),
    ),
    BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-0.90, 0.95),
        radius: 0.90,
        colors: [Color(0x0800D9FF), Colors.transparent],
        stops: [0.0, 0.55],
      ),
    ),
  ];

  // ===========================================================================
  // Helper to access the palette from a BuildContext
  // ===========================================================================

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;
}