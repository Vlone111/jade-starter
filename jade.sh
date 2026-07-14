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
cat >/opt/remnanode/docker-compose.yml <<EOF
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

#Работа с портами
ufw allow 22/tcp
ufw allow 443/tcp
ufw --force enable
ufw allow $NODE_PORT

# Буст сети (с защитой от дублирования записей)
echo "Настройка системных оптимизаций (BBR)..."
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
  sysctl -p
fi

#DNS
cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Задаем вопрос пользователю
read -p "Нужно ли устанавливать Warp (y/n): " answer

case "$answer" in
[Yy]* | [Yy][Ee][Ss]*)
  echo "Действие подтверждено. Продолжаем работу..."
  # Здесь твой код, если пользователь согласился
  sudo mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

  sudo apt update -y
  sudo apt install cloudflare-warp -y

  warp-cli registration new
  warp-cli mode proxy
  warp-cli connect
  sleep 3
  WARP_STATUS=$(warp-cli status 2>&1)

  if [[ "$WARP_STATUS" =~ "Status update: Connected" ]]; then
    echo "WARP установлен и работает"
    echo "установка сприпта очищения"
    echo "warp-cli restart" > /etc/cron.daily/warp-cli-restart
    chmod +x /etc/cron.daily/warp-cli-restart
    echo "скрипт установлен"
    echo "скрипт будет запускаться ежедневно в 00:00"
  else
    echo "ошибка при установке"
    exit 1
  fi
  ;;
[Nn]* | [Nn][Oo]*)
  echo "Действие отменено."
  ;;
*)
  echo "Неверный ввод. Отмена операции."
  exit 1
  ;;
esac
# Читаем текущее значение статуса IPv6
IPV6_STATUS=$(cat /sys/module/ipv6/parameters/disable)

# Проверяем: если равен 0 (IPv6 включен), то отключаем
if [ "$IPV6_STATUS" -eq 0 ]; then
  echo "IPv6 включен (status 0). Отключаем..."

  # Отключаем «на лету»
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
  sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null

  # Проверяем, записаны ли уже настройки в sysctl.conf, чтобы не дублировать
  if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
    echo -e "\nnet.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf >/dev/null
    sudo sysctl -p >/dev/null
  fi

  echo "IPv6 успешно отключен и зафиксирован в настройках."
else
  echo "IPv6 уже отключен (status не 0). Ничего делать не нужно."
fi

echo "Запускаем контейнер..."
docker compose up -d && docker compose logs remnanode
