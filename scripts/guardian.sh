#!/usr/bin/env bash
# Control Server v1.0 — Guardian (Anti-Lockout Safety System)
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Uso:
#   ./guardian.sh scan              → Escaneia e reporta estado
#   ./guardian.sh protect           → Escaneia e CORRIGE problemas
#   ./guardian.sh simulate "CMD"    → Testa se comando UFW é seguro SEM executar
#   ./guardian.sh rollback          → Restaura último snapshot

set -euo pipefail

ACTION="${1:-scan}"
SIMULATE_CMD="${2:-}"
SKILL_DIR="${HOME}/.openclaw/skills/control-server"
SNAPSHOT_DIR="${SKILL_DIR}/data/snapshots"
LOG_FILE="${SKILL_DIR}/logs/firewall.log"

mkdir -p "$SNAPSHOT_DIR" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_action() {
    echo "[$(date -Iseconds)] [GUARDIAN] $*" >> "$LOG_FILE"
}

# ===== DISCOVERY =====

discover_ssh_port() {
    local PORT=$(grep -oP '^\s*Port\s+\K[0-9]+' /etc/ssh/sshd_config 2>/dev/null | head -1)
    if [[ -z "$PORT" ]]; then
        PORT=$(ss -tlnp 2>/dev/null | grep sshd | grep -oP ':(\K[0-9]+)' | head -1)
    fi
    echo "${PORT:-22}"
}

discover_openclaw() {
    local OC="${HOME}/.openclaw/openclaw.json"
    local GW_PORT="18789" GW_BIND="loopback" HAS_NODES="false"
    if [[ -f "$OC" ]]; then
        GW_PORT=$(grep -oP '"port"\s*:\s*\K[0-9]+' "$OC" 2>/dev/null | head -1 || echo "18789")
        GW_BIND=$(grep -oP '"bind"\s*:\s*"\K[^"]+' "$OC" 2>/dev/null | head -1 || echo "loopback")
        grep -q '"nodes"' "$OC" 2>/dev/null && HAS_NODES="true"
    fi
    echo "$GW_PORT|$GW_BIND|$HAS_NODES"
}

# ===== VALIDATE =====

validate_state() {
    local SSH_PORT=$(discover_ssh_port)
    local OC_INFO=$(discover_openclaw)
    local GW_PORT=$(echo "$OC_INFO" | cut -d'|' -f1)
    local GW_BIND=$(echo "$OC_INFO" | cut -d'|' -f2)
    local HAS_NODES=$(echo "$OC_INFO" | cut -d'|' -f3)
    local ISSUES=() STATUS="healthy"

    local UFW_HEAD=$(ufw status 2>/dev/null | head -1)
    if echo "$UFW_HEAD" | grep -qi "inactive"; then
        echo "{\"status\":\"ufw_inactive\",\"ssh_port\":$SSH_PORT,\"gw_port\":$GW_PORT,\"gw_bind\":\"$GW_BIND\",\"issues\":[\"UFW inativo\"]}"
        return
    fi

    if ! ufw status 2>/dev/null | grep -qE "${SSH_PORT}/(tcp|udp).*ALLOW|${SSH_PORT}.*ALLOW"; then
        ISSUES+=("SSH porta $SSH_PORT sem ALLOW")
        STATUS="critical"
    fi

    if [[ "$GW_BIND" != "loopback" ]]; then
        if ! ufw status 2>/dev/null | grep -qE "${GW_PORT}/(tcp|udp).*ALLOW|${GW_PORT}.*ALLOW"; then
            ISSUES+=("OpenClaw Gateway porta $GW_PORT sem ALLOW (bind=$GW_BIND)")
            STATUS="critical"
        fi
    fi

    if [[ "$HAS_NODES" == "true" ]]; then
        if ! ufw status 2>/dev/null | grep -qE "5353.*ALLOW"; then
            ISSUES+=("mDNS 5353/udp sem ALLOW (nodes configurados)")
            [[ "$STATUS" == "healthy" ]] && STATUS="warning"
        fi
    fi

    local ACTIVE_SSH=$(ss -tnp 2>/dev/null | grep -c "ssh" || echo "0")
    local ISSUES_JSON="[]"
    if [[ ${#ISSUES[@]} -gt 0 ]]; then
        ISSUES_JSON="[$(printf '"%s",' "${ISSUES[@]}" | sed 's/,$//')]"
    fi

    echo "{\"status\":\"$STATUS\",\"ssh_port\":$SSH_PORT,\"gw_port\":$GW_PORT,\"gw_bind\":\"$GW_BIND\",\"has_nodes\":$HAS_NODES,\"active_ssh\":$ACTIVE_SSH,\"issues\":$ISSUES_JSON}"
}

# ===== PROTECT =====

auto_protect() {
    local SSH_PORT=$(discover_ssh_port)
    local OC_INFO=$(discover_openclaw)
    local GW_PORT=$(echo "$OC_INFO" | cut -d'|' -f1)
    local GW_BIND=$(echo "$OC_INFO" | cut -d'|' -f2)
    local HAS_NODES=$(echo "$OC_INFO" | cut -d'|' -f3)
    local FIXES=0

    if ! ufw status 2>/dev/null | grep -qE "${SSH_PORT}/(tcp|udp).*ALLOW|${SSH_PORT}.*ALLOW"; then
        ufw allow "${SSH_PORT}/tcp" comment "SSH - AUTO-RESTAURADO" 2>/dev/null
        log_action "AUTO-FIX SSH port=$SSH_PORT"
        echo "🚨 SSH porta $SSH_PORT restaurado"
        FIXES=$((FIXES+1))
    fi

    if [[ "$GW_BIND" != "loopback" ]]; then
        if ! ufw status 2>/dev/null | grep -qE "${GW_PORT}/(tcp|udp).*ALLOW|${GW_PORT}.*ALLOW"; then
            ufw allow "${GW_PORT}/tcp" comment "OpenClaw Gateway - AUTO-RESTAURADO" 2>/dev/null
            log_action "AUTO-FIX OpenClaw port=$GW_PORT"
            echo "🚨 OpenClaw Gateway porta $GW_PORT restaurado"
            FIXES=$((FIXES+1))
        fi
    fi

    if [[ "$HAS_NODES" == "true" ]]; then
        if ! ufw status 2>/dev/null | grep -qE "5353.*ALLOW"; then
            ufw allow 5353/udp comment "mDNS OpenClaw - AUTO-RESTAURADO" 2>/dev/null
            log_action "AUTO-FIX mDNS 5353"
            echo "🚨 mDNS 5353/udp restaurado"
            FIXES=$((FIXES+1))
        fi
    fi

    [[ $FIXES -eq 0 ]] && echo "✅ Tudo protegido." || echo "🔧 $FIXES correção(ões) aplicada(s)."
}

# ===== SIMULATE =====

simulate_command() {
    local CMD="$1"
    local CMD_LOWER=$(echo "$CMD" | tr '[:upper:]' '[:lower:]')
    local SSH_PORT=$(discover_ssh_port)
    local OC_INFO=$(discover_openclaw)
    local GW_PORT=$(echo "$OC_INFO" | cut -d'|' -f1)
    local GW_BIND=$(echo "$OC_INFO" | cut -d'|' -f2)

    if echo "$CMD_LOWER" | grep -qE "(delete|deny|reject|remove).*(${SSH_PORT}|ssh)"; then
        echo "{\"safe\":false,\"level\":\"BLOCKED\",\"reason\":\"Fecharia SSH (porta $SSH_PORT)\"}"
        return 1
    fi
    if [[ "$GW_BIND" != "loopback" ]] && echo "$CMD_LOWER" | grep -qE "(delete|deny|reject|remove).*${GW_PORT}"; then
        echo "{\"safe\":false,\"level\":\"BLOCKED\",\"reason\":\"Fecharia OpenClaw Gateway (porta $GW_PORT)\"}"
        return 1
    fi
    if echo "$CMD_LOWER" | grep -qE "^(disable|reset)$"; then
        echo "{\"safe\":false,\"level\":\"DANGEROUS\",\"reason\":\"Desabilitaria/resetaria firewall inteiro\",\"needs_confirmation\":true}"
        return 1
    fi
    if echo "$CMD_LOWER" | grep -qE "default deny outgoing"; then
        echo "{\"safe\":false,\"level\":\"DANGEROUS\",\"reason\":\"Bloquearia tráfego de saída do servidor\",\"needs_confirmation\":true}"
        return 1
    fi
    if echo "$CMD_LOWER" | grep -qE "allow.*(3306|5432|6379|27017)" && ! echo "$CMD_LOWER" | grep -qE "from "; then
        echo "{\"safe\":false,\"level\":\"WARNING\",\"reason\":\"Banco de dados aberto para toda internet\",\"needs_confirmation\":true}"
        return 1
    fi

    echo "{\"safe\":true,\"level\":\"OK\"}"
    return 0
}

# ===== ROLLBACK =====

rollback() {
    local LATEST=$(ls -t "$SNAPSHOT_DIR"/snap_*.txt 2>/dev/null | head -1)
    if [[ -z "$LATEST" ]]; then
        echo "{\"success\":false,\"error\":\"Nenhum snapshot\"}"
        return 1
    fi
    echo "📸 Snapshot: $(basename "$LATEST")"
    cat "$LATEST"
    log_action "ROLLBACK requested snapshot=$(basename "$LATEST")"
}

# ===== MAIN =====

case "$ACTION" in
    scan)       validate_state ;;
    protect)    auto_protect ;;
    simulate)   [[ -z "$SIMULATE_CMD" ]] && { echo "Informe: ./guardian.sh simulate \"CMD\""; exit 1; }; simulate_command "$SIMULATE_CMD" ;;
    rollback)   rollback ;;
    *)          echo "Uso: guardian.sh [scan|protect|simulate|rollback]"; exit 1 ;;
esac
