#!/usr/bin/env bash
# Control Server v1.0 — Service Installer
# Criado por BollaNetwork
set -euo pipefail
SVC="${1:-}"; A2="${2:-}"; A3="${3:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"
LF="${HOME}/.openclaw/skills/control-server/logs/installs.log"
mkdir -p "$(dirname "$LF")"; touch "$LF"
li() { echo "[$(date -Iseconds)] [INSTALL] $*" >> "$LF"; }
gp() { openssl rand -base64 48|tr -dc 'a-zA-Z0-9'|head -c 24; }
chk() { dpkg -l "$1" 2>/dev/null|grep -q "^ii"; }
[[ -z "$SVC" ]] && { echo "Uso: service_install.sh <postgresql|mysql|redis|nginx|certbot|node|pm2|docker> [args]"; exit 1; }
case "$SVC" in
    postgresql|postgres|pg)
        chk postgresql || { apt update -qq && apt install postgresql postgresql-contrib -y; systemctl enable postgresql; systemctl start postgresql; li "postgresql installed"; echo "✅ PostgreSQL instalado"; }
        [[ -n "$A2" ]] && {
            DB="$A2"; U="${A3:-${DB}_user}"; PW=$(gp)
            sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$U'"|grep -q 1 || sudo -u postgres psql -c "CREATE USER $U WITH PASSWORD '$PW';"
            sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB'"|grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE $DB OWNER $U;"
            sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB TO $U;"
            "$DIR/vault.sh" save "pg_${DB}" host localhost; "$DIR/vault.sh" save "pg_${DB}" port 5432
            "$DIR/vault.sh" save "pg_${DB}" db_name "$DB"; "$DIR/vault.sh" save "pg_${DB}" user "$U"; "$DIR/vault.sh" save "pg_${DB}" password "$PW"
            li "pg_db=$DB user=$U"; echo "✅ DB $DB criado (senha no vault)"
            echo "DATABASE_URL=postgresql://${U}:${PW}@localhost:5432/${DB}"; } ;;
    mysql|mariadb)
        chk mariadb-server || { apt update -qq && apt install mariadb-server -y; systemctl enable mariadb; systemctl start mariadb; li "mariadb installed"; echo "✅ MariaDB instalado"; }
        [[ -n "$A2" ]] && {
            DB="$A2"; U="${A3:-${DB}_user}"; PW=$(gp)
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB\`;"
            mysql -u root -e "CREATE USER IF NOT EXISTS '$U'@'localhost' IDENTIFIED BY '$PW';"
            mysql -u root -e "GRANT ALL ON \`$DB\`.* TO '$U'@'localhost'; FLUSH PRIVILEGES;"
            "$DIR/vault.sh" save "mysql_${DB}" host localhost; "$DIR/vault.sh" save "mysql_${DB}" port 3306
            "$DIR/vault.sh" save "mysql_${DB}" db_name "$DB"; "$DIR/vault.sh" save "mysql_${DB}" user "$U"; "$DIR/vault.sh" save "mysql_${DB}" password "$PW"
            li "mysql_db=$DB user=$U"; echo "✅ DB $DB criado (senha no vault)"; } ;;
    redis)
        chk redis-server || { apt update -qq && apt install redis-server -y; systemctl enable redis-server
            PW=$(gp); sed -i "s/^# requirepass .*/requirepass $PW/" /etc/redis/redis.conf 2>/dev/null || echo "requirepass $PW" >> /etc/redis/redis.conf
            systemctl restart redis-server
            "$DIR/vault.sh" save redis host localhost; "$DIR/vault.sh" save redis port 6379; "$DIR/vault.sh" save redis password "$PW"
            li "redis installed"; echo "✅ Redis instalado (senha no vault)"; } ;;
    nginx) chk nginx || { apt update -qq && apt install nginx -y; systemctl enable nginx; systemctl start nginx; li "nginx installed"; echo "✅ Nginx instalado"; } ;;
    certbot|ssl) apt update -qq && apt install certbot python3-certbot-nginx -y; li "certbot installed"; echo "✅ Certbot instalado" ;;
    node|nodejs) V="${A2:-20}"
        command -v node &>/dev/null && { echo "ℹ️ Node $(node -v) já instalado"; exit 0; }
        export NVM_DIR="$HOME/.nvm"
        [[ ! -d "$NVM_DIR" ]] && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        source "$NVM_DIR/nvm.sh" 2>/dev/null; nvm install "$V"; nvm alias default "$V"
        li "node=$V"; echo "✅ Node.js $V instalado" ;;
    pm2) command -v pm2 &>/dev/null && { echo "ℹ️ PM2 $(pm2 -v) já instalado"; exit 0; }
        npm install -g pm2; pm2 startup 2>/dev/null||true; li "pm2 installed"; echo "✅ PM2 instalado" ;;
    docker) command -v docker &>/dev/null && { echo "ℹ️ Docker já instalado"; exit 0; }
        curl -fsSL https://get.docker.com|sh; systemctl enable docker; usermod -aG docker "$USER" 2>/dev/null||true
        li "docker installed"; echo "✅ Docker instalado" ;;
    *) echo "Desconhecido: $SVC"; exit 1 ;;
esac
