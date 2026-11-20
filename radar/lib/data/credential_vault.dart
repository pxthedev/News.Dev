import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialVault {
  Future<String?> read();
  Future<void> write(String? value);
}

/// Um único registro criptografado mantém access/refresh consistentes após reiniciar.
class SecureCredentialVault implements CredentialVault {
  const SecureCredentialVault();
  static const _storage = FlutterSecureStorage();
  static const _key = 'radar.credentials.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: value);
}

/// Injetado somente nos testes; o app inicializa SecureCredentialVault.
class MemoryCredentialVault implements CredentialVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async {
    this.value = value;
  }
}
