package br.com.radar.common;

import org.springframework.http.HttpStatus;

public class ApiException extends RuntimeException {
  public final HttpStatus status;
  public final String code;

  public ApiException(HttpStatus status, String code, String message) {
    super(message);
    this.status = status;
    this.code = code;
  }

  public static ApiException missing() {
    return new ApiException(
        HttpStatus.NOT_FOUND, "not_found", "Esse conteúdo não está disponível.");
  }

  public static ApiException invalid(String message) {
    return new ApiException(HttpStatus.BAD_REQUEST, "invalid_request", message);
  }

  public static ApiException unauthorized() {
    return new ApiException(
        HttpStatus.UNAUTHORIZED, "unauthorized", "Entre novamente para continuar.");
  }
}
