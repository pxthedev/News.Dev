package br.com.radar.auth;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.*;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Repository;

@Repository
public class IdentityRepository {
  private final PostgresStore store;

  public IdentityRepository(PostgresStore store) {
    this.store = store;
  }

  public DocumentReference userRef(String id) {
    return store.doc("users", id);
  }

  public DocumentSnapshot user(String id) {
    var u = store.get(userRef(id));
    if (!u.exists() || Boolean.TRUE.equals(u.getBoolean("deleted")))
      throw ApiException.unauthorized();
    return u;
  }

  public DocumentSnapshot byEmail(String email) {
    var index = store.get(store.doc("emails", hash(email)));
    return index.exists() ? store.get(userRef(index.getString("userId"))) : null;
  }

  public void create(
      String id, String email, String password, String name, String role, String platform) {
    store.transaction(
        tx -> {
          var index = email == null ? null : store.doc("emails", hash(email));
          if (index != null && await(tx.get(index)).exists())
            throw new ApiException(
                org.springframework.http.HttpStatus.CONFLICT,
                "email_in_use",
                "Esse email já possui uma conta.");
          tx.create(
              userRef(id),
              map(
                  "id",
                  id,
                  "email",
                  email,
                  "passwordHash",
                  password,
                  "name",
                  name,
                  "role",
                  role,
                  "platform",
                  platform,
                  "createdAt",
                  Instant.now().toString(),
                  "following",
                  List.of(),
                  "authVersion",
                  0));
          if (index != null) tx.create(index, Map.of("userId", id));
          return null;
        });
  }

  public void upgrade(String id, String email, String password, String name) {
    store.transaction(
        tx -> {
          var u = await(tx.get(userRef(id)));
          var index = store.doc("emails", hash(email));
          var emailDoc = await(tx.get(index));
          if (!u.exists() || u.getString("email") != null)
            throw ApiException.invalid("Essa conta já foi cadastrada.");
          if (emailDoc.exists())
            throw new ApiException(
                org.springframework.http.HttpStatus.CONFLICT,
                "email_in_use",
                "Esse email já possui uma conta.");
          tx.update(userRef(id), map("email", email, "passwordHash", password, "name", name));
          tx.create(index, Map.of("userId", id));
          return null;
        });
  }

  public void session(String id, String user, String hash, Instant expiry) {
    store.transaction(
        tx -> {
          var u = await(tx.get(userRef(user)));
          require(u);
          tx.create(
              store.doc("sessions", id),
              map(
                  "userId",
                  user,
                  "refreshHash",
                  hash,
                  "expiresAt",
                  time(expiry),
                  "revoked",
                  false,
                  "authVersion",
                  version(u)));
          tx.create(store.doc("refreshTokens", hash), Map.of("sessionId", id));
          return null;
        });
  }

  public boolean active(String sid, String user) {
    var s = store.get(store.doc("sessions", sid));
    var u = store.get(userRef(user));
    return s.exists()
        && u.exists()
        && user.equals(s.getString("userId"))
        && !Boolean.TRUE.equals(s.getBoolean("revoked"))
        && s.getInstant("expiresAt") != null
        && instant(s.getInstant("expiresAt")).isAfter(Instant.now())
        && version(u) == version(s);
  }

  public static long version(DocumentSnapshot doc) {
    Long v = doc.getLong("authVersion");
    return v == null ? 0 : v;
  }

  public void revoke(String id) {
    await(store.doc("sessions", id).update("revoked", true));
  }

  public DocumentSnapshot consumeRefresh(
      String token, String nextId, String nextHash, Instant expiry) {
    return store.transaction(
        tx -> {
          var index = await(tx.get(store.doc("refreshTokens", hash(token))));
          if (!index.exists()) throw ApiException.unauthorized();
          var ref = store.doc("sessions", index.getString("sessionId"));
          var session = await(tx.get(ref));
          if (!session.exists()
              || Boolean.TRUE.equals(session.getBoolean("revoked"))
              || !instant(session.getInstant("expiresAt")).isAfter(Instant.now()))
            throw ApiException.unauthorized();
          var user = await(tx.get(userRef(session.getString("userId"))));
          if (!user.exists() || version(user) != version(session))
            throw ApiException.unauthorized();
          tx.update(ref, "revoked", true);
          tx.create(
              store.doc("sessions", nextId),
              map(
                  "userId",
                  user.getId(),
                  "refreshHash",
                  nextHash,
                  "expiresAt",
                  time(expiry),
                  "revoked",
                  false,
                  "authVersion",
                  version(user)));
          tx.create(store.doc("refreshTokens", nextHash), Map.of("sessionId", nextId));
          return user;
        });
  }

  public void revokeAll(String user) {
    for (var session : store.query(store.collection("sessions").whereEqualTo("userId", user)))
      await(session.getReference().update("revoked", true));
  }

  public String social(String uid, String email, String name, String anonymous) {
    return store.transaction(
        tx -> {
          var provider = store.doc("socialIdentities", hash(uid));
          var linked = await(tx.get(provider));
          if (linked.exists()) {
            var u = await(tx.get(userRef(linked.getString("userId"))));
            require(u);
            return u.getId();
          }
          var emailRef = store.doc("emails", hash(email));
          var existing = await(tx.get(emailRef));
          var anon = anonymous == null ? null : await(tx.get(userRef(anonymous)));
          if (existing.exists())
            throw new ApiException(
                org.springframework.http.HttpStatus.CONFLICT,
                "account_link_required",
                "Entre com sua senha antes de vincular o login social.");
          String id =
              anon != null && anon.exists() && anon.getString("email") == null
                  ? anonymous
                  : UUID.randomUUID().toString();
          var data =
              map(
                  "id",
                  id,
                  "email",
                  email,
                  "passwordHash",
                  null,
                  "name",
                  name,
                  "role",
                  "USER",
                  "platform",
                  "other",
                  "createdAt",
                  Instant.now().toString(),
                  "following",
                  List.of(),
                  "authVersion",
                  0);
          if (id.equals(anonymous)) tx.update(userRef(id), map("email", email, "name", name));
          else tx.create(userRef(id), data);
          tx.create(provider, Map.of("userId", id));
          tx.create(emailRef, Map.of("userId", id));
          return id;
        });
  }

  public void linkSocial(String user, String uid, String email) {
    store.transaction(
        tx -> {
          var u = await(tx.get(userRef(user)));
          var ref = store.doc("socialIdentities", hash(uid));
          var linked = await(tx.get(ref));
          if (!u.exists() || u.getString("email") == null || !email.equals(u.getString("email")))
            throw ApiException.invalid("Use o mesmo email da sua conta para vincular esse acesso.");
          if (linked.exists() && !user.equals(linked.getString("userId")))
            throw new ApiException(
                org.springframework.http.HttpStatus.CONFLICT,
                "provider_in_use",
                "Esse acesso já está vinculado a outra conta.");
          tx.set(ref, Map.of("userId", user));
          return null;
        });
  }
}
