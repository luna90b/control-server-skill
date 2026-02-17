# 🖥️ Control Server Skill — V1.0

> **Criado por [BollaNetwork](https://github.com/luna90b)**

Skill unificada de controle total do servidor para [OpenClaw](https://github.com/openclaw/openclaw).

## Features

- **Execução segura** — 5 níveis de risco, confiança progressiva
- **Guardian anti-lockout** — Scan real de processos SSH + OpenClaw, nunca bloqueia
- **Instalação de serviços** — PostgreSQL, MySQL, Redis, Nginx, Node.js, PM2, Docker, Certbot
- **Vault de credenciais** — Senhas salvas com chmod 600, acessíveis ao agente
- **Logs completos** — Todo comando logado
- **Diagnóstico** — Health check, análise de logs, resolução automática
- **Criação de scripts** — Salva em ~/scripts/
- **Auditoria de portas** — Detecta portas órfãs

## Instalação

```bash
cd ~/.openclaw/skills
git clone https://github.com/luna90b/control-server-skill.git control-server
chmod +x control-server/scripts/*.sh
```

Habilitar no `~/.openclaw/openclaw.json`:
```json
{ "skills": { "entries": { "control-server": { "enabled": true } } } }
```

## Atualizar
```bash
cd ~/.openclaw/skills/control-server && git pull
```

## Estrutura
```
control-server/
├── SKILL.md                    # Instruções do agente
├── README.md
├── scripts/
│   ├── guardian.sh             # Anti-lockout (scan real de processos)
│   ├── safe_exec.sh            # Executor seguro com logging
│   ├── vault.sh                # Credenciais seguras
│   ├── service_install.sh      # Instalador de serviços
│   ├── health_check.sh         # Diagnóstico
│   ├── port_audit.sh           # Auditoria portas UFW
│   └── log_manager.sh          # Gerenciador de logs
├── references/
│   └── common_commands.md
├── data/                       # (runtime)
└── logs/                       # (runtime)
```

## Segurança
- Guardian escaneia processos SSH e OpenClaw em tempo real antes de cada alteração UFW
- Conta sessões SSH ativas antes de bloquear qualquer porta
- Credenciais com chmod 600
- Apenas LEITURA em ~/.openclaw/

## License
MIT — BollaNetwork © 2026
