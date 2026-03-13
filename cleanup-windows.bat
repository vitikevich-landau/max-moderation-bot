@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

echo.
echo ════════════════════════════════════════════════════
echo      Max Moderation Bot — Полная очистка (Windows)
echo ════════════════════════════════════════════════════
echo.
echo   Будут удалены:
echo     - Все контейнеры maxbot-*
echo     - Все volumes (БД, Redis, Grafana, Prometheus)
echo     - Docker-сеть maxbot
echo     - Образы проекта (toxicity-api, toxicity-ui)
echo     - Файлы .monitoring и prod.env
echo.
echo   ВНИМАНИЕ: Данные базы данных и Redis будут потеряны!
echo.
set /p "CONFIRM=  Продолжить? [y/N]: "

if /i "!CONFIRM!"=="y" goto :do_cleanup
if /i "!CONFIRM!"=="yes" goto :do_cleanup
if /i "!CONFIRM!"=="д" goto :do_cleanup
if /i "!CONFIRM!"=="да" goto :do_cleanup

echo [ИНФО] Очистка отменена.
goto :eof

:do_cleanup

echo.
echo [1/5] Остановка и удаление контейнеров...
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml --profile toxicity down 2>nul
docker compose -f docker-compose.yml --profile toxicity down 2>nul
docker compose down 2>nul

echo.
echo [2/5] Удаление volumes...
for %%v in (maxbot-pgdata maxbot-redis-data maxbot-prometheus-data maxbot-grafana-data) do (
    docker volume rm %%v 2>nul && echo   Удалён volume: %%v
)

echo.
echo [3/5] Удаление сети...
docker network rm maxbot 2>nul && echo   Удалена сеть: maxbot

echo.
echo [4/5] Удаление образов проекта...
for /f "tokens=*" %%i in ('docker images --filter "reference=max-moderation-bot-toxicity-api" -q 2^>nul') do docker rmi %%i 2>nul
for /f "tokens=*" %%i in ('docker images --filter "reference=max-moderation-bot-toxicity-ui" -q 2^>nul') do docker rmi %%i 2>nul
echo   Образы toxicity удалены (если были).

echo.
echo [5/5] Удаление служебных файлов...
if exist ".monitoring" del ".monitoring" && echo   Удалён .monitoring
if exist "prod.env" del "prod.env" && echo   Удалён prod.env

echo.
echo ════════════════════════════════════════════════════
echo   Очистка завершена. Можно запускать установку заново:
echo   .\install-windows.bat ^<ТОКЕН^>
echo ════════════════════════════════════════════════════
echo.
pause
