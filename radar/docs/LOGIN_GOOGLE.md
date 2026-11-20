# Login Google · Supabase

A integração Firebase foi substituída por Supabase Auth. O login por email/senha
continua no backend Java. Cadastro e login são obrigatórios antes dos interesses.

Siga [a configuração Supabase e migração](../../backend/docs/SUPABASE.md#3-google-no-supabase).
Use `supabase.client.example.json`; o script aceita `-SupabaseConfigPath`.
O JSON de conta de serviço Google e arquivos de configuração Firebase não são mais
usados pelo app. Apenas URL Supabase, chave pública e IDs OAuth vão para o build.
