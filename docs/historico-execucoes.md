# Histórico de execuções

Datas desta entrega em America/Sao_Paulo (UTC−03:00). Ambiente informado pelo usuário: Windows 11 Pro e VS Code. Ambiente medido pelo runner: Windows PowerShell **5.1.26100.9818**, Pester **3.4.0**, processo **64 bits**, versão Windows retornada pelo runtime **10.0.26300.0**. O identificador do runtime não é uma nova confirmação da edição comercial do Windows.

## Antes da documentação versionada

Não existem relatórios brutos preservados dessas etapas no repositório. Os IDs QA foram atribuídos agora e servem como rastreabilidade retrospectiva, não como prova de execução histórica.

| Registro | Data | Origem e cenário | Resultado e classificação | Evidência disponível |
| --- | --- | --- | --- | --- |
| HIST-001 | 2026-11-17, horário não arquivado | Usuário informou que `-File -Ferramentas "Git","VS Code"` chegava como um nome CSV | RELATADO; originou DEF-001 | Conversa; nenhum artefato bruto |
| HIST-002 | 2026-11-17, horário não arquivado | Ferramentas da sessão validaram CSV, arrays, perfis, seleção interativa e códigos de erro | OBSERVADO NA SESSÃO; regressões atuais QA-009/039/040/041 | Saídas na conversa; sem relatório arquivado |
| HIST-003 | 2026-11-17, horário não arquivado | Usuário informou `winget --version` = v1.29.380 no terminal do VS Code | RELATADO | Mensagem do usuário |
| HIST-004 | 2026-11-17, horário não arquivado | Consultas da sessão: PATH continha WindowsApps; Get-Command encontrava WinGet; execução falhava na sandbox e retornava v1.29.380 fora dela, após autorização | OBSERVADO NA SESSÃO; restrição de contexto, sem alteração de PATH ou permissões | Saídas na conversa; não reexecutadas pela suíte |
| HIST-005 | 2026-11-17, horário não arquivado | Consultas autorizadas list/upgrade: Git 2.56.0.4 e VS Code 1.146.0; sem upgrade listado para esses IDs na fonte consultada | OBSERVADO NA SESSÃO, não prova de estado atual | Saídas na conversa; sem arquivo de inventário arquivado |
| HIST-006 | 2026-11-17, horário não arquivado | Primeira aplicação Node implementada e exercitada com funções falsas em memória | OBSERVADO NA SESSÃO; sem instalação real; nenhuma contagem agregada reconstruída | Saídas na conversa; agora coberto por QA-025 a QA-035/042/043 |

## Execuções desta entrega

**Tipo global das execuções automatizadas abaixo: `MOCKADO`**, inclusive as tentativas reprovada/incompleta. Há mocks nas operações externas, verificações estáticas e leitura controlada de arquivos reais. A classificação não é o resultado: as falhas originais permanecem falhas. Para registros antigos, o rótulo é retrospectivo nos resumos derivados; não consta necessariamente dos originais. Técnicas individuais estão no plano e nos novos `casos[].tecnicas`, sem transformar a execução em validação real de instalação.

| Execução | Início São Paulo | Ambiente | Resultado real | Evidência |
| --- | --- | --- | --- | --- |
| `20261117-154802196-29e46476` | 2026-11-17 15:48:02.196 −03:00 | PowerShell 5.1 / Pester 3.4 / sandbox | ERRO DE INFRAESTRUTURA: exportador XML nativo recebeu acesso negado ao consultar CIM/WMI. Contagem de testes não recuperada nessa tentativa; não é aprovação. DEF-006 | XML local parcial em `evidencias/execucoes/<id>/pester.nunit.xml`, ignorado; erro observado na sessão |
| `20261117-154901824-e02807e8` | 2026-11-17 15:49:01.824 −03:00 | 5.1.26100.9818 / 3.4.0 / 64 bits / sandbox | COMPROVADO POR ARTEFATO: 43 casos, 36 aprovados, **7 falhos**, zero pendentes/ignorados. Produção preservada. Falhas no harness, DEF-007 | [Resumo revisado reprovado](../evidencias/resumos/20261117-154901824-e02807e8.json); XML bruto local ignorado |
| `20261117-154951182-4a307157` | 2026-11-17 15:49:51.182 −03:00 | 5.1.26100.9818 / 3.4.0 / 64 bits / sandbox | COMPROVADO POR ARTEFATO: **43/43 aprovados**, zero falhos/pendentes/ignorados. Produção preservada. Exportação sem WMI e regressão do harness confirmadas | [Resumo revisado aprovado](../evidencias/resumos/20261117-154951182-4a307157.json); XML bruto local ignorado |
| `20261117-155843943-58008942` | 2026-11-17 15:58:43.943 −03:00 | 5.1.26100.9818 / 3.4.0 / 64 bits; Windows runtime 10.0.26300.0 | COMPROVADO POR ARTEFATO: **43/43 testes isolados aprovados**, zero falhos/pendentes/ignorados. Interações externas substituídas por mocks; sem instalação real. XML/JSON e hashes das sete fontes conferidos nesta revisão | [Resumo derivado revisado](../evidencias/resumos/20261117-155843943-58008942.json); XML/JSON originais preservados e ignorados |
| `20261117-161114058-8591ed63` | 2026-11-17 16:11:14.058 −03:00 | 5.1.26100.9818 / 3.4.0 / 64 bits; Windows runtime 10.0.26300.0 | **MOCKADO**, COMPROVADO POR ARTEFATO: **43/43 aprovados**, zero falhos/pendentes/ignorados. Inclui verificações estáticas, leitura controlada e mocks; metadados nativos no novo JSON/XML. Produção preservada | [Resumo derivado revisado](../evidencias/resumos/20261117-161114058-8591ed63.json); novos XML/JSON originais locais; commit de origem não comprovado |

Na execução intermediária, falharam QA-022 e QA-027 a QA-032. O histórico de mocks estava acumulado no escopo Describe, e um helper não era visível dentro do módulo instrumentado. A correção limitou as contagens a `It` e carregou o helper no módulo de teste. Não houve correção de produção nessa etapa.

Cada resumo contém hashes das fontes e do XML local. Uma edição futura invalida a associação do resultado antigo com a nova fonte: crie nova execução e nova linha. Falhas anteriores não devem ser apagadas nem convertidas em aprovações.

### Proveniência da execução 15:58

O relatório original não contém commit. A revisão encontrou QA ainda não rastreado e mudanças anteriores em `scripts/instalar.ps1`; portanto **commit de origem não comprovado (`null`)**. Os sete SHA256 registrados coincidem com a cópia de trabalho revisada. Não é correto atribuir esse resultado ao HEAD nem afirmar que uma publicação apenas dos arquivos de QA validaria o instalador antigo daquele commit.

O runner não foi reexecutado nesta preparação: XML/JSON consistentes, 43 casos coincidentes e fontes testadas inalteradas. Foram alterados somente textos de documentação/proveniência, sem mudar testes ou comportamento de produção. Os originais não foram sanitizados em seu lugar: a cópia derivada acrescenta hashes dos artefatos e o limite de proveniência.

Essa afirmação descreve a preparação anterior. Na padronização posterior, o gerador e o teste QA-001 foram alterados; a nova execução segura `20261117-161114058-8591ed63` foi concluída como `MOCKADO`, 43/43. Não associar os hashes antigos a essas novas fontes. Os resumos derivados antigos explicitam a atribuição retrospectiva de tipo/técnicas e a divergência atual dos hashes do gerador/teste; seus resultados e originais foram preservados.

## Instalação direta relatada — REAL_CONTROLADO

Registro **REAL-20261117-NODE-WINGET-DIRETO**, data informada **17/11/2026**, horário não fornecido. Tipo de execução: **REAL_CONTROLADO**; grau de comprovação: **RELATADO pelo usuário**, sem log bruto, captura ou transcrição anexados e sem reprodução independente nesta entrega. Ambiente informado anteriormente: Windows 11 Pro, VS Code e Windows PowerShell 5.1; não aferido novamente.

O usuário informou ter executado diretamente:

```powershell
winget install --id OpenJS.NodeJS.LTS --exact --source winget --interactive --no-upgrade --skip-dependencies
```

| Etapa | Resultado informado |
| --- | --- |
| Instalação direta | WinGet exibiu `Successfully installed` |
| Inventário | Node.js LTS `26.13.1` |
| PATH inicial da sessão | `node` e `npm.cmd` não eram encontrados |
| Verificação pelos caminhos completos | Node `v26.13.1` e npm `11.20.0` funcionaram |
| Ajuste | Somente o PATH da sessão foi atualizado, conforme relato; comando exato não fornecido |
| Verificação após ajuste | `node --version` e `npm.cmd --version` funcionaram, com as versões informadas acima |
| Resolução | `Get-Command node` apontou `C:\Program Files\nodejs\node.exe` |

Resultado documental: **SUCESSO_RELATADO da instalação via WinGet direto**. Não há código de saída numérico, horário, hash de instalador ou commit de origem comprovado. O PATH inicial desatualizado não equivale, neste relato, a falha de instalação: os caminhos completos funcionavam antes do ajuste da sessão. Não inferir persistência do PATH nem sucesso em novo terminal.

Evidência derivada: [registro sanitizado do relato](../evidencias/resumos/20261117-node-lts-winget-direto-relato.json). Não foi fabricado relatório Pester/XML nem saída de terminal. Nenhum comando de instalação, versão ou alteração de PATH foi executado pelo assistente nesta entrega.

**A rotina `scripts/instalar.ps1 -Aplicar` não foi usada nesse procedimento e continua sem validação real ponta a ponta.** Seus 43 testes automatizados permanecem `MOCKADO`, com os mesmos artefatos e resultados anteriores.

## Não executado pela suíte / não validado em execução real

Instalação real pela rotina `-Aplicar`; upgrades e remoções reais; confirmação física e tratamento de EULA/UAC/reboot pela rotina; testes em Pester 4/5 e outros ambientes. Os cenários `-Aplicar` desta suíte usam somente mocks isolados. O relato separado de WinGet direto não valida essas etapas do script.

Esses cenários têm tipo `NAO_EXECUTADO` em execução real pela suíte. Há um registro externo `REAL_CONTROLADO` com grau `RELATADO`, acima; ele não é evidência independente nem muda a classificação dos testes automatizados.

## Modelo para nova execução

`ID | data com fuso | ambiente medido | casos executados/contagens | resultado | hashes e link para resumo revisado | defeitos/limitações`

Se a execução não chegar ao relatório, registrar o erro e o que efetivamente foi observado; não inventar contagens. Revisar os dados antes de publicar evidências. Nenhum commit/push é automático.
