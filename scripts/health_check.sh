#!/usr/bin/env bash
# Control Server v1.0 — Health Check & Diagnostics
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Uso:
#   ./health_check.sh              → Checkup rápido
#   ./health_check.sh full         → Checkup completo com logs
#   ./health_check.sh service NAME → Status de um serviço específico

set -euo pipefail

MODE="${1:-quick}"
TARGET="${2:-}"

echo "🏥 Health Check do Servidor"
echo "$(date)"
echo "================================"

# ===== SISTEMA =====
echo ""
echo "📊 SISTEMA"

UPTIME=$(uptime -p 2>/dev/null || uptime)
echo "  Uptime: $UPTIME"

# Disco
DISK_PCT=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
DISK_ICON="✅"; [[ $DISK_PCT -gt 80 ]] && DISK_ICON="⚠️"; [[ $DISK_PCT -gt 90 ]] && DISK_ICON="🚨"
echo "  $DISK_ICON Disco: ${DISK_PCT}% usado"

# Memória
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
MEM_ICON="✅"; [[ $MEM_PCT -gt 75 ]] && MEM_ICON="⚠️"; [[ $MEM_PCT -gt 90 ]] && MEM_ICON="🚨"
echo "  $MEM_ICON Memória: ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PCT}%)"

# CPU
CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
CPU_CORES=$(nproc 2>/dev/null || echo 1)
echo "  📈 CPU: load $CPU_LOAD ($CPU_CORES cores)"

# ===== SERVIÇOS =====
echo ""
echo "🔧 SERVIÇOS"

check_svc() {
    local SVC="$1" LABEL="${2:-$1}"
    if systemctl is-active "$SVC" &>/dev/null; then
        echo "  ✅ $LABEL: rodando"
    elif systemctl is-enabled "$SVC" &>/dev/null; then
        echo "  ❌ $LABEL: parado (mas habilitado)"
    elif dpkg -l | grep -q "$SVC" 2>/dev/null; then
        echo "  ⚠️ $LABEL: instalado mas não ativo"
    fi
}

check_svc "nginx" "Nginx"
check_svc "postgresql" "PostgreSQL"
check_svc "mariadb" "MariaDB/MySQL"
check_svc "redis-server" "Redis"
check_svc "docker" "Docker"
check_svc "ssh" "SSH"

# PM2
if command -v pm2 &>/dev/null; then
    PM2_COUNT=$(pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d))" 2>/dev/null || echo "0")
    PM2_ONLINE=$(pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(sum(1 for p in d if p.get('pm2_env',{}).get('status')=='online'))" 2>/dev/null || echo "0")
    echo "  📦 PM2: $PM2_ONLINE/$PM2_COUNT processos online"
fi

# Docker
if command -v docker &>/dev/null; then
    DOCK_RUN=$(docker ps -q 2>/dev/null | wc -l || echo "0")
    DOCK_STOP=$(docker ps -aq --filter "status=exited" 2>/dev/null | wc -l || echo "0")
    echo "  🐳 Docker: $DOCK_RUN rodando, $DOCK_STOP parados"
fi

# ===== FIREWALL =====
echo ""
echo "🛡️ FIREWALL"
UFW_STATUS=$(ufw status 2>/dev/null | head -1)
echo "  Status: $UFW_STATUS"
OPEN_PORTS=$(ufw status 2>/dev/null | grep "ALLOW" | awk '{print $1}' | sort -u | tr '\n' ', ' | sed 's/,$//')
echo "  Portas ALLOW: ${OPEN_PORTS:-nenhuma}"

# ===== SERVIÇOS COM FALHA =====
echo ""
echo "❌ FALHAS"
FAILED=$(systemctl --failed --no-legend 2>/dev/null | wc -l || echo "0")
if [[ $FAILED -gt 0 ]]; then
    echo "  $FAILED serviço(s) com falha:"
    systemctl --failed --no-legend 2>/dev/null | while read -r line; do
        echo "    ❌ $line"
    done
else
    echo "  ✅ Nenhum serviço com falha"
fi

# ===== LOGS (modo full) =====
if [[ "$MODE" == "full" ]]; then
    echo ""
    echo "📋 LOGS (última hora)"
    
    ERRORS=$(journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | wc -l || echo "0")
    echo "  Erros no journal: $ERRORS"
    
    OOM=$(dmesg 2>/dev/null | grep -ci "out of memory\|oom" || echo "0")
    echo "  Eventos OOM: $OOM"
    
    if [[ -f /var/log/nginx/error.log ]]; then
        NGX_ERR=$(tail -500 /var/log/nginx/error.log 2>/dev/null | grep -c "error\|crit" || echo "0")
        echo "  Erros Nginx: $NGX_ERR"
    fi
    
    if [[ -f /var/log/auth.log ]]; then
        SSH_FAIL=$(tail -500 /var/log/auth.log 2>/dev/null | grep -c "Failed password" || echo "0")
        echo "  Tentativas SSH falhas: $SSH_FAIL"
    fi
    
    # Top 5 processos por memória
    echo ""
    echo "📊 TOP 5 PROCESSOS (memória)"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %s %s%% MEM %s%% CPU\n", $11, $4, $3}'
fi

# ===== SERVIÇO ESPECÍFICO =====
if [[ "$MODE" == "service" && -n "$TARGET" ]]; then
    echo ""
    echo "🔍 Detalhes: $TARGET"
    systemctl status "$TARGET" --no-pager 2>&1 | head -20
    echo ""
    echo "📋 Últimas linhas de log:"
    journalctl -u "$TARGET" -n 20 --no-pager 2>/dev/null || echo "  (sem logs)"
fi

echo ""
echo "================================"
echo "✅ Health check concluído"
