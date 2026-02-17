#!/usr/bin/env bash
# Control Server v1.0 — Service Installer
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Instala e configura serviços comuns com credenciais salvas no vault
# Uso:
#   ./service_install.sh postgresql [db_name] [db_user]
#   ./service_install.sh mysql [db_name] [db_user]
#   ./service_install.sh redis
#   ./service_install.sh nginx
#   ./service_install.sh certbot
#   ./service_install.sh node [version]
#   ./service_install.sh pm2
#   ./service_install.sh docker

set -euo pipefail

SERVICE="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="${HOME}/.openclaw/skills/control-server"
LOG_FILE="${SKILL_DIR}/logs/installs.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_install() { echo "[$(date -Iseconds)] [INSTALL] $*" >> "$LOG_FILE"; }

generate_pass() {
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 24
}

check_installed() {
    local PKG="$1"
    if dpkg -l "$PKG" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    return 1
}

if [[ -z "$SERVICE" ]]; then
    echo "Uso: service_install.sh <serviço> [args...]"
    echo "Serviços: postgresql mysql redis nginx certbot node pm2 docker"
    exit 1
fi

case "$SERVICE" in
    postgresql|postgres|pg)
        DB_NAME="${ARG2:-}"
        DB_USER="${ARG3:-}"
        
        if ! check_installed "postgresql"; then
            echo "📦 Instalando PostgreSQL..."
            apt update -qq && apt install postgresql postgresql-contrib -y
            systemctl enable postgresql
            systemctl start postgresql
            log_install "package=postgresql status=installed"
            echo "✅ PostgreSQL instalado"
        else
            echo "ℹ️ PostgreSQL já está instalado"
        fi
        
        if [[ -n "$DB_NAME" ]]; then
            DB_USER="${DB_USER:-${DB_NAME}_user}"
            PASSWORD=$(generate_pass)
            
            echo "📦 Criando banco: $DB_NAME (user: $DB_USER)"
            
            sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
                sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$PASSWORD';"
            
            sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
                sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
            
            sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
            
            # Salvar no vault
            "$SCRIPT_DIR/vault.sh" save "postgresql_${DB_NAME}" "host" "localhost"
            "$SCRIPT_DIR/vault.sh" save "postgresql_${DB_NAME}" "port" "5432"
            "$SCRIPT_DIR/vault.sh" save "postgresql_${DB_NAME}" "db_name" "$DB_NAME"
            "$SCRIPT_DIR/vault.sh" save "postgresql_${DB_NAME}" "user" "$DB_USER"
            "$SCRIPT_DIR/vault.sh" save "postgresql_${DB_NAME}" "password" "$PASSWORD"
            
            log_install "package=postgresql_db db=$DB_NAME user=$DB_USER status=created"
            
            echo "✅ Banco criado!"
            echo "  Host: localhost"
            echo "  Port: 5432"
            echo "  Database: $DB_NAME"
            echo "  User: $DB_USER"
            echo "  Password: (salva no vault)"
            echo ""
            echo "Connection string: postgresql://${DB_USER}:****@localhost:5432/${DB_NAME}"
            echo ""
            echo "Para .env:"
            echo "  DATABASE_URL=postgresql://${DB_USER}:${PASSWORD}@localhost:5432/${DB_NAME}"
        fi
        ;;
    
    mysql|mariadb)
        DB_NAME="${ARG2:-}"
        DB_USER="${ARG3:-}"
        
        if ! check_installed "mariadb-server"; then
            echo "📦 Instalando MariaDB..."
            apt update -qq && apt install mariadb-server -y
            systemctl enable mariadb
            systemctl start mariadb
            log_install "package=mariadb status=installed"
            echo "✅ MariaDB instalado"
        else
            echo "ℹ️ MariaDB já está instalado"
        fi
        
        if [[ -n "$DB_NAME" ]]; then
            DB_USER="${DB_USER:-${DB_NAME}_user}"
            PASSWORD=$(generate_pass)
            
            echo "📦 Criando banco: $DB_NAME"
            
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
            mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$PASSWORD';"
            mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
            mysql -u root -e "FLUSH PRIVILEGES;"
            
            "$SCRIPT_DIR/vault.sh" save "mysql_${DB_NAME}" "host" "localhost"
            "$SCRIPT_DIR/vault.sh" save "mysql_${DB_NAME}" "port" "3306"
            "$SCRIPT_DIR/vault.sh" save "mysql_${DB_NAME}" "db_name" "$DB_NAME"
            "$SCRIPT_DIR/vault.sh" save "mysql_${DB_NAME}" "user" "$DB_USER"
            "$SCRIPT_DIR/vault.sh" save "mysql_${DB_NAME}" "password" "$PASSWORD"
            
            log_install "package=mysql_db db=$DB_NAME user=$DB_USER status=created"
            
            echo "✅ Banco criado!"
            echo "  Database: $DB_NAME | User: $DB_USER | Password: (vault)"
        fi
        ;;
    
    redis)
        if ! check_installed "redis-server"; then
            echo "📦 Instalando Redis..."
            apt update -qq && apt install redis-server -y
            systemctl enable redis-server
            
            PASSWORD=$(generate_pass)
            # Configurar senha
            sed -i "s/^# requirepass .*/requirepass $PASSWORD/" /etc/redis/redis.conf 2>/dev/null || \
                echo "requirepass $PASSWORD" >> /etc/redis/redis.conf
            
            systemctl restart redis-server
            
            "$SCRIPT_DIR/vault.sh" save "redis" "host" "localhost"
            "$SCRIPT_DIR/vault.sh" save "redis" "port" "6379"
            "$SCRIPT_DIR/vault.sh" save "redis" "password" "$PASSWORD"
            
            log_install "package=redis status=installed password=vault"
            echo "✅ Redis instalado com senha (salva no vault)"
        else
            echo "ℹ️ Redis já está instalado"
        fi
        ;;
    
    nginx)
        if ! check_installed "nginx"; then
            echo "📦 Instalando Nginx..."
            apt update -qq && apt install nginx -y
            systemctl enable nginx
            systemctl start nginx
            log_install "package=nginx status=installed"
            echo "✅ Nginx instalado"
        else
            echo "ℹ️ Nginx já está instalado"
        fi
        ;;
    
    certbot|ssl)
        echo "📦 Instalando Certbot..."
        apt update -qq && apt install certbot python3-certbot-nginx -y
        log_install "package=certbot status=installed"
        echo "✅ Certbot instalado"
        ;;
    
    node|nodejs)
        VERSION="${ARG2:-20}"
        if ! command -v node &>/dev/null; then
            echo "📦 Instalando Node.js $VERSION via nvm..."
            export NVM_DIR="$HOME/.nvm"
            if [[ ! -d "$NVM_DIR" ]]; then
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            fi
            source "$NVM_DIR/nvm.sh" 2>/dev/null
            nvm install "$VERSION"
            nvm alias default "$VERSION"
            log_install "package=nodejs version=$VERSION method=nvm status=installed"
            echo "✅ Node.js $VERSION instalado"
        else
            echo "ℹ️ Node.js já instalado: $(node -v)"
        fi
        ;;
    
    pm2)
        if ! command -v pm2 &>/dev/null; then
            echo "📦 Instalando PM2..."
            npm install -g pm2
            pm2 startup 2>/dev/null || true
            log_install "package=pm2 status=installed"
            echo "✅ PM2 instalado"
        else
            echo "ℹ️ PM2 já instalado: $(pm2 -v)"
        fi
        ;;
    
    docker)
        if ! command -v docker &>/dev/null; then
            echo "📦 Instalando Docker..."
            curl -fsSL https://get.docker.com | sh
            systemctl enable docker
            usermod -aG docker "$USER" 2>/dev/null || true
            log_install "package=docker status=installed"
            echo "✅ Docker instalado (relogue para usar sem sudo)"
        else
            echo "ℹ️ Docker já instalado: $(docker -v)"
        fi
        ;;
    
    *)
        echo "Serviço desconhecido: $SERVICE"
        echo "Disponíveis: postgresql mysql redis nginx certbot node pm2 docker"
        exit 1
        ;;
esac
