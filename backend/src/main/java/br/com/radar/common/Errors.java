package br.com.radar.common;

import java.util.Map;
import org.slf4j.LoggerFactory;
import org.springframework.http.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class Errors {
  public static Map<String, Object> body(String code, String message) {
    return Map.of("error", Map.of("code", code, "message", message));
  }

  @ExceptionHandler(ApiException.class)
  ResponseEntity<?> api(ApiException e) {
    return ResponseEntity.status(e.status).body(body(e.code, e.getMessage()));
  }

  @ExceptionHandler({
    MethodArgumentNotValidException.class,
    HandlerMethodValidationException.class,
    HttpMessageNotReadableException.class,
    MethodArgumentTypeMismatchException.class,
    MissingServletRequestParameterException.class
  })
  ResponseEntity<?> invalid(Exception e) {
    return ResponseEntity.badRequest()
        .body(body("invalid_request", "Confira os campos enviados e tente novamente."));
  }

  @ExceptionHandler(AccessDeniedException.class)
  ResponseEntity<?> forbidden(Exception e) {
    return ResponseEntity.status(403)
        .body(body("forbidden", "Sua conta não tem acesso a essa ação."));
  }

  @ExceptionHandler(NoResourceFoundException.class)
  ResponseEntity<?> missing(Exception e) {
    return ResponseEntity.status(404).body(body("not_found", "Essa rota não existe."));
  }

  @ExceptionHandler(org.springframework.web.HttpRequestMethodNotSupportedException.class)
  ResponseEntity<?> methodNotAllowed(Exception e) {
    return ResponseEntity.status(405)
        .body(body("method_not_allowed", "Esse método não está disponível para essa rota."));
  }

  @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
  ResponseEntity<?> unsupportedMedia(Exception e) {
    return ResponseEntity.status(415)
        .body(body("unsupported_media_type", "Envie os dados no formato JSON."));
  }

  @ExceptionHandler(org.springframework.dao.DataAccessException.class)
  ResponseEntity<?> storage(org.springframework.dao.DataAccessException e) {
    LoggerFactory.getLogger(Errors.class)
        .warn("Banco indisponível: {}", e.getMostSpecificCause().getClass().getSimpleName());
    return ResponseEntity.status(503)
        .body(
            body(
                "storage_unavailable",
                "Não foi possível acessar o banco. Tente novamente em instantes."));
  }

  @ExceptionHandler(Exception.class)
  ResponseEntity<?> unexpected(Exception e) {
    LoggerFactory.getLogger(Errors.class).error("Falha ao processar requisição", e);
    return ResponseEntity.internalServerError()
        .body(
            body("internal_error", "O news.dev está instável agora. Tente de novo em instantes."));
  }
}
