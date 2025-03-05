#!/bin/bash

# Check if domain and port arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <port>"
    exit 1
fi

DOMAIN=$1
PORT=$2
EMAIL="hafiz@fizion.id"  # Change this email or add as an argument if needed

# Update package list and install required tools
sudo apt update
sudo apt install -y curl software-properties-common

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Nginx and Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Configure Nginx
CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
sudo tee $CONFIG_FILE > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

# Enable the site
sudo ln -sf $CONFIG_FILE /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Obtain SSL certificate
sudo certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email -d $DOMAIN

# Add proxy configuration to Nginx
sudo sed -i "/ssl_dhparam \/etc\/letsencrypt\/ssl-dhparams.pem;/a \
    \n\
    location \/ {\n\
        proxy_pass http:\/\/localhost:$PORT;\n\
        proxy_set_header Host \$host;\n\
        proxy_set_header X-Real-IP \$remote_addr;\n\
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\
        proxy_set_header X-Forwarded-Proto \$scheme;\n\
    }" $CONFIG_FILE

# Reload Nginx configuration
sudo nginx -t && sudo systemctl reload nginx

# Enable firewall (if needed)
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow ssh
sudo ufw enable

# Create PostgreSQL configuration directory
sudo mkdir -p /etc/postgresql/conf

# Create sample PostgreSQL configuration files
sudo tee /etc/postgresql/conf/postgresql.conf > /dev/null <<EOF
# Enable listening on all interfaces
listen_addresses = '*'
EOF

sudo tee /etc/postgresql/conf/pg_hba.conf > /dev/null <<EOF
# Allow all remote connections with MD5 encryption
host    all             all             0.0.0.0/0               md5
EOF

echo "Installation complete!"
echo "Nginx is configured to handle SSL for $DOMAIN and proxy requests to port $PORT"
echo "Ensure your Docker container is running on port $PORT"
echo ""
echo "PostgreSQL Configuration Notes:"
echo "1. In your Docker Compose file, add these volumes to your PostgreSQL service:"
echo "   volumes:"
echo "     - /etc/postgresql/conf/postgresql.conf:/etc/postgresql/postgresql.conf"
echo "     - /etc/postgresql/conf/pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf"
echo "2. Expose port 5432 in your Docker Compose:"
echo "   ports:"
echo "     - \"5432:5432\""
echo "3. Set authentication method in your environment variables:"
echo "   environment:"
echo "     - POSTGRES_HOST_AUTH_METHOD=md5"
echo "     - POSTGRES_PASSWORD=your_secure_password"
