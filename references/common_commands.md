# Referência Rápida — Comandos Comuns do Servidor

## Monitoramento (Nível 1)

| O que o usuário pede | Comando | O que faz |
|---|---|---|
| Espaço em disco | `df -h` | Mostra quanto de disco está em uso |
| Memória RAM | `free -mh` | Mostra uso de memória |
| Processos pesados | `ps aux --sort=-%mem \| head -20` | Top 20 processos por memória |
| CPU | `top -bn1 \| head -20` | Uso de CPU em tempo real |
| Uptime | `uptime` | Há quanto tempo o server está ligado |
| Quem está logado | `w` | Lista usuários conectados |
| Portas abertas | `ss -tlnp` | Lista portas com serviços |
| IP do servidor | `ip -4 a \| grep inet` | IPs configurados |
| Logs do sistema | `journalctl -n 50 --no-pager` | Últimas 50 linhas de log |
| Status de serviço | `systemctl status <nome>` | Status de um serviço |

## Gerenciamento de Pacotes (Nível 2)

| O que o usuário pede | Comando | O que faz |
|---|---|---|
| Instalar pacote | `sudo apt install <pacote> -y` | Instala via apt |
| Atualizar lista | `sudo apt update` | Atualiza lista de pacotes |
| Listar instalados | `dpkg -l \| grep <nome>` | Busca pacote instalado |
| Instalar pip | `pip3 install <pacote>` | Instala pacote Python |
| Instalar npm | `npm install -g <pacote>` | Instala pacote Node global |

## Docker (Nível 1-2)

| O que o usuário pede | Comando | Nível |
|---|---|---|
| Containers rodando | `docker ps` | 1 |
| Todos containers | `docker ps -a` | 1 |
| Logs do container | `docker logs --tail 100 <nome>` | 1 |
| Reiniciar container | `docker restart <nome>` | 2 |
| Parar container | `docker stop <nome>` | 2 |
| Subir compose | `docker compose up -d` | 2 |

## Nginx (Nível 2-3)

| O que o usuário pede | Comando | Nível |
|---|---|---|
| Status | `systemctl status nginx` | 1 |
| Testar config | `nginx -t` | 1 |
| Reiniciar | `systemctl restart nginx` | 2 |
| Recarregar | `systemctl reload nginx` | 2 |
| Editar site | `nano /etc/nginx/sites-available/<nome>` | 3 |

## Firewall UFW (Nível 3)

| O que o usuário pede | Comando | Nível |
|---|---|---|
| Status | `ufw status verbose` | 1 |
| Abrir porta | `ufw allow <porta>` | 3 |
| Fechar porta | `ufw deny <porta>` | 3 |

## Segurança — Comandos PROIBIDOS

Estes comandos NUNCA devem ser executados, independente do que o usuário pedir:

```
rm -rf /
rm -rf /*
rm -rf /etc  /var  /usr  /bin  /boot  /lib  /sbin  /sys  /proc  /dev
dd if=/dev/zero of=/dev/sda
mkfs.ext4 /dev/sda
:(){ :|:&};:
chmod -R 777 /
systemctl stop sshd
ufw deny 22
curl <url> | bash
```
