#!/bin/bash
set -e

# Usage: ./remote_deploy.sh <YOUR_DIGITALOCEAN_IP>
# Default to the user provided IP if not specified
TARGET_IP=${1:-"64.225.41.225"}
SSH_USER="root"

echo "=================================================="
echo "Deploying OpenIM to DigitalOcean Droplet: $TARGET_IP"
echo "=================================================="

# 1. Install Dependencies on Remote Server
echo "[1/5] Installing dependencies on remote server..."
ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_IP << 'EOF'
  export DEBIAN_FRONTEND=noninteractive
  apt update && apt upgrade -y
  apt install -y docker.io docker-compose make git unzip

  # Install Go 1.20 if not present
  # Always install/update Go to 1.22.0
  rm -rf /usr/local/go
  echo "Installing Go 1.22.0..."
  wget -q https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
  tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
  
  # Ensure path is set (idempotent)
  if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
  fi
  if ! grep -q "/usr/local/go/bin" ~/.profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
  fi
EOF

# 2. Clone Code from GitHub (Fresh Install)
echo "[2/5] Cloning code from GitHub..."
ssh $SSH_USER@$TARGET_IP << 'EOF'
  # Clean up old dirs if they exist
  rm -rf /root/open-im-server /root/chat

  # Clone OpenIM Server
  git clone -b release-v3.8.3 https://github.com/openimsdk/open-im-server.git /root/open-im-server
  
  # Clone Chat Server
  git clone -b release-v1.8.4 https://github.com/openimsdk/chat.git /root/chat
EOF

# 3. Configure OpenIM Server (Apply Custom Images)
echo "[3/5] Configuring OpenIM Server (Applying Custom Images)..."
ssh $SSH_USER@$TARGET_IP << 'EOF'
  cd /root/open-im-server
  
  # Overwrite .env with the working configuration (Custom Images)
  cat > .env <<INNEREOF
MONGO_IMAGE=mongo:7.0
REDIS_IMAGE=redis:7.0.0
KAFKA_IMAGE=bitnamilegacy/kafka:4.0.0-debian-12-r10
MINIO_IMAGE=minio/minio:RELEASE.2024-01-11T07-46-16Z
ETCD_IMAGE=quay.io/coreos/etcd:v3.5.13
PROMETHEUS_IMAGE=prom/prometheus:v2.45.6
ALERTMANAGER_IMAGE=prom/alertmanager:v0.27.0
GRAFANA_IMAGE=grafana/grafana:11.0.1
NODE_EXPORTER_IMAGE=prom/node-exporter:v1.7.0

OPENIM_WEB_FRONT_IMAGE=openim/openim-web-front:release-v3.8.3
OPENIM_ADMIN_FRONT_IMAGE=openim/openim-admin-front:release-v1.8.4

DATA_DIR=./

PROMETHEUS_PORT=19091
ALERTMANAGER_PORT=19093
GRAFANA_PORT=13000
NODE_EXPORTER_PORT=19100
INNEREOF

  # Initialize the server
  # We use the install.sh script which reads the .env file
  chmod +x install.sh
EOF

# 4. Start OpenIM Server
echo "[4/5] Starting OpenIM Server..."
ssh $SSH_USER@$TARGET_IP << EOF
  source ~/.bashrc
  export PATH=\$PATH:/usr/local/go/bin
  
  cd /root/open-im-server
  
  # Stop any existing services
  docker-compose down || true
  
  # Run install script with the Public IP
  # This configures MinIO and API to advertise the correct IP
  ./install.sh --endpoint http://$TARGET_IP:10005 --api http://$TARGET_IP:10002/object/
EOF

# 5. Start Chat Server
echo "[5/5] Starting Chat Server..."
ssh $SSH_USER@$TARGET_IP << EOF
  source ~/.bashrc
  export PATH=\$PATH:/usr/local/go/bin
  
  cd /root/chat
  chmod +x bootstrap.sh
  
  # Install build tools (mage)
  ./bootstrap.sh
  
  # Build and Start
  # We use nohup to keep it running after disconnect
  # First stop if running
  pkill -f "chat_api" || true
  pkill -f "chat_rpc" || true
  
  # Build binaries
  mage Build
  
  # Start services in background
  nohup mage Start > chat.log 2>&1 &
  
  echo "Chat Server started. Check logs at /root/chat/chat.log"
EOF

echo "=================================================="
echo "Deployment Complete!"
echo "OpenIM API: http://$TARGET_IP:10002"
echo "Chat API:   http://$TARGET_IP:10008"
echo "=================================================="
