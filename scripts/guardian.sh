#!/usr/bin/env bash
# Control Server v1.0 — Guardian (Anti-Lockout)
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
# Usa 3 fontes: CONFIG + PROCESSOS + PORTAS em tempo real
set -euo pipefail
ACTION="${1:-scan}"; CMD="${2:-}"
SD="${HOME}/.openclaw/skills/control-server"
SNAP="${SD}/data/snapshots"; LOG="${SD}/logs/firewall.log"
mkdir -p "$SNAP" "$(dirname "$LOG")"; touch "$LOG"
lg() { echo "[$(date -Iseconds)] [GUARDIAN] $*" >> "$LOG"; }

ssh_cfg() { grep -oP '^\s*Port\s+\K[0-9]+' /etc/ssh/sshd_config 2>/dev/null | head -1 || echo ""; }
ssh_proc() { ss -tlnp 2>/dev/null | grep -E "sshd|\"ssh\"" | grep -oP ':(\K[0-9]+)(?=\s)' | sort -un || echo ""; }
oc_cfg() {
    local F="${HOME}/.openclaw/openclaw.json" P="18789" B="loopback"
    [[ -f "$F" ]] && { P=$(grep -oP '"port"\s*:\s*\K[0-9]+' "$F" 2>/dev/null | head -1 || echo "18789"); B=$(grep -oP '"bind"\s*:\s*"\K[^"]+' "$F" 2>/dev/null | head -1 || echo "loopback"); }
    echo "$P|$B"
}
oc_proc() {
    local PIDS=$(pgrep -f "openclaw|clawdbot" 2>/dev/null || echo "") PORTS=""
    for PID in $PIDS; do
        local P=$(ss -tlnp 2>/dev/null | grep "pid=${PID}," | grep -oP ':(\K[0-9]+)(?=\s)' || true)
        [[ -n "$P" ]] && PORTS="$PORTS $P"
    done
    local CP=$(oc_cfg | cut -d'|' -f1)
    ss -tlnp 2>/dev/null | grep -q ":${CP} " && PORTS="$PORTS $CP"
    echo "$PORTS" | tr ' ' '\n' | sort -un | tr '\n' ' ' | xargs
}
active_ssh() { ss -tnp 2>/dev/null | grep -cE "ESTAB.*sshd" || echo "0"; }
protected() {
    local A=() SC=$(ssh_cfg) SP=$(ssh_proc) OC=$(oc_cfg | cut -d'|' -f1) OP=$(oc_proc)
    [[ -n "$SC" ]] && A+=("$SC"); for p in $SP; do A+=("$p"); done; A+=("22")
    [[ -n "$OC" ]] && A+=("$OC"); for p in $OP; do A+=("$p"); done; A+=("18789" "5353")
    echo "${A[@]}" | tr ' ' '\n' | sort -un | tr '\n' ' ' | xargs
}

do_scan() {
    local SC=$(ssh_cfg) SP=$(ssh_proc) SSH="${SC:-${SP%% *}}"; SSH="${SSH:-22}"
    local OR=$(oc_cfg) GP=$(echo "$OR"|cut -d'|' -f1) GB=$(echo "$OR"|cut -d'|' -f2) OP=$(oc_proc)
    local HN=false; [[ -f "${HOME}/.openclaw/openclaw.json" ]] && grep -q '"nodes"' "${HOME}/.openclaw/openclaw.json" 2>/dev/null && HN=true
    local AS=$(active_ssh) PP=$(protected) IS=() ST="healthy"
    if ufw status 2>/dev/null | head -1 | grep -qi "inactive"; then
        echo "{\"status\":\"ufw_inactive\",\"ssh\":\"$SSH\",\"gw\":\"$GP\",\"protected\":\"$PP\",\"active_ssh\":$AS}"; return; fi
    for s in ${SP:-$SSH}; do
        ufw status 2>/dev/null | grep -qE "${s}/(tcp|udp).*ALLOW|${s}.*ALLOW" || { IS+=("SSH $s sem ALLOW — $AS sessões ativas"); ST="critical"; }; done
    if [[ "$GB" != "loopback" ]]; then for o in $GP $OP; do [[ -z "$o" ]] && continue
        ufw status 2>/dev/null | grep -qE "${o}/(tcp|udp).*ALLOW|${o}.*ALLOW" || { IS+=("OpenClaw $o sem ALLOW"); ST="critical"; }; done; fi
    [[ "$HN" == "true" ]] && ! ufw status 2>/dev/null | grep -qE "5353.*ALLOW" && { IS+=("mDNS sem ALLOW"); [[ "$ST" == "healthy" ]] && ST="warning"; }
    local IJ="[]"; [[ ${#IS[@]} -gt 0 ]] && IJ="[$(printf '"%s",' "${IS[@]}"|sed 's/,$//')]"
    echo "{\"status\":\"$ST\",\"ssh\":\"$SSH\",\"ssh_proc\":\"$SP\",\"gw\":\"$GP\",\"gw_bind\":\"$GB\",\"oc_proc\":\"$OP\",\"active_ssh\":$AS,\"protected\":\"$PP\",\"issues\":$IJ}"
    lg "SCAN st=$ST ssh=$SSH gw=$GP active=$AS"
}

do_protect() {
    local FX=0 SA="$(ssh_cfg) $(ssh_proc) 22"
    for s in $(echo "$SA"|tr ' ' '\n'|sort -un); do [[ -z "$s" ]] && continue
        ufw status 2>/dev/null | grep -qE "${s}/(tcp|udp).*ALLOW|${s}.*ALLOW" || {
            ufw allow "${s}/tcp" comment "SSH $s - AUTO-RESTAURADO" 2>/dev/null; lg "FIX SSH $s"; echo "🚨 SSH $s restaurado"; FX=$((FX+1)); }; done
    local OR=$(oc_cfg) GB=$(echo "$OR"|cut -d'|' -f2)
    if [[ "$GB" != "loopback" ]]; then local OA="$(echo "$OR"|cut -d'|' -f1) $(oc_proc)"
        for o in $(echo "$OA"|tr ' ' '\n'|sort -un); do [[ -z "$o" ]] && continue
            ufw status 2>/dev/null | grep -qE "${o}/(tcp|udp).*ALLOW|${o}.*ALLOW" || {
                ufw allow "${o}/tcp" comment "OpenClaw $o - AUTO-RESTAURADO" 2>/dev/null; lg "FIX OC $o"; echo "🚨 OpenClaw $o restaurado"; FX=$((FX+1)); }; done; fi
    [[ -f "${HOME}/.openclaw/openclaw.json" ]] && grep -q '"nodes"' "${HOME}/.openclaw/openclaw.json" 2>/dev/null && {
        ufw status 2>/dev/null | grep -qE "5353.*ALLOW" || { ufw allow 5353/udp comment "mDNS - AUTO" 2>/dev/null; FX=$((FX+1)); echo "🚨 mDNS restaurado"; }; }
    [[ $FX -eq 0 ]] && echo "✅ Tudo protegido." || echo "🔧 $FX fix(es)."
    lg "PROTECT fx=$FX"
}

do_simulate() {
    local C="$1" CL=$(echo "$1"|tr '[:upper:]' '[:lower:]') PP=$(protected) AS=$(active_ssh)
    if echo "$CL" | grep -qE "(delete|deny|reject|remove)"; then
        local T=$(echo "$CL"|grep -oE '[0-9]+'|head -1)
        if [[ -n "$T" ]]; then for p in $PP; do [[ "$T" == "$p" ]] && {
            local W="porta protegida $p"
            echo "$(ssh_cfg) $(ssh_proc) 22"|tr ' ' '\n'|sort -un|grep -qw "$T" && W="SSH ($T) — $AS sessões ativas. PERDA DE ACESSO REMOTO"
            echo "$(oc_cfg|cut -d'|' -f1) $(oc_proc) 18789"|grep -qw "$T" && W="OpenClaw ($T) — AGENTE PARA"
            [[ "$T" == "5353" ]] && W="mDNS"
            echo "{\"safe\":false,\"level\":\"BLOCKED\",\"reason\":\"Fecharia $W\",\"port\":$T,\"active_ssh\":$AS}"
            lg "SIM BLOCKED $C port=$T"; return 1; }; done; fi
        echo "$CL"|grep -qE "(delete|deny|reject|remove).*ssh" && {
            echo "{\"safe\":false,\"level\":\"BLOCKED\",\"reason\":\"Ref SSH — $AS sessões\",\"active_ssh\":$AS}"; return 1; }; fi
    echo "$CL"|grep -qE "^(disable|reset)$" && { echo "{\"safe\":false,\"level\":\"DANGEROUS\",\"reason\":\"Reset firewall\",\"needs_confirmation\":true}"; return 1; }
    echo "$CL"|grep -qE "default deny outgoing" && { echo "{\"safe\":false,\"level\":\"DANGEROUS\",\"reason\":\"Bloquearia saída\",\"needs_confirmation\":true}"; return 1; }
    echo "$CL"|grep -qE "allow.*(3306|5432|6379|27017)" && ! echo "$CL"|grep -qE "from " && {
        echo "{\"safe\":false,\"level\":\"WARNING\",\"reason\":\"DB aberto pra internet\",\"needs_confirmation\":true}"; return 1; }
    echo "{\"safe\":true,\"level\":\"OK\",\"protected\":\"$PP\",\"active_ssh\":$AS}"
    lg "SIM OK $C"; return 0
}

case "$ACTION" in
    scan) do_scan ;; protect) do_protect ;;
    simulate) [[ -z "$CMD" ]] && { echo "Uso: guardian.sh simulate CMD"; exit 1; }; do_simulate "$CMD" ;;
    rollback) F=$(ls -t "$SNAP"/snap_*.txt 2>/dev/null|head -1); [[ -z "$F" ]] && { echo "Sem snapshot"; exit 1; }; cat "$F"; lg "ROLLBACK $(basename "$F")" ;;
    *) echo "Uso: guardian.sh [scan|protect|simulate|rollback]"; exit 1 ;;
esac
