import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repository.dart';

/// Supabase handles social identity only. API sessions stay in CredentialVault.
class SupabaseBridge {
  SupabaseBridge._();
  static bool ready = false;
  static Future<void>? _googleReady;
  static Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) return;
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw StateError('SUPABASE_URL deve usar HTTPS.');
    }
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        persistSession: false,
        autoRefreshToken: false,
        pkceAsyncStorage: _SecurePkceStorage(),
        detectSessionInUriPredicate: _isAuthCallback,
      ),
    );
    ready = true;
  }

  static bool _isAuthCallback(Uri uri) => kIsWeb
      ? uri.queryParameters.containsKey('code') ||
          uri.queryParameters.containsKey('error')
      : uri.scheme == 'radar' && uri.host == 'auth-callback';

  static Future<String> socialToken({required bool apple}) async {
    if (!ready) {
      throw const RepoException(
          'Login Google indisponível nesta versão. Use email e senha.');
    }
    final auth = Supabase.instance.client.auth;
    if (!apple &&
        !kIsWeb &&
        _configured('web') != null &&
        (defaultTargetPlatform == TargetPlatform.android ||
            (defaultTargetPlatform == TargetPlatform.iOS &&
                _configured('ios') != null))) {
      _googleReady ??= GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? _configured('ios')
            : null,
        serverClientId: _configured('web'),
      );
      try {
        await _googleReady;
      } on Object {
        _googleReady = null;
        rethrow;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const RepoException('Não foi possível obter o acesso do Google.');
      }
      final result = await auth.signInWithIdToken(
          provider: OAuthProvider.google, idToken: idToken);
      final token = result.session?.accessToken;
      if (token == null) {
        throw const RepoException('Não foi possível concluir o login.');
      }
      return token;
    }
    final completer = Completer<String>();
    final previous = auth.currentSession?.accessToken;
    final subscription = auth.onAuthStateChange.listen((event) {
      final token = event.session?.accessToken;
      if (event.event == AuthChangeEvent.signedIn &&
          token != null &&
          token != previous &&
          !completer.isCompleted) {
        completer.complete(token);
      }
    }, onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });
    try {
      final launched = await auth.signInWithOAuth(
        apple ? OAuthProvider.apple : OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'radar://auth-callback',
      );
      if (!launched) {
        throw const RepoException('Não foi possível abrir o login.');
      }
      return await completer.future.timeout(const Duration(minutes: 3),
          onTimeout: () => throw const RepoException(
              'O login não foi concluído. Tente novamente.'));
    } finally {
      await subscription.cancel();
    }
  }

  static Future<String> redirectedToken() async {
    final auth = Supabase.instance.client.auth;
    final current = auth.currentSession?.accessToken;
    if (current != null) return current;
    final event = await auth.onAuthStateChange
        .firstWhere((event) =>
            event.event == AuthChangeEvent.signedIn && event.session != null)
        .timeout(const Duration(seconds: 30));
    return event.session!.accessToken;
  }

  static String? _configured(String kind) {
    const web = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    const ios = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    final value = kind == 'ios' ? ios : web;
    return value.isEmpty ? null : value;
  }

  static Future<void> signOut() async {
    if (ready) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
    if (!kIsWeb && _googleReady != null) await GoogleSignIn.instance.signOut();
  }
}

/// The PKCE verifier is private; it must not be stored in plain preferences.
class _SecurePkceStorage extends GotrueAsyncStorage {
  const _SecurePkceStorage();
  static const _storage = FlutterSecureStorage();
  String _key(String key) => 'fionova.supabase.pkce.$key';
  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));
}
