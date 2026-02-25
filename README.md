# Max Moderation Bot

Бот модерации для MAX (Telegram-совместимый). Автоматически фильтрует нежелательный контент в групповых чатах.

## Возможности

- Фильтрация запрещённых слов и доменов
- Автоматическая настройка при добавлении в чат
- Встроенные словари модерации (~870 слов, ~10 доменов)
- Управление через inline-меню прямо в чате
- Мьют нарушителей

## Быстрый старт

### Linux (Ubuntu / Debian)

```bash
git clone https://github.com/vitikevich-landau/max-moderation-bot.git
cd max-moderation-bot
chmod +x install-linux.sh
./install-linux.sh ТВОЙ_ТОКЕН_БОТА
```

Скрипт автоматически установит Docker если его нет.

### Windows

**Требуется:** [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/)

**PowerShell:**
```powershell
git clone https://github.com/vitikevich-landau/max-moderation-bot.git
cd max-moderation-bot
.\install-windows.ps1 ТВОЙ_ТОКЕН_БОТА
```

**CMD (bat):**
```cmd
git clone https://github.com/vitikevich-landau/max-moderation-bot.git
cd max-moderation-bot
install-windows.bat ТВОЙ_ТОКЕН_БОТА
```

## Как работает

1. Запускаете скрипт с токеном бота
2. Добавляете бота в чат
3. Назначаете бота администратором
4. Готово — бот модерирует

## Управление

| Команда | Описание |
|---------|----------|
| `docker logs -f maxbot-bot` | Логи бота |
| `docker compose ps` | Статус контейнеров |
| `docker compose down` | Остановить бота |
| `docker compose pull && docker compose up -d` | Обновить до последней версии |

## Получение токена

Создайте бота через BotFather и скопируйте токен.
