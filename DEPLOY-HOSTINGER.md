# Deploy automático da API na Hostinger

O workflow `Validate` executa análise, testes e smoke tests. O job `deploy-hostinger`, no mesmo workflow, só publica a API quando:

- o evento é um `push` para `master` (normalmente após o merge aprovado de um pull request);
- o job `validate` terminou com sucesso; e
- a variável de repositório `HOSTINGER_DEPLOY_ENABLED` está definida como `true`.

O deploy publica somente o backend ASP.NET Core. Não altera o APK/Windows, não executa alterações de schema e não copia o arquivo de configuração `app.env`.

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

1. O workflow publica `InfiniteCoffee2.csproj` para `linux-x64`, usando o runtime .NET 10 já instalado na VM.
2. Envia um pacote temporário via SCP usando a chave armazenada em GitHub Secrets.
3. Confirma que `/opt/padaria-api/app.env` existe e que o pacote não contém outro `app.env`.
4. Monta uma versão candidata em `/opt`, copiando o `app.env` existente sem enviá-lo ao GitHub.
5. Para `padaria-api`, move a versão atual para `/opt/padaria-api-backups/` e coloca a candidata em `/opt/padaria-api`.
6. Reinicia o serviço e consulta `http://127.0.0.1:8080/api/health`. Se a verificação falhar, move a versão com falha para um diretório separado e restaura a anterior; o job termina como falha para sinalizar a necessidade de inspeção.

As versões anteriores ficam na VM em `/opt/padaria-api-backups/`, incluindo seu `app.env`, com permissões restritas; elas não são enviadas como artefatos do GitHub Actions. Depois de confirmar várias publicações estáveis, o responsável pela VM pode remover versões antigas conforme a política de retenção da equipe.

## O que não é publicado automaticamente

- **Aplicativo Flutter:** APK e Windows são entregues separadamente. Publicar a API não atualiza aplicativos já instalados. O build do cliente precisa apontar para a URL da Hostinger; confira `Installer/Build-Apps.ps1`, cujo valor padrão ainda pode ser diferente.
- **Banco de dados:** mudanças em tabelas ou procedures precisam de um script versionado, backup e aplicação controlada na VM. O workflow não executa migrations nem o script completo de instalação.
- **Deploy a partir de `kaio` ou `CdmEdu`:** o job não publica diretamente dessas branches. A publicação é após validação de um push em `master`, de acordo com o fluxo de integração do repositório.

## Primeiro teste

1. Adicione os secrets e a variável no GitHub, mantendo `HOSTINGER_DEPLOY_ENABLED` diferente de `true` enquanto valida os dados.
2. Confirme o acesso SSH e as permissões do usuário de deploy.
3. Habilite a variável como `true`.
4. Após um merge aprovado em `master`, acompanhe **Actions → Validate → Deploy API to Hostinger KVM**.
5. Confira o status do workflow e, se houver falha, consulte os logs do job e `journalctl -u padaria-api` na VM.
