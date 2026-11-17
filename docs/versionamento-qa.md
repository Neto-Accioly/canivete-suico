# Preparação para versionamento da Estrutura Básica Comentada

Revisão de 17/11/2026. Nenhum commit, push, instalação ou alteração de produção foi executado nesta preparação. Somente este guia foi atualizado; os candidatos abaixo não foram adicionados ao índice.

## Evidências conferidas

A execução `20261117-172726440-979f713b` é **MOCKADO, 67/67 aprovados**, sem falhas, ignorados ou pendentes: 43 casos QA e 24 casos PRJ. A classificação global inclui mocks de operações externas, análise estática e leitura controlada; não comprova instalação real. Ambiente registrado: PowerShell 5.1.26100.9818, Pester 3.4.0, processo de 64 bits.

JSON e XML originais concordam com o [resumo revisado](../evidencias/resumos/20261117-172726440-979f713b.json). Os hashes de ambos os originais e das dez fontes registradas foram conferidos. As fontes testadas permanecem iguais; não foi necessário repetir a suíte. Os originais permanecem locais, inalterados e ignorados em `evidencias/execucoes/`. As execuções anteriores, inclusive falhas, permanecem históricas.

**Commit de origem não comprovado: `null`.** A correspondência por SHA256 não atribui retroativamente a execução ao HEAD ou a um commit futuro.

DEF-010 está coberto por PRJ-021 a PRJ-024: destino absoluto final sem duplicar Nome, projeto novo, caminho relativo e caminhos inseguros. Código, testes e documentação usam Destino como pasta final; Nome é identificação/metadados.

A aplicação em qa-playwright de 17/11/2026 é **REAL_CONTROLADO / RELATADO**, registrada no [resumo do relato](../evidencias/resumos/20261117-criar-projeto-aplicacao-relato.json). A mensagem do usuário informa confirmação de criação, recusa de substituição de package.json, `ARQUIVOS_PRESERVADOS; DEPENDENCIAS_NAO_EXECUTADAS` e seis presenças posteriores via Test-Path. Não há log bruto anexado, código de saída comprovado, hashes anteriores nem validação independente nesta revisão. Não inferir contagem de arquivos efetivamente criados apenas da presença posterior.

**MEL-001 e MEL-002 continuam PENDENTE — somente registrado**: contagem de criados/preservados e diff legível do package.json. Não são funcionalidades entregues neste lote.

## Lista explícita e divisão proposta

São 23 candidatos: 12 modificados e 11 novos (contando a fixture como arquivo). Arquivos já versionados e inalterados não precisam ser adicionados novamente. Os comandos abaixo são propostas para autorização posterior, não foram executados. Executar na raiz do repositório, revisando cada índice antes do respectivo commit.

### 1. Funcionalidade

```powershell
git add -- scripts/criar-projeto.ps1
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "feat: adiciona estrutura comentada Playwright com destino final"
```

O script preserva simulação padrão, confirmações separadas para criação e npm, proteção de projetos existentes e escopo didático: o aluno escreve seus testes. Não inicializa Git nem gera testes resolvidos. A aprovação mockada não substitui validação real de todos os caminhos de aplicação.

### 2. Testes, fixture e plano

```powershell
$testes = @(
    'scripts/testar.ps1'
    'tests/CriarProjeto.Tests.ps1'
    'tests/TestSupport.ps1'
    'tests/fixtures/projeto-playwright/package.json'
    'tests/fixtures/README.md'
    'docs/plano-testes.md'
)
git add -- $testes
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "test: cobre estrutura comentada e regressao DEF-010"
```

A fixture é sintética; não é cópia do projeto do aluno. A suíte QA original permanece preservada. O runner inclui os novos casos e mantém as barreiras de operações externas.

### 3. Documentação e resumos sanitizados

```powershell
$documentacao = @(
    'AGENTS.md'
    'README.md'
    'docs/criar-projeto.md'
    'docs/defeitos.md'
    'docs/historico-execucoes.md'
    'docs/qa.md'
    'docs/versionamento-qa.md'
    'evidencias/README.md'
    'evidencias/resumos/README.md'
    'evidencias/resumos/20261117-170822514-f6d9c32b.json'
    'evidencias/resumos/20261117-170957796-626fc625.json'
    'evidencias/resumos/20261117-171430336-2439193e.json'
    'evidencias/resumos/20261117-172726440-979f713b.json'
    'evidencias/resumos/20261117-playwright-simulacao-existente.json'
    'evidencias/resumos/20261117-playwright-destino-final-simulacao.json'
    'evidencias/resumos/20261117-criar-projeto-aplicacao-relato.json'
)
git add -- $documentacao
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "docs: registra evidencias e limites da estrutura comentada"
git status -sb
```

## Privacidade e exclusões

A inspeção dos candidatos e a busca por caminhos de perfil pessoal e padrões comuns de credenciais não identificaram dados sensíveis. Os resumos publicados usam dados mínimos e sanitizados; não incluem os logs brutos. Exemplos de caminhos e fixtures dos testes não representam arquivos do aluno. Essa revisão não é garantia universal de detecção de segredos; revisar o diff exato antes de publicar.

`.gitignore` mantém originais de execução, logs, temporários, .env, node_modules e relatórios brutos fora do lote. Não foram encontrados brutos ou arquivos do projeto do aluno entre os arquivos rastreados/candidatos. Os originais JSON/XML da execução aprovada estão ignorados e seus hashes conferem. Nunca usar `git add .` nem forçar arquivos ignorados. Ignore não protege arquivos já rastreados.

`scripts/instalar.ps1`, `scripts/verificar.ps1` e `config/ferramentas.json` estão sem diff e ficam fora deste lote. `.gitignore` já está versionado e não precisou mudar. O projeto externo qa-playwright não foi alterado nesta preparação.

`git diff --stat` mostra apenas mudanças rastreadas; os arquivos novos aparecem em `git status -sb` e só entrarão no diff do índice após autorização de staging. Nenhum arquivo foi staged nesta revisão. Os commits propostos dependem da sequência funcionalidade, testes e documentação; não realizar push sem autorização.
