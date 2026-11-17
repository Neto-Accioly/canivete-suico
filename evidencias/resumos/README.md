# Resumos revisados

Somente JSON sanitizado após revisão manual. O runner não publica nem copia resultados automaticamente para esta pasta.

Antes de copiar: remover caminhos absolutos, usuário, hostname, PATH, tokens e detalhes de erro sensíveis; manter data/ambiente mínimo, contagens, IDs dos casos e hashes. Não alterar os resultados reais. Para execuções falhas, preservar o estado falho e vincular a execução posterior que validou a correção.

Os resumos Pester são evidências dos testes isolados, sem instalação real. A ausência do XML bruto versionado é deliberada por privacidade; seu hash pode ser verificado contra o arquivo local original quando disponível. Registros externos de procedimentos reais devem indicar separadamente tipo, origem e grau de comprovação.

O campo global `tipo_execucao` dos resumos da suíte é `MOCKADO`; `casos[].tecnicas` separa mocks, estática e leitura controlada. Atribuições retrospectivas devem ser marcadas na proveniência, sem alterar resultados ou originais. Os outros tipos previstos são `REAL_CONTROLADO`, `MANUAL` e `NAO_EXECUTADO`.

`20261117-node-lts-winget-direto-relato.json` documenta exclusivamente o relato do usuário: `REAL_CONTROLADO`, grau `RELATADO`, sem log bruto e sem reprodução independente. Não é resultado Pester, não valida `-Aplicar` e não aumenta nem reclassifica os 43 testes automatizados.

`20261117-criar-projeto-aplicacao-relato.json` documenta aplicação parcial de `criar-projeto.ps1 -Aplicar` informada pelo usuário. Tipo `REAL_CONTROLADO`, grau `RELATADO`; seis presenças Test-Path relatadas, sem código de saída numérico, logs ou hashes anteriores. A substituição do manifesto foi recusada e npm não foi executado; não inferir que houve pergunta ou recusa explícita de npm. Manter os testes mockados separados.
