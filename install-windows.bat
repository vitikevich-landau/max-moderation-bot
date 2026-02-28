@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

echo.
echo ════════════════════════════════════════════════════
echo      Max Moderation Bot — Установка (Windows)
echo ════════════════════════════════════════════════════
echo.

:: Check Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Docker не установлен.
    echo.
    echo   Установите Docker Desktop:
    echo   https://docs.docker.com/desktop/install/windows-install/
    echo.
    echo   Или через winget:
    echo   winget install Docker.DockerDesktop
    pause
    exit /b 1
)
echo [OK] Docker установлен.

:: Check Docker running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Docker daemon не запущен. Запустите Docker Desktop.
    pause
    exit /b 1
)
echo [OK] Docker daemon запущен.

:: Token
set "TOKEN=%~1"
set "ENV_FILE=prod.env"
set "DEFAULT_ENV=default.env"

if "%TOKEN%"=="" (
    if exist %ENV_FILE% (
        for /f "tokens=1,* delims==" %%a in ('findstr /b "BOT_TOKEN=" %ENV_FILE%') do set "TOKEN=%%b"
    )
)

if "%TOKEN%"=="" (
    echo [ОШИБКА] Токен бота не указан.
    echo.
    echo   Использование: install-windows.bat ^<ТОКЕН_БОТА^>
    echo.
    pause
    exit /b 1
)
echo [OK] Токен получен.

:: Create prod.env from default.env as base
if not exist "%ENV_FILE%" (
    if exist "%DEFAULT_ENV%" (
        copy /y "%DEFAULT_ENV%" "%ENV_FILE%" >nul
        echo [ИНФО] Скопирован %DEFAULT_ENV% как основа.
    )
)
:: Replace BOT_TOKEN in prod.env
if exist "%ENV_FILE%" (
    powershell -Command "(Get-Content '%ENV_FILE%') -replace '^BOT_TOKEN=.*', 'BOT_TOKEN=!TOKEN!' | Set-Content '%ENV_FILE%'"
) else (
    echo BOT_TOKEN=!TOKEN!> "%ENV_FILE%"
)
echo [OK] Файл %ENV_FILE% обновлён с BOT_TOKEN.

:: Start
echo.
echo ════════════════════════════════════════════════════
echo [ИНФО] Скачиваю образ и запускаю контейнеры...
echo ════════════════════════════════════════════════════
echo.

docker compose up -d --pull always
if %errorlevel% neq 0 (
    echo [ОШИБКА] Запуск не удался.
    pause
    exit /b 1
)

:: Wait with health check polling
set "BOT_CONTAINER=maxbot-bot"
set "MAX_WAIT=60"
set "ELAPSED=0"

echo.
echo [ИНФО] Ожидание запуска контейнеров (до %MAX_WAIT% секунд)...

:wait_loop
if !ELAPSED! geq %MAX_WAIT% goto :wait_done
for /f "tokens=*" %%i in ('docker inspect -f "{{.State.Health.Status}}" %BOT_CONTAINER% 2^>nul') do set "HEALTH=%%i"
if "!HEALTH!"=="healthy" goto :wait_done
if "!HEALTH!"=="unhealthy" (
    echo [ОШИБКА] Контейнер бота перешёл в состояние unhealthy.
    echo [!] Последние логи контейнера:
    echo.
    docker logs --tail 30 %BOT_CONTAINER%
    pause
    exit /b 1
)
timeout /t 3 /nobreak >nul
set /a ELAPSED+=3
goto :wait_loop

:wait_done
for /f "tokens=*" %%i in ('docker inspect -f "{{.State.Running}}" %BOT_CONTAINER% 2^>nul') do set "RUNNING=%%i"
if not "!RUNNING!"=="true" (
    echo [ОШИБКА] Контейнер бота не запустился за %MAX_WAIT% секунд.
    echo [!] Последние логи контейнера:
    echo.
    docker logs --tail 30 %BOT_CONTAINER%
    pause
    exit /b 1
)

:: Logs
echo.
echo ════════════════════════════════════════════════════
echo [OK] Логи бота:
echo ════════════════════════════════════════════════════
echo.
docker logs --tail 20 %BOT_CONTAINER%

echo.
echo ════════════════════════════════════════════════════
echo.
echo   ✅ Бот успешно запущен!
echo.
echo ════════════════════════════════════════════════════
echo.
echo   Команды:
echo     Логи:       docker logs -f %BOT_CONTAINER%
echo     Статус:     docker compose ps
echo     Остановка:  docker compose down
echo     Обновление: docker compose pull ^& docker compose up -d
echo.
pause
