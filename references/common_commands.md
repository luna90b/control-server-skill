# Control Server v1.0 — Referência Rápida
> Criado por BollaNetwork — https://github.com/luna90b/control-server-skill

## Monitoramento (Nível 1)
| Pedir | Comando |
|---|---|
| Disco | `df -h` |
| RAM | `free -mh` |
| CPU | `top -bn1 \| head -20` |
| Portas | `ss -tlnp` |
| Status serviço | `systemctl status <nome>` |
| PM2 | `pm2 list` |
| Docker | `docker ps` |

## Instalar Serviços
| Serviço | Comando |
|---|---|
| PostgreSQL + DB | `service_install.sh postgresql meu_db meu_user` |
| MySQL + DB | `service_install.sh mysql meu_db meu_user` |
| Redis | `service_install.sh redis` |
| Node.js | `service_install.sh node 20` |
| PM2 | `service_install.sh pm2` |
| Nginx | `service_install.sh nginx` |
| Docker | `service_install.sh docker` |
| Certbot | `service_install.sh certbot` |

## Firewall
| Ação | Comando |
|---|---|
| Status | `safe_exec.sh "ufw status verbose"` |
| Abrir porta | `safe_exec.sh "ufw allow 3000/tcp comment 'App'"` |
| Auditoria | `port_audit.sh` |
| Scan segurança | `guardian.sh scan` |
| Auto-corrigir | `guardian.sh protect` |

## Credenciais
| Ação | Comando |
|---|---|
| Salvar | `vault.sh save serviço chave valor` |
| Buscar | `vault.sh get serviço chave` |
| Listar | `vault.sh list` |
| Gerar senha | `vault.sh generate 32` |
| Exportar .env | `vault.sh export serviço env` |

## Logs
| Ação | Comando |
|---|---|
| Ver comandos | `log_manager.sh show commands` |
| Ver erros | `log_manager.sh show errors` |
| Buscar | `log_manager.sh search "nginx"` |
| Resumo dia | `log_manager.sh summary today` |
