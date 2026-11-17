# QA do NETO-LAB

Esta documentação descreve o estado atual do projeto e como testá-lo sem instalar programas. O diagnóstico `verificar.ps1` é de leitura. O `instalar.ps1` simula por padrão e tem uma aplicação real restrita ao Node.js LTS; essa aplicação **não faz parte dos testes reais do ambiente**.

## Comece aqui

1. Leia o [plano de testes](plano-testes.md), os [defeitos](defeitos.md) e o [histórico](historico-execucoes.md).
2. Use Windows PowerShell 5.1 com Pester 3.4 ou 4.x **já instalado**. A sessão inicial tem Pester 3.4.0; compatibilidade com 4.x é prevista, mas precisa de execução própria. Pester 5 não é selecionado pelo runner porque a suíte usa a sintaxe clássica do Pester 3/4. Nenhum módulo é instalado/atualizado automaticamente.
3. Na raiz do repositório, execute:

   ```powershell
   .\scripts\testar.ps1
   ```

4. Confira código de saída e `evidencias/execucoes/<id>/resumo.json`. O XML `pester.nunit.xml` contém detalhes de falhas; o JSONL `historico-local.jsonl` registra execuções concluídas. Nada disso é publicado por padrão.
5. Se uma política bloquear scripts, não use `Set-ExecutionPolicy` para mudar o computador. Nesta sessão de desenvolvimento o runner foi iniciado em processo filho com `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\testar.ps1`; a opção vale apenas para aquele processo. Os workers usam a mesma abordagem de processo isolado. Isso não desativa a sandbox nem concede administração.

O runner retorna `0` quando todos os testes passam e os arquivos de produção mantêm seus hashes; `1` para falha, pendência ou execução incompleta; `2` para erro de infraestrutura. Não confunda esses códigos com os resultados individuais dos cenários instrumentados do instalador.

## O que cada camada comprova

### Classificação global, técnica e resultado são eixos separados

| `tipo_execucao` | Critério |
| --- | --- |
| `MOCKADO` | Execução isolada; operações externas substituídas por mocks/barreiras. Pode incluir verificações estáticas, execução de funções e leitura controlada de arquivos reais. Não valida instalação real. É a classificação global dos 43 testes atuais. |
| `REAL_CONTROLADO` | Execução contra componentes reais em ambiente/escopo controlado e autorizado, com evidências. Não significa necessariamente instalação; exige registrar quais operações reais ocorreram. A suíte atual não produz este tipo. |
| `MANUAL` | Caso executado por uma pessoa, com passos, ambiente, resultado e evidências registrados. Um relato isolado não comprova execução manual. |
| `NAO_EXECUTADO` | Cenário não realizado; não possui resultado de aprovação nem evidência de execução. |

O runner fixa `MOCKADO`; não oferece um parâmetro que permita rotular a mesma suíte como real. No JSON, `tipo_execucao` descreve a execução completa e `casos[].tecnicas` descreve as técnicas de cada teste. Por exemplo, QA-005 lê o catálogo real de forma controlada e QA-017 usa mocks; ambos pertencem à mesma execução global `MOCKADO`. O resultado `APROVADO` e o grau de comprovação documental são informações independentes desse tipo.

As técnicas são anotações do desenho do caso, não telemetria de cobertura. Um caso falho pode parar antes de exercer todas as suas etapas; acrescentar técnicas ao resumo não muda isso nem comprova caminhos não alcançados.

No XML, o tipo está em `test-results/test-suite/properties/property[@name='tipo_execucao']`, usando metadados de suite no formato NUnit. A raiz, os atributos existentes, os nomes, contagens e o caminho `test-suite/results/test-case` permanecem iguais. As técnicas individuais estão no JSON e no plano, sem atributos customizados nos casos XML. A compatibilidade verificada é estrutural com os leitores existentes; não representa certificação contra todos os consumidores/esquemas NUnit.

Os resumos antigos revisados recebem classificação **retrospectiva na cópia derivada**, identificada na proveniência. XML/JSON originais sem o campo permanecem intactos; não dizer que já continham a classificação. O erro de exportação sem resultado utilizável continua erro de infraestrutura, não execução aprovada.

- **Análise estática:** o parser verifica sintaxe; a inspeção de AST verifica os comandos permitidos. Uma sintaxe válida não comprova funcionamento.
- **Testes de funções:** verificam catálogo, seleção, interpretação de evidências, planejamento e bloqueios com entradas controladas.
- **Fluxo principal instrumentado:** um processo filho executa uma cópia em memória do bloco principal com dependências falsas. Comprova ramificações e códigos de saída, mas não a instalação real nem a passagem de arrays nativos diretamente para `powershell.exe -File instalar.ps1`.
- **Consultas reais anteriores:** os resultados disponíveis na conversa são observações da sessão, não artefatos preservados no repositório. Não são reexecutados por esta suíte nem convertidos automaticamente em execução `REAL_CONTROLADO` ou `MANUAL` comprovada.
- **Instalação real:** continua não executada. Interface do instalador, contratos, UAC, reinicialização e sucesso em um Windows limpo não foram comprovados.

`INSTALAR` no plano não significa programa instalado. `ATUALIZAR` é recomendação simulada; nenhum upgrade real é implementado. `MANTER` significa que a consulta reconhecida não listou atualização, sem garantir a versão mais recente de todas as fontes. `REVISAR` bloqueia aplicação quando faltam evidências.

## Como o isolamento funciona

`TestSupport.ps1` analisa os arquivos de produção, extrai suas funções e não executa seus blocos principais. Funções que chamam WinGet, instaladores ou executáveis de versão são substituídas por barreiras que lançam `BARREIRA_QA` se chamadas sem mock. Consultas globais ao Registro e à disponibilidade do WinGet também são neutralizadas. Uma nova invocação nativa fora das funções conhecidas interrompe a instrumentação para revisão.

Os mocks Pester são instalados dentro de `QaInstalador`. As asserções de chamadas usam o escopo `It`, evitando contagens acumuladas entre testes. Dados artificiais ficam em `tests/fixtures/`. Os testes de VS Code usam arquivos/metadados falsos; não afirmam que o editor está instalado neste computador.

`Invoke-SafeScenario.ps1` aplica primeiro as barreiras e depois substitui consultas, confirmação, instalação e verificação por funções falsas. Somente essa cópia em memória pode receber `-Aplicar` na suíte. O worker nunca chama o instalador original por `-File`. O timeout encerra apenas o processo filho criado pelo próprio teste.

O teste da confirmação física não é automatizado: nos cenários de aplicação ela é uma resposta simulada. Os testes comprovam que o código chama a confirmação e respeita cancelamento; não devem ser apresentados como validação da experiência humana de confirmação.

## Evidências e dados sensíveis

O exportador XML desta suíte usa os resultados do Pester diretamente. Não usa o exportador nativo do Pester 3, que tentou consultar CIM/WMI e falhou com acesso negado na primeira tentativa. Não é necessário elevar permissões para gerar o relatório.

Relatórios brutos podem conter caminhos pessoais em mensagens de erro. O resumo omite erro/stacktrace, usuário, hostname e PATH; inclui data, versões do ambiente, casos e hashes de origem. Ainda assim, revise qualquer resumo antes de copiá-lo para `evidencias/resumos/`. Use identificadores de execução, não capturas de tela ou inventários pessoais desnecessários.

Estados documentais:

| Estado | Significado |
| --- | --- |
| COMPROVADO POR ARTEFATO | Execução atual vinculada a um relatório existente e aos hashes das fontes. Mocks continuam sendo mocks. |
| OBSERVADO NA SESSÃO | Resultado apareceu na conversa, sem relatório bruto arquivado. |
| RELATADO | Informação fornecida por uma pessoa, sem reprodução arquivada. |
| NÃO EXECUTADO | Existe cenário ou intenção, sem teste correspondente concluído. |
| ERRO DE INFRAESTRUTURA | O ambiente/runner impediu obter um resultado utilizável; não contar como aprovação. |

## Manutenção durante desenvolvimento

Para cada mudança funcional: atualize casos e fixtures pertinentes, execute a suíte segura, registre a execução (inclusive falhas), vincule defeitos reproduzidos e só então atualize o estado da correção. Não reutilize um relatório antigo como evidência de um novo hash de produção. O `AGENTS.md` torna esse fluxo parte das orientações do repositório.

Mantenha IDs existentes; acrescente novos IDs para novos comportamentos. As contagens 25/5/13/15 são contratos da versão atual do catálogo: uma expansão autorizada exige atualizar o catálogo, os testes e o plano juntos. As rotinas de produção foram preservadas nesta entrega.

## Limites atuais

Para preparar uma publicação, siga [versionamento de QA](versionamento-qa.md). O resumo das 15:58 foi conferido na revisão anterior; a mudança posterior do gerador e do teste de contrato exigiu uma nova execução `MOCKADO`. As evidências continuam vinculadas aos respectivos SHA256, sem commit de origem comprovado; não transferir aprovação antiga para fontes alteradas.

Sem instalação real, rede, WinGet real, consulta real ao Registro ou serviços nos cenários automatizados do instalador. Não há medição de cobertura por linhas, teste de todas as versões/arquiteturas do Windows, certificação de segurança, validação de UI nem garantia contra alterações concorrentes externas. O diagnóstico Maven é textual e as dependências Node são declarações. A evidência de um teste falso nunca comprova uma ferramenta instalada.
