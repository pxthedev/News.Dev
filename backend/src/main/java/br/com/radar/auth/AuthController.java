package br.com.radar.auth;

import static br.com.radar.auth.AuthModels.*;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/auth")
public class AuthController {
  private final AuthService service;
  private final RecoveryService recovery;
  private final SocialAuthService social;
  private final br.com.radar.user.UserRepository users;

  public AuthController(
      AuthService service,
      RecoveryService recovery,
      SocialAuthService social,
      br.com.radar.user.UserRepository users) {
    this.recovery = recovery;
    this.social = social;
    this.users = users;
    this.service = service;
  }

  @PostMapping("/anonymous")
  Tokens anonymous(@Valid @RequestBody Anonymous r) {
    return service.anonymous(r.platform());
  }

  @PostMapping("/register")
  @ResponseStatus(HttpStatus.CREATED)
  Tokens register(@Valid @RequestBody Register r) {
    return service.register(r);
  }

  @PostMapping("/login")
  Tokens login(@Valid @RequestBody Login r, @AuthenticationPrincipal Jwt jwt) {
    var tokens = service.login(r);
    if (jwt != null) {
      String target = service.userIdForEmail(r.email());
      users.mergeAnonymous(jwt.getSubject(), target);
    }
    return tokens;
  }

  @PostMapping("/refresh")
  Tokens refresh(@Valid @RequestBody Refresh r) {
    return service.refresh(r.refreshToken());
  }

  @PostMapping("/logout")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void logout(@AuthenticationPrincipal Jwt jwt) {
    service.logout(jwt.getClaimAsString("sid"));
  }

  @PostMapping("/upgrade")
  @ResponseStatus(HttpStatus.CREATED)
  Tokens upgrade(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody Register r) {
    return service.upgrade(jwt.getSubject(), r);
  }

  @PostMapping("/supabase")
  Tokens supabase(@Valid @RequestBody Social r, @AuthenticationPrincipal Jwt jwt) {
    return social.login(r.accessToken(), jwt == null ? null : jwt.getSubject());
  }

  @PostMapping("/forgot-password")
  @ResponseStatus(HttpStatus.ACCEPTED)
  void forgot(@Valid @RequestBody EmailRequest r) {
    recovery.request(r.email());
  }

  @PostMapping("/reset-password")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void reset(@Valid @RequestBody Reset r) {
    recovery.reset(r.token(), r.password());
  }

  @PostMapping("/link/supabase")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void link(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody Social r) {
    social.link(jwt.getSubject(), r.accessToken());
  }
}
