#!/usr/bin/env bash
# Control Server v1.0 — Log Manager
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Uso:
#   ./log_manager.sh show [type] [lines]    → Mostrar logs (commands|firewall|installs|errors|credentials|all)
#   ./log_manager.sh search "termo"         → Buscar nos logs
#   ./log_manager.sh summary [today|week]   → Resumo de atividades
#   ./log_manager.sh rotate                 → Rotacionar logs antigos (>30 dias)

set -euo pipefail

ACTION="${1:-show}"
ARG2="${2:-all}"
ARG3="${3:-50}"

SKILL_DIR="${HOME}/.openclaw/skills/control-server"
LOG_DIR="${SKILL_DIR}/logs"

mkdir -p "$LOG_DIR"

case "$ACTION" in
    show)
        TYPE="$ARG2"
        LINES="$ARG3"
        
        if [[ "$TYPE" == "all" ]]; then
            for f in "$LOG_DIR"/*.log; do
                [[ -f "$f" ]] || continue
                echo "=== $(basename "$f") ==="
                tail -"$LINES" "$f" 2>/dev/null
                echo ""
            done
        else
            FILE="$LOG_DIR/${TYPE}.log"
            if [[ -f "$FILE" ]]; then
                tail -"$LINES" "$FILE"
            else
                echo "Log não encontrado: $TYPE"
                echo "Disponíveis: $(ls "$LOG_DIR"/*.log 2>/dev/null | xargs -I{} basename {} .log | tr '\n' ', ')"
            fi
        fi
        ;;
    
    search)
        TERM="$ARG2"
        if [[ -z "$TERM" ]]; then
            echo "Uso: log_manager.sh search \"termo\""
            exit 1
        fi
        echo "🔍 Buscando \"$TERM\" nos logs..."
        echo ""
        grep -rn --color=always "$TERM" "$LOG_DIR"/*.log 2>/dev/null || echo "Nenhum resultado"
        ;;
    
    summary)
        PERIOD="$ARG2"
        case "$PERIOD" in
            today)  SINCE=$(date +%Y-%m-%d) ;;
            week)   SINCE=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d) ;;
            *)      SINCE=$(date +%Y-%m-%d) ;;
        esac
        
        echo "📋 Resumo de atividades desde $SINCE"
        echo ""
        
        CMD_COUNT=$(grep -c "$SINCE" "$LOG_DIR/commands.log" 2>/dev/null || echo "0")
        echo "  ⚡ Comandos executados: $CMD_COUNT"
        
        FW_COUNT=$(grep -c "$SINCE" "$LOG_DIR/firewall.log" 2>/dev/null || echo "0")
        echo "  🛡️ Alterações de firewall: $FW_COUNT"
        
        INST_COUNT=$(grep -c "$SINCE" "$LOG_DIR/installs.log" 2>/dev/null || echo "0")
        echo "  📦 Instalações: $INST_COUNT"
        
        ERR_COUNT=$(grep -c "$SINCE" "$LOG_DIR/errors.log" 2>/dev/null || echo "0")
        echo "  ❌ Erros: $ERR_COUNT"
        
        CRED_COUNT=$(grep -c "$SINCE" "$LOG_DIR/credentials.log" 2>/dev/null || echo "0")
        echo "  🔑 Acessos a credenciais: $CRED_COUNT"
        
        if [[ $ERR_COUNT -gt 0 ]]; then
            echo ""
            echo "  Últimos erros:"
            grep "$SINCE" "$LOG_DIR/errors.log" 2>/dev/null | tail -5 | while read -r line; do
                echo "    $line"
            done
        fi
        ;;
    
    rotate)
        echo "🔄 Rotacionando logs com mais de 30 dias..."
        ARCHIVE_DIR="$LOG_DIR/archive"
        mkdir -p "$ARCHIVE_DIR"
        
        for f in "$LOG_DIR"/*.log; do
            [[ -f "$f" ]] || continue
            NAME=$(basename "$f")
            LINES=$(wc -l < "$f")
            if [[ $LINES -gt 10000 ]]; then
                # Manter últimas 5000 linhas, arquivar o resto
                TS=$(date +%Y%m%d)
                head -n -5000 "$f" >> "$ARCHIVE_DIR/${NAME%.log}_${TS}.log"
                tail -5000 "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
                echo "  📁 $NAME: arquivou $(( LINES - 5000 )) linhas"
            fi
        done
        echo "✅ Rotação concluída"
        ;;
    
    *)
        echo "Uso: log_manager.sh [show|search|summary|rotate]"
        exit 1
        ;;
esac
