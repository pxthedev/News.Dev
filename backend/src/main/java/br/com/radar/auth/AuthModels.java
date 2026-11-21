package br.com.radar.auth;

import jakarta.validation.constraints.*;

public final class AuthModels {
  public record Anonymous(@NotBlank @Pattern(regexp = "ios|android|other") String platform) {}

  public record Register(
      @NotBlank @Email @Size(max = 254) String email,
      @NotBlank @Size(min = 8, max = 72) String password,
      @NotBlank @Size(max = 80) String name) {}

  public record Login(
      @NotBlank @Email @Size(max = 254) String email, @NotBlank @Size(max = 72) String password) {}

  public record Refresh(@NotBlank @Size(max = 256) String refreshToken) {}

  public record Tokens(String token, String refreshToken, long expiresIn) {}

  public record EmailRequest(
      @NotBlank @jakarta.validation.constraints.Email @Size(max = 254) String email) {}

  public record Reset(
      @NotBlank @Size(max = 256) String token,
      @NotBlank @Size(min = 8, max = 72) String password) {}

  public record Social(@NotBlank @Size(max = 10000) String accessToken) {}
}
