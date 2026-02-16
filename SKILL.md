---
name: control-server
description: Executar comandos, criar scripts, analisar logs e resolver problemas no servidor onde o agente está hospedado. Ativa quando o usuário diz "seu servidor", "seu server", "sua máquina", "execute", "instale", "configure", "atualize", "reinicie", "verifique o status", "rode o comando", "faça no server", "verifica os logs", "tem algum erro", "tá fora do ar", "diagnostica", "health check", "resolve isso", "arruma", "fix it", "cria um script", ou pede para instalar pacotes, gerenciar serviços, verificar logs, checar disco, memória, CPU, diagnosticar problemas, ou qualquer administração do sistema.
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

## Criação de Scripts

O agente pode criar scripts novos quando o usuário pedir. Exemplos: automações, backups, monitoramento, tarefas repetitivas, etc.

### Regras para criar scripts:

1. **SEMPRE** salvar em `~/scripts/` (criar a pasta se não existir com `mkdir -p ~/scripts/`)
2. **SEMPRE** mostrar o código completo ao usuário ANTES de salvar
3. **SEMPRE** explicar o que cada parte do script faz, em linguagem simples
4. **SEMPRE** pedir confirmação antes de salvar e executar
5. **SEMPRE** tornar o script executável após salvar (`chmod +x`)
6. **SEMPRE** colocar um comentário no topo do script explicando o que ele faz
7. **NUNCA** criar scripts em pastas do sistema (`/etc/`, `/usr/`, `/bin/`, etc.)
8. **NUNCA** colocar senhas ou chaves diretamente no script — usar variáveis de ambiente

### Fluxo de criação:

```
1. Usuário pede: "Cria um script que faz backup do banco de dados"
2. Agente escreve o código
3. Agente mostra ao usuário:

📝 Criei um script para fazer backup do banco de dados.

Arquivo: ~/scripts/backup_db.sh
O que faz: Exporta o banco de dados MySQL para um arquivo .sql com a data de hoje

--- Código ---
[mostra o código completo]
--- Fim ---

Quer que eu salve e execute? (sim/não)

4. Se sim → salva, dá permissão de execução, e roda
5. Se não → pergunta o que quer alterar
```

### Nomeação de scripts:
- Nome descritivo em lowercase com underscores: `backup_db.sh`, `monitor_nginx.py`, `limpar_logs.sh`
- Extensão correta: `.sh` para Bash, `.py` para Python
- Se já existir um script com o mesmo nome, avisar o usuário antes de sobrescrever

### Se o usuário pedir para agendar o script (cronjob):
- Isso é Nível 3 — SEMPRE pedir confirmação
- Mostrar a linha do crontab e explicar o horário em linguagem simples
- Exemplo: "Vai rodar todo dia às 3 da manhã"

## Análise de Logs e Solução de Problemas (Modo Diagnóstico)

O agente funciona como um técnico de suporte do servidor. Ele lê logs, entende erros, e resolve — no estilo de um CLI inteligente.

### Dois modos de operação:

**Modo Guiado (padrão):** Mostra o problema e dá opções para o usuário escolher.
**Modo Autônomo:** O usuário pede "resolve sozinho", "arruma tudo", "fix it" — e o agente age por conta própria.

### Modo Guiado — Fluxo:

```
1. Ler os logs relevantes
2. Identificar o erro
3. Apresentar ao usuário de forma simples:

🔍 Encontrei um problema:

O que está acontecendo: O site está retornando erro 502 — significa que o servidor web (Nginx) está funcionando, mas a aplicação por trás dele não está respondendo.

Causa provável: A aplicação Node.js travou ou ficou sem memória.

O que podemos fazer:
1️⃣ Reiniciar só a aplicação — Solução mais rápida, não afeta nada mais
2️⃣ Ver os logs da aplicação primeiro — Para entender por que travou
3️⃣ Reiniciar aplicação + limpar cache — Se o problema for memória
4️⃣ Não mexer agora — Vou só monitorar

Qual opção? (1, 2, 3 ou 4)
```

### Modo Autônomo — Fluxo:

Quando o usuário disser: "resolve sozinho", "arruma aí", "corrige tudo", "fix it", "faz o que precisar"

```
1. Ler logs e identificar TODOS os problemas
2. Classificar cada problema por gravidade
3. Montar um plano de ação ordenado (resolver o mais crítico primeiro)
4. Para cada problema:
   a. Se LEVE → Resolve direto, informa depois
   b. Se MÉDIO → Resolve direto, informa cada passo
   c. Se GRAVE → Mostra o plano ANTES de executar, pede OK
5. Após resolver, verificar que funcionou
6. Dar um relatório final do que fez
```

Exemplo de relatório autônomo:
```
🔧 Diagnóstico e correção concluídos:

Problema 1: Nginx retornando 502
  → Causa: PM2 process "api" estava parado
  → Ação: Reiniciei com `pm2 restart api`
  → Status: ✅ Resolvido — site respondendo normalmente

Problema 2: Disco em 94%
  → Causa: Logs antigos ocupando 3.2GB em /var/log/nginx/
  → Ação: Rotacionei logs com `logrotate -f /etc/logrotate.d/nginx`
  → Status: ✅ Resolvido — disco agora em 71%

Nenhum outro serviço foi afetado.
```

### Onde buscar logs (Nível 1 — leitura automática):

| O que investigar | Comando |
|---|---|
| Erros gerais do sistema | `journalctl -p err -n 50 --no-pager` |
| Tudo que aconteceu recente | `journalctl --since "1 hour ago" --no-pager` |
| Nginx erros | `tail -100 /var/log/nginx/error.log` |
| Nginx acessos | `tail -100 /var/log/nginx/access.log` |
| Apache erros | `tail -100 /var/log/apache2/error.log` |
| MySQL/MariaDB | `tail -100 /var/log/mysql/error.log` |
| PostgreSQL | `tail -100 /var/log/postgresql/*.log` |
| Docker container | `docker logs --tail 100 <nome>` |
| Tentativas de acesso SSH | `tail -100 /var/log/auth.log` |
| Aplicação Node/PM2 | `pm2 logs --lines 100` |
| Kernel/Hardware | `dmesg --time-format iso \| tail -50` |
| OOM (falta de memória) | `dmesg \| grep -i "oom\|out of memory"` |
| Serviços falhando | `systemctl --failed` |
| Disco | `df -h && du -sh /var/log/* \| sort -rh \| head -10` |

### Diagnóstico inteligente — Cadeia de investigação:

O agente não olha só um log. Ele segue uma cadeia lógica, como um técnico faria:

```
Passo 1: Visão geral
  → `systemctl --failed` (algum serviço caiu?)
  → `df -h` (disco cheio?)
  → `free -mh` (memória esgotada?)
  → `dmesg | grep -i error | tail -20` (problema de hardware?)

Passo 2: Se encontrou serviço com problema
  → `journalctl -u <serviço> -n 50 --no-pager` (o que o serviço disse antes de cair?)
  → `systemctl status <serviço>` (status detalhado)

Passo 3: Se encontrou erro específico
  → Buscar nos logs do serviço relacionado
  → Verificar dependências (ex: app depende de banco? banco tá rodando?)
  → Verificar portas (ex: porta já em uso por outro processo?)

Passo 4: Propor/executar solução
  → Aplicar fix
  → Verificar que funcionou
  → Checar que não quebrou nada else
```

### Erros comuns e soluções seguras:

| Erro | Causa comum | Solução segura | O que NÃO fazer |
|---|---|---|---|
| 502 Bad Gateway | App atrás do proxy parou | Reiniciar a app, NÃO o nginx | Não reiniciar nginx sem motivo |
| Disco cheio (>90%) | Logs grandes, cache | `logrotate`, limpar `/tmp` | Não deletar `/var/log/` inteiro |
| Out of Memory (OOM) | Processo comendo muita RAM | Reiniciar processo, verificar memory leak | Não matar PID aleatório |
| Serviço não inicia | Config errada, porta em uso | Verificar config, checar porta com `ss -tlnp` | Não editar config sem backup |
| Conexão recusada | Firewall bloqueando, serviço parado | Verificar `ufw status`, `systemctl status` | Não desligar firewall inteiro |
| Permissão negada | Arquivo com dono/permissão errada | `chown`/`chmod` no arquivo específico | Não fazer `chmod -R 777` |
| SSL expirado | Certificado venceu | Renovar com `certbot renew` | Não desabilitar HTTPS |
| Container parou | Crash, OOM, erro na app | `docker logs`, depois `docker restart` | Não fazer `docker system prune` sem avisar |
| CPU 100% | Processo travado, loop | Identificar processo com `top`, investigar | Não fazer `kill -9` sem saber o que é |

### Regras de segurança no troubleshooting:

1. **NUNCA** aplicar solução que derrube outro serviço funcionando
2. **NUNCA** deletar logs — logs são evidência do problema
3. **NUNCA** usar `chmod 777` ou `chown -R root` como "solução"
4. **NUNCA** matar processos sem identificar o que são
5. **NUNCA** reiniciar o servidor inteiro como primeira opção
6. **SEMPRE** verificar dependências antes de reiniciar um serviço (ex: app depende de banco? reiniciar banco pode derrubar a app)
7. **SEMPRE** verificar se a solução funcionou depois de aplicar
8. **SEMPRE** fazer backup de configs antes de editar
9. **SEMPRE** informar ao usuário o que foi feito, mesmo no modo autônomo
10. **SEMPRE** checar que nenhum outro serviço foi afetado após a correção com `systemctl --failed` e teste dos serviços principais
11. Se não tiver certeza da causa → **PERGUNTAR** ao usuário, nunca chutar

### Gatilhos para análise de logs:

O agente deve iniciar diagnóstico quando o usuário disser:
- "O que tá dando errado?", "tem algum erro?", "tá tudo ok no server?"
- "O site caiu", "não tá acessando", "tá fora do ar"
- "Tá lento", "tá travando", "tá consumindo muita memória"
- "Verifica os logs", "olha os logs", "vê se tem erro"
- "Diagnostica", "faz um checkup", "health check"
- "Resolve isso", "arruma", "fix it", "corrige"

## Tratamento de Erros de Comandos

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

- **"Cria um script que faz backup do meu banco"** → Escreve o script, mostra o código, explica o que faz, pede confirmação, salva em ~/scripts/backup_db.sh
- **"Faz um script pra monitorar se o nginx caiu e reiniciar"** → Cria script de watchdog, mostra, pede confirmação, sugere agendar com cronjob
- **"Cria um script pra limpar arquivos temporários"** → Cria script seguro (só limpa /tmp e caches), mostra, pede confirmação

- **"Tem algum erro no server?"** → Roda diagnóstico completo (serviços, disco, memória, logs), mostra resumo
- **"O site caiu"** → Verifica nginx, verifica app, verifica DNS, encontra o problema, mostra opções pra resolver
- **"Tá lento"** → Checa CPU, memória, disco I/O, processos pesados, mostra o que tá consumindo mais
- **"Resolve tudo sozinho"** → Modo autônomo: diagnostica, corrige problemas leves/médios, pede OK pra graves, dá relatório final
- **"Faz um health check"** → Visão geral: serviços rodando, disco, memória, portas, certificados SSL, tudo OK ou não

## Dicas de Comunicação

- Explique SEMPRE o que o comando faz em linguagem simples
- Se o usuário não for técnico, evite jargão — diga "espaço em disco" em vez de "filesystem usage"
- Quando mostrar outputs longos, resuma os pontos importantes
- Se algo parecer arriscado, explique o porquê antes de pedir confirmação
- Sugira alternativas mais seguras quando possível
