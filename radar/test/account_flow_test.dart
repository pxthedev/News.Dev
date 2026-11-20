import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radar/app.dart';
import 'package:radar/data/api/api_client.dart';
import 'package:radar/data/api/http_repository.dart';
import 'package:radar/data/credential_vault.dart';
import 'package:radar/data/local_store.dart';
import 'package:radar/routes.dart';
import 'package:radar/screens/account_screen.dart';
import 'package:radar/screens/onboarding/topics_screen.dart';
import 'package:radar/state/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void prepare(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> clean(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
      'Começar exige cadastro antes dos interesses; Google aparece no cadastro e login',
      (tester) async {
    prepare(tester);
    final state = AppState();
    await tester.pumpWidget(RadarApp(state: state));
    await tester.ensureVisible(find.text('Começar'));
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('O que te interessa?'), findsNothing);
    await tester.ensureVisible(find.text('Voltar para entrar'));
    await tester.tap(find.text('Voltar para entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar no news.dev'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsNothing);
    expect(find.text('Continuar com Google'), findsOneWidget);
    await clean(tester, state);
  });

  testWidgets(
      'rotas e interesses não permitem contornar login, mesmo com onboarding antigo',
      (tester) async {
    prepare(tester);
    final state = AppState(onboarded: true);
    await tester.pumpWidget(RadarApp(state: state));
    expect(find.text('Começar'), findsOneWidget);
    rootNavigatorKey.currentState!.pushNamed(Routes.editTopics);
    await tester.pumpAndSettle();
    expect(find.text('Entrar no news.dev'), findsOneWidget);
    expect(find.text('Tópicos seguidos'), findsNothing);
    state.completeOnboarding();
    // O valor legado não concede acesso à conta.
    expect(state.isAccount, isFalse);
    await clean(tester, state);
  });

  for (final register in [false, true]) {
    testWidgets(
        '${register ? 'cadastro' : 'login'} válido vai para interesses e não conclui onboarding',
        (tester) async {
      prepare(tester);
      final store = await LocalStore.open(vault: MemoryCredentialVault());
      final calls = <String>[];
      final api = ApiClient(
          baseUrl: 'https://example.test',
          store: store,
          client: MockClient((request) async {
            calls.add(request.url.path);
            final body = request.url.path.startsWith('/v1/auth/')
                ? {'token': 'access', 'refreshToken': 'refresh'}
                : request.url.path == '/v1/me'
                    ? {
                        'id': 'user-1',
                        'name': 'Ana',
                        'email': 'ana@example.com',
                        'createdAt': '2026-11-16T12:00:00Z'
                      }
                    : request.url.path == '/v1/me/prefs'
                        ? {
                            'topics': ['ia', 'seguranca', 'programacao']
                          }
                        : <String, Object>{};
            return http.Response(jsonEncode(body), 200,
                headers: {'content-type': 'application/json'});
          }));
      final repo = HttpRepository(api, store);
      final state = AppState(repo: repo, store: store);
      await tester.pumpWidget(AppScope(
          state: state,
          child: MaterialApp(home: AccountScreen(register: register))));
      final fields = find.byType(TextFormField);
      if (register) await tester.enterText(fields.at(0), 'Ana');
      await tester.enterText(fields.at(register ? 1 : 0), 'ana@example.com');
      await tester.enterText(fields.at(register ? 2 : 1), 'Senha123');
      if (register) await tester.enterText(fields.at(3), 'Senha123');
      final submit = find.text(register ? 'Criar conta' : 'Entrar');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(store.isAccount, isTrue);
      expect(find.byType(TopicsScreen), findsOneWidget);
      expect(find.text('O que te interessa?'), findsOneWidget);
      expect(state.onboarded, isFalse);
      expect(calls, contains(register ? '/v1/auth/upgrade' : '/v1/auth/login'));
      await clean(tester, state);
    });
  }

  testWidgets('erro de credenciais mantém usuário no login', (tester) async {
    prepare(tester);
    final store = await LocalStore.open(vault: MemoryCredentialVault());
    await store.setCredentials(token: 'anonymous');
    final api = ApiClient(
        baseUrl: 'https://example.test',
        store: store,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Email ou senha inválidos.'}
            }),
            401,
            headers: {'content-type': 'application/json'})));
    final state = AppState(repo: HttpRepository(api, store));
    await tester.pumpWidget(AppScope(
        state: state, child: const MaterialApp(home: AccountScreen())));
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-errada');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(store.isAccount, isFalse);
    expect(find.byType(TopicsScreen), findsNothing);
    expect(find.text('Email ou senha inválidos.'), findsOneWidget);
    await clean(tester, state);
  });
}
