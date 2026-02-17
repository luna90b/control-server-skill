#!/usr/bin/env bash
# Control Server v1.0 — Vault Manager (Credential Storage)
# Criado por BollaNetwork — https://github.com/luna90b/control-server-skill
#
# Uso:
#   ./vault.sh save <service> <key> <value>     → Salvar credencial
#   ./vault.sh get <service> [key]               → Buscar credencial
#   ./vault.sh list                              → Listar serviços salvos
#   ./vault.sh generate [length]                 → Gerar senha segura
#   ./vault.sh export <service> <format>         → Exportar como .env ou JSON

set -euo pipefail

ACTION="${1:-}"
SKILL_DIR="${HOME}/.openclaw/skills/control-server"
VAULT_FILE="${SKILL_DIR}/data/vault.json"
LOG_FILE="${SKILL_DIR}/logs/credentials.log"

mkdir -p "$(dirname "$VAULT_FILE")" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_cred() { echo "[$(date -Iseconds)] [CREDENTIAL] $*" >> "$LOG_FILE"; }

# Inicializar vault se não existe
if [[ ! -f "$VAULT_FILE" ]]; then
    echo '{"services":{},"api_keys":{}}' > "$VAULT_FILE"
    chmod 600 "$VAULT_FILE"
fi

# Garantir permissão
chmod 600 "$VAULT_FILE" 2>/dev/null

case "$ACTION" in
    save)
        SERVICE="${2:-}"
        KEY="${3:-}"
        VALUE="${4:-}"
        
        if [[ -z "$SERVICE" || -z "$KEY" || -z "$VALUE" ]]; then
            echo '{"error":"Uso: vault.sh save <service> <key> <value>"}'
            exit 1
        fi
        
        python3 -c "
import json, os
vault_path = '$VAULT_FILE'
with open(vault_path) as f:
    vault = json.load(f)

vault.setdefault('services', {})
vault['services'].setdefault('$SERVICE', {})
vault['services']['$SERVICE']['$KEY'] = '$VALUE'
vault['services']['$SERVICE']['updated_at'] = '$(date -Iseconds)'

with open(vault_path, 'w') as f:
    json.dump(vault, f, indent=2)
os.chmod(vault_path, 0o600)
print(json.dumps({'success': True, 'service': '$SERVICE', 'key': '$KEY'}))
" 2>/dev/null
        
        log_cred "action=save service=$SERVICE key=$KEY"
        ;;
    
    get)
        SERVICE="${2:-}"
        KEY="${3:-}"
        
        if [[ -z "$SERVICE" ]]; then
            echo '{"error":"Uso: vault.sh get <service> [key]"}'
            exit 1
        fi
        
        log_cred "action=read service=$SERVICE key=${KEY:-ALL}"
        
        python3 -c "
import json
with open('$VAULT_FILE') as f:
    vault = json.load(f)

service = vault.get('services', {}).get('$SERVICE', {})
if not service:
    print(json.dumps({'found': False, 'service': '$SERVICE'}))
elif '$KEY':
    val = service.get('$KEY', None)
    if val:
        print(json.dumps({'found': True, 'service': '$SERVICE', 'key': '$KEY', 'value': val}))
    else:
        print(json.dumps({'found': False, 'service': '$SERVICE', 'key': '$KEY'}))
else:
    keys = [k for k in service.keys() if k != 'updated_at']
    print(json.dumps({'found': True, 'service': '$SERVICE', 'keys': keys}))
" 2>/dev/null
        ;;
    
    list)
        log_cred "action=list"
        python3 -c "
import json
with open('$VAULT_FILE') as f:
    vault = json.load(f)

services = vault.get('services', {})
api_keys = vault.get('api_keys', {})

print('📦 Serviços salvos:')
if not services:
    print('  (nenhum)')
for name, data in services.items():
    keys = [k for k in data.keys() if k != 'updated_at']
    updated = data.get('updated_at', '?')
    print(f'  🔑 {name}: {len(keys)} credenciais (atualizado: {updated})')

if api_keys:
    print('\\n🔐 API Keys:')
    for name, data in api_keys.items():
        print(f'  🔑 {name}: env_var={data.get(\"env_var\", \"?\")}')" 2>/dev/null
        ;;
    
    generate)
        LENGTH="${2:-24}"
        PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%&*' | head -c "$LENGTH")
        echo "$PASSWORD"
        ;;
    
    export)
        SERVICE="${2:-}"
        FORMAT="${3:-env}"
        
        if [[ -z "$SERVICE" ]]; then
            echo '{"error":"Uso: vault.sh export <service> <format: env|json>"}'
            exit 1
        fi
        
        log_cred "action=export service=$SERVICE format=$FORMAT"
        
        python3 -c "
import json
with open('$VAULT_FILE') as f:
    vault = json.load(f)

service = vault.get('services', {}).get('$SERVICE', {})
if not service:
    print('# Serviço não encontrado: $SERVICE')
    exit()

fmt = '$FORMAT'
if fmt == 'env':
    for k, v in service.items():
        if k == 'updated_at': continue
        print(f'{k.upper()}={v}')
elif fmt == 'json':
    clean = {k: v for k, v in service.items() if k != 'updated_at'}
    print(json.dumps(clean, indent=2))
" 2>/dev/null
        ;;
    
    *)
        echo "Uso: vault.sh [save|get|list|generate|export]"
        echo "  save <service> <key> <value>  → Salvar credencial"
        echo "  get <service> [key]            → Buscar credencial"
        echo "  list                           → Listar tudo"
        echo "  generate [length]              → Gerar senha"
        echo "  export <service> <env|json>    → Exportar"
        exit 1
        ;;
esac
