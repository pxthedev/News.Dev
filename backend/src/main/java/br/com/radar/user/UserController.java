package br.com.radar.user;

import static br.com.radar.user.UserModels.*;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1")
public class UserController {
  private final UserRepository users;

  public UserController(UserRepository users) {
    this.users = users;
  }

  @GetMapping("/me")
  Map<String, Object> me(@AuthenticationPrincipal Jwt jwt) {
    return users.profile(jwt.getSubject());
  }

  @PutMapping("/me")
  Map<String, Object> updateProfile(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ProfileUpdate profile) {
    return users.updateProfile(jwt.getSubject(), profile);
  }

  @GetMapping("/me/prefs")
  Prefs prefs(@AuthenticationPrincipal Jwt jwt) {
    return users.prefs(jwt.getSubject());
  }

  @PutMapping("/me/prefs")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void prefs(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody Prefs p) {
    users.savePrefs(jwt.getSubject(), p);
  }

  @GetMapping("/me/stats/weekly")
  Map<String, Object> stats(@AuthenticationPrincipal Jwt jwt) {
    return users.weekly(jwt.getSubject());
  }

  @GetMapping("/me/saved")
  Map<String, Object> saved(@AuthenticationPrincipal Jwt jwt) {
    return Map.of("items", users.saved(jwt.getSubject()));
  }

  @PutMapping("/me/saved/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void save(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable @Pattern(regexp = "[a-z0-9-]{1,100}") String id,
      @Valid @RequestBody SavedPatch p) {
    users.save(jwt.getSubject(), id, p);
  }

  @DeleteMapping("/me/saved/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void unsave(@AuthenticationPrincipal Jwt jwt, @PathVariable String id) {
    users.unsave(jwt.getSubject(), id);
  }

  @PutMapping("/me/following/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void follow(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable @Pattern(regexp = "[a-z0-9-]{1,100}") String id) {
    users.follow(jwt.getSubject(), id, true);
  }

  @DeleteMapping("/me/following/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void unfollow(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable @Pattern(regexp = "[a-z0-9-]{1,100}") String id) {
    users.follow(jwt.getSubject(), id, false);
  }

  @GetMapping("/me/alerts")
  Map<String, Object> alerts(@AuthenticationPrincipal Jwt jwt) {
    return Map.of("items", users.alerts(jwt.getSubject()));
  }

  @PostMapping("/me/alerts/read")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void read(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ReadAlerts r) {
    users.readAlerts(jwt.getSubject(), r.ids());
  }

  @PostMapping("/me/push-tokens")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void push(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PushToken p) {
    users.push(jwt.getSubject(), p);
  }

  @PostMapping("/waitlist/community")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void waitlist(@AuthenticationPrincipal Jwt jwt) {
    users.waitlist(jwt.getSubject());
  }

  @PostMapping("/me/reads/{articleId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void readArticle(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable @Pattern(regexp = "[a-z0-9-]{1,100}") String articleId) {
    users.recordRead(jwt.getSubject(), articleId);
  }

  @DeleteMapping("/me/push-tokens")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void removePush(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RemovePush r) {
    users.removePush(jwt.getSubject(), r.token());
  }
}
