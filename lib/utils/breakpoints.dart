import 'package:flutter/material.dart';

/// Breakpoints mirror the web Tailwind scale so layouts match across platforms.
class BP {
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
  static const double xxl = 1536;

  /// Max width for centered content on large screens (like web max-w).
  static const double contentMax = 1280;
}

enum ScreenSize { compact, medium, expanded }

extension ScreenSizeX on ScreenSize {
  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;
  bool get atLeastMedium => this != ScreenSize.compact;
  bool get atLeastExpanded => this == ScreenSize.expanded;
}

ScreenSize sizeFromWidth(double w) {
  if (w < BP.md) return ScreenSize.compact;
  if (w < BP.lg) return ScreenSize.medium;
  return ScreenSize.expanded;
}

/// Responsive helpers readable anywhere via MediaQuery.
class Responsive {
  static ScreenSize of(BuildContext context) =>
      sizeFromWidth(MediaQuery.sizeOf(context).width);

  static bool isCompact(BuildContext context) => of(context).isCompact;
  static bool isMedium(BuildContext context) => of(context).isMedium;
  static bool isExpanded(BuildContext context) => of(context).isExpanded;

  /// Horizontal page padding that scales with screen.
  static EdgeInsets pagePadding(BuildContext context) {
    final s = of(context);
    if (s.isCompact) return const EdgeInsets.symmetric(horizontal: 20);
    if (s.isMedium) return const EdgeInsets.symmetric(horizontal: 32);
    return const EdgeInsets.symmetric(horizontal: 48);
  }

  /// Pick a value per size.
  static T pick<T>(BuildContext context, {required T compact, T? medium, T? expanded}) {
    final s = of(context);
    if (s.isExpanded) return expanded ?? medium ?? compact;
    if (s.isMedium) return medium ?? compact;
    return compact;
  }
}