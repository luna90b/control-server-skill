#!/usr/bin/env bash
# Control Server v1.0 — Port Auditor
# Criado por BollaNetwork
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SC=$("$DIR/guardian.sh" scan 2>/dev/null||echo '{}')
SP=$(echo "$SC"|grep -oP '"ssh":\s*"\K[^"]+' ||echo "22")
GP=$(echo "$SC"|grep -oP '"gw":\s*"\K[^"]+' ||echo "18789")
PP=("$SP" "$GP" "5353")
ip() { for p in "${PP[@]}"; do [[ "$1" == "$p" ]] && return 0; done; return 1; }
ufw status 2>/dev/null|head -1|grep -qi "inactive" && { echo "UFW inativo"; exit 0; }
echo "🔍 Auditoria (SSH=$SP, OC=$GP protegidos)"
ORP=()
while IFS= read -r line; do
    PT=$(echo "$line"|awk '{print $1}'|grep -oE '^[0-9]+'||true); [[ -z "$PT" ]] && continue
    ip "$PT" && { echo "  🔒 $PT — Protegida"; continue; }
    if ss -tlnp 2>/dev/null|grep -q ":${PT} "||ss -ulnp 2>/dev/null|grep -q ":${PT} "; then
        PR=$(ss -tlnp 2>/dev/null|grep ":${PT} "|grep -oP 'users:\(\("\K[^"]+'||echo "ativo")
        echo "  ✅ $PT — $PR"
    else echo "  ⚠️  $PT — ÓRFÃ"; ORP+=("$PT"); fi
done < <(ufw status 2>/dev/null|grep "ALLOW")
echo ""; echo "📊 ${#ORP[@]} órfã(s)"
