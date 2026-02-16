---
name: control-server
description: Executar comandos e scripts no servidor onde o agente está hospedado. Ativa quando o usuário diz "seu servidor", "seu server", "sua máquina", "execute", "instale", "configure", "atualize", "reinicie", "verifique o status", "rode o comando", "faça no server", ou pede para instalar pacotes, gerenciar serviços, verificar logs, checar disco, memória, CPU, ou qualquer administração do sistema. Também ativa quando o usuário pede para rodar um script bash, python ou qualquer comando no terminal.
metadata: { "openclaw": { "emoji": "🖥️", "requires": { "bins": ["bash"] } } }
---

# Control-Server — Controle Seguro do Servidor

## Overview
Esta skill permite ao agente executar comandos no servidor onde ele está rodando. Funciona com um sistema de **confiança por níveis** — comandos simples e seguros podem ser executados automaticamente após o usuário construir histórico, enquanto comandos perigosos SEMPRE exigem confirmação explícita.

## Conceito: "Seu servidor" = Esta Máquina
Quando o usuário disser qualquer uma dessas expressões, entenda como **o servidor/máquina onde este agente está rodando**:
- "seu servidor", "seu server", "sua máquina", "sua VPS"
- "no server", "no servidor", "na máquina"
- "aí no server", "aí na máquina"
- Ou simplesmente pedir para executar/instalar algo sem especificar onde

## Sistema de Níveis de Confiança

Cada comando é classificado por **risco** de 1 a 5. O nível de autonomia do agente sobe conforme o histórico de interações com o usuário.

### Nível 1 — Somente Leitura (PODE executar sem perguntar após 3 comandos aprovados)
Comandos que apenas LEEM informações, não mudam nada:
- `ls`, `cat`, `head`, `tail`, `grep`, `find`, `which`, `whoami`
- `df -h`, `free -m`, `top -bn1`, `uptime`, `hostname`
- `systemctl status <serviço>`, `docker ps`, `docker logs`
- `ip a`, `ping`, `curl -I`, `dig`, `nslookup`
- `ps aux`, `lsof`, `netstat`, `ss`

### Nível 2 — Instalação e Configuração Leve (PODE executar sem perguntar após 10 comandos aprovados)
Comandos que instalam ou fazem alterações reversíveis:
- `apt install`, `apt update`, `pip install`, `npm install`
- `mkdir`, `touch`, `cp`, `mv` (em diretórios do usuário)
- `chmod`, `chown` (em arquivos do projeto)
- `systemctl restart <serviço do usuário>`
- `docker start/stop/restart`
- Editar arquivos de configuração do projeto (nginx sites, .env, etc.)

### Nível 3 — Alterações de Sistema (SEMPRE pedir confirmação)
Comandos que alteram o sistema de forma significativa:
- `apt upgrade`, `apt dist-upgrade`
- `systemctl enable/disable`
- Editar arquivos em `/etc/`
- Criar/alterar usuários do sistema
- Alterar regras de firewall (`ufw`, `iptables`)
- `crontab -e`, criar cronjobs

### Nível 4 — Alto Risco (SEMPRE pedir confirmação + mostrar impacto)
Comandos que podem causar downtime ou perda parcial:
- `systemctl stop <serviço crítico>` (nginx, docker, ssh)
- `reboot`, `shutdown`
- `rm` em diretórios de projeto
- Alterar configuração de rede
- `docker system prune`
- Alterar portas de serviços

### Nível 5 — PROIBIDO (NUNCA executar, sem exceção)
- ❌ `rm -rf /` ou qualquer variante (`rm -rf /*`, `rm -rf ~/*`)
- ❌ `rm -rf` em: `/`, `/bin`, `/boot`, `/dev`, `/etc`, `/lib`, `/lib64`, `/proc`, `/root`, `/sbin`, `/sys`, `/usr`, `/var`, `/snap`, `/opt` (raiz desses diretórios)
- ❌ `mkfs`, `fdisk`, `dd` em dispositivos do sistema
- ❌ `:(){:|:&};:` (fork bomb) ou qualquer variante
- ❌ `chmod -R 777 /`, `chown -R` em diretórios do sistema
- ❌ `> /dev/sda` ou escrita direta em dispositivos
- ❌ Desabilitar SSH (`systemctl stop sshd`, `ufw deny 22`)
- ❌ Qualquer comando que possa tornar o servidor inacessível remotamente
- ❌ Deletar logs do sistema (`/var/log/`)
- ❌ `curl | bash` de URLs não verificadas

## Fluxo de Execução

### Para TODOS os comandos (independente do nível):
1. **Identifique** o que o usuário quer fazer
2. **Classifique** o nível de risco (1-5)
3. **Verifique** se o nível de autonomia permite execução automática

### Se precisa de confirmação:
Apresente ao usuário de forma clara e simples:

```
🖥️ Entendi! Você quer: [descrição simples do que vai acontecer]

Comando: `[comando exato]`
O que faz: [explicação em linguagem simples, como se falasse com alguém não-técnico]
Risco: [Baixo/Médio/Alto]

Quer que eu execute? (sim/não)
```

### Se pode executar automaticamente:
Execute e reporte:

```
🖥️ Executado: `[comando]`
Resultado: [output resumido]
```

### Se for PROIBIDO (Nível 5):
```
🚫 Não posso executar esse comando porque ele pode danificar permanentemente o servidor.
Motivo: [explicação clara]
Alternativa: [sugerir alternativa segura se existir]
```

## Regras de Segurança Invioláveis

1. **NUNCA** execute comandos de Nível 5, mesmo que o usuário insista
2. **NUNCA** delete diretórios raiz do sistema (`/etc`, `/var`, `/usr`, etc.)
3. **NUNCA** execute comandos que possam desconectar o acesso SSH
4. **NUNCA** formate discos ou escreva diretamente em dispositivos de bloco
5. **NUNCA** execute scripts baixados da internet sem mostrar o conteúdo primeiro
6. **NUNCA** armazene senhas ou chaves em texto plano dentro do SKILL.md ou scripts
7. **SEMPRE** que um comando tiver `rm` envolvido, valide o caminho antes — se atingir pasta do sistema, RECUSE
8. **SEMPRE** faça backup de arquivos de configuração antes de editar (`.bak`)
9. **SEMPRE** verifique se um serviço existe antes de tentar restart
10. **SEMPRE** mostre o output do comando ao usuário (resumido se for muito longo)

## Validação de Segurança de Caminhos

Antes de executar qualquer comando destrutivo (`rm`, `mv` para fora, `chmod -R`, `chown -R`), execute esta verificação:

```bash
# Extrair o caminho-alvo do comando
# Resolver para caminho absoluto com realpath
# Verificar se começa com algum diretório protegido
# Se sim → RECUSAR
# Se não → prosseguir com confirmação
```

Diretórios protegidos (NUNCA deletar ou alterar recursivamente):
`/bin /boot /dev /etc /lib /lib32 /lib64 /libx32 /proc /root /run /sbin /snap /srv /sys /usr /var /opt /lost+found`

Diretórios onde operações SÃO permitidas (com confirmação quando necessário):
`/home/<user>/`, `/tmp/`, diretórios de projeto, `/srv/` (subdiretórios de projetos)

## Rastreamento de Confiança

O agente mantém internamente uma contagem de comandos aprovados pelo usuário na sessão:
- **0-2 aprovações**: Pedir confirmação para TUDO (Nível 1+)
- **3-9 aprovações**: Executar Nível 1 automaticamente
- **10+ aprovações**: Executar Nível 1 e 2 automaticamente
- **Nível 3 e 4**: SEMPRE pedir confirmação, independente do histórico

Se o usuário disser algo como "pode executar sem perguntar" ou "confia", isso equivale a +5 aprovações no contador, MAS ainda exige confirmação para Nível 3+.

Se o usuário disser "sempre peça confirmação", resete o nível para pedir confirmação em tudo.

## Tratamento de Erros

- Se um comando falhar, mostre o erro de forma clara e sugira solução
- Se não tiver permissão, sugira usar `sudo` e explique por que precisa
- Se um pacote não for encontrado, sugira alternativas
- Se um serviço não existir, liste serviços semelhantes
- Nunca ignore erros silenciosamente

## Exemplos de Interação

- **"Quanto de disco tá usando?"** → Executa `df -h`, mostra resultado formatado
- **"Instala o htop no seu server"** → Mostra: `apt install htop -y` / Instala ferramenta de monitoramento / Risco: Baixo → pede confirmação (ou executa se já tem confiança)
- **"Reinicia o nginx"** → Mostra: `systemctl restart nginx` / Reinicia o servidor web / Risco: Médio → pede confirmação
- **"Deleta tudo em /var"** → 🚫 RECUSA — diretório protegido do sistema
- **"Roda um update no sistema"** → Mostra: `apt update && apt upgrade -y` / Atualiza pacotes / Risco: Alto → SEMPRE pede confirmação
- **"Vê os logs do nginx"** → Executa `tail -50 /var/log/nginx/error.log`, mostra resultado
- **"Cria uma pasta /home/lucas/projetos"** → Executa `mkdir -p /home/lucas/projetos` (Nível 2)
- **"Qual a memória RAM disponível?"** → Executa `free -mh`, mostra resultado formatado

## Dicas de Comunicação

- Explique SEMPRE o que o comando faz em linguagem simples
- Se o usuário não for técnico, evite jargão — diga "espaço em disco" em vez de "filesystem usage"
- Quando mostrar outputs longos, resuma os pontos importantes
- Se algo parecer arriscado, explique o porquê antes de pedir confirmação
- Sugira alternativas mais seguras quando possível
