#!/usr/bin/env bash
# Control Server v1.0 — Health Check
# Criado por BollaNetwork
set -euo pipefail
M="${1:-quick}"; T="${2:-}"
echo "🏥 Health Check — $(date)"
echo "================================"
echo "📊 SISTEMA"
echo "  Uptime: $(uptime -p 2>/dev/null||uptime)"
DP=$(df -h /|tail -1|awk '{print $5}'|tr -d '%'); DI="✅"; [[ $DP -gt 80 ]] && DI="⚠️"; [[ $DP -gt 90 ]] && DI="🚨"
echo "  $DI Disco: ${DP}%"
MT=$(free -m|awk '/^Mem:/{print $2}'); MU=$(free -m|awk '/^Mem:/{print $3}'); MP=$((MU*100/MT)); MI="✅"; [[ $MP -gt 75 ]] && MI="⚠️"; [[ $MP -gt 90 ]] && MI="🚨"
echo "  $MI RAM: ${MU}MB/${MT}MB (${MP}%)"
echo "  📈 CPU: load $(cat /proc/loadavg|awk '{print $1}') ($(nproc 2>/dev/null||echo 1) cores)"
echo ""; echo "🔧 SERVIÇOS"
for s in nginx:Nginx postgresql:PostgreSQL mariadb:MariaDB redis-server:Redis docker:Docker ssh:SSH; do
    N="${s%%:*}"; L="${s##*:}"
    systemctl is-active "$N" &>/dev/null && echo "  ✅ $L" || { systemctl is-enabled "$N" &>/dev/null && echo "  ❌ $L: parado"; }; done
command -v pm2 &>/dev/null && { C=$(pm2 jlist 2>/dev/null|python3 -c "import sys,json;d=json.load(sys.stdin);print(f'{sum(1 for p in d if p.get(\"pm2_env\",{}).get(\"status\")==\"online\")}/{len(d)}')" 2>/dev/null||echo "?"); echo "  📦 PM2: $C online"; }
echo ""; echo "🛡️ FIREWALL: $(ufw status 2>/dev/null|head -1)"
echo ""; F=$(systemctl --failed --no-legend 2>/dev/null|wc -l||echo 0)
[[ $F -gt 0 ]] && { echo "❌ $F serviço(s) com falha:"; systemctl --failed --no-legend 2>/dev/null; } || echo "✅ Sem falhas"
[[ "$M" == "full" ]] && { echo ""; echo "📋 LOGS (1h)"
    echo "  Erros journal: $(journalctl -p err --since '1 hour ago' --no-pager 2>/dev/null|wc -l||echo 0)"
    echo "  OOM: $(dmesg 2>/dev/null|grep -ci 'out of memory\|oom'||echo 0)"
    [[ -f /var/log/auth.log ]] && echo "  SSH falhas: $(tail -500 /var/log/auth.log 2>/dev/null|grep -c 'Failed password'||echo 0)"; }
[[ "$M" == "service" && -n "$T" ]] && { echo ""; systemctl status "$T" --no-pager 2>&1|head -20; }
echo ""; echo "================================"
