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
error() { echo -e "${RED}[ОШИБКА]${NC} $1"; }
line()  { echo "════════════════════════════════════════════════════"; }

cd "$(dirname "$0")"

# ── Баннер ─────────────────────────────────────────────────
echo ""
line
echo -e "${BOLD}     Max Moderation Bot — Установка${NC}"
line
echo ""

# ── Проверка: запуск от root или с sudo ────────────────────
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        error "Запустите скрипт с правами root или установите sudo."
        exit 1
    fi
fi

# ── Установка Docker (если нет) ────────────────────────────
if ! command -v docker &>/dev/null; then
    warn "Docker не найден. Устанавливаю..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq docker.io docker-compose-plugin > /dev/null
    $SUDO systemctl enable --now docker
    ok "Docker установлен."
else
    ok "Docker уже установлен."
fi

# ── Проверка: Docker Compose ──────────────────────────────
if ! docker compose version &>/dev/null; then
    warn "Docker Compose не найден. Устанавливаю..."
    $SUDO apt-get install -y -qq docker-compose-plugin > /dev/null
    ok "Docker Compose установлен."
else
    ok "Docker Compose доступен."
fi

# ── Проверка: Docker daemon ───────────────────────────────
if ! $SUDO docker info &>/dev/null 2>&1; then
    info "Запускаю Docker daemon..."
    $SUDO systemctl start docker
fi
ok "Docker daemon запущен."

# ── Определение токена ────────────────────────────────────
ENV_FILE="prod.env"
PLACEHOLDER="вставь_сюда_токен"
TOKEN=""

if [ -n "${1:-}" ]; then
    TOKEN="$1"
    ok "Токен получен из аргумента."
elif [ -f "$ENV_FILE" ]; then
    TOKEN=$(grep -E '^BOT_TOKEN=' "$ENV_FILE" | head -1 | cut -d'=' -f2-)
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "$PLACEHOLDER" ]; then
        TOKEN=""
    else
        ok "Токен найден в $ENV_FILE."
    fi
fi

if [ -z "$TOKEN" ]; then
    error "Токен бота не указан."
    echo ""
    echo "  Использование: ./install-linux.sh <ТОКЕН_БОТА>"
    echo ""
    echo "  Токен можно получить у BotFather."
    exit 1
fi

# ── Создание prod.env ─────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "default.env" ]; then
        cp default.env "$ENV_FILE"
        info "Скопирован default.env как основа."
    fi
fi
# Записать/перезаписать BOT_TOKEN в prod.env
if grep -q '^BOT_TOKEN=' "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=${TOKEN}|" "$ENV_FILE"
else
    echo "BOT_TOKEN=${TOKEN}" >> "$ENV_FILE"
fi
ok "Файл $ENV_FILE обновлён с BOT_TOKEN."

# ── Мониторинг (Prometheus + Grafana) ────────────────────
MONITORING_FILE=".monitoring"
COMPOSE_CMD="docker compose"

if [ -f "$MONITORING_FILE" ]; then
    # Уже установлен с мониторингом — сохраняем выбор
    COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.monitoring.yml"
    ok "Обнаружена предыдущая установка с мониторингом."
else
    echo ""
    echo -e "${BOLD}  Установить мониторинг (Prometheus + Grafana)?${NC}"
    echo "  Это добавит веб-панель с графиками и метриками бота."
    echo "  Требует ~512 МБ дополнительной оперативной памяти."
    echo ""
    read -rp "  Установить мониторинг? [y/N]: " MONITORING_ANSWER
    echo ""

    if [[ "${MONITORING_ANSWER,,}" =~ ^(y|yes|д|да)$ ]]; then
        COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.monitoring.yml"
        touch "$MONITORING_FILE"
        ok "Мониторинг будет установлен."
    else
        info "Мониторинг пропущен. Можно добавить позже, запустив скрипт заново."
    fi
fi

# ── Фильтр токсичности ───────────────────────────────────
echo ""
echo -e "${BOLD}Включить ML-фильтр токсичности (rubert-tiny-toxicity)?${NC}"
echo "  Анализирует смысл текста на токсичность, оскорбления, угрозы."
echo "  Требует ~512MB RAM, первая сборка может занять от 5 минут."
echo -n "  [y/N]: "
read -r TOXICITY_ANSWER

COMPOSE_PROFILES=""
if [[ "$TOXICITY_ANSWER" =~ ^[Yy]$ ]]; then
    COMPOSE_PROFILES="--profile toxicity"
    if grep -q '^TOXICITY_ENABLED=' "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^TOXICITY_ENABLED=.*|TOXICITY_ENABLED=true|" "$ENV_FILE"
    else
        echo "TOXICITY_ENABLED=true" >> "$ENV_FILE"
    fi
    if ! grep -q '^TOXICITY_API_URL=' "$ENV_FILE" 2>/dev/null; then
        echo "TOXICITY_API_URL=http://toxicity-api:8000" >> "$ENV_FILE"
    fi
    ok "ML-фильтр токсичности включён."
else
    if grep -q '^TOXICITY_ENABLED=' "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^TOXICITY_ENABLED=.*|TOXICITY_ENABLED=false|" "$ENV_FILE"
    fi
    info "ML-фильтр токсичности отключён (только совпадение слов)."
fi

# ── Запуск ────────────────────────────────────────────────
echo ""
line
info "Скачиваю образы и запускаю контейнеры..."
line
echo ""

if ! $SUDO $COMPOSE_CMD $COMPOSE_PROFILES up -d --pull always; then
    error "Запуск не удался. Проверьте вывод выше."
    exit 1
fi

# ── Ожидание ──────────────────────────────────────────────
echo ""
info "Ожидание запуска контейнеров (до 60 секунд)..."

BOT_CONTAINER="maxbot-bot"
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$($SUDO docker inspect -f '{{.State.Health.Status}}' "$BOT_CONTAINER" 2>/dev/null || echo "missing")
    if [ "$STATUS" = "healthy" ]; then
        break
    fi
    if [ "$STATUS" = "unhealthy" ]; then
        error "Контейнер бота перешёл в состояние unhealthy."
        warn "Последние логи контейнера:"
        echo ""
        $SUDO docker logs --tail 30 "$BOT_CONTAINER" 2>&1
        exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done

if [ "$($SUDO docker inspect -f '{{.State.Running}}' "$BOT_CONTAINER" 2>/dev/null)" != "true" ]; then
    error "Контейнер бота не запустился за ${MAX_WAIT} секунд."
    warn "Последние логи контейнера:"
    echo ""
    $SUDO docker logs --tail 30 "$BOT_CONTAINER" 2>&1
    exit 1
fi

# ── Логи ──────────────────────────────────────────────────
echo ""
line
ok "Логи бота:"
line
echo ""
$SUDO docker logs --tail 20 "$BOT_CONTAINER" 2>&1
echo ""

# ── Успех ─────────────────────────────────────────────────
line
echo -e "${GREEN}${BOLD}"
echo "  ✅ Бот успешно запущен!"
echo -e "${NC}"
line
echo ""
echo -e "  ${BOLD}Команды:${NC}"
echo "    Логи:       $SUDO docker logs -f $BOT_CONTAINER"
echo "    Статус:     $SUDO $COMPOSE_CMD ps"
echo "    Остановка:  $SUDO $COMPOSE_CMD down"
echo "    Обновление: $SUDO $COMPOSE_CMD pull && $SUDO $COMPOSE_CMD up -d"
echo ""
if [ -f "$MONITORING_FILE" ]; then
    echo -e "  ${BOLD}Мониторинг:${NC}"
    echo "    Grafana:    http://localhost:3000  (логин: admin / ${GRAFANA_ADMIN_PASSWORD:-admin})"
    echo "    Prometheus: http://localhost:9091"
    echo ""
fi
line
echo ""
