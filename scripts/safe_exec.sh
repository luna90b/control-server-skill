#!/usr/bin/env bash
# Control Server v1.0 — Safe Executor
# Criado por BollaNetwork
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SD="${HOME}/.openclaw/skills/control-server"
mkdir -p "$SD/logs" "$SD/data/backups" "$SD/data/snapshots"
TIMEOUT=60
[[ "${1:-}" == "--timeout" ]] && { TIMEOUT="${2:-60}"; shift 2; }
CMD="${1:-}"
[[ -z "$CMD" ]] && { echo '{"error":"Sem comando"}'; exit 1; }
lg() { echo "[$(date -Iseconds)] [COMMAND] $*" >> "$SD/logs/commands.log"; }
lge() { echo "[$(date -Iseconds)] [ERROR] $*" >> "$SD/logs/errors.log"; }
# Block level 5
CL=$(echo "$CMD"|tr '[:upper:]' '[:lower:]')
for p in "rm -rf /" "rm -rf /*" "mkfs" "fdisk" "dd if=" ":(){ " "chmod -r 777 /" "> /dev/sd"; do
    echo "$CL"|grep -qiF "$p" 2>/dev/null && { lg "BLOCKED cmd=\"$CMD\""; echo "🚫 Comando PROIBIDO"; exit 1; }; done
# Block openclaw dir changes
echo "$CMD"|grep -qE "(rm|mv|chmod|chown|>|tee|sed.*-i).*\.openclaw" && { lg "BLOCKED openclaw cmd=\"$CMD\""; echo "🚫 Não posso alterar ~/.openclaw/"; exit 1; }
# UFW → Guardian pipeline
if echo "$CMD"|grep -qE "^ufw "; then
    UA="${CMD#ufw }"
    echo "$UA"|grep -qE "^status" && { ufw $UA 2>&1; lg "cmd=\"$CMD\" exit=0"; exit 0; }
    SIM=$("$DIR/guardian.sh" simulate "$UA" 2>&1)
    echo "$SIM"|grep -q '"safe":false' && { echo "$SIM"; exit 1; }
    TS=$(date +%Y%m%d_%H%M%S)
    ufw status numbered > "$SD/data/snapshots/snap_${TS}.txt" 2>/dev/null
    OUT=$(ufw $UA 2>&1) || EC=$?; EC=${EC:-0}
    echo "[$(date -Iseconds)] [FIREWALL] action=\"$UA\" exit=$EC snap=$TS" >> "$SD/logs/firewall.log"
    [[ $EC -ne 0 ]] && { lge "ufw cmd=\"$CMD\" out=\"$(echo "$OUT"|head -1)\""; echo "❌ $OUT"; exit 1; }
    ST=$("$DIR/guardian.sh" scan 2>&1)
    echo "$ST"|grep -q '"status":"critical"' && { "$DIR/guardian.sh" protect; echo "⚠️ Portas críticas restauradas"; }
    echo "$OUT"; exit 0
fi
# Config backup
echo "$CMD"|grep -qE "(sed.*-i|tee)\s+/etc/" && {
    CF=$(echo "$CMD"|grep -oE '/etc/[^ ]+'|head -1)
    [[ -n "$CF" && -f "$CF" ]] && cp "$CF" "$SD/data/backups/$(echo "$CF"|tr '/' '_').$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null; }
# Execute
lg "cmd=\"$CMD\" timeout=$TIMEOUT"
S=$(date +%s)
OUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1) || EC=$?; EC=${EC:-0}
D=$(($(date +%s)-S))
lg "cmd=\"$CMD\" exit=$EC dur=${D}s"
[[ $EC -ne 0 ]] && lge "cmd=\"$CMD\" exit=$EC out=\"$(echo "$OUT"|head -3)\""
echo "$OUT"; exit $EC
