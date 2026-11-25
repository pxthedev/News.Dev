package br.com.radar.user;

import static br.com.radar.common.PostgresStore.*;
import static br.com.radar.user.UserModels.*;

import br.com.radar.auth.IdentityRepository;
import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import br.com.radar.content.*;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.*;
import java.util.*;
import javax.imageio.ImageIO;
import javax.imageio.stream.MemoryCacheImageInputStream;
import org.springframework.stereotype.Repository;

@Repository
public class UserRepository {
  private final PostgresStore store;
  private final JsonStore json;
  private final IdentityRepository identities;

  public UserRepository(PostgresStore store, JsonStore json, IdentityRepository identities) {
    this.store = store;
    this.json = json;
    this.identities = identities;
  }

  public CollectionReference collection(String user, String name) {
    return identities.userRef(user).collection(name);
  }

  public Map<String, Object> profile(String user) {
    var u = identities.user(user);
    return map(
        "id",
        u.getId(),
        "name",
        u.getString("name"),
        "bio",
        u.getString("bio"),
        "avatarBase64",
        u.getString("avatarBase64"),
        "createdAt",
        u.getString("createdAt"),
        "email",
        u.getString("email"),
        "anonymous",
        u.getString("email") == null);
  }

  public Map<String, Object> updateProfile(String user, ProfileUpdate profile) {
    if (identities.user(user).getString("email") == null) throw ApiException.unauthorized();
    String name = profile.name().strip();
    if (name.isEmpty() || name.codePoints().anyMatch(Character::isISOControl)) {
      throw ApiException.invalid("Informe um nome válido.");
    }

    var changes = map("name", name, "bio", profile.bio().strip());
    if (profile.avatarBase64() != null) {
      if (profile.removeAvatar())
        throw ApiException.invalid("Escolha uma única alteração de foto.");
      changes.put("avatarBase64", validatedAvatar(profile.avatarBase64()));
    } else if (profile.removeAvatar()) {
      changes.put("avatarBase64", FieldValue.delete());
    }
    await(identities.userRef(user).update(changes));
    return profile(user);
  }

  static String validatedAvatar(String image) {
    try {
      byte[] bytes = Base64.getDecoder().decode(image);
      if (bytes.length == 0 || bytes.length > 256 * 1024) throw invalidAvatar();
      try (var input = new MemoryCacheImageInputStream(new ByteArrayInputStream(bytes))) {
        var readers = ImageIO.getImageReaders(input);
        if (!readers.hasNext()) throw invalidAvatar();
        var reader = readers.next();
        try {
          if (!Set.of("jpeg", "png").contains(reader.getFormatName().toLowerCase(Locale.ROOT))) {
            throw invalidAvatar();
          }
          reader.setInput(input, true, true);
          int width = reader.getWidth(0);
          int height = reader.getHeight(0);
          if (width < 1 || height < 1 || width > 1024 || height > 1024 || reader.read(0) == null)
            throw invalidAvatar();
        } finally {
          reader.dispose();
        }
      }
      return Base64.getEncoder().encodeToString(bytes);
    } catch (IllegalArgumentException | IOException e) {
      throw invalidAvatar();
    }
  }

  private static ApiException invalidAvatar() {
    return ApiException.invalid("Escolha uma imagem JPG ou PNG de até 256 KB.");
  }

  public Prefs prefs(String user) {
    var u = identities.user(user);
    String raw = u.getString("prefs");
    if (raw == null) throw ApiException.missing();
    var p = json.read(raw, Prefs.class);
    return new Prefs(
        p.topics(),
        p.alertLevel(),
        p.digestTimes(),
        p.quietHours(),
        p.showRumors(),
        p.urgentAlerts(),
        following(user));
  }

  public List<String> topics(String user) {
    try {
      return prefs(user).topics();
    } catch (ApiException e) {
      if (e.status.value() == 404) return List.of();
      throw e;
    }
  }

  @SuppressWarnings("unchecked")
  public List<String> following(String user) {
    Object f = identities.user(user).get("following");
    return f instanceof List<?> ? (List<String>) f : List.of();
  }

  public void savePrefs(String user, Prefs p) {
    await(
        identities
            .userRef(user)
            .update(
                map(
                    "prefs",
                    json.write(p),
                    "following",
                    p.followedEntities().stream().distinct().toList())));
  }

  public void follow(String user, String entity, boolean enabled) {
    store.transaction(
        tx -> {
          var ref = identities.userRef(user);
          var u = await(tx.get(ref));
          require(u);
          var following = new LinkedHashSet<String>();
          Object f = u.get("following");
          if (f instanceof List<?> list) list.forEach(x -> following.add((String) x));
          if (enabled) following.add(entity);
          else following.remove(entity);
          if (following.size() > 200)
            throw ApiException.invalid("Você já segue o limite de 200 entidades.");
          tx.update(ref, "following", new ArrayList<>(following));
          return null;
        });
  }

  public List<Map<String, Object>> saved(String user) {
    var docs =
        store.query(collection(user, "saved").orderBy("savedAt", Query.Direction.DESCENDING));
    var result = new ArrayList<Map<String, Object>>();
    for (int i = 0; i < docs.size(); i += 100) {
      var chunk = docs.subList(i, Math.min(i + 100, docs.size()));
      var refs =
          chunk.stream()
              .map(d -> store.doc("articles", d.getId()))
              .toArray(DocumentReference[]::new);
      var exists = new HashSet<String>();
      await(store.getAll(refs)).stream()
          .filter(DocumentSnapshot::exists)
          .forEach(d -> exists.add(d.getId()));
      for (var doc : chunk)
        if (exists.contains(doc.getId()))
          result.add(
              map(
                  "articleId",
                  doc.getId(),
                  "savedAt",
                  instant(doc.getInstant("savedAt")).toString(),
                  "progress",
                  doc.getDouble("progress"),
                  "archived",
                  doc.getBoolean("archived")));
    }
    return result;
  }

  public void save(String user, String article, SavedPatch p) {
    store.transaction(
        tx -> {
          var articleDoc = await(tx.get(store.doc("articles", article)));
          require(articleDoc);
          var ref = collection(user, "saved").document(article);
          var existing = await(tx.get(ref));
          var data =
              existing.exists()
                  ? new HashMap<>(existing.getData())
                  : map("savedAt", time(Instant.now()), "progress", 0.0, "archived", false);
          if (p.progress() != null) data.put("progress", p.progress());
          if (p.archived() != null) data.put("archived", p.archived());
          tx.set(ref, data);
          return null;
        });
    if (Boolean.TRUE.equals(p.archived()) || (p.progress() != null && p.progress() >= 1))
      recordRead(user, article);
  }

  public void unsave(String user, String article) {
    await(collection(user, "saved").document(article).delete());
  }

  public void recordRead(String user, String article) {
    String day = LocalDate.now(ContentService.ZONE).toString();
    store.transaction(
        tx -> {
          var a = await(tx.get(store.doc("articles", article)));
          require(a);
          var ref = collection(user, "reads").document(day + "_" + article);
          var old = await(tx.get(ref));
          var dayRef = collection(user, "readingDays").document(day);
          var daily = await(tx.get(dayRef));
          if (old.exists()) return null;
          boolean scoop = Boolean.TRUE.equals(a.getBoolean("firstInBrazil"));
          long lead = a.getLong("leadMinutes") == null ? 0 : a.getLong("leadMinutes");
          tx.create(
              ref, map("articleId", article, "day", day, "scoop", scoop, "leadMinutes", lead));
          var data =
              daily.exists()
                  ? new HashMap<>(daily.getData())
                  : map("day", day, "count", 0L, "scoops", 0L, "leadTotal", 0L);
          data.put("count", ((Number) data.get("count")).longValue() + 1);
          if (scoop) {
            data.put("scoops", ((Number) data.get("scoops")).longValue() + 1);
            data.put("leadTotal", ((Number) data.get("leadTotal")).longValue() + lead);
          }
          tx.set(dayRef, data);
          tx.set(
              store.doc("readerEvents", hash(user + "|" + article + "|" + day)),
              map("userId", user, "articleId", article, "day", day));
          return null;
        });
  }

  public Map<String, Object> weekly(String user) {
    LocalDate today = LocalDate.now(ContentService.ZONE),
        monday = today.minusDays(today.getDayOfWeek().getValue() - 1);
    var rows =
        store.query(
            collection(user, "readingDays").whereGreaterThanOrEqualTo("day", monday.toString()));
    var index = new HashMap<String, DocumentSnapshot>();
    rows.forEach(d -> index.put(d.getId(), d));
    var days = new ArrayList<Long>();
    long scoops = 0, lead = 0;
    for (int i = 0; i < 7; i++) {
      var row = index.get(monday.plusDays(i).toString());
      days.add(row == null ? 0 : row.getLong("count"));
      if (row != null) {
        scoops += row.getLong("scoops");
        lead += row.getLong("leadTotal");
      }
    }
    int streak = 0;
    LocalDate date = today;
    // Uma consulta por bloco de 90 dias, para sequências longas sem ler todo o histórico.
    boolean started = false, done = false;
    while (!done) {
      var recent =
          store.query(
              collection(user, "readingDays")
                  .whereLessThanOrEqualTo("day", date.toString())
                  .orderBy("day", Query.Direction.DESCENDING)
                  .limit(90));
      if (recent.isEmpty()) break;
      for (var row : recent) {
        var actual = LocalDate.parse(row.getId());
        if (!started && actual.equals(today.minusDays(1))) date = actual;
        if (!actual.equals(date)) {
          done = true;
          break;
        }
        started = true;
        streak++;
        date = date.minusDays(1);
      }
      if (recent.size() < 90) break;
    }
    return Map.of(
        "scoops",
        scoops,
        "avgLeadMinutes",
        scoops == 0 ? 0 : Math.round((double) lead / scoops),
        "streakDays",
        streak,
        "perDay",
        days);
  }

  public List<Map<String, Object>> alerts(String user) {
    return store
        .query(
            collection(user, "alerts")
                .whereGreaterThanOrEqualTo("at", time(Instant.now().minus(Duration.ofDays(7))))
                .orderBy("at", Query.Direction.DESCENDING)
                .limit(500))
        .stream()
        .map(
            d -> {
              var m = new LinkedHashMap<>(d.getData());
              m.put("id", d.getId());
              m.put("at", instant(d.getInstant("at")).toString());
              return (Map<String, Object>) m;
            })
        .toList();
  }

  public void readAlerts(String user, List<String> ids) {
    store.transaction(
        tx -> {
          var docs = new ArrayList<DocumentSnapshot>();
          for (String id : ids) docs.add(await(tx.get(collection(user, "alerts").document(id))));
          for (var doc : docs) if (doc.exists()) tx.update(doc.getReference(), "read", true);
          return null;
        });
  }

  public void push(String user, PushToken p) {
    await(
        store
            .doc("pushTokens", hash(p.token()))
            .set(
                map(
                    "token",
                    p.token(),
                    "userId",
                    user,
                    "platform",
                    p.platform(),
                    "kind",
                    p.kind() == null ? "token" : p.kind(),
                    "updatedAt",
                    time(Instant.now()))));
  }

  public void waitlist(String user) {
    store.transaction(
        tx -> {
          var ref = identities.userRef(user);
          var u = await(tx.get(ref));
          require(u);
          if (u.get("communityJoinedAt") == null)
            tx.update(ref, "communityJoinedAt", Instant.now().toString());
          return null;
        });
  }

  public String createAlert(AlertRequest a) {
    identities.user(a.userId());
    if (a.articleId() != null) require(store.get(store.doc("articles", a.articleId())));
    String id = UUID.randomUUID().toString();
    await(
        collection(a.userId(), "alerts")
            .document(id)
            .create(
                map(
                    "type",
                    a.type(),
                    "category",
                    a.category(),
                    "title",
                    a.title(),
                    "subtitle",
                    a.subtitle(),
                    "articleId",
                    a.articleId(),
                    "at",
                    time(Instant.now()),
                    "read",
                    false)));
    return id;
  }

  public List<Map<String, Object>> trending() {
    var readers = new HashMap<String, Set<String>>();
    for (var d :
        store.query(
            store
                .collection("readerEvents")
                .whereGreaterThanOrEqualTo(
                    "day", LocalDate.now(ContentService.ZONE).minusDays(6).toString())))
      readers
          .computeIfAbsent(d.getString("articleId"), id -> new HashSet<>())
          .add(d.getString("userId"));
    // Os mais lidos vêm primeiro; sem atividade, usa as últimas matérias confirmadas.
    var candidates = new LinkedHashSet<String>();
    readers.entrySet().stream()
        .sorted(
            Comparator.<Map.Entry<String, Set<String>>>comparingInt(e -> e.getValue().size())
                .reversed()
                .thenComparing(Map.Entry.comparingByKey()))
        .limit(20)
        .forEach(e -> candidates.add(e.getKey()));
    store
        .query(
            store
                .collection("articles")
                .whereEqualTo("confirmed", true)
                .whereLessThanOrEqualTo("publishedAt", time(Instant.now()))
                .orderBy("publishedAt", Query.Direction.DESCENDING)
                .limit(3))
        .forEach(d -> candidates.add(d.getId()));
    var result = new ArrayList<Map<String, Object>>();
    for (String id : candidates) {
      var a = store.get(store.doc("articles", id));
      if (a.exists()
          && Boolean.TRUE.equals(a.getBoolean("confirmed"))
          && !instant(a.getInstant("publishedAt")).isAfter(Instant.now()))
        result.add(
            Map.of(
                "articleId",
                id,
                "title",
                a.getString("title"),
                "readers",
                readers.getOrDefault(id, Set.of()).size()));
      if (result.size() == 3) break;
    }
    return result;
  }

  /** Cópia retomável; origem continua intacta até todos os lotes terem sido importados. */
  public void mergeAnonymous(String source, String target) {
    if (source == null || source.equals(target)) return;
    var original = identities.user(source);
    if (original.getString("email") != null) return;
    var dest = identities.user(target);
    for (var doc : store.query(collection(source, "saved"))) {
      store.transaction(
          tx -> {
            var ref = collection(target, "saved").document(doc.getId());
            var current = await(tx.get(ref));
            var data = new HashMap<>(doc.getData());
            if (current.exists()) {
              data.put(
                  "progress", Math.max(doc.getDouble("progress"), current.getDouble("progress")));
              data.put(
                  "archived",
                  Boolean.TRUE.equals(doc.getBoolean("archived"))
                      || Boolean.TRUE.equals(current.getBoolean("archived")));
              data.put("savedAt", current.getInstant("savedAt"));
            }
            tx.set(ref, data);
            return null;
          });
    }
    if (dest.getString("prefs") == null && original.getString("prefs") != null)
      await(
          identities
              .userRef(target)
              .update(
                  map(
                      "prefs",
                      original.getString("prefs"),
                      "following",
                      original.get("following"))));
    for (var doc : store.query(collection(source, "alerts")))
      await(
          collection(target, "alerts")
              .document(doc.getId())
              .set(doc.getData(), SetOptions.merge()));
  }

  public void removePush(String user, String token) {
    store.transaction(
        tx -> {
          var ref = store.doc("pushTokens", hash(token));
          var doc = await(tx.get(ref));
          if (doc.exists() && user.equals(doc.getString("userId"))) tx.delete(ref);
          return null;
        });
  }
}
