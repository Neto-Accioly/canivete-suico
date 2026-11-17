# Preparação para versionamento de QA

Revisão documental de 2026-11-17. Nenhum commit, push, instalação ou alteração de produção foi executado nesta preparação. Os arquivos seguros abaixo foram revisados como candidatos; não foram adicionados ao índice.

## Evidência conferida

Execução `20261117-155843943-58008942`, iniciada às **15:58:43.943 −03:00**. XML e JSON indicam os mesmos **43 testes isolados aprovados**, sem falhas, pendências ou ignorados. PowerShell 5.1.26100.9818, Pester 3.4.0, processo 64 bits, Windows runtime 10.0.26300.0.

As interações externas do instalador foram substituídas por mocks/barreiras; o diagnóstico lê fixtures. Isso não comprova instalação real, versão real de programas, confirmação física ou UI/EULA/UAC.

O hash do XML confere com o resumo. Os sete hashes de fontes conferem com os arquivos atuais, portanto não houve necessidade de executar novamente `scripts/testar.ps1`. O [resumo derivado](../evidencias/resumos/20261117-155843943-58008942.json) preserva os resultados e acrescenta proveniência e hashes dos dois originais; o XML e o JSON originais continuam inalterados em `evidencias/execucoes/`, ignorados pelo Git.

**Commit de origem: não comprovado (`null`).** O relatório não registrou commit. Os testes/runner ainda não estão rastreados e `scripts/instalar.ps1` possui alterações anteriores não commitadas. Os SHA256 comprovam a correspondência atual dos arquivos, não a existência de um commit contendo toda a execução. Não atribuir o resultado ao HEAD, ao commit futuro de QA nem inferir o contexto da execução pelo horário da revisão.

## Arquivos revisados seguros para uma futura publicação

Lista explícita para revisão antes de uma eventual adição ao índice:

```text
.gitignore
AGENTS.md
README.md
scripts/testar.ps1
tests/QA.Tests.ps1
tests/TestSupport.ps1
tests/Invoke-SafeScenario.ps1
tests/fixtures/README.md
tests/fixtures/catalogo-minimo.json
tests/fixtures/json-invalido.txt
tests/fixtures/winget-cenarios.json
tests/fixtures/projeto-node/package.json
tests/fixtures/projeto-java/pom.xml
docs/qa.md
docs/plano-testes.md
docs/historico-execucoes.md
docs/defeitos.md
docs/versionamento-qa.md
evidencias/README.md
evidencias/resumos/README.md
evidencias/resumos/20261117-154901824-e02807e8.json
evidencias/resumos/20261117-154951182-4a307157.json
evidencias/resumos/20261117-155843943-58008942.json
evidencias/resumos/20261117-161114058-8591ed63.json
evidencias/resumos/20261117-node-lts-winget-direto-relato.json
```

Os caminhos `C:\fixture` nos testes são sintéticos; exemplos `C:\Dev` no README são genéricos, sem nome pessoal. As fixtures são dados fictícios e não executáveis. Resumos incluem somente ambiente mínimo, casos e hashes; não incluem PATH, contas, máquina, erros brutos ou stacktraces. Logs brutos e originais não fazem parte desta lista.

Após esta preparação, a padronização de tipos modificou o gerador e o teste QA-001. A execução mais recente é `20261117-161114058-8591ed63`, **MOCKADO, 43/43**. Os resumos antigos preservam os resultados históricos, com classificação retrospectiva somente nas cópias revisadas. Não usar seus hashes para afirmar que as fontes novas foram testadas naquela data; consultar o histórico e o resumo novo.

O registro posterior de WinGet direto de 17/11/2026 é `REAL_CONTROLADO` com grau `RELATADO`, baseado na mensagem do usuário; não possui log bruto anexado e não comprova a execução de `-Aplicar`. É um registro externo à suíte Pester e não altera os 43 testes.

## Fora deste lote

- `scripts/instalar.ps1`: diff de produção preexistente, preservado. A suíte depende das funções de aplicação Node contidas nessa cópia de trabalho; é necessária revisão separada desse diff antes de publicar uma revisão que se pretenda reproduzível. Não incluí-lo automaticamente no lote de QA.
- `scripts/verificar.ps1` e `config/ferramentas.json`: preservados, já rastreados, sem mudança nesta preparação.
- Tudo em `evidencias/execucoes/`: originais e históricos locais, nunca forçar inclusão.
- Logs, transcrições, `.env`, relatórios XML brutos e quaisquer arquivos pessoais: manter locais e ignorados.

## Checagens antes de publicar

1. Conferir `git status -sb`, `git diff --stat` e a lista acima. `git diff --stat` não inclui arquivos ainda não rastreados, mas inclui o diff anterior de produção.
2. Verificar regras de ignore e que nenhum bruto já esteja rastreado. `.gitignore` não remove dados do histórico nem protege arquivos já rastreados.
3. Revisar a lista exata a adicionar, sem `git add .`, sem `-f` e sem ações automáticas de commit/push.
4. Resolver a dependência do diff de produção em revisão separada. Esta preparação não declara a suíte aprovada para o HEAD atual isoladamente.
5. Depois de uma mudança funcional, executar a suíte segura e registrar nova evidência. Apenas documentação sem mudança nas fontes testadas não exige repetir uma execução consistente.
