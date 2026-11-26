package br.com.radar.content;

import java.util.regex.Pattern;

public final class BrazilianPublishers {
  public static final String URL_PATTERN =
      "^https?://([a-z0-9-]+\\.)*(?:(globo\\.com|ebc\\.com\\.br|r7\\.com|band\\.com\\.br|sbt\\.com\\.br|tvcultura\\.com\\.br)([/?#]|$)"
          + "|cnnbrasil\\.com\\.br/(tecnologia|ciencia-e-tecnologia|economia/(money/)?(tecnologia|inteligencia-artificial))(/|[?#]|$))";
  private static final Pattern URL = Pattern.compile(URL_PATTERN, Pattern.CASE_INSENSITIVE);

  private BrazilianPublishers() {}

  public static boolean contains(String url) {
    return URL.matcher(url).find();
  }
}
