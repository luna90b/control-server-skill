#!/usr/bin/env bash
# log_manager.sh — Gerenciador de logs de execução
# Uso: bash log_manager.sh --action [today|date|search|last|failures|stats|clean] --log-dir /path

set -euo pipefail

ACTION=""
LOG_DIR=""
DATE_QUERY=""
SEARCH_QUERY=""
COUNT=20
DAYS_KEEP=30

# === PARSE ARGS ===
while [[ $# -gt 0 ]]; do
    case $1 in
        --action)    ACTION="$2"; shift 2 ;;
        --log-dir)   LOG_DIR="$2"; shift 2 ;;
        --date)      DATE_QUERY="$2"; shift 2 ;;
        --query)     SEARCH_QUERY="$2"; shift 2 ;;
        --count)     COUNT="$2"; shift 2 ;;
        --days-keep) DAYS_KEEP="$2"; shift 2 ;;
        *) echo "ERRO: Argumento desconhecido: $1"; exit 1 ;;
    esac
done

if [ -z "$ACTION" ] || [ -z "$LOG_DIR" ]; then
    echo "ERRO: --action e --log-dir são obrigatórios"
    exit 1
fi

# === AÇÕES ===

action_today() {
    local today
    today=$(date '+%Y-%m-%d')
    local log_file="$LOG_DIR/${today}.log"
    
    if [ ! -f "$log_file" ]; then
        echo "Nenhum log encontrado para hoje ($today)"
        return 0
    fi
    
    echo "=== Logs de $today ==="
    cat "$log_file"
    echo ""
    echo "=== Total de entradas: $(grep -c '^timestamp:' "$log_file" 2>/dev/null || echo 0) ==="
}

action_date() {
    if [ -z "$DATE_QUERY" ]; then
        echo "ERRO: --date é obrigatório para action=date"
        exit 1
    fi
    
    local log_file="$LOG_DIR/${DATE_QUERY}.log"
    
    if [ ! -f "$log_file" ]; then
        echo "Nenhum log encontrado para $DATE_QUERY"
        echo "Datas disponíveis:"
        ls -1 "$LOG_DIR"/*.log 2>/dev/null | xargs -I{} basename {} .log | sort -r | head -10
        return 0
    fi
    
    echo "=== Logs de $DATE_QUERY ==="
    cat "$log_file"
}

action_search() {
    if [ -z "$SEARCH_QUERY" ]; then
        echo "ERRO: --query é obrigatório para action=search"
        exit 1
    fi
    
    echo "=== Buscando '$SEARCH_QUERY' em todos os logs ==="
    local found=0
    
    for log_file in "$LOG_DIR"/*.log; do
        if [ -f "$log_file" ]; then
            local matches
            matches=$(grep -i "$SEARCH_QUERY" "$log_file" 2>/dev/null || true)
            if [ -n "$matches" ]; then
                echo ""
                echo "--- $(basename "$log_file" .log) ---"
                echo "$matches"
                found=1
            fi
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "Nenhum resultado encontrado para '$SEARCH_QUERY'"
    fi
}

action_last() {
    echo "=== Últimos $COUNT comandos executados ==="
    
    # Combinar todos os logs, ordenar por data (mais recentes primeiro)
    local all_entries=""
    
    for log_file in $(ls -1t "$LOG_DIR"/*.log 2>/dev/null); do
        if [ -f "$log_file" ]; then
            # Extrair entradas (blocos entre ---)
            local content
            content=$(cat "$log_file")
            all_entries="${all_entries}
${content}"
        fi
    done
    
    # Mostrar últimas N entradas (cada entrada começa com "---" e termina com "---")
    echo "$all_entries" | grep -A5 "^timestamp:" | tail -n "$((COUNT * 6))"
}

action_failures() {
    echo "=== Comandos que falharam (exit_code != 0) ==="
    local found=0
    
    for log_file in "$LOG_DIR"/*.log; do
        if [ -f "$log_file" ]; then
            # Buscar entradas com exit_code diferente de 0
            local in_block=0
            local block=""
            local has_failure=0
            
            while IFS= read -r line; do
                if [ "$line" == "---" ]; then
                    if [ $in_block -eq 1 ] && [ $has_failure -eq 1 ]; then
                        echo "$block"
                        echo "---"
                        echo ""
                        found=1
                    fi
                    in_block=$((1 - in_block))
                    block="---"
                    has_failure=0
                else
                    block="${block}
${line}"
                    if [[ "$line" =~ ^exit_code:\ *[1-9] ]]; then
                        has_failure=1
                    fi
                fi
            done < "$log_file"
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "Nenhuma falha encontrada nos logs."
    fi
}

action_stats() {
    echo "=== Estatísticas de Execução ==="
    echo ""
    
    local total_files=0
    local total_entries=0
    local total_failures=0
    local total_size=0
    
    for log_file in "$LOG_DIR"/*.log; do
        if [ -f "$log_file" ]; then
            total_files=$((total_files + 1))
            local entries
            entries=$(grep -c "^timestamp:" "$log_file" 2>/dev/null || echo 0)
            total_entries=$((total_entries + entries))
            local failures
            failures=$(grep -c "^exit_code: [1-9]" "$log_file" 2>/dev/null || echo 0)
            total_failures=$((total_failures + failures))
            local size
            size=$(stat -f%z "$log_file" 2>/dev/null || stat --printf="%s" "$log_file" 2>/dev/null || echo 0)
            total_size=$((total_size + size))
        fi
    done
    
    echo "Arquivos de log: $total_files"
    echo "Total de comandos: $total_entries"
    echo "Falhas: $total_failures"
    if [ $total_entries -gt 0 ]; then
        local success_rate=$(( (total_entries - total_failures) * 100 / total_entries ))
        echo "Taxa de sucesso: ${success_rate}%"
    fi
    echo "Tamanho total: $(numfmt --to=iec $total_size 2>/dev/null || echo "${total_size} bytes")"
    echo ""
    echo "Período coberto:"
    ls -1 "$LOG_DIR"/*.log 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.log//' | xargs -I{} echo "  Primeiro: {}"
    ls -1 "$LOG_DIR"/*.log 2>/dev/null | tail -1 | xargs basename 2>/dev/null | sed 's/.log//' | xargs -I{} echo "  Último: {}"
}

action_clean() {
    echo "=== Limpando logs com mais de $DAYS_KEEP dias ==="
    local deleted=0
    
    find "$LOG_DIR" -name "*.log" -mtime +"$DAYS_KEEP" -print -delete 2>/dev/null | while read -r f; do
        echo "Removido: $(basename "$f")"
        deleted=$((deleted + 1))
    done
    
    echo "Limpeza concluída."
}

# === DISPATCH ===
case "$ACTION" in
    today)    action_today ;;
    date)     action_date ;;
    search)   action_search ;;
    last)     action_last ;;
    failures) action_failures ;;
    stats)    action_stats ;;
    clean)    action_clean ;;
    *)
        echo "ERRO: Ação '$ACTION' não reconhecida"
        echo "Ações: today, date, search, last, failures, stats, clean"
        exit 1
        ;;
esac
