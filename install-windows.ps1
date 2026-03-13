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

# Monitoring choice
$MonitoringFile = ".monitoring"
$ComposeCmd = "docker compose --env-file prod.env"

if (Test-Path $MonitoringFile) {
    $ComposeCmd = "docker compose --env-file prod.env -f docker-compose.yml -f docker-compose.monitoring.yml"
    Write-Ok "Обнаружена предыдущая установка с мониторингом."
} else {
    Write-Host ""
    Write-Host "  Установить мониторинг (Prometheus + Grafana)?" -ForegroundColor White
    Write-Host "  Это добавит веб-панель с графиками и метриками бота."
    Write-Host "  Требует ~512 МБ дополнительной оперативной памяти."
    Write-Host ""
    $answer = Read-Host "  Установить мониторинг? [y/N]"
    Write-Host ""

    if ($answer -match '^(y|yes|д|да)$') {
        $ComposeCmd = "docker compose --env-file prod.env -f docker-compose.yml -f docker-compose.monitoring.yml"
        New-Item -ItemType File -Path $MonitoringFile -Force | Out-Null
        Write-Ok "Мониторинг будет установлен."
    } else {
        Write-Info "Мониторинг пропущен. Можно добавить позже, запустив скрипт заново."
    }
}


# Toxicity filter
Write-Host ""
Write-Host "Включить ML-фильтр токсичности (rubert-tiny-toxicity)?" -ForegroundColor White
Write-Host "  Анализирует смысл текста на токсичность, оскорбления, угрозы."
Write-Host "  Требует ~512MB RAM, первая сборка может занять от 5 минут."
$ToxAnswer = Read-Host "  [y/N]"

$ComposeProfiles = @()
if ($ToxAnswer -match "^[Yy]$") {
    $ComposeProfiles = @("--profile", "toxicity")
    if (Test-Path $EnvFile) {
        $content = Get-Content $EnvFile
        if ($content -match 'TOXICITY_ENABLED') {
            $content = $content -replace '^TOXICITY_ENABLED=.*', 'TOXICITY_ENABLED=true'
        } else {
            $content += "TOXICITY_ENABLED=true"
        }
        if (-not ($content -match 'TOXICITY_API_URL')) {
            $content += "TOXICITY_API_URL=http://toxicity-api:8000"
        }
        $content | Set-Content $EnvFile
    }
    Write-Ok "ML-фильтр токсичности включён."
} else {
    if (Test-Path $EnvFile) {
        (Get-Content $EnvFile) -replace '^TOXICITY_ENABLED=.*', 'TOXICITY_ENABLED=false' | Set-Content $EnvFile
    }
    Write-Info "ML-фильтр токсичности отключён (только совпадение слов)."
}

# Start
Write-Host ""
Write-Host "════════════════════════════════════════════════════"
Write-Info "Скачиваю образы и запускаю контейнеры..."
Write-Host "════════════════════════════════════════════════════"
Write-Host ""

# Ensure Docker network exists
$networkExists = docker network inspect maxbot 2>$null
if ($LASTEXITCODE -ne 0) {
    docker network create maxbot | Out-Null
}
Write-Ok "Docker-сеть maxbot готова."

Invoke-Expression "$ComposeCmd @ComposeProfiles up -d --pull always"
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
Write-Host "    Статус:     $ComposeCmd ps"
Write-Host "    Остановка:  $ComposeCmd down"
Write-Host "    Обновление: $ComposeCmd pull; $ComposeCmd up -d"
Write-Host ""
if (Test-Path $MonitoringFile) {
    Write-Host "  Мониторинг:" -ForegroundColor White
    Write-Host "    Grafana:    http://localhost:4200  (логин: admin)"
    Write-Host "    Prometheus: http://localhost:4210"
    Write-Host ""
}
Write-Host ""
