# news.dev · Flutter

Aplicativo de notícias de tecnologia, com conta obrigatória antes de escolher
interesses. Login/cadastro, senha mínima de 8 caracteres, Google via Supabase Auth,
feed, leitura, busca, salvos, estatísticas, alertas e perfil com saída da conta.

- [Supabase: configuração, dados e Google](../backend/docs/SUPABASE.md)
- [Instalação USB](docs/INSTALAR_NO_CELULAR.md)
- [Contrato da API Java](docs/API.md)
- [Identidade visual](../brand/fionova/README.md)

```powershell
flutter pub get
flutter analyze
flutter test
.\scripts\build-mobile-apks.ps1 -Mode usb -SupabaseConfigPath .\supabase.client.json
```

Copie `supabase.client.example.json` para `supabase.client.json` e preencha os valores
públicos. O backend usa PostgreSQL Supabase, enquanto Flutter conversa com a API Java.
Sem RADAR_API_URL há dados de demonstração, mas sem cadastro fictício ou acesso
anônimo aos interesses. Sem configuração Supabase, email/senha continuam dependendo
da API e Google informa indisponibilidade. Push externo depende de um provedor.

IDs de instalação e links `radar://` foram mantidos para permitir atualizar o app.
