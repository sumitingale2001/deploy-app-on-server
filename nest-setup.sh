#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo "🧩 NestJS Setup Started"

# 🛠️ Dependencies & Build
read -p "❓ Install flags (e.g. --legacy-peer-deps): " INSTALL_FLAGS
$PACKAGE_MANAGER install $INSTALL_FLAGS || true

if ! $PACKAGE_MANAGER run build; then
    echo "❌ Build failed. Please check your code."
    exit 1
fi

# 📝 Configuration
APP_NAME=$(basename "$(pwd)")
DEFAULT_ROOT="$(pwd)"

ask_with_default "Nginx config name" "$APP_NAME" CONF_NAME
ask_with_default "Domain (server_name)" "api.example.com" SERVER_NAME
ask_with_default "Root path" "$DEFAULT_ROOT" ROOT_PATH
ask_with_default "Upstream name" "${APP_NAME}_upstream" UPSTREAM

# 🔥 AUTO PORT
PORT=$(get_next_port 8000)
echo "🚀 Auto-selected NestJS port: $PORT"

NGINX_FILE="/etc/nginx/sites-available/$CONF_NAME"

sudo tee "$NGINX_FILE" >/dev/null <<EOF
upstream $UPSTREAM {
    server 127.0.0.1:$PORT;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name $SERVER_NAME;

    access_log off;
    error_log off;

    root $ROOT_PATH;
    index index.html;

    client_max_body_size 20m;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript application/xml+rss application/xml application/octet-stream image/svg+xml;
    gzip_min_length 1024;

    location / {
        proxy_pass http://$UPSTREAM;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location = /nginx-health {
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }
}
EOF

sudo ln -sf "$NGINX_FILE" /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 🔐 SSL PROMPT (same behavior)
ask_and_setup_ssl "$SERVER_NAME"

# 🚀 PM2
command -v pm2 >/dev/null || npm install -g pm2

MAIN_FILE="dist/main.js"
if [[ ! -f "$MAIN_FILE" ]]; then
    echo "❌ Build file not found at $MAIN_FILE. Checking for other common entry points..."
    MAIN_FILE=$(find dist -name "main.js" | head -n 1)
fi

if [[ -f "$MAIN_FILE" ]]; then
    PORT=$PORT pm2 start "$MAIN_FILE" --name "$SERVER_NAME"
else
    echo "❌ Could not find main entry point. Please start manually using PM2."
fi

pm2 save
pm2 startup

