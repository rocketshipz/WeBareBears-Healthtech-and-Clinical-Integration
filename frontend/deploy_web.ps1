<#
.SYNOPSIS
  Builds the Flutter web app against the deployed backend and deploys it to Vercel.

.EXAMPLE
  .\deploy_web.ps1 -ApiBaseUrl https://triagemy-api.onrender.com/api
  .\deploy_web.ps1                # reuses the URL saved by the last run
  .\deploy_web.ps1 -Preview       # preview deployment instead of production

  If scripts are blocked: powershell -ExecutionPolicy Bypass -File .\deploy_web.ps1
  Local development is unaffected: `flutter run -d chrome` still uses localhost.
#>
param(
    [string]$ApiBaseUrl,
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Remembered between runs (gitignored), so later deploys need no arguments.
$urlFile = Join-Path $PSScriptRoot '.deploy_api_url'
# Vercel keeps the project link in build/web/.vercel, which `flutter build` can wipe; keep a copy here.
$linkBackup = Join-Path $PSScriptRoot '.vercel-web-link'
$linkDir = Join-Path $PSScriptRoot 'build\web\.vercel'

if (-not $ApiBaseUrl -and (Test-Path $urlFile)) {
    $ApiBaseUrl = (Get-Content $urlFile -Raw).Trim()
}
if (-not $ApiBaseUrl) {
    $ApiBaseUrl = Read-Host 'Backend API URL (e.g. https://<service>.onrender.com/api)'
}
$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd('/')
if ($ApiBaseUrl -notmatch '^https://') {
    throw "API URL must start with https:// (browsers block http:// calls from an https page): $ApiBaseUrl"
}
if ($ApiBaseUrl -notmatch '/api$') {
    throw "API URL must end with /api: $ApiBaseUrl"
}
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    throw 'Vercel CLI not found. Install it with: npm install -g vercel, then run: vercel login'
}
Set-Content -Path $urlFile -Value $ApiBaseUrl -Encoding ascii

Write-Host "Building web app against $ApiBaseUrl ..." -ForegroundColor Cyan
flutter build web --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }

if ((Test-Path $linkBackup) -and -not (Test-Path $linkDir)) {
    Copy-Item $linkBackup $linkDir -Recurse
}

Write-Host 'Deploying to Vercel ...' -ForegroundColor Cyan
if ($Preview) {
    vercel deploy build/web
} else {
    vercel deploy build/web --prod
}
if ($LASTEXITCODE -ne 0) { throw "vercel deploy failed (exit $LASTEXITCODE)" }

if (Test-Path $linkDir) {
    if (Test-Path $linkBackup) { Remove-Item $linkBackup -Recurse -Force }
    Copy-Item $linkDir $linkBackup -Recurse
}
Write-Host 'Done. If this is a new Vercel address, add it to CORS_ORIGINS on the backend.' -ForegroundColor Green
