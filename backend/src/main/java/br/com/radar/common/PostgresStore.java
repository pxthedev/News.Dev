package br.com.radar.common;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Function;
import org.springframework.dao.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/** SQL/JSONB persistence. All filtering, ordering, counts and pagination execute in PostgreSQL. */
@Component
public class PostgresStore {
  private final JdbcTemplate jdbc;
  private final JsonStore json;
  private final TransactionTemplate transactions;
  private static final DateTimeFormatter CLOCK =
      new DateTimeFormatterBuilder().appendInstant(9).toFormatter();
  private static final Map<String, String> TABLES =
      Map.ofEntries(
          Map.entry("users", "users"), Map.entry("emails", "emails"),
          Map.entry("sessions", "sessions"), Map.entry("refreshTokens", "refresh_tokens"),
          Map.entry("socialIdentities", "social_identities"),
              Map.entry("passwordResets", "password_resets"),
          Map.entry("articles", "articles"), Map.entry("liveEvents", "live_events"),
          Map.entry("readerEvents", "reader_events"), Map.entry("outbox", "outbox"),
          Map.entry("sources", "sources"), Map.entry("imports", "imports"),
          Map.entry("pushTokens", "push_tokens"), Map.entry("system", "system"),
          Map.entry("users/saved", "user_saved"), Map.entry("users/reads", "user_reads"),
          Map.entry("users/readingDays", "user_reading_days"),
              Map.entry("users/alerts", "user_alerts"));

  public PostgresStore(JdbcTemplate jdbc, JsonStore json, PlatformTransactionManager manager) {
    this.jdbc = jdbc;
    this.json = json;
    transactions = new TransactionTemplate(manager);
    transactions.setIsolationLevel(TransactionDefinition.ISOLATION_SERIALIZABLE);
    transactions.setTimeout(20);
  }

  public CollectionReference collection(String name) {
    return collection(name, "");
  }

  private CollectionReference collection(String name, String owner) {
    String table = TABLES.get(name);
    if (table == null) throw new IllegalArgumentException("Unknown data collection");
    return new CollectionReference(this, table, owner);
  }

  public DocumentReference doc(String collection, String id) {
    return collection(collection).document(id);
  }

  public DocumentSnapshot get(DocumentReference ref) {
    return await(ref.get());
  }

  public List<DocumentSnapshot> query(Query query) {
    return await(query.get()).getDocuments();
  }

  public CompletableFuture<List<DocumentSnapshot>> getAll(DocumentReference... refs) {
    var result = new LinkedHashMap<String, DocumentSnapshot>();
    var groups = new LinkedHashMap<String, List<DocumentReference>>();
    for (var ref : refs)
      groups.computeIfAbsent(ref.table + "/" + ref.owner, x -> new ArrayList<>()).add(ref);
    for (var group : groups.values()) {
      var first = group.getFirst();
      var params = new ArrayList<Object>();
      params.add(first.owner);
      group.forEach(ref -> params.add(ref.id));
      String sql =
          "select id,data::text from fionova."
              + first.table
              + " where owner_id=? and id in ("
              + String.join(",", Collections.nCopies(group.size(), "?"))
              + ")";
      jdbc.query(
          sql,
          (org.springframework.jdbc.core.RowCallbackHandler)
              rs -> {
                var ref = new DocumentReference(this, first.table, first.owner, rs.getString(1));
                result.put(ref.key(), new DocumentSnapshot(ref, read(rs.getString(2))));
              },
          params.toArray());
    }
    return CompletableFuture.completedFuture(
        Arrays.stream(refs)
            .map(r -> result.getOrDefault(r.key(), new DocumentSnapshot(r, null)))
            .toList());
  }

  public <T> T transaction(Function<Transaction, T> work) {
    for (int attempt = 0; ; attempt++) {
      try {
        return transactions.execute(status -> work.apply(new Transaction()));
      } catch (TransientDataAccessException e) {
        if (attempt >= 4)
          throw new ApiException(
              HttpStatus.SERVICE_UNAVAILABLE,
              "storage_busy",
              "O banco está ocupado. Tente novamente.");
      } catch (DuplicateKeyException e) {
        throw new ApiException(
            HttpStatus.CONFLICT,
            "data_conflict",
            "Esse registro já existe. Atualize e tente novamente.");
      }
    }
  }

  public WriteBatch batch() {
    return new WriteBatch();
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> read(String raw) {
    return json.read(raw, Map.class);
  }

  private static Object normalized(Object value) {
    if (value instanceof Instant instant) return CLOCK.format(instant);
    if (value instanceof Map<?, ?> map) {
      var copy = new LinkedHashMap<String, Object>();
      map.forEach((k, v) -> copy.put(k.toString(), normalized(v)));
      return copy;
    }
    if (value instanceof Collection<?> list)
      return list.stream().map(PostgresStore::normalized).toList();
    return value;
  }

  private String encode(Object value) {
    return json.write(normalized(value));
  }

  public static <T> T await(CompletableFuture<T> result) {
    return result.join();
  }

  public static Instant time(Instant instant) {
    return instant;
  }

  public static Instant instant(Instant instant) {
    return instant;
  }

  public static String hash(String value) {
    try {
      return HexFormat.of()
          .formatHex(
              MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException(e);
    }
  }

  public static Map<String, Object> map(Object... pairs) {
    var result = new LinkedHashMap<String, Object>();
    for (int i = 0; i < pairs.length; i += 2) result.put((String) pairs[i], pairs[i + 1]);
    return result;
  }

  public static void require(DocumentSnapshot record) {
    if (!record.exists()) throw ApiException.missing();
  }

  private static String field(String field) {
    if (field.equals("__id__")) return "id";
    if (!field.matches("[A-Za-z][A-Za-z0-9_]*"))
      throw new IllegalArgumentException("Invalid field");
    return "(data->>'" + field + "')";
  }

  private static String expression(String field, Object value) {
    String sql = field(field);

    if (value instanceof Number) return sql + "::numeric";
    return sql;
  }

  private static Object parameter(Object value) {
    return value instanceof Boolean ? value.toString() : normalized(value);
  }

  public static class DocumentSnapshot {
    private final DocumentReference ref;
    private final Map<String, Object> data;

    DocumentSnapshot(DocumentReference ref, Map<String, Object> data) {
      this.ref = ref;
      this.data = data;
    }

    public String getId() {
      return ref.id;
    }

    public DocumentReference getReference() {
      return ref;
    }

    public boolean exists() {
      return data != null;
    }

    public Map<String, Object> getData() {
      return data == null ? null : new LinkedHashMap<>(data);
    }

    public Object get(String field) {
      return data == null ? null : data.get(field);
    }

    public String getString(String field) {
      Object v = get(field);
      return v == null ? null : v.toString();
    }

    public Boolean getBoolean(String field) {
      return (Boolean) get(field);
    }

    public Long getLong(String field) {
      Object v = get(field);
      return v == null ? null : ((Number) v).longValue();
    }

    public Double getDouble(String field) {
      Object v = get(field);
      return v == null ? null : ((Number) v).doubleValue();
    }

    public Instant getInstant(String field) {
      Object v = get(field);
      return v == null ? null : Instant.parse(v.toString());
    }
  }

  public static class DocumentReference {
    private final PostgresStore store;
    private final String table, owner, id;

    DocumentReference(PostgresStore store, String table, String owner, String id) {
      if (id == null || id.isBlank() || id.contains("/") || id.length() > 1500)
        throw ApiException.invalid("O identificador é inválido.");
      this.store = store;
      this.table = table;
      this.owner = owner;
      this.id = id;
    }

    private String key() {
      return table + "/" + owner + "/" + id;
    }

    public String getId() {
      return id;
    }

    public CollectionReference collection(String name) {
      if (!table.equals("users") || !owner.isEmpty())
        throw new IllegalArgumentException("Invalid child collection");
      return store.collection("users/" + name, id);
    }

    public CompletableFuture<DocumentSnapshot> get() {
      var rows =
          store.jdbc.query(
              "select data::text from fionova." + table + " where owner_id=? and id=?",
              (rs, n) -> new DocumentSnapshot(this, store.read(rs.getString(1))),
              owner,
              id);
      return CompletableFuture.completedFuture(
          rows.isEmpty() ? new DocumentSnapshot(this, null) : rows.getFirst());
    }

    public CompletableFuture<Void> create(Map<String, Object> data) {
      store.jdbc.update(
          "insert into fionova." + table + "(owner_id,id,data) values (?,?,?::jsonb)",
          owner,
          id,
          store.encode(data));
      return CompletableFuture.completedFuture(null);
    }

    public CompletableFuture<Void> set(Map<String, Object> data) {
      return set(data, null);
    }

    public CompletableFuture<Void> set(Map<String, Object> data, SetOptions merge) {
      store.jdbc.update(
          "insert into fionova."
              + table
              + " as target(owner_id,id,data) values (?,?,?::jsonb) on conflict(owner_id,id) do update set data="
              + (merge == null ? "excluded.data" : "target.data || excluded.data")
              + ", updated_at=now()",
          owner,
          id,
          store.encode(data));
      return CompletableFuture.completedFuture(null);
    }

    public CompletableFuture<Void> update(String field, Object value) {
      return update(map(field, value));
    }

    public CompletableFuture<Void> update(Map<String, Object> values) {
      String sql = "data";
      var params = new ArrayList<Object>();
      for (var entry : values.entrySet()) {
        String name = entry.getKey();
        field(name);
        if (entry.getValue() instanceof FieldValue change) {
          if (change.delete) sql = "(" + sql + " - '" + name + "')";
          else {
            sql =
                "jsonb_set("
                    + sql
                    + ",'{"
                    + name
                    + "}',to_jsonb(coalesce((data->>'"
                    + name
                    + "')::numeric,0)+?::numeric),true)";
            params.add(change.amount);
          }
        } else {
          sql = "jsonb_set(" + sql + ",'{" + name + "}',?::jsonb,true)";
          params.add(store.encode(entry.getValue()));
        }
      }
      params.add(owner);
      params.add(id);
      if (store.jdbc.update(
              "update fionova."
                  + table
                  + " set data="
                  + sql
                  + ", updated_at=now() where owner_id=? and id=?",
              params.toArray())
          == 0) throw ApiException.missing();
      return CompletableFuture.completedFuture(null);
    }

    public CompletableFuture<Void> delete() {
      store.jdbc.update("delete from fionova." + table + " where owner_id=? and id=?", owner, id);
      return CompletableFuture.completedFuture(null);
    }
  }

  public static class Query {
    public enum Direction {
      ASCENDING,
      DESCENDING
    }

    private record Order(String field, Direction direction) {}

    protected final PostgresStore store;
    protected final String table, owner;
    private final List<String> predicates;
    private final List<Object> params;
    private final List<Order> orders;
    private int limit;
    private List<String> selected;

    Query(PostgresStore store, String table, String owner) {
      this.store = store;
      this.table = table;
      this.owner = owner;
      predicates = new ArrayList<>(List.of("owner_id=?"));
      params = new ArrayList<>(List.of(owner));
      orders = new ArrayList<>();
    }

    Query(Query source) {
      store = source.store;
      table = source.table;
      owner = source.owner;
      predicates = new ArrayList<>(source.predicates);
      params = new ArrayList<>(source.params);
      orders = new ArrayList<>(source.orders);
      limit = source.limit;
      selected = source.selected;
    }

    private Query where(String name, String op, Object value) {
      var copy = new Query(this);
      copy.predicates.add(expression(name, value) + op + "?");
      copy.params.add(parameter(value));
      return copy;
    }

    public Query whereEqualTo(String f, Object v) {
      if (v != null) return where(f, "=", v);
      var q = new Query(this);
      q.predicates.add(field(f) + " is null");
      return q;
    }

    public Query whereGreaterThan(String f, Object v) {
      return where(f, ">", v);
    }

    public Query whereGreaterThanOrEqualTo(String f, Object v) {
      return where(f, ">=", v);
    }

    public Query whereLessThan(String f, Object v) {
      return where(f, "<", v);
    }

    public Query whereLessThanOrEqualTo(String f, Object v) {
      return where(f, "<=", v);
    }

    public Query whereIn(String f, List<?> values) {
      var q = new Query(this);
      if (values.isEmpty()) {
        q.predicates.add("false");
        return q;
      }
      q.predicates.add(
          expression(f, values.getFirst())
              + " in ("
              + String.join(",", Collections.nCopies(values.size(), "?"))
              + ")");
      values.forEach(v -> q.params.add(parameter(v)));
      return q;
    }

    public Query whereArrayContains(String f, Object v) {
      return whereArrayContainsAny(f, List.of(v));
    }

    public Query wherePrimaryArticleSourceMatches(String pattern) {
      var q = new Query(this);
      q.predicates.add("((data->>'payload')::jsonb #>> '{sources,0,url}') ~* ?");
      q.params.add(pattern);
      return q;
    }

    /**
     * Matéria com texto completo ou, se confirmada, ao menos uma sinopse para exibir com o link da
     * fonte. Importação ainda em revisão editorial sem texto continua fora.
     */
    public Query whereArticleHasBodyOrSynopsis() {
      var q = new Query(this);
      q.predicates.add(
          "(((data->>'payload')::jsonb ->> 'body') ~ '[^[:space:]]'"
              + " or (((data->>'payload')::jsonb ->> 'confirmed') = 'true'"
              + " and ((data->>'payload')::jsonb #>> '{summary,0}') ~ '[^[:space:]]'))");
      return q;
    }

    public Query whereArrayContainsAny(String f, List<?> values) {
      field(f);
      var q = new Query(this);
      if (values.isEmpty()) {
        q.predicates.add("false");
        return q;
      }
      q.predicates.add(
          "("
              + String.join(
                  " or ", Collections.nCopies(values.size(), "(data->'" + f + "') @> ?::jsonb"))
              + ")");
      values.forEach(v -> q.params.add(store.encode(List.of(v))));
      return q;
    }

    public Query orderBy(String f) {
      return orderBy(f, Direction.ASCENDING);
    }

    public Query orderBy(String f, Direction d) {
      field(f);
      var q = new Query(this);
      q.orders.add(new Order(f, d));
      return q;
    }

    public Query limit(int value) {
      if (value < 1 || value > 10000) throw new IllegalArgumentException("Invalid limit");
      var q = new Query(this);
      q.limit = value;
      return q;
    }

    public Query select(String... fields) {
      for (String f : fields) field(f);
      var q = new Query(this);
      q.selected = List.of(fields);
      return q;
    }

    public Query startAfter(DocumentSnapshot cursor) {
      return startAfter(
          orders.stream()
              .map(o -> o.field.equals("__id__") ? cursor.getId() : cursor.get(o.field))
              .toArray());
    }

    public Query startAfter(Object... values) {
      if (values.length != orders.size() || values.length == 0)
        throw ApiException.invalid("O cursor é inválido.");
      var q = new Query(this);
      var alternatives = new ArrayList<String>();
      for (int i = 0; i < values.length; i++) {
        var terms = new ArrayList<String>();
        for (int j = 0; j < i; j++) {
          terms.add(expression(orders.get(j).field, values[j]) + "=?");
          q.params.add(parameter(values[j]));
        }
        var order = orders.get(i);
        terms.add(
            expression(order.field, values[i])
                + (order.direction == Direction.DESCENDING ? "<?" : ">?"));
        q.params.add(parameter(values[i]));
        alternatives.add("(" + String.join(" and ", terms) + ")");
      }
      q.predicates.add("(" + String.join(" or ", alternatives) + ")");
      return q;
    }

    private String whereSql() {
      return " from fionova." + table + " where " + String.join(" and ", predicates);
    }

    private String suffix() {
      String sql = "";
      if (!orders.isEmpty())
        sql +=
            " order by "
                + String.join(
                    ",",
                    orders.stream()
                        .map(
                            o ->
                                field(o.field)
                                    + (o.direction == Direction.DESCENDING ? " desc" : " asc"))
                        .toList());
      if (limit > 0) sql += " limit " + limit;
      return sql;
    }

    public CompletableFuture<QueryResult> get() {
      String payload = "data";
      if (selected != null)
        payload =
            selected.isEmpty()
                ? "'{}'::jsonb"
                : "jsonb_build_object("
                    + String.join(
                        ",", selected.stream().map(f -> "'" + f + "',data->'" + f + "'").toList())
                    + ")";
      var rows =
          store.jdbc.query(
              "select id,(" + payload + ")::text" + whereSql() + suffix(),
              (rs, n) ->
                  new DocumentSnapshot(
                      new DocumentReference(store, table, owner, rs.getString(1)),
                      store.read(rs.getString(2))),
              params.toArray());
      return CompletableFuture.completedFuture(new QueryResult(rows));
    }

    public CountQuery count() {
      return new CountQuery(this);
    }
  }

  public static class CollectionReference extends Query {
    CollectionReference(PostgresStore store, String table, String owner) {
      super(store, table, owner);
    }

    public DocumentReference document(String id) {
      return new DocumentReference(store, table, owner, id);
    }

    public DocumentReference document() {
      return document(UUID.randomUUID().toString());
    }
  }

  public record QueryResult(List<DocumentSnapshot> documents) {
    public List<DocumentSnapshot> getDocuments() {
      return documents;
    }
  }

  public record CountResult(long count) {
    public long getCount() {
      return count;
    }
  }

  public record CountQuery(Query query) {
    public CompletableFuture<CountResult> get() {
      return CompletableFuture.completedFuture(
          new CountResult(
              query.store.jdbc.queryForObject(
                  "select count(*)" + query.whereSql(), Long.class, query.params.toArray())));
    }
  }

  public static class FieldPath {
    public static String documentId() {
      return "__id__";
    }
  }

  public static class FieldValue {
    private final boolean delete;
    private final long amount;

    private FieldValue(boolean delete, long amount) {
      this.delete = delete;
      this.amount = amount;
    }

    public static FieldValue delete() {
      return new FieldValue(true, 0);
    }

    public static FieldValue increment(long amount) {
      return new FieldValue(false, amount);
    }
  }

  public static class SetOptions {
    public static SetOptions merge() {
      return new SetOptions();
    }
  }

  public static class Transaction {
    public CompletableFuture<DocumentSnapshot> get(DocumentReference ref) {
      return ref.get();
    }

    public Transaction create(DocumentReference ref, Map<String, Object> data) {
      await(ref.create(data));
      return this;
    }

    public Transaction set(DocumentReference ref, Map<String, Object> data) {
      await(ref.set(data));
      return this;
    }

    public Transaction update(DocumentReference ref, String f, Object v) {
      await(ref.update(f, v));
      return this;
    }

    public Transaction update(DocumentReference ref, Map<String, Object> data) {
      await(ref.update(data));
      return this;
    }

    public Transaction delete(DocumentReference ref) {
      await(ref.delete());
      return this;
    }
  }

  public class WriteBatch {
    private final List<Runnable> work = new ArrayList<>();

    public WriteBatch delete(DocumentReference ref) {
      work.add(() -> await(ref.delete()));
      return this;
    }

    public WriteBatch set(DocumentReference ref, Map<String, Object> data) {
      work.add(() -> await(ref.set(data)));
      return this;
    }

    public CompletableFuture<Void> commit() {
      transaction(
          tx -> {
            work.forEach(Runnable::run);
            return null;
          });
      return CompletableFuture.completedFuture(null);
    }
  }
}
