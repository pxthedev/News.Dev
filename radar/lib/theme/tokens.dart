import 'package:material_ui/material_ui.dart';

/// Design system do Radar. Único lugar com cores, tipografia e medidas.
/// Espelha a seção 3 do PROMPT_RADAR.md e as variáveis do Figma.

abstract final class RColors {
  static const bgBase = Color(0xFF000000);
  static const bgCard = Color(0xFF1C1C1E);
  static const bgElevated = Color(0xFF2C2C2E);
  static const bgControl = Color(0xFF3A3A3C);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF636366);

  static const radar = Color(0xFFD4FF3A);
  static const onRadar = Color(0xFF0D1400);

  static const urgent = Color(0xFFFF453A);
  static const link = Color(0xFF0A84FF);
  static const purple = Color(0xFFBF5AF2);
  static const orange = Color(0xFFFF9F0A);

  static const separator = Color(0xFF38383A);

  /// Fundo de ícones: cor da categoria com 16–18% de opacidade.
  static Color tint(Color c, [double alpha = 0.17]) => c.withValues(alpha: alpha);
}

/// Escala tipográfica iOS. A fonte é a do sistema (SF Pro no iPhone).
abstract final class RText {
  static TextStyle _s(double size, double lineHeight, FontWeight weight, {double tracking = -0.01}) => TextStyle(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: size * tracking,
        color: RColors.textPrimary,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static final display = _s(48, 52, FontWeight.w700, tracking: -0.02);
  static final largeTitle = _s(34, 41, FontWeight.w700, tracking: -0.02);
  static final title1 = _s(28, 34, FontWeight.w700, tracking: -0.02);
  static final title2 = _s(22, 28, FontWeight.w700, tracking: -0.02);
  static final title3 = _s(20, 25, FontWeight.w600, tracking: -0.02);
  static final bigNumber = _s(36, 40, FontWeight.w600, tracking: -0.02);
  static final headline = _s(17, 22, FontWeight.w600);
  static final body = _s(17, 22, FontWeight.w400);
  static final callout = _s(16, 21, FontWeight.w400);
  static final subheadline = _s(15, 20, FontWeight.w400);
  static final subheadlineEmph = _s(15, 20, FontWeight.w600);
  static final footnote = _s(13, 18, FontWeight.w400);
  static final footnoteEmph = _s(13, 18, FontWeight.w600);
  static final caption1 = _s(12, 16, FontWeight.w400, tracking: 0);
  static final caption1Emph = _s(12, 16, FontWeight.w500, tracking: 0);
  static final caption2 = _s(11, 13, FontWeight.w600, tracking: 0);
}

abstract final class RSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const screen = 20.0;
  static const block = 16.0;
}

abstract final class RRadius {
  static const sm = 12.0;
  static const field = 14.0;
  static const thumb = 16.0;
  static const card = 22.0;
  static const cardLg = 24.0;
  static const hero = 28.0;
  static const sheet = 34.0;
  static const pill = 999.0;
}

abstract final class RSize {
  static const button = 54.0;
  static const tabBar = 64.0;
  static const circleButton = 40.0;
  static const thumb = 72.0;
  static const minTap = 44.0;
  static const tabFade = 170.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: RSpace.screen);

  /// Espaço no fim das listas pra o conteúdo não ficar atrás da tab bar.
  static double tabClearance(BuildContext context) => MediaQuery.paddingOf(context).bottom + tabBar + 40;
}

extension RTextStyleX on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);
}
