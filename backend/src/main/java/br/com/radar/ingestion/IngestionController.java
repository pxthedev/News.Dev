package br.com.radar.ingestion;

import static br.com.radar.common.PostgresStore.*;

import br.com.radar.common.PostgresStore;
import jakarta.validation.constraints.Pattern;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/admin/sources")
public class IngestionController {
  private final IngestionService service;
  private final PostgresStore store;

  public IngestionController(IngestionService service, PostgresStore store) {
    this.service = service;
    this.store = store;
  }

  @PutMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void save(
      @PathVariable @Pattern(regexp = "[a-z0-9-]{1,80}") String id,
      @RequestBody IngestionService.SourceConfig source) {
    service.save(
        new IngestionService.SourceConfig(
            id, source.name(), source.url(), source.category(), source.allowFullText()));
  }

  @GetMapping
  Map<String, Object> list() {
    return Map.of(
        "items",
        store.query(store.collection("sources")).stream()
            .map(
                d ->
                    map(
                        "id",
                        d.getId(),
                        "name",
                        d.getString("name"),
                        "url",
                        d.getString("url"),
                        "category",
                        d.getString("category"),
                        "enabled",
                        d.getBoolean("enabled")))
            .toList());
  }

  @PostMapping("/{id}/collect")
  Map<String, Integer> collect(@PathVariable String id) {
    return service.run(id);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(@PathVariable String id) {
    await(store.doc("sources", id).delete());
  }
}
