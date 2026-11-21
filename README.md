# news.dev com Docker

O pacote inclui o frontend Flutter Web, o backend Java e o PostgreSQL.
O banco é criado localmente e o backend aplica o schema ao iniciar.
O primeiro build baixa as dependências e as imagens.

## Iniciar

1. Instale e inicie o Docker Desktop ou o Docker Engine com Compose v2.
2. Na pasta que contém `compose.yaml`, copie `.env.example` para `.env`.
   Escolha uma senha para `POSTGRES_PASSWORD` e um segredo com pelo menos
   32 bytes para `JWT_SECRET`. No PowerShell, para criar ambos em uma
   instalação nova, você pode usar:

   ```powershell
   @(
     "POSTGRES_PASSWORD=$([guid]::NewGuid().ToString('N'))"
     "JWT_SECRET=$([guid]::NewGuid().ToString('N'))$([guid]::NewGuid().ToString('N'))"
     'WEB_PORT=3000'
     'INGESTION_ENABLED=true'
   ) | Set-Content -Encoding utf8 .env
   ```

3. Execute `docker compose up --build -d`.
4. Abra [news.dev](http://localhost:3000/) e crie uma conta com e-mail e senha.
   A primeira coleta de notícias começa quando a API sobe.
   Esta instalação local oferece login com e-mail e senha.

Verifique a API em [saúde](http://localhost:3000/api/actuator/health).
Se a porta 3000 estiver ocupada, altere `WEB_PORT` no `.env`.

Use `docker compose logs -f api` para acompanhar o backend e
`docker compose down` para parar os serviços preservando o banco local.
