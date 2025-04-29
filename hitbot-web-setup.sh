#!/bin/bash
# hitbot-web-setup.sh - Web sunucusu kurulum betiği

# SSH anahtarı oluştur
echo "SSH anahtarı oluşturuluyor..."
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "SSH anahtarı oluşturuldu ve yapılandırıldı."

# Sistem güncellemelerini yap
echo "Sistem güncelleniyor..."
dnf update -y

# MongoDB kurulumu
echo "MongoDB kuruluyor..."
echo '[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc' | tee /etc/yum.repos.d/mongodb-org-6.0.repo

dnf install -y mongodb-org
systemctl enable mongod
systemctl start mongod
echo "MongoDB kuruldu ve başlatıldı."

# Node.js kurulumu
echo "Node.js kuruluyor..."
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs git
echo "Node.js kuruldu."

# PM2 global kurulumu
echo "PM2 kuruluyor..."
npm install -g pm2
echo "PM2 kuruldu."

# Uygulama dizinini oluştur
echo "Uygulama dizini oluşturuluyor..."
mkdir -p /var/www/hitbot
cd /var/www/hitbot

# Proje alt dizinlerini oluştur
mkdir -p frontend/build backend uploads
echo "Uygulama dizinleri oluşturuldu."

# Backend dizinine örnek server.js oluştur
echo "Backend örneği oluşturuluyor..."
cat > /var/www/hitbot/backend/server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Çevre değişkenleri
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend/build')));

// MongoDB bağlantısı
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/hitbot_db')
  .then(() => console.log('MongoDB Connected'))
  .catch(err => console.log('MongoDB Connection Error', err));

// Kullanıcı modeli
const UserSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['admin', 'user'], default: 'user' },
  allowedKeywords: [String],
  lastActive: { type: Date, default: Date.now },
  createdAt: { type: Date, default: Date.now }
});

// Parola hashleme
UserSchema.pre('save', async function(next) {
  if (this.isModified('password')) {
    this.password = await bcrypt.hash(this.password, 10);
  }
  next();
});

const User = mongoose.model('User', UserSchema);

// Auth route
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;
  
  try {
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ success: false, message: 'Kullanıcı adı veya şifre hatalı' });
    }
    
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ success: false, message: 'Kullanıcı adı veya şifre hatalı' });
    }
    
    const token = jwt.sign(
      { id: user._id, username: user.username, role: user.role },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '1d' }
    );
    
    res.json({
      success: true,
      data: {
        user: {
          id: user._id,
          username: user.username,
          role: user.role,
          allowedKeywords: user.allowedKeywords,
          lastActive: user.lastActive,
          createdAt: user.createdAt
        },
        token
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'Sunucu hatası' });
  }
});

// Diğer rotalar ve API endpoint'leri buraya eklenecek

// SPA için catch-all route
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/build/index.html'));
});

// Server'ı başlat
app.listen(port, () => {
  console.log(`HitBot Backend running on port ${port}`);
});
EOF

# Frontend dizinine örnek index.html
echo "Frontend örneği oluşturuluyor..."
cat > /var/www/hitbot/frontend/build/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HitBot Pro - Control Panel</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            padding: 20px;
            width: 90%;
            max-width: 500px;
            text-align: center;
        }
        h1 {
            color: #333;
        }
        p {
            color: #666;
            margin-bottom: 20px;
        }
        .btn {
            background-color: #4CAF50;
            color: white;
            padding: 10px 15px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            transition: background-color 0.3s;
        }
        .btn:hover {
            background-color: #45a049;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>HitBot Pro</h1>
        <p>Web server kurulumu başarıyla tamamlandı!</p>
        <p>Backend API ve frontend uygulaması eklenmeye hazır.</p>
        <button class="btn" onclick="alert('HitBot Pro!')">Test Et</button>
    </div>
</body>
</html>
EOF

# Backend için .env dosyası oluştur
cat > /var/www/hitbot/backend/.env << 'EOF'
PORT=3001
JWT_SECRET=hitbot_secure_secret_key_change_in_production
MONGODB_URI=mongodb://localhost:27017/hitbot_db
NODE_ENV=production
EOF

# Backend için package.json
cat > /var/www/hitbot/backend/package.json << 'EOF'
{
  "name": "hitbot-backend",
  "version": "1.0.0",
  "description": "HitBot Pro Backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "bcrypt": "^5.1.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "mongoose": "^7.0.3"
  }
}
EOF

# Backend bağımlılıklarını kur
cd /var/www/hitbot/backend
npm install

# Admin kullanıcısı oluştur (zaten var olup olmadığı kontrol edilecek)
echo "MongoDB kullanıcı oluşturuluyor..."
mongosh --eval "
  db = db.getSiblingDB('hitbot_db');
  if (db.users.countDocuments({username: 'admin'}) === 0) {
    db.users.insertOne({
      username: 'admin',
      password: '\$2b\$10\$1qAz2wSx3eDc4rFv5tMb/OSdL2ktBCisWY1F9UCrLR2ut930NXkue', // şifre: admin
      role: 'admin',
      allowedKeywords: ['google', 'facebook', 'twitter', 'instagram'],
      lastActive: new Date(),
      createdAt: new Date()
    });
    print('Admin kullanıcısı oluşturuldu.');
  } else {
    print('Admin kullanıcısı zaten var.');
  }
" || echo "MongoDB kullanıcı oluşturma hatası."

# Nginx kurulumu
echo "Nginx kuruluyor..."
dnf remove -y nginx
dnf install -y nginx

# SSL sertifikası için Certbot kurulumu
echo "Certbot kuruluyor..."
dnf install -y epel-release
dnf install -y certbot python3-certbot-nginx

# Nginx yapılandırma dosyası
echo "Nginx yapılandırılıyor..."
cat > /etc/nginx/conf.d/hitbot.conf << 'EOF'
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

    location /socket.io {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /uploads {
        alias /var/www/hitbot/uploads;
    }
}
EOF

# Default configurasyonları devre dışı bırak
rm -f /etc/nginx/conf.d/default.conf

# Nginx'i yeniden başlat
systemctl enable nginx
systemctl restart nginx

# SSL sertifikası al
echo "SSL sertifikası alınıyor..."
certbot --nginx -d hitbot.pro -d www.hitbot.pro -n --agree-tos --email admin@hitbot.pro

# Web server için systemd servisi oluştur
echo "Backend servisi oluşturuluyor..."
cat > /etc/systemd/system/hitbot-backend.service << 'EOF'
[Unit]
Description=HitBot Backend Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/hitbot/backend
ExecStart=/usr/bin/node /var/www/hitbot/backend/server.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=hitbot-backend

[Install]
WantedBy=multi-user.target
EOF

# Servisi etkinleştir
systemctl daemon-reload
systemctl enable hitbot-backend
systemctl start hitbot-backend

# Güvenlik için firewall ayarları
echo "Firewall yapılandırılıyor..."
dnf install -y firewalld
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=3001/tcp
firewall-cmd --reload

echo "Web sunucusu kurulumu tamamlandı!"
echo "Admin paneline hitbot.pro adresinden erişebilirsiniz."
echo "Kullanıcı: admin, Şifre: admin"