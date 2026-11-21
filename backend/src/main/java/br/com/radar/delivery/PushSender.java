package br.com.radar.delivery;

import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** Provider adapter, e.g. a Supabase Edge Function connected to APNs/Web Push. */
@Component
public class PushSender {
  private final String url, secret;
  private final RestClient client;

  public PushSender(
      @Value("${radar.push.webhook-url}") String url,
      @Value("${radar.push.webhook-secret}") String secret) {
    this.url = url;
    this.secret = secret;
    if (!url.isBlank() && (!"https".equals(URI.create(url).getScheme()) || secret.isBlank()))
      throw new IllegalArgumentException("Push exige webhook HTTPS e PUSH_WEBHOOK_SECRET.");
    var factory =
        new JdkClientHttpRequestFactory(
            HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
    factory.setReadTimeout(Duration.ofSeconds(10));
    client = RestClient.builder().requestFactory(factory).build();
  }

  public boolean available() {
    return !url.isBlank() && !secret.isBlank();
  }

  public void send(String id, Map<String, Object> job, List<Map<String, Object>> devices) {
    if (!available()) throw new IllegalStateException("Push não configurado");
    client
        .post()
        .uri(url)
        .headers(h -> h.setBearerAuth(secret))
        .header("Idempotency-Key", id)
        .body(
            Map.of(
                "notificationId",
                id,
                "userId",
                job.get("userId"),
                "title",
                job.get("title"),
                "body",
                job.get("body"),
                "deepLink",
                job.get("deepLink"),
                "devices",
                devices))
        .retrieve()
        .toBodilessEntity();
  }
}
