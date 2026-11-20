import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radar/data/credential_vault.dart';
import 'package:radar/data/local_store.dart';
import 'package:radar/data/api/api_client.dart';
import 'package:radar/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  http.Response response(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
  test('troca acesso Supabase por sessão da API sem persistir o token social',
      () async {
    final store = await LocalStore.open(vault: MemoryCredentialVault());
    await store.setCredentials(token: 'anonymous');
    final api = ApiClient(
        baseUrl: 'https://example.com',
        store: store,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/auth/supabase');
          expect(jsonDecode(request.body), {'accessToken': 'supabase-access'});
          return response(
              {'token': 'api-access', 'refreshToken': 'api-refresh'});
        }));
    await api.socialSignIn('supabase-access');
    expect(store.token, 'api-access');
    expect(store.refreshToken, 'api-refresh');
    expect(store.isAccount, isTrue);
  });
  test('invalida sessão antiga uma vez e preserva novas credenciais no cofre',
      () async {
    SharedPreferences.setMockInitialValues({'api_token': 'old'});
    final vault = MemoryCredentialVault()
      ..value = jsonEncode({
        'token': 'firebase-api-token',
        'refreshToken': 'old-refresh',
        'isAccount': true
      });
    final previousPrefs = await SharedPreferences.getInstance();
    await previousPrefs.setString('app_state.v1',
        jsonEncode({'userName': 'Old profile', 'onboarded': true}));
    final store = await LocalStore.open(vault: vault);
    expect(store.token, isNull);
    expect(store.readState(), isNull);
    expect(store.isAccount, isFalse);
    expect(
        (await SharedPreferences.getInstance()).getString('api_token'), isNull);
    await store.setCredentials(
        token: 'access', refreshToken: 'refresh', isAccount: true);
    final reopened = await LocalStore.open(vault: vault);
    expect(reopened.token, 'access');
    expect(reopened.refreshToken, 'refresh');
    expect(reopened.isAccount, isTrue);
    expect((await SharedPreferences.getInstance()).getKeys(),
        {'backend_generation.v1'});
  });
  test('401 simultâneos renovam uma única vez e preservam a identidade',
      () async {
    final store = await LocalStore.open(vault: MemoryCredentialVault());
    await store.setCredentials(
        token: 'old', refreshToken: 'refresh-old', isAccount: true);
    int refreshes = 0, anonymous = 0;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        store: store,
        client: MockClient((request) async {
          if (request.url.path == '/v1/auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return response({'token': 'new', 'refreshToken': 'refresh-new'});
          }
          if (request.url.path == '/v1/auth/anonymous') {
            anonymous++;
            return response({'token': 'anonymous'});
          }
          if (request.headers['Authorization'] == 'Bearer old') {
            return response({}, 401);
          }
          return response({'id': 'same-user'});
        }));
    final values =
        await Future.wait(List.generate(4, (_) => api.get('/v1/me')));
    expect(refreshes, 1);
    expect(anonymous, 0);
    expect(store.token, 'new');
    expect(store.refreshToken, 'refresh-new');
    expect(store.isAccount, isTrue);
    expect(values.every((value) => value['id'] == 'same-user'), isTrue);
  });
  test(
      'indisponibilidade e refresh revogado não apagam credenciais nem criam anônimo',
      () async {
    final store = await LocalStore.open(vault: MemoryCredentialVault());
    await store.setCredentials(
        token: 'old', refreshToken: 'refresh-old', isAccount: true);
    var refreshStatus = 503;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        store: store,
        client: MockClient((request) async => response(
            {}, request.url.path == '/v1/auth/refresh' ? refreshStatus : 401)));
    await expectLater(api.get('/v1/me'), throwsA(isA<RepoException>()));
    expect(store.token, 'old');
    expect(store.refreshToken, 'refresh-old');
    refreshStatus = 401;
    await expectLater(api.get('/v1/me'), throwsA(isA<RepoException>()));
    expect(store.token, 'old');
    expect(store.isAccount, isTrue);
  });
  test('cadastro promove a identidade anônima e mantém tokens no cofre',
      () async {
    final store = await LocalStore.open(vault: MemoryCredentialVault());
    await store.setCredentials(token: 'anon', refreshToken: 'anon-refresh');
    final api = ApiClient(
        baseUrl: 'https://example.com',
        store: store,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/auth/upgrade');
          expect(request.headers['Authorization'], 'Bearer anon');
          expect(jsonDecode(request.body)['email'], 'ana@example.com');
          return response(
              {'token': 'account', 'refreshToken': 'account-refresh'}, 201);
        }));
    await api.signUp('Ana', 'ana@example.com', 'senha-forte-de-teste');
    expect(store.isAccount, isTrue);
    expect(store.token, 'account');
    expect((await SharedPreferences.getInstance()).getKeys(),
        {'backend_generation.v1'});
  });
  test('logout revoga no servidor antes de apagar o cofre e os caches privados',
      () async {
    final vault = MemoryCredentialVault();
    final store = await LocalStore.open(vault: vault);
    await store.setCredentials(
        token: 'account', refreshToken: 'refresh', isAccount: true);
    await store.writeState({'userName': 'Ana'});
    final api = ApiClient(
        baseUrl: 'https://example.com',
        store: store,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/auth/logout');
          return http.Response('', 204);
        }));
    await api.signOut();
    expect(store.token, isNull);
    expect(store.readState(), isNull);
    expect(await vault.read(), isNull);
  });

  test('sessão revogada não impede entrar novamente com senha válida',
      () async {
    final store = await LocalStore.open(vault: MemoryCredentialVault());
    await store.setCredentials(
        token: 'revoked', refreshToken: 'revoked-refresh', isAccount: true);
    final api = ApiClient(
        baseUrl: 'https://example.com',
        store: store,
        client: MockClient((request) async {
          if (request.url.path == '/v1/auth/login' &&
              !request.headers.containsKey('Authorization')) {
            return response(
                {'token': 'fresh-account', 'refreshToken': 'fresh-refresh'});
          }
          return response({}, 401);
        }));
    await api.signIn('ana@example.com', 'senha-forte-de-teste');
    expect(store.token, 'fresh-account');
    expect(store.isAccount, isTrue);
  });
}
