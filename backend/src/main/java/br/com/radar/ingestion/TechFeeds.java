package br.com.radar.ingestion;

import java.net.URI;
import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

final class TechFeeds {
  record Feed(
      String id,
      String name,
      String url,
      String fallback,
      boolean licensedOnly,
      boolean openFullText) {
    Feed(String id, String name, String url, String fallback, boolean licensedOnly) {
      this(id, name, url, fallback, licensedOnly, false);
    }

    String host() {
      return URI.create(url).getHost();
    }
  }

  private static final List<Feed> CATALOG =
      List.of(
          new Feed(
              "rss-g1-tech", "g1", "https://g1.globo.com/rss/g1/tecnologia/", "tech-br", false),
          new Feed(
              "rss-cnn-brasil", "CNN Brasil", "https://admin.cnnbrasil.com.br/feed/", null, false),
          new Feed(
              "rss-ebc-geral",
              "Agência Brasil (EBC)",
              "https://agenciabrasil.ebc.com.br/rss/geral/feed.xml",
              null,
              false),
          new Feed("rss-canaltech", "Canaltech", "https://canaltech.com.br/rss/", null, false),
          new Feed("rss-tecnoblog", "Tecnoblog", "https://tecnoblog.net/feed/", "tech-br", false),
          new Feed(
              "rss-techcrunch", "TechCrunch", "https://techcrunch.com/feed/", "startups", false),
          new Feed(
              "rss-ars",
              "Ars Technica",
              "https://feeds.arstechnica.com/arstechnica/index",
              null,
              false),
          new Feed("rss-wired", "WIRED", "https://www.wired.com/feed/rss", null, false),
          new Feed("rss-verge", "The Verge", "https://www.theverge.com/rss/index.xml", null, false),
          new Feed(
              "rss-mit-tr",
              "MIT Technology Review",
              "https://www.technologyreview.com/feed/",
              null,
              false),
          new Feed("rss-dbt", "dbt Labs", "https://www.getdbt.com/blog/feed.xml", "dados", false),
          new Feed(
              "rss-wikimedia-tech",
              "Wikimedia Diff",
              "https://diff.wikimedia.org/category/technology/feed/",
              "programacao",
              false,
              true),
          new Feed(
              "rss-power-bi",
              "Microsoft Power BI",
              "https://community.fabric.microsoft.com/t5/s/rss/board?board.id=fbc_pbiupdatesblog",
              "dados",
              false),
          new Feed(
              "rss-bbc-tech",
              "BBC News",
              "https://feeds.bbci.co.uk/news/technology/rss.xml",
              "bigtech",
              true),
          new Feed(
              "rss-guardian-tech",
              "The Guardian",
              "https://www.theguardian.com/uk/technology/rss",
              "bigtech",
              true),
          new Feed(
              "rss-nyt-tech",
              "The New York Times",
              "https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml",
              "bigtech",
              true));

  private record Rule(String category, Pattern pattern) {
    Rule(String category, String terms) {
      this(category, Pattern.compile("\\b(?:" + terms + ")\\b"));
    }
  }

  private static final List<Rule> RULES =
      List.of(
          new Rule(
              "seguranca",
              "cybersecurity|ransomware|malware|phishing|data breach|vulnerabilit(?:y|ies)|vulnerabilidade[s]?|vazamento de dados|ciberseguranca|ataque hacker|spyware"),
          new Rule(
              "ia",
              "ai|ia|llm[s]?|chatgpt|openai|anthropic|claude|gemini|artificial intelligence|inteligencia artificial|machine learning"),
          new Rule(
              "chips",
              "chip[s]?|chipset[s]?|semiconductor[s]?|semicondutor(?:es)?|gpu[s]?|cpu[s]?|processador(?:es)?|nvidia|tsmc|qualcomm"),
          new Rule(
              "regulacao",
              "antitrust|antitruste|lgpd|data protection|digital markets act|regulacao digital|regulamentacao de ia"),
          new Rule("espaco", "spacex|nasa|starship|foguete[s]?|satellite[s]?|satelite[s]?"),
          new Rule("cripto", "bitcoin|crypto|criptomoeda[s]?|ethereum|blockchain"),
          new Rule(
              "games", "gaming|video games?|videogame[s]?|playstation|xbox|nintendo|steam deck"),
          new Rule(
              "dados",
              "sql|power bi|tableau|bigquery|snowflake|analista(?:s)? de dados|analise de dados|analitica de dados|engenharia de dados|ciencia de dados|visualizacao de dados|data analyst[s]?|data engineering|data analytics|data science|data visualization|data warehouse[s]?|business intelligence"),
          new Rule(
              "programacao",
              "programacao|programming|github|javascript|python|open source|codigo aberto|software development|developer tools|kubernetes"),
          new Rule(
              "gadgets",
              "smartphone[s]?|iphone[s]?|android|pixel|galaxy|laptop[s]?|notebook[s]?|smartwatch|wearables|tablet[s]?"),
          new Rule("startups", "startup[s]?|venture capital|seed funding|rodada de investimento"),
          new Rule(
              "bigtech",
              "apple|google|microsoft|meta|amazon web services|tiktok|instagram|whatsapp|youtube|big tech|software|social media|redes sociais|cloud computing|computacao em nuvem"));

  private static final Pattern PROMOTION =
      Pattern.compile(
          "\\b(?:sponsored content|partner content|conteudo patrocinado|publicidade|publieditorial|black friday|cyber monday)\\b");

  private TechFeeds() {}

  static List<Feed> catalog(boolean licensed) {
    return CATALOG.stream().filter(feed -> licensed || !feed.licensedOnly()).toList();
  }

  static String category(String title, String excerpt, String fallback) {
    String normalizedTitle = normalize(title);
    if (PROMOTION.matcher(normalizedTitle).find()) return null;
    if ("dados".equals(fallback)) return fallback;
    for (String text : List.of(normalizedTitle, normalize(excerpt))) {
      for (Rule rule : RULES) {
        if (rule.pattern().matcher(text).find()) return rule.category();
      }
    }
    return fallback;
  }

  private static String normalize(String value) {
    return Normalizer.normalize(value, Normalizer.Form.NFD)
        .replaceAll("\\p{M}+", "")
        .toLowerCase(Locale.ROOT);
  }
}
