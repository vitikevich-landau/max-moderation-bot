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

:: Create prod.env
echo BOT_TOKEN=%TOKEN%> %ENV_FILE%
echo [OK] Файл %ENV_FILE% создан.

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

:: Wait
echo [ИНФО] Ожидание запуска (10 сек)...
timeout /t 10 /nobreak >nul

:: Logs
echo.
echo ════════════════════════════════════════════════════
echo [OK] Логи бота:
echo ════════════════════════════════════════════════════
echo.
docker logs --tail 20 maxbot-bot

echo.
echo ════════════════════════════════════════════════════
echo.
echo   ✅ Бот успешно запущен!
echo.
echo ════════════════════════════════════════════════════
echo.
echo   Команды:
echo     Логи:       docker logs -f maxbot-bot
echo     Статус:     docker compose ps
echo     Остановка:  docker compose down
echo     Обновление: docker compose pull ^& docker compose up -d
echo.
pause
