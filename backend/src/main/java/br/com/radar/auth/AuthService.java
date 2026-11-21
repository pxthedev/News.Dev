package br.com.radar.auth;

import static br.com.radar.auth.AuthModels.*;
import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.*;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;

@Service
public class AuthService {
  private final IdentityRepository identities;
  private final PasswordEncoder passwords;
  private final JwtEncoder encoder;
  private final String issuer;
  private final long accessSeconds, anonymousSeconds, refreshDays;
  private final String dummy;

  public AuthService(
      IdentityRepository identities,
      PasswordEncoder passwords,
      JwtEncoder encoder,
      @Value("${radar.security.issuer}") String issuer,
      @Value("${radar.security.access-seconds}") long accessSeconds,
      @Value("${radar.security.anonymous-seconds}") long anonymousSeconds,
      @Value("${radar.security.refresh-days}") long refreshDays) {
    this.identities = identities;
    this.passwords = passwords;
    this.encoder = encoder;
    this.issuer = issuer;
    this.accessSeconds = accessSeconds;
    this.anonymousSeconds = anonymousSeconds;
    this.refreshDays = refreshDays;
    dummy = passwords.encode(UUID.randomUUID().toString());
  }

  public Tokens anonymous(String platform) {
    String id = UUID.randomUUID().toString();
    identities.create(id, null, null, "Leitor", "USER", platform);
    return issue(id, "USER", true);
  }

  public Tokens register(Register r) {
    validatePassword(r.password());
    String id = UUID.randomUUID().toString();
    identities.create(
        id, normalize(r.email()), passwords.encode(r.password()), r.name().trim(), "USER", "other");
    return issue(id, "USER", false);
  }

  public Tokens upgrade(String id, Register r) {
    validatePassword(r.password());
    identities.upgrade(id, normalize(r.email()), passwords.encode(r.password()), r.name().trim());
    return issue(id, "USER", false);
  }

  public Tokens login(Login r) {
    if (r.password().getBytes(StandardCharsets.UTF_8).length > 72)
      throw ApiException.unauthorized();
    var u = identities.byEmail(normalize(r.email()));
    String stored = u == null ? null : u.getString("passwordHash");
    if (!passwords.matches(r.password(), stored == null ? dummy : stored)
        || u == null
        || stored == null) throw ApiException.unauthorized();
    return issue(u.getId(), u.getString("role"), false);
  }

  public Tokens refresh(String token) {
    String sid = UUID.randomUUID().toString(), refresh = randomToken();
    Instant now = Instant.now();
    var u =
        identities.consumeRefresh(
            token, sid, hash(refresh), now.plus(Duration.ofDays(refreshDays)));
    return encode(u.getId(), u.getString("role"), u.getString("email") == null, sid, refresh, now);
  }

  public void logout(String sid) {
    identities.revoke(sid);
  }

  public String userIdForEmail(String email) {
    var user = identities.byEmail(normalize(email));
    if (user == null) throw ApiException.unauthorized();
    return user.getId();
  }

  public Tokens issueFor(String user) {
    var u = identities.user(user);
    return issue(user, u.getString("role"), u.getString("email") == null);
  }

  private Tokens issue(String user, String role, boolean anonymous) {
    String sid = UUID.randomUUID().toString(), refresh = randomToken();
    Instant now = Instant.now();
    identities.session(sid, user, hash(refresh), now.plus(Duration.ofDays(refreshDays)));
    return encode(user, role, anonymous, sid, refresh, now);
  }

  private Tokens encode(
      String user, String role, boolean anonymous, String sid, String refresh, Instant now) {
    long seconds = anonymous ? anonymousSeconds : accessSeconds;
    var claims =
        JwtClaimsSet.builder()
            .issuer(issuer)
            .subject(user)
            .issuedAt(now)
            .expiresAt(now.plusSeconds(seconds))
            .claim("sid", sid)
            .claim("roles", List.of(role))
            .build();
    return new Tokens(
        encoder
            .encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
            .getTokenValue(),
        refresh,
        seconds);
  }

  public static String randomToken() {
    byte[] bytes = new byte[48];
    new SecureRandom().nextBytes(bytes);
    return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
  }

  public static String normalize(String email) {
    return email.trim().toLowerCase(Locale.ROOT);
  }

  public static void validatePassword(String password) {
    if (password.length() < 8 || password.getBytes(StandardCharsets.UTF_8).length > 72)
      throw ApiException.invalid("Use uma senha de pelo menos 8 caracteres e até 72 bytes.");
  }
}
