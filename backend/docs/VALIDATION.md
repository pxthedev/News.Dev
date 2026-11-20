# Validação · 15/11/2026

- Java 21.0.10, Spring Boot 3.5.16, Firebase Admin 9.12.0.
- Emulador Cloud Firestore 1.22.0, projeto fictício `demo-radar`, porta local 18080; nenhum banco Firebase real acessado.
- `mvn spotless:apply clean verify`: aprovado. **22 testes**, zero falhas/erros/skips (16 de integração e seis de unidade).
- `mvn spotless:check`: aprovado.
- Flutter 3.44.1 / Dart 3.12.1: `flutter analyze` sem problemas e `flutter test` com **29 testes aprovados**.
- `flutter build web --no-pub`: aprovado, artefato em `radar/build/web`. Build também aprovou o dry run Wasm. Existe aviso de fonte Cupertino não incluída pelo projeto original; não foi feito build iOS/Android nem teste em aparelho nesta entrega.
- JAR iniciado com Firestore: health UP, cadastro preservou o ID anônimo e refresh/logout revogaram as sessões esperadas em chamadas HTTP reais.
- Configuração do Docker Compose validada e script PowerShell de Cloud Run analisado sintaticamente. Docker não foi executado e nenhum deploy foi realizado.

Integrações externas nos testes: identidade Google/Apple, fonte RSS remota e SMTP simulados. O XML/RSS foi testado com dados locais e bloqueio de entidades externas. O teste de SMTP verificou backoff, retry e remoção do corpo após aceitação simulada. FCM/APNs, OAuth real e SMTP real dependem das contas e credenciais do usuário.

O workflow de CI foi criado, mas ainda não foi executado no GitHub. As regras e os índices do Firestore estão preparados; o emulador não valida toda a necessidade de índices de produção. Publique-os e valide no seu projeto antes da liberação.


## Atualização · pacotes Android para USB

Em 15/11/2026 foram gerados `artifacts/mobile/radar-demo.apk` e `artifacts/mobile/radar-usb.apk`, ambos Flutter release 0.1.0 (1), APK universal ARM/ARM64/x86-64, minSdk 24 e targetSdk 36. Assinatura APK v2 verificada com `apksigner`, usando certificado Android de desenvolvimento para teste local. Hashes SHA-256 e metadados estão junto aos arquivos.

A versão USB contém o endpoint `http://127.0.0.1:8080`; a versão demo não contém esse endpoint. A configuração de rede compilada mantém HTTPS como padrão e libera HTTP somente para localhost/loopback e host do emulador. Os pacotes foram verificados quanto à ausência dos arquivos privados de credenciais do backend. Nenhum Android estava conectado; não foi feita instalação ou teste de execução em aparelho físico.

Foi preparado `.github/workflows/ios-ipa.yml` e validadas as sintaxes YAML, Bash e Python das etapas. O workflow não foi executado e não há IPA gerado ou assinado, pois faltam ambiente macOS e certificados/perfil Apple. Instruções em `radar/docs/INSTALAR_NO_CELULAR.md`.


## Atualização · identidade Fionova · 16/11/2026

Nome público, monograma, splash e ícones Android/iOS/web atualizados para Fionova.
Identificadores técnicos e links existentes preservados. Flutter analyze sem
problemas e 29 testes Flutter aprovados. Ícones iOS conferidos quanto a dimensões
e ausência de canal alfa; XML Android validado. Backend compilado com Maven.
O empacotamento do JAR encontrou bloqueio de arquivo por processos locais em
execução; esses processos não foram interrompidos.

As fontes vetoriais e a prévia estão em `brand/fionova`; o gerador reproduzível
fica em `tools/branding`. Não houve teste em aparelho físico nem build iOS.

Gerados e verificados os APKs `fionova-demo.apk` e `fionova-usb.apk`, versão 0.2.0 (2), com rótulo Fionova e assinatura válida. As cópias com nomes antigos foram mantidas.


## Atualização · conta antes dos interesses · 16/11/2026

Boas-vindas abre cadastro ou login; só contas acessam interesses, conteúdo e links
internos. Login/cadastro válido abre interesses, mantendo onboarding pendente.
Restauração de estado anônimo não libera onboarding; logout limpa a pilha de rotas.
Formulários incluem confirmação de senha e Google em login e cadastro, com erros
de disponibilidade/cancelamento tratados. Tokens continuam no cofre da plataforma.

Flutter analyze sem problemas; 34 testes aprovados, incluindo cadastro/login com
API simulada, erro de credenciais e bloqueio das rotas. APK USB release 0.3.0 (3)
gerado e assinatura validada. Não foi instalado ou executado em aparelho físico.
O teste OAuth Google real depende de configuração pública Firebase e cliente Web
OAuth ainda ausentes; este APK foi gerado com FIREBASE_ENABLED=false. Instruções
em radar/docs/LOGIN_GOOGLE.md; o build aceita -FirebaseConfigPath.
A versão demo existente permanece 0.2.0 e não contém o novo fluxo.


## Atualização · sair pelo perfil · 17/11/2026

Botão Sair da conta visível diretamente no perfil, com estado Saindo e bloqueio
de toques repetidos. Perfil e gerenciamento de conta usam o mesmo componente.
O fluxo revoga a sessão na API, remove credenciais/caches privados, encerra a
sessão Firebase e limpa a navegação até o login. A limpeza local não busca dados
anônimos nem cria uma sessão nova. Se a revogação na API falha, o erro é exibido
e o usuário pode tentar novamente; falhas no logout do provedor social não
impedem limpar o estado depois da revogação da API.

Flutter analyze sem problemas; 36 testes aprovados, incluindo logout pelo perfil,
remoção dos tokens/dados e impossibilidade de voltar ao perfil após sair.

APK USB 0.3.1 (4) gerado e assinatura verificada. Não instalado em aparelho.


## Correção · inicialização local · 17/11/2026

Confirmado `no main manifest attribute` no JAR intermediário deixado por um
empacotamento interrompido. `mvn -DskipTests package` reconstruiu o pacote Spring
Boot executável. start-local.ps1 agora verifica manifest/Start-Class/dependências,
reconstrói JAR ausente ou inválido e detecta porta ocupada antes de iniciar.

Verificados o JAR executável e a rejeição do .jar.original intermediário, a sintaxe
PowerShell e o diagnóstico da porta 8080 ocupada. Início real via -UseJar confirmado;
GET /actuator/health retornou {"status":"UP"}. Isso valida a inicialização, não
operações de autenticação ou leitura/escrita no Firestore.


## Atualização · senha mínima de 8 caracteres · 17/11/2026

Cadastro e redefinição aceitam senhas a partir de 8 caracteres no formulário,
nas constraints Bean Validation e no serviço Java. Mantidos BCrypt custo 12,
limite de 72 bytes UTF-8 e compatibilidade de login com senhas existentes.

Dois testes Java de política passaram (8 aceitos, 7 rejeitados; limite de bytes
preservado). Os 36 testes Flutter passaram, incluindo cadastro com 8 caracteres.
Flutter analyze sem problemas. Backend reempacotado e reiniciado na porta 8080;
/actuator/health retornou UP. Não foi criada uma conta real no Firestore nos testes.

APK USB 0.3.2 (5) gerado, assinatura validada, instalado por USB e reaberto no Android conectado.


## Diagnóstico · mensagem de instabilidade · 17/11/2026

Logs reais indicam FAILED_PRECONDITION: The query requires an index, em consultas
articles por confirmed/publishedAt. Os índices já estão definidos no arquivo
firestore.indexes.json (31 definições compostas). A conta de serviço recebe 403
na API administrativa de índices, embora a API de dados funcione. Nenhum índice
foi criado por esta tentativa; a causa ainda depende de autorização no projeto.

Preparado backend/scripts/firestore-indexes.cjs: modo padrão consulta os índices;
--apply cria somente compostos ausentes, sem excluir índices, alterar regras,
dados ou TTL. Lê as credenciais externas referenciadas no .env sem imprimi-las.
Requer Node.js com fetch e permissão datastore.indexes.list/create/get.


## Migração Firebase → Supabase · 17/11/2026

Persistência convertida para PostgreSQL/JDBC, transações SERIALIZABLE com retry,
pool Hikari, migração Flyway e índices B-tree/GIN. Schema fionova privado com RLS.
Pacotes Firebase Admin/Firestore removidos do JAR; Firebase Auth/Core/Messaging
removidos do Flutter e componentes Firebase ausentes no manifesto do APK.
Google usa Supabase Auth; email/senha e sessões continuam na API Java.

33 testes Java aprovados (20 de integração HTTP/SQL, 5 de verificação Supabase
simulada, além de política de senha, RSS e notificações). A integração foi executada
em PostgreSQL 18.6 local, isolado no banco fionova_test. Cobertos rollback, proteção
do schema, refresh concorrente de uso único, conta social e recuperação por email.
38 testes Flutter aprovados e flutter analyze sem problemas.

JAR executável 1.1.0 iniciado para teste na porta 18081: health UP, cadastro com
8 caracteres, preferências, home/feed e logout com posterior rejeição do JWT
revogado. O banco sem notícias responde com home vazia válida em vez de erro.

Exportação Firestore somente leitura concluída: 1 perfil e 1 índice de email,
sem notícias. Dump privado em artifacts/migration, ignorado pelo Git. Importação
atômica desse dump validada em banco local separado fionova_migration_check.
A origem não foi alterada. Tokens, filas e identificadores Firebase não são migrados.

APK USB 0.4.0 (6) gerado e assinatura verificada; não instalado nesta etapa.
Workflows YAML/Python, compose, TOML e scripts PowerShell validados estaticamente.
Docker, CI remoto, OAuth real Google/Supabase e iOS não foram executados. O teste
PostgreSQL usou os binários locais existentes; Docker Desktop não ficou disponível.

A conexão Supabase em nuvem e a importação real continuam pendentes: faltam URL,
credenciais JDBC e chave publicável. backend/.env foi preparado sem variáveis de
runtime Firebase, preservando os valores privados existentes e o backup local.
O serviço antigo já iniciado na porta 8080 não foi substituído por um banco não
configurado. O novo JAR deve ser iniciado após configurar a conexão Supabase.
Push externo depende de provedor/webhook; alertas internos e SMTP foram preservados.


Verificação final: o cliente remove uma única vez as credenciais/cache da geração
Firestore antes de abrir a versão Supabase, evitando refresh inválido bloquear
cadastro. Teste confirma invalidação antiga e preservação de novas sessões após
reiniciar. Os 38 testes Flutter e a análise foram repetidos com essa mudança e
passaram. APK 0.4.0 reconstruído e assinatura/hash conferidos novamente.
Os processos locais auxiliares de teste (API 18081 e PostgreSQL 15432) foram encerrados;
os dados privados de verificação permanecem ignorados em .local para auditoria.


## Conexão real Supabase · 19/11/2026

Configuração validada para jiyfrstixyadywyqzhnd (destino do link e do banco informados).
A chave publicável foi aceita pelo endpoint Auth settings (HTTP 200). A conexão
Direct IPv6 expirou; o Session pooler informado pelo usuário conectou com TLS.
Variáveis privadas foram salvas somente no backend/.env; o Flutter recebeu apenas
URL e chave publicável. Nenhuma credencial privada foi incorporada ao aplicativo.

JAR 1.1.0 iniciado na porta 8080; Flyway criou o schema fionova e aplicou V1 no
PostgreSQL 17.12 Supabase. Importação atômica concluída: 1 perfil e 1 índice de email,
0 notícias (a origem não continha artigos). Firebase de origem não foi alterado.
Health retornou UP; home/feed/explore responderam corretamente no banco real.
A identidade anônima usada na verificação foi revogada e removida com seus tokens.

Google está desativado no Auth settings do projeto; sua habilitação/configuração
OAuth continua pendente no painel. Email/senha continuam na API Java.


APK 0.4.1 (7) recompilado com URL/chave publicável reais, assinatura validada.
O comando combinado de instalação/encerramento/reabertura do app foi rejeitado
pela revisão automática. A alternativa somente de instalação foi executada,
mas o verificador Android recusou com INSTALL_FAILED_VERIFICATION_FAILURE.
Nenhuma verificação de segurança foi desativada. O APK foi copiado por USB para
/sdcard/Download/Fionova-0.4.1.apk, para instalação normal pelo próprio usuário.
O telefone ainda indicava 0.3.2 na última consulta. API Supabase permanece UP.

O usuário confirmou a instalação manual da atualização pelo app Arquivos.


## Identidade Nexora Tech · 19/11/2026

Nome público alterado para Nexora Tech nas telas, compartilhamento, mensagens,
rótulos Android/iOS/web e textos do backend. IDs de instalação, deep links,
credenciais, nomes das tabelas/schema Supabase e identificadores privados foram
preservados. Novo símbolo gerado por image_gen e exportado para ícones e abertura.
Fontes raster e arquivos de apresentação em brand/nexora-tech; gerador reprodutível
em tools/branding/generate.mjs. A identidade anterior foi preservada.

Flutter analyze sem problemas e 38 testes aprovados com o novo nome. XML Android
validado e ícones iOS conferidos quanto a dimensões e ausência de canal alfa.
JAR 1.1.1 compilado/empacotado com -DskipTests (não foi reexecutada a integração
PostgreSQL nesta alteração visual). O processo da API em execução permanece na
versão anterior até o próximo reinício; Google Branding também é configuração
externa e precisa ser atualizado no painel.

APK Nexora Tech 0.5.0 (8) gerado, rótulo e assinatura verificados. O asset da nova logo foi comparado com o conteúdo real do APK e corresponde. Cópias com nomes anteriores foram mantidas para compatibilidade. A atualização mantém o mesmo identificador e certificado.
