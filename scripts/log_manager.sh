#!/usr/bin/env bash
# Control Server v1.0 — Log Manager
# Criado por BollaNetwork
set -euo pipefail
A="${1:-show}"; B="${2:-all}"; C="${3:-50}"
LD="${HOME}/.openclaw/skills/control-server/logs"; mkdir -p "$LD"
case "$A" in
    show) if [[ "$B" == "all" ]]; then for f in "$LD"/*.log; do [[ -f "$f" ]]||continue; echo "=== $(basename "$f") ==="; tail -"$C" "$f"; echo; done
        else [[ -f "$LD/${B}.log" ]] && tail -"$C" "$LD/${B}.log" || echo "Não encontrado: $B"; fi ;;
    search) [[ -z "$B" ]] && { echo "Uso: log_manager.sh search termo"; exit 1; }
        grep -rn --color=always "$B" "$LD"/*.log 2>/dev/null || echo "Nada encontrado" ;;
    summary) case "$B" in today) S=$(date +%Y-%m-%d);; week) S=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null||date +%Y-%m-%d);; *) S=$(date +%Y-%m-%d);; esac
        echo "📋 Desde $S"
        for t in commands firewall installs errors credentials; do
            N=$(grep -c "$S" "$LD/${t}.log" 2>/dev/null||echo 0); echo "  $t: $N"; done ;;
    rotate) mkdir -p "$LD/archive"
        for f in "$LD"/*.log; do [[ -f "$f" ]]||continue; L=$(wc -l<"$f")
            [[ $L -gt 10000 ]] && { head -n -5000 "$f">>"$LD/archive/$(basename "$f" .log)_$(date +%Y%m%d).log"; tail -5000 "$f">"${f}.tmp"&&mv "${f}.tmp" "$f"; echo "Rotacionado: $(basename "$f")"; }; done ;;
    *) echo "Uso: log_manager.sh [show|search|summary|rotate]" ;;
esac
