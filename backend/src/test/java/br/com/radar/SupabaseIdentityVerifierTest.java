package br.com.radar;

import static org.assertj.core.api.Assertions.*;

import br.com.radar.auth.SupabaseIdentityVerifier;
import br.com.radar.common.ApiException;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.*;

class SupabaseIdentityVerifierTest {
  HttpServer server;
  String response;
  int status;
  SupabaseIdentityVerifier verifier;

  @BeforeEach
  void setup() throws Exception {
    response =
        "{\"id\":\"user-1\",\"email\":\"ana@example.com\",\"email_confirmed_at\":\"2026-11-17T00:00:00Z\",\"app_metadata\":{\"providers\":[\"google\"]},\"user_metadata\":{\"full_name\":\"Ana\"}}";
    status = 200;
    server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    server.createContext(
        "/auth/v1/user",
        exchange -> {
          if (!"Bearer verified-access"
                  .equals(exchange.getRequestHeaders().getFirst("Authorization"))
              || !"public-test-key".equals(exchange.getRequestHeaders().getFirst("apikey"))) {
            exchange.sendResponseHeaders(401, -1);
            exchange.close();
            return;
          }
          byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
          exchange.getResponseHeaders().set("Content-Type", "application/json");
          exchange.sendResponseHeaders(status, bytes.length);
          try (var output = exchange.getResponseBody()) {
            output.write(bytes);
          }
        });
    server.start();
    verifier =
        new SupabaseIdentityVerifier(
            "http://127.0.0.1:" + server.getAddress().getPort(), "public-test-key");
  }

  @AfterEach
  void stop() {
    server.stop(0);
  }

  @Test
  void validatesAgainstSupabaseAndUsesProviderNamespace() {
    var identity = verifier.verify("verified-access");
    assertThat(identity.uid()).isEqualTo("supabase:user-1");
    assertThat(identity.email()).isEqualTo("ana@example.com");
  }

  @Test
  void rejectsInvalidAccess() {
    assertThatThrownBy(() -> verifier.verify("forged-token"))
        .isInstanceOfSatisfying(
            ApiException.class, e -> assertThat(e.status.value()).isEqualTo(401));
  }

  @Test
  void rejectsUnconfirmedEmail() {
    response = response.replace("\"email_confirmed_at\":\"2026-11-17T00:00:00Z\",", "");
    assertThatThrownBy(() -> verifier.verify("verified-access")).isInstanceOf(ApiException.class);
  }

  @Test
  void rejectsNonSocialIdentity() {
    response = response.replace("[\"google\"]", "[\"email\"]");
    assertThatThrownBy(() -> verifier.verify("verified-access")).isInstanceOf(ApiException.class);
  }

  @Test
  void providerFailureDoesNotAcceptTokenOrExposeResponse() {
    status = 500;
    response = "{\"error\":\"internal error\"}";
    assertThatThrownBy(() -> verifier.verify("verified-access"))
        .isInstanceOfSatisfying(
            ApiException.class, e -> assertThat(e.status.value()).isEqualTo(503));
  }
}
