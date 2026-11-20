import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Só tema escuro no MVP.
ThemeData buildRadarTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: RColors.bgBase,
    canvasColor: RColors.bgBase,
    colorScheme: const ColorScheme.dark(
      primary: RColors.radar,
      onPrimary: RColors.onRadar,
      secondary: RColors.radar,
      onSecondary: RColors.onRadar,
      surface: RColors.bgCard,
      onSurface: RColors.textPrimary,
      error: RColors.urgent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: RColors.separator,
    textTheme: base.textTheme.apply(bodyColor: RColors.textPrimary, displayColor: RColors.textPrimary),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: RColors.radar,
      selectionColor: Color(0x55A5B4FC),
      selectionHandleColor: RColors.radar,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark, primaryColor: RColors.radar),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    }),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
  );
}
