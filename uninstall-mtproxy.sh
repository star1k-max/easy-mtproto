#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== Удаление MTProxy ===${NC}"
echo -e "${YELLOW}ВНИМАНИЕ: Будут удалены все файлы, сервис и конфигурация MTProxy.${NC}"
read -p "Продолжить? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Отмена."
    exit 0
fi

# Определяем порт, если нужно закрыть в UFW
if command -v ufw &> /dev/null; then
    read -p "Закрыть порт MTProxy в UFW? Если да, введите порт (например, 443). Оставьте пустым для пропуска: " PORT
    if [[ -n "$PORT" ]]; then
        ufw delete allow $PORT/tcp 2>/dev/null || true
        echo -e "${GREEN}Порт $PORT удалён из правил UFW${NC}"
    fi
fi

# Остановка и отключение сервиса
echo -e "${YELLOW}Остановка и отключение сервиса mtproxy...${NC}"
systemctl stop mtproxy 2>/dev/null || true
systemctl disable mtproxy 2>/dev/null || true
rm -f /etc/systemd/system/mtproxy.service
systemctl daemon-reload

# Удаление файлов
echo -e "${YELLOW}Удаление файлов MTProxy...${NC}"
rm -rf /opt/mtproxy
rm -f /etc/cron.d/mtproxy-update
rm -f /root/mtproxy_link.txt
rm -f /root/mtproxy_qr.png

# Опционально: удаление установленных пакетов
echo -e "${YELLOW}Хотите удалить пакеты, установленные во время установки?${NC}"
echo "Список пакетов: build-essential, libssl-dev, zlib1g-dev, ca-certificates, qrencode"
read -p "Удалить эти пакеты? (y/N): " remove_pkgs
if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
    apt remove -y build-essential libssl-dev zlib1g-dev ca-certificates qrencode
    apt autoremove -y
    echo -e "${GREEN}Пакеты удалены${NC}"
else
    echo -e "${GREEN}Пакеты оставлены${NC}"
fi

echo -e "${GREEN}=== Удаление MTProxy завершено ===${NC}"
