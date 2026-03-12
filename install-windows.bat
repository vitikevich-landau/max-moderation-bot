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

:: Monitoring choice
set "MONITORING_FILE=.monitoring"
set "COMPOSE_CMD=docker compose"

if exist "%MONITORING_FILE%" (
    set "COMPOSE_CMD=docker compose -f docker-compose.yml -f docker-compose.monitoring.yml"
    echo [OK] Обнаружена предыдущая установка с мониторингом.
    goto :mon_done
)

echo.
echo   Установить мониторинг ^(Prometheus + Grafana^)?
echo   Это добавит веб-панель с графиками и метриками бота.
echo   Требует ~512 МБ дополнительной оперативной памяти.
echo.
set /p "MON_ANSWER=  Установить мониторинг? [y/N]: "
echo.

if /i "!MON_ANSWER!"=="y" goto :mon_yes
if /i "!MON_ANSWER!"=="yes" goto :mon_yes
if /i "!MON_ANSWER!"=="д" goto :mon_yes
if /i "!MON_ANSWER!"=="да" goto :mon_yes
echo [ИНФО] Мониторинг пропущен. Можно добавить позже, запустив скрипт заново.
goto :mon_done

:mon_yes
set "COMPOSE_CMD=docker compose -f docker-compose.yml -f docker-compose.monitoring.yml"
echo.> "%MONITORING_FILE%"
echo [OK] Мониторинг будет установлен.

:mon_done

:: Toxicity filter
echo.
echo Включить ML-фильтр токсичности (rubert-tiny-toxicity)?
echo   Анализирует смысл текста на токсичность, оскорбления, угрозы.
echo   Требует ~512MB RAM, первая сборка может занять от 5 минут.
set /p "TOXICITY_ANSWER=  [y/N]: "
set "COMPOSE_PROFILES="
if /i "!TOXICITY_ANSWER!"=="y" (
    set "COMPOSE_PROFILES=--profile toxicity"
    if exist "%ENV_FILE%" (
        powershell -Command "(Get-Content '%ENV_FILE%') -replace '^TOXICITY_ENABLED=.*', 'TOXICITY_ENABLED=true' | Set-Content '%ENV_FILE%'"
        findstr /c:"TOXICITY_ENABLED" "%ENV_FILE%" >nul 2>&1 || echo TOXICITY_ENABLED=true>> "%ENV_FILE%"
        findstr /c:"TOXICITY_API_URL" "%ENV_FILE%" >nul 2>&1 || echo TOXICITY_API_URL=http://toxicity-api:8000>> "%ENV_FILE%"
    )
    echo [OK] ML-фильтр токсичности включён.
) else (
    if exist "%ENV_FILE%" (
        powershell -Command "(Get-Content '%ENV_FILE%') -replace '^TOXICITY_ENABLED=.*', 'TOXICITY_ENABLED=false' | Set-Content '%ENV_FILE%'"
    )
    echo [ИНФО] ML-фильтр токсичности отключён (только совпадение слов).
)

:: Start
echo.
echo ════════════════════════════════════════════════════
echo [ИНФО] Скачиваю образы и запускаю контейнеры...
echo ════════════════════════════════════════════════════
echo.

!COMPOSE_CMD! !COMPOSE_PROFILES! up -d --pull always
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
echo     Статус:     !COMPOSE_CMD! ps
echo     Остановка:  !COMPOSE_CMD! down
echo     Обновление: !COMPOSE_CMD! pull ^& !COMPOSE_CMD! up -d
echo.
if exist "%MONITORING_FILE%" (
    echo   Мониторинг:
    echo     Grafana:    http://localhost:3000  ^(логин: admin / admin^)
    echo     Prometheus: http://localhost:9091
    echo.
)
pause
