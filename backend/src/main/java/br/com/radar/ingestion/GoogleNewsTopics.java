package br.com.radar.ingestion;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Consultas do Google News (RSS de busca) para cada tópico do app.
 *
 * <p>As consultas ficam em português e são restritas por {@code site:} aos veículos dos quais o app
 * pode guardar o texto completo; o feed só exibe matérias com corpo, então buscar fora deles só
 * gastaria requisições.
 */
final class GoogleNewsTopics {
  static final String HOST = "news.google.com";

  /** Tópico (mesmos slugs de ContentModels.CATEGORY) → termos de busca. */
  static final Map<String, String> QUERIES = new LinkedHashMap<>();

  static {
    QUERIES.put(
        "ia",
        "\"inteligência artificial\" OR ChatGPT OR OpenAI OR Gemini OR \"aprendizado de máquina\"");
    QUERIES.put(
        "seguranca",
        "cibersegurança OR \"ataque hacker\" OR ransomware OR \"vazamento de dados\" OR golpe digital");
    QUERIES.put(
        "bigtech", "\"big techs\" OR Google OR Apple OR Microsoft OR Meta OR Amazon OR TikTok");
    QUERIES.put(
        "programacao",
        "programação OR desenvolvedores OR \"código aberto\" OR software livre OR GitHub");
    QUERIES.put("chips", "semicondutores OR chips OR Nvidia OR processadores OR TSMC");
    QUERIES.put(
        "startups", "startup OR startups OR \"rodada de investimento\" OR \"venture capital\"");
    QUERIES.put("gadgets", "smartphone OR celular OR iPhone OR Android OR notebook OR tablet");
    QUERIES.put("games", "games OR videogame OR \"jogos eletrônicos\" OR PlayStation OR Xbox");
    QUERIES.put(
        "regulacao",
        "\"regulação da inteligência artificial\" OR LGPD OR ANPD OR \"regulação das plataformas\""
            + " OR \"marco civil da internet\"");
    QUERIES.put("cripto", "bitcoin OR criptomoedas OR criptoativos OR blockchain OR Drex");
    QUERIES.put(
        "tech-br",
        "tecnologia OR inovação OR \"transformação digital\" OR conectividade OR 5G OR Anatel");
    QUERIES.put("espaco", "NASA OR SpaceX OR AEB OR foguete OR satélite OR astronomia");
    QUERIES.put(
        "dados",
        "\"ciência de dados\" OR \"análise de dados\" OR \"engenharia de dados\" OR \"Power BI\""
            + " OR \"inteligência de dados\"");
  }

  private GoogleNewsTopics() {}

  /** URL do RSS de busca do Google News, em pt-BR, limitada aos últimos {@code window} dias. */
  static String searchUrl(String topic, Collection<String> sites, int windowDays) {
    String terms = QUERIES.get(topic);
    if (terms == null) throw new IllegalArgumentException("Tópico sem consulta: " + topic);
    String query = "(" + terms + ")";
    if (!sites.isEmpty())
      query +=
          " ("
              + sites.stream().map(site -> "site:" + site).collect(Collectors.joining(" OR "))
              + ")";
    query += " when:" + Math.max(1, windowDays) + "d";
    return "https://"
        + HOST
        + "/rss/search?q="
        + URLEncoder.encode(query, StandardCharsets.UTF_8)
        + "&hl=pt-BR&gl=BR&ceid=BR:pt-419";
  }

  /**
   * O Google News acrescenta " - Veículo" ao título. Devolve {título, veículo}; o veículo fica
   * vazio quando não há sufixo.
   */
  static String[] splitTitle(String raw) {
    String title = raw == null ? "" : raw.strip();
    int dash = title.lastIndexOf(" - ");
    if (dash <= 0 || dash > title.length() - 4) return new String[] {title, ""};
    return new String[] {title.substring(0, dash).strip(), title.substring(dash + 3).strip()};
  }
}
