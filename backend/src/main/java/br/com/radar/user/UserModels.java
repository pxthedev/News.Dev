package br.com.radar.user;

import br.com.radar.content.ContentModels;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.List;

public final class UserModels {
  public record QuietHours(
      @NotNull @Pattern(regexp = "([01][0-9]|2[0-3]):[0-5][0-9]") String from,
      @NotNull @Pattern(regexp = "([01][0-9]|2[0-3]):[0-5][0-9]") String to) {}

  public record Prefs(
      @NotNull @Size(max = ContentModels.CATEGORY_COUNT)
          List<@NotNull @Pattern(regexp = ContentModels.CATEGORY) String> topics,
      @NotNull @Pattern(regexp = "urgent|balanced|realtime") String alertLevel,
      @NotNull @Size(max = 10)
          List<@NotNull @Pattern(regexp = "([01][0-9]|2[0-3]):[0-5][0-9]") String> digestTimes,
      @Valid QuietHours quietHours,
      boolean showRumors,
      boolean urgentAlerts,
      @NotNull @Size(max = 200)
          List<@NotNull @Pattern(regexp = "[a-z0-9-]{1,100}") String> followedEntities) {}

  public record SavedPatch(
      @DecimalMin("0.0") @DecimalMax("1.0") Double progress, Boolean archived) {}

  public record ReadAlerts(@NotNull @Size(max = 100) List<@NotBlank @Size(max = 36) String> ids) {}

  public record PushToken(
      @NotBlank @Size(max = 2048) String token,
      @NotNull @Pattern(regexp = "ios|android|other") String platform,
      @Pattern(regexp = "token|fid") String kind) {}

  public record AlertRequest(
      @NotBlank @Size(max = 36) String userId,
      @Size(max = 100) String articleId,
      @NotNull @Pattern(regexp = "urgent|scoop|digest|article") String type,
      @Pattern(regexp = ContentModels.CATEGORY) String category,
      @NotBlank @Size(max = 240) String title,
      @NotBlank @Size(max = 300) String subtitle) {}

  public record RemovePush(@NotBlank @Size(max = 2048) String token) {}
}
