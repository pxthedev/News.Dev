package br.com.radar.content;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.List;

public final class ContentModels {
  public static final String CATEGORY =
      "ia|seguranca|bigtech|programacao|chips|startups|gadgets|games|regulacao|cripto|tech-br|espaco";

  public record Source(
      @NotBlank @Size(max = 100) String name,
      @NotBlank @Pattern(regexp = "https?://[^\\s]+") String url,
      @Size(max = 2048) String logoUrl,
      @Pattern(regexp = "#[0-9a-fA-F]{6}") String color) {}

  public record Entity(
      @NotBlank @Pattern(regexp = "company|person") String type,
      @NotBlank @Pattern(regexp = "[a-z0-9-]{1,100}") String id,
      @NotBlank @Size(max = 100) String name) {}

  public record Article(
      @NotBlank @Pattern(regexp = "[a-z0-9-]{1,100}") String id,
      @NotBlank @Size(max = 240) String title,
      @NotNull @Size(min = 3, max = 3) List<@NotBlank @Size(max = 1000) String> summary,
      @NotBlank @Size(max = 100000) String body,
      @NotBlank @Pattern(regexp = CATEGORY) String category,
      @Size(max = 100) String kicker,
      @Size(max = 2048) String imageUrl,
      @NotNull Instant detectedAt,
      @NotNull Instant publishedAt,
      @NotNull @Size(min = 1, max = 30) List<@NotNull @Valid Source> sources,
      @Min(1) int sourceCount,
      boolean firstInBrazil,
      @Min(0) Integer leadMinutes,
      @NotBlank @Pattern(regexp = "normal|important|urgent") String urgency,
      boolean confirmed,
      @Min(1) @Max(120) int readingMinutes,
      @Size(max = 2048) String audioUrl,
      @Min(1) Integer audioMinutes,
      @NotNull @Size(max = 50) List<@NotNull @Valid Entity> entities,
      @Size(max = 80) String trendingTag) {
    public Article {
      if (publishedAt != null)
        publishedAt = publishedAt.truncatedTo(java.time.temporal.ChronoUnit.MICROS);
      if (detectedAt != null)
        detectedAt = detectedAt.truncatedTo(java.time.temporal.ChronoUnit.MICROS);
    }
  }

  public record LiveUpdate(@NotNull Instant at, @NotBlank @Size(max = 2000) String text) {}

  public record LiveEvent(
      @NotBlank @Pattern(regexp = "[a-z0-9-]{1,100}") String id,
      @NotBlank @Size(max = 240) String title,
      @NotBlank @Size(max = 500) String headline,
      @NotNull Instant startsAt,
      @NotNull Instant endsAt,
      @NotNull @Size(max = 500) List<@NotNull @Valid LiveUpdate> updates) {}

  public record Page<T>(List<T> items, String nextCursor) {}
}
