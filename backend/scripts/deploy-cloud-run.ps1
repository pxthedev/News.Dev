[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{4,61}[a-z0-9]$')][string]$ProjectId,
 [Parameter(Mandatory)][string]$Image,
 [Parameter(Mandatory)][string]$ServiceAccount,
 [Parameter(Mandatory)][string]$JwtSecretName,
 [Parameter(Mandatory)][string]$DbUrlSecretName,
 [Parameter(Mandatory)][string]$DbUserSecretName,
 [Parameter(Mandatory)][string]$DbPasswordSecretName,
 [string]$SupabaseUrl = '',
 [string]$SupabasePublishableKey = '',
 [string]$Region = 'southamerica-east1',
 [string]$Service = 'radar-api',
 [string]$CorsOrigin = 'https://example.com',
 [switch]$EnableWorkers
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) { throw 'Instale a Google Cloud CLI e autentique sua conta.' }
if ($Image -notmatch '^[a-z0-9.-]+-docker.pkg.dev/[a-z0-9-]+/[a-z0-9_-]+/[a-z0-9_.:/-]+$') { throw 'Informe uma imagem existente no Artifact Registry.' }
$workerValue = if ($EnableWorkers) { 'true' } else { 'false' }
# Cloud Run fornece HTTPS. Credenciais PostgreSQL e JWT vêm do Secret Manager.
# Workers em segundo plano exigem CPU sempre alocada e ao menos uma instância.
$deployArgs = @('run','deploy',$Service,'--project',$ProjectId,'--region',$Region,'--image',$Image,
 '--service-account',$ServiceAccount,'--allow-unauthenticated','--port','8080','--memory','1Gi',
 '--min','1','--max','1','--no-cpu-throttling','--timeout','60',
 '--set-secrets',"JWT_SECRET=${JwtSecretName}:latest,SUPABASE_DB_URL=${DbUrlSecretName}:latest,SUPABASE_DB_USER=${DbUserSecretName}:latest,SUPABASE_DB_PASSWORD=${DbPasswordSecretName}:latest",
 '--set-env-vars',"SUPABASE_URL=$SupabaseUrl,SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey,CORS_ORIGINS=$CorsOrigin,API_DOCS_ENABLED=false,DELIVERY_ENABLED=$workerValue")
& gcloud @deployArgs
if ($LASTEXITCODE -ne 0) { throw 'O deploy falhou.' }
$serviceUrl = & gcloud run services describe $Service --project $ProjectId --region $Region --format 'value(status.url)'
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível consultar a URL do serviço.' }
$health = Invoke-RestMethod -Uri "$serviceUrl/actuator/health" -TimeoutSec 30
if ($health.status -ne 'UP') { throw 'O serviço não passou na verificação de saúde.' }
Write-Output "Backend disponível em $serviceUrl"
