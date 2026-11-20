import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'models.dart';

/// Dados mockados em pt-BR iguais aos exemplos do design.
/// Os horários são relativos ao momento em que o app abre.

DateTime _ago(int minutes) => DateTime.now().subtract(Duration(minutes: minutes));

DateTime _todayAt(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

DateTime _yesterdayAt(int h, int m) => _todayAt(h, m).subtract(const Duration(days: 1));

// Fontes
const _reuters = Source('Reuters', 'https://www.reuters.com', RColors.orange);
const _bloomberg = Source('Bloomberg', 'https://www.bloomberg.com', RColors.link);
const _valor = Source('Valor', 'https://valor.globo.com', RColors.purple);
const _nikkei = Source('Nikkei Asia', 'https://asia.nikkei.com', Color(0xFFB71C1C));
const _cnbc = Source('CNBC', 'https://www.cnbc.com', Color(0xFF005594));
const _verge = Source('The Verge', 'https://www.theverge.com', Color(0xFF5200FF));
const _wired = Source('Wired', 'https://www.wired.com', RColors.bgControl);
const _techcrunch = Source('TechCrunch', 'https://techcrunch.com', Color(0xFF0A9E01));
const _g1 = Source('g1', 'https://g1.globo.com', Color(0xFFC4170C));
const _folha = Source('Folha', 'https://www.folha.uol.com.br', Color(0xFF1A4F8B));
const _estadao = Source('Estadão', 'https://www.estadao.com.br', Color(0xFF26323C));
const _bleeping = Source('BleepingComputer', 'https://www.bleepingcomputer.com', Color(0xFF2B6CB0));
const _ars = Source('Ars Technica', 'https://arstechnica.com', Color(0xFFFF4E00));
const _msblog = Source('Blog da Microsoft', 'https://blogs.microsoft.com', Color(0xFF00A4EF));
const _ghblog = Source('Blog do GitHub', 'https://github.blog', Color(0xFF6E40C9));
const _nineToFive = Source('9to5Mac', 'https://9to5mac.com', Color(0xFF4A4A4A));

// Entidades
const _nvidia = Entity('company', 'nvidia', 'Nvidia');
const _openai = Entity('company', 'openai', 'OpenAI');
const _anthropic = Entity('company', 'anthropic', 'Anthropic');
const _google = Entity('company', 'google', 'Google');
const _meta = Entity('company', 'meta', 'Meta');
const _microsoft = Entity('company', 'microsoft', 'Microsoft');
const _apple = Entity('company', 'apple', 'Apple');
const _huang = Entity('person', 'jensen-huang', 'Jensen Huang');

List<Article> buildMockArticles() => [
      Article(
        id: 'nvidia-fabrica',
        title: 'Jensen Huang confirma nova fábrica da Nvidia na Ásia',
        category: NewsCategory.chips,
        publishedAt: _ago(4),
        detectedAt: _ago(6),
        sources: const [_reuters, _bloomberg, _valor, _nikkei, _cnbc, _verge],
        sourceCount: 12,
        firstInBrazil: true,
        leadMinutes: 38,
        urgency: Urgency.important,
        readingMinutes: 2,
        audioMinutes: 2,
        audioUrl: 'https://radar.app/audio/nvidia-fabrica.m4a',
        entities: const [_nvidia, _huang],
        trendingTag: 'nvidia',
        summary: const [
          'Investimento de US\$ 12 bilhões em Taiwan e Japão',
          'Produção das novas GPUs começa em 2028',
          'Ações sobem 4% no pré-mercado após o anúncio',
        ],
        body: 'O CEO da Nvidia anunciou nesta quinta-feira, em Taipé, a construção de uma nova fábrica dedicada a GPUs '
            'para data centers. O investimento soma US\$ 12 bilhões e será dividido entre Taiwan e Japão.\n\n'
            'Segundo Jensen Huang, a capacidade extra responde à demanda por chips de IA, que segue maior que a oferta. '
            'A produção deve começar em 2028, em parceria com a TSMC.\n\n'
            'O mercado reagiu rápido: as ações subiram 4% no pré-mercado americano. Analistas veem o movimento como '
            'uma forma de reduzir a dependência de um único polo de produção.',
      ),
      Article(
        id: 'banco-ataque',
        title: 'Ataque hacker expõe dados de banco brasileiro',
        category: NewsCategory.seguranca,
        publishedAt: _ago(12),
        detectedAt: _ago(15),
        sources: const [_g1, _reuters, _bleeping, _folha],
        sourceCount: 6,
        firstInBrazil: true,
        leadMinutes: 41,
        urgency: Urgency.urgent,
        readingMinutes: 3,
        audioMinutes: 2,
        audioUrl: 'https://radar.app/audio/banco-ataque.m4a',
        trendingTag: 'ransomware',
        summary: const [
          'Dados de 2 milhões de clientes foram expostos',
          'O grupo por trás do ataque usa ransomware e pede resgate',
          'O banco diz que senhas e saldos não foram afetados',
        ],
        body: 'Um banco digital brasileiro confirmou nesta manhã um ataque que expôs nome, CPF e e-mail de cerca de '
            '2 milhões de clientes. O grupo responsável publicou uma amostra dos dados num fórum e pede resgate.\n\n'
            'Em nota, o banco afirma que senhas, saldos e dados de cartão não foram acessados. A orientação é '
            'desconfiar de contatos pedindo códigos ou transferências.\n\n'
            'A ANPD foi notificada. É o terceiro ataque com ransomware a uma instituição financeira no país este ano.',
      ),
      Article(
        id: 'modelo-benchmark',
        title: 'Novo modelo bate recorde em benchmark de código',
        category: NewsCategory.ia,
        publishedAt: _ago(8),
        detectedAt: _ago(10),
        sources: const [_verge, _wired, _techcrunch],
        sourceCount: 8,
        readingMinutes: 3,
        audioMinutes: 2,
        audioUrl: 'https://radar.app/audio/modelo-benchmark.m4a',
        summary: const [
          'O modelo resolveu 78% das tarefas do benchmark',
          'O recorde anterior era de 71%, de três meses atrás',
          'Acesso começa pela API, com preço por token menor',
        ],
        body: 'Um novo modelo de linguagem superou o recorde do principal benchmark de programação, resolvendo 78% '
            'das tarefas reais de repositórios open source.\n\n'
            'A empresa diz que o ganho veio de treino com execução de testes. O acesso começa pela API.',
      ),
      Article(
        id: 'marco-ia',
        title: 'Senado vota marco legal da IA na próxima semana',
        category: NewsCategory.regulacao,
        publishedAt: _ago(31),
        detectedAt: _ago(35),
        sources: const [_folha, _estadao, _g1],
        sourceCount: 5,
        urgency: Urgency.important,
        readingMinutes: 4,
        audioMinutes: 3,
        audioUrl: 'https://radar.app/audio/marco-ia.m4a',
        entities: const [],
        summary: const [
          'Votação está marcada pra terça-feira no plenário',
          'Texto classifica sistemas de IA por nível de risco',
          'Big techs pedem mais prazo pra se adequar',
        ],
        body: 'O presidente do Senado marcou pra próxima terça-feira a votação do marco legal da inteligência '
            'artificial. O texto classifica sistemas por nível de risco e cria regras de transparência.\n\n'
            'Empresas de tecnologia pedem mais prazo de adequação. Entidades de defesa do consumidor apoiam o texto atual.',
      ),
      Article(
        id: 'agentes-office',
        title: 'Agentes autônomos chegam ao Office',
        category: NewsCategory.ia,
        publishedAt: _ago(60),
        detectedAt: _ago(64),
        sources: const [_verge, _msblog],
        sourceCount: 6,
        readingMinutes: 3,
        audioMinutes: 2,
        audioUrl: 'https://radar.app/audio/agentes-office.m4a',
        entities: const [_microsoft],
        summary: const [
          'Agentes podem montar planilhas e apresentações sozinhos',
          'Recurso chega primeiro pra empresas, em inglês',
          'Versão em português está prevista pro começo do ano',
        ],
        body: 'A Microsoft liberou agentes que executam tarefas de várias etapas no Word, Excel e PowerPoint.\n\n'
            'O recurso chega primeiro pra clientes corporativos. A versão em português está prevista pro começo do ano.',
      ),
      Article(
        id: 'nvidia-valiosa',
        title: 'Nvidia volta a ser a empresa mais valiosa do mundo',
        category: NewsCategory.bigtech,
        kicker: 'Mercado',
        publishedAt: _ago(120),
        detectedAt: _ago(124),
        sources: const [_valor, _cnbc, _bloomberg],
        sourceCount: 7,
        readingMinutes: 2,
        audioMinutes: 2,
        entities: const [_nvidia],
        summary: const [
          'Valor de mercado passou de US\$ 5 trilhões',
          'Alta foi puxada pelo anúncio da nova fábrica',
          'Apple e Microsoft vêm logo atrás',
        ],
        body: 'Com a alta desta quinta, a Nvidia voltou ao topo do ranking de empresas mais valiosas do mundo.\n\n'
            'O movimento foi puxado pelo anúncio da fábrica na Ásia e por previsões de demanda por chips de IA.',
      ),
      Article(
        id: 'nvidia-acoes',
        title: 'Nvidia sobe 4% após anúncio de fábrica',
        category: NewsCategory.bigtech,
        kicker: 'Mercado',
        publishedAt: _ago(3),
        detectedAt: _ago(4),
        sources: const [_cnbc, _bloomberg],
        sourceCount: 5,
        readingMinutes: 1,
        entities: const [_nvidia],
        summary: const [
          'Ações sobem 4% no pré-mercado',
          'Investidores reagem à fábrica de US\$ 12 bi',
          'Fornecedores asiáticos também sobem',
        ],
        body: 'As ações da Nvidia sobem 4% no pré-mercado depois do anúncio da nova fábrica.\n\n'
            'Fornecedores da cadeia de semicondutores na Ásia acompanham a alta.',
      ),
      Article(
        id: 'rust-windows',
        title: 'Rust chega ao kernel do Windows e muda o jogo pra drivers',
        category: NewsCategory.programacao,
        publishedAt: _ago(140),
        detectedAt: _ago(150),
        sources: const [_ars, _msblog, _verge],
        sourceCount: 9,
        firstInBrazil: true,
        leadMinutes: 25,
        readingMinutes: 6,
        audioMinutes: 4,
        audioUrl: 'https://radar.app/audio/rust-windows.m4a',
        entities: const [_microsoft],
        summary: const [
          'Novos drivers poderão ser escritos em Rust',
          'Objetivo é reduzir falhas de memória no kernel',
          'Ferramentas chegam aos desenvolvedores em 2027',
        ],
        body: 'A Microsoft confirmou que o kernel do Windows vai aceitar drivers escritos em Rust.\n\n'
            'A empresa diz que cerca de 70% das falhas graves de segurança vêm de erros de memória, que a linguagem evita.',
      ),
      Article(
        id: 'openai-modelo',
        title: 'OpenAI lança novo modelo de raciocínio',
        category: NewsCategory.ia,
        publishedAt: _ago(150),
        detectedAt: _ago(156),
        sources: const [_verge, _techcrunch, _wired],
        sourceCount: 14,
        firstInBrazil: true,
        leadMinutes: 22,
        urgency: Urgency.important,
        readingMinutes: 3,
        audioMinutes: 2,
        entities: const [_openai],
        summary: const [
          'Disponível hoje na API e no app',
          'Modelo pensa mais antes de responder',
          'Preço por token caiu pela metade',
        ],
        body: 'A OpenAI lançou um novo modelo de raciocínio, disponível hoje na API e no app.\n\n'
            'Segundo a empresa, ele resolve problemas de matemática e código com menos erros e custa metade do anterior.',
      ),
      Article(
        id: 'anthropic-sp',
        title: 'Anthropic abre escritório em São Paulo e contrata engenheiros',
        category: NewsCategory.ia,
        publishedAt: _ago(260),
        detectedAt: _ago(270),
        sources: const [_valor, _techcrunch],
        sourceCount: 4,
        firstInBrazil: true,
        leadMinutes: 31,
        readingMinutes: 3,
        audioMinutes: 2,
        entities: const [_anthropic],
        summary: const [
          'Escritório é o primeiro da empresa na América Latina',
          'Vagas são pra engenharia e atendimento a empresas',
          'Clientes brasileiros cresceram no último ano',
        ],
        body: 'A Anthropic vai abrir um escritório em São Paulo, o primeiro da empresa na América Latina.\n\n'
            'As vagas iniciais são de engenharia e atendimento a clientes corporativos.',
      ),
      Article(
        id: 'google-agentes',
        title: 'Google testa busca com agentes de IA no Brasil',
        category: NewsCategory.ia,
        publishedAt: _ago(380),
        detectedAt: _ago(384),
        sources: const [_g1, _verge],
        sourceCount: 5,
        readingMinutes: 2,
        entities: const [_google],
        summary: const [
          'Teste começa com uma parte dos usuários',
          'Agentes fazem reservas e comparam preços',
          'Função chega em português desde o início',
        ],
        body: 'O Google começou a testar no Brasil uma busca em que agentes de IA executam tarefas, como reservas.\n\n'
            'O recurso chega em português desde o início, pra uma parte dos usuários.',
      ),
      Article(
        id: 'meta-oculos',
        title: 'Meta lança óculos com tradução simultânea em português',
        category: NewsCategory.ia,
        publishedAt: _ago(600),
        detectedAt: _ago(606),
        sources: const [_verge, _techcrunch],
        sourceCount: 6,
        readingMinutes: 3,
        entities: const [_meta],
        summary: const [
          'Tradução aparece em legenda na lente',
          'Português está entre os primeiros idiomas',
          'Preço no Brasil ainda não foi divulgado',
        ],
        body: 'A Meta apresentou óculos que traduzem conversas em tempo real, com legenda na lente.\n\n'
            'O português está entre os primeiros idiomas. O preço no Brasil ainda não foi divulgado.',
      ),
      Article(
        id: 'startup-paulista',
        title: 'Startup paulista capta R\$ 80 mi',
        category: NewsCategory.startups,
        publishedAt: _ago(200),
        detectedAt: _ago(204),
        sources: const [_valor, _estadao],
        sourceCount: 3,
        readingMinutes: 2,
        summary: const [
          'Rodada série B liderada por fundo americano',
          'Empresa usa IA pra prever estoque de pequenos varejistas',
          'Plano é chegar a 20 mil lojas até 2027',
        ],
        body: 'Uma startup paulista que usa IA pra prever estoque de pequenos varejistas captou R\$ 80 milhões.\n\n'
            'O dinheiro vai pra contratação e expansão pra outros estados.',
      ),
      Article(
        id: 'npm-ataque',
        title: 'Como o ataque à cadeia de pacotes do npm aconteceu',
        category: NewsCategory.seguranca,
        publishedAt: _ago(330),
        detectedAt: _ago(340),
        sources: const [_bleeping, _ghblog, _ars],
        sourceCount: 6,
        readingMinutes: 7,
        audioMinutes: 5,
        audioUrl: 'https://radar.app/audio/npm-ataque.m4a',
        summary: const [
          'Conta de um mantenedor foi invadida por phishing',
          'Versões maliciosas ficaram no ar por duas horas',
          'Projetos devem travar versões e revisar dependências',
        ],
        body: 'Invasores tomaram a conta de um mantenedor popular do npm e publicaram versões com código malicioso.\n\n'
            'As versões ficaram no ar por cerca de duas horas. A recomendação é travar versões e revisar o lockfile.',
      ),
      Article(
        id: 'agentes-computador',
        title: 'O que muda quando agentes passam a usar o computador por você',
        category: NewsCategory.ia,
        publishedAt: _ago(480),
        detectedAt: _ago(490),
        sources: const [_wired, _verge],
        sourceCount: 4,
        readingMinutes: 5,
        audioMinutes: 4,
        audioUrl: 'https://radar.app/audio/agentes-computador.m4a',
        summary: const [
          'Agentes já clicam, digitam e navegam sozinhos',
          'Riscos de segurança crescem com o acesso',
          'Empresas criam regras de permissão por tarefa',
        ],
        body: 'Agentes de IA que operam o computador saíram do laboratório e chegaram a produtos comerciais.\n\n'
            'Com mais acesso vêm mais riscos. As empresas apostam em permissões por tarefa e confirmação humana.',
      ),
      Article(
        id: 'github-fora',
        title: 'GitHub ficou fora do ar por 40 min',
        category: NewsCategory.programacao,
        publishedAt: _yesterdayAt(21, 14),
        detectedAt: _yesterdayAt(21, 10),
        sources: const [_ghblog, _verge],
        sourceCount: 3,
        readingMinutes: 1,
        entities: const [_microsoft],
        summary: const [
          'Falha atingiu pushes, pull requests e Actions',
          'Causa foi uma mudança de configuração no banco',
          'Serviço está normalizado',
        ],
        body: 'O GitHub ficou fora do ar por cerca de 40 minutos. A causa foi uma mudança de configuração no banco de dados.\n\n'
            'O serviço está normalizado.',
      ),
      Article(
        id: 'chrome-falha',
        title: 'Falha crítica no Chrome: atualize já',
        category: NewsCategory.seguranca,
        publishedAt: _yesterdayAt(16, 2),
        detectedAt: _yesterdayAt(15, 55),
        sources: const [_bleeping, _g1],
        sourceCount: 4,
        urgency: Urgency.urgent,
        firstInBrazil: true,
        leadMinutes: 19,
        readingMinutes: 2,
        entities: const [_google],
        summary: const [
          'Falha já está sendo explorada por atacantes',
          'Correção saiu na versão mais recente',
          'Reinicie o navegador pra aplicar',
        ],
        body: 'O Google corrigiu uma falha crítica no Chrome que já estava sendo explorada.\n\n'
            'Pra se proteger, atualize o navegador e reinicie.',
      ),
      Article(
        id: 'rumor-apple',
        title: 'Apple estaria testando iPhone dobrável com tela de 7,8 polegadas',
        category: NewsCategory.gadgets,
        publishedAt: _ago(90),
        detectedAt: _ago(92),
        sources: const [_nineToFive],
        sourceCount: 1,
        confirmed: false,
        readingMinutes: 2,
        entities: const [_apple],
        summary: const [
          'Informação vem de uma única fonte da cadeia de produção',
          'Apple não comenta',
          'Lançamento seria em 2027',
        ],
        body: 'Um relatório da cadeia de produção diz que a Apple testa um iPhone dobrável. A empresa não comenta.\n\n'
            'Só uma fonte confirma até agora.',
      ),
    ];

/// Notícias que chegam enquanto o app está aberto (pílula "↑ 3 novas").
List<Article> buildNewArrivals(int seed) => [
      Article(
        id: 'novo-$seed-1',
        title: 'Falha em roteadores expõe 300 mil redes no Brasil',
        category: NewsCategory.seguranca,
        publishedAt: _ago(0),
        detectedAt: _ago(2),
        sources: const [_bleeping, _g1],
        sourceCount: 4,
        firstInBrazil: true,
        leadMinutes: 27,
        urgency: Urgency.important,
        readingMinutes: 2,
        summary: const ['Modelo popular de roteador tem senha padrão exposta', 'Fabricante liberou atualização', 'Troque a senha do painel'],
        body: 'Uma falha em um modelo popular de roteador expõe cerca de 300 mil redes no país.\n\nO fabricante já liberou atualização.',
      ),
      Article(
        id: 'novo-$seed-2',
        title: 'Google libera novo modelo Gemini pra desenvolvedores',
        category: NewsCategory.ia,
        publishedAt: _ago(1),
        detectedAt: _ago(3),
        sources: const [_verge, _techcrunch],
        sourceCount: 6,
        readingMinutes: 2,
        entities: const [_google],
        summary: const ['Disponível na API a partir de hoje', 'Janela de contexto maior', 'Preço igual ao da versão anterior'],
        body: 'O Google liberou um novo modelo Gemini pra desenvolvedores.\n\nA janela de contexto cresceu e o preço não mudou.',
      ),
      Article(
        id: 'novo-$seed-3',
        title: 'Apple confirma evento de lançamento pra próxima semana',
        category: NewsCategory.gadgets,
        publishedAt: _ago(2),
        detectedAt: _ago(4),
        sources: const [_nineToFive, _verge],
        sourceCount: 5,
        readingMinutes: 1,
        entities: const [_apple],
        summary: const ['Convite saiu agora há pouco', 'Novos Macs são esperados', 'Transmissão será on-line'],
        body: 'A Apple enviou convites pra um evento de lançamento na próxima semana.\n\nNovos Macs são esperados.',
      ),
    ];

List<AlertItem> buildMockAlerts() {
  final now = DateTime.now();
  final morning = now.hour >= 8 ? _todayAt(8, 0) : _ago(30);
  return [
    AlertItem(
      id: 'al-1',
      title: 'Ataque hacker atinge banco digital',
      subtitle: 'Urgente · primeiro no Brasil',
      at: _ago(12),
      icon: Icons.notification_important_outlined,
      color: RColors.urgent,
      unread: true,
      articleId: 'banco-ataque',
    ),
    AlertItem(
      id: 'al-2',
      title: 'Nvidia anuncia fábrica de US\$ 12 bi',
      subtitle: 'Chips · 12 fontes',
      at: _ago(27),
      icon: Icons.bolt,
      color: RColors.radar,
      unread: true,
      articleId: 'nvidia-fabrica',
    ),
    AlertItem(
      id: 'al-3',
      title: 'Resumo da manhã: 8 notícias',
      subtitle: 'Seu resumo diário',
      at: morning,
      icon: Icons.auto_awesome,
      color: RColors.link,
    ),
    AlertItem(
      id: 'al-4',
      title: 'GitHub ficou fora do ar por 40 min',
      subtitle: 'Programação · resolvido',
      at: _yesterdayAt(21, 14),
      icon: Icons.code,
      color: RColors.purple,
      articleId: 'github-fora',
    ),
    AlertItem(
      id: 'al-5',
      title: 'Falha crítica no Chrome: atualize já',
      subtitle: 'Segurança · patch disponível',
      at: _yesterdayAt(16, 2),
      icon: Icons.shield_outlined,
      color: RColors.orange,
      articleId: 'chrome-falha',
    ),
  ];
}

const mockEntities = [
  EntityInfo(id: 'nvidia', name: 'Nvidia', kind: 'Empresa', color: Color(0xFF76B900), articleCount: 412, scoopsToday: 3),
  EntityInfo(id: 'openai', name: 'OpenAI', kind: 'Empresa', color: Color(0xFF10A37F), articleCount: 388, scoopsToday: 2),
  EntityInfo(id: 'anthropic', name: 'Anthropic', kind: 'Empresa', color: Color(0xFFD97757), articleCount: 164, scoopsToday: 1),
  EntityInfo(id: 'google', name: 'Google', kind: 'Empresa', color: Color(0xFF4285F4), articleCount: 520, scoopsToday: 1),
  EntityInfo(id: 'meta', name: 'Meta', kind: 'Empresa', color: Color(0xFF0866FF), articleCount: 297, scoopsToday: 0),
  EntityInfo(id: 'microsoft', name: 'Microsoft', kind: 'Empresa', color: Color(0xFF00A4EF), articleCount: 341, scoopsToday: 1),
  EntityInfo(id: 'apple', name: 'Apple', kind: 'Empresa', color: Color(0xFF8E8E93), articleCount: 455, scoopsToday: 0),
  EntityInfo(id: 'jensen-huang', name: 'Jensen Huang', kind: 'Pessoa', color: RColors.link, articleCount: 96, scoopsToday: 1),
  EntityInfo(id: 'sam-altman', name: 'Sam Altman', kind: 'Pessoa', color: RColors.purple, articleCount: 120, scoopsToday: 0),
];

const mockPeople = [
  Person('JH', 'J. Huang', 'Jensen Huang', RColors.link),
  Person('SA', 'S. Altman', 'Sam Altman', RColors.purple),
  Person('LS', 'L. Su', 'Lisa Su', RColors.urgent),
  Person('DA', 'D. Amodei', 'Dario Amodei', RColors.orange),
  Person('SN', 'S. Nadella', 'Satya Nadella', Color(0xFF30B0C7)),
];

const mockTopicStats = [
  TopicStat(NewsCategory.ia, '+12%', 48),
  TopicStat(NewsCategory.seguranca, '+31%', 22),
  TopicStat(NewsCategory.programacao, '+4%', 31),
  TopicStat(NewsCategory.chips, '+18%', 9),
];

const mockTrending = [
  TrendingItem('nvidia-fabrica', 'Nvidia constrói fábrica na Ásia', '12,4 mil lendo'),
  TrendingItem('banco-ataque', 'Vazamento no banco digital', '9,8 mil lendo'),
  TrendingItem('rust-windows', 'Rust no kernel do Windows', '5,1 mil lendo'),
];

const mockRecentSearches = [
  RecentSearch('nvidia blackwell'),
  RecentSearch('resultados q3 nvidia'),
  RecentSearch('fábrica nvidia ásia', trending: true),
];

/// Salvos iniciais do mock (aba Salvos com conteúdo na primeira abertura).
const mockSavedIds = ['rust-windows', 'npm-ataque', 'agentes-computador', 'marco-ia', 'openai-modelo', 'anthropic-sp'];
const mockReadProgress = {'rust-windows': 0.55, 'npm-ataque': 0.08, 'marco-ia': 0.3};

const mockWeek =WeeklyStats(scoops: 9, streakDays: 42, avgLeadMinutes: 38, perDay: [1, 2, 1, 2, 1, 0, 2]);

LiveEvent buildMockLiveEvent() => LiveEvent(
      id: 'keynote-nvidia',
      title: 'Keynote Nvidia',
      headline: 'Huang revela a GPU Rubin Ultra',
      startsAt: _todayAt(9, 0),
      endsAt: _todayAt(10, 30),
      updates: [
        LiveUpdate(_todayAt(9, 31), 'Rubin Ultra: 2x mais rápida que Blackwell'),
        LiveUpdate(_todayAt(9, 18), 'Parceria com TSMC pra fábrica no Japão'),
      ],
    );

/// Empresas pra os chips de filtro da página de tópico.
const companiesByCategory = <NewsCategory, List<String>>{
  NewsCategory.ia: ['OpenAI', 'Anthropic', 'Google', 'Meta'],
  NewsCategory.seguranca: ['Google', 'Microsoft'],
  NewsCategory.chips: ['Nvidia'],
  NewsCategory.bigtech: ['Nvidia', 'Apple', 'Microsoft'],
  NewsCategory.programacao: ['Microsoft'],
};
