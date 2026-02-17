#!/usr/bin/env bash
# Control Server v1.0 — Port Auditor
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Detecta portas órfãs. NUNCA marca SSH ou OpenClaw como órfã.
# Uso: ./port_audit.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAN=$("$SCRIPT_DIR/guardian.sh" scan 2>/dev/null || echo '{}')
SSH_PORT=$(echo "$SCAN" | grep -oP '"ssh_port":\s*\K[0-9]+' || echo "22")
GW_PORT=$(echo "$SCAN" | grep -oP '"gw_port":\s*\K[0-9]+' || echo "18789")

PROTECTED=("$SSH_PORT" "$GW_PORT" "5353")
is_protected() { for p in "${PROTECTED[@]}"; do [[ "$1" == "$p" ]] && return 0; done; return 1; }

if ufw status 2>/dev/null | head -1 | grep -qi "inactive"; then
    echo '{"status":"ufw_inactive","orphans":0}'
    exit 0
fi

echo "🔍 Auditoria de portas (SSH=$SSH_PORT, OpenClaw=$GW_PORT protegidos)"
echo ""

ORPHANS=()
while IFS= read -r line; do
    PORT=$(echo "$line" | awk '{print $1}' | grep -oE '^[0-9]+' 2>/dev/null || true)
    [[ -z "$PORT" ]] && continue
    if is_protected "$PORT"; then
        echo "  🔒 Porta $PORT — Protegida"
        continue
    fi
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
        PROC=$(ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -oP 'users:\(\("\K[^"]+' || echo "ativo")
        echo "  ✅ Porta $PORT — $PROC"
    else
        echo "  ⚠️  Porta $PORT — ÓRFÃ"
        ORPHANS+=("$PORT")
    fi
done < <(ufw status 2>/dev/null | grep "ALLOW")

echo ""
echo "📊 ${#ORPHANS[@]} porta(s) órfã(s)"
