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
              "cybersecurity|ransomware|malware|phishing|data breach|vulnerabilit(?:y|ies)|vulnerabilidade[s]?|vazamento de dados|ciberseguranca|ataque hacker|ataques hackers|hacker[s]?|spyware|criptografia|golpe[s]? digita(?:l|is)|golpe[s]? (?:online|virtual|virtuais|pela internet|no whatsapp|via whatsapp)"),
          new Rule(
              "ia",
              "ai|ia|llm[s]?|chatgpt|openai|anthropic|claude|gemini|artificial intelligence|inteligencia artificial|machine learning"),
          new Rule(
              "chips",
              "chip[s]?|chipset[s]?|semiconductor[s]?|semicondutor(?:es)?|gpu[s]?|cpu[s]?|processador(?:es)?|nvidia|tsmc|qualcomm|computacao quantica|computador(?:es)? quantico[s]?|tecnologia quantica|pos-quantica|huawei"),
          new Rule(
              "regulacao",
              "antitrust|antitruste|lgpd|data protection|digital markets act|regulacao digital|regulamentacao de ia"),
          new Rule(
              "espaco",
              "spacex|nasa|starship|foguete[s]?|satellite[s]?|satelite[s]?|estacao espacial|astronauta[s]?|missao espacial|agencia espacial|telescopio[s]?|asteroide[s]?"),
          new Rule("cripto", "bitcoin|crypto|criptomoeda[s]?|ethereum|blockchain"),
          new Rule(
              "games",
              "gaming|games?|video games?|videogame[s]?|jogos eletronicos|esports?|e-sports?|playstation|xbox|nintendo|steam deck"),
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
              "apple|google|microsoft|meta|amazon web services|tiktok|instagram|whatsapp|youtube|big techs?|software|social media|redes sociais|cloud computing|computacao em nuvem"));

  /**
   * Tecnologia em geral, só para a checagem estrita do Google News: sem isso o tópico tech-br não
   * teria regra própria. Fica fora de RULES para não mudar a categoria das matérias do RSS.
   */
  private static final Rule TECH_BR =
      new Rule(
          "tech-br",
          "tecnologia[s]?|tecnologic[ao]s?|inovacao tecnologica|anatel|5g|telecomunicac(?:ao|oes)|ministerio da ciencia");

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

  /**
   * Categoria pelas regras de tecnologia, sem cair no tópico padrão: null quando o texto não fala
   * de tecnologia. Se o tópico preferido também bater, ele vence.
   */
  static String strictCategory(String text, String preferred) {
    String normalized = normalize(text == null ? "" : text);
    if (PROMOTION.matcher(normalized).find()) return null;
    String first = null;
    for (Rule rule : RULES) {
      if (!rule.pattern().matcher(normalized).find()) continue;
      if (rule.category().equals(preferred)) return preferred;
      if (first == null) first = rule.category();
    }
    if (first == null && TECH_BR.pattern().matcher(normalized).find()) return TECH_BR.category();
    return first;
  }

  private static String normalize(String value) {
    return Normalizer.normalize(value, Normalizer.Form.NFD)
        .replaceAll("\\p{M}+", "")
        .toLowerCase(Locale.ROOT);
  }
}
