package br.com.radar;

import static org.assertj.core.api.Assertions.*;

import br.com.radar.config.AuthRateLimit;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;

class AuthRateLimitTest {
  @Test
  void limitsAuthPerAddressAndDoesNotTrustForwardedHeader() throws Exception {
    var filter = new AuthRateLimit(new ObjectMapper(), 2);
    for (int i = 0; i < 3; i++) {
      var req = new MockHttpServletRequest("POST", "/v1/auth/login");
      req.setRemoteAddr("127.0.0.99");
      req.addHeader("X-Forwarded-For", "10.0.0." + i);
      var res = new MockHttpServletResponse();
      filter.doFilter(req, res, new MockFilterChain());
      assertThat(res.getStatus()).isEqualTo(i == 2 ? 429 : 200);
      if (i == 2) assertThat(res.getHeader("Retry-After")).isEqualTo("60");
    }
    var req = new MockHttpServletRequest("POST", "/v1/auth/login");
    req.setRemoteAddr("127.0.0.100");
    var res = new MockHttpServletResponse();
    filter.doFilter(req, res, new MockFilterChain());
    assertThat(res.getStatus()).isEqualTo(200);
  }
}
