# Evidências

- `execucoes/<id>/resumo.json`: ambiente mínimo, contagens, resultados por ID e hashes das fontes.
- `execucoes/<id>/pester.nunit.xml`: XML local de resultados, incluindo detalhes de falhas. Gerado sem consultas CIM/WMI.
- `execucoes/<id>/infraestrutura.txt`: falha do runner, quando disponível.
- `execucoes/historico-local.jsonl`: índice local das execuções que chegaram ao resumo.
- `resumos/`: cópias sanitizadas e revisadas que podem ser versionadas.

## Classificação

Tipos globais: `MOCKADO`, `REAL_CONTROLADO`, `MANUAL`, `NAO_EXECUTADO` (critérios em [QA](../docs/qa.md)). As execuções da suíte atual são `MOCKADO`: os 43 casos incluem mocks de operações externas, análise estática e leitura controlada de arquivos reais. Não validam instalação real. A técnica individual não altera o tipo global.

A extensão criar-projeto acrescenta 20 casos PRJ (total 63), também `MOCKADO`. A [observação de simulação no projeto existente](resumos/20261117-playwright-simulacao-existente.json) é `REAL_CONTROLADO` restrito a leitura/simulação; não foi aplicação, instalação ou execução de navegadores. Sua transcrição bruta continua local em `execucoes/`.

A correção de Destino final acrescenta quatro regressões, passando a **67 casos**. O [resultado MOCKADO 67/67](resumos/20261117-172726440-979f713b.json) e a [nova observação somente leitura](resumos/20261117-playwright-destino-final-simulacao.json) são registros separados; a segunda comprova o plano sem duplicação, não a execução de escrita/npm.

Novos JSON incluem `tipo_execucao: "MOCKADO"` e técnicas em `casos[].tecnicas`; novos XML incluem a propriedade NUnit de suite `tipo_execucao=MOCKADO`. Os campos `tipo`, contagens e estrutura anterior dos casos são preservados. Resultado, tipo e força da evidência são eixos diferentes.

Resumos revisados antigos recebem o rótulo retrospectivamente apenas na cópia derivada, com hashes dos originais e nota de proveniência. Nunca regravar XML/JSON antigos para acrescentar campos. Um cenário `NAO_EXECUTADO` não recebe aprovação; uma falha de infraestrutura não vira sucesso pelo tipo `MOCKADO`.

`execucoes/` e outros arquivos brutos são ignorados. Caminhos, erros de teste, relatórios XML, screenshots, inventário e transcrições podem conter dados pessoais. Não use `git add -f` para publicá-los. O `.gitignore` não remove segredos já rastreados nem substitui revisão humana.

Uma fixture não é evidência. Um resumo comprova o resultado observado para os hashes indicados, no ambiente indicado, com mocks; não comprova programas instalados. Mantenha a ligação no [histórico](../docs/historico-execucoes.md).

O [registro de Node via WinGet direto](resumos/20261117-node-lts-winget-direto-relato.json) é uma exceção documental aos resumos Pester: tipo `REAL_CONTROLADO`, grau `RELATADO`, fonte mensagem do usuário. Não possui XML/log anexado, commit ou código de saída comprovados; não inventar esses dados. Não valida `-Aplicar` e não altera os 43 casos `MOCKADO`. O caminho genérico do sistema foi normalizado no JSON; o histórico preserva o caminho informado, sem nome de usuário.

O [registro de aplicação parcial de criar-projeto](resumos/20261117-criar-projeto-aplicacao-relato.json) também é `REAL_CONTROLADO` / `RELATADO`: confirmação de estrutura, recusa do manifesto, npm não executado e seis presenças informadas por Test-Path. Não há logs, exit code ou hashes anteriores fornecidos. Não é relatório Pester, não comprova conteúdo/criação independentemente e não modifica evidências `MOCKADO` anteriores.
