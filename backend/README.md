# news.dev API · Supabase

Backend Java 21 / Spring Boot 3.5, Spring Security, JDBC/PostgreSQL e Flyway.

- Contas com email/senha BCrypt, JWT e refresh rotativo, logout e revogação.
- Senha mínima de 8 caracteres e recuperação SMTP com token de uso único.
- Google via Supabase Auth, validado no servidor; vínculos explícitos entre contas.
- Feed com filtros, paginação por cursor, busca e conteúdo editorial/RSS.
- Preferências, salvos, progresso, estatísticas, alertas e outbox transacional.
- Schema privado com RLS, índices SQL versionados e pool de conexões.

Configure `backend/.env` usando `.env.example`. A configuração Firebase antiga foi
preservada em backup local apenas para exportar dados. O aplicativo não contém
credenciais PostgreSQL.

**[Configuração e migração completas](docs/SUPABASE.md)**

```powershell
mvn -f backend/pom.xml -DskipTests package
.\backend\scripts\start-local.ps1 -UseJar
```

Saúde: `/actuator/health`. Swagger: `/swagger-ui/index.html` quando
`API_DOCS_ENABLED=true`. Contrato: [API](../radar/docs/API.md).

Para Docker, `backend/compose.yaml` recebe a conexão Supabase pelo `.env`, sem
volumes de credenciais Google. `scripts/deploy-cloud-run.ps1` permite hospedar a
API em Cloud Run com banco Supabase; segredos ficam no Secret Manager.

Testes de integração usam PostgreSQL local `fionova_test`, nunca a base real.
Veja `docs/VALIDATION.md` para resultados e limites das verificações.

## Discloud

Na raiz do projeto, gere o ZIP do backend com:

```powershell
.\backend\scripts\package-discloud.ps1 -Subdomain appnewsai
```

O ZIP fica em `artifacts/discloud`. Para incluir o `backend/.env` já configurado,
use `-IncludeLocalEnv` e envie o ZIP privado apenas pelo painel da Discloud.
O app precisa de Java 21 ou superior. No painel, copie a URL HTTPS atribuída
e confirme `status: UP` em `/actuator/health`.

Use a URL exibida no painel para compilar o APK:

```powershell
.\radar\scripts\build-mobile-apks.ps1 -Mode hosted -ApiUrl 'https://appnewsai.discloud.app' -SupabaseConfigPath '.\radar\supabase.client.json'
```

Se a URL atribuída terminar em `.discloud.dev`, use esse domínio no comando.

## Coleta de notícias de tecnologia

Na Discloud e no ambiente local, defina `INGESTION_ENABLED=true` e
`TECH_FEEDS_ENABLED=true` no arquivo `.env`.
A coleta roda na inicialização e depois a cada 15 minutos por padrão
(`INGESTION_DELAY_MS`), com até 25 novos itens por fonte por ciclo.
Os itens recentes são agrupados pelas categorias do aplicativo e deduplicados
pela URL canônica. O catálogo publica manchetes com atribuição, link original
e uma descrição curta quando fornecida pelo feed.

O coletor automático usa os RSS do g1, da CNN Brasil e da Agência Brasil
(EBC). Feed, destaques e busca exibem matérias cuja fonte principal pertence
à lista de emissoras brasileiras. O filtro também vale para matérias já
importadas.

Fontes cadastradas pelo endpoint de administração continuam usando
`RSS_ALLOWED_HOSTS` e o fluxo de revisão editorial.

### Leitura e idiomas

O leitor mostra o texto completo quando existe um corpo editorial ou um feed
autorizado fornece o conteúdo integral. Para um feed com permissão de
republicação, habilite `allowFullText` ao cadastrar a fonte. O coletor usa o
conteúdo publicado no próprio RSS e mantém a atribuição à fonte. Quando o item
ainda estiver no feed, uma nova coleta preenche o corpo de matérias importadas
anteriormente que só tinham sinopse. Matérias sem texto integral disponibilizado
continuam exibindo a sinopse e as fontes.

Os comentários ficam vinculados à matéria e à conta que os publicou. Em bancos
gerenciados pelo Flyway, a tabela é criada na inicialização da API. Para bancos
configurados manualmente pelo SQL Editor, reaplique `supabase/schema.sql`.

A tradução de matérias usa a API do Gemini. Configure `GEMINI_API_KEY` no
ambiente da API. Para trocar o modelo, defina `GEMINI_TRANSLATION_MODEL`. O app guarda a preferência localmente em Perfil.
