cat > clean-setup.sh << 'EOF'
#!/bin/bash

echo "Temiz kurulum başlıyor..."

# Sistem güncellemesi
dnf update -y

# Gerekli paketler
dnf install -y nginx mongodb-org nodejs git

# MongoDB servisi
systemctl enable mongod
systemctl start mongod

# Uygulama dizinleri
mkdir -p /var/www/hitbot/frontend/build
mkdir -p /var/www/hitbot/backend
mkdir -p /var/www/hitbot/uploads

# Basit bir web sayfası oluştur
cat > /var/www/hitbot/frontend/build/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>HitBot Pro</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; }
        .container { max-width: 800px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>HitBot Pro</h1>
        <p>Sunucu başarıyla kuruldu!</p>
    </div>
</body>
</html>
HTML

# Basit Express.js backend
cat > /var/www/hitbot/backend/server.js << 'JS'
const express = require('express');
const app = express();
const port = 3001;

app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
JS

# Backend için package.json
cat > /var/www/hitbot/backend/package.json << 'JSON'
{
  "name": "hitbot-backend",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2"
  }
}
JSON

# Backend bağımlılıklarını kur
cd /var/www/hitbot/backend
npm install

# Nginx yapılandırması
cat > /etc/nginx/conf.d/hitbot.conf << 'NGINX'
server {
    listen 80;
    server_name hitbot.pro www.hitbot.pro;

    location / {
        root /var/www/hitbot/frontend/build;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX

# Nginx servisini başlat
systemctl restart nginx

# PM2 kur (Node.js process manager)
npm install pm2 -g

# Node.js uygulamasını başlat
cd /var/www/hitbot/backend
pm2 start server.js
pm2 save
pm2 startup

echo "Kurulum tamamlandı!"
EOF
