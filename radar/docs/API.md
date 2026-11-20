# Radar · contrato da API (front ↔ back)

Este documento descreve o que o app em Flutter espera do backend em Java/Spring Boot. O código do lado do app está em:

- `lib/data/models.dart`: modelos e leitura/escrita do JSON (`fromJson` / `toJson`)
- `lib/data/api/http_repository.dart`: uma função por endpoint
- `test/data_test.dart`: exemplos reais de JSON que o app aceita

Se algo aqui não fizer sentido do lado de vocês, vale mudar. O ponto é a gente combinar antes e manter este arquivo atualizado.

---

## 1. Convenções

| Item | Regra |
|---|---|
| Base | `https://<host>/v1` |
| Formato | JSON UTF-8, chaves em **camelCase** (Jackson no backend Java) |
| Datas | RFC 3339 em UTC. Exemplo: `"2026-11-14T12:41:05Z"` (nanossegundos são aceitos) |
| Enums | string em minúsculas (`"urgent"`, `"tech-br"`) |
| Opcionais | podem vir ausentes (`omitempty`) ou `null` |
| Campos extras | o app ignora; dá pra adicionar campo sem quebrar versão antiga |
| Idioma | o app manda `Accept-Language: pt-BR`. Todo texto já vem em português |
| Auth | `Authorization: Bearer <token>` em todas as rotas de negócio; anônimo/cadastro/login/refresh são públicos, logout exige Bearer |
| Paginação | cursor opaco: `?cursor=<string>&limit=20` → `{ "items": [...], "nextCursor": "..." }`. `nextCursor` ausente/null = acabou |
| Rumores | rotas de matérias aceitam `?rumors=true|false`. **Padrão `false`**: não devolver `confirmed=false` |
| Sem conteúdo | `204 No Content` (corpo vazio) nas rotas de escrita |

### Erros

```json
{ "error": { "code": "not_found", "message": "Essa matéria saiu do ar." } }
```

- `message` aparece **direto pro usuário**: português, frase curta, sem "por favor", sem exclamação, dizendo o que fazer.
- Status que o app trata de forma especial:
  - `401`: o app descarta o token, faz login anônimo de novo e repete a chamada uma vez.
  - `404` em `GET /articles/{id}`, `GET /live/{id}` e `GET /me/prefs`: o app entende como "não existe".
  - `5xx`: o app mostra "O Radar está instável agora…" se não vier `message`.
- Sem resposta em 15 s: o app trata como sem conexão e mostra o cache.

---

## 2. Endpoints

### Autenticação
| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| POST | `/v1/auth/anonymous` | `{ "platform": "ios" \| "android" }` | `{ "token": "..." }` |

No MVP, todo usuário começa anônimo (um token por instalação). Login com Apple/Google ("Já tenho conta") fica pra depois. Quando entrar, a ideia é `POST /v1/auth/apple` e `/v1/auth/google` devolverem o mesmo formato e unirem os dados do usuário anônimo.

### Conteúdo
| Método | Rota | Query | Resposta | Tela |
|---|---|---|---|---|
| GET | `/v1/home` | `rumors` | `HomeSummary` | 05 Agora (topo) |
| GET | `/v1/feed` | `filter`, `cursor`, `limit`, `rumors` | `Page<Article>` | 05 Agora (lista) |
| GET | `/v1/feed/new-count` | `since` (RFC 3339), `filter`, `rumors` | `{ "count": 3 }` | pílula "↑ 3 novas" (o app consulta a cada 15 s) |
| GET | `/v1/articles/{id}` | | `Article` (404 se não existe) | 06 Matéria, deep link, push |
| GET | `/v1/articles` | `ids=a,b,c` | `{ "items": [Article] }` (ignora ids inexistentes) | 10 Salvos, ranking |
| GET | `/v1/topics/{slug}` | `company`, `cursor`, `rumors` | `TopicPage` | 08 Tópico |
| GET | `/v1/explore` | | `ExploreData` | 07 Explorar |
| GET | `/v1/search` | `q`, `rumors` | `SearchResult` | 09 Busca |
| GET | `/v1/live/{id}` | | `LiveEvent` | 14/15 Live Activity (lado nativo) |

`filter` do feed: `for-you` (padrão) | `urgent` (`urgency` ≠ `normal`) | `following` (tópicos e entidades que o usuário segue, salvos em `/me/prefs`).

### Usuário
| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| GET | `/v1/me` | | `UserProfile` |
| GET | `/v1/me/stats/weekly` | | `WeeklyStats` |
| GET | `/v1/me/prefs` | | `UserPrefs` (404 se nunca salvou) |
| PUT | `/v1/me/prefs` | `UserPrefs` (objeto inteiro) | 204 |
| GET | `/v1/me/alerts` | | `{ "items": [Alert] }` (mais recentes primeiro, últimos 7 dias) |
| POST | `/v1/me/alerts/read` | `{ "ids": ["al-1"] }` | 204 |
| GET | `/v1/me/saved` | | `{ "items": [SavedEntry] }` |
| PUT | `/v1/me/saved/{articleId}` | `{ "progress"?: 0.55, "archived"?: true }` (campos opcionais, upsert) | 204 |
| DELETE | `/v1/me/saved/{articleId}` | | 204 |
| PUT | `/v1/me/following/{entityId}` | | 204 |
| DELETE | `/v1/me/following/{entityId}` | | 204 |
| POST | `/v1/me/push-tokens` | `{ "token": "...", "platform": "ios" }` | 204 |
| POST | `/v1/waitlist/community` | | 204 |

**Quem manda nos dados:** o app guarda tudo localmente e envia cada mudança na hora (salvar, seguir, preferências). Se o envio falhar, o estado local vale. O `GET /me/saved` só é usado na primeira abertura, ou num aparelho novo, pra restaurar os salvos.

---

## 3. Modelos (notação de referência)

O mesmo formato do `PROMPT_RADAR.md` §6, com os campos extras que as telas pediram. Os comentários marcam o que é **novo** em relação ao prompt.

```go
package api

import "time"

type Category string // "ia" | "seguranca" | "bigtech" | "programacao" | "chips" | "startups"
// | "gadgets" | "games" | "regulacao" | "cripto" | "tech-br" | "espaco"

type Urgency string // "normal" | "important" | "urgent"

type Source struct {
	Name    string  `json:"name"`
	URL     string  `json:"url"`
	LogoURL *string `json:"logoUrl,omitempty"`
	Color   *string `json:"color,omitempty"` // NOVO, opcional: "#B71C1C". Sem cor, o app gera uma a partir do nome
}

type Entity struct {
	Type string `json:"type"` // "company" | "person"
	ID   string `json:"id"`   // slug estável: "nvidia", "jensen-huang"
	Name string `json:"name"`
}

type Article struct {
	ID             string    `json:"id"`
	Title          string    `json:"title"`
	Summary        [3]string `json:"summary"` // exatamente 3 pontos
	Body           string    `json:"body"`    // texto puro; parágrafos separados por "\n\n"
	Category       Category  `json:"category"`
	Kicker         *string   `json:"kicker,omitempty"` // NOVO, opcional: rótulo editorial no lugar da categoria ("Mercado")
	ImageURL       *string   `json:"imageUrl,omitempty"`
	DetectedAt     time.Time `json:"detectedAt"`
	PublishedAt    time.Time `json:"publishedAt"`
	Sources        []Source  `json:"sources"`     // as 2–3 principais (o app mostra "The Verge, Wired +6")
	SourceCount    int       `json:"sourceCount"` // total de fontes que confirmam
	FirstInBrazil  bool      `json:"firstInBrazil"`
	LeadMinutes    *int      `json:"leadMinutes,omitempty"`
	Urgency        Urgency   `json:"urgency"`
	Confirmed      bool      `json:"confirmed"`
	ReadingMinutes int       `json:"readingMinutes"`
	AudioURL       *string   `json:"audioUrl,omitempty"`
	AudioMinutes   *int      `json:"audioMinutes,omitempty"`
	Entities       []Entity  `json:"entities"`
	TrendingTag    *string   `json:"trendingTag,omitempty"`
}

type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"nextCursor,omitempty"`
}

// GET /v1/home (NOVO)
type HomeSummary struct {
	Hero                 Article     `json:"hero"`                 // card de destaque limão
	ScoopsSinceLastNight int         `json:"scoopsSinceLastNight"` // "14 furos desde ontem à noite"
	Trending             TrendingTag `json:"trending"`             // card "Em alta hoje"
}

type TrendingTag struct {
	Tag    string `json:"tag"`    // sem "#": "ransomware"
	Count  int    `json:"count"`  // "231 matérias"
	PerDay [7]int `json:"perDay"` // 7 barras, mais antigo → hoje
}

// GET /v1/topics/{slug} (NOVO)
type TopicPage struct {
	Today     int           `json:"today"`     // "48 hoje"
	Week      int           `json:"week"`      // "312 na semana"
	Scoops    int           `json:"scoops"`    // "6 furos"
	Companies []string      `json:"companies"` // chips de filtro: ["OpenAI","Anthropic","Google","Meta"]
	Feed      Page[Article] `json:"feed"`
}

// GET /v1/explore (NOVO)
type ExploreData struct {
	Topics   []TopicStat    `json:"topics"`   // grade 2×2 (4 itens)
	Trending []TrendingItem `json:"trending"` // ranking 1–3
	People   []Person       `json:"people"`   // "Pessoas em destaque"
}

type TopicStat struct {
	Category     Category `json:"category"`
	DeltaPercent int      `json:"deltaPercent"` // 12 → o app mostra "+12%"
	Today        int      `json:"today"`
}

type TrendingItem struct {
	ArticleID string `json:"articleId"`
	Title     string `json:"title"`   // título curto pro ranking
	Readers   int    `json:"readers"` // 12400 → o app mostra "12,4 mil lendo"
}

type Person struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`                // "Jensen Huang" (o app tira as iniciais)
	ShortName *string `json:"shortName,omitempty"` // "J. Huang"; se faltar, o app monta
	Color     *string `json:"color,omitempty"`
}

// GET /v1/search (NOVO)
type SearchResult struct {
	Articles []Article   `json:"articles"`
	Entity   *EntityInfo `json:"entity,omitempty"` // melhor correspondência: card "Nvidia · Empresa · 412 matérias"
	People   []Person    `json:"people"`
	// Tópicos não precisam: o app busca na lista fixa de categorias.
}

type EntityInfo struct {
	ID           string  `json:"id"`
	Type         string  `json:"type"` // "company" | "person"
	Name         string  `json:"name"`
	Color        *string `json:"color,omitempty"` // cor da marca: "#76B900"
	ArticleCount int     `json:"articleCount"`
	ScoopsToday  int     `json:"scoopsToday"`
}

type LiveEvent struct {
	ID       string       `json:"id"`
	Title    string       `json:"title"`    // "Keynote Nvidia"
	Headline string       `json:"headline"` // NOVO: "Huang revela a GPU Rubin Ultra"
	StartsAt time.Time    `json:"startsAt"`
	EndsAt   time.Time    `json:"endsAt"`
	Updates  []LiveUpdate `json:"updates"` // mais recentes primeiro
}

type LiveUpdate struct {
	At   time.Time `json:"at"`
	Text string    `json:"text"`
}

// GET /v1/me (NOVO)
type UserProfile struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`      // anônimo: "Leitor"
	CreatedAt time.Time `json:"createdAt"` // "Leitor desde outubro de 2026"
}

type WeeklyStats struct {
	Scoops         int    `json:"scoops"`
	StreakDays     int    `json:"streakDays"`
	AvgLeadMinutes int    `json:"avgLeadMinutes"`
	PerDay         [7]int `json:"perDay"` // seg → dom
}

type QuietHours struct {
	From string `json:"from"` // "23:00" (horário de Brasília)
	To   string `json:"to"`   // "07:00"
}

type UserPrefs struct {
	Topics           []Category  `json:"topics"`
	AlertLevel       string      `json:"alertLevel"`  // "urgent" | "balanced" | "realtime"
	DigestTimes      []string    `json:"digestTimes"` // ["08:00","19:00"] ou [] (resumo desligado)
	QuietHours       *QuietHours `json:"quietHours"`  // null = sem horário de silêncio
	ShowRumors       bool        `json:"showRumors"`
	UrgentAlerts     bool        `json:"urgentAlerts"` // NOVO: toggle "Urgentes" do Perfil
	FollowedEntities []string    `json:"followedEntities"`
}

// GET /v1/me/alerts (NOVO)
type Alert struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"`               // "urgent" | "scoop" | "digest" | "article"
	Category  *Category `json:"category,omitempty"` // usado quando type = "article" (define ícone e cor)
	Title     string    `json:"title"`              // "Ataque hacker atinge banco digital"
	Subtitle  string    `json:"subtitle"`           // "Urgente · primeiro no Brasil"
	At        time.Time `json:"at"`
	Read      bool      `json:"read"`
	ArticleID *string   `json:"articleId,omitempty"` // toque abre a matéria
}

// GET /v1/me/saved (NOVO)
type SavedEntry struct {
	ArticleID string    `json:"articleId"`
	SavedAt   time.Time `json:"savedAt"`
	Progress  float64   `json:"progress"` // 0 a 1
	Archived  bool      `json:"archived"` // aba "Lidos"
}
```

O app decide ícone e cor a partir de `category` e `type`. O backend não precisa mandar nada visual, exceto as cores opcionais de marca (`color`).

---

## 4. Push e deep links

O payload de toda notificação precisa ter o link que abre a tela certa:

```json
{
  "aps": { "alert": { "title": "Urgente · Ataque hacker atinge banco", "body": "Dados de 2 milhões de clientes expostos. Primeiro no Brasil, 41 min antes da imprensa." } },
  "deepLink": "radar://materia/banco-ataque?source=push"
}
```

Links que o app entende: `radar://materia/{id}`, `radar://topico/{slug}`, `radar://alertas`. O `?source=` (`push` | `widget` | `live`) vai pro analytics.

**Disponível:** alertas internos, tela de pré-permissão, registro de dispositivos e adaptador webhook no backend. O envio externo depende de um provedor de push e da implementação de `PushProvider` no aplicativo. Supabase não fornece FCM/APNs automaticamente.

O backend precisa respeitar, por usuário: `alertLevel`, `urgentAlerts`, `digestTimes`, `quietHours` (urgentes passam mesmo no silêncio) e `showRumors`.

---

## 5. Rodar o app contra a API local

```bash
# simulador iOS (localhost funciona direto)
flutter run --dart-define=RADAR_API_URL=http://localhost:8080

# emulador Android (localhost da máquina = 10.0.2.2)
flutter run --dart-define=RADAR_API_URL=http://10.0.2.2:8080
```

Sem `RADAR_API_URL`, o app roda com os dados mockados. O http só é liberado em rede local/debug; em produção a API precisa de https.

## 6. Ordem de referência do MVP

1. Cadastro/login antes dos interesses; `home`, `feed`, `articles/{id}` carregam conteúdo após autenticação. O endpoint anonymous permanece para promover a identidade no cadastro, sem liberar o onboarding.
2. `me`, `me/prefs`, `me/saved`, `me/stats/weekly`.
3. `topics/{slug}`, `explore`, `search`.
4. `me/alerts`, `feed/new-count`, `me/following`, `waitlist`.
5. Push (`me/push-tokens` + envio) e `live/{id}`.


## 7. Backend Java + Supabase PostgreSQL

A implementação está em [../../backend](../../backend/README.md). A persistência usa PostgreSQL Supabase via JDBC, com schema privado, RLS e migrações Flyway. O Flutter continua consumindo `/v1` via Spring Security, sem acesso direto às tabelas.

Contas, refresh, logout, recuperação de senha e Google/Apple estão documentados no README do backend e integrados ao cliente Flutter. Para manter salvos no cadastro, o app usa `/v1/auth/upgrade`; para conta existente, login com Bearer anônimo importa salvos e preferências. O cliente migra tokens para armazenamento seguro e não cria outra identidade ao falhar um refresh.

O registro de dispositivos mantém `kind: "token"`; identificadores FCM/FID antigos não são migrados nem usados para entrega. `DELETE /v1/me/push-tokens` recebe `{"token":"..."}` e só remove o identificador do usuário autenticado. Filas, agendamento, preferências e coleta RSS estão implementados, com ativação dependente das configurações reais dos serviços.

Leituras concluídas usam `/v1/me/reads/{articleId}`. Campos extras de `/v1/me`: `email` e `anonymous`. As rotas de autenticação públicas são anonymous, register, login, refresh, forgot-password, reset-password e supabase; upgrade, link/supabase e logout exigem Bearer.


### Login social Supabase

`POST /v1/auth/supabase` recebe `{"accessToken":"TOKEN_SUPABASE"}` e retorna
`{token, refreshToken, expiresIn}` da API. O backend verifica o usuário social e
email confirmado no Supabase. `POST /v1/auth/link/supabase` recebe o mesmo corpo,
exige Bearer da API e vincula o provedor ao mesmo email. Email/senha continuam no
backend Java; não há chave privada PostgreSQL ou service_role no aplicativo.

`GET /v1/home` retorna sucesso mesmo sem notícias, com destaque ausente/null e
contadores vazios. A paginação do feed permanece `{items,nextCursor}`.
