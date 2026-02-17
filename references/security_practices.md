# Práticas de Segurança para Administração de Servidores

## Regras Fundamentais

### Credenciais
- NUNCA exibir senhas/tokens diretamente no chat — sempre referenciar o credential_manager
- NUNCA armazenar credenciais em scripts ou arquivos de configuração versionados
- SEMPRE usar senhas fortes geradas automaticamente (min 24 caracteres)
- SEMPRE restringir permissões dos arquivos de credenciais (chmod 600)
- Trocar senhas padrão imediatamente após instalação de qualquer serviço

### Comandos Perigosos — SEMPRE confirmar antes
```
rm -rf (qualquer variação)
DROP DATABASE / DROP TABLE
mkfs (formatação de disco)
dd (escrita em disco)
> /dev/sda (ou qualquer device)
chmod -R 777
iptables -F (flush de todas as regras)
ufw disable
systemctl stop sshd
kill -9 1
```

### SSH
- Usar chaves SSH em vez de senhas quando possível
- Desabilitar login root via SSH: `PermitRootLogin no`
- Usar porta não-padrão (ex: 2222) se exposto à internet
- Configurar fail2ban para SSH

### Firewall (UFW)
- Default: deny incoming, allow outgoing
- Abrir APENAS as portas necessárias
- Sempre manter porta SSH aberta antes de ativar o firewall
- Verificar regras antes de ativar: `sudo ufw status`

### Banco de dados
- NUNCA expor PostgreSQL/MongoDB/Redis à internet sem autenticação
- Usar bind a 127.0.0.1 por padrão
- Se acesso remoto for necessário, usar SSH tunnel ou VPN
- Criar usuários específicos por aplicação (não usar root/admin para apps)

### Backups
- Antes de operações destrutivas, SEMPRE fazer backup
- Testar restore de backups periodicamente
- Manter backups em local diferente do servidor principal

### Updates
- Manter sistema atualizado: `sudo apt update && sudo apt upgrade`
- Habilitar atualizações automáticas de segurança:
  ```bash
  sudo apt install unattended-upgrades
  sudo dpkg-reconfigure --priority=low unattended-upgrades
  ```

## Antes de Qualquer Operação Crítica

1. Verificar se há backup recente
2. Confirmar com o usuário
3. Documentar no log o que será feito
4. Executar em etapas (não tudo de uma vez)
5. Verificar resultado de cada etapa
6. Se algo der errado, ter plano de rollback
