# 🖥️ Control Server Skill — V1.0

> **Criado por [BollaNetwork](https://github.com/luna90b)**

Skill unificada de controle total do servidor para [OpenClaw](https://github.com/openclaw/openclaw). Transforma o agente em um DevOps inteligente que gerencia o servidor de forma segura.

## Features

- **Execução segura de comandos** — 5 níveis de risco, confiança progressiva
- **Firewall inteligente (UFW)** — Guardian anti-lockout garante que SSH e OpenClaw nunca são bloqueados
- **Instalação de serviços** — PostgreSQL, MySQL, Redis, Nginx, Node.js, PM2, Docker, Certbot
- **Vault de credenciais** — Senhas salvas de forma segura e acessíveis ao agente
- **Logs completos** — Todo comando logado com timestamp, duração, resultado
- **Diagnóstico e troubleshooting** — Health check, análise de logs, resolução automática
- **Criação de scripts** — Cria, salva e agenda scripts em ~/scripts/
- **Auditoria de portas** — Detecta portas órfãs e corrige

## Instalação

```bash
cd ~/.openclaw/skills
git clone https://github.com/luna90b/control-server-skill.git control-server
chmod +x control-server/scripts/*.sh
```

Habilitar no `~/.openclaw/openclaw.json`:
```json
{
  "skills": {
    "entries": {
      "control-server": { "enabled": true }
    }
  }
}
```

## Atualizar

```bash
cd ~/.openclaw/skills/control-server && git pull
```

## Estrutura

```
control-server/
├── SKILL.md                        # Instruções do agente
├── README.md                       # Este arquivo
├── scripts/
│   ├── guardian.sh                  # Anti-lockout (SSH + OpenClaw)
│   ├── safe_exec.sh                # Executor seguro com logging
│   ├── vault.sh                    # Gerenciador de credenciais
│   ├── service_install.sh          # Instalador de serviços
│   ├── health_check.sh             # Diagnóstico do servidor
│   ├── port_audit.sh               # Auditoria de portas UFW
│   └── log_manager.sh              # Visualizador de logs
├── references/
│   └── common_commands.md           # Referência rápida
├── data/                            # (criado em runtime)
│   ├── vault.json                   # Credenciais (chmod 600)
│   ├── server_config.json           # Config persistente
│   ├── snapshots/                   # Snapshots UFW
│   └── backups/                     # Backups de configs
└── logs/                            # (criado em runtime)
    ├── commands.log
    ├── firewall.log
    ├── installs.log
    ├── errors.log
    └── credentials.log
```

## Segurança

- **Guardian**: Todo comando UFW passa por simulate → snapshot → execute → validate
- **Vault**: Credenciais com `chmod 600`, senhas nunca nos logs
- **Proteções**: SSH e OpenClaw nunca são bloqueados, diretórios do sistema nunca deletados
- **OpenClaw**: Apenas LEITURA em `~/.openclaw/` — nunca altera configs do agente

## License

MIT

---
*BollaNetwork © 2026*
