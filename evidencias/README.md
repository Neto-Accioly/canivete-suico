# Evidências

- `execucoes/<id>/resumo.json`: ambiente mínimo, contagens, resultados por ID e hashes das fontes.
- `execucoes/<id>/pester.nunit.xml`: XML local de resultados, incluindo detalhes de falhas. Gerado sem consultas CIM/WMI.
- `execucoes/<id>/infraestrutura.txt`: falha do runner, quando disponível.
- `execucoes/historico-local.jsonl`: índice local das execuções que chegaram ao resumo.
- `resumos/`: cópias sanitizadas e revisadas que podem ser versionadas.

## Classificação

Tipos globais: `MOCKADO`, `REAL_CONTROLADO`, `MANUAL`, `NAO_EXECUTADO` (critérios em [QA](../docs/qa.md)). As execuções da suíte atual são `MOCKADO`: os 43 casos incluem mocks de operações externas, análise estática e leitura controlada de arquivos reais. Não validam instalação real. A técnica individual não altera o tipo global.

Novos JSON incluem `tipo_execucao: "MOCKADO"` e técnicas em `casos[].tecnicas`; novos XML incluem a propriedade NUnit de suite `tipo_execucao=MOCKADO`. Os campos `tipo`, contagens e estrutura anterior dos casos são preservados. Resultado, tipo e força da evidência são eixos diferentes.

Resumos revisados antigos recebem o rótulo retrospectivamente apenas na cópia derivada, com hashes dos originais e nota de proveniência. Nunca regravar XML/JSON antigos para acrescentar campos. Um cenário `NAO_EXECUTADO` não recebe aprovação; uma falha de infraestrutura não vira sucesso pelo tipo `MOCKADO`.

`execucoes/` e outros arquivos brutos são ignorados. Caminhos, erros de teste, relatórios XML, screenshots, inventário e transcrições podem conter dados pessoais. Não use `git add -f` para publicá-los. O `.gitignore` não remove segredos já rastreados nem substitui revisão humana.

Uma fixture não é evidência. Um resumo comprova o resultado observado para os hashes indicados, no ambiente indicado, com mocks; não comprova programas instalados. Mantenha a ligação no [histórico](../docs/historico-execucoes.md).
