import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../utils/format.dart';
import 'json.dart';

/// Modelos do app + leitura/escrita em JSON.
/// O formato do JSON é o contrato com o backend: ver docs/API.md.
///
/// Convenções: chaves em camelCase, datas em RFC 3339 (UTC), enums como string,
/// campos opcionais podem vir ausentes ou null.

/// Categorias do contrato com o backend (seção 6 do prompt).
/// Cada uma carrega rótulo, ícone, cor e médias usadas na estimativa do onboarding.
enum NewsCategory {
  ia(
      'ia',
      'IA',
      'Inteligência Artificial',
      'Modelos, agentes, pesquisa e regulação.',
      Icons.auto_awesome,
      Icons.smart_toy_outlined,
      RColors.radar,
      Color(0xFF1F5F2B),
      18,
      3),
  seguranca(
      'seguranca',
      'Segurança',
      'Segurança',
      'Ataques, vazamentos, falhas e correções.',
      Icons.shield_outlined,
      Icons.shield_outlined,
      RColors.urgent,
      Color(0xFF4A0E0B),
      12,
      2),
  bigtech(
      'bigtech',
      'Big Techs',
      'Big Techs',
      'Nvidia, Apple, Google, Microsoft, Meta e seus CEOs.',
      Icons.account_balance_outlined,
      Icons.account_balance_outlined,
      RColors.orange,
      Color(0xFF5A2E00),
      15,
      2),
  programacao(
      'programacao',
      'Programação',
      'Programação',
      'Linguagens, ferramentas e open source.',
      Icons.code,
      Icons.code,
      RColors.link,
      Color(0xFF062A5C),
      10,
      1),
  dados(
      'dados',
      'Área de dados',
      'Área de dados',
      'Análise de dados, SQL, BI, engenharia de dados e carreira.',
      Icons.analytics_outlined,
      Icons.analytics_outlined,
      RColors.link,
      Color(0xFF062A5C),
      0,
      0),
  chips(
      'chips',
      'Chips',
      'Chips e hardware',
      'GPUs, fábricas, semicondutores e data centers.',
      Icons.memory,
      Icons.memory,
      RColors.purple,
      Color(0xFF3A0F4F),
      6,
      1),
  startups(
      'startups',
      'Startups',
      'Startups',
      'Rodadas, aquisições e quem está crescendo.',
      Icons.rocket_launch_outlined,
      Icons.rocket_launch_outlined,
      RColors.radar,
      Color(0xFF1F5F2B),
      8,
      1),
  gadgets(
      'gadgets',
      'Gadgets',
      'Gadgets',
      'Celulares, wearables e lançamentos.',
      Icons.smartphone,
      Icons.smartphone,
      RColors.link,
      Color(0xFF062A5C),
      9,
      1),
  games(
      'games',
      'Games',
      'Games',
      'Consoles, estúdios e a indústria de jogos.',
      Icons.sports_esports_outlined,
      Icons.sports_esports_outlined,
      RColors.purple,
      Color(0xFF3A0F4F),
      7,
      0),
  regulacao(
      'regulacao',
      'Regulação',
      'Regulação',
      'Leis, governo e o que muda pra quem usa tecnologia.',
      Icons.balance,
      Icons.balance,
      RColors.orange,
      Color(0xFF5A2E00),
      5,
      1),
  cripto(
      'cripto',
      'Cripto',
      'Cripto',
      'Bitcoin, blockchain e ativos digitais.',
      Icons.currency_bitcoin,
      Icons.currency_bitcoin,
      RColors.orange,
      Color(0xFF5A2E00),
      6,
      1),
  techBr(
      'tech-br',
      'Tech BR',
      'Tech no Brasil',
      'Startups, governo e empresas brasileiras.',
      Icons.flag_outlined,
      Icons.flag_outlined,
      RColors.radar,
      Color(0xFF1F5F2B),
      7,
      2),
  espaco(
      'espaco',
      'Espaço',
      'Espaço',
      'Foguetes, satélites e exploração espacial.',
      Icons.public,
      Icons.public,
      RColors.link,
      Color(0xFF062A5C),
      4,
      0);

  const NewsCategory(
      this.slug,
      this.label,
      this.fullName,
      this.description,
      this.icon,
      this.chipIcon,
      this.color,
      this.deep,
      this.dailyAvg,
      this.scoopsAvg);

  final String slug;
  final String label;
  final String fullName;
  final String description;
  final IconData icon;

  /// Ícone usado nos chips do onboarding (IA usa o robô).
  final IconData chipIcon;
  final Color color;

  /// Tom escuro da cor, fim do gradiente das miniaturas.
  final Color deep;
  final int dailyAvg;
  final int scoopsAvg;

  static NewsCategory fromSlug(String slug) => NewsCategory.values
      .firstWhere((c) => c.slug == slug, orElse: () => NewsCategory.ia);
}

/// No JSON vem como string: "normal" | "important" | "urgent".
enum Urgency {
  normal,
  important,
  urgent;

  static Urgency fromJson(Object? v) => Urgency.values
      .firstWhere((u) => u.name == v, orElse: () => Urgency.normal);
}

/// No JSON vem como string: "urgent" | "balanced" | "realtime".
enum AlertLevel {
  urgent,
  balanced,
  realtime;

  static AlertLevel fromJson(Object? v) => AlertLevel.values
      .firstWhere((l) => l.name == v, orElse: () => AlertLevel.balanced);
}

class Source {
  const Source(this.name, this.url,
      [this.color = RColors.bgControl, this.logoUrl]);
  final String name;
  final String url;

  /// Cor do avatar da fonte (enquanto não houver logoUrl).
  final Color color;
  final String? logoUrl;

  factory Source.fromJson(Json j) {
    final name = j.str('name');
    return Source(name, j.str('url'), j.color('color') ?? colorFromText(name),
        j.strOrNull('logoUrl'));
  }

  Json toJson() => {
        'name': name,
        'url': url,
        'color': colorToHex(color),
        if (logoUrl != null) 'logoUrl': logoUrl
      };
}

class Entity {
  const Entity(this.type, this.id, this.name);
  final String type; // company | person
  final String id;
  final String name;

  factory Entity.fromJson(Json j) =>
      Entity(j.str('type'), j.str('id'), j.str('name'));
  Json toJson() => {'type': type, 'id': id, 'name': name};
}

class ArticleTranslation {
  const ArticleTranslation(this.title, this.synopsis, this.body);
  final String title;
  final String synopsis;
  final String body;

  factory ArticleTranslation.fromJson(Json json) => ArticleTranslation(
        json.str('title'),
        json.str('synopsis'),
        json.str('body'),
      );
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.category,
    this.kicker,
    this.imageUrl,
    required this.detectedAt,
    required this.publishedAt,
    required this.sources,
    required this.sourceCount,
    this.firstInBrazil = false,
    this.leadMinutes,
    this.urgency = Urgency.normal,
    this.confirmed = true,
    required this.readingMinutes,
    this.audioUrl,
    this.audioMinutes,
    this.entities = const [],
    this.trendingTag,
  });

  final String id;
  final String title;
  final List<String> summary; // sempre 3 pontos
  final String body;
  final NewsCategory category;

  /// Rótulo editorial opcional no lugar da categoria (ex.: "Mercado").
  final String? kicker;
  final String? imageUrl;
  final DateTime detectedAt;
  final DateTime publishedAt;
  final List<Source> sources;
  final int sourceCount;
  final bool firstInBrazil;
  final int? leadMinutes;
  final Urgency urgency;
  final bool confirmed;
  final int readingMinutes;
  final String? audioUrl;
  final int? audioMinutes;
  final List<Entity> entities;
  final String? trendingTag;

  bool get isInternationalRss =>
      id.startsWith('rss-') &&
      sources.length == 1 &&
      const {
        'TechCrunch',
        'Ars Technica',
        'WIRED',
        'The Verge',
        'MIT Technology Review',
        'BBC News',
        'The Guardian',
        'The New York Times',
        'dbt Labs',
        'Microsoft Power BI',
      }.contains(sources.single.name);

  String get kickerLabel => kicker ?? category.label;

  /// "The Verge, Wired +6"
  String get sourcesLabel {
    final shown = sources.take(2).toList();
    final names = shown.map((s) => s.name).join(', ');
    final extra = sourceCount - shown.length;
    return extra > 0 ? '$names +$extra' : names;
  }

  static const shareHost = 'appnewsai.discloud.app';
  String get shareUrl => Uri.https(shareHost, '/m/$id').toString();
  String get deepLink => 'radar://materia/$id';

  Article copyWith({String? id, DateTime? publishedAt, DateTime? detectedAt}) =>
      Article(
        id: id ?? this.id,
        title: title,
        summary: summary,
        body: body,
        category: category,
        kicker: kicker,
        imageUrl: imageUrl,
        detectedAt: detectedAt ?? this.detectedAt,
        publishedAt: publishedAt ?? this.publishedAt,
        sources: sources,
        sourceCount: sourceCount,
        firstInBrazil: firstInBrazil,
        leadMinutes: leadMinutes,
        urgency: urgency,
        confirmed: confirmed,
        readingMinutes: readingMinutes,
        audioUrl: audioUrl,
        audioMinutes: audioMinutes,
        entities: entities,
        trendingTag: trendingTag,
      );

  int remainingMinutes(double progress) =>
      math.max(1, ((1 - progress) * readingMinutes).ceil());

  factory Article.fromJson(Json j) => Article(
        id: j.str('id'),
        title: j.str('title'),
        summary: j.list('summary').cast<String>(),
        body: j.str('body'),
        category: NewsCategory.fromSlug(j.str('category')),
        kicker: j.strOrNull('kicker'),
        imageUrl: j.strOrNull('imageUrl'),
        detectedAt: j.date('detectedAt'),
        publishedAt: j.date('publishedAt'),
        sources: j.objects('sources').map(Source.fromJson).toList(),
        sourceCount: j.integer('sourceCount'),
        firstInBrazil: j.boolean('firstInBrazil'),
        leadMinutes: j.intOrNull('leadMinutes'),
        urgency: Urgency.fromJson(j['urgency']),
        confirmed: j.boolean('confirmed', fallback: true),
        readingMinutes: j.integer('readingMinutes', fallback: 1),
        audioUrl: j.strOrNull('audioUrl'),
        audioMinutes: j.intOrNull('audioMinutes'),
        entities: j.objects('entities').map(Entity.fromJson).toList(),
        trendingTag: j.strOrNull('trendingTag'),
      );

  Json toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'body': body,
        'category': category.slug,
        if (kicker != null) 'kicker': kicker,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'detectedAt': detectedAt.toUtc().toIso8601String(),
        'publishedAt': publishedAt.toUtc().toIso8601String(),
        'sources': [for (final s in sources) s.toJson()],
        'sourceCount': sourceCount,
        'firstInBrazil': firstInBrazil,
        if (leadMinutes != null) 'leadMinutes': leadMinutes,
        'urgency': urgency.name,
        'confirmed': confirmed,
        'readingMinutes': readingMinutes,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioMinutes != null) 'audioMinutes': audioMinutes,
        'entities': [for (final e in entities) e.toJson()],
        if (trendingTag != null) 'trendingTag': trendingTag,
      };
}

class LiveUpdate {
  const LiveUpdate(this.at, this.text);
  final DateTime at;
  final String text;

  factory LiveUpdate.fromJson(Json j) =>
      LiveUpdate(j.date('at'), j.str('text'));
}

class LiveEvent {
  const LiveEvent({
    required this.id,
    required this.title,
    required this.headline,
    required this.startsAt,
    required this.endsAt,
    required this.updates,
  });
  final String id;
  final String title;
  final String headline;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<LiveUpdate> updates;

  factory LiveEvent.fromJson(Json j) => LiveEvent(
        id: j.str('id'),
        title: j.str('title'),
        headline: j.str('headline'),
        startsAt: j.date('startsAt'),
        endsAt: j.date('endsAt'),
        updates: j.objects('updates').map(LiveUpdate.fromJson).toList(),
      );
}

class WeeklyStats {
  const WeeklyStats(
      {required this.scoops,
      required this.streakDays,
      required this.avgLeadMinutes,
      required this.perDay});
  final int scoops;
  final int streakDays;
  final int avgLeadMinutes;
  final List<int> perDay; // 7 valores, seg→dom

  factory WeeklyStats.fromJson(Json j) => WeeklyStats(
        scoops: j.integer('scoops'),
        streakDays: j.integer('streakDays'),
        avgLeadMinutes: j.integer('avgLeadMinutes'),
        perDay: j.list('perDay').map((v) => (v as num).toInt()).toList(),
      );

  Json toJson() => {
        'scoops': scoops,
        'streakDays': streakDays,
        'avgLeadMinutes': avgLeadMinutes,
        'perDay': perDay
      };
}

class AlertItem {
  AlertItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.icon,
    required this.color,
    this.unread = false,
    this.articleId,
  });
  final String id;
  final String title;
  final String subtitle;
  final DateTime at;
  final IconData icon;
  final Color color;
  bool unread;
  final String? articleId;

  /// O backend manda o tipo do alerta; ícone e cor são decididos aqui.
  /// type: "urgent" | "scoop" | "digest" | "article" (este usa a cor da `category`).
  factory AlertItem.fromJson(Json j) {
    final category = j.strOrNull('category');
    final (icon, color) = switch (j.str('type')) {
      'urgent' => (Icons.notification_important_outlined, RColors.urgent),
      'scoop' => (Icons.bolt, RColors.radar),
      'digest' => (Icons.auto_awesome, RColors.link),
      _ when category != null => (
          NewsCategory.fromSlug(category).icon,
          NewsCategory.fromSlug(category).color
        ),
      _ => (Icons.notifications_none, RColors.textSecondary),
    };
    return AlertItem(
      id: j.str('id'),
      title: j.str('title'),
      subtitle: j.str('subtitle'),
      at: j.date('at'),
      icon: icon,
      color: color,
      unread: !j.boolean('read'),
      articleId: j.strOrNull('articleId'),
    );
  }
}

class EntityInfo {
  const EntityInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    required this.articleCount,
    required this.scoopsToday,
  });
  final String id;
  final String name;
  final String kind; // "Empresa" | "Pessoa"
  final Color color;
  final int articleCount;
  final int scoopsToday;

  /// JSON: { id, type: "company" | "person", name, color?, articleCount, scoopsToday }
  factory EntityInfo.fromJson(Json j) {
    final name = j.str('name');
    return EntityInfo(
      id: j.str('id'),
      name: name,
      kind: j.str('type') == 'person' ? 'Pessoa' : 'Empresa',
      color: j.color('color') ?? colorFromText(name),
      articleCount: j.integer('articleCount'),
      scoopsToday: j.integer('scoopsToday'),
    );
  }
}

class Person {
  const Person(this.initials, this.shortName, this.fullName, this.color);
  final String initials;
  final String shortName;
  final String fullName;
  final Color color;

  /// JSON: { id, name: "Jensen Huang", shortName?: "J. Huang", color? }
  factory Person.fromJson(Json j) {
    final name = j.str('name');
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    final short = parts.length > 1 ? '${parts.first[0]}. ${parts.last}' : name;
    return Person(initials, j.strOrNull('shortName') ?? short, name,
        j.color('color') ?? colorFromText(name));
  }
}

class TopicStat {
  const TopicStat(this.category, this.delta, this.today);
  final NewsCategory category;
  final String delta;
  final int today;

  /// JSON: { category: "ia", deltaPercent: 12, today: 48 }
  factory TopicStat.fromJson(Json j) {
    final d = j.integer('deltaPercent');
    final sign = d >= 0 ? '+' : '';
    return TopicStat(NewsCategory.fromSlug(j.str('category')), '$sign$d%',
        j.integer('today'));
  }
}

class TrendingItem {
  const TrendingItem(this.articleId, this.title, this.readers);
  final String articleId;
  final String title;
  final String readers;

  /// JSON: { articleId, title, readers: 12400 } → "12,4 mil lendo"
  factory TrendingItem.fromJson(Json j) => TrendingItem(j.str('articleId'),
      j.str('title'), '${compactCount(j.integer('readers'))} lendo');
}

class RecentSearch {
  const RecentSearch(this.text, {this.trending = false});
  final String text;
  final bool trending;

  factory RecentSearch.fromJson(Json j) =>
      RecentSearch(j.str('text'), trending: j.boolean('trending'));
  Json toJson() => {'text': text, 'trending': trending};
}

// ---------------------------------------------------------------------------
// Respostas da API (ver docs/API.md). Agrupam o que cada tela precisa numa chamada.

/// Página do feed. `nextCursor == null` = acabou.
class FeedPage {
  const FeedPage({required this.items, this.nextCursor, this.offline = false});
  final List<Article> items;
  final String? nextCursor;

  /// true quando veio do cache local por falta de conexão.
  final bool offline;
  bool get hasMore => nextCursor != null;

  factory FeedPage.fromJson(Json j) => FeedPage(
      items: j.objects('items').map(Article.fromJson).toList(),
      nextCursor: j.strOrNull('nextCursor'));
}

/// "Em alta hoje" da home: tag, total de matérias e 7 barras.
class TrendingTag {
  const TrendingTag(
      {required this.tag, required this.count, required this.perDay});
  final String tag;
  final int count;
  final List<int> perDay;

  factory TrendingTag.fromJson(Json j) => TrendingTag(
        tag: j.str('tag'),
        count: j.integer('count'),
        perDay: j.list('perDay').map((v) => (v as num).toInt()).toList(),
      );
}

/// Topo da home (05): card de destaque, contador de furos e "Em alta hoje".
class HomeSummary {
  const HomeSummary(
      {required this.hero,
      required this.scoopsSinceLastNight,
      required this.trending});
  final Article? hero;
  final int scoopsSinceLastNight;
  final TrendingTag trending;

  factory HomeSummary.fromJson(Json j) => HomeSummary(
        hero: j['hero'] == null ? null : Article.fromJson(j.obj('hero')),
        scoopsSinceLastNight: j.integer('scoopsSinceLastNight'),
        trending: TrendingTag.fromJson(j.obj('trending')),
      );
}

/// Página de tópico (08).
class TopicPage {
  const TopicPage({
    required this.today,
    required this.week,
    required this.scoops,
    required this.companies,
    required this.feed,
  });
  final int today;
  final int week;
  final int scoops;

  /// Nomes pros chips de filtro ("OpenAI", "Anthropic"...). "Tudo" é adicionado no app.
  final List<String> companies;
  final FeedPage feed;

  factory TopicPage.fromJson(Json j) => TopicPage(
        today: j.integer('today'),
        week: j.integer('week'),
        scoops: j.integer('scoops'),
        companies: j.list('companies').cast<String>(),
        feed: FeedPage.fromJson(j.obj('feed')),
      );
}

/// Explorar (07).
class ExploreData {
  const ExploreData(
      {required this.topics, required this.trending, required this.people});
  final List<TopicStat> topics;
  final List<TrendingItem> trending;
  final List<Person> people;

  factory ExploreData.fromJson(Json j) => ExploreData(
        topics: j.objects('topics').map(TopicStat.fromJson).toList(),
        trending: j.objects('trending').map(TrendingItem.fromJson).toList(),
        people: j.objects('people').map(Person.fromJson).toList(),
      );
}

/// Busca (09). Tópicos são resolvidos no app (lista fixa de categorias).
class SearchResult {
  const SearchResult(
      {this.articles = const [], this.entity, this.people = const []});
  final List<Article> articles;
  final EntityInfo? entity;
  final List<Person> people;

  static const empty = SearchResult();

  factory SearchResult.fromJson(Json j) => SearchResult(
        articles: j.objects('articles').map(Article.fromJson).toList(),
        entity:
            j['entity'] == null ? null : EntityInfo.fromJson(j.obj('entity')),
        people: j.objects('people').map(Person.fromJson).toList(),
      );
}

/// GET /me
class UserProfile {
  const UserProfile(
      {required this.id,
      required this.name,
      required this.createdAt,
      this.email});
  final String id;
  final String name;
  final DateTime createdAt;
  final String? email;

  factory UserProfile.fromJson(Json j) => UserProfile(
      id: j.str('id'),
      name: j.str('name'),
      createdAt: j.date('createdAt'),
      email: j.strOrNull('email'));
}

/// Item salvo. O progresso de leitura vai de 0 a 1.
class SavedEntry {
  const SavedEntry(
      {required this.articleId,
      required this.savedAt,
      this.progress = 0,
      this.archived = false});
  final String articleId;
  final DateTime savedAt;
  final double progress;
  final bool archived;

  factory SavedEntry.fromJson(Json j) => SavedEntry(
        articleId: j.str('articleId'),
        savedAt: j.date('savedAt'),
        progress: j.number('progress'),
        archived: j.boolean('archived'),
      );
}

/// Preferências do usuário (seção 6 do prompt + `urgentAlerts`, que o Perfil precisa).
class UserPrefs {
  const UserPrefs({
    required this.topics,
    required this.alertLevel,
    required this.digestTimes,
    this.quietHours,
    required this.showRumors,
    required this.urgentAlerts,
    required this.followedEntities,
  });
  final List<NewsCategory> topics;
  final AlertLevel alertLevel;

  /// ["08:00", "19:00"] ou vazio quando o resumo está desligado.
  final List<String> digestTimes;
  final ({String from, String to})? quietHours;
  final bool showRumors;
  final bool urgentAlerts;
  final List<String> followedEntities;

  factory UserPrefs.fromJson(Json j) {
    final q = j['quietHours'];
    return UserPrefs(
      topics:
          j.list('topics').cast<String>().map(NewsCategory.fromSlug).toList(),
      alertLevel: AlertLevel.fromJson(j['alertLevel']),
      digestTimes: j.list('digestTimes').cast<String>(),
      quietHours:
          q is Map ? (from: q['from'] as String, to: q['to'] as String) : null,
      showRumors: j.boolean('showRumors'),
      urgentAlerts: j.boolean('urgentAlerts', fallback: true),
      followedEntities: j.list('followedEntities').cast<String>(),
    );
  }

  Json toJson() => {
        'topics': [for (final t in topics) t.slug],
        'alertLevel': alertLevel.name,
        'digestTimes': digestTimes,
        'quietHours': quietHours == null
            ? null
            : {'from': quietHours!.from, 'to': quietHours!.to},
        'showRumors': showRumors,
        'urgentAlerts': urgentAlerts,
        'followedEntities': followedEntities,
      };
}
