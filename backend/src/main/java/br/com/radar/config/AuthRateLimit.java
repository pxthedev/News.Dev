package br.com.radar.config;

import br.com.radar.common.Errors;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Limite local por IP. Em múltiplas réplicas, aplicar também no gateway/Redis. */
@Component
public class AuthRateLimit extends OncePerRequestFilter {
  private record Window(long minute, int count) {}

  private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
  private final ObjectMapper mapper;
  private final int requestsPerMinute;

  public AuthRateLimit(
      ObjectMapper mapper,
      @org.springframework.beans.factory.annotation.Value(
              "${radar.security.auth-requests-per-minute:30}")
          int requestsPerMinute) {
    this.mapper = mapper;
    this.requestsPerMinute = requestsPerMinute;
  }

  @Override
  protected boolean shouldNotFilter(HttpServletRequest r) {
    return !r.getMethod().equals("POST") || !r.getRequestURI().startsWith("/v1/auth/");
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest req, HttpServletResponse res, FilterChain chain)
      throws ServletException, IOException {
    long minute = System.currentTimeMillis() / 60000;
    if (windows.size() > 10000) windows.entrySet().removeIf(e -> e.getValue().minute() < minute);
    if (windows.size() > 10000 && !windows.containsKey(req.getRemoteAddr())) {
      reject(res);
      return;
    }
    var window =
        windows.compute(
            req.getRemoteAddr(),
            (ip, w) ->
                w == null || w.minute() != minute
                    ? new Window(minute, 1)
                    : new Window(minute, w.count() + 1));
    if (window.count() > requestsPerMinute) {
      reject(res);
      return;
    }
    chain.doFilter(req, res);
  }

  private void reject(HttpServletResponse res) throws IOException {
    res.setStatus(429);
    res.setHeader("Retry-After", "60");
    res.setContentType("application/json;charset=UTF-8");
    mapper.writeValue(
        res.getOutputStream(),
        Errors.body("rate_limited", "Aguarde um minuto antes de tentar novamente."));
  }
}
