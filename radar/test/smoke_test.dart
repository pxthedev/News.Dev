import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radar/app.dart';
import 'package:radar/data/mock_repository.dart';
import 'package:radar/data/models.dart';
import 'package:radar/data/repository.dart';
import 'package:radar/routes.dart';
import 'package:radar/l10n/app_copy.dart';
import 'package:radar/state/app_state.dart';

/// Abre o app já depois do onboarding e passa pelas telas que carregam dados do repositório.
void main() {
  testWidgets('home, matéria, tópico e busca carregam do repositório',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556); // iPhone 15 Pro
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A fonte de teste (Ahem) é bem mais larga que a SF Pro: ignora só avisos de overflow.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.toString().contains('overflowed')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);

    final repo = _TranslationRepository();
    Repo.instance = repo;
    final state = _AuthenticatedState(repo);
    await state.refreshRemote();

    await tester.pumpWidget(RadarApp(state: state));
    await tester.pump(const Duration(milliseconds: 100));

    // Home: destaque e contador vindos de home().
    expect(
        find.textContaining('confirma nova fábrica da Nvidia'), findsWidgets);
    expect(find.text('14 furos desde ontem à noite'), findsOneWidget);
    expect(find.text('#ransomware'), findsOneWidget);
    // Explorar e Salvos ficam montados no IndexedStack.
    expect(find.text('Em alta agora', skipOffstage: false), findsOneWidget);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    final hero = find.textContaining('confirma nova fábrica da Nvidia').first;
    final trending = find.text('#ransomware');
    expect(tester.getTopLeft(trending).dx,
        greaterThan(tester.getTopRight(hero).dx));

    tester.view.physicalSize = const Size(1440, 1500);
    await tester.pump();
    unawaited(Routes.openArticle('nvidia-fabrica'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmado por', skipOffstage: false),
        findsOneWidget);

    final synopsis = find.text('Sinopse');
    final fullArticle = find.text('Matéria completa');
    expect(synopsis, findsOneWidget);
    expect(fullArticle, findsNothing);
    final readButton = find.text('Ler matéria completa');
    await tester.ensureVisible(readButton);
    await tester.tap(readButton);
    await tester.pump();
    expect(fullArticle, findsOneWidget);
    expect(tester.getTopLeft(synopsis).dy,
        lessThan(tester.getTopLeft(fullArticle).dy));
    final points = repo.byId('nvidia-fabrica')!.summary;
    expect(find.textContaining(points.first), findsOneWidget);
    expect(find.textContaining('Ouvir '), findsNothing);
    expect(find.text('Fontes'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Fontes')).dy,
        greaterThan(tester.getTopLeft(fullArticle).dy));
    state.setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Translated synopsis.'), findsOneWidget);
    expect(find.text('Translated full story.'), findsOneWidget);
    expect(find.text('Full article'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    state.setLanguage(AppLanguage.portuguese);
    await tester.pumpAndSettle();

    unawaited(Routes.openTopic(NewsCategory.ia));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Inteligência Artificial', skipOffstage: false),
        findsOneWidget);
    expect(find.text('312', skipOffstage: false), findsOneWidget);

    unawaited(Routes.openSearch('nvidia'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Nvidia', skipOffstage: false), findsWidgets);

    unawaited(Routes.openArticle('rss-preview'));
    await tester.pumpAndSettle();
    expect(find.text('Ler matéria completa'), findsOneWidget);
    expect(find.text('Fontes'), findsOneWidget);

    // Desmonta pra cancelar timers (polling de notícias novas, toasts).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    state.dispose();
  });
}

void unawaited(Future<void> f) {}

class _AuthenticatedState extends AppState {
  _AuthenticatedState(RadarRepository repo)
      : super(repo: repo, onboarded: true);
  @override
  bool get isAccount => true;
}

class _TranslationRepository extends MockRepository {
  _TranslationRepository() : super(latency: false);
  @override
  Future<Article?> article(String id) async {
    if (id != 'rss-preview') return super.article(id);
    final sample = await super.article('nvidia-fabrica');
    return Article.fromJson({...sample!.toJson(), 'id': id, 'body': ''});
  }

  @override
  Future<ArticleTranslation> translateArticle(
          String id, String language) async =>
      const ArticleTranslation(
          'Translated title', 'Translated synopsis.', 'Translated full story.');
}
