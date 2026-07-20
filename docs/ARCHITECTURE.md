# Архитектура

- `bin/vpn` — единая точка входа
- `lib/common.sh` — конфигурация и общие функции
- `lib/status.sh` — краткий статус
- `lib/doctor.sh` — диагностика
- `lib/backup.sh` — резервные копии
- `lib/monitor.sh` — проверка состояния
- `lib/logs.sh` — журналы
- `lib/self-update.sh` — обновление проекта
- `systemd/` — периодический мониторинг
- `cron/` — ежедневный backup
- `tests/` — синтаксические и smoke-тесты
