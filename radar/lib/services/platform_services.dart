import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repository.dart';
import '../routes.dart';

/// Pontes com o sistema operacional.
///
/// Prontas: links externos (url_launcher), compartilhar (share_plus), avaliação
/// (in_app_review → SKStoreReviewController) e deep links (app_links).
/// Push depende do provedor, que ainda não foi escolhido (ver [PushProvider]).
class PlatformServices {
  PlatformServices._();
  static final instance = PlatformServices._();

  StreamSubscription<Uri>? _links;

  /// Provedor de push. Ainda não foi escolhido (APNs direto, Web Push ou outro provedor):
  /// quando for, basta implementar [PushProvider] e trocar aqui no main.dart.
  PushProvider push = const NoPushProvider();

  /// Chama o prompt nativo. Só deve ser usado depois da tela de pré-permissão.
  /// Se o usuário aceitar, manda o token pro backend (POST /v1/me/push-tokens).
  Future<bool> requestPushPermission() async {
    if (kIsWeb) return false;
    try {
      if (!await push.requestPermission()) return false;
    } on Object catch (e) {
      debugPrint('[platform] falha ao pedir permissão de push: $e');
      return false;
    }
    try {
      final token = await push.token();
      if (token != null) {
        await Repo.instance.registerPushToken(
          token,
          platform:
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          kind: push.identifierKind,
        );
      }
    } on Object catch (e) {
      debugPrint('[platform] falha ao registrar token de push: $e');
    }
    return true;
  }

  /// Abre no navegador do app (SFSafariViewController no iOS).
  Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (kIsWeb) return launchUrl(uri);
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// [png] é o card 1080×1920 pronto pros Stories.
  Future<void> shareImage(Uint8List? png, {String? text}) async {
    await SharePlus.instance.share(ShareParams(
      text: text,
      files: png == null
          ? null
          : [
              XFile.fromData(png, mimeType: 'image/png', name: 'radar-furo.png')
            ],
    ));
  }

  /// Atalhos do sheet de compartilhar. Sem o app instalado, cai na planilha do sistema.
  Future<void> shareTo(String channel, String url) async {
    final u = Uri.encodeComponent(url);
    final target = switch (channel) {
      'whatsapp' => Uri.parse('whatsapp://send?text=$u'),
      'x' => Uri.parse('https://x.com/intent/post?url=$u'),
      'linkedin' =>
        Uri.parse('https://www.linkedin.com/sharing/share-offsite/?url=$u'),
      _ => null,
    };
    final opened = target != null &&
        await launchUrl(target, mode: LaunchMode.externalApplication)
            .catchError((_) => false);
    if (!opened) {
      await SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));
    }
  }

  Future<void> requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) await review.requestReview();
  }

  /// radar://materia/{id}, radar://topico/{slug}, radar://alertas.
  /// Também trata o link que abriu o app (app fechado).
  void listenDeepLinks() {
    if (kIsWeb) return;
    final links = AppLinks();
    _links ??= links.uriLinkStream.listen(_open,
        onError: (Object e) => debugPrint('[platform] deep link: $e'));
  }

  void openDeepLink(Uri uri) => _open(uri);

  void _open(Uri uri) {
    if (rootNavigatorKey.currentState != null) {
      Routes.handleDeepLink(uri);
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => Routes.handleDeepLink(uri));
    }
  }
}

/// O que o app precisa de qualquer provedor de push.
abstract class PushProvider {
  const PushProvider();
  String get identifierKind => 'token';

  /// Mostra o prompt do sistema. true se o usuário permitiu.
  Future<bool> requestPermission();

  /// Token do aparelho pra mandar ao backend (null se ainda não tiver).
  Future<String?> token();
}

/// Enquanto o provedor não é escolhido: não pede nada e não registra token.
class NoPushProvider extends PushProvider {
  const NoPushProvider();

  @override
  Future<bool> requestPermission() async {
    debugPrint('[platform] push ainda sem provedor (TODO(push))');
    return false;
  }

  @override
  Future<String?> token() async => null;
}
