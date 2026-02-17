---
name: control-server
description: Execute commands on remote or local Linux servers via SSH or locally. Use when user asks to run shell commands, install packages (apt, pip, npm, PostgreSQL, Redis, Nginx, Docker, etc.), configure services, check server status, manage processes, view logs, manage files on servers, setup databases, configure firewalls, or any system administration task. Also triggers when agent needs to execute a command to complete another task, install dependencies, or when any other skill requires server-side execution. Manages credentials securely and maintains execution logs.
metadata: { "openclaw": { "emoji": "🖥️", "requires": { "bins": ["bash", "ssh"] } } }
---

# Control Server Skill

## Overview
Skill para executar comandos em servidores Linux (local ou remoto via SSH). Funciona como a "mão" do agente — qualquer tarefa que exija executar algo no servidor passa por esta skill. Mantém logs de tudo que é executado e gerencia credenciais de forma segura.

**IMPORTANTE:** Esta skill é uma skill de INFRAESTRUTURA. Outras skills podem (e devem) depender dela para executar comandos no servidor. Quando o agente precisa rodar algo no terminal para completar qualquer tarefa, esta skill deve ser utilizada.

## Arquitetura

```
{baseDir}/
├── SKILL.md                          # Este arquivo
├── scripts/
│   ├── execute.sh                    # Executor principal de comandos
│   ├── install_service.sh            # Instalador de serviços
│   ├── credential_manager.sh         # Gerenciador de credenciais
│   └── log_manager.sh               # Gerenciador de logs
├── references/
│   ├── common_services.md            # Guia de instalação de serviços comuns
│   └── security_practices.md         # Práticas de segurança
├── data/
│   ├── logs/                         # Logs de execução (criado automaticamente)
│   │   └── YYYY-MM-DD.log           # Um arquivo por dia
│   └── credentials/                  # Credenciais encriptadas
│       └── .credentials.enc         # Arquivo de credenciais
```

## Configuração Inicial

### Primeiro uso — Setup do ambiente
Na primeira execução, garanta que o diretório de dados existe:
```bash
mkdir -p {baseDir}/data/logs {baseDir}/data/credentials
chmod 700 {baseDir}/data/credentials
```

### Conexão SSH (para servidores remotos)
Se o servidor for remoto, o agente deve ter acesso SSH configurado. Verifique:
```bash
ssh -o ConnectTimeout=5 -o BatchMode=yes USER@HOST "echo ok"
```

### Servidor local
Para comandos locais, execute diretamente sem SSH.

## Instruções Principais

### 1. Executar Comando no Servidor

**Para QUALQUER comando que precise ser executado:**

1. Determine se é local ou remoto
2. Execute usando o script executor:
```bash
bash {baseDir}/scripts/execute.sh --mode [local|ssh] --host [HOST] --user [USER] --cmd "COMANDO_AQUI" --log-dir {baseDir}/data/logs
```

3. O script automaticamente:
   - Registra o comando, timestamp, e resultado no log
   - Captura stdout e stderr
   - Retorna o exit code
   - Formata a saída para o agente

**Se o script não estiver disponível, execute manualmente e registre:**
```bash
# Executar
RESULTADO=$(COMANDO_AQUI 2>&1)
EXIT_CODE=$?

# Registrar no log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD: COMANDO_AQUI | EXIT: $EXIT_CODE | OUTPUT: $RESULTADO" >> {baseDir}/data/logs/$(date '+%Y-%m-%d').log
```

### 2. Instalar Serviços e Pacotes

Para instalar qualquer serviço, use o script de instalação:
```bash
bash {baseDir}/scripts/install_service.sh --service [NOME] --log-dir {baseDir}/data/logs --cred-dir {baseDir}/data/credentials
```

Serviços suportados pelo script: `postgresql`, `redis`, `nginx`, `docker`, `nodejs`, `python3`, `certbot`, `ufw`, `fail2ban`, `pm2`

Para pacotes avulsos:
```bash
bash {baseDir}/scripts/execute.sh --mode local --cmd "sudo apt-get update && sudo apt-get install -y PACOTE" --log-dir {baseDir}/data/logs
```

**APÓS instalar qualquer serviço que gere credenciais**, salve-as:
```bash
bash {baseDir}/scripts/credential_manager.sh --action save --service NOME --key "CHAVE" --value "VALOR" --cred-dir {baseDir}/data/credentials
```

Para detalhes de instalação de cada serviço, consulte: `{baseDir}/references/common_services.md`

### 3. Gerenciar Credenciais

**Salvar credencial:**
```bash
bash {baseDir}/scripts/credential_manager.sh --action save --service "postgresql" --key "password" --value "SENHA_AQUI" --cred-dir {baseDir}/data/credentials
```

**Recuperar credencial:**
```bash
bash {baseDir}/scripts/credential_manager.sh --action get --service "postgresql" --key "password" --cred-dir {baseDir}/data/credentials
```

**Listar serviços com credenciais salvas:**
```bash
bash {baseDir}/scripts/credential_manager.sh --action list --cred-dir {baseDir}/data/credentials
```

**Remover credencial:**
```bash
bash {baseDir}/scripts/credential_manager.sh --action delete --service "postgresql" --key "password" --cred-dir {baseDir}/data/credentials
```

### 4. Consultar Logs

**Ver logs de hoje:**
```bash
bash {baseDir}/scripts/log_manager.sh --action today --log-dir {baseDir}/data/logs
```

**Ver logs de uma data:**
```bash
bash {baseDir}/scripts/log_manager.sh --action date --date "2026-02-17" --log-dir {baseDir}/data/logs
```

**Buscar nos logs:**
```bash
bash {baseDir}/scripts/log_manager.sh --action search --query "postgresql" --log-dir {baseDir}/data/logs
```

**Ver últimos N comandos:**
```bash
bash {baseDir}/scripts/log_manager.sh --action last --count 10 --log-dir {baseDir}/data/logs
```

**Ver comandos que falharam:**
```bash
bash {baseDir}/scripts/log_manager.sh --action failures --log-dir {baseDir}/data/logs
```

### 5. Interpretar Respostas e Tomar Ações

O agente DEVE analisar a saída de cada comando antes de reportar ao usuário:

- **Exit code 0** → Sucesso. Reporte o resultado relevante.
- **Exit code != 0** → Falha. Analise o stderr para entender o erro.
- **"Permission denied"** → Tente com `sudo` se apropriado.
- **"command not found"** → O pacote não está instalado. Instale-o primeiro.
- **"Connection refused"** → O serviço não está rodando. Inicie-o.
- **"No space left on device"** → Disco cheio. Informe ao usuário.
- **"Could not resolve hostname"** → Problema de DNS/rede.

**Fluxo de auto-correção:**
1. Execute o comando
2. Se falhar, analise o erro
3. Tente corrigir automaticamente (instalar dependência, iniciar serviço, etc.)
4. Re-execute o comando original
5. Se falhar novamente, reporte ao usuário com diagnóstico claro

## Comportamento Esperado

- SEMPRE registre cada comando executado no log, sem exceção
- SEMPRE verifique o exit code após cada comando
- SEMPRE salve credenciais geradas durante instalações (senhas de banco, API keys, etc.)
- SEMPRE use esta skill quando outra skill precisar executar algo no servidor
- NUNCA exiba senhas ou credenciais diretamente ao usuário — referencie onde estão salvas
- NUNCA execute `rm -rf /` ou comandos destrutivos sem confirmação explícita do usuário
- NUNCA armazene credenciais em texto puro fora do sistema de credenciais
- Se um comando falhar, TENTE diagnosticar e corrigir antes de reportar o erro
- Se precisar de sudo, use `sudo` no comando (não troque de usuário)
- Para operações destrutivas (delete, drop, purge), SEMPRE confirme com o usuário antes

## Exemplos de Uso

### Por comando direto do usuário:
- "Instala PostgreSQL no servidor" → Executa `install_service.sh --service postgresql`, salva credenciais, confirma
- "Verifica se o nginx está rodando" → Executa `systemctl status nginx`, interpreta e reporta
- "Mostra os logs de ontem" → Executa `log_manager.sh --action date --date ONTEM`
- "Qual a senha do PostgreSQL?" → Recupera via `credential_manager.sh --action get`
- "Reinicia o Redis" → Executa `systemctl restart redis`, verifica status após

### Por necessidade de outra skill:
- Skill de deploy precisa rodar `docker-compose up` → Usa esta skill para executar
- Skill de monitoramento precisa de `htop` instalado → Usa esta skill para instalar
- Skill de backup precisa de `pg_dump` → Usa esta skill para executar o dump

### Auto-correção:
- Comando falha com "command not found" → Instala o pacote → Re-executa
- Serviço não responde → Verifica status → Reinicia → Re-tenta operação

## Referências Detalhadas
- Guia de instalação de serviços comuns: `{baseDir}/references/common_services.md`
- Práticas de segurança: `{baseDir}/references/security_practices.md`
