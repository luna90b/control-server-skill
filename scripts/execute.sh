#!/usr/bin/env bash
# execute.sh — Executor principal de comandos com logging automático
# Uso: bash execute.sh --mode [local|ssh] --cmd "comando" --log-dir /path/logs [--host HOST --user USER --port PORT]

set -euo pipefail

# === DEFAULTS ===
MODE="local"
HOST=""
USER_SSH=""
PORT="22"
CMD=""
LOG_DIR=""
TIMEOUT=300
IDENTITY=""

# === PARSE ARGS ===
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)    MODE="$2"; shift 2 ;;
        --host)    HOST="$2"; shift 2 ;;
        --user)    USER_SSH="$2"; shift 2 ;;
        --port)    PORT="$2"; shift 2 ;;
        --cmd)     CMD="$2"; shift 2 ;;
        --log-dir) LOG_DIR="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --identity) IDENTITY="$2"; shift 2 ;;
        *) echo "ERRO: Argumento desconhecido: $1"; exit 1 ;;
    esac
done

# === VALIDAÇÃO ===
if [ -z "$CMD" ]; then
    echo "ERRO: --cmd é obrigatório"
    echo "Uso: bash execute.sh --mode [local|ssh] --cmd \"comando\" --log-dir /path/logs"
    exit 1
fi

if [ "$MODE" == "ssh" ]; then
    if [ -z "$HOST" ] || [ -z "$USER_SSH" ]; then
        echo "ERRO: --host e --user são obrigatórios no modo ssh"
        exit 1
    fi
fi

# === SETUP LOG ===
LOG_FILE=""
if [ -n "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/$(date '+%Y-%m-%d').log"
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
START_TIME=$(date +%s)

# === LOG FUNCTION ===
log_entry() {
    local exit_code="$1"
    local output="$2"
    local duration="$3"
    
    if [ -n "$LOG_FILE" ]; then
        # Truncar output muito longo para o log (max 2000 chars)
        local log_output="$output"
        if [ ${#log_output} -gt 2000 ]; then
            log_output="${log_output:0:1000}...[TRUNCATED]...${log_output: -500}"
        fi
        
        cat >> "$LOG_FILE" <<EOF
---
timestamp: $TIMESTAMP
mode: $MODE
host: ${HOST:-localhost}
user: ${USER_SSH:-$(whoami)}
command: $CMD
exit_code: $exit_code
duration: ${duration}s
output: |
$(echo "$log_output" | sed 's/^/  /')
---
EOF
    fi
}

# === EXECUTAR ===
TEMP_OUT=$(mktemp)
TEMP_ERR=$(mktemp)
trap "rm -f $TEMP_OUT $TEMP_ERR" EXIT

EXIT_CODE=0

if [ "$MODE" == "local" ]; then
    # Execução local
    timeout "$TIMEOUT" bash -c "$CMD" > "$TEMP_OUT" 2> "$TEMP_ERR" || EXIT_CODE=$?
elif [ "$MODE" == "ssh" ]; then
    # Execução remota via SSH
    SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o BatchMode=yes -p $PORT"
    if [ -n "$IDENTITY" ]; then
        SSH_OPTS="$SSH_OPTS -i $IDENTITY"
    fi
    timeout "$TIMEOUT" ssh $SSH_OPTS "$USER_SSH@$HOST" "$CMD" > "$TEMP_OUT" 2> "$TEMP_ERR" || EXIT_CODE=$?
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

STDOUT=$(cat "$TEMP_OUT")
STDERR=$(cat "$TEMP_ERR")

# Combinar output
if [ -n "$STDERR" ] && [ $EXIT_CODE -ne 0 ]; then
    FULL_OUTPUT="STDOUT:
$STDOUT

STDERR:
$STDERR"
else
    FULL_OUTPUT="$STDOUT"
    if [ -n "$STDERR" ]; then
        FULL_OUTPUT="$FULL_OUTPUT

STDERR (warnings):
$STDERR"
    fi
fi

# === REGISTRAR LOG ===
log_entry "$EXIT_CODE" "$FULL_OUTPUT" "$DURATION"

# === OUTPUT ESTRUTURADO PARA O AGENTE ===
cat <<EOF
==== EXECUTION RESULT ====
MODE: $MODE
HOST: ${HOST:-localhost}
COMMAND: $CMD
EXIT_CODE: $EXIT_CODE
DURATION: ${DURATION}s
TIMESTAMP: $TIMESTAMP

OUTPUT:
$FULL_OUTPUT

==== END RESULT ====
EOF

exit $EXIT_CODE
