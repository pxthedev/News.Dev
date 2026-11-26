package br.com.radar.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Cliente mínimo do Gemini com saída JSON estruturada, compartilhado por tradução e resumo. */
@Component
public class GeminiClient {
  private static final Logger LOG = LoggerFactory.getLogger(GeminiClient.class);

  /** Falha ao gerar conteúdo; quem chama decide se propaga ou usa um fallback. */
  public static class Failure extends RuntimeException {
    Failure(String message) {
      super(message, null, false, false);
    }
  }

  private final HttpClient client =
      HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
  private final ObjectMapper json;
  private final String apiKey;
  private final URI endpoint;

  public GeminiClient(
      ObjectMapper json,
      @Value("${radar.translation.gemini-key}") String apiKey,
      @Value("${radar.translation.gemini-model}") String model) {
    this.json = json;
    this.apiKey = apiKey.strip();
    if (!model.matches("gemini-[a-z0-9.-]+")) {
      throw new IllegalArgumentException("GEMINI_TRANSLATION_MODEL inválido.");
    }
    this.endpoint =
        URI.create(
            "https://generativelanguage.googleapis.com/v1beta/models/"
                + model
                + ":generateContent");
  }

  public boolean configured() {
    return !apiKey.isBlank();
  }

  public JsonNode generate(String instructions, Object input, Map<String, Object> schema) {
    if (!configured()) throw new Failure("not_configured");
    try {
      var requestBody =
          Map.of(
              "systemInstruction", parts(instructions),
              "contents", List.of(parts(json.writeValueAsString(input))),
              "generationConfig",
                  Map.of(
                      "responseMimeType",
                      "application/json",
                      "responseJsonSchema",
                      schema,
                      "thinkingConfig",
                      Map.of("thinkingLevel", "MINIMAL")));
      var request =
          HttpRequest.newBuilder(endpoint)
              .timeout(Duration.ofSeconds(20))
              .header("Content-Type", "application/json")
              .header("x-goog-api-key", apiKey)
              .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(requestBody)))
              .build();
      var response = client.send(request, HttpResponse.BodyHandlers.ofString());
      if (response.statusCode() != 200) {
        LOG.warn("Gemini returned HTTP {}", response.statusCode());
        throw new Failure("http_" + response.statusCode());
      }
      var candidate = json.readTree(response.body()).path("candidates").path(0);
      if (!"STOP".equals(candidate.path("finishReason").asText()))
        throw new Failure("finish_" + candidate.path("finishReason").asText());
      var output = new StringBuilder();
      for (var part : candidate.path("content").path("parts")) {
        if (!part.path("thought").asBoolean()) output.append(part.path("text").asText());
      }
      var parsed = json.readTree(output.toString());
      if (parsed == null || !parsed.isObject()) throw new Failure("invalid_json");
      return parsed;
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new Failure("interrupted");
    } catch (java.io.IOException e) {
      throw new Failure("io");
    }
  }

  private static Map<String, Object> parts(String text) {
    return Map.of("parts", List.of(Map.of("text", text)));
  }
}
