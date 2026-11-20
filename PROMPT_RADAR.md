# Prompt — Radar: app de notícias de tecnologia (MVP)

Você vai construir o frontend do **Radar**, um app iOS-first de notícias de tecnologia para o público brasileiro. Leia tudo antes de começar. O design de referência está no Figma (arquivo "Radar — App de notícias tech"); este documento descreve exatamente o que está lá.

---

## 1. O produto

**Proposta:** "Tecnologia, antes de todo mundo." O Radar usa vários motores de IA rodando 24h para monitorar mais de 2.000 fontes (agências, blogs oficiais de empresas, sites gringos, redes sociais, repositórios, avisos de segurança). Quando uma notícia relevante surge, a IA confirma em mais de uma fonte, traduz, resume em português e entrega ao usuário, de preferência **antes da imprensa brasileira**.

**Temas:** IA, segurança e ataques hacker, big techs e seus CEOs (Nvidia, OpenAI, Apple, Google, Microsoft, Meta…), programação, chips, startups, gadgets, games, regulação, cripto, tech no Brasil e espaço.

**Diferenciais que aparecem na interface:**
- **Selo "Primeiro no Brasil"** em notícias que o Radar publicou antes dos veículos brasileiros.
- **Vantagem medida:** "você soube X min antes da imprensa BR". Aparece no feed, nas notificações, no perfil e no card de compartilhar.
- **Confirmação por fontes:** toda notícia mostra quantas fontes confirmam ("12 fontes") e o horário em que foi detectada.
- **Resumo da IA em 3 pontos** em cada matéria, mais áudio ("Ouvir 2 min").
- **Rumores não confirmados vêm desligados por padrão.** A velocidade não pode custar credibilidade.

**Escopo do MVP:** só notícias. A **Comunidade** (discussões por tópico) vem depois. No MVP ela aparece apenas como teaser "Em breve" com lista de espera.

**Idioma e tom:** português do Brasil. Frases curtas, sentence case (nunca Title Case nem CAIXA ALTA em textos corridos), verbo primeiro nos botões ("Ativar notificações", "Entrar na lista"). Sem "por favor", sem exclamação em texto de sistema, sem "com sucesso". Tom de amigo que entende de tecnologia.

---

## 2. Stack e plataforma

- iOS primeiro (iPhone 15/16 Pro: 393×852 pt). Respeite safe areas, Dynamic Island e home indicator.
- Use a stack que eu indicar. Se não houver indicação, prefira **SwiftUI** para o app, **WidgetKit** para widgets e **ActivityKit** para Live Activity/Dynamic Island. Para cross-platform: React Native/Expo.
- **Só tema escuro** no MVP (o design é dark por identidade).
- Fonte: **SF Pro** (sistema) no app real. No Figma está em Inter só por limitação técnica.
- Acessibilidade: Dynamic Type, VoiceOver em todos os ícones, contraste AA, alvo de toque mínimo de 44 pt.

---

## 3. Design system

### 3.1 Cores (tokens)
| Token | Hex | Uso |
|---|---|---|
| `bg/base` | `#000000` | Fundo das telas |
| `bg/card` | `#1C1C1E` | Cards, tab bar, campos |
| `bg/elevated` | `#2C2C2E` | Sheets internos, botão secundário, banners |
| `bg/control` | `#3A3A3C` | Toggle desligado, trilhos, barras inativas |
| `text/primary` | `#FFFFFF` | Texto principal |
| `text/secondary` | `#8E8E93` | Texto de apoio |
| `text/tertiary` | `#636366` | Metadados, chevrons |
| `accent/radar` | `#D4FF3A` | Cor da marca (verde-limão): destaque, CTA, item ativo |
| `accent/on-radar` | `#0D1400` | Texto e ícone sobre o verde-limão |
| `status/urgent` | `#FF453A` | Urgente, ao vivo, segurança |
| `status/link` | `#0A84FF` | Programação, links, "tempo real" |
| `status/purple` | `#BF5AF2` | Chips/hardware |
| `status/orange` | `#FF9F0A` | Regulação, mercado |
| `separator` | `#38383A` | Divisores (0,5 pt) e bordas |

**Cor por categoria** (ícones, miniaturas e rótulos): IA = limão, Segurança = vermelho, Programação = azul, Chips = roxo, Regulação/Mercado = laranja.
**Tints:** fundos de ícones usam a cor da categoria com 16–18% de opacidade.
**Miniaturas:** gradiente diagonal da cor da categoria até um tom bem escuro dela (ex.: `#D4FF3A → #1F5F2B`). Quando houver imagem real, use a imagem com o mesmo raio.

### 3.2 Tipografia (escala iOS)
| Estilo | Tamanho/altura de linha | Peso |
|---|---|---|
| Display | 48/52 | Bold |
| Large Title | 34/41 | Bold |
| Title 1 | 28/34 | Bold |
| Title 2 | 22/28 | Bold |
| Title 3 | 20/25 | Semibold |
| Big Number | 36/40 | Semibold |
| Headline | 17/22 | Semibold |
| Body | 17/22 | Regular |
| Callout | 16/21 | Regular |
| Subheadline | 15/20 | Regular / Semibold (Emph) |
| Footnote | 13/18 | Regular / Semibold (Emph) |
| Caption 1 | 12/16 | Regular / Medium (Emph) |
| Caption 2 | 11/13 | Semibold |

Letter-spacing levemente negativo em títulos (−2%) e no corpo (−1%).

### 3.3 Medidas
- Margem lateral das telas: **20 pt**. Espaço entre blocos: **16–18 pt**.
- Raios: 12 (pequeno), 16 (miniaturas e tiles), **20–24 (cards)**, **28 (card de destaque e sheets)**, 999 (pílulas).
- Espaçamentos: 4 / 8 / 12 / 16 / 24.
- Ícones: estilo outline com traço de 2 pt (Tabler Icons ou SF Symbols equivalentes), em 16–24 pt.

### 3.4 Componentes
1. **Status bar:** padrão iOS, branca.
2. **Tab bar flutuante:** pílula de 353×64, `bg/card`, borda de 0,5 pt `separator`, a 20 pt das laterais e logo acima do home indicator. Quatro abas: **Agora** (raio), **Explorar** (bússola), **Salvos** (marcador), **Perfil** (usuário). A aba ativa vira uma pílula verde-limão com ícone e rótulo em `on-radar`; as inativas mostram só o ícone cinza. Atrás dela há um gradiente de transparente para preto (170 pt) para o conteúdo sumir por baixo.
3. **Botão** (altura 54, pílula, largura total):
   - **Primário:** fundo limão, texto `on-radar` Headline.
   - **Secundário:** `bg/elevated`, texto branco.
   - **Texto:** sem fundo, texto `text/secondary`.
4. **Chip** (pílula, 8×14 de padding, Subheadline Semibold): ativo = limão com texto escuro; inativo = `bg/card` com texto branco.
5. **Chip de tópico com ícone** (onboarding): ícone de 18 pt + rótulo + check quando selecionado. Inativo tem borda de 1 pt `separator`.
6. **Segmented control (pílula):** fundo `bg/card` com padding de 4. O segmento ativo é `bg/control` com texto branco Semibold; os outros ficam em texto cinza.
7. **Toggle:** 51×31. Ligado = trilho limão com bolinha escura; desligado = trilho `bg/control` com bolinha branca.
8. **Linha de notícia:** à esquerda, coluna com categoria + tempo (Caption 1 Emph na cor da categoria, ex.: "IA · há 8 min"), título (Headline, até 3 linhas) e fontes (Footnote cinza, "The Verge, Wired +6"). À direita, miniatura de 72×72 com raio 16. Divisor inferior de 0,5 pt.
9. **Selo "Primeiro no Brasil":** pílula `on-radar` com ponto limão e texto limão Caption 1 Emph.
10. **Notificação iOS:** vidro escuro (85% de opacidade), raio 22. Ícone do app de 38 pt, título Footnote Semibold, horário à direita e texto Footnote.
11. **Botão circular:** 40×40, `bg/card`, ícone de 20 pt (voltar, salvar, compartilhar, mais).
12. **Ícone do app:** quadrado limão de raio 16 com ícone de radar escuro.
13. **Tile de ícone:** quadrado com raio de 30% do tamanho, fundo com tint da cor e ícone na cor cheia.
14. **Sheet:** `bg/card`, cantos superiores com raio 34, grabber de 36×5, padding inferior de 44. Overlay preto de 60% atrás.
15. **Toast:** pílula `bg/elevated` com check limão em círculo, mensagem e ação "Desfazer" em limão. Fica acima da tab bar.
16. **Banner in-app urgente:** card `bg/elevated` de raio 24 com borda vermelha (60%), tile vermelho com ícone de alerta, "URGENTE · AGORA" em vermelho Caption 2, título e chevron. Entra pelo topo, logo abaixo da status bar.

---

## 4. Telas (20)

### Onboarding
**01 Boas-vindas**
- Fundo preto com brilho radial limão suave no topo.
- Pilha de 3 notificações de exemplo sobrepostas: as de trás mais estreitas e transparentes, com texto truncado em 1 linha. A da frente é urgente.
- Ícone do app, título Display "Tecnologia, antes de todo mundo.", subtítulo "Nossa IA vasculha mais de 2.000 fontes, 24 horas por dia, e traduz o que importa pro português."
- Botões: "Começar" (primário) e "Já tenho conta" (texto).

**02 Escolha de tópicos**
- Barra de progresso em 33%. Título "O que te interessa?" e subtítulo "Escolha 3 ou mais. Seu feed se ajusta ao que você lê."
- Grade com quebra de linha de 12 chips com ícone: IA, Segurança, Big Techs, Programação, Chips, Startups, Gadgets, Games, Regulação, Cripto, Tech BR, Espaço.
- Card de dica com ícone de brilho: "Com esses tópicos você receberia cerca de 40 notícias por dia, com 6 furos em média." A estimativa é dinâmica.
- Botão "Continuar · N escolhidos", ativo só com 3 ou mais.

**03 Intensidade de alertas**
- Progresso em 66%. Título "Quantos alertas você quer?"
- Três cards de opção (raio 24) com tile colorido, título, descrição e rádio:
  - **Só urgentes** (vermelho): "1 a 2 por dia. Só o que não pode esperar."
  - **Equilibrado** (limão, padrão): "Urgentes + resumos às 8h e às 19h."
  - **Tempo real** (azul): "Tudo que nossa IA confirmar, na hora."
- O card selecionado ganha borda limão de 2 pt e rádio cheio com check.
- Card com toggle: "Silêncio das 23h às 7h, exceto urgentes" (ligado).

**04 Pré-permissão de notificações**
- Prévia de tela bloqueada (data, relógio de 86 pt e 2 notificações de exemplo, uma dizendo "Você soube 38 min antes da imprensa brasileira").
- Pílula "Último passo", título "Seja o primeiro a saber" e texto explicativo.
- Botões "Ativar notificações", que só então chama o prompt nativo do iOS, e "Agora não".

### App
**05 Agora (home)**
- Header: avatar com iniciais (círculo limão), segmented "Pra você | Urgente | Seguindo" e sino em botão circular com ponto vermelho de não lidas.
- Saudação "Bom dia, João" (Title 1) + linha com raio limão "14 furos desde ontem à noite".
- **Card de destaque** (limão, raio 28): selo "Primeiro no Brasil" + "há 4 min", título Title 2 escuro, avatares sobrepostos das fontes + "12 fontes · 2 min" e botão circular escuro com seta ↗.
- Dois cards lado a lado:
  - **Sua vantagem:** anel de progresso limão com raio no centro, "38 min" em Big Number e "à frente da imprensa BR, em média".
  - **Em alta hoje:** "#ransomware", gráfico de 7 barras arredondadas (a última em limão, as outras em `bg/control`) e "↗ 231 matérias".
- Seção "Últimas" com "Ver tudo" e lista de linhas de notícia, com scroll infinito e pull-to-refresh.

**06 Matéria**
- Nav: voltar à esquerda; salvar e compartilhar à direita (botões circulares).
- Imagem de 353×190 com raio 28.
- Pílula de categoria + selo. Título Title 1. Linha com check limão: "Confirmado por 12 fontes · detectado às 9:37".
- Card "Resumo em 3 pontos" com ícone de brilho limão e itens numerados em círculos com tint limão.
- Corpo em Body cinza.
- Barra flutuante inferior (pílula `bg/elevated`) com "Ouvir 2 min" (limão) e "Fonte original" (abre o link externo), com fade atrás.

**07 Explorar**
- Large Title "Explorar" e campo de busca (`bg/card`, raio 14, "Empresas, pessoas e tópicos").
- Grade 2×2 de cards de tópico: tile colorido, variação "+12%" na cor da categoria, nome e "48 hoje".
- "Em alta agora": card com ranking 1–3 (número Title 2; o 1º em limão), título, "12,4 mil lendo" e chevron.
- "Pessoas em destaque": avatares de 56 pt com nome (J. Huang, S. Altman, L. Su, D. Amodei, S. Nadella).

**08 Página de tópico**
- Nav com voltar e mais.
- Card de cabeçalho com gradiente escuro esverdeado: tile limão com ícone, botão "✓ Seguindo" em vidro, título "Inteligência Artificial", descrição e 3 mini-estatísticas ("48 hoje", "312 na semana", "6 furos").
- Chips de filtro por empresa (Tudo, OpenAI, Anthropic, Google, Meta) com scroll horizontal.
- Lista de notícias.

**09 Busca**
- Campo ativo com borda limão e texto digitado, mais "Cancelar" em limão. Chips "Tudo / Matérias / Tópicos / Pessoas".
- Card da entidade encontrada: logo, "Nvidia", "Empresa · 412 matérias · 3 furos hoje" e botão + limão para seguir.
- Resultados de "Matérias" com contagem.
- "Buscas recentes" com ícone de relógio (ou de tendência em limão para as populares), seta ↗ e "Limpar".

**10 Salvos**
- Large Title, chips "Ler depois / Ouvir / Lidos".
- Card-resumo com gradiente: "12 matérias", "38 min de leitura ou 24 min ouvindo" e botão "▶ Ouvir" limão, que gera uma playlist de áudio.
- Cards de matéria salva: categoria colorida, marcador limão, título e barra de progresso de leitura na cor da categoria + "2 min restantes".
- Deslizar para arquivar.

**11 Central de alertas**
- Voltar + "Marcar como lidos" em limão. Large Title "Alertas".
- Grupos "HOJE" e "ONTEM" em cards: tile colorido por tipo, título (Semibold se não lido), subtítulo ("Urgente · primeiro no Brasil"), horário e ponto colorido de não lido.

**12 Perfil e ajustes**
- Avatar de 60 pt, nome, "Leitor desde outubro de 2026" e botão mais.
- **Card da semana** (limão): "Sua semana", número Display "9" + "furos antes de todo mundo", pílula escura com chama "42 dias" (sequência) e gráfico de 7 barras escuras (S T Q Q S S D), com o dia atual sólido.
- Grupo "NOTIFICAÇÕES": Urgentes (on), Resumo 8h e 19h (on), Rumores não confirmados (off).
- Grupo "CONTA": Tópicos seguidos "6 >", Comunidade com pílula "Em breve".
- Cada linha tem tile de ícone colorido de 30 pt.

### Fora do app
**13 Tela bloqueada:** papel de parede escuro com brilhos limão e azul.
- **Widget circular:** anel limão com "14 furos".
- **Widget retangular:** "RADAR · 4 min / Nvidia sobe 4% após anúncio de fábrica".
- Notificações:
  - Urgente: "Urgente · Ataque hacker atinge banco" / "Dados de 2 milhões de clientes expostos. Primeiro no Brasil, 41 min antes da imprensa."
  - Comum: "Nvidia anuncia fábrica de US$ 12 bi".
- Pilha agrupada "+ 6 notificações do Radar".

**14 Live Activity** (eventos ao vivo, como keynotes):
- Card escuro com ícone do app, "Ao vivo · Keynote Nvidia" e pílula vermelha "● 23 min".
- Título "Huang revela a GPU Rubin Ultra", "3 anúncios até agora · tradução em tempo real".
- Barra de progresso limão do evento, "Início 9:00 / Fim ~10:30".
- Abaixo, linha do tempo dos últimos anúncios com horário em limão.

**15 Dynamic Island**
- **Compacta:** ícone do app à esquerda, "● Ao vivo" vermelho à direita.
- **Mínima:** só o ícone do app, quando divide espaço com outra atividade.
- **Expandida (notícia urgente):** ícone, pílula "Urgente", título, "2 milhões de clientes afetados · 4 fontes confirmam" e botões "Ler agora" (limão) e "Salvar".
- **Expandida (evento ao vivo):** ícone grande, "Keynote Nvidia · 23 min" vermelho e título.

**16 Widgets da tela inicial**
- **Pequeno (limão):** ícone, "há 4 min" e manchete do último furo.
- **Médio (`bg/card`):** "Radar" + "14 furos hoje" e 3 linhas, cada uma com barrinha colorida, horário e manchete.
- **Grande:** card limão de destaque "PRIMEIRO NO BRASIL · 4 MIN" + manchete, mais 2 notícias com categoria.

### Pop-ups e sheets
**17 Banner urgente + toast:**
- O banner aparece sobre qualquer tela quando chega uma notícia urgente com o app aberto. Toque abre a matéria; arrastar para cima dispensa.
- O toast "Salvo pra ler depois · Desfazer" aparece ao salvar e some em 3 s.

**18 Compartilhar (sheet)**
- "Compartilhar furo" e card de imagem pronto: gradiente limão, logo Radar, selo, manchete e "Soube 38 min antes da imprensa brasileira".
- Atalhos: WhatsApp, Stories, X, LinkedIn, Copiar link.
- Botão "Compartilhar imagem". O card é exportado como PNG em 1080×1920 para Stories.

**19 Teaser da comunidade (sheet)**
- Avatares sobrepostos, pílula "Em breve", título "Comunidade Radar" e "Debata os furos com quem vive de tecnologia. Entre na lista e ganhe acesso antecipado."
- Benefícios: discussões por tópico, selo de fundador para os primeiros 1.000, aviso quando abrir.
- "Entrar na lista" / "Agora não". Mostrar no máximo uma vez a cada 14 dias.

**20 Pedido de avaliação**
- Alerta central: ícone do app, "Curtindo o Radar?" e "Você soube de 9 furos antes de todo mundo esta semana. Conta pra gente na App Store?"
- 5 estrelas limão, "Avaliar" e "Agora não". Use `SKStoreReviewController` depois de um momento positivo.

---

## 5. Comportamentos e estados
- **Tempo relativo** em pt-BR: "agora", "há 4 min", "há 1 h", "ontem às 21:14".
- **Feed:** pull-to-refresh, paginação infinita, skeleton com shimmer escuro (`bg/card` → `bg/elevated`) no carregamento. Novas notícias geram a pílula flutuante "↑ 3 novas" no topo.
- **Estados vazios:** convite e não pedido de desculpas (ex.: Salvos vazio = "Salve matérias pra ler ou ouvir depois").
- **Erros:** diga o que houve e o que fazer ("Sem conexão. Mostrando as últimas notícias salvas.").
- **Offline:** cache das últimas 50 matérias e dos salvos.
- **Haptics:** leve ao salvar, seguir e trocar de aba; notificação de sucesso ao concluir o onboarding.
- **Animações:** spring padrão do iOS. Card de destaque com leve escala ao tocar (0,98). Tab ativa com transição da pílula entre abas.
- **Deep links:** `radar://materia/{id}`, `radar://topico/{slug}`, `radar://alertas`. Notificações, widgets e Live Activity abrem direto na matéria.
- **Analytics** (nomes sugeridos): `onboarding_topics_selected`, `alert_level_selected`, `push_permission_result`, `article_opened {source: feed|push|widget|live}`, `article_listened`, `article_shared`, `community_waitlist_joined`.

---

## 6. Modelo de dados (contrato com o backend)
```ts
type Category = "ia" | "seguranca" | "bigtech" | "programacao" | "chips" | "startups"
  | "gadgets" | "games" | "regulacao" | "cripto" | "tech-br" | "espaco";

interface Article {
  id: string;
  title: string;            // já em pt-BR
  summary: [string, string, string]; // resumo da IA em 3 pontos
  body: string;
  category: Category;
  imageUrl?: string;
  detectedAt: string;       // ISO: quando a IA detectou
  publishedAt: string;      // ISO: quando o Radar publicou
  sources: { name: string; url: string; logoUrl?: string }[];
  sourceCount: number;
  firstInBrazil: boolean;
  leadMinutes?: number;     // minutos de vantagem sobre a imprensa BR
  urgency: "normal" | "important" | "urgent";
  confirmed: boolean;       // false = rumor (escondido por padrão)
  readingMinutes: number;
  audioUrl?: string;
  audioMinutes?: number;
  entities: { type: "company" | "person"; id: string; name: string }[];
  trendingTag?: string;
}

interface LiveEvent { id: string; title: string; startsAt: string; endsAt: string;
  updates: { at: string; text: string }[]; }

interface UserPrefs { topics: Category[]; alertLevel: "urgent" | "balanced" | "realtime";
  digestTimes: string[]; quietHours?: { from: string; to: string };
  showRumors: boolean; followedEntities: string[]; }

interface WeeklyStats { scoops: number; streakDays: number; avgLeadMinutes: number;
  perDay: number[]; } // 7 valores, seg→dom
```

---

## 7. Fora do escopo do MVP
- Comunidade (só teaser e lista de espera), comentários, login social além de Apple/Google, tema claro, iPad e Android nativo (só se a stack escolhida já cobrir).

**Entregue:** as 20 telas acima com componentes reutilizáveis, tokens centralizados (cores, tipografia e medidas num único arquivo de tema), dados mockados realistas em pt-BR iguais aos exemplos deste documento, e navegação completa entre as telas.
