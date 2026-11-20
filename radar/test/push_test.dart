import 'package:flutter_test/flutter_test.dart';
import 'package:radar/data/mock_repository.dart';
import 'package:radar/data/repository.dart';
import 'package:radar/services/platform_services.dart';

class _Repo extends MockRepository {
  _Repo() : super(latency: false);
  final tokens = <String>[];

  @override
  Future<void> registerPushToken(String token,
          {required String platform, String kind = 'token'}) async =>
      tokens.add(token);
}

class _Push extends PushProvider {
  _Push(this.allow);
  final bool allow;

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<String?> token() async => 'tok-123';
}

void main() {
  late _Repo repo;
  setUp(() => Repo.instance = repo = _Repo());
  tearDown(() => PlatformServices.instance.push = const NoPushProvider());

  test('sem provedor: não concede e não registra token', () async {
    expect(await PlatformServices.instance.requestPushPermission(), isFalse);
    expect(repo.tokens, isEmpty);
  });

  test('provedor aceitou: registra o token no backend', () async {
    PlatformServices.instance.push = _Push(true);
    expect(await PlatformServices.instance.requestPushPermission(), isTrue);
    expect(repo.tokens, ['tok-123']);
  });

  test('usuário recusou: não registra token', () async {
    PlatformServices.instance.push = _Push(false);
    expect(await PlatformServices.instance.requestPushPermission(), isFalse);
    expect(repo.tokens, isEmpty);
  });
}
