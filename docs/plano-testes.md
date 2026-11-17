# Plano de testes

Versão inicial: 2026-11-17. Escopo: catálogo, seleção, detecção, planejamento, aplicação restrita **simulada** e diagnóstico de projetos. Suite: `tests/QA.Tests.ps1`. Não executar instalações reais ou `-Aplicar` não instrumentado.

## Tipo global e técnicas individuais

As execuções automatizadas QA-001 a QA-043 são globalmente **MOCKADO**: operações externas isoladas, sem instalação real. Isso não significa que cada linha usa mock. Análise estática e leitura controlada do catálogo, fontes e fixtures também são reais, dentro desse isolamento. `REAL_CONTROLADO`, `MANUAL` e `NAO_EXECUTADO` seguem os critérios do [guia](qa.md); aprovação e tipo são independentes.

| Casos | `casos[].tecnicas` predominantes |
| --- | --- |
| QA-001, QA-003, QA-004 | `ANALISE_ESTATICA`, `LEITURA_CONTROLADA` |
| QA-002 | `BARREIRA_SEGURANCA` |
| QA-005 | `LEITURA_CONTROLADA` |
| QA-006 a QA-008 | `MOCK` |
| QA-009 a QA-016 | `FUNCAO_ISOLADA`, `LEITURA_CONTROLADA` |
| QA-017 a QA-032 | `MOCK` |
| QA-033 a QA-035 | `MOCK`, `AMBIENTE_PROCESSO_TEMPORARIO` |
| QA-036 a QA-038 | `FUNCAO_ISOLADA`, `LEITURA_CONTROLADA` |
| QA-039 a QA-043 | `MOCK`, `PROCESSO_FILHO_INSTRUMENTADO`, `LEITURA_CONTROLADA` |

As técnicas descrevem o caso e podem coexistir; não são tipos globais adicionais. A revisão atual amplia QA-001 com asserções estáticas do contrato de metadados JSON/XML, mantendo os 43 IDs. A exportação resultante é conferida também contra os artefatos da nova execução.

## Pré-condições comuns

- **P:** Windows PowerShell 5.1; Pester local 3.4/4.x; cópia de trabalho; runner autorizado a escrever apenas seus relatórios locais.
- **M:** módulos instrumentados por AST; todas as chamadas nativas de produção neutralizadas. Nenhuma consulta WinGet ou instalação real.
- **C:** catálogo atual de 25 itens, perfis independentes (5 essencial, 13 apis-bancos, 15 avancado). `winget_id` nulo é válido.
- **F:** fixtures fictícias versionadas, sem executáveis ou credenciais.
- **W:** worker seguro em processo filho; bloco principal instrumentado, entradas/instalação/verificação falsas.

Cada linha herda P e explicita as demais pré-condições. “Esperado” é critério de aprovação, não resultado executado; resultados pertencem ao [histórico](historico-execucoes.md).

| ID | Pré-condições | Passos | Resultado esperado |
| --- | --- | --- | --- |
| QA-001 | Fontes e testes legíveis | Analisar `.ps1` com parser 5.1; conferir declarações de tipo global, técnicas e propriedades XML no gerador | Zero erros; contrato de metadados presente |
| QA-002 | M | Chamar três pontos nativos sem mocks | `BARREIRA_QA`, sem execução nativa |
| QA-003 | Fonte original legível | Inspecionar AST de instalação | Um ID literal `OpenJS.NodeJS.LTS`; exact/source/interactive/no-upgrade/skip-dependencies; sem force/silent/accept |
| QA-004 | Fonte original legível | Inspecionar consulta de upgrades | Sem seleção de pacote; sem flag inexistente disable-source-update |
| QA-005 | C | Ler JSON, contar itens/IDs nulos e nomes; conferir campos | 25 itens, nove IDs nulos, nenhum nome duplicado, campos existentes |
| QA-006 | M, F | Simular arquivo válido com ID nulo; chamar Read-Catalogo | Objeto aceito, null preservado |
| QA-007 | M | Simular arquivo ausente e JSON inválido | Erros claros, sem plano |
| QA-008 | M | Simular campo ausente e nomes repetidos | Validação rejeita ambos |
| QA-009 | M, C | Selecionar Git; array; CSV com espaços e repetição | 1, 2 e 2 itens únicos |
| QA-010 | M, C | Informar nome desconhecido e CSV com elemento vazio | Erros claros |
| QA-011 | M, C | Selecionar Todas | 25 itens |
| QA-012 | M, C | Selecionar essencial; verificar associação de cada membro | Exatamente cinco membros, sem herança |
| QA-013 | M, C | Selecionar apis-bancos; verificar associação | Exatamente 13 membros |
| QA-014 | M, C | Selecionar avancado; verificar associação | Exatamente 15 membros |
| QA-015 | M, C, F | Perfil inexistente e referência inválida em fixture | Rejeição explícita |
| QA-016 | M, F | Interpretar tabela de um espaço e ID semelhante | Versão do ID exato; nenhum match parcial |
| QA-017 | M | Listar Git 2 fictício e upgrade 3 fictício | Versões registradas; ATUALIZAR apenas no plano |
| QA-018 | M | Tabela de upgrades completa sem Git | MANTER, limitado à consulta/fonte |
| QA-019 | M | Falha, versão Unknown e WinGet indisponível | INCONCLUSIVA/REVISAR, nunca presumir atualizado |
| QA-020 | M | Ausência WinGet; repetir com instalação local confirmada | INSTALAR no primeiro plano; REVISAR no conflito |
| QA-021 | M, C | Simular upgrades Java JDK, MySQL Server, MongoDB Server | REVISAR nos três |
| QA-022 | M, C | Consultar dependências npm/Maven e Pester | Zero chamadas WinGet |
| QA-023 | M | Simular git.exe em WindowsApps | INCONCLUSIVA; alias não confirma instalação |
| QA-024 | M | Simular Code.exe do perfil com metadados de produto | CONFIRMADA; versão, caminho e fonte LOCALAPPDATA |
| QA-025 | M, C | Pedir aplicação Node+Git e ID Node incorreto | Bloqueio integral, zero instalação e confirmação |
| QA-026 | M | Node existente ou inconclusivo | Bloqueio antes da aplicação |
| QA-027 | M | Ausência fictícia; confirmação retorna falso | CANCELADO; zero instalação/verificação |
| QA-028 | M | Ausência; confirmação verdadeira; instalação/verificação falsas positivas | SUCESSO; duas revalidações; uma confirmação e uma instalação falsa |
| QA-029 | M | Instalador falso retorna 1603, verificação positiva | FALHA, saída 1; não mascarar erro |
| QA-030 | M | Instalador falso retorna 0, verificação incompleta | VERIFICAÇÃO PENDENTE, saída 2 |
| QA-031 | M | Instalador falso retorna 3010 | Verificação pendente; não reiniciar automaticamente |
| QA-032 | M | Ausente antes da confirmação; inconclusivo depois | Bloqueio; zero instalação |
| QA-033 | M | Simular node/npm e inventário coerentes; verificar | Duas chamadas de versão, um list exato; PATH do processo restaurado |
| QA-034 | M | Simular versão node diferente do inventário | Sem confirmação de sucesso |
| QA-035 | M | Simular exceção no inventário pós-instalação | Exceção propagada; PATH restaurado |
| QA-036 | M, F | Diagnosticar projeto vazio e caminho inexistente | NAO INFORMADO e CAMINHO INVALIDO |
| QA-037 | M, F | Ler package.json fictício | Duas dependências DECLARADO; nenhum npm executado |
| QA-038 | M, F | Ler POM fictício | Dois INDICIO ENCONTRADO; nenhum Maven executado |
| QA-039 | W, C | Worker single/multiple/array/all/interactive | Saída 0; contagens 1/2/2/25/2; nenhum instalador falso chamado |
| QA-040 | W, C | Worker nos três perfis | Perfil e contagem 5/13/15; sem aplicação |
| QA-041 | W | Perfil/ferramenta inválidos e seletores conflitantes | Saída 1; zero instalação |
| QA-042 | W | Aplicação falsa: sucesso/cancelamento/falha/pendência | Saídas 0/0/1/2 e resultado legível; cancelamento não instala |
| QA-043 | W | Aplicação com seleção mista, existente ou inconclusiva | Saída 1; nenhuma chamada ao instalador falso |

## Cenários existentes fora da execução automatizada atual

Os cenários MAN abaixo são **NAO_EXECUTADO nesta suíte/entrega**. Seus nomes/observações anteriores não comprovam execução manual atual. Se efetivamente realizados no futuro, registrar o tipo `MANUAL` ou `REAL_CONTROLADO` conforme o procedimento e as evidências; nunca promover apenas por relato.

| ID | Pré-condições | Passos propostos | Resultado esperado | Situação |
| --- | --- | --- | --- | --- |
| MAN-001 | Ambiente de teste autorizado, sem instalação | Comparar `Get-Command winget`, `where.exe winget`, `winget --version` e PATH dentro/fora da sandbox, com autorização pontual | Separar descoberta, execução e restrição do ambiente | Observado anteriormente na sessão; não reexecutar pelo runner |
| MAN-002 | Console interativo, mocks de aplicação e leitura revisados | Digitar confirmação incorreta/correta; testar entrada redirecionada | Só a frase exata permite a operação falsa; redirecionamento bloqueado | Observações anteriores sem artefato; confirmação física não automatizada |
| MAN-003 | Ambiente descartável e autorização específica futura | Executar instalação real de Node ausente; validar EULA/UAC, versões e PATH em novo terminal | Resultado real verificável | NÃO EXECUTADO e fora da autorização desta entrega |
| MAN-004 | Ambiente de teste específico | Executar suite com Pester 4.x, outros Windows/arquiteturas e política de execução | Resultado registrado por ambiente | NÃO EXECUTADO |
| MAN-005 | Programa portátil fora do PATH/Registro | Avaliar limitações de descoberta sem instalar nada | Não prometer ausência global | Limitação conhecida; sem cenário físico montado |

Critério de saída: suíte sem falhas/pendências/ignorados, hashes de produção preservados, evidência vinculada ao hash testado e defeitos/limitações registrados. “Todos passaram” não transforma MAN-003 em cenário realizado.
