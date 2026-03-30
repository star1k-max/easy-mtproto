#!/bin/bash

set -e

# Цвета для вывода информиации в консоль
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Установка MTProxy  ===${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Нужен sudo${NC}"
    exit 1
fi

# Определяем IP-адрес
IP=$(curl -s ifconfig.me)
echo -e "${YELLOW}IP сервера: $IP${NC}"

read -p "Введите порт для прокси (по умолчанию 443): " PORT
PORT=${PORT:-443}

# Установка зависимостей
echo -e "${GREEN}[1/7] Установка зависимостей...${NC}"
apt update
apt install -y git curl build-essential libssl-dev zlib1g-dev ca-certificates qrencode

# Сборка
echo -e "${GREEN}[2/7] Сборка MTProxy из исходников...${NC}"
cd /opt
rm -rf mtproxy 2>/dev/null || true
git clone https://github.com/TelegramMessenger/MTProxy.git mtproxy
cd /opt/mtproxy
make

# Настройка конфигов
echo -e "${GREEN}[3/7] Настройка конфигурации...${NC}"
mkdir -p /opt/mtproxy/data
curl -fsSL https://core.telegram.org/getProxySecret -o /opt/mtproxy/data/proxy-secret
curl -fsSL https://core.telegram.org/getProxyConfig -o /opt/mtproxy/data/proxy-multi.conf

# Генерация секрета
SECRET=$(openssl rand -hex 16)
echo -e "${GREEN}Сгенерирован секрет: ${YELLOW}$SECRET${NC}"

# Создание systemd сервиса
echo -e "${GREEN}[4/7] Создание systemd сервиса...${NC}"
cat > /etc/systemd/system/mtproxy.service <<EOF
[Unit]
Description=MTProxy
After=network.target
Documentation=https://github.com/TelegramMessenger/MTProxy

[Service]
Type=simple
WorkingDirectory=/opt/mtproxy
ExecStart=/opt/mtproxy/objs/bin/mtproto-proxy -u nobody -p 8888 -H $PORT -S $SECRET --aes-pwd /opt/mtproxy/data/proxy-secret /opt/mtproxy/data/proxy-multi.conf -M 1
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Запуск сервиса
systemctl daemon-reload
systemctl enable mtproxy
systemctl start mtproxy

# Настройка ufw
echo -e "${GREEN}[5/7] Настройка firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow $PORT/tcp
    ufw reload
    echo -e "${GREEN}Порт $PORT открыт в UFW${NC}"
fi

# Создание ссылки
CLIENT_SECRET="dd$SECRET"
PROXY_LINK="https://t.me/proxy?server=$IP&port=$PORT&secret=$CLIENT_SECRET"

# Сохранение ссылки в файл
echo "$PROXY_LINK" > /root/mtproxy_link.txt
echo -e "${GREEN}[6/7] Ссылка сохранена в /root/mtproxy_link.txt${NC}"

# Генерация QR-кода
echo -e "${GREEN}[7/7] Генерация QR-кода...${NC}"

# Функция для вывода QR в терминал
print_qr() {
    echo -e "${BLUE}"
    echo "$1" | qrencode -t ANSIUTF8 -s 2 -l M
    echo -e "${NC}"
}

# Создаем QR в файл PNG
qrencode -o /root/mtproxy_qr.png -s 10 -l M "$PROXY_LINK"
echo -e "${GREEN}QR-код сохранен в /root/mtproxy_qr.png${NC}"

# Вывод
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}=== УСТАНОВКА ЗАВЕРШЕНА ===${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}=== Ваши данные для подключения ===${NC}"
echo -e "Сервер: ${GREEN}$IP${NC}"
echo -e "Порт: ${GREEN}$PORT${NC}"
echo -e "Секрет (серверный): ${GREEN}$SECRET${NC}"
echo -e "Клиентский секрет: ${GREEN}$CLIENT_SECRET${NC}"
echo ""
echo -e "${YELLOW}=== Ссылка для Telegram ===${NC}"
echo -e "${GREEN}$PROXY_LINK${NC}"
echo ""
echo -e "${YELLOW}=== QR-код (в консоли) ===${NC}"
print_qr "$PROXY_LINK"
echo ""
echo -e "${YELLOW}=== Полезные команды ===${NC}"
echo -e "Статус сервиса: ${GREEN}systemctl status mtproxy${NC}"
echo -e "Логи: ${GREEN}journalctl -u mtproxy -f${NC}"
echo -e "Ссылка сохранена: ${GREEN}/root/mtproxy_link.txt${NC}"
echo -e "QR-код сохранен: ${GREEN}/root/mtproxy_qr.png${NC}"
echo ""
echo -e "${GREEN}Для добавления в Telegram отсканируйте QR-код в терминале${NC}"
echo -e "${GREEN}или откройте ссылку на телефоне${NC}"
