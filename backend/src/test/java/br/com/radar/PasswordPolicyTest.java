package br.com.radar;

import static org.assertj.core.api.Assertions.*;

import br.com.radar.auth.AuthModels;
import br.com.radar.auth.AuthService;
import br.com.radar.common.ApiException;
import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;

class PasswordPolicyTest {
  @Test
  void acceptsEightCharactersAndRejectsSevenForRegistrationAndReset() {
    try (var factory = Validation.buildDefaultValidatorFactory()) {
      var validator = factory.getValidator();
      assertThat(validator.validate(new AuthModels.Register("ana@example.com", "Senha123", "Ana")))
          .isEmpty();
      assertThat(validator.validate(new AuthModels.Reset("reset-token", "Senha123"))).isEmpty();
      assertThat(validator.validate(new AuthModels.Register("ana@example.com", "Senha12", "Ana")))
          .isNotEmpty();
      assertThat(validator.validate(new AuthModels.Reset("reset-token", "Senha12"))).isNotEmpty();
    }
    assertThatCode(() -> AuthService.validatePassword("Senha123")).doesNotThrowAnyException();
    assertThatThrownBy(() -> AuthService.validatePassword("Senha12"))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void preservesBcryptLimitInBytes() {
    assertThatCode(() -> AuthService.validatePassword("a".repeat(72))).doesNotThrowAnyException();
    assertThatThrownBy(() -> AuthService.validatePassword("a".repeat(73)))
        .isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuthService.validatePassword("á".repeat(37)))
        .isInstanceOf(ApiException.class);
  }
}
