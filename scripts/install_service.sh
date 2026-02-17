#!/usr/bin/env bash
# install_service.sh — Instalador de serviços comuns com logging e salvamento de credenciais
# Uso: bash install_service.sh --service [nome] --log-dir /path/logs --cred-dir /path/credentials

set -euo pipefail

SERVICE=""
LOG_DIR=""
CRED_DIR=""
EXTRA_ARGS=""

# === PARSE ARGS ===
while [[ $# -gt 0 ]]; do
    case $1 in
        --service)  SERVICE="$2"; shift 2 ;;
        --log-dir)  LOG_DIR="$2"; shift 2 ;;
        --cred-dir) CRED_DIR="$2"; shift 2 ;;
        --args)     EXTRA_ARGS="$2"; shift 2 ;;
        *) echo "ERRO: Argumento desconhecido: $1"; exit 1 ;;
    esac
done

if [ -z "$SERVICE" ]; then
    echo "ERRO: --service é obrigatório"
    echo "Serviços disponíveis: postgresql, redis, nginx, docker, nodejs, python3, certbot, ufw, fail2ban, pm2, mongodb, git"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# === FUNÇÕES AUXILIARES ===
log_action() {
    local msg="$1"
    echo "[$TIMESTAMP] [INSTALL:$SERVICE] $msg"
    if [ -n "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        echo "[$TIMESTAMP] [INSTALL:$SERVICE] $msg" >> "$LOG_DIR/$(date '+%Y-%m-%d').log"
    fi
}

save_credential() {
    local key="$1"
    local value="$2"
    if [ -n "$CRED_DIR" ]; then
        bash "$SCRIPT_DIR/credential_manager.sh" --action save --service "$SERVICE" --key "$key" --value "$value" --cred-dir "$CRED_DIR"
    fi
}

check_installed() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

generate_password() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

# === INSTALADORES ===

install_postgresql() {
    log_action "Iniciando instalação do PostgreSQL..."
    
    if [ "$(check_installed psql)" == "true" ]; then
        log_action "PostgreSQL já está instalado. Verificando status..."
        sudo systemctl status postgresql --no-pager || true
        return 0
    fi
    
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    
    # Iniciar e habilitar
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Gerar senha para o usuário postgres
    PG_PASS=$(generate_password)
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_PASS';"
    
    # Salvar credenciais
    save_credential "user" "postgres"
    save_credential "password" "$PG_PASS"
    save_credential "host" "localhost"
    save_credential "port" "5432"
    
    # Configurar pg_hba.conf para aceitar conexões locais com senha
    PG_HBA=$(sudo -u postgres psql -t -c "SHOW hba_file;" | tr -d ' ')
    if [ -n "$PG_HBA" ]; then
        # Adicionar linha para autenticação md5 local se não existir
        if ! sudo grep -q "local.*all.*all.*md5" "$PG_HBA"; then
            sudo sed -i 's/local\s*all\s*all\s*peer/local   all             all                                     md5/' "$PG_HBA"
            sudo systemctl reload postgresql
        fi
    fi
    
    log_action "PostgreSQL instalado com sucesso. Credenciais salvas em $CRED_DIR"
    
    echo ""
    echo "=== POSTGRESQL INSTALADO ==="
    echo "Usuário: postgres"
    echo "Host: localhost"
    echo "Porta: 5432"
    echo "Senha: [salva no credential_manager]"
    echo "Conectar: psql -U postgres -h localhost"
    echo "==========================="
}

install_redis() {
    log_action "Iniciando instalação do Redis..."
    
    if [ "$(check_installed redis-server)" == "true" ]; then
        log_action "Redis já está instalado."
        sudo systemctl status redis-server --no-pager || sudo systemctl status redis --no-pager || true
        return 0
    fi
    
    sudo apt-get update
    sudo apt-get install -y redis-server
    
    # Gerar senha
    REDIS_PASS=$(generate_password)
    
    # Configurar senha e bind
    sudo sed -i "s/# requirepass foobared/requirepass $REDIS_PASS/" /etc/redis/redis.conf
    sudo sed -i "s/bind 127.0.0.1 ::1/bind 127.0.0.1/" /etc/redis/redis.conf 2>/dev/null || true
    
    sudo systemctl restart redis-server
    sudo systemctl enable redis-server
    
    save_credential "password" "$REDIS_PASS"
    save_credential "host" "127.0.0.1"
    save_credential "port" "6379"
    
    log_action "Redis instalado com sucesso."
    
    echo ""
    echo "=== REDIS INSTALADO ==="
    echo "Host: 127.0.0.1"
    echo "Porta: 6379"
    echo "Senha: [salva no credential_manager]"
    echo "Testar: redis-cli -a '[senha]' ping"
    echo "========================"
}

install_nginx() {
    log_action "Iniciando instalação do Nginx..."
    
    if [ "$(check_installed nginx)" == "true" ]; then
        log_action "Nginx já está instalado."
        sudo systemctl status nginx --no-pager || true
        return 0
    fi
    
    sudo apt-get update
    sudo apt-get install -y nginx
    
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # Abrir firewall se ufw estiver ativo
    if command -v ufw &> /dev/null; then
        sudo ufw allow 'Nginx Full' 2>/dev/null || true
    fi
    
    save_credential "config_dir" "/etc/nginx"
    save_credential "sites_available" "/etc/nginx/sites-available"
    save_credential "sites_enabled" "/etc/nginx/sites-enabled"
    save_credential "webroot" "/var/www/html"
    
    log_action "Nginx instalado com sucesso."
    
    echo ""
    echo "=== NGINX INSTALADO ==="
    echo "Config: /etc/nginx/nginx.conf"
    echo "Sites: /etc/nginx/sites-available/"
    echo "Webroot: /var/www/html/"
    echo "Status: sudo systemctl status nginx"
    echo "========================"
}

install_docker() {
    log_action "Iniciando instalação do Docker..."
    
    if [ "$(check_installed docker)" == "true" ]; then
        log_action "Docker já está instalado."
        docker --version
        return 0
    fi
    
    # Instalar dependências
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Adicionar chave GPG do Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Adicionar repositório
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Adicionar usuário atual ao grupo docker
    sudo usermod -aG docker $(whoami) 2>/dev/null || true
    
    sudo systemctl start docker
    sudo systemctl enable docker
    
    save_credential "socket" "/var/run/docker.sock"
    save_credential "config_dir" "/etc/docker"
    
    log_action "Docker instalado com sucesso."
    
    echo ""
    echo "=== DOCKER INSTALADO ==="
    echo "Versão: $(docker --version)"
    echo "Compose: docker compose version"
    echo "NOTA: Faça logout/login para usar docker sem sudo"
    echo "========================"
}

install_nodejs() {
    log_action "Iniciando instalação do Node.js (LTS)..."
    
    if [ "$(check_installed node)" == "true" ]; then
        log_action "Node.js já está instalado: $(node --version)"
        return 0
    fi
    
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # Instalar gerenciador de pacotes global
    sudo npm install -g npm@latest
    
    save_credential "version" "$(node --version)"
    save_credential "npm_version" "$(npm --version)"
    
    log_action "Node.js $(node --version) instalado com sucesso."
    
    echo ""
    echo "=== NODE.JS INSTALADO ==="
    echo "Node: $(node --version)"
    echo "NPM: $(npm --version)"
    echo "========================="
}

install_python3() {
    log_action "Iniciando instalação do Python 3..."
    
    if [ "$(check_installed python3)" == "true" ]; then
        log_action "Python 3 já está instalado: $(python3 --version)"
        return 0
    fi
    
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv python3-dev
    
    save_credential "version" "$(python3 --version)"
    
    log_action "Python 3 instalado com sucesso."
}

install_certbot() {
    log_action "Iniciando instalação do Certbot..."
    
    if [ "$(check_installed certbot)" == "true" ]; then
        log_action "Certbot já está instalado."
        return 0
    fi
    
    sudo apt-get update
    sudo apt-get install -y certbot
    
    # Plugin nginx se nginx estiver instalado
    if [ "$(check_installed nginx)" == "true" ]; then
        sudo apt-get install -y python3-certbot-nginx
    fi
    
    log_action "Certbot instalado com sucesso."
    echo "Uso: sudo certbot --nginx -d seudominio.com"
}

install_ufw() {
    log_action "Iniciando configuração do UFW..."
    
    sudo apt-get update
    sudo apt-get install -y ufw
    
    # Regras básicas
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    
    log_action "UFW configurado. ATENÇÃO: Não habilitado automaticamente. Use 'sudo ufw enable' quando pronto."
    
    echo ""
    echo "=== UFW CONFIGURADO ==="
    echo "Regras padrão: deny incoming, allow outgoing"
    echo "SSH permitido"
    echo "ATIVAR: sudo ufw enable"
    echo "STATUS: sudo ufw status"
    echo "========================"
}

install_fail2ban() {
    log_action "Iniciando instalação do Fail2ban..."
    
    sudo apt-get update
    sudo apt-get install -y fail2ban
    
    # Criar configuração local
    if [ ! -f /etc/fail2ban/jail.local ]; then
        sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        # Configuração básica de SSH
        sudo tee -a /etc/fail2ban/jail.local > /dev/null <<JAILEOF

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
JAILEOF
    fi
    
    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban
    
    log_action "Fail2ban instalado e configurado."
}

install_pm2() {
    log_action "Iniciando instalação do PM2..."
    
    if [ "$(check_installed pm2)" == "true" ]; then
        log_action "PM2 já está instalado."
        return 0
    fi
    
    # Verificar se npm está disponível
    if [ "$(check_installed npm)" != "true" ]; then
        log_action "npm não encontrado. Instalando Node.js primeiro..."
        install_nodejs
    fi
    
    sudo npm install -g pm2
    
    # Configurar startup
    pm2 startup systemd -u $(whoami) --hp $HOME 2>/dev/null || true
    
    log_action "PM2 instalado com sucesso."
}

install_mongodb() {
    log_action "Iniciando instalação do MongoDB..."
    
    if [ "$(check_installed mongod)" == "true" ]; then
        log_action "MongoDB já está instalado."
        return 0
    fi
    
    sudo apt-get update
    sudo apt-get install -y gnupg curl
    
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    
    sudo systemctl start mongod
    sudo systemctl enable mongod
    
    MONGO_PASS=$(generate_password)
    
    # Criar usuário admin
    mongosh admin --eval "
        db.createUser({
            user: 'admin',
            pwd: '$MONGO_PASS',
            roles: [{ role: 'root', db: 'admin' }]
        })
    " 2>/dev/null || true
    
    save_credential "user" "admin"
    save_credential "password" "$MONGO_PASS"
    save_credential "host" "localhost"
    save_credential "port" "27017"
    
    log_action "MongoDB instalado com sucesso."
}

install_git() {
    log_action "Instalando Git..."
    sudo apt-get update
    sudo apt-get install -y git
    log_action "Git $(git --version) instalado."
}

# === DISPATCH ===
case "$SERVICE" in
    postgresql|postgres|pg)   install_postgresql ;;
    redis)                    install_redis ;;
    nginx)                    install_nginx ;;
    docker)                   install_docker ;;
    nodejs|node)              install_nodejs ;;
    python3|python)           install_python3 ;;
    certbot|letsencrypt)      install_certbot ;;
    ufw|firewall)             install_ufw ;;
    fail2ban)                 install_fail2ban ;;
    pm2)                      install_pm2 ;;
    mongodb|mongo)            install_mongodb ;;
    git)                      install_git ;;
    *)
        echo "ERRO: Serviço '$SERVICE' não reconhecido."
        echo ""
        echo "Serviços disponíveis:"
        echo "  postgresql (pg)  - Banco de dados relacional"
        echo "  redis            - Cache e message broker"
        echo "  nginx            - Web server / reverse proxy"
        echo "  docker           - Container runtime"
        echo "  nodejs (node)    - Runtime JavaScript"
        echo "  python3          - Python 3 + pip + venv"
        echo "  certbot          - SSL/TLS certificates"
        echo "  ufw              - Firewall"
        echo "  fail2ban         - Proteção contra brute force"
        echo "  pm2              - Process manager para Node.js"
        echo "  mongodb (mongo)  - Banco de dados NoSQL"
        echo "  git              - Version control"
        echo ""
        echo "Para pacotes avulsos, use execute.sh com apt-get install"
        exit 1
        ;;
esac

log_action "Instalação de '$SERVICE' concluída com sucesso."
exit 0
