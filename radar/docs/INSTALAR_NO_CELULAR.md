# Instalar no celular por USB

## Android

Os arquivos gerados ficam em `../../artifacts/mobile` a partir desta pasta.

- `fionova-demo.apk`: versão anterior de demonstração (0.2.0), sem o novo fluxo obrigatório de conta.
- `fionova-usb.apk`: conecta à API Java no computador pela porta 8080 usando `adb reverse`.

São APKs universais de teste local, compilados em release e assinados com o certificado de desenvolvimento Android. As duas versões têm o mesmo identificador `app.radar.radar`: instalar uma atualiza/substitui a outra. Não são pacotes para publicação na Play Store.

Para a demonstração, copie o APK ao armazenamento do Android pelo cabo, abra-o no app Arquivos e permita a instalação pelo app usado para abrir o arquivo.

Para usar o backend pelo cabo, ative Opções do desenvolvedor → Depuração USB e aceite a autorização do computador. Na raiz `C:\dev\appnews-main\appnews-main`, execute:

```powershell
.\radar\scripts\install-android-usb.ps1 -Mode usb
```

Em outro terminal:

```powershell
Set-Location 'C:\dev\appnews-main\appnews-main\backend'
.\scripts\start-local.ps1 -UseJar
```

O backend deve estar conectado ao PostgreSQL Supabase, com as migrações aplicadas. Veja [configuração Supabase](../../backend/docs/SUPABASE.md). O banco precisa de notícias publicadas para popular o feed. Google depende das configurações públicas Supabase/OAuth; push externo exige um provedor de entrega.

Recriar os dois APKs:

```powershell
.\radar\scripts\build-mobile-apks.ps1
```

Nenhuma senha PostgreSQL, chave service_role, `.env` do backend ou chave JWT é incorporada nos APKs. O HTTP da versão USB é permitido apenas para loopback e host do emulador; servidores externos precisam usar HTTPS.

## iPhone

Não foi gerado um IPA nesta máquina Windows. Flutter precisa de macOS/Xcode para compilar iOS e de uma assinatura Apple válida para instalar em um iPhone físico. Um email Apple sozinho não contém o certificado nem o perfil de provisionamento. Copiar um IPA ao armazenamento do iPhone não o instala.

Foi preparado o workflow `.github/workflows/ios-ipa.yml`, para execução em um runner macOS do GitHub Actions depois que o projeto estiver em um repositório seu. Ele ainda não foi executado.

Em Settings → Secrets and variables → Actions, configure:

| Secret | Valor |
| --- | --- |
| `IOS_CERTIFICATE_P12_BASE64` | Certificado de assinatura com chave privada, exportado como P12 e codificado em Base64 |
| `IOS_CERTIFICATE_PASSWORD` | Senha desse P12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | Perfil development/ad-hoc codificado em Base64, com o App ID e o UDID do iPhone registrados |

Não envie a senha da conta Apple nem certificados privados pelo chat. Eles devem ficar nos secrets do serviço de build. O certificado precisa corresponder ao perfil; o perfil deve incluir o iPhone e não estar expirado. O runner usa esses arquivos apenas durante o build e os remove ao terminar.

Em Actions → Build iPhone IPA → Run workflow, escolha `development` ou `ad-hoc` conforme o perfil. A URL da API deve usar HTTPS; vazia gera demonstração. O IPA, quando o build e a assinatura forem aprovados, aparecerá no artefato `radar-iphone-ipa`.

Esse fluxo não depende de um Mac local, mas exige acesso ao GitHub Actions e as credenciais de assinatura Apple. O provisionamento real e a instalação no aparelho ainda precisam ser feitos. Para um build iOS de desenvolvimento com conta Apple pessoal sem certificado exportável configurado, use Xcode em um Mac e o iPhone conectado.

Referências: [APK Flutter](https://docs.flutter.dev/deployment/android), [IPA Flutter](https://docs.flutter.dev/deployment/ios) e [dispositivos físicos Apple](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device).

A partir da versão 0.3.0, use o APK USB e mantenha a API ativa para criar conta/entrar. Google depende da configuração descrita em [LOGIN_GOOGLE.md](LOGIN_GOOGLE.md).
