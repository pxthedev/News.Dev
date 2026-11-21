import 'package:material_ui/material_ui.dart';

import 'routes.dart';
import 'l10n/app_copy.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/root_shell.dart';
import 'screens/onboarding/topics_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/brand.dart';
import 'widgets/system.dart';

class RadarApp extends StatelessWidget {
  const RadarApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ValueListenableBuilder<AppLanguage>(
          valueListenable: state.languageListenable,
          builder: (context, language, _) {
            return MaterialApp(
              title: AppBrand.name,
              debugShowCheckedModeBanner: false,
              navigatorKey: rootNavigatorKey,
              theme: buildRadarTheme(),
              locale: language.locale,
              supportedLocales: AppLanguage.values.map((value) => value.locale),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: state.isAccount
                  ? (state.onboarded ? const RootShell() : const TopicsScreen())
                  : const WelcomeScreen(),
              onGenerateRoute: Routes.generate,
              builder: (context, child) =>
                  OverlayHost(child: child ?? const SizedBox.shrink()),
            );
          }),
    );
  }
}
