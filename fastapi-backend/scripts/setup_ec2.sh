#!/usr/bin/env bash
# ==============================================================================
# FastKirana Backend - 1-Click AWS EC2 (Mumbai Ubuntu 24.04) Auto-Deploy Script
# ==============================================================================
set -e

echo "🚀 [1/6] Updating Ubuntu packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "📦 [2/6] Installing Python 3, Git, Nginx, Certbot..."
sudo apt-get install -y python3 python3-pip python3-venv git nginx certbot python3-certbot-nginx build-essential libpq-dev

echo "🐍 [3/6] Setting up Virtualenv & Dependencies..."
cd /home/ubuntu
if [ ! -d "Fast_Kirana" ]; then
    echo "Cloning repository..."
    git clone https://github.com/hrdksachan0/Fast_Kirana.git
fi

cd /home/ubuntu/Fast_Kirana/fastapi-backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "⚙️ [4/6] Creating Systemd Service for FastAPI (24/7 Autorestart)..."
sudo bash -c 'cat > /etc/systemd/system/fastapi.service <<EOF
[Unit]
Description=FastKirana FastAPI Microservice
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/Fast_Kirana/fastapi-backend
Environment="PATH=/home/ubuntu/Fast_Kirana/fastapi-backend/venv/bin"
EnvironmentFile=/home/ubuntu/Fast_Kirana/fastapi-backend/.env
ExecStart=/home/ubuntu/Fast_Kirana/fastapi-backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable fastapi
sudo systemctl restart fastapi

echo "🌐 [5/6] Configuring Nginx Reverse Proxy..."
sudo bash -c 'cat > /etc/nginx/sites-available/fastapi <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
}
EOF'

sudo ln -sf /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo "✅ [6/6] FastAPI Service Status:"
sudo systemctl status fastapi --no-pager

echo ""
echo "🎉 DEPLOYMENT COMPLETE! FastAPI is now running 24/7 on your AWS EC2 instance."
echo "👉 You can test: curl http://localhost:8000/health"
