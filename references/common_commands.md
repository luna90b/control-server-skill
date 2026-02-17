# Control Server v1.0 — Referência de Comandos Comuns
> Criado por BollaNetwork — https://github.com/luna90b/control-server-skill

## Monitoramento (Nível 1 — Leitura)

| O que pedir | Comando | O que faz |
|---|---|---|
| Espaço em disco | `df -h` | Uso de disco |
| Memória RAM | `free -mh` | Uso de memória |
| Processos pesados | `ps aux --sort=-%mem \| head -20` | Top 20 por memória |
| CPU | `top -bn1 \| head -20` | Uso de CPU |
| Uptime | `uptime` | Tempo ligado |
| Portas abertas | `ss -tlnp` | Serviços escutando |
| Status serviço | `systemctl status <nome>` | Estado de um serviço |
| Logs do sistema | `journalctl -n 50 --no-pager` | Últimos logs |
| PM2 processos | `pm2 list` | Apps rodando |
| Docker containers | `docker ps` | Containers ativos |

## Instalação (Nível 2)

| Serviço | Script | Exemplo |
|---|---|---|
| PostgreSQL + DB | `service_install.sh postgresql meu_db meu_user` | Instala + cria banco + salva senha no vault |
| MySQL + DB | `service_install.sh mysql meu_db meu_user` | Idem |
| Redis | `service_install.sh redis` | Instala com senha automática |
| Node.js | `service_install.sh node 20` | Via nvm |
| PM2 | `service_install.sh pm2` | Gerenciador de processos |
| Nginx | `service_install.sh nginx` | Servidor web |
| Docker | `service_install.sh docker` | Containers |
| SSL/Certbot | `service_install.sh certbot` | Certificados HTTPS |

## Firewall (Nível 2-3)

| O que pedir | Comando via safe_ufw | Nível |
|---|---|---|
| Ver regras | `safe_exec.sh "ufw status verbose"` | 1 |
| Abrir porta | `safe_exec.sh "ufw allow 3000/tcp comment 'App'"` | 2 |
| Fechar porta | `safe_exec.sh "ufw deny 8080"` | 2 |
| Auditoria | `port_audit.sh` | 1 |
| Health check | `guardian.sh scan` | 1 |
| Auto-corrigir | `guardian.sh protect` | — |

## Credenciais

| O que pedir | Comando | Exemplo |
|---|---|---|
| Salvar | `vault.sh save pg_meudb password "abc123"` | Salva no vault |
| Buscar | `vault.sh get pg_meudb password` | Retorna valor |
| Listar | `vault.sh list` | Todos os serviços |
| Gerar senha | `vault.sh generate 32` | Senha aleatória |
| Exportar .env | `vault.sh export pg_meudb env` | Para colar em .env |

## Logs

| O que pedir | Comando |
|---|---|
| Ver comandos executados | `log_manager.sh show commands` |
| Ver erros | `log_manager.sh show errors` |
| Buscar algo | `log_manager.sh search "nginx"` |
| Resumo do dia | `log_manager.sh summary today` |
| Resumo da semana | `log_manager.sh summary week` |
| Rotacionar | `log_manager.sh rotate` |
