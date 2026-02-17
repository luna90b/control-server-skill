#!/usr/bin/env bash
# Control Server v1.0 — Safe Executor
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Executa comandos com logging, validação de paths e timeout.
# Para UFW: usa pipeline Guardian (simulate→snapshot→execute→validate)
#
# Uso:
#   ./safe_exec.sh "comando"              → Executa com proteções
#   ./safe_exec.sh "ufw allow 3000/tcp"   → Pipeline Guardian para UFW
#   ./safe_exec.sh --timeout 120 "comando" → Custom timeout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="${HOME}/.openclaw/skills/control-server"
LOG_DIR="${SKILL_DIR}/logs"
BACKUP_DIR="${SKILL_DIR}/data/backups"
SNAPSHOT_DIR="${SKILL_DIR}/data/snapshots"
LOCK_FILE="/tmp/control-server-exec.lock"

mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR"

TIMEOUT=60

# Parse args
if [[ "${1:-}" == "--timeout" ]]; then
    TIMEOUT="${2:-60}"
    shift 2
fi

CMD="${1:-}"

if [[ -z "$CMD" ]]; then
    echo '{"success":false,"error":"Nenhum comando"}'
    exit 1
fi

# Logging
log_cmd() { echo "[$(date -Iseconds)] [COMMAND] $*" >> "$LOG_DIR/commands.log"; }
log_fw()  { echo "[$(date -Iseconds)] [FIREWALL] $*" >> "$LOG_DIR/firewall.log"; }
log_err() { echo "[$(date -Iseconds)] [ERROR] $*" >> "$LOG_DIR/errors.log"; }

# Lock
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$PID" 2>/dev/null; then
            echo '{"success":false,"error":"Outra operação rodando"}'
            exit 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}
release_lock() { rm -f "$LOCK_FILE"; }
trap release_lock EXIT

# ===== PROTECTED PATHS =====

PROTECTED_DIRS=("/" "/bin" "/boot" "/dev" "/etc" "/lib" "/lib64" "/proc" "/root" "/sbin" "/sys" "/usr" "/var" "/opt" "/snap")
OPENCLAW_DIR="${HOME}/.openclaw"

check_path_safety() {
    local CHECK_CMD="$1"
    
    # Verificar se tenta alterar ~/.openclaw
    if echo "$CHECK_CMD" | grep -qE "(rm|mv|chmod|chown|>|tee|sed.*-i|nano|vim).*${OPENCLAW_DIR}"; then
        echo '{"safe":false,"reason":"Tentativa de alterar ~/.openclaw — BLOQUEADO"}'
        return 1
    fi
    
    # Verificar rm em dirs protegidos
    if echo "$CHECK_CMD" | grep -qE "rm\s+(-r|-rf|-fr)\s+"; then
        for dir in "${PROTECTED_DIRS[@]}"; do
            if echo "$CHECK_CMD" | grep -qE "rm\s+(-r|-rf|-fr)\s+${dir}(/|$|\s)"; then
                echo "{\"safe\":false,\"reason\":\"rm em diretório protegido: $dir\"}"
                return 1
            fi
        done
    fi
    
    echo '{"safe":true}'
    return 0
}

# ===== LEVEL 5 BLOCK =====

CMD_LOWER=$(echo "$CMD" | tr '[:upper:]' '[:lower:]')

BLOCKED_PATTERNS=(
    "rm -rf /" "rm -rf /*" "rm -rf ~/*"
    "mkfs" "fdisk" "dd if=" "dd of=/dev"
    ":(){ :|:&};:" ":(){" 
    "chmod -r 777 /" "chown -r.*/"
    "> /dev/sd"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$CMD_LOWER" | grep -qiF "$pattern" 2>/dev/null; then
        log_cmd "BLOCKED cmd=\"$CMD\" reason=\"Level 5 forbidden\""
        echo "🚫 Comando PROIBIDO (Nível 5)"
        exit 1
    fi
done

# Check path safety
PATH_CHECK=$(check_path_safety "$CMD")
if echo "$PATH_CHECK" | grep -q '"safe":false'; then
    REASON=$(echo "$PATH_CHECK" | grep -oP '"reason":"\K[^"]+')
    log_cmd "BLOCKED cmd=\"$CMD\" reason=\"$REASON\""
    echo "🚫 $REASON"
    exit 1
fi

acquire_lock

# ===== UFW COMMANDS → Guardian Pipeline =====

if echo "$CMD" | grep -qE "^ufw "; then
    UFW_ARGS="${CMD#ufw }"
    
    # Status commands don't need protection
    if echo "$UFW_ARGS" | grep -qE "^status"; then
        ufw $UFW_ARGS 2>&1
        log_cmd "cmd=\"$CMD\" exit=0 type=ufw_status"
        exit 0
    fi
    
    # Step 1: Simulate
    SIM=$("$SCRIPT_DIR/guardian.sh" simulate "$UFW_ARGS" 2>&1)
    if echo "$SIM" | grep -q '"safe":false'; then
        LEVEL=$(echo "$SIM" | grep -oP '"level":"\K[^"]+' || echo "UNKNOWN")
        REASON=$(echo "$SIM" | grep -oP '"reason":"\K[^"]+' || echo "?")
        log_fw "BLOCKED action=\"$UFW_ARGS\" level=$LEVEL reason=\"$REASON\""
        echo "$SIM"
        exit 1
    fi
    
    # Step 2: Snapshot
    TS=$(date +%Y%m%d_%H%M%S)
    ufw status numbered > "$SNAPSHOT_DIR/snap_${TS}.txt" 2>/dev/null
    
    # Step 3: Execute
    OUTPUT=$(ufw $UFW_ARGS 2>&1) || EC=$?
    EC=${EC:-0}
    log_fw "action=\"$UFW_ARGS\" exit=$EC snapshot=$TS"
    
    if [[ $EC -ne 0 ]]; then
        log_err "ufw_fail cmd=\"$CMD\" output=\"$(echo "$OUTPUT" | head -1)\""
        echo "❌ $OUTPUT"
        exit 1
    fi
    
    # Step 4: Validate
    STATE=$("$SCRIPT_DIR/guardian.sh" scan 2>&1)
    if echo "$STATE" | grep -q '"status":"critical"'; then
        log_fw "CRITICAL_AFTER action=\"$UFW_ARGS\" — running auto-protect"
        "$SCRIPT_DIR/guardian.sh" protect
        echo "⚠️ Problema detectado após execução — portas críticas restauradas"
    fi
    
    echo "$OUTPUT"
    echo "{\"success\":true,\"command\":\"$CMD\",\"snapshot\":\"$TS\"}"
    exit 0
fi

# ===== REGULAR COMMANDS =====

# Backup config files before editing
if echo "$CMD" | grep -qE "(sed.*-i|tee|nano|vim|vi)\s+/etc/"; then
    CONFIG_FILE=$(echo "$CMD" | grep -oE '/etc/[^ ]+' | head -1)
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        BK_NAME=$(echo "$CONFIG_FILE" | tr '/' '_')
        cp "$CONFIG_FILE" "$BACKUP_DIR/${BK_NAME}.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true
    fi
fi

# Execute with timeout
log_cmd "cmd=\"$CMD\" timeout=$TIMEOUT"
START=$(date +%s)
OUTPUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1) || EC=$?
EC=${EC:-0}
DURATION=$(( $(date +%s) - START ))

log_cmd "cmd=\"$CMD\" exit=$EC duration=${DURATION}s"

if [[ $EC -ne 0 ]]; then
    log_err "cmd=\"$CMD\" exit=$EC output=\"$(echo "$OUTPUT" | head -3)\""
fi

echo "$OUTPUT"
exit $EC
