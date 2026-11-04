# Backlog — Instalador Gratuito do Infinite Coffee

> Objetivo: permitir que uma instalação limpa do Windows coloque o sistema para funcionar
> com o mínimo de configuração, sem depender de licença paga. O SQL Server continua sendo
> a fonte oficial local e o Flutter mantém o banco Hive embutido para uso offline.

## Arquitetura alvo

```text
Instalador Windows
  ├─ Backend ASP.NET Core self-contained
  ├─ Flutter Desktop
  ├─ Script de inicialização web + API
  └─ Banco SQL Server Express local (pré-requisito/instalação assistida)

Flutter Mobile ──API HTTPS/VPN──> Backend ──> SQL Server local
      └── Hive embutido para cache, fila offline e sincronização
```

## Fases

### Fase 1 — Publicação e instalador base

- [x] Criar backlog versionado do instalador.
- [x] Criar script de publicação do backend self-contained e Flutter Windows.
- [x] Criar launcher que inicia a API e abre o navegador.
- [x] Criar configuração do Inno Setup com atalhos e desinstalação.
- [ ] Gerar e testar o primeiro `InfiniteCoffee-Setup.exe` em uma máquina limpa.

### Fase 2 — Banco local sem dor de cabeça

- [ ] Detectar automaticamente SQL Server Express/LocalDB instalado.
- [ ] Oferecer instalação silenciosa do SQL Server Express quando autorizado.
- [ ] Criar o banco somente se ele não existir.
- [ ] Executar scripts SQL idempotentes em ordem, sem apagar dados existentes.
- [ ] Criar tela/assistente para configurar servidor e testar conexão.
- [ ] Remover a connection string fixa do código e ler configuração protegida.

### Fase 3 — Inicialização e operação no Windows

- [ ] Instalar o backend como serviço do Windows ou inicialização automática opcional.
- [ ] Garantir encerramento limpo e evitar múltiplas instâncias da API.
- [ ] Adicionar página de diagnóstico: API, banco, porta e sincronização.
- [ ] Criar logs locais rotacionados sem armazenar senhas ou tokens.

### Fase 4 — Backup gratuito e recuperação

- [ ] Criar backup SQL Server agendado em pasta local configurável.
- [ ] Permitir cópia do backup para uma pasta sincronizada pelo usuário.
- [ ] Adicionar restauração assistida com confirmação explícita.
- [ ] Documentar opções gratuitas de armazenamento, como OneDrive/Google Drive.
- [ ] Testar restauração em uma instalação limpa.

### Fase 5 — API para o mobile

- [ ] Definir URL por ambiente com `API_BASE_URL`.
- [ ] Publicar API de forma segura para acesso externo via VPN ou servidor cloud.
- [ ] Não expor SQL Server diretamente à internet.
- [ ] Adicionar autenticação, autorização e HTTPS antes de uso externo.
- [ ] Validar CORS apenas para origens necessárias.

### Fase 6 — Offline e sincronização

- [ ] Finalizar Hive embutido e seed inicial.
- [ ] Implementar fila offline idempotente com `client_uuid`.
- [ ] Sincronizar vendas, estoque e catálogo pela API.
- [ ] Resolver conflitos por regra documentada e preservar histórico.
- [ ] Validar celular offline → servidor → desktop.

### Fase 7 — Distribuição

- [ ] Gerar APK assinado para Android.
- [ ] Gerar instalador Windows reproduzível em CI.
- [ ] Criar checklist de instalação, atualização e backup.
- [ ] Testar atualização sem perder banco nem configurações.

## Ferramentas gratuitas

- Inno Setup para o instalador Windows.
- .NET self-contained para não exigir o runtime manualmente.
- SQL Server Express ou LocalDB, conforme o volume e os recursos necessários.
- Flutter para os aplicativos Windows e Android.

## Critérios de segurança

- Nunca expor a porta do SQL Server diretamente na internet.
- Nunca sobrescrever banco existente sem confirmação e backup.
- Não incluir credenciais no instalador ou no repositório.
- Toda operação de restauração deve pedir confirmação explícita.
