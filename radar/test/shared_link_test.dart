import 'package:flutter_test/flutter_test.dart';
import 'package:radar/routes.dart';

void main() {
  test('opens only valid news.dev article links', () {
    final https =
        Routes.fromUri(Uri.parse('https://appnewsai.discloud.app/m/rss-123'));
    final fallback =
        Routes.fromUri(Uri.parse('radar://materia/rss-123?source=share'));
    for (final route in [https, fallback]) {
      expect(route?.name, Routes.article);
      final article = route?.arguments as ArticleArgs;
      expect(article.id, 'rss-123');
      expect(article.source, 'share');
    }
    expect(
        Routes.fromUri(Uri.parse('https://other.example/m/rss-123')), isNull);
    expect(Routes.fromUri(Uri.parse('https://appnewsai.discloud.app/m/a/b')),
        isNull);
  });
}
