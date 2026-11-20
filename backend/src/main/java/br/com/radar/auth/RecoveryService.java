package br.com.radar.auth;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.*;
import br.com.radar.common.PostgresStore.FieldValue;
import br.com.radar.delivery.DeliveryQueue;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class RecoveryService {
  private final PostgresStore store;
  private final IdentityRepository users;
  private final PasswordEncoder passwords;
  private final DeliveryQueue queue;
  private final String baseUrl;

  public RecoveryService(
      PostgresStore store,
      IdentityRepository users,
      PasswordEncoder passwords,
      DeliveryQueue queue,
      @Value("${radar.mail.reset-url}") String baseUrl) {
    this.store = store;
    this.users = users;
    this.passwords = passwords;
    this.queue = queue;
    this.baseUrl = baseUrl;
  }

  public void request(String email) {
    var u = users.byEmail(AuthService.normalize(email));
    if (u == null) return;
    String token = AuthService.randomToken();
    var ref = store.doc("passwordResets", hash(token));
    store.transaction(
        tx -> {
          var user = await(tx.get(users.userRef(u.getId())));
          if (!user.exists()) return null;
          var last = user.getInstant("resetRequestedAt");
          if (last != null && instant(last).isAfter(Instant.now().minusSeconds(60))) return null;
          tx.update(user.getReference(), "resetRequestedAt", time(Instant.now()));
          tx.create(
              ref,
              map(
                  "userId",
                  u.getId(),
                  "expiresAt",
                  time(Instant.now().plusSeconds(1800)),
                  "authVersion",
                  IdentityRepository.version(user)));
          String link =
              baseUrl
                  + (baseUrl.contains("?") ? "&" : "?")
                  + "token="
                  + URLEncoder.encode(token, StandardCharsets.UTF_8);
          queue.email(
              tx,
              "reset-" + ref.getId(),
              u.getString("email"),
              "Redefina sua senha do news.dev",
              "Use o link para criar uma nova senha. Ele expira em 30 minutos.\n\n"
                  + link
                  + "\n\nSe você não solicitou, ignore este email.");
          return null;
        });
  }

  public void reset(String token, String password) {
    AuthService.validatePassword(password);
    String encoded = passwords.encode(password);
    store.transaction(
        tx -> {
          var ref = store.doc("passwordResets", hash(token));
          var reset = await(tx.get(ref));
          if (!reset.exists() || !instant(reset.getInstant("expiresAt")).isAfter(Instant.now()))
            throw ApiException.invalid("Esse link expirou. Solicite outro email de recuperação.");
          var userRef = users.userRef(reset.getString("userId"));
          var user = await(tx.get(userRef));
          if (!user.exists()
              || IdentityRepository.version(user) != IdentityRepository.version(reset))
            throw ApiException.invalid("Esse link já foi utilizado. Solicite outro email.");
          tx.update(userRef, map("passwordHash", encoded, "authVersion", FieldValue.increment(1)));
          tx.delete(ref);
          return null;
        });
  }
}
