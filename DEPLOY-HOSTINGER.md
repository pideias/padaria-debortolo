# Deploy automático da API na Hostinger

O workflow `Validate` executa análise, testes e smoke tests. O job `deploy-hostinger`, no mesmo workflow, só publica a API quando:

- o evento é um `push` para `master` ou uma execução manual (**Run workflow**) selecionando `master`;
- o job `validate` terminou com sucesso; e
- a variável de repositório `HOSTINGER_DEPLOY_ENABLED` está definida como `true`.

O deploy publica o backend ASP.NET Core e as Views/CSS do site. Não altera APK/Windows, não executa alterações de schema e não copia `app.env`.

## Migração inicial para blue-green

A VM inicialmente servia Kestrel diretamente em `0.0.0.0:8080`, sem proxy. Execute esta migração uma única vez; ela cria Nginx na porta pública `8080` e slots ASP.NET locais em `127.0.0.1:8081` (blue) e `127.0.0.1:8082` (green).

Antes da troca, compile e prepare a publicação Linux x64. Envie a publicação extraída para `/tmp/infinitecoffee-api-stage/` e copie o script de bootstrap:

```powershell
scp .\Installer\Setup-BlueGreen-Hostinger.sh root@srv1956950.hstgr.cloud:/tmp/
```

Na VM, rode durante uma janela sem atendimentos abertos. A API atual mantém os identificadores do atendimento em memória; a migração inicial reinicia esse processo uma vez. O script pede confirmação antes do corte:

```bash
bash /tmp/Setup-BlueGreen-Hostinger.sh /tmp/infinitecoffee-api-stage
```

O script valida o runtime, `app.env`, ambos os slots e o Nginx antes da troca. Ele faz a troca inicial com breve interrupção e restaura o serviço legado se o health-check falhar. O arquivo `/opt/padaria-api/app.env` é preservado e compartilhado pelos slots. Só depois de o marcador `/etc/padaria-api/bluegreen-ready` existir deve-se mesclar/publicar o workflow blue-green.

Os slots são mantidos para preservar sessões MVC em memória. O cookie `padaria_slot` mantém cada navegador no slot onde iniciou o atendimento; o deploy recusa reutilizar um slot que recebeu tráfego nos últimos 30 minutos (`Session.IdleTimeout`). As portas `8081` e `8082` ficam restritas a loopback; não abra essas portas no firewall.

## Addam local (serviço Python separado)

O endpoint `POST /api/addam/chat` encaminha mensagens para um serviço Python local em
`http://127.0.0.1:8091`. A API devolve `503` se esse serviço não estiver instalado ou ativo. O
workflow atual não instala nem atualiza esse sidecar; faça isso separadamente na VM:

1. Na VM, instale Ollama e baixe o modelo local Qwen2.5 0.5B (Q4_K_M, cerca de 398 MB):

   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   systemctl enable --now ollama
   ollama pull qwen2.5:0.5b
   ```

2. Pelo PowerShell, copie `AddamPython/addam_service.py` e `AddamPython/padaria-addam.service` para `/tmp/` na VM via SCP.
3. Na VM, crie o usuário de serviço e instale os arquivos:

   ```bash
   id -u padaria-addam >/dev/null 2>&1 || useradd --system --user-group --home-dir /nonexistent --shell /usr/sbin/nologin padaria-addam
   install -d -o padaria-addam -g padaria-addam -m 750 /opt/padaria-addam
   install -o padaria-addam -g padaria-addam -m 640 /tmp/addam_service.py /opt/padaria-addam/addam_service.py
   install -o root -g root -m 644 /tmp/padaria-addam.service /etc/systemd/system/padaria-addam.service
   systemctl daemon-reload
   systemctl enable --now padaria-addam
   curl -fsS http://127.0.0.1:8091/health
   ```

4. Confirme `{"status":"ok","assistant":"Addam","model":"qwen2.5:0.5b"}` e então publique/reinicie a API ASP.NET.

O serviço Python usa apenas a biblioteca padrão, chama Ollama em loopback e não deve ter as portas
`8091` nem `11434` abertas no firewall. O Qwen local propõe ações estruturadas; o APK mostra uma prévia
e, após confirmação, chama os endpoints REST existentes. O modelo não acessa SQL nem executa comandos.
O API demo continua público/HTTP: use somente dados de teste, pois a confirmação no APK não é autenticação.

## Configuração no GitHub

Em **Settings → Secrets and variables → Actions**, configure a variável e os secrets:

| Nome | Tipo | Valor |
|---|---|---|
| `HOSTINGER_DEPLOY_ENABLED` | Variable | `true` para habilitar o deploy; ausente ou outro valor mantém o job ignorado. |
| `HOSTINGER_HOST` | Secret | IP ou hostname SSH atual da VM. |
| `HOSTINGER_USER` | Secret | Usuário SSH de deploy. |
| `HOSTINGER_SSH_PORT` | Secret | Porta SSH; se não definida, o workflow usa `22`. |
| `HOSTINGER_SSH_PRIVATE_KEY` | Secret | Chave privada dedicada ao deploy, em formato OpenSSH. |
| `HOSTINGER_KNOWN_HOSTS` | Secret | Linha de chave pública do host, conferida com a impressão digital confiável da VM. |

Não coloque chave privada, senha SQL, connection string ou conteúdo de `app.env` no repositório. Recomenda-se usar uma chave SSH de deploy e uma conta que tenha somente as permissões necessárias: gravar em `/opt/padaria-api` e `/opt/padaria-api-backups` e reiniciar/consultar `padaria-api` sem prompt interativo (`sudo -n`, se não for root).

Antes de habilitar o workflow, configure a chave pública correspondente em `authorized_keys` da VM e confirme a chave do host fora do workflow. A entrada de `HOSTINGER_KNOWN_HOSTS` deve corresponder ao host e à porta configurados; não use uma chave obtida sem verificar sua impressão digital.

## O que ocorre em cada publicação

1. O workflow publica `InfiniteCoffee2.csproj` para `linux-x64`, usando o runtime .NET 10 instalado na VM.
2. Envia o pacote de publicação via SCP usando a chave armazenada nos GitHub Secrets.
3. Confirma que `/opt/padaria-api/app.env` existe e que o pacote não contém outro `app.env`.
4. Atualiza o slot inativo, inicia-o em loopback e valida `http://127.0.0.1:8081` ou `:8082`.
5. Troca o upstream do Nginx por reload gracioso e consulta `http://127.0.0.1:8080/api/health`; a instância que atende não é reiniciada.
6. Se o health-check falhar, restaura o upstream anterior. A versão anterior fica no outro slot para atender sessões MVC existentes.

As versões de slots anteriores ficam na VM em `/opt/padaria-api-backups/slots/`. O único `app.env` permanece em `/opt/padaria-api/app.env` e não é incluído nos pacotes. Depois de confirmar várias publicações estáveis, o responsável pela VM pode remover backups antigos conforme a política de retenção da equipe.

## O que não é publicado automaticamente

- **Aplicativo Flutter:** APK e Windows são entregues separadamente. Publicar a API não atualiza aplicativos já instalados. O build do cliente precisa apontar para a URL da Hostinger; confira `Installer/Build-Apps.ps1`, cujo valor padrão ainda pode ser diferente.
- **Banco de dados:** mudanças em tabelas ou procedures precisam de um script versionado, backup e aplicação controlada na VM. O workflow não executa migrations nem o script completo de instalação.
- **Deploy a partir de `kaio` ou `CdmEdu`:** o job não publica diretamente dessas branches. Integre a `CdmEdu` à `master` por PR aprovado; então o push em `master` ou um `Run workflow` em `master` pode publicar após validação.

## Primeiro teste

1. Adicione os secrets e a variável no GitHub, mantendo `HOSTINGER_DEPLOY_ENABLED` diferente de `true` enquanto valida os dados.
2. Confirme o acesso SSH e as permissões do usuário de deploy.
3. Execute uma vez o bootstrap `Installer/Setup-BlueGreen-Hostinger.sh` na VM, com o site em janela sem atendimentos abertos.
4. Habilite `HOSTINGER_DEPLOY_ENABLED=true`.
5. Após um merge aprovado em `master`, acompanhe **Actions → Validate → Deploy API blue-green to Hostinger KVM**. Também é possível usar **Actions → Validate → Run workflow** selecionando `master`.
6. Confira `/api/health` e, se houver falha, consulte os logs do workflow, `journalctl -u padaria-api-blue`/`padaria-api-green` e Nginx na VM.
