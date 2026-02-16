#!/usr/bin/env bash
# control-server: Path Safety Validator
# Verifica se um caminho é seguro para operações destrutivas
# Uso: ./validate_path.sh <caminho> <operação>
# Retorna: exit 0 = seguro, exit 1 = BLOQUEADO

set -euo pipefail

PROTECTED_DIRS=(
    "/" "/bin" "/boot" "/dev" "/etc" "/lib" "/lib32" "/lib64"
    "/libx32" "/proc" "/root" "/run" "/sbin" "/snap" "/srv"
    "/sys" "/usr" "/var" "/opt" "/lost+found"
)

TARGET_PATH="${1:-}"
OPERATION="${2:-unknown}"

if [[ -z "$TARGET_PATH" ]]; then
    echo '{"safe": false, "reason": "Nenhum caminho fornecido", "level": 5}'
    exit 1
fi

# Resolver caminho absoluto (sem precisar que exista)
if command -v realpath &>/dev/null && [[ -e "$TARGET_PATH" ]]; then
    RESOLVED=$(realpath "$TARGET_PATH")
else
    # Fallback: resolver manualmente
    case "$TARGET_PATH" in
        /*) RESOLVED="$TARGET_PATH" ;;
        ~*) RESOLVED="${TARGET_PATH/#\~/$HOME}" ;;
        *)  RESOLVED="$(pwd)/$TARGET_PATH" ;;
    esac
fi

# Remover trailing slash
RESOLVED="${RESOLVED%/}"

# Verificar contra diretórios protegidos
for dir in "${PROTECTED_DIRS[@]}"; do
    dir="${dir%/}"
    if [[ "$RESOLVED" == "$dir" ]]; then
        echo "{\"safe\": false, \"reason\": \"Caminho protegido do sistema: $dir\", \"level\": 5, \"path\": \"$RESOLVED\"}"
        exit 1
    fi
done

# Verificar se é subdiretório direto de protegido com operação recursiva
if [[ "$OPERATION" == *"rm"* || "$OPERATION" == *"chmod -R"* || "$OPERATION" == *"chown -R"* ]]; then
    for dir in "${PROTECTED_DIRS[@]}"; do
        dir="${dir%/}"
        # Se o caminho é filho direto de diretório protegido (ex: /etc/nginx é OK para editar, mas não para rm -rf)
        if [[ "$RESOLVED" == "$dir/"* ]]; then
            # Permitir operações em subdiretórios profundos (2+ níveis)
            RELATIVE="${RESOLVED#$dir/}"
            DEPTH=$(echo "$RELATIVE" | tr '/' '\n' | wc -l)
            if [[ $DEPTH -le 1 && "$OPERATION" == *"rm"* ]]; then
                echo "{\"safe\": false, \"reason\": \"Não é seguro deletar subdiretório direto de $dir\", \"level\": 4, \"path\": \"$RESOLVED\"}"
                exit 1
            fi
        fi
    done
fi

# Tudo OK
echo "{\"safe\": true, \"reason\": \"Caminho seguro para operação\", \"level\": 1, \"path\": \"$RESOLVED\"}"
exit 0
