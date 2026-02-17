#!/usr/bin/env bash
# credential_manager.sh — Gerenciador de credenciais seguro
# Armazena credenciais em arquivos individuais por serviço com permissões restritas
# Uso: bash credential_manager.sh --action [save|get|list|delete|export] --service NAME --key KEY --value VALUE --cred-dir /path

set -euo pipefail

ACTION=""
SERVICE=""
KEY=""
VALUE=""
CRED_DIR=""

# === PARSE ARGS ===
while [[ $# -gt 0 ]]; do
    case $1 in
        --action)   ACTION="$2"; shift 2 ;;
        --service)  SERVICE="$2"; shift 2 ;;
        --key)      KEY="$2"; shift 2 ;;
        --value)    VALUE="$2"; shift 2 ;;
        --cred-dir) CRED_DIR="$2"; shift 2 ;;
        *) echo "ERRO: Argumento desconhecido: $1"; exit 1 ;;
    esac
done

if [ -z "$ACTION" ] || [ -z "$CRED_DIR" ]; then
    echo "ERRO: --action e --cred-dir são obrigatórios"
    echo "Uso: bash credential_manager.sh --action [save|get|list|delete|export] --cred-dir /path"
    exit 1
fi

# Garantir diretório seguro
mkdir -p "$CRED_DIR"
chmod 700 "$CRED_DIR"

# Arquivo de credenciais por serviço (JSON simples)
get_cred_file() {
    echo "$CRED_DIR/${1}.creds"
}

# === AÇÕES ===

action_save() {
    if [ -z "$SERVICE" ] || [ -z "$KEY" ] || [ -z "$VALUE" ]; then
        echo "ERRO: --service, --key e --value são obrigatórios para save"
        exit 1
    fi
    
    local cred_file
    cred_file=$(get_cred_file "$SERVICE")
    
    # Criar ou atualizar entrada
    if [ -f "$cred_file" ]; then
        # Verificar se a chave já existe e atualizar
        if grep -q "^${KEY}=" "$cred_file" 2>/dev/null; then
            # Atualizar valor existente
            sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$cred_file"
            echo "ATUALIZADO: $SERVICE/$KEY"
        else
            # Adicionar nova chave
            echo "${KEY}=${VALUE}" >> "$cred_file"
            echo "SALVO: $SERVICE/$KEY"
        fi
    else
        # Criar novo arquivo
        echo "# Credenciais para: $SERVICE" > "$cred_file"
        echo "# Criado em: $(date '+%Y-%m-%d %H:%M:%S')" >> "$cred_file"
        echo "# ATENÇÃO: Não edite manualmente" >> "$cred_file"
        echo "${KEY}=${VALUE}" >> "$cred_file"
        echo "SALVO: $SERVICE/$KEY (novo arquivo)"
    fi
    
    # Permissões restritas
    chmod 600 "$cred_file"
}

action_get() {
    if [ -z "$SERVICE" ]; then
        echo "ERRO: --service é obrigatório para get"
        exit 1
    fi
    
    local cred_file
    cred_file=$(get_cred_file "$SERVICE")
    
    if [ ! -f "$cred_file" ]; then
        echo "ERRO: Nenhuma credencial encontrada para serviço '$SERVICE'"
        exit 1
    fi
    
    if [ -n "$KEY" ]; then
        # Retornar valor específico
        local result
        result=$(grep "^${KEY}=" "$cred_file" 2>/dev/null | head -1 | cut -d'=' -f2-)
        if [ -z "$result" ]; then
            echo "ERRO: Chave '$KEY' não encontrada para serviço '$SERVICE'"
            exit 1
        fi
        echo "$result"
    else
        # Retornar todas as credenciais do serviço (sem comentários)
        echo "=== Credenciais: $SERVICE ==="
        grep -v '^#' "$cred_file" | grep -v '^$' || echo "(vazio)"
        echo "=============================="
    fi
}

action_list() {
    echo "=== Serviços com credenciais salvas ==="
    local found=0
    for f in "$CRED_DIR"/*.creds 2>/dev/null; do
        if [ -f "$f" ]; then
            local svc_name
            svc_name=$(basename "$f" .creds)
            local keys
            keys=$(grep -v '^#' "$f" | grep -v '^$' | cut -d'=' -f1 | tr '\n' ', ' | sed 's/,$//')
            echo "  $svc_name: [$keys]"
            found=1
        fi
    done
    if [ $found -eq 0 ]; then
        echo "  (nenhuma credencial salva)"
    fi
    echo "======================================="
}

action_delete() {
    if [ -z "$SERVICE" ]; then
        echo "ERRO: --service é obrigatório para delete"
        exit 1
    fi
    
    local cred_file
    cred_file=$(get_cred_file "$SERVICE")
    
    if [ ! -f "$cred_file" ]; then
        echo "ERRO: Nenhuma credencial encontrada para serviço '$SERVICE'"
        exit 1
    fi
    
    if [ -n "$KEY" ]; then
        # Deletar chave específica
        if grep -q "^${KEY}=" "$cred_file"; then
            sed -i "/^${KEY}=/d" "$cred_file"
            echo "DELETADO: $SERVICE/$KEY"
        else
            echo "ERRO: Chave '$KEY' não encontrada"
            exit 1
        fi
    else
        # Deletar todo o arquivo de credenciais do serviço
        rm -f "$cred_file"
        echo "DELETADO: Todas as credenciais de '$SERVICE'"
    fi
}

action_export() {
    # Exportar todas as credenciais em formato ENV (para uso em scripts)
    echo "# Credenciais exportadas em $(date '+%Y-%m-%d %H:%M:%S')"
    for f in "$CRED_DIR"/*.creds 2>/dev/null; do
        if [ -f "$f" ]; then
            local svc_name
            svc_name=$(basename "$f" .creds | tr '[:lower:]' '[:upper:]' | tr '-' '_')
            while IFS='=' read -r key value; do
                [[ "$key" =~ ^#.*$ ]] && continue
                [ -z "$key" ] && continue
                local env_key
                env_key="${svc_name}_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
                echo "export ${env_key}=\"${value}\""
            done < "$f"
        fi
    done
}

# === DISPATCH ===
case "$ACTION" in
    save)   action_save ;;
    get)    action_get ;;
    list)   action_list ;;
    delete) action_delete ;;
    export) action_export ;;
    *)
        echo "ERRO: Ação '$ACTION' não reconhecida"
        echo "Ações disponíveis: save, get, list, delete, export"
        exit 1
        ;;
esac
