#!/bin/bash
set -e
GREEN='\033[0;32m'
NC='\033[0m'
clear
echo -e "${GREEN}"
cat <<'EOF'
      ____.  _____  ________  ___________
     |    | /  _  \ \______ \ \_   _____/
     |    |/  /_\  \ |    |  \ |    __)_ 
 /\__|    /    |    \|    `   \|        \
 \________\____|__  /_______  /_______  /
                  \/        \/        \/ 
EOF
echo -e "          JADE Node Installer v1.0"
echo -e "-----------------------------------------${NC}"
sleep 1

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт от имени sudo/root"
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  echo "curl уже установлен"
else
  echo "curl не найден, устанавливаем..."
  apt install curl -y
fi

if command -v ufw >/dev/null 2>&1; then
  echo "ufw уже установлен"
else
  echo "ufw не найден, устанавливаем..."
  apt install ufw -y
fi

echo "Начинаем установку Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

echo "Подготовка директории для Remnawave..."
mkdir -p /opt/remnanode
cd /opt/remnanode

# Запрашиваем порт и секрет
echo ""
read -p "Введите порт для ноды (NODE_PORT): " NODE_PORT
echo ""
read -p "Введите секретный ключ (SECRET_KEY): " SECRET_KEY
echo ""

# Генерируем docker-compose.yml
cat > /opt/remnanode/docker-compose.yml <<EOF
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    network_mode: host
    restart: always
    cap_add:
      - NET_ADMIN
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      - NODE_PORT=${NODE_PORT}
      - SECRET_KEY=${SECRET_KEY}
EOF

echo "Файл docker-compose.yml создан в /opt/remnanode/"
echo "Открываем порт для ноды..."
ufw allow 22/tcp
ufw --force enable
ufw allow $NODE_PORT

echo "Запускаем контейнер..."
docker compose up -d && docker compose logs remnanode
