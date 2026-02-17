# Guia de Instalação e Configuração de Serviços Comuns

## Índice
1. [PostgreSQL](#postgresql)
2. [Redis](#redis)
3. [Nginx](#nginx)
4. [Docker](#docker)
5. [Node.js](#nodejs)
6. [PM2](#pm2)
7. [Certbot/SSL](#certbot)
8. [UFW Firewall](#ufw)
9. [Fail2ban](#fail2ban)
10. [MongoDB](#mongodb)

---

## PostgreSQL

### Pós-instalação
```bash
# Criar novo banco de dados
sudo -u postgres createdb nome_do_banco

# Criar novo usuário
sudo -u postgres createuser --interactive

# Criar banco com dono específico
sudo -u postgres psql -c "CREATE DATABASE meubanco OWNER meuuser;"

# Dar permissões
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE meubanco TO meuuser;"
```

### Configuração de acesso remoto
```bash
# Editar postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf
# Alterar: listen_addresses = '*'

# Editar pg_hba.conf — adicionar linha:
# host    all    all    0.0.0.0/0    md5

# Reiniciar
sudo systemctl restart postgresql
```

### Backup e Restore
```bash
# Backup
pg_dump -U postgres -h localhost nome_do_banco > backup.sql

# Restore
psql -U postgres -h localhost nome_do_banco < backup.sql

# Backup comprimido
pg_dump -U postgres -Fc nome_do_banco > backup.dump

# Restore comprimido
pg_restore -U postgres -d nome_do_banco backup.dump
```

### Connection String
```
postgresql://USER:PASSWORD@HOST:PORT/DATABASE
```

---

## Redis

### Comandos úteis
```bash
# Testar conexão
redis-cli -a SENHA ping

# Ver informações
redis-cli -a SENHA info

# Monitorar comandos em tempo real
redis-cli -a SENHA monitor

# Flush (CUIDADO - apaga tudo)
redis-cli -a SENHA FLUSHALL
```

### Configuração de persistência
```bash
# Editar /etc/redis/redis.conf
# RDB (snapshot):
save 900 1
save 300 10
save 60 10000

# AOF (append-only):
appendonly yes
appendfsync everysec
```

### Connection String
```
redis://:PASSWORD@HOST:PORT/DB_NUMBER
```

---

## Nginx

### Criar novo site (virtual host)
```bash
sudo tee /etc/nginx/sites-available/meusite <<'EOF'
server {
    listen 80;
    server_name meudominio.com www.meudominio.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Ativar site
sudo ln -s /etc/nginx/sites-available/meusite /etc/nginx/sites-enabled/

# Testar configuração
sudo nginx -t

# Recarregar
sudo systemctl reload nginx
```

### Servir arquivos estáticos
```nginx
server {
    listen 80;
    server_name static.meudominio.com;
    root /var/www/meusite;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

---

## Docker

### Comandos essenciais
```bash
# Listar containers
docker ps -a

# Logs
docker logs --tail 100 -f CONTAINER_NAME

# Executar comando em container rodando
docker exec -it CONTAINER_NAME bash

# Docker Compose
docker compose up -d
docker compose down
docker compose logs -f
docker compose ps

# Limpar recursos não utilizados
docker system prune -a
```

### Docker Compose básico
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    
  db:
    image: postgres:16
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    restart: unless-stopped

volumes:
  pgdata:
```

---

## Node.js

### Gerenciamento de versões com NVM
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts
```

---

## PM2

### Comandos essenciais
```bash
# Iniciar aplicação
pm2 start app.js --name "minha-app"

# Iniciar com ecosystem
pm2 start ecosystem.config.js

# Listar processos
pm2 list

# Logs
pm2 logs

# Monitorar
pm2 monit

# Reiniciar
pm2 restart all

# Salvar lista de processos
pm2 save

# Restaurar após reboot
pm2 resurrect
```

### Ecosystem file
```javascript
module.exports = {
  apps: [{
    name: 'minha-app',
    script: 'app.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

---

## Certbot

### SSL com Nginx
```bash
sudo certbot --nginx -d meudominio.com -d www.meudominio.com

# Renovação automática (já configurado por padrão)
sudo certbot renew --dry-run

# Verificar timer de renovação
sudo systemctl status certbot.timer
```

### SSL standalone
```bash
sudo certbot certonly --standalone -d meudominio.com
```

---

## UFW

### Regras comuns
```bash
# Permitir porta específica
sudo ufw allow 3000

# Permitir de IP específico
sudo ufw allow from 192.168.1.0/24

# Permitir serviço
sudo ufw allow 'Nginx Full'
sudo ufw allow 'OpenSSH'

# Negar porta
sudo ufw deny 3306

# Ver status
sudo ufw status verbose

# Remover regra
sudo ufw delete allow 3000
```

---

## Fail2ban

### Verificar status
```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Desbanir IP
sudo fail2ban-client set sshd unbanip IP_ADDRESS
```

---

## MongoDB

### Comandos básicos
```bash
# Conectar
mongosh -u admin -p SENHA --authenticationDatabase admin

# Criar banco e coleção
use meu_banco
db.createCollection("minha_colecao")

# Operações CRUD
db.colecao.insertOne({nome: "teste"})
db.colecao.find()
db.colecao.updateOne({nome: "teste"}, {$set: {valor: 42}})
db.colecao.deleteOne({nome: "teste"})
```

### Connection String
```
mongodb://USER:PASSWORD@HOST:PORT/DATABASE?authSource=admin
```
