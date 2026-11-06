import 'package:flutter/material.dart';
import '../utils/breakpoints.dart';

/// Rebuilds when the width crosses a breakpoint.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize size) builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          builder(context, sizeFromWidth(constraints.maxWidth)),
    );
  }
}

/// Centers content and caps its width on large screens (web-style container).
class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const ConstrainedContent({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BP.contentMax),
        child: Padding(
          padding: padding ?? Responsive.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// Grid that adapts column count to screen width.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int compact;
  final int medium;
  final int expanded;
  final double spacing;
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.compact = 1,
    this.medium = 2,
    this.expanded = 3,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size) {
        final count = size.isExpanded ? expanded : (size.isMedium ? medium : compact);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: _ratio(size),
          children: children,
        );
      },
    );
  }

  double _ratio(ScreenSize size) => size.isCompact ? 1.05 : 1.25;
}