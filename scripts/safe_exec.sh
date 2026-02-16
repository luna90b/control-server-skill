#!/usr/bin/env bash
# control-server: Safe Command Executor
# Wrapper que executa comandos com proteções de segurança
# Uso: ./safe_exec.sh "<comando>" [timeout_seconds]
# Faz backup automático de configs antes de editar

set -euo pipefail

CMD="${1:-}"
TIMEOUT="${2:-60}"
LOG_DIR="${HOME}/.openclaw/skills/control-server/logs"
BACKUP_DIR="${HOME}/.openclaw/skills/control-server/backups"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/exec_${TIMESTAMP}.log"

if [[ -z "$CMD" ]]; then
    echo '{"success": false, "error": "Nenhum comando fornecido"}'
    exit 1
fi

# Classificar primeiro
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLASSIFICATION=$("$SCRIPT_DIR/classify_command.sh" "$CMD" 2>/dev/null || echo '{"level": 5, "blocked": true}')

# Checar se bloqueado
if echo "$CLASSIFICATION" | grep -q '"blocked": true'; then
    echo "{\"success\": false, \"error\": \"Comando BLOQUEADO por segurança\", \"classification\": $CLASSIFICATION}"
    echo "[$(date)] BLOCKED: $CMD" >> "$LOG_FILE"
    exit 1
fi

# Se comando edita arquivo de config, fazer backup
if echo "$CMD" | grep -qE "(nano|vim|vi|sed.*-i|tee) .*/etc/"; then
    CONFIG_FILE=$(echo "$CMD" | grep -oE '/etc/[^ ]+' | head -1)
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        BACKUP_NAME=$(echo "$CONFIG_FILE" | tr '/' '_')
        cp "$CONFIG_FILE" "$BACKUP_DIR/${BACKUP_NAME}.${TIMESTAMP}.bak" 2>/dev/null || true
        echo "📋 Backup criado: ${BACKUP_NAME}.${TIMESTAMP}.bak"
    fi
fi

# Log
echo "[$(date)] EXEC: $CMD" >> "$LOG_FILE"

# Executar com timeout
OUTPUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1) || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}

# Log resultado
echo "[$(date)] EXIT: $EXIT_CODE" >> "$LOG_FILE"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "$OUTPUT"
else
    echo "⚠️ Comando retornou código $EXIT_CODE"
    echo "$OUTPUT"
fi

exit $EXIT_CODE
