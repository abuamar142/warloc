/// Spacing scale used across the app.
///
/// Values follow the dominant inline paddings/sizes found in the UI code
/// (4 / 8 / 16 / 24 / 32).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Common corner radii.
class AppRadius {
  AppRadius._();

  /// Small elements: chips, dropdown containers, date pills.
  static const double sm = 8;

  /// Medium elements: inputs, small cards.
  static const double md = 12;

  /// Large elements: dialogs, cards.
  static const double lg = 16;

  /// Card corner radius (matches cardTheme in app_theme.dart).
  static const double card = lg;
}
