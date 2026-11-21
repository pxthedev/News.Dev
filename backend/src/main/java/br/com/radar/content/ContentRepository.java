package br.com.radar.content;

import static br.com.radar.common.PostgresStore.*;
import static br.com.radar.content.ContentModels.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Repository;

@Repository
public class ContentRepository {
  private final PostgresStore store;
  private final JsonStore json;

  public ContentRepository(PostgresStore store, JsonStore json) {
    this.store = store;
    this.json = json;
  }

  public Article decode(DocumentSnapshot doc) {
    return json.read(doc.getString("payload"), Article.class);
  }

  public Article find(String id) {
    var doc = store.get(store.doc("articles", id));
    require(doc);
    return decode(doc);
  }

  public List<Article> byIds(List<String> ids) {
    if (ids.size() > 100) throw ApiException.invalid("Busque até 100 matérias de cada vez.");
    if (ids.isEmpty()) return List.of();
    var refs =
        ids.stream()
            .distinct()
            .map(id -> store.doc("articles", id))
            .toArray(DocumentReference[]::new);
    return await(store.getAll(refs)).stream()
        .filter(DocumentSnapshot::exists)
        .map(this::decode)
        .toList();
  }

  public Query base(boolean rumors) {
    Query q =
        store.collection("articles").whereLessThanOrEqualTo("publishedAt", time(Instant.now()));
    return rumors ? q : q.whereEqualTo("confirmed", true);
  }

  private Query ordered(Query q) {
    return q.orderBy("publishedAt", Query.Direction.DESCENDING)
        .orderBy(FieldPath.documentId(), Query.Direction.DESCENDING);
  }

  private List<Query> queries(
      String user,
      String filter,
      boolean rumors,
      String category,
      String company,
      List<String> topics) {
    if (!List.of("for-you", "urgent", "following").contains(filter))
      throw ApiException.invalid("Escolha um filtro de feed válido.");
    Query q = base(rumors);
    if (category != null) q = q.whereEqualTo("category", category);
    if (company != null && !company.isBlank())
      q = q.whereArrayContains("companyKeys", fold(company));
    if (filter.equals("urgent")) q = q.whereIn("urgency", List.of("important", "urgent"));
    if (!filter.equals("following")) return List.of(q);
    var u = store.get(store.doc("users", user));
    var follows = u.exists() ? u.get("following") : null;
    List<?> entities = follows instanceof List<?> list ? list : List.of();
    var queries = new ArrayList<Query>();
    if (!topics.isEmpty()) queries.add(q.whereIn("category", topics.stream().distinct().toList()));
    for (int i = 0; i < entities.size(); i += 30)
      queries.add(
          q.whereArrayContainsAny(
              "entityIds", entities.subList(i, Math.min(i + 30, entities.size()))));
    return queries;
  }

  private Query cursor(Query q, String cursor) {
    if (cursor == null) return q;
    try {
      if (cursor.length() > 500) throw new IllegalArgumentException();
      String[] parts =
          new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8)
              .split("\\|", -1);
      if (parts.length != 2 || !parts[1].matches("[a-z0-9-]{1,100}"))
        throw new IllegalArgumentException();
      return q.startAfter(time(Instant.parse(parts[0])), parts[1]);
    } catch (Exception e) {
      throw ApiException.invalid("O cursor é inválido. Atualize a lista.");
    }
  }

  public Page<Article> feed(
      String user,
      String filter,
      boolean rumors,
      String category,
      String company,
      String cursor,
      int limit,
      List<String> topics) {
    var unique = new HashMap<String, Article>();
    // Validar cursor também quando o usuário ainda não segue nada.
    if (cursor != null) cursor(ordered(base(rumors)), cursor);
    for (Query query : queries(user, filter, rumors, category, company, topics))
      for (var doc : store.query(cursor(ordered(query), cursor).limit(limit + 1)))
        unique.put(doc.getId(), decode(doc));
    var ordered =
        unique.values().stream()
            .sorted(
                Comparator.comparing(Article::publishedAt).thenComparing(Article::id).reversed())
            .toList();
    boolean more = ordered.size() > limit;
    var items = ordered.subList(0, Math.min(limit, ordered.size()));
    String next = null;
    if (more) {
      var last = items.getLast();
      next =
          Base64.getUrlEncoder()
              .withoutPadding()
              .encodeToString(
                  (last.publishedAt() + "|" + last.id()).getBytes(StandardCharsets.UTF_8));
    }
    return new Page<>(items, next);
  }

  public int newCount(
      String user, String filter, boolean rumors, Instant since, List<String> topics) {
    var queries = queries(user, filter, rumors, null, null, topics);
    if (queries.size() == 1)
      return Math.toIntExact(
          await(queries.getFirst().whereGreaterThan("publishedAt", time(since)).count().get())
              .getCount());
    var ids = new HashSet<String>();
    for (var q : queries)
      for (var doc :
          store.query(q.whereGreaterThan("publishedAt", time(since)).select(new String[0])))
        ids.add(doc.getId());
    return ids.size();
  }

  public List<Article> search(String term, boolean rumors) {
    String normalized = fold(term);
    if (normalized.length() < 2) return List.of();
    String first = normalized.split("[^a-z0-9]+")[0];
    if (first.isBlank()) return List.of();
    // Busca lexical indexada com GIN/JSONB, preservando os termos do contrato da API.
    return store
        .query(ordered(base(rumors).whereArrayContains("searchTerms", first)).limit(200))
        .stream()
        .map(this::decode)
        .filter(
            a ->
                fold(a.title()
                        + " "
                        + String.join(" ", a.summary())
                        + " "
                        + a.entities().stream().map(Entity::name).reduce("", (x, y) -> x + " " + y))
                    .contains(normalized))
        .limit(50)
        .toList();
  }

  public void save(Article a) {
    if (a.sourceCount() < a.sources().size())
      throw ApiException.invalid("O total de fontes não pode ser menor que a lista de fontes.");
    if (a.entities().stream().map(Entity::id).distinct().count() != a.entities().size())
      throw ApiException.invalid("Remova as entidades duplicadas.");
    var companies = new LinkedHashSet<String>();
    a.entities().stream()
        .filter(e -> e.type().equals("company"))
        .forEach(
            e -> {
              companies.add(fold(e.id()));
              companies.add(fold(e.name()));
            });
    var terms = new LinkedHashSet<String>();
    String search =
        fold(
            a.title()
                + " "
                + String.join(" ", a.summary())
                + " "
                + a.entities().stream().map(Entity::name).reduce("", (x, y) -> x + " " + y));
    for (String word : search.split("[^a-z0-9]+")) {
      if (word.length() < 2) continue;
      terms.add(word);
      for (int i = 2; i <= Math.min(word.length(), 24); i++) terms.add(word.substring(0, i));
      if (terms.size() > 2000) break;
    }
    await(
        store
            .doc("articles", a.id())
            .set(
                map(
                    "payload",
                    json.write(a),
                    "title",
                    a.title(),
                    "category",
                    a.category(),
                    "confirmed",
                    a.confirmed(),
                    "urgency",
                    a.urgency(),
                    "firstInBrazil",
                    a.firstInBrazil(),
                    "leadMinutes",
                    a.leadMinutes(),
                    "publishedAt",
                    time(a.publishedAt()),
                    "trendingTag",
                    a.trendingTag(),
                    "entityIds",
                    a.entities().stream().map(Entity::id).toList(),
                    "companyKeys",
                    new ArrayList<>(companies),
                    "searchTerms",
                    new ArrayList<>(terms),
                    "entities",
                    a.entities().stream()
                        .map(e -> Map.of("id", e.id(), "name", e.name(), "type", e.type()))
                        .toList())));
  }

  public void delete(String id) {
    var ref = store.doc("articles", id);
    store.transaction(
        tx -> {
          require(await(tx.get(ref)));
          tx.delete(ref);
          return null;
        });
  }

  public LiveEvent live(String id) {
    var doc = store.get(store.doc("liveEvents", id));
    require(doc);
    return json.read(doc.getString("payload"), LiveEvent.class);
  }

  public void saveLive(LiveEvent e) {
    if (!e.endsAt().isAfter(e.startsAt()))
      throw ApiException.invalid("O término deve ser depois do início.");
    var ordered =
        new LiveEvent(
            e.id(),
            e.title(),
            e.headline(),
            e.startsAt(),
            e.endsAt(),
            e.updates().stream().sorted(Comparator.comparing(LiveUpdate::at).reversed()).toList());
    await(store.doc("liveEvents", e.id()).set(Map.of("payload", json.write(ordered))));
  }

  public void deleteLive(String id) {
    var ref = store.doc("liveEvents", id);
    store.transaction(
        tx -> {
          require(await(tx.get(ref)));
          tx.delete(ref);
          return null;
        });
  }

  public static String fold(String value) {
    return Normalizer.normalize(value, Normalizer.Form.NFD)
        .replaceAll("\\p{M}", "")
        .toLowerCase(Locale.ROOT)
        .trim();
  }
}
