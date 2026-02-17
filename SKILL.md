---
name: control-server
description: "Controle completo do servidor onde o agente roda. Executar comandos, instalar pacotes, gerenciar serviços, firewall UFW, deploy de projetos, DNS, Nginx, PM2, SSL, PostgreSQL, MySQL, Redis, análise de logs, troubleshooting automático, e criação de scripts. Ativa quando o usuário diz: 'seu servidor', 'seu server', 'sua máquina', 'execute', 'instale', 'configure', 'atualize', 'reinicie', 'deploy', 'colocar online', 'firewall', 'abrir porta', 'fechar porta', 'proteger servidor', 'verificar portas', 'banco de dados', 'PostgreSQL', 'MySQL', 'Redis', 'nginx', 'pm2', 'domínio', 'subdomínio', 'DNS', 'SSL', 'certbot', 'logs', 'erro', 'diagnosticar', 'health check', 'cria um script', ou qualquer tarefa de administração do servidor."
metadata: { "openclaw": { "emoji": "🖥️", "requires": { "bins": ["bash", "ufw", "ss"] } } }
---

# Control Server — V1.0

> **Criado por [BollaNetwork](https://github.com/luna90b)**
> **Repositório:** https://github.com/luna90b/control-server-skill
> **Para atualizar:** `cd ~/.openclaw/skills/control-server && git pull`

## Overview

Skill unificada de controle total do servidor. O agente usa esta skill como ponte para executar QUALQUER tarefa que precise rodar na máquina — desde verificar disco até deploy completo com domínio e SSL. Funciona como um DevOps inteligente integrado ao OpenClaw.

**Esta skill é também o "braço" do agente no servidor.** Quando qualquer outra tarefa ou resposta do OpenClaw precisar executar um comando na máquina, esta skill é acionada para fazer isso de forma segura.

## Conceitos Fundamentais

### "Seu servidor" = Esta Máquina
Expressões que significam o servidor onde o agente roda:
- "seu servidor", "seu server", "sua máquina", "sua VPS"
- "no server", "na máquina", "aí no server"
- Ou simplesmente pedir para executar/instalar algo

### Skill como Ponte
O agente frequentemente precisa executar comandos para completar tarefas que NÃO são explicitamente "de servidor". Exemplos:
- Tarefa: "configura o banco pro meu projeto" → Precisa rodar `psql`, `createdb`, etc.
- Tarefa: "verifica se meu site tá no ar" → Precisa rodar `curl`, `systemctl status`
- Tarefa: "atualiza meu projeto" → Precisa rodar `git pull`, `npm install`, `pm2 restart`

Nestes casos, o agente usa esta skill internamente sem necessariamente mencionar ao usuário que está "usando a skill de servidor".

## Sistema de Logs — Tudo é Registrado

**TODA ação executada por esta skill é logada.** Sem exceção.

### Localização: `{baseDir}/logs/`
- `commands.log` — Todo comando executado: timestamp, comando, exit code, quem pediu
- `installs.log` — Todo pacote/serviço instalado
- `firewall.log` — Toda alteração de UFW
- `deploys.log` — Todo deploy realizado
- `errors.log` — Todo erro encontrado e como foi resolvido
- `credentials.log` — Todo acesso a credenciais (sem mostrar a senha, só o que foi acessado)

### Formato do log:
```
[2026-02-17T14:30:00Z] [COMMAND] user_request="instala htop" cmd="apt install htop -y" exit=0 duration=3s
[2026-02-17T14:31:00Z] [FIREWALL] action="allow" port=3000 proto=tcp comment="Node app" snapshot="20260217_143100"
[2026-02-17T14:32:00Z] [INSTALL] package="postgresql-16" method="apt" status="success"
[2026-02-17T14:33:00Z] [CREDENTIAL] action="save" service="postgresql" user="meu_projeto_db" stored_at="vault"
```

### Regras de log:
1. **SEMPRE** logar antes e depois de executar
2. **NUNCA** logar senhas, tokens ou chaves nos logs
3. Manter logs dos últimos 30 dias (rotacionar automaticamente)
4. O agente pode consultar logs para entender histórico: "o que foi feito ontem?"

## Sistema de Credenciais Seguras (Vault)

Credenciais de serviços (banco de dados, APIs, etc.) são salvas de forma segura para o agente reutilizar.

### Localização: `{baseDir}/data/vault.json`
### Permissões: `chmod 600` (só o dono lê)

### Estrutura:
```json
{
  "services": {
    "postgresql": {
      "host": "localhost",
      "port": 5432,
      "databases": {
        "meu_projeto": {
          "db_name": "meu_projeto_db",
          "user": "meu_projeto_user",
          "password": "ENCRYPTED_OR_REFERENCE",
          "created_at": "2026-02-17",
          "used_by": ["meu-projeto-api"]
        }
      }
    },
    "mysql": { ... },
    "redis": {
      "host": "localhost",
      "port": 6379,
      "password": "ENCRYPTED_OR_REFERENCE",
      "databases": { ... }
    }
  },
  "api_keys": {
    "projeto-x": {
      "key_name": "API_KEY",
      "env_var": "PROJETO_X_API_KEY",
      "stored_in": "env_file",
      "path": "/home/lucas/projects/projeto-x/.env"
    }
  }
}
```

### Regras do vault:
1. **NUNCA** mostrar senhas em texto claro na conversa — usar `****` ou referência
2. **SEMPRE** `chmod 600` no vault.json após alterar
3. Quando o agente precisar de uma credencial, buscar no vault PRIMEIRO
4. Se não existir, perguntar ao usuário ou gerar automaticamente
5. Senhas geradas automaticamente: mínimo 24 chars, alfanumérico + especiais
6. **SEMPRE** logar acesso ao vault (sem mostrar a senha)

### Como o agente usa o vault:
```
Agente precisa conectar no PostgreSQL do projeto X
  → Lê vault.json → encontra credenciais
  → Usa para executar comandos psql
  → Loga: "[CREDENTIAL] action=read service=postgresql db=meu_projeto_db"
```

## Níveis de Confiança para Comandos

### Nível 1 — Leitura (auto após 3 aprovações)
`ls`, `cat`, `head`, `tail`, `grep`, `find`, `df -h`, `free -m`, `uptime`, `systemctl status`, `docker ps`, `docker logs`, `ip a`, `ping`, `curl -I`, `ps aux`, `ss -tlnp`, `pm2 list`, `pm2 logs`, `nginx -t`

### Nível 2 — Instalação leve (auto após 10 aprovações)
`apt install`, `apt update`, `pip install`, `npm install`, `mkdir`, `cp`, `mv`, `chmod`, `chown` (em pastas do projeto), `systemctl restart`, `docker restart`, `pm2 restart`

### Nível 3 — Alteração de sistema (SEMPRE confirmação)
`apt upgrade`, `systemctl enable/disable`, editar `/etc/`, criar usuários, firewall, cronjobs, configurar serviços (PostgreSQL, Nginx, etc.)

### Nível 4 — Alto risco (SEMPRE confirmação + impacto)
`systemctl stop` serviço crítico, `reboot`, `rm` em projetos, `docker system prune`

### Nível 5 — PROIBIDO (nunca, sem exceção)
`rm -rf /` e variantes, `mkfs`, `dd` em dispositivos, fork bomb, `chmod -R 777 /`, fechar SSH, desabilitar acesso remoto, deletar `/var/log/`, `curl | bash`

## Instalação e Configuração de Serviços

### PostgreSQL

**Instalar:**
```bash
apt install postgresql postgresql-contrib -y
systemctl enable postgresql
systemctl start postgresql
```

**Criar banco para projeto:**
```bash
# Gerar senha segura
PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Criar user e banco
sudo -u postgres psql -c "CREATE USER nome_user WITH PASSWORD '$PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE nome_db OWNER nome_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE nome_db TO nome_user;"

# Salvar no vault
# Logar criação
```

**Após instalar:** Salvar credenciais no vault, logar em installs.log, informar usuário.

### MySQL / MariaDB

**Instalar:**
```bash
apt install mariadb-server -y
systemctl enable mariadb
systemctl start mariadb
mysql_secure_installation  # Guiar usuário interativamente
```

**Criar banco:**
```bash
PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
mysql -u root -e "CREATE DATABASE nome_db;"
mysql -u root -e "CREATE USER 'nome_user'@'localhost' IDENTIFIED BY '$PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON nome_db.* TO 'nome_user'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
```

### Redis

**Instalar:**
```bash
apt install redis-server -y
systemctl enable redis-server
# Configurar senha:
# Editar /etc/redis/redis.conf → requirepass <senha>
systemctl restart redis-server
```

### Node.js (via nvm)
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm alias default 20
npm install -g pm2
```

### Nginx
```bash
apt install nginx -y
systemctl enable nginx
```

### Certbot (SSL)
```bash
apt install certbot python3-certbot-nginx -y
```

### Regras para instalação de serviços:
1. **SEMPRE** Nível 3 — pedir confirmação
2. **SEMPRE** habilitar no systemd (`enable`)
3. **SEMPRE** salvar credenciais no vault
4. **SEMPRE** logar em `installs.log`
5. **SEMPRE** verificar se já está instalado antes
6. Para bancos: **SEMPRE** gerar senha forte automaticamente
7. Para bancos: **NUNCA** abrir porta pro mundo no UFW (só localhost)

## Firewall (UFW) com Guardian

### Pipeline de segurança — todo comando UFW passa por:
```
1. SIMULATE → Testar se é seguro (sem executar)
2. SNAPSHOT → Salvar estado atual
3. EXECUTE  → Rodar comando
4. VALIDATE → Verificar SSH + OpenClaw intactos
   → Se quebrou → AUTO-FIX instantâneo
```

### Detecção automática antes de qualquer alteração:
```bash
# Porta SSH real (lê sshd_config + processo)
SSH_PORT=$(grep -oP '^\s*Port\s+\K[0-9]+' /etc/ssh/sshd_config 2>/dev/null || echo "22")

# OpenClaw Gateway (SÓ LEITURA do config, NUNCA alterar)
GW_PORT=$(grep -oP '"port"\s*:\s*\K[0-9]+' ~/.openclaw/openclaw.json 2>/dev/null || echo "18789")
GW_BIND=$(grep -oP '"bind"\s*:\s*"\K[^"]+' ~/.openclaw/openclaw.json 2>/dev/null || echo "loopback")
```

### BLOQUEADO (nunca executa):
- Fechar porta SSH
- Fechar porta do OpenClaw Gateway (se exposta)
- `default deny outgoing`

### Relação com OpenClaw — SÓ LEITURA:
- ✅ Ler `~/.openclaw/openclaw.json` para detectar porta/bind
- ❌ NUNCA alterar qualquer arquivo em `~/.openclaw/`
- ❌ NUNCA mexer no systemd do OpenClaw
- ❌ NUNCA matar processos do OpenClaw

## Análise de Logs e Troubleshooting

### Dois modos:

**Guiado:** Mostra problema, explica, dá opções numeradas para escolher.
**Autônomo:** "Resolve sozinho" — corrige problemas leves/médios direto, mostra plano para graves.

### Cadeia de investigação:
```
1. systemctl --failed (serviços caídos?)
2. df -h (disco cheio?)
3. free -mh (memória esgotada?)
4. dmesg | grep error (hardware?)
5. → Se achou problema → investigar logs específicos do serviço
6. → Propor/executar solução
7. → Verificar que funcionou
8. → Checar que nada mais quebrou
```

### Regras de troubleshooting:
- **NUNCA** deletar logs como "solução"
- **NUNCA** `kill -9` sem saber o que é o processo
- **NUNCA** reiniciar servidor inteiro como primeira opção
- **SEMPRE** verificar dependências antes de reiniciar serviço
- **SEMPRE** informar o que foi feito

## Criação de Scripts

Salvar em `~/scripts/`. Regras:
1. Mostrar código completo antes de salvar
2. Explicar o que faz em linguagem simples
3. Pedir confirmação antes de salvar e executar
4. `chmod +x` após salvar
5. Comentário no topo explicando o que faz
6. NUNCA criar em pastas do sistema
7. NUNCA senhas hardcoded — usar variáveis de ambiente ou vault

## Configuração Persistente

`{baseDir}/data/server_config.json` — Salva informações do servidor para reusar:
- IP externo, usuário, pasta de projetos
- Domínios e wildcard DNS configurados
- Projetos ativos com porta, domínio, PM2 name
- Serviços instalados e status

Na primeira interação perguntar informações básicas. Depois usar automaticamente.

## Segurança — Diretórios Protegidos

**NUNCA deletar ou alterar recursivamente:**
`/bin /boot /dev /etc /lib /lib64 /proc /root /sbin /sys /usr /var /opt /snap`

**NUNCA alterar:**
`~/.openclaw/` (SÓ LEITURA para detecção)

**Operações permitidas (com confirmação):**
`/home/<user>/`, `/tmp/`, diretórios de projetos, `/srv/`

## Exemplos de Interação

- **"Quanto de disco tá usando?"** → `df -h` (Nível 1)
- **"Instala PostgreSQL"** → Instala, configura, gera senha, salva no vault
- **"Cria banco pro meu projeto"** → Cria user + db, salva credenciais, mostra .env
- **"Protege meu servidor"** → Guardian scan → setup UFW seguro
- **"Deploy github.com/user/app"** → Clone → install → build → PM2 → Nginx → SSL
- **"O site caiu"** → Diagnóstico completo → opções ou fix autônomo
- **"Qual a senha do banco do projeto X?"** → Busca no vault → mostra referência
- **"Cria script de backup"** → Mostra código → confirmação → salva em ~/scripts/
- **"O que foi feito ontem no server?"** → Consulta logs → resumo

## Referências
- Comandos comuns: `{baseDir}/references/common_commands.md`
- Para atualizar skill: `cd {baseDir} && git pull` ou veja https://github.com/luna90b/control-server-skill
