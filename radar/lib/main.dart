import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

import 'app.dart';
import 'routes.dart';
import 'screens/onboarding/topics_screen.dart';
import 'data/api/api_client.dart';
import 'data/api/http_repository.dart';
import 'data/local_store.dart';
import 'data/repository.dart';
import 'services/platform_services.dart';
import 'services/supabase_bridge.dart';
import 'state/app_state.dart';

/// URL da API Java. Vazio = usa os dados mockados.
///   flutter run --dart-define=RADAR_API_URL=http://localhost:8080
const apiUrl = String.fromEnvironment('RADAR_API_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
  );

  final store = await LocalStore.open();
  if (apiUrl.isNotEmpty) {
    Repo.instance =
        HttpRepository(ApiClient(baseUrl: apiUrl, store: store), store);
  }

  final state = AppState(repo: Repo.instance, store: store)..restore();
  runApp(RadarApp(state: state));

  try {
    final initialLink = kIsWeb ? null : await AppLinks().getInitialLink();
    final socialCallback = kIsWeb
        ? Uri.base.queryParameters.containsKey('code')
        : initialLink?.scheme == 'radar' &&
            initialLink?.host == 'auth-callback';
    await SupabaseBridge.initialize();
    if (socialCallback &&
        SupabaseBridge.ready &&
        Repo.instance is HttpRepository) {
      final token = await SupabaseBridge.redirectedToken();
      await (Repo.instance as HttpRepository).api.socialSignIn(token);
      await state.reloadIdentity();
      rootNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const TopicsScreen()),
          (_) => false);
    }
  } on Object {
    debugPrint(
        '[supabase] Serviços indisponíveis; login por email continua disponível.');
  }
  state.refreshRemote();
  PlatformServices.instance.listenDeepLinks();
}
