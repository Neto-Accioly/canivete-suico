# Registro de defeitos e limitações

Um relato é separado de reprodução. “Corrigido” exige regressão identificada; instalação real não foi testada. Impacto aqui descreve o desenvolvimento/QA, sem substituir análise de segurança.

| ID | Origem / reprodução | Esperado versus observado | Impacto | Estado / regressão |
| --- | --- | --- | --- | --- |
| DEF-001 | Relato do usuário na sessão anterior, sem log preservado | Com `powershell.exe -File`, `Git,VS Code` deveria selecionar dois itens; chegava como um nome único | Seleção múltipla bloqueada | Correção prévia observada na sessão; normalização CSV comprovada agora por QA-009/039. O worker não reproduz o transporte nativo exato de `-File instalar.ps1`; esse ponto continua como observação anterior |
| DEF-002 | Observado na sessão: WinGet resolvido, mas inacessível na sandbox; funcionava fora após autorização pontual | Descoberta de comando não garante que o launcher possa ser executado | Consultas tornam-se inconclusivas | Limitação de ambiente, sem mudar PATH/ACL; comportamento inconclusivo coberto com mocks em QA-019. Nenhum novo teste real WinGet nesta entrega |
| DEF-003 | Ajuda real v1.29.380 lida na sessão anterior | Versão antiga do script exigia `--disable-source-update`, opção ausente | Omitia consulta WinGet mesmo quando executável funcionava fora da sandbox | Código corrigido previamente; QA-004 verifica ausência da flag. Sem alegar que a consulta seja livre de logs/cache internos |
| DEF-004 | Documentação da Microsoft e ajuda lidas na sessão anterior | `winget upgrade --id` não é prévia, pode atualizar; deve usar listagem sem seleção e filtrar ID em memória | Implementação insegura se confundida com leitura | Comando perigoso não foi executado; implementação atual protegida por QA-004. Registro de decisão preventiva, não incidente de atualização |
| DEF-005 | README lido nesta entrega dizia “instalador ainda não implementado” | Documentação deveria reconhecer simulação e aplicação restrita Node | Desorientação de uso | README corrigido nesta entrega, por revisão documental; scripts preservados |
| DEF-006 | Reprodução atual `20261117-154802196-29e46476` | Exportar relatório sem privilégios extras; exportador nativo Pester 3 consultou CIM/WMI e falhou com acesso negado | Sem relatório utilizável; saída de infraestrutura | Corrigido no runner novo com XML próprio sem WMI. Execução `20261117-154951182-4a307157` gerou artefatos; nenhuma permissão extra concedida |
| DEF-007 | Reprodução atual `20261117-154901824-e02807e8` | Mocks deveriam ser contados por caso, com helper acessível no módulo; houve contagem acumulada e helper não encontrado | Sete falsos negativos na suíte: QA-022, QA-027 a QA-032 | Corrigido no harness: `-Scope It` e helper no módulo. Regressão seguinte 43/43, artefato no histórico. Produção não modificada |

### Extensão criar-projeto

| ID | Reprodução | Observado / correção | Regressão |
| --- | --- | --- | --- |
| DEF-008 | PRJ-001 em `20261117-170822514-f6d9c32b` | A regex de nomes usava comparação sem distinção de caixa e aceitava maiúsculas apesar da regra anunciada. Corrigida para `-cnotmatch` | PRJ-001 aprovado em `20261117-171430336-2439193e` |
| DEF-009 | Primeiras duas execuções PRJ e tentativa interrompida | Mocks Pester 3 persistiam no Describe; leitores simulados e filtros de confirmação interferiam em outros casos. O encaminhamento de leitor introduziu PathType nulo e lentidão. Cenário de junction isolado em módulo separado; confirmações reinicializadas | 63/63 em `20261117-171430336-2439193e`; sem mudança nos scripts instalar/verificar |
| DEF-010 | Relato do usuário: Nome qa-playwright e Destino final já terminado em qa-playwright; composição anterior confirmada por inspeção do código | O resolver tratava Destino como pasta-base e acrescentava Nome, planejando a raiz duplicada qa-playwright/qa-playwright e procurando os pacotes no local errado. Destino agora é final; Nome é somente identificação/metadados; relativos usam a localização PowerShell. Não foi afirmado que houve criação física da pasta duplicada | PRJ-021 a PRJ-024 e suíte **67/67** em `20261117-172726440-979f713b`; simulação real somente leitura confirmou manifesto/lock/node_modules/Playwright no destino correto |

## Limitações conhecidas, sem defeito reproduzido adicional

- Descoberta é limitada ao escopo consultado. Software portátil, variantes, nomes de Registro diferentes e alterações concorrentes podem exigir revisão; ausência global não é garantida.
- Um arquivo/registro localizado não prova funcionamento nem versão atualizada. Dependências declaradas não comprovam instalação.
- Não há instalação real validada; recuperação após falha parcial e UI/EULA/UAC não foram exercitadas.
- O runner seleciona Pester 3.4/4.x; execução comprovada somente em 3.4.0. Pester 5 exige migração explícita da suíte, não instalação automática.
- A análise Maven do diagnóstico é textual. Os testes preservam essa semântica, sem prometer resolução completa de dependências.

## Melhorias de usabilidade pendentes

As solicitações abaixo decorrem da aplicação parcial relatada em 17/11/2026, registro REAL-20261117-CRIAR-PROJETO-APLICAR. São melhorias propostas, não falhas de preservação reproduzidas, correções implementadas ou testes aprovados.

| ID | Solicitação / motivação | Critério de aceite futuro | Estado |
| --- | --- | --- | --- |
| MEL-001 | Mostrar contagens de criados e preservados no resultado; o usuário confirmou seis presenças com Test-Path, mas não forneceu contagem emitida pelo recurso | Apresentar contagens e listas por ação: criados, já iguais, preservados por recusa e falhos. Não confundir presença posterior com criação feita nesta execução. Cobrir cancelamento, recusa parcial e repetição com testes mockados | PENDENTE — somente registrado |
| MEL-002 | Tornar mais legível o diff individual de package.json, evitando ruído de reindentação | Mostrar mudanças com contexto e identificação de propriedades, especialmente scripts adicionados, preservando campos do aluno; manter aprovação individual obrigatória e conferir o conteúdo final proposto. Cobrir preservação e recusa em regressão mockada | PENDENTE — somente registrado |

## Modelo de novo defeito ou melhoria

ID; data/fuso; origem (relato ou reprodução); ambiente; caso de teste; pré-condições; passos mínimos; esperado; observado; impacto; evidência sanitizada; estado; correção; execução de regressão. Não incluir segredos ou declarar causa definitiva sem evidência. Reabrir se a regressão falhar.
