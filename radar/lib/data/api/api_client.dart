import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../json.dart';
import '../local_store.dart';
import '../repository.dart';

/// Cliente HTTP fino: base URL, token, timeout, erros padronizados.
///
/// Autenticação: na primeira chamada, se não houver token salvo, faz
/// `POST /v1/auth/anonymous` e guarda o token. 401 → renova a sessão uma vez, preservando a identidade.
class ApiClient {
  ApiClient(
      {required String baseUrl,
      required this.store,
      http.Client? client,
      this.timeout = const Duration(seconds: 15)})
      : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = client ?? http.Client();

  final String baseUrl;
  final LocalStore store;
  final Duration timeout;
  final http.Client _http;
  Future<void>? _authInFlight;
  Future<void>? _refreshInFlight;

  /// Plataforma enviada no login anônimo e no registro do token de push.
  static String get platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'other',
      };

  Future<dynamic> get(String path, {Map<String, Object?> query = const {}}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Uri _uri(String path, Map<String, Object?> query) {
    final q = <String, String>{
      for (final e in query.entries)
        if (e.value != null)
          e.key: e.value is DateTime
              ? (e.value as DateTime).toUtc().toIso8601String()
              : '${e.value}',
    };
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<void> _ensureToken() async {
    if (store.token != null) return;
    _authInFlight ??= () async {
      final res = await _raw('POST', '/v1/auth/anonymous',
          body: {'platform': platform}, auth: false);
      await _saveTokens(res as Json, account: false);
    }()
        .whenComplete(() => _authInFlight = null);
    await _authInFlight;
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, Object?> query = const {},
      Object? body,
      bool retried = false}) async {
    await _ensureToken();
    final sentToken = store.token;
    try {
      return await _raw(method, path, query: query, body: body);
    } on RepoException catch (e) {
      if (e.statusCode == 401 && !retried) {
        final attemptedToken = sentToken;
        _refreshInFlight ??=
            _renew(attemptedToken).whenComplete(() => _refreshInFlight = null);
        await _refreshInFlight;
        return _send(method, path, query: query, body: body, retried: true);
      }
      rethrow;
    }
  }

  Future<void> _saveTokens(Json result, {required bool account}) =>
      store.setCredentials(
          token: result.str('token'),
          refreshToken: result.strOrNull('refreshToken'),
          isAccount: account);

  Future<void> _renew(String? failedToken) async {
    if (store.token != failedToken) return;
    final refresh = store.refreshToken;
    if (refresh != null) {
      // Rede/5xx não apagam a sessão. Um refresh revogado também não troca a identidade silenciosamente.
      final result = await _raw('POST', '/v1/auth/refresh',
          body: {'refreshToken': refresh}, auth: false) as Json;
      if (store.token == failedToken) {
        await _saveTokens(result, account: store.isAccount);
      }
      return;
    }
    if (store.isAccount) {
      throw const RepoException('Sua sessão expirou. Entre novamente.',
          statusCode: 401);
    }
    // Migração de instalações antigas que possuíam somente access token.
    await store.setToken(null);
    await _ensureToken();
  }

  Future<void> signIn(String email, String password) async {
    await _ensureToken();
    Json result;
    try {
      result = await post('/v1/auth/login',
          body: {'email': email.trim(), 'password': password}) as Json;
    } on RepoException catch (e) {
      if (e.statusCode != 401) rethrow;
      // Uma sessão expirada não pode impedir login com novas credenciais.
      result = await _raw('POST', '/v1/auth/login',
          body: {'email': email.trim(), 'password': password},
          auth: false) as Json;
    }
    await _saveTokens(result, account: true);
  }

  Future<void> signUp(String name, String email, String password) async {
    final result = await post('/v1/auth/upgrade', body: {
      'name': name.trim(),
      'email': email.trim(),
      'password': password
    }) as Json;
    await _saveTokens(result, account: true);
  }

  Future<void> socialSignIn(String accessToken) async {
    await _ensureToken();
    Json result;
    try {
      result =
          await post('/v1/auth/supabase', body: {'accessToken': accessToken})
              as Json;
    } on RepoException catch (e) {
      if (e.statusCode != 401) rethrow;
      result = await _raw('POST', '/v1/auth/supabase',
          body: {'accessToken': accessToken}, auth: false) as Json;
    }
    await _saveTokens(result, account: true);
  }

  Future<void> linkSocial(String accessToken) async {
    await post('/v1/auth/link/supabase', body: {'accessToken': accessToken});
  }

  Future<void> forgotPassword(String email) async {
    await _raw('POST', '/v1/auth/forgot-password',
        body: {'email': email.trim()}, auth: false);
  }

  Future<void> resetPassword(String token, String password) async {
    await _raw('POST', '/v1/auth/reset-password',
        body: {'token': token, 'password': password}, auth: false);
  }

  Future<void> signOut() async {
    if (store.token != null) {
      try {
        await post('/v1/auth/logout');
      } on RepoException catch (e) {
        if (e.statusCode != 401) rethrow;
      }
    }
    await store.setToken(null);
    await store.clearUserData();
  }

  Future<dynamic> _raw(String method, String path,
      {Map<String, Object?> query = const {},
      Object? body,
      bool auth = true}) async {
    final req = http.Request(method, _uri(path, query))
      ..headers.addAll({
        'Accept': 'application/json',
        'Accept-Language': 'pt-BR',
        if (auth && store.token != null)
          'Authorization': 'Bearer ${store.token}',
      });
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res =
          await _http.send(req).then(http.Response.fromStream).timeout(timeout);
    } on TimeoutException {
      throw const RepoException(
          'A conexão está lenta. Tente de novo em instantes.',
          offline: true);
    } on http.ClientException {
      throw const RepoException(
          'Sem conexão. Mostrando as últimas notícias salvas.',
          offline: true);
    }

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 400) {
      throw RepoException(_errorMessage(text, res.statusCode),
          statusCode: res.statusCode);
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  /// Formato de erro da API: `{"error": {"code": "...", "message": "..."}}`.
  String _errorMessage(String body, int status) {
    try {
      final msg =
          ((jsonDecode(body) as Json)['error'] as Json?)?['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } on Object {
      // corpo não é JSON
    }
    return status >= 500
        ? 'O news.dev está instável agora. Tente de novo em instantes.'
        : 'Não deu certo. Tente de novo.';
  }
}
