import 'package:flutter_test/flutter_test.dart';
import 'package:radar/app.dart';
import 'package:radar/screens/onboarding/topics_screen.dart';
import 'package:radar/data/models.dart';
import 'package:radar/state/app_state.dart';
import 'package:radar/utils/format.dart';

void main() {
  testWidgets('abre nas boas-vindas', (tester) async {
    await tester.pumpWidget(RadarApp(state: AppState()));
    expect(find.text('Tecnologia, antes de todo mundo.'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });

  test('estimativa do onboarding bate com o design (IA + Segurança + Programação)', () {
    final (daily, scoops) =
        TopicsScreen.estimate({NewsCategory.ia, NewsCategory.seguranca, NewsCategory.programacao});
    expect(daily, 40);
    expect(scoops, 6);
  });

  test('tempo relativo em pt-BR', () {
    final now = DateTime(2026, 11, 12, 10, 0);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'agora');
    expect(relativeTime(now.subtract(const Duration(minutes: 4)), now: now), 'há 4 min');
    expect(relativeTime(now.subtract(const Duration(hours: 1)), now: now), 'há 1 h');
    expect(relativeTime(DateTime(2026, 11, 11, 21, 14), now: now), 'ontem às 21:14');
  });
}
