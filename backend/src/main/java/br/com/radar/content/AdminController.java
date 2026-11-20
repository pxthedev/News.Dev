package br.com.radar.content;

import static br.com.radar.content.ContentModels.*;

import br.com.radar.common.ApiException;
import br.com.radar.user.UserModels.AlertRequest;
import br.com.radar.user.UserRepository;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {
  private final ContentRepository repo;
  private final UserRepository users;

  public AdminController(ContentRepository repo, UserRepository users) {
    this.repo = repo;
    this.users = users;
  }

  @PutMapping("/articles/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void save(@PathVariable String id, @Valid @RequestBody Article a) {
    if (!id.equals(a.id()))
      throw ApiException.invalid("O identificador da matéria deve coincidir com a rota.");
    repo.save(a);
  }

  @DeleteMapping("/articles/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(@PathVariable String id) {
    repo.delete(id);
  }

  @PutMapping("/live/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void live(@PathVariable String id, @Valid @RequestBody LiveEvent e) {
    if (!id.equals(e.id()))
      throw ApiException.invalid("O identificador do evento deve coincidir com a rota.");
    repo.saveLive(e);
  }

  @DeleteMapping("/live/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void deleteLive(@PathVariable String id) {
    repo.deleteLive(id);
  }

  @PostMapping("/alerts")
  @ResponseStatus(HttpStatus.CREATED)
  Map<String, String> alert(@Valid @RequestBody AlertRequest a) {
    return Map.of("id", users.createAlert(a));
  }
}
