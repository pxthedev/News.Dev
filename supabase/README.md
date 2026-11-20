# Schema Fionova para Supabase

Abra `schema.sql`, copie o conteúdo para o SQL Editor do seu projeto Supabase
e execute a consulta completa. São 18 tabelas de aplicação e 18 índices adicionais
no schema privado `fionova`. O arquivo pode ser repetido: não exclui dados e não
recria tabelas ou índices que já existem; reaplica RLS e permissões privadas.
Ele não substitui migrações de alteração de estrutura de tabelas existentes.

As tabelas são compatíveis com o backend atual: `id`, `owner_id`, `data` JSONB,
`created_at` e `updated_at`. Contas e sessões da API Java ficam nesse schema;
`auth.users` é gerenciado pelo Supabase Auth e não é criado por este arquivo.
O acesso do app continua pela API Java, sem liberar tabelas privadas para anon
ou authenticated. Não adicione `fionova` aos schemas expostos da Data API.

No projeto conectado em 19/11/2026, as tabelas já foram criadas pelo Flyway.
Para vê-las no Table Editor, selecione o schema `fionova`. Também pode consultar:

```sql
select table_name
from information_schema.tables
where table_schema = 'fionova' and table_type = 'BASE TABLE'
order by table_name;
```

`flyway_schema_history` é uma tabela adicional de controle de versões do backend.
Não a remova. O schema.sql não escreve nem modifica esse histórico.

Em um projeto NOVO, escolha criar a estrutura pelo Flyway ao iniciar o backend
OU por este arquivo; se usar este arquivo primeiro, configure
`DB_MIGRATIONS_ENABLED=false` antes de iniciar a API. Em um projeto já controlado
pelo Flyway, mantenha o fluxo atual e faça futuras alterações com novas migrações.

Configuração e importação dos dados: `../backend/docs/SUPABASE.md`.
