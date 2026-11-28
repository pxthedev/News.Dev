import 'package:radar/data/credential_vault.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radar/data/api/api_client.dart';
import 'package:radar/data/api/http_repository.dart';
import 'package:radar/data/local_store.dart';
import 'package:radar/data/mock_data.dart';
import 'package:radar/data/mock_repository.dart';
import 'package:radar/data/models.dart';
import 'package:radar/data/repository.dart';
import 'package:radar/state/app_state.dart';
import 'package:radar/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Matéria no formato exato que o Go vai mandar (time.Time → RFC 3339 com Z, campos opcionais ausentes).
const goArticle = {
  'id': 'nvidia-fabrica',
  'title': 'Nvidia anuncia fábrica de US\$ 12 bi na Ásia',
  'summary': ['Ponto 1', 'Ponto 2', 'Ponto 3'],
  'body': 'Texto.',
  'category': 'chips',
  'detectedAt': '2026-11-14T12:37:00Z',
  'publishedAt': '2026-11-14T12:41:05.123456789Z',
  'sources': [
    {'name': 'Reuters', 'url': 'https://www.reuters.com'},
    {
      'name': 'Nikkei Asia',
      'url': 'https://asia.nikkei.com',
      'color': '#B71C1C'
    },
  ],
  'sourceCount': 12,
  'firstInBrazil': true,
  'leadMinutes': 38,
  'urgency': 'important',
  'confirmed': true,
  'readingMinutes': 2,
  'entities': [
    {'type': 'company', 'id': 'nvidia', 'name': 'Nvidia'},
  ],
  'campoNovoQueOAppNaoConhece': 123,
};

void main() {
  test('home sem notícias do banco novo aceita destaque ausente', () {
    final home = HomeSummary.fromJson({
      'scoopsSinceLastNight': 0,
      'trending': {
        'tag': 'tecnologia',
        'count': 0,
        'perDay': [0, 0, 0, 0, 0, 0, 0]
      }
    });
    expect(home.hero, isNull);
    expect(home.scoopsSinceLastNight, 0);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('JSON', () {
    test('lê a matéria no formato do Go', () {
      final a = Article.fromJson(goArticle);
      expect(a.category, NewsCategory.chips);
      expect(a.urgency, Urgency.important);
      expect(a.publishedAt.toUtc(),
          DateTime.utc(2026, 11, 14, 12, 41, 5, 123, 456));
      expect(a.sourcesLabel, 'Reuters, Nikkei Asia +10');
      expect(a.sources[1].color.toARGB32(), 0xFFB71C1C);
      expect(a.imageUrl, isNull);
      expect(a.audioMinutes, isNull);
    });

    test('ida e volta preserva a matéria', () {
      final a = Article.fromJson(goArticle);
      final b = Article.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(b.toJson(), a.toJson());
    });

    test('todas as matérias mockadas sobrevivem à serialização', () {
      for (final a in buildMockArticles()) {
        final b = Article.fromJson(
            jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
        expect(b.id, a.id);
        expect(b.title, a.title);
        expect(b.publishedAt, a.publishedAt);
      }
    });

    test('campo obrigatório ausente diz qual é', () {
      final broken = Map<String, dynamic>.of(goArticle)..remove('title');
      expect(() => Article.fromJson(broken),
          throwsA(predicate((e) => '$e'.contains('"title"'))));
    });

    test('alerta: tipo vira ícone e cor no app', () {
      final urgent = AlertItem.fromJson({
        'id': '1',
        'type': 'urgent',
        'title': 't',
        'subtitle': 's',
        'at': '2026-11-14T10:00:00Z',
        'read': false
      });
      expect(urgent.color, RColors.urgent);
      expect(urgent.unread, isTrue);
      final byCategory = AlertItem.fromJson({
        'id': '2',
        'type': 'article',
        'category': 'programacao',
        'title': 't',
        'subtitle': 's',
        'at': '2026-11-14T10:00:00Z',
        'read': true,
      });
      expect(byCategory.color, NewsCategory.programacao.color);
      expect(byCategory.unread, isFalse);
    });

    test('formatos derivados: delta, leitores e iniciais', () {
      expect(
          TopicStat.fromJson(
              {'category': 'ia', 'deltaPercent': 12, 'today': 48}).delta,
          '+12%');
      expect(
          TopicStat.fromJson(
              {'category': 'ia', 'deltaPercent': -3, 'today': 48}).delta,
          '-3%');
      expect(
          TrendingItem.fromJson(
              {'articleId': 'x', 'title': 't', 'readers': 12400}).readers,
          '12,4 mil lendo');
      final p = Person.fromJson({'id': 'jensen-huang', 'name': 'Jensen Huang'});
      expect((p.initials, p.shortName), ('JH', 'J. Huang'));
    });

    test('preferências: ida e volta', () {
      const prefs = UserPrefs(
        topics: [NewsCategory.ia, NewsCategory.techBr],
        alertLevel: AlertLevel.realtime,
        digestTimes: ['08:00', '19:00'],
        quietHours: (from: '23:00', to: '07:00'),
        showRumors: false,
        urgentAlerts: true,
        followedEntities: ['nvidia'],
      );
      final j = prefs.toJson();
      expect(j['topics'], ['ia', 'tech-br']);
      expect(UserPrefs.fromJson(j).toJson(), j);
    });
  });

  group('MockRepository', () {
    test('pagina com cursor até acabar', () async {
      final repo = MockRepository(latency: false);
      var page = await repo.feed();
      var pages = 1;
      while (page.hasMore) {
        page = await repo.feed(cursor: page.nextCursor);
        pages++;
      }
      expect(pages, MockRepository.maxPages + 1);
    });

    test('rumores ficam de fora por padrão', () async {
      final repo = MockRepository(latency: false);
      final page = await repo.feed();
      expect(page.items.every((a) => a.confirmed), isTrue);
    });
  });

  group('HttpRepository', () {
    late LocalStore store;
    late List<http.Request> calls;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await LocalStore.open(vault: MemoryCredentialVault());
      calls = [];
    });

    HttpRepository repoWith(
        Future<http.Response> Function(http.Request) handler) {
      final client = MockClient((req) {
        calls.add(req);
        return handler(req);
      });
      return HttpRepository(
          ApiClient(baseUrl: 'http://api.test/', store: store, client: client),
          store);
    }

    http.Response json(Object body, [int status = 200]) => http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    test('faz login anônimo, manda o token e lê o feed', () async {
      final repo = repoWith((req) async => switch (req.url.path) {
            '/v1/auth/anonymous' => json({'token': 'tok-1'}),
            '/v1/feed' => json({
                'items': [goArticle],
                'nextCursor': 'abc',
              }),
            _ => json({}, 404),
          });

      final page = await repo.feed(
          filter: FeedFilter.urgent,
          topics: {NewsCategory.ia, NewsCategory.chips});

      expect(calls.first.url.path, '/v1/auth/anonymous');
      final feedCall = calls.last;
      expect(feedCall.headers['Authorization'], 'Bearer tok-1');
      expect(feedCall.url.queryParameters,
          {
            'filter': 'urgent',
            'limit': '20',
            'rumors': 'false',
            'topics': 'chips,ia',
          });
      expect(page.items.single.title, contains('fábrica'));
      expect(page.nextCursor, 'abc');
      expect(repo.byId('nvidia-fabrica'), isNotNull);
    });

    test('401 descarta o token e tenta de novo', () async {
      await store.setToken('velho');
      var feedCalls = 0;
      final repo = repoWith((req) async {
        if (req.url.path == '/v1/auth/anonymous') {
          return json({'token': 'novo'});
        }
        feedCalls++;
        if (req.headers['Authorization'] == 'Bearer velho') {
          return json({}, 401);
        }
        return json({'items': <Object>[]});
      });
      await repo.feed();
      expect(feedCalls, 2);
      expect(store.token, 'novo');
    });

    test('sem conexão: feed vem do cache com aviso', () async {
      var online = true;
      final repo = repoWith((req) async {
        if (!online) throw http.ClientException('sem rede');
        return req.url.path == '/v1/auth/anonymous'
            ? json({'token': 't'})
            : json({
                'items': [goArticle],
              });
      });
      await repo.feed(); // popula o cache
      online = false;
      final page = await repo.feed();
      expect(page.offline, isTrue);
      expect(page.items.single.id, 'nvidia-fabrica');
    });

    test('erro da API vira mensagem pro usuário', () async {
      final repo = repoWith((req) async => req.url.path == '/v1/auth/anonymous'
          ? json({'token': 't'})
          : json({
              'error': {
                'code': 'rate_limited',
                'message': 'Muitas buscas seguidas. Espere um pouco.'
              },
            }, 429));
      expect(
        () => repo.search('nvidia'),
        throwsA(isA<RepoException>().having((e) => e.message, 'message',
            'Muitas buscas seguidas. Espere um pouco.')),
      );
    });

    test('matéria inexistente devolve null', () async {
      final repo = repoWith((req) async => req.url.path == '/v1/auth/anonymous'
          ? json({'token': 't'})
          : json({
              'error': {'message': 'x'}
            }, 404));
      expect(await repo.article('nao-existe'), isNull);
    });
  });

  group('AppState', () {
    test('salva no aparelho e restaura', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open(vault: MemoryCredentialVault());
      final repo = MockRepository(latency: false);

      final a = AppState(repo: repo, store: store)
        ..completeOnboarding()
        ..setShowRumors(true)
        ..setAlertLevel(AlertLevel.realtime)
        ..toggleSave('rust-windows')
        ..addRecentSearch('nvidia');
      await a.persistNow();

      final b = AppState(repo: repo, store: store)..restore();
      expect(b.onboarded,
          isFalse); // Preferências locais não concedem acesso sem conta.
      expect(b.showRumors, isTrue);
      expect(b.alertLevel, AlertLevel.realtime);
      expect(b.savedIds, ['rust-windows']);
      expect(b.recentSearches.first.text, 'nvidia');
      a.dispose();
      b.dispose();
    });

    test('primeira abertura traz salvos, perfil e alertas do repositório',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open(vault: MemoryCredentialVault());
      final s = AppState(repo: MockRepository(latency: false), store: store)
        ..restore();
      await s.refreshRemote();
      expect(s.savedIds, mockSavedIds);
      expect(s.userName, 'João Guilherme');
      expect(s.alerts, isNotEmpty);
      s.dispose();
    });
  });
}
