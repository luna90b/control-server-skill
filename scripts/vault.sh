#!/usr/bin/env bash
# Control Server v1.0 — Vault
# Criado por BollaNetwork
set -euo pipefail
A="${1:-}"; SD="${HOME}/.openclaw/skills/control-server"
VF="${SD}/data/vault.json"; LF="${SD}/logs/credentials.log"
mkdir -p "$(dirname "$VF")" "$(dirname "$LF")"; touch "$LF"
lg() { echo "[$(date -Iseconds)] [CREDENTIAL] $*" >> "$LF"; }
[[ ! -f "$VF" ]] && { echo '{"services":{},"api_keys":{}}' > "$VF"; chmod 600 "$VF"; }
chmod 600 "$VF" 2>/dev/null
case "$A" in
    save) S="${2:-}"; K="${3:-}"; V="${4:-}"
        [[ -z "$S" || -z "$K" || -z "$V" ]] && { echo "Uso: vault.sh save service key value"; exit 1; }
        python3 -c "
import json,os
with open('$VF') as f: v=json.load(f)
v.setdefault('services',{}).setdefault('$S',{})['$K']='$V'
v['services']['$S']['updated_at']='$(date -Iseconds)'
with open('$VF','w') as f: json.dump(v,f,indent=2)
os.chmod('$VF',0o600)
print('{\"ok\":true,\"service\":\"$S\",\"key\":\"$K\"}')"
        lg "save service=$S key=$K" ;;
    get) S="${2:-}"; K="${3:-}"
        [[ -z "$S" ]] && { echo "Uso: vault.sh get service [key]"; exit 1; }
        lg "read service=$S key=${K:-ALL}"
        python3 -c "
import json
with open('$VF') as f: v=json.load(f)
s=v.get('services',{}).get('$S',{})
if not s: print('{\"found\":false}')
elif '$K': print('{\"found\":true,\"value\":\"'+s.get('$K','NOT_FOUND')+'\"}'  )
else: print('{\"found\":true,\"keys\":'+json.dumps([k for k in s if k!='updated_at'])+'}')" ;;
    list) lg "list"
        python3 -c "
import json
with open('$VF') as f: v=json.load(f)
for n,d in v.get('services',{}).items():
    ks=[k for k in d if k!='updated_at']
    print(f'  🔑 {n}: {len(ks)} credenciais')" ;;
    generate) L="${2:-24}"; openssl rand -base64 48|tr -dc 'a-zA-Z0-9'|head -c "$L"; echo ;;
    export) S="${2:-}"; F="${3:-env}"; lg "export service=$S"
        python3 -c "
import json
with open('$VF') as f: v=json.load(f)
s=v.get('services',{}).get('$S',{})
for k,val in s.items():
    if k=='updated_at': continue
    print(f'{k.upper()}={val}' if '$F'=='env' else '')" ;;
    *) echo "Uso: vault.sh [save|get|list|generate|export]"; exit 1 ;;
esac
