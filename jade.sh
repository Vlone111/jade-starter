#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m'

clear
# Выводим текст зеленым
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

# Проверяем, запущен ли скрипт от root
if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт от имени sudo/root"
  exit 1
fi

echo "Обновляем систему..."
apt update && apt upgrade -y

# Проверка и установка curl
if command -v curl >/dev/null 2>&1; then
  echo "curl уже установлен"
else
  echo "curl не найден, устанавливаем..."
  apt install curl ufw -y
fi

if command -v ufw >/dev/null 2>&1; then
  echo "ufw уже установлен"
else
  echo "ufw не найден, устанавливаем..."
  apt install -y
fi

echo "Начинаем установку Docker..."
curl -fsSL https://get.docker.com | sh

echo "Подготовка директории для Remnawave..."
mkdir -p /opt/remnanode
cd /opt/remnanode

echo "Сейчас откроется редактор. Вставьте содержимое docker-compose.yml, сохраните (Ctrl+O, Enter) и выходите (Ctrl+X)"
sleep 3 # Небольшая пауза, чтобы успеть прочитать текст
nano docker-compose.yml

echo "Настройка завершена. Файл находится в /opt/remnanode/docker-compose.yml"

PORT=$(grep "NODE_PORT" /opt/remnanode/docker-compose.yml | cut -d'=' -f2)

echo "открываем порт для ноды"
ufw allow 22/tcp
ufw --force enable
ufw allow $PORT

echo "запускаем контейнер"
docker compose up -d && docker compose logs remannode
