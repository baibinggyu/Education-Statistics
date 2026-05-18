import 'package:flutter/material.dart';

enum Breakpoint { compact, medium, expanded }

class Responsive {
  final double width;
  final double height;

  const Responsive._({required this.width, required this.height});

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Responsive._(width: size.width, height: size.height);
  }

  Breakpoint get breakpoint {
    if (width < 600) return Breakpoint.compact;
    if (width < 900) return Breakpoint.medium;
    return Breakpoint.expanded;
  }

  bool get isCompact => breakpoint == Breakpoint.compact;
  bool get isMedium => breakpoint == Breakpoint.medium;
  bool get isExpanded => breakpoint == Breakpoint.expanded;

  /// Scale factor: 1.0 at compact, 1.15 at medium, 1.3 at expanded
  double get scale {
    return switch (breakpoint) {
      Breakpoint.compact => 1.0,
      Breakpoint.medium => 1.15,
      Breakpoint.expanded => 1.3,
    };
  }

  /// Scaled value: base * scale
  double scaled(double base) => base * scale;

  /// Clamped scaled value: scale the base but keep within [min, max]
  double clamped(double base, double min, double max) => scaled(base).clamp(min, max);

  /// Grid columns for a staggered/masonry layout
  int get gridColumns {
    return switch (breakpoint) {
      Breakpoint.compact => 2,
      Breakpoint.medium => 3,
      Breakpoint.expanded => 4,
    };
  }

  /// Max extent for SliverGridDelegateWithMaxCrossAxisExtent
  double get maxCrossAxisExtent => switch (breakpoint) {
    Breakpoint.compact => 220,
    Breakpoint.medium => 200,
    Breakpoint.expanded => 220,
  };

  /// Standard horizontal padding that scales with width
  double get hPadding => clamped(16, 12, 32);

  /// Standard vertical padding
  double get vPadding => clamped(16, 12, 28);

  /// Card border radius
  double get radius => clamped(16, 12, 20);

  /// Icon button size
  double get iconButtonSize => clamped(52, 44, 64);

  /// Banner height as proportion of screen height
  double get bannerHeight => height * (isCompact ? 0.22 : 0.2);

  /// Course card aspect ratio
  double get courseCardAspectRatio => isCompact ? 0.72 : 0.78;

  /// Is the device wide enough for a two-column layout?
  bool get isWide => width >= 720;

  /// Max content width for very wide screens (readability)
  double get maxContentWidth => isExpanded ? 1200 : double.infinity;
}

/// Extension to make responsive values easy to access from BuildContext
extension ResponsiveContext on BuildContext {
  Responsive get responsive => Responsive.of(this);
}
