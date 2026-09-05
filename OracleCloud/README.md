# SQL Server na Oracle Cloud

Este roteiro prepara uma VM Oracle Cloud Free para hospedar o SQL Server usado pela API
no Render. Nenhuma senha ou chave deve ser colocada neste repositorio.

## Criar a VM

Use estas escolhas no Oracle Cloud:

- Imagem: Ubuntu 22.04 LTS.
- Shape: AMD x86 E2.1.Micro ou outro shape x86 elegivel ao Always Free.
- IP publico reservado: recomendado para nao mudar a connection string.
- Disco: pelo menos 50 GB.
- Chave SSH: gere uma nova e guarde a chave privada fora do repositorio.

Nao use uma VM Ampere ARM para o SQL Server. O SQL Server Linux deste projeto precisa de
uma VM x86/AMD.

## Rede Oracle

Na VCN, subnet e Network Security Group, permita:

- TCP 22 somente do seu IP para SSH.
- TCP 1433 somente do IP ou faixa de saida autorizada para a API.

O Render Free pode nao fornecer um IP de saida fixo. Nesse caso, o acesso TCP 1433 precisa
ser publico e deve depender de uma senha SQL forte, TLS e do firewall da VM. Se o Render
oferecer egress fixo no plano usado, restrinja a regra 1433 a essa faixa.

## Preparar o servidor

Conecte por SSH e execute:

```bash
chmod 700 bootstrap-sqlserver-ubuntu.sh
sudo ./bootstrap-sqlserver-ubuntu.sh --allow-cidr 0.0.0.0/0
```

O argumento `--allow-cidr` e obrigatorio para evitar a abertura acidental da porta 1433.
Prefira substituir `0.0.0.0/0` por uma faixa restrita quando possivel.

O script:

- instala SQL Server 2022 Developer;
- ativa o servico no boot;
- configura o firewall local para SSH e SQL Server;
- deixa o SQL Server pronto para receber o script idempotente do banco.

Copie o script e o arquivo SQL para a VM antes da execucao, por exemplo com `scp`. Depois
aplique `DatabaseScripts/InstallDatabase.sql` usando SSMS ou `sqlcmd` com o usuario `sa`.

## Configurar o Render

Depois de descobrir o IP publico da VM, configure `PADARIA_CONNECTION_STRING` como segredo
no Render:

```text
Server=IP_PUBLICO_DA_VM,1433;Database=infiniteCoffee;User Id=sa;Password=SENHA_SQL;Encrypt=True;TrustServerCertificate=True;Connect Timeout=30;
```

Nao use `localhost`, `Trusted_Connection=True` ou a senha no Git. Reinicie o servico do
Render depois de salvar a variavel.

O `render.yaml` ja declara `PADARIA_CONNECTION_STRING` como segredo.

## Validacao

1. No Render, confira `/api/health`.
2. Confira `GET /api/estoque`.
3. Registre uma entrada de estoque pelo app.
4. Confirme a movimentacao no SQL Server da VM.
5. Confirme o estoque pela API.

Nao exponha a porta 1433 antes de configurar senha forte, atualizacoes e as regras da VCN.
