#!binbash
# hitbot-bot-setup.sh - Bot sunucusu kurulum betiği

# SSH anahtarı oluştur
echo SSH anahtarı oluşturuluyor...
ssh-keygen -t rsa -b 4096 -f ~.sshid_rsa -N 
cat ~.sshid_rsa.pub  ~.sshauthorized_keys
chmod 600 ~.sshauthorized_keys
echo SSH anahtarı oluşturuldu ve yapılandırıldı.

# Sistem güncellemelerini yap
echo Sistem güncelleniyor...
dnf update -y

# Node.js kurulumu
echo Node.js kuruluyor...
curl -sL httpsrpm.nodesource.comsetup_18.x  bash -
dnf install -y nodejs git chromium
echo Node.js kuruldu.

# Bot için dizin oluştur
echo Bot dizinleri oluşturuluyor...
mkdir -p opthitbotlogs
cd opthitbot

# Bot için package.json oluştur
echo Bot konfigürasyonu oluşturuluyor...
cat  opthitbotpackage.json  'EOF'
{
  name hitbot,
  version 1.0.0,
  description HitBot Automation Service,
  main bot.js,
  scripts {
    start node bot.js
  },
  dependencies {
    axios ^1.3.5,
    dotenv ^16.0.3,
    puppeteer ^19.8.5,
    socket.io-client ^4.6.1
  }
}
EOF

# Bot kodu oluştur
cat  opthitbotbot.js  'EOF'
const puppeteer = require('puppeteer');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { io } = require('socket.io-client');
require('dotenv').config();

 Çevre değişkenleri
const API_URL = process.env.API_URL  'httpshitbot.proapi';
const WS_URL = process.env.WS_URL  'httpshitbot.pro';
const BOT_TOKEN = process.env.BOT_TOKEN  'test_bot_token';
const LOG_FILE = path.join(__dirname, 'logs', 'bot.log');

 Log dizini kontrolü
if (!fs.existsSync(path.join(__dirname, 'logs'))) {
  fs.mkdirSync(path.join(__dirname, 'logs'), { recursive true });
}

 Log fonksiyonu
const logMessage = (message) = {
  const timestamp = new Date().toISOString();
  const logEntry = `[${timestamp}] ${message}n`;
  
  console.log(message);
  fs.appendFileSync(LOG_FILE, logEntry);
};

 Socket.io bağlantısı
const socket = io(WS_URL, {
  reconnectionDelayMax 10000,
  auth {
    token BOT_TOKEN
  }
});

 Bot durumu
let botStatus = {
  isRunning false,
  currentJob null,
  startTime null,
  stats {
    hits 0,
    fails 0,
    retries 0
  }
};

 Socket olayları
socket.on('connect', () = {
  logMessage(`Socket.io bağlantısı kuruldu. ID ${socket.id}`);
  socket.emit('bot-register', { serverId process.env.SERVER_ID  'bot-server' });
});

socket.on('disconnect', () = {
  logMessage('Socket.io bağlantısı kesildi.');
});

socket.on('bot-command', async (command) = {
  logMessage(`Komut alındı ${JSON.stringify(command)}`);
  
  if (command.action === 'start') {
    await startBot(command.params);
  } else if (command.action === 'stop') {
    await stopBot();
  } else if (command.action === 'status') {
    reportStatus();
  }
});

 Bot başlatma fonksiyonu
const startBot = async (params) = {
  if (botStatus.isRunning) {
    logMessage('Bot zaten çalışıyor!');
    return;
  }
  
  botStatus.isRunning = true;
  botStatus.startTime = new Date();
  botStatus.currentJob = params;
  botStatus.stats = { hits 0, fails 0, retries 0 };
  
  logMessage(`Bot başlatılıyor ${JSON.stringify(params)}`);
  
  try {
     Puppet işlemi başlat
    const browser = await puppeteer.launch({
      headless true,
      args [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu'
      ]
    });
    
     Rastgele aralıklı ziyaret et
    const interval = setInterval(async () = {
      try {
        const page = await browser.newPage();
        
         User-Agent ayarla
        await page.setUserAgent('Mozilla5.0 (Windows NT 10.0; Win64; x64) AppleWebKit537.36 (KHTML, like Gecko) Chrome111.0.0.0 Safari537.36');
        
         Sayfaya git
        await page.goto(params.url, { waitUntil 'networkidle2', timeout 60000 });
        
         Keyword varsa ara
        if (params.keyword) {
          await page.type('input[type=text]', params.keyword);
          await page.keyboard.press('Enter');
          await page.waitForNavigation({ waitUntil 'networkidle2' });
        }
        
         Rastgele scroll
        await autoScroll(page);
        
         2-5 saniye bekle
        await page.waitForTimeout(2000 + Math.random()  3000);
        
         İstatistik güncelle
        botStatus.stats.hits++;
        
         Sayfayı kapat
        await page.close();
        
         Socket üzerinden durum bildir
        reportStatus();
      } catch (error) {
        logMessage(`Ziyaret hatası ${error.message}`);
        botStatus.stats.fails++;
        reportStatus();
      }
    }, 2000);  2 saniyede bir ziyaret
    
     Bot çalışma süresi
    const duration = params.duration  60;  Dakika
    
     Belirtilen süre sonra bot durdur
    setTimeout(async () = {
      clearInterval(interval);
      await browser.close();
      botStatus.isRunning = false;
      botStatus.currentJob = null;
      
      logMessage(`Bot çalışması tamamlandı. Süre ${duration} dakika`);
      reportStatus();
    }, duration  60  1000);
    
  } catch (error) {
    logMessage(`Bot başlatma hatası ${error.message}`);
    botStatus.isRunning = false;
    botStatus.currentJob = null;
    reportStatus();
  }
};

 Bot durdurma fonksiyonu
const stopBot = async () = {
  if (!botStatus.isRunning) {
    logMessage('Bot zaten durdurulmuş durumda!');
    return;
  }
  
  botStatus.isRunning = false;
  botStatus.currentJob = null;
  
  logMessage('Bot durduruldu.');
  reportStatus();
};

 Durum raporu fonksiyonu
const reportStatus = () = {
  const status = {
    isRunning botStatus.isRunning,
    currentJob botStatus.currentJob,
    stats botStatus.stats,
    uptime botStatus.startTime  Math.floor((new Date() - botStatus.startTime)  1000)  0
  };
  
  socket.emit('bot-status', status);
  logMessage(`Durum güncellemesi ${JSON.stringify(status)}`);
};

 Otomatik scroll fonksiyonu
const autoScroll = async (page) = {
  await page.evaluate(async () = {
    await new Promise((resolve) = {
      let totalHeight = 0;
      const distance = 100;
      const timer = setInterval(() = {
        const scrollHeight = document.body.scrollHeight;
        window.scrollBy(0, distance);
        totalHeight += distance;
        
        if (totalHeight = scrollHeight  Math.random()  0.7) {
          clearInterval(timer);
          resolve();
        }
      }, 100);
    });
  });
};

 Ana program başlangıcı
(async () = {
  logMessage('HitBot başlatıldı.');
  
   30 saniyede bir durum güncellemesi gönder
  setInterval(() = {
    if (socket.connected) {
      reportStatus();
    }
  }, 30000);
})();
EOF

# Bot için .env dosyası oluştur
cat  opthitbot.env  'EOF'
API_URL=httpshitbot.proapi
WS_URL=httpshitbot.pro
BOT_TOKEN=test_bot_token
SERVER_ID=bot-server-1
EOF

# Bot bağımlılıklarını kur
cd opthitbot
npm install

# Bot için systemd servisi oluştur
echo Bot servisi oluşturuluyor...
cat  etcsystemdsystemhitbot.service  'EOF'
[Unit]
Description=HitBot Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=opthitbot
ExecStart=usrbinnode opthitbotbot.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=hitbot

[Install]
WantedBy=multi-user.target
EOF

# Servisi etkinleştir
systemctl daemon-reload
systemctl enable hitbot
systemctl start hitbot

# Güvenlik için firewall ayarları
echo Firewall yapılandırılıyor...
dnf install -y firewalld
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-port=3002tcp
firewall-cmd --reload

echo Bot sunucusu kurulumu tamamlandı!
echo HitBot servisi çalışıyor ve web sunucusuna bağlanmaya hazır.