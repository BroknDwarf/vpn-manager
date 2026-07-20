# VPN Manager

Утилита для обслуживания VPS с **3x-ui/Xray**: диагностика, мониторинг,
резервные копии и безопасное обновление самого VPN Manager.

## Возможности

- `vpn status` — краткий статус сервера
- `vpn doctor` — расширенная диагностика без изменения настроек
- `vpn backup` — резервная копия 3x-ui/Xray
- `vpn monitor` — одна проверка состояния
- `vpn logs` — просмотр журналов
- `vpn self-update` — обновление VPN Manager из GitHub
- systemd timer для мониторинга
- cron для ежедневных резервных копий
- ShellCheck и тесты в GitHub Actions

## Установка

```bash
git clone https://github.com/OWNER/vpn-manager.git
cd vpn-manager
sudo bash install.sh
```

После установки:

```bash
vpn status
vpn doctor
vpn backup
vpn logs
```

## Безопасность

VPN Manager:

- не меняет конфигурацию Xray/Reality;
- не перезапускает x-ui автоматически;
- проверяет архив после создания;
- не удаляет резервные копии моложе заданного срока;
- выполняет диагностику в режиме read-only.

## Поддерживаемая система

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- systemd
- 3x-ui/Xray в стандартном пути `/usr/local/x-ui`

## Лицензия

MIT.
