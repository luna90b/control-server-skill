#!/usr/bin/env bash
# control-server: Command Risk Classifier
# Classifica um comando pelo nível de risco (1-5)
# Uso: ./classify_command.sh "<comando>"
# Output: JSON com level, category, description, needs_confirmation

set -euo pipefail

CMD="${1:-}"

if [[ -z "$CMD" ]]; then
    echo '{"level": 0, "category": "invalid", "description": "Nenhum comando fornecido", "needs_confirmation": true}'
    exit 1
fi

# Normalizar: lowercase para matching
CMD_LOWER=$(echo "$CMD" | tr '[:upper:]' '[:lower:]')

# ===== NÍVEL 5: PROIBIDO =====
FORBIDDEN_PATTERNS=(
    "rm -rf /"
    "rm -rf /*"
    "rm -rf ~/*"
    "rm -rf /bin" "rm -rf /boot" "rm -rf /dev" "rm -rf /etc"
    "rm -rf /lib" "rm -rf /proc" "rm -rf /root" "rm -rf /sbin"
    "rm -rf /sys" "rm -rf /usr" "rm -rf /var" "rm -rf /opt"
    "rm -rf /snap" "rm -rf /srv" "rm -rf /run"
    "mkfs" "fdisk" "dd if=" "dd of=/dev"
    ":(){ :|:&};:" ":(){" "fork bomb"
    "chmod -r 777 /"
    "chown -r" # seguido de /
    "> /dev/sd"
    "systemctl stop sshd" "systemctl stop ssh"
    "ufw deny 22" "iptables.*drop.*22"
    "curl.*|.*bash" "wget.*|.*bash"
    "curl.*|.*sh" "wget.*|.*sh"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if echo "$CMD_LOWER" | grep -qiE "$pattern" 2>/dev/null; then
        echo "{\"level\": 5, \"category\": \"forbidden\", \"description\": \"Comando proibido: pode destruir o sistema\", \"needs_confirmation\": false, \"blocked\": true}"
        exit 0
    fi
done

# ===== NÍVEL 4: ALTO RISCO =====
if echo "$CMD_LOWER" | grep -qE "(reboot|shutdown|poweroff|halt)"; then
    echo '{"level": 4, "category": "high_risk", "description": "Reiniciar/desligar servidor", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "systemctl (stop|disable) (nginx|docker|apache|mysql|postgresql|mariadb|redis)"; then
    echo '{"level": 4, "category": "high_risk", "description": "Parar serviço crítico", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "docker system prune"; then
    echo '{"level": 4, "category": "high_risk", "description": "Limpar todos containers/imagens Docker não usados", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "rm -rf? /home"; then
    echo '{"level": 4, "category": "high_risk", "description": "Deletar diretórios de usuário", "needs_confirmation": true}'
    exit 0
fi

# ===== NÍVEL 3: ALTERAÇÃO DE SISTEMA =====
if echo "$CMD_LOWER" | grep -qE "(apt upgrade|apt dist-upgrade|apt full-upgrade)"; then
    echo '{"level": 3, "category": "system_change", "description": "Atualizar pacotes do sistema", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "systemctl (enable|disable)"; then
    echo '{"level": 3, "category": "system_change", "description": "Habilitar/desabilitar serviço na inicialização", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(ufw|iptables|firewall)"; then
    echo '{"level": 3, "category": "system_change", "description": "Alterar regras de firewall", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(crontab|/etc/cron)"; then
    echo '{"level": 3, "category": "system_change", "description": "Alterar tarefas agendadas", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(adduser|useradd|usermod|userdel|passwd)"; then
    echo '{"level": 3, "category": "system_change", "description": "Gerenciar usuários do sistema", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(nano|vim|vi|tee|sed.*-i) .*/etc/"; then
    echo '{"level": 3, "category": "system_change", "description": "Editar arquivo de configuração do sistema", "needs_confirmation": true}'
    exit 0
fi

# ===== NÍVEL 2: INSTALAÇÃO/CONFIG LEVE =====
if echo "$CMD_LOWER" | grep -qE "(apt install|apt-get install|apt remove)"; then
    echo '{"level": 2, "category": "install", "description": "Instalar/remover pacote", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(pip install|pip3 install|npm install|npm i |yarn add)"; then
    echo '{"level": 2, "category": "install", "description": "Instalar pacote de linguagem", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(mkdir|touch|cp |mv )"; then
    echo '{"level": 2, "category": "file_manage", "description": "Criar/copiar/mover arquivo ou pasta", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "(chmod|chown)" && ! echo "$CMD_LOWER" | grep -qE "(-R|--recursive).*/"; then
    echo '{"level": 2, "category": "permissions", "description": "Alterar permissões de arquivo", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "systemctl restart"; then
    echo '{"level": 2, "category": "service", "description": "Reiniciar serviço", "needs_confirmation": true}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "docker (start|stop|restart|exec|run)"; then
    echo '{"level": 2, "category": "docker", "description": "Gerenciar container Docker", "needs_confirmation": true}'
    exit 0
fi

# ===== NÍVEL 1: SOMENTE LEITURA =====
if echo "$CMD_LOWER" | grep -qE "^(ls|cat|head|tail|grep|find|which|whoami|pwd|echo|date|wc)"; then
    echo '{"level": 1, "category": "read_only", "description": "Comando de leitura", "needs_confirmation": false}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "^(df|free|top|uptime|hostname|uname|lsb_release)"; then
    echo '{"level": 1, "category": "system_info", "description": "Informação do sistema", "needs_confirmation": false}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "^(systemctl status|service.*status|docker ps|docker logs|docker images)"; then
    echo '{"level": 1, "category": "status", "description": "Verificar status de serviço", "needs_confirmation": false}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "^(ip |ifconfig|ping|curl -I|dig|nslookup|traceroute|ss |netstat)"; then
    echo '{"level": 1, "category": "network_info", "description": "Informação de rede", "needs_confirmation": false}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "^(ps|lsof|htop|iotop|nproc|lscpu|lsmem)"; then
    echo '{"level": 1, "category": "process_info", "description": "Informação de processos", "needs_confirmation": false}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "^(apt list|dpkg -l|pip list|npm list)"; then
    echo '{"level": 1, "category": "package_info", "description": "Listar pacotes instalados", "needs_confirmation": false}'
    exit 0
fi
if echo "$CMD_LOWER" | grep -qE "^(tail|less|more|journalctl).*log"; then
    echo '{"level": 1, "category": "logs", "description": "Visualizar logs", "needs_confirmation": false}'
    exit 0
fi

# ===== DEFAULT: DESCONHECIDO → pedir confirmação =====
echo '{"level": 3, "category": "unknown", "description": "Comando não classificado — requer confirmação por segurança", "needs_confirmation": true}'
exit 0
