import 'package:cupertino_ui/cupertino_ui.dart';

import 'data/models.dart';
import 'screens/alerts_screen.dart';
import 'screens/account_screen.dart';
import 'screens/article_screen.dart';
import 'screens/article_list_screen.dart';
import 'screens/onboarding/topics_screen.dart';
import 'screens/previews/dynamic_island_preview.dart';
import 'screens/previews/home_widgets_preview.dart';
import 'screens/previews/live_activity_preview.dart';
import 'screens/previews/lock_screen_preview.dart';
import 'screens/previews/previews_screen.dart';
import 'screens/search_screen.dart';
import 'screens/topic_screen.dart';
import 'services/analytics.dart';
import 'state/app_state.dart';
import 'widgets/account_gate.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class ArticleArgs {
  const ArticleArgs(this.id, {this.source = 'feed'});
  final String id;
  final String source; // feed | push | widget | live
}

class ListArgs {
  const ListArgs(this.title, this.articles);
  final String title;
  final List<Article> articles;
}

/// Rotas nomeadas + deep links (radar://materia/{id}, radar://topico/{slug}, radar://alertas).
abstract final class Routes {
  static const account = '/conta';
  static const resetPassword = '/recuperar-senha';
  static const article = '/materia';
  static const topic = '/topico';
  static const alerts = '/alertas';
  static const search = '/busca';
  static const list = '/lista';
  static const editTopics = '/topicos';
  static const previews = '/previas';
  static const lockScreen = '/previas/bloqueio';
  static const liveActivity = '/previas/live-activity';
  static const dynamicIsland = '/previas/dynamic-island';
  static const homeWidgets = '/previas/widgets';

  static Route<dynamic>? generate(RouteSettings s) {
    final args = s.arguments;
    final Widget? page = switch (s.name) {
      Routes.account => const AccountScreen(),
      Routes.resetPassword => AccountScreen(resetToken: args as String),
      Routes.article => ArticleScreen(
          articleId: args is ArticleArgs ? args.id : args as String),
      Routes.topic => TopicScreen(
          category: args is NewsCategory
              ? args
              : NewsCategory.fromSlug(args as String)),
      Routes.alerts => const AlertsScreen(),
      Routes.search => SearchScreen(initialQuery: args is String ? args : ''),
      Routes.list => ArticleListScreen(args: args as ListArgs),
      Routes.editTopics => const TopicsScreen(editing: true),
      Routes.previews => const PreviewsScreen(),
      Routes.lockScreen => const LockScreenPreview(),
      Routes.liveActivity => const LiveActivityPreview(),
      Routes.dynamicIsland => const DynamicIslandPreview(),
      Routes.homeWidgets => const HomeWidgetsPreview(),
      _ => null,
    };
    if (page == null) return null;
    return CupertinoPageRoute<dynamic>(
        builder: (_) => s.name == resetPassword || s.name == account
            ? page
            : AccountGate(child: page),
        settings: s);
  }

  static NavigatorState get _nav => rootNavigatorKey.currentState!;

  static Future<void> openArticle(String id, {String source = 'feed'}) {
    Analytics.log('article_opened', {'id': id, 'source': source});
    return _nav.pushNamed(article, arguments: ArticleArgs(id, source: source));
  }

  static Future<void> openTopic(NewsCategory c) =>
      _nav.pushNamed(topic, arguments: c);
  static Future<void> openAlerts() => _nav.pushNamed(alerts);
  static Future<void> openSearch([String query = '']) =>
      _nav.pushNamed(search, arguments: query);
  static Future<void> openList(String title, List<Article> articles) =>
      _nav.pushNamed(list, arguments: ListArgs(title, articles));
  static Future<void> push(String name) => _nav.pushNamed(name);

  /// Converte um deep link em rota. Ligue no pacote app_links:
  /// `AppLinks().uriLinkStream.listen(Routes.handleDeepLink);`
  static RouteSettings? fromUri(Uri uri) {
    final seg = uri.pathSegments;
    if (uri.scheme == 'https' &&
        uri.host == Article.shareHost &&
        uri.userInfo.isEmpty &&
        uri.port == 443 &&
        seg.length == 2 &&
        seg.first == 'm' &&
        _validArticleId(seg.last)) {
      return RouteSettings(
          name: article, arguments: ArticleArgs(seg.last, source: 'share'));
    }
    if (uri.scheme != 'radar') return null;
    return switch (uri.host) {
      'materia' when seg.length == 1 && _validArticleId(seg.first) =>
        RouteSettings(
            name: article,
            arguments: ArticleArgs(seg.first,
                source: uri.queryParameters['source'] ?? 'push')),
      'topico' when seg.isNotEmpty =>
        RouteSettings(name: topic, arguments: NewsCategory.fromSlug(seg.first)),
      'alertas' => const RouteSettings(name: alerts),
      'recuperar-senha'
          when (uri.queryParameters['token']?.length ?? 0) >= 32 =>
        RouteSettings(
            name: resetPassword, arguments: uri.queryParameters['token']),
      _ => null,
    };
  }

  static bool _validArticleId(String id) =>
      RegExp(r'^[a-z0-9-]{1,100}$').hasMatch(id);

  static void handleDeepLink(Uri uri) {
    final s = fromUri(uri);
    if (s == null) return;
    if (s.arguments is ArticleArgs) {
      final a = s.arguments as ArticleArgs;
      final state = AppScope.read(_nav.context);
      if (a.source == 'share' && !state.isAccount) {
        state.pendingSharedArticle = a.id;
        _nav.pushNamed(account);
        return;
      }
      openArticle(a.id, source: a.source);
      return;
    }
    _nav.pushNamed(s.name!, arguments: s.arguments);
  }
}
