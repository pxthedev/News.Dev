package br.com.radar.config;

import br.com.radar.auth.*;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class AdminBootstrap implements ApplicationRunner {
  private final IdentityRepository identities;
  private final PasswordEncoder encoder;
  private final String email, password;

  public AdminBootstrap(
      IdentityRepository identities,
      PasswordEncoder encoder,
      @Value("${radar.bootstrap.admin-email}") String email,
      @Value("${radar.bootstrap.admin-password}") String password) {
    this.identities = identities;
    this.encoder = encoder;
    this.email = email;
    this.password = password;
  }

  public void run(ApplicationArguments args) {
    if (email.isBlank() && password.isBlank()) return;
    if (!email.contains("@")
        || password.length() < 16
        || password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72)
      throw new IllegalStateException("Configure ADMIN_EMAIL e ADMIN_PASSWORD (16 a 72 bytes)");
    var existing = identities.byEmail(AuthService.normalize(email));
    if (existing != null) {
      if (!"ADMIN".equals(existing.getString("role")))
        throw new IllegalStateException("Email de editor já pertence a conta comum");
      return;
    }
    identities.create(
        UUID.randomUUID().toString(),
        AuthService.normalize(email),
        encoder.encode(password),
        "Editor news.dev",
        "ADMIN",
        "other");
  }
}
