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

Skill unificada de controle total do servidor. O agente usa esta skill como ponte para executar QUALQUER tarefa que precise rodar na máquina — desde verificar disco até deploy completo com domínio e SSL.

**Esta skill é o "braço" do agente no servidor.** Quando qualquer outra tarefa do OpenClaw precisar executar um comando na máquina, esta skill é acionada para fazer isso de forma segura.

## Conceitos Fundamentais

### "Seu servidor" = Esta Máquina
Expressões que significam este servidor: "seu servidor", "seu server", "sua máquina", "sua VPS", "no server", "na máquina", "aí no server", ou simplesmente pedir para executar/instalar algo.

### Skill como Ponte
O agente usa esta skill internamente quando precisa rodar comandos para completar outras tarefas (configurar banco, verificar site, atualizar projeto, etc.)

## Sistema de Logs — Tudo é Registrado

Localização: `{baseDir}/logs/`
- `commands.log` — Todo comando executado: timestamp, comando, exit code
- `installs.log` — Todo pacote/serviço instalado
- `firewall.log` — Toda alteração de UFW
- `errors.log` — Todo erro e como foi resolvido
- `credentials.log` — Todo acesso a credenciais (sem mostrar senha)

Regras: SEMPRE logar antes e depois. NUNCA logar senhas. Rotacionar a cada 30 dias.

## Credenciais Seguras (Vault)

Localização: `{baseDir}/data/vault.json` (chmod 600)
Gerenciado por: `{baseDir}/scripts/vault.sh`

Regras:
1. NUNCA mostrar senhas em texto claro na conversa — usar **** ou referência
2. SEMPRE chmod 600 no vault.json
3. Buscar no vault PRIMEIRO quando precisar de credencial
4. Senhas geradas: mínimo 24 chars, alfanumérico + especiais

## Guardian — Sistema Anti-Lockout (Firewall)

O Guardian usa 3 fontes para NUNCA bloquear SSH ou OpenClaw:
1. **CONFIG**: Lê sshd_config e openclaw.json (SÓ LEITURA)
2. **PROCESSOS**: Escaneia processos reais de sshd e openclaw rodando AGORA
3. **PORTAS**: Verifica quais portas esses processos usam em tempo real

Pipeline de segurança — todo comando UFW passa por:
```
1. SIMULATE → Testa com scan real de processos — vai afetar SSH? OpenClaw?
2. SNAPSHOT → Salva estado atual
3. EXECUTE  → Roda comando
4. VALIDATE → Verifica SSH + OpenClaw intactos
   → Se quebrou → AUTO-FIX instantâneo
```

### Proteção SSH (acesso remoto):
- Detecta porta SSH de 3 formas: config + processo sshd + default 22
- Conta sessões SSH ativas ANTES de cada alteração
- Se qualquer comando tentar fechar porta SSH → BLOQUEADO com mensagem mostrando quantas sessões estão ativas
- Se SSH sumir após execução → restaura IMEDIATAMENTE

### Relação com OpenClaw — SÓ LEITURA:
- ✅ Ler ~/.openclaw/openclaw.json para detectar porta/bind
- ❌ NUNCA alterar qualquer arquivo em ~/.openclaw/
- ❌ NUNCA mexer no systemd do OpenClaw
- ❌ NUNCA matar processos do OpenClaw

## Níveis de Confiança

### Nível 1 — Leitura (auto após 3 aprovações)
ls, cat, head, tail, grep, find, df, free, uptime, systemctl status, docker ps, docker logs, ss, pm2 list, pm2 logs, nginx -t

### Nível 2 — Instalação leve (auto após 10 aprovações)
apt install, apt update, pip install, npm install, mkdir, cp, mv, chmod, chown (projeto), systemctl restart, docker restart, pm2 restart

### Nível 3 — Sistema (SEMPRE confirmação)
apt upgrade, systemctl enable/disable, editar /etc/, criar usuários, firewall, cronjobs, instalar serviços

### Nível 4 — Alto risco (SEMPRE confirmação + impacto)
systemctl stop crítico, reboot, rm em projetos, docker system prune

### Nível 5 — PROIBIDO
rm -rf / e variantes, mkfs, dd em dispositivos, fork bomb, chmod -R 777 /, fechar SSH, desabilitar acesso remoto

## Instalação de Serviços

Script: `{baseDir}/scripts/service_install.sh`
Serviços: postgresql, mysql, redis, nginx, certbot, node, pm2, docker

Regras: SEMPRE Nível 3 (confirmação). SEMPRE salvar credenciais no vault. SEMPRE logar. Para bancos: gerar senha forte, NUNCA abrir porta pro mundo.

## Análise de Logs e Troubleshooting

Modo Guiado: Mostra problema, explica, dá opções numeradas.
Modo Autônomo ("resolve sozinho"): Corrige leves/médios direto, mostra plano para graves.

Regras: NUNCA deletar logs. NUNCA kill -9 sem saber o que é. SEMPRE verificar dependências antes de reiniciar.

## Criação de Scripts

Salvar em ~/scripts/. Mostrar código antes. Pedir confirmação. chmod +x. NUNCA senhas hardcoded.

## Segurança — Diretórios Protegidos

NUNCA deletar: /bin /boot /dev /etc /lib /lib64 /proc /root /sbin /sys /usr /var /opt /snap
NUNCA alterar: ~/.openclaw/ (SÓ LEITURA)

## Exemplos

- "Quanto de disco?" → df -h
- "Instala PostgreSQL" → Instala, configura, gera senha, salva vault
- "Protege meu servidor" → Guardian scan → setup UFW
- "O site caiu" → Diagnóstico → opções ou fix
- "O que foi feito ontem?" → Consulta logs → resumo

## Referências
- Comandos comuns: `{baseDir}/references/common_commands.md`
- Atualizar: `cd {baseDir} && git pull` ou https://github.com/luna90b/control-server-skill
