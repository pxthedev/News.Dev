package br.com.radar.auth;

import br.com.radar.common.ApiException;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.*;

/** Validates the access token remotely with Supabase Auth, never by trusting decoded JWT claims. */
@Component
public class SupabaseIdentityVerifier {
  public record Identity(String uid, String email, String name) {}

  private final RestClient client;
  private final boolean configured;

  public SupabaseIdentityVerifier(
      @Value("${radar.supabase.url}") String url,
      @Value("${radar.supabase.publishable-key}") String key) {
    configured = !url.isBlank() && !key.isBlank();
    if (configured) {
      URI uri = URI.create(url);
      if (!"https".equals(uri.getScheme())
          && !("http".equals(uri.getScheme())
              && List.of("localhost", "127.0.0.1").contains(uri.getHost())))
        throw new IllegalArgumentException(
            "SUPABASE_URL deve usar HTTPS (ou localhost para testes).");
    }
    var factory =
        new JdkClientHttpRequestFactory(
            HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
    factory.setReadTimeout(Duration.ofSeconds(10));
    client =
        RestClient.builder()
            .baseUrl(url.isBlank() ? "http://localhost" : url.replaceAll("/+$", ""))
            .defaultHeader("apikey", key)
            .requestFactory(factory)
            .build();
  }

  public Identity verify(String token) {
    if (!configured)
      throw new ApiException(
          HttpStatus.SERVICE_UNAVAILABLE,
          "social_unavailable",
          "Login Google indisponível. Use email e senha.");
    if (token == null || token.isBlank() || token.length() > 10000)
      throw ApiException.unauthorized();
    try {
      var user =
          client
              .get()
              .uri("/auth/v1/user")
              .headers(h -> h.setBearerAuth(token))
              .retrieve()
              .body(Map.class);
      if (user == null
          || !(user.get("id") instanceof String id)
          || !(user.get("email") instanceof String email)
          || user.get("email_confirmed_at") == null
          || email.isBlank()) throw ApiException.unauthorized();
      Object metadata = user.get("app_metadata");
      var app = metadata instanceof Map<?, ?> m ? m : Map.of();
      Object providers = app.get("providers");
      boolean social =
          providers instanceof List<?> p && (p.contains("google") || p.contains("apple"));
      if (!social) throw ApiException.unauthorized();
      Object details = user.get("user_metadata");
      var profile = details instanceof Map<?, ?> m ? m : Map.of();
      Object name = profile.get("full_name");
      return new Identity(
          "supabase:" + id,
          AuthService.normalize(email),
          name instanceof String s && !s.isBlank() ? s : "Leitor");
    } catch (HttpClientErrorException e) {
      if (e.getStatusCode().value() == 401 || e.getStatusCode().value() == 403)
        throw ApiException.unauthorized();
      throw new ApiException(
          HttpStatus.SERVICE_UNAVAILABLE,
          "social_unavailable",
          "Não foi possível verificar o login. Tente novamente.");
    } catch (RestClientException e) {
      throw new ApiException(
          HttpStatus.SERVICE_UNAVAILABLE,
          "social_unavailable",
          "Não foi possível verificar o login. Tente novamente.");
    }
  }
}
