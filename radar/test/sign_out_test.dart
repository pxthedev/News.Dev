import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radar/data/api/api_client.dart';
import 'package:radar/data/api/http_repository.dart';
import 'package:radar/data/credential_vault.dart';
import 'package:radar/data/local_store.dart';
import 'package:radar/routes.dart';
import 'package:radar/screens/account_screen.dart';
import 'package:radar/screens/profile_screen.dart';
import 'package:radar/state/app_state.dart';

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
        'sair pelo perfil ${succeeds ? 'limpa sessão e volta ao login' : 'preserva sessão se servidor falha'}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await LocalStore.open(vault: MemoryCredentialVault());
      await store.setCredentials(
          token: 'account', refreshToken: 'refresh', isAccount: true);
      await store.writeState({'userName': 'Ana', 'onboarded': true});
      final api = ApiClient(
          baseUrl: 'https://example.test',
          store: store,
          client: MockClient((request) async {
            expect(request.url.path, '/v1/auth/logout');
            expect(request.headers['Authorization'], 'Bearer account');
            return succeeds
                ? http.Response('', 204)
                : http.Response(
                    jsonEncode({
                      'error': {'message': 'Servidor indisponível.'}
                    }),
                    503,
                    headers: {'content-type': 'application/json'});
          }));
      final state = AppState(
          repo: HttpRepository(api, store), store: store, onboarded: true)
        ..userName = 'Ana'
        ..userEmail = 'ana@example.com';
      state.savedIds.add('private-article');
      await tester.pumpWidget(AppScope(
          state: state,
          child: const MaterialApp(
              locale: Locale('pt', 'BR'),
              supportedLocales: [Locale('pt', 'BR')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(body: ProfileScreen()),
              onGenerateRoute: Routes.generate)));
      await tester.scrollUntilVisible(find.text('Sair da conta'), 280);
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      if (succeeds) {
        expect(store.token, isNull);
        expect(store.refreshToken, isNull);
        expect(store.isAccount, isFalse);
        expect(state.onboarded, isFalse);
        expect(state.savedIds, isEmpty);
        expect(state.userEmail, isNull);
        expect(find.byType(AccountScreen), findsOneWidget);
        expect(find.text('Entrar no news.dev'), findsOneWidget);
        expect(
            Navigator.of(tester.element(find.byType(AccountScreen))).canPop(),
            isFalse);
      } else {
        expect(store.token, 'account');
        expect(store.isAccount, isTrue);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(state.toast.value?.message, 'Servidor indisponível.');
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
