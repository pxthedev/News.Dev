# Supabase: conexão, migração e Google

O backend continua Java 21 + Spring Boot/Security. A persistência agora usa JDBC,
PostgreSQL, Hikari e migrações Flyway. Os dados ficam em tabelas do schema privado
`fionova`, com chave primária, JSONB, índices B-tree/GIN e transações SERIALIZABLE
com repetição limitada em conflitos. Feed, busca, filtros, contagem e paginação são
executados no banco. Não é necessário criar índices manualmente pelo painel.

## 1. Conectar o banco

Crie um projeto Supabase e abra **Connect → Session pooler** (compatível com IPv4).
Copie o host, porta e usuário exatamente como aparecem no painel. Em `backend/.env`:

```dotenv
SUPABASE_DB_URL=jdbc:postgresql://SEU_HOST:5432/postgres?sslmode=require
SUPABASE_DB_USER=postgres.SEU_PROJECT_REF
SUPABASE_DB_PASSWORD=SUA_SENHA_DO_BANCO
DB_POOL_SIZE=5
DB_MIGRATIONS_ENABLED=true
SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL
```

O JWT_SECRET local existente foi preservado; mantenha seu valor.
A senha é a do banco PostgreSQL, não a chave publicável nem `service_role`.
A conexão Direct também funciona quando há IPv6. Evite o transaction pooler
nessa configuração: use Session ou Direct para Flyway/JDBC. URL e senha ficam
separadas, portanto caracteres especiais da senha não precisam entrar na URL.

A primeira inicialização aplica `src/main/resources/db/migration/V1__supabase_postgres.sql`.
Alternativamente, aplique o arquivo equivalente `supabase/migrations/20261117000100_fionova.sql`
no SQL Editor/Supabase CLI e defina `DB_MIGRATIONS_ENABLED=false`. **Escolha um método**:
não execute as duas versões da mesma migração. Se usar Flyway, futuras migrações
devem continuar nesse fluxo, preservando o histórico e checksums.

O schema tem RLS habilitada e acesso revogado para `public`, `anon` e `authenticated`.
Ele não deve ser incluído nos schemas expostos pela Data API. O backend usa a
conexão PostgreSQL autorizada; o aplicativo recebe apenas a URL e a chave pública.
Não coloque senha do banco, chave secreta ou `service_role` no Flutter.

Iniciar, a partir da raiz do projeto:

```powershell
.\backend\scripts\start-local.ps1 -UseJar
```

O script valida as variáveis e reconstrói JAR ausente/inválido. Para recompilar
alterações posteriores, encerre a instância anterior e rode `mvn -f backend/pom.xml -DskipTests package`.
A saúde `/actuator/health` agora inclui uma consulta PostgreSQL de conectividade.

## 2. Migrar dados existentes

O arquivo `.env.firebase.backup`, ignorado pelo Git, preserva a configuração antiga
apenas para exportação. A conta de serviço permanece fora do repositório.
O exportador lê Firestore sem modificar ou excluir a origem:

```powershell
node backend/scripts/export-firestore-to-supabase.cjs
```

Saída privada: `artifacts/migration/firestore-to-supabase.sql` e `summary.json`.
O exportador recusa sobrescrever um arquivo existente. Preserve esse backup fora
do controle de versão; ele contém dados de contas e hashes de senha.

Após criar o schema em um destino vazio, confira e importe:

```powershell
.\backend\scripts\import-supabase.ps1
.\backend\scripts\import-supabase.ps1 -Apply
```

A prévia não escreve no banco. A importação é uma transação e **não sobrescreve**
IDs existentes: qualquer colisão reverte todo o lote. `psql` deve estar instalado.
Não importe por cima das fixtures dos testes ou de uma base já utilizada sem revisar
os IDs. Desative o bootstrap de administrador durante a importação se o email já
existir no backup. Não exclua o Firebase até conferir os dados no destino.

São migrados perfis, hashes BCrypt, emails, notícias, fontes RSS, importações,
atividade de leitura, salvos, preferências e alertas. As senhas existentes continuam
válidas porque email/senha continuam sob responsabilidade do backend Java.
Sessões/refresh tokens, recuperação, fila de entrega, tokens FCM e vínculos sociais
Firebase não são copiados. O app invalida uma única vez a sessão/cache da versão Firebase na primeira abertura
da versão Supabase e solicita novo login. Depois disso, as sessões atuais são
preservadas normalmente. Os dados remotos ficam preservados na exportação. Quem usava apenas Google
pode usar “Esqueci minha senha” para definir uma senha por link enviado ao email
verificado, entrar com ela e então vincular o Google no gerenciamento da conta.
Isso exige SMTP configurado. O backend mantém proteção contra vinculação automática
por coincidência de email.

## 3. Google no Supabase

Em **Authentication → Providers → Google**, habilite o provedor e configure o OAuth
Web Client ID/secret no painel. No Google Cloud, autorize o callback informado pelo
Supabase (`https://SEU_PROJECT_REF.supabase.co/auth/v1/callback`). O secret fica no
painel, nunca no app. Sem IDs nativos no arquivo do aplicativo, o Google usa o navegador OAuth com
retorno ao app. Para habilitar Google nativo no Android, registre também o pacote
`app.radar.radar` e os fingerprints nos clientes OAuth Android e preencha
GOOGLE_WEB_CLIENT_ID no arquivo público.

Em **Authentication → URL Configuration**, autorize `radar://auth-callback` e as
origens web usadas. Para iOS nativo, configure também o client ID iOS e seu URL
scheme invertido no projeto Xcode. A assinatura/compilação iOS continua exigindo
macOS e credenciais Apple.

Copie `radar/supabase.client.example.json` para `radar/supabase.client.json` e preencha:

```json
{
  "RADAR_API_URL": "http://127.0.0.1:8080",
  "SUPABASE_URL": "https://SEU_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "CHAVE_PUBLICA",
  "GOOGLE_WEB_CLIENT_ID": "CLIENTE_WEB.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": ""
}
```

```powershell
.\radar\scripts\build-mobile-apks.ps1 -Mode usb -SupabaseConfigPath .\radar\supabase.client.json
.\radar\scripts\install-android-usb.ps1 -Mode usb
```

O Flutter troca o token Google por uma sessão Supabase; a API valida o access token
em `/auth/v1/user` e então emite sua própria sessão. O cliente da API usa
`POST /v1/auth/supabase` com `accessToken`. Os tokens da API continuam no cofre do
aparelho. A sessão auxiliar Supabase fica em memória e o segredo PKCE no cofre.
O login web e o retorno ao app usam PKCE. Android/iOS usam Google nativo quando
os respectivos IDs OAuth estão configurados; caso contrário, usam o navegador.
Email/senha, recuperação por SMTP e administração continuam nas tabelas privadas,
**não na lista de usuários do Supabase Auth**. Supabase Auth contém as identidades sociais.
Senha mínima: 8 caracteres; BCrypt mantém limite de 72 bytes.

## 4. Notificações e emails

Firebase Messaging foi removido. Alertas dentro do app e planejamento de notificações
continuam persistidos. Supabase sozinho não substitui FCM/APNs. O envio externo
usa o adaptador `PushSender`, com `PUSH_WEBHOOK_URL` HTTPS e `PUSH_WEBHOOK_SECRET` no
backend. Ele pode chamar uma Edge Function ligada ao provedor escolhido. O contrato
inclui notificationId, userId, title, body, deepLink, devices e header Idempotency-Key.
Sem provedor configurado, jobs push não são marcados como enviados. O registro e
permissão nativa no app precisam do adaptador do provedor que você escolher.
Emails continuam por SMTP, com outbox transacional e retries. A limpeza agendada
substitui TTL para sessões, recuperação e filas expiradas.

## 5. Testes

Use um PostgreSQL **local e separado**, chamado `fionova_test`:

```powershell
$env:TEST_DATABASE_URL='jdbc:postgresql://127.0.0.1:5432/fionova_test'
$env:TEST_DATABASE_USER='postgres'
$env:TEST_DATABASE_PASSWORD='SENHA_LOCAL'
mvn -f backend/pom.xml verify spotless:check
```

Sem TEST_DATABASE_URL, os testes usam 127.0.0.1:15432/fionova_test. A suíte recusa
outros hosts ou nomes de banco antes de limpar fixtures. O CI sobe PostgreSQL
próprio. Nunca aponte testes para seu Supabase real.

Referências: [conectar PostgreSQL](https://supabase.com/docs/guides/database/connecting-to-postgres),
[Google Auth](https://supabase.com/docs/guides/auth/social-sign-in/auth-google),
[Flutter ID token](https://supabase.com/docs/reference/dart/auth-signinwithidtoken).
