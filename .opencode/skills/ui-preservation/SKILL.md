---
name: ui-preservation
description: Use when adding functionality to existing web screens without changing their established HTML, CSS, routes, or visual design.
---

# Preservacao de Telas

1. A branch `CdmEdu` é a fonte oficial para criar ou alterar Views Razor, HTML, CSS e componentes visuais do site.
2. Em outras branches, não edite esses arquivos; implemente regras no controller/backend ou encaminhe a mudança visual para integração pela `CdmEdu`.
3. Não remova telas ou rotas e preserve nomes de campos, links e contratos existentes.
4. Não mova arquivos existentes.
5. Ao adicionar comportamento, mantenha as ações já existentes e valide acessibilidade/responsividade na branch autorizada.
6. Confirme o impacto em rotas, verbos HTTP e contratos antes de integrar uma mudança visual.
