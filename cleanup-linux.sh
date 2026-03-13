#!/usr/bin/env bash
set -euo pipefail

# ── Цвета ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[ИНФО]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
line()  { echo "════════════════════════════════════════════════════"; }

cd "$(dirname "$0")"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    fi
fi

echo ""
line
echo -e "${BOLD}     Max Moderation Bot — Полная очистка${NC}"
line
echo ""
echo "  Будут удалены:"
echo "    - Все контейнеры maxbot-*"
echo "    - Все volumes (БД, Redis, Grafana, Prometheus)"
echo "    - Docker-сеть maxbot"
echo "    - Образы проекта (toxicity-api, toxicity-ui)"
echo "    - Файлы .monitoring и prod.env"
echo ""
warn "Данные базы данных и Redis будут потеряны!"
echo ""
read -rp "  Продолжить? [y/N]: " CONFIRM

if [[ ! "${CONFIRM,,}" =~ ^(y|yes|д|да)$ ]]; then
    info "Очистка отменена."
    exit 0
fi

echo ""
info "[1/5] Остановка и удаление контейнеров..."
$SUDO docker compose -f docker-compose.yml -f docker-compose.monitoring.yml --profile toxicity down 2>/dev/null || true
$SUDO docker compose -f docker-compose.yml --profile toxicity down 2>/dev/null || true
$SUDO docker compose down 2>/dev/null || true

echo ""
info "[2/5] Удаление volumes..."
for vol in maxbot-pgdata maxbot-redis-data maxbot-prometheus-data maxbot-grafana-data; do
    if $SUDO docker volume rm "$vol" 2>/dev/null; then
        ok "Удалён volume: $vol"
    fi
done

echo ""
info "[3/5] Удаление сети..."
if $SUDO docker network rm maxbot 2>/dev/null; then
    ok "Удалена сеть: maxbot"
fi

echo ""
info "[4/5] Удаление образов проекта..."
$SUDO docker images --filter "reference=max-moderation-bot-toxicity-api" -q 2>/dev/null | xargs -r $SUDO docker rmi 2>/dev/null || true
$SUDO docker images --filter "reference=max-moderation-bot-toxicity-ui" -q 2>/dev/null | xargs -r $SUDO docker rmi 2>/dev/null || true
ok "Образы toxicity удалены (если были)."

echo ""
info "[5/5] Удаление служебных файлов..."
[ -f ".monitoring" ] && rm -f ".monitoring" && ok "Удалён .monitoring"
[ -f "prod.env" ] && rm -f "prod.env" && ok "Удалён prod.env"

echo ""
line
echo -e "${GREEN}${BOLD}  Очистка завершена.${NC}"
echo ""
echo "  Можно запускать установку заново:"
echo "  ./install-linux.sh <ТОКЕН>"
line
echo ""
