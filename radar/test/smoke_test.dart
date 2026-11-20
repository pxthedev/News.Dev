import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radar/app.dart';
import 'package:radar/data/mock_repository.dart';
import 'package:radar/data/models.dart';
import 'package:radar/data/repository.dart';
import 'package:radar/routes.dart';
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

    final repo = MockRepository(latency: false);
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
    final translateButton = find.text('Traduzir notícia');
    await tester.ensureVisible(translateButton);
    await tester.tap(translateButton);
    await tester.pumpAndSettle();
    expect(find.text('Português'), findsOneWidget);
    expect(find.text('Inglês'), findsOneWidget);
    rootNavigatorKey.currentState!.pop();
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
