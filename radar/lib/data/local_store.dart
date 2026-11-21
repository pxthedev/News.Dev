import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'json.dart';
import 'credential_vault.dart';
import 'models.dart';

/// Persistência local (shared_preferences): estado do app, token da API
/// e cache offline (últimas 50 matérias do feed + matérias salvas).
class LocalStore {
  LocalStore(this._p, this._vault);
  final CredentialVault _vault;
  Json _credentials = {};
  final SharedPreferences _p;

  static Future<LocalStore> open(
      {CredentialVault vault = const SecureCredentialVault()}) async {
    final store = LocalStore(await SharedPreferences.getInstance(), vault);
    // Sessions from Firestore cannot be resumed in the new PostgreSQL store.
    // This runs once; subsequent launches preserve the current API credentials.
    if (store._p.getString(_kGeneration) != _generation) {
      await vault.write(null);
      await store.clearUserData();
      await store._p.remove(_kToken);
      await store._p.setString(_kGeneration, _generation);
    }
    final raw = await vault.read();
    if (raw != null) {
      try {
        store._credentials = jsonDecode(raw) as Json;
      } on Object {
        await vault.write(null);
      }
    }
    await store._p.remove(_kToken);
    return store;
  }

  static const feedCacheSize = 50;
  static const _kGeneration = 'backend_generation.v1';
  static const _generation = 'supabase-postgres-v1';
  static const _kState = 'app_state.v1';
  static const _kToken = 'api_token';
  static const _kFeed = 'feed_cache.v1';
  static const _kSavedArticles = 'saved_articles.v1';

  Json? _readJson(String key) {
    final raw = _p.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Json;
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeJson(String key, Json value) =>
      _p.setString(key, jsonEncode(value));

  // ---- Estado do app (preferências, salvos, buscas…)
  String? get appLanguage => _p.getString('app_language.v1');
  Future<void> writeAppLanguage(String code) =>
      _p.setString('app_language.v1', code);

  Json? readState() => _readJson(_kState);
  Future<void> writeState(Json state) => _writeJson(_kState, state);

  // ---- Token da API
  String? get token => _credentials['token'] as String?;
  String? get refreshToken => _credentials['refreshToken'] as String?;
  bool get isAccount => _credentials['isAccount'] == true;
  Future<void> setCredentials(
      {required String token,
      String? refreshToken,
      bool isAccount = false}) async {
    final value = <String, dynamic>{
      'token': token,
      'refreshToken': refreshToken,
      'isAccount': isAccount
    };
    await _vault.write(jsonEncode(value));
    _credentials = value;
  }

  Future<void> setToken(String? value) async {
    if (value != null) {
      await setCredentials(token: value);
      return;
    }
    await _vault.write(null);
    _credentials = {};
  }

  Future<void> clearUserData() async {
    for (final key in [_kState, _kFeed, _kSavedArticles]) {
      await _p.remove(key);
    }
  }

  // ---- Cache offline
  List<Article> cachedFeed() => _readArticles(_kFeed);

  Future<void> cacheFeed(List<Article> items) =>
      _writeArticles(_kFeed, items.take(feedCacheSize).toList());

  List<Article> savedArticles() => _readArticles(_kSavedArticles);

  /// Guarda o conteúdo completo das matérias salvas, pra ler sem internet.
  Future<void> cacheSavedArticles(List<Article> items) =>
      _writeArticles(_kSavedArticles, items);

  List<Article> _readArticles(String key) {
    final j = _readJson(key);
    if (j == null) return const [];
    try {
      return j.objects('items').map(Article.fromJson).toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _writeArticles(String key, List<Article> items) =>
      _writeJson(key, {
        'items': [for (final a in items) a.toJson()]
      });

  Future<void> clear() async {
    await setToken(null);
    await _p.clear();
  }
}
