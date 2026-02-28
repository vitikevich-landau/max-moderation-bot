# Max Moderation Bot - Windows Installer (PowerShell)
# Usage: .\install-windows.ps1 <BOT_TOKEN>

param(
    [Parameter(Position=0)]
    [string]$Token
)

$ErrorActionPreference = "Stop"

function Write-Info  { Write-Host "[ИНФО] $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Err   { Write-Host "[ОШИБКА] $args" -ForegroundColor Red }

Write-Host ""
Write-Host "════════════════════════════════════════════════════"
Write-Host "     Max Moderation Bot — Установка (Windows)" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════"
Write-Host ""

# Check Docker
$dockerExists = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerExists) {
    Write-Err "Docker не установлен."
    Write-Host ""
    Write-Host "  Установите Docker Desktop:"
    Write-Host "  https://docs.docker.com/desktop/install/windows-install/"
    Write-Host ""
    Write-Host "  Или через winget:"
    Write-Host "  winget install Docker.DockerDesktop"
    exit 1
}
Write-Ok "Docker установлен."

# Check Docker running
try {
    docker info 2>$null | Out-Null
    Write-Ok "Docker daemon запущен."
} catch {
    Write-Err "Docker daemon не запущен. Запустите Docker Desktop."
    exit 1
}

# Token
$EnvFile = "prod.env"
$DefaultEnv = "default.env"
$Placeholder = "вставь_сюда_токен"

if (-not $Token) {
    if (Test-Path $EnvFile) {
        $line = Get-Content $EnvFile | Where-Object { $_ -match "^BOT_TOKEN=" } | Select-Object -First 1
        if ($line) {
            $Token = $line -replace "^BOT_TOKEN=", ""
        }
        if (-not $Token -or $Token -eq $Placeholder) { $Token = "" }
        if ($Token) { Write-Ok "Токен найден в $EnvFile." }
    }
}

if (-not $Token) {
    Write-Err "Токен бота не указан."
    Write-Host ""
    Write-Host "  Использование: .\install-windows.ps1 <ТОКЕН_БОТА>"
    Write-Host ""
    exit 1
}

# Create prod.env from default.env as base
if (-not (Test-Path $EnvFile)) {
    if (Test-Path $DefaultEnv) {
        Copy-Item $DefaultEnv $EnvFile
        Write-Info "Скопирован $DefaultEnv как основа."
    }
}
# Replace BOT_TOKEN in prod.env
if (Test-Path $EnvFile) {
    (Get-Content $EnvFile) -replace '^BOT_TOKEN=.*', "BOT_TOKEN=$Token" | Set-Content $EnvFile
} else {
    "BOT_TOKEN=$Token" | Out-File -FilePath $EnvFile -Encoding utf8NoBOM
}
Write-Ok "Файл $EnvFile обновлён с BOT_TOKEN."

# Start
Write-Host ""
Write-Host "════════════════════════════════════════════════════"
Write-Info "Скачиваю образ и запускаю контейнеры..."
Write-Host "════════════════════════════════════════════════════"
Write-Host ""

docker compose up -d --pull always
if ($LASTEXITCODE -ne 0) {
    Write-Err "Запуск не удался."
    exit 1
}

# Wait with health check polling
$BotContainer = "maxbot-bot"
$MaxWait = 60
$Elapsed = 0

Write-Info "Ожидание запуска контейнеров (до $MaxWait секунд)..."

while ($Elapsed -lt $MaxWait) {
    $health = docker inspect -f '{{.State.Health.Status}}' $BotContainer 2>$null
    if ($health -eq "healthy") { break }
    if ($health -eq "unhealthy") {
        Write-Err "Контейнер бота перешёл в состояние unhealthy."
        docker logs --tail 30 $BotContainer
        exit 1
    }
    Start-Sleep -Seconds 3
    $Elapsed += 3
}

$running = docker inspect -f '{{.State.Running}}' $BotContainer 2>$null
if ($running -ne "true") {
    Write-Err "Контейнер бота не запустился за $MaxWait секунд."
    docker logs --tail 30 $BotContainer
    exit 1
}

# Logs
Write-Host ""
Write-Host "════════════════════════════════════════════════════"
Write-Ok "Логи бота:"
Write-Host "════════════════════════════════════════════════════"
Write-Host ""
docker logs --tail 20 $BotContainer

# Success
Write-Host ""
Write-Host "════════════════════════════════════════════════════"
Write-Host ""
Write-Host "  ✅ Бот успешно запущен!" -ForegroundColor Green
Write-Host ""
Write-Host "════════════════════════════════════════════════════"
Write-Host ""
Write-Host "  Команды:"
Write-Host "    Логи:       docker logs -f $BotContainer"
Write-Host "    Статус:     docker compose ps"
Write-Host "    Остановка:  docker compose down"
Write-Host "    Обновление: docker compose pull; docker compose up -d"
Write-Host ""
