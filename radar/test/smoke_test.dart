import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:radar/app.dart';
import 'package:radar/data/mock_repository.dart';
import 'package:radar/data/models.dart';
import 'package:radar/data/repository.dart';
import 'package:radar/routes.dart';
import 'package:radar/l10n/app_copy.dart';
import 'package:radar/state/app_state.dart';
import 'package:radar/widgets/article_comments.dart';

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
    await tester.pumpAndSettle();
    expect(fullArticle, findsOneWidget);
    final article = repo.byId('nvidia-fabrica')!;
    expect(find.text(article.title), findsOneWidget);
    expect(find.text(article.body.split('\n\n').first.trim()), findsOneWidget);
    expect(synopsis, findsNothing);
    expect(find.text('Fontes'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.textContaining(article.summary.first), findsOneWidget);
    expect(find.textContaining('Ouvir '), findsNothing);
    expect(find.text('Fontes'), findsOneWidget);
    state.setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('Translated synopsis.'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    final readTranslated = find.text('Read full article');
    await tester.ensureVisible(readTranslated);
    await tester.tap(readTranslated);
    await tester.pumpAndSettle();
    expect(find.text('Translated title'), findsOneWidget);
    expect(find.text('Translated full story.'), findsOneWidget);
    expect(find.text('Full article'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
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
    // Sem texto aberto: o botão abre a página do veículo dentro do app.
    expect(find.text('Ler matéria completa'), findsOneWidget);
    expect(find.text('O texto completo não está disponível no app.'),
        findsNothing);
    expect(find.text('Fontes'), findsOneWidget);

    // Desmonta pra cancelar timers (polling de notícias novas, toasts).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    state.dispose();
  });

  testWidgets('leitor publica comentário no formulário da matéria',
      (tester) async {
    final repo = MockRepository(latency: false);
    final state = _AuthenticatedState(repo);
    await tester.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(
        locale: Locale('pt', 'BR'),
        supportedLocales: [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleComments(articleId: 'nvidia-fabrica'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Boa análise!');
    await tester.pump();
    await tester.tap(find.text('Publicar comentário'));
    await tester.pumpAndSettle();
    expect(find.text('Boa análise!'), findsOneWidget);
    final page = await repo.articleComments('nvidia-fabrica');
    expect(page.items.single.body, 'Boa análise!');
    await tester.tap(find.text('Curtir · 0'));
    await tester.pumpAndSettle();
    expect(find.text('Descurtir · 1'), findsOneWidget);
    await tester.tap(find.text('Descurtir · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Curtir · 0'), findsOneWidget);
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Também concordo.');
    await tester.pump();
    final publishReply = find.text('Publicar resposta');
    await tester.ensureVisible(publishReply);
    await tester.tap(publishReply);
    await tester.pumpAndSettle();
    expect(find.text('Também concordo.'), findsOneWidget);
    final replies = await repo.articleComments('nvidia-fabrica',
        parentId: page.items.single.id);
    expect(replies.items.single.body, 'Também concordo.');
    await tester.pumpWidget(const SizedBox());
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
