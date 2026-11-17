# Estrutura Básica Comentada de Playwright + TypeScript

**O Canivete prepara ambiente e organização; o aluno cria seus testes.** O recurso não resolve exercícios nem gera testes `.spec.ts`, Page Objects, assertions ou cenários. Não inicializa Git, executa testes ou instala navegadores.

## Usar primeiro em simulação

No Windows PowerShell 5.1, na raiz do Canivete:

```powershell
.\scripts\criar-projeto.ps1 -Tipo playwright-typescript -Nome qa-playwright -Destino "C:\Dev\qa-playwright"
```

`-Destino` é o **caminho completo e final do projeto**, sem acrescentar `-Nome`. `-Nome` serve somente como identificação e metadado de um manifesto novo; não renomeia pastas nem o nome de um manifesto existente. O tipo inicial é somente `playwright-typescript`. A identificação mantém letras minúsculas, números e hífens, até 64 caracteres, sem nomes reservados.

O destino pode ser absoluto (`C:\Dev\qa-playwright`) ou relativo (`.\qa-playwright`), resolvido a partir da localização atual do **PowerShell**, não do diretório corrente interno do processo .NET. Separadores e segmentos `.`/`..` são normalizados antes da validação. Por exemplo, estando em `C:\Dev`, ambos os destinos acima apontam para a mesma pasta, independentemente do valor de `-Nome`.

Caminhos UNC, provedores não FileSystem, ADS, curingas, caminhos ambíguos como `C:pasta`/`\pasta`, segmentos reservados, nomes com ponto/espaço final, raiz de disco e links/junctions são rejeitados. O caminho final é mostrado no plano; arquivos gerados devem permanecer dentro dele. Nada é gravado em simulação, inclusive em projeto existente.

**Mudança de contrato:** a primeira versão tratava Destino como pasta-base e concatenava Nome; ao informar a pasta final, isso duplicava `qa-playwright\qa-playwright`. Essa composição foi removida. Quem usava apenas `-Destino C:\Dev` deve agora informar a pasta final desejada. Não se tenta adivinhar ou acrescentar o nome automaticamente.

## Estrutura proposta

```text
<destino-final>/
  README.md
  package.json
  playwright.config.ts
  tsconfig.json
  .gitignore
  tests/README.md
  docs/README.md
```

As duas pastas contêm apenas orientações. A configuração Playwright aponta para `tests/`, mas não inclui testes nem projetos de navegador adicionais. `package.json` novo começa privado, sem dependências instaladas, com `test:e2e` e `typecheck`; o aluno decide quando executá-los depois de preparar seu ambiente e escrever seus testes. Sem testes, o executor pode informar que não encontrou testes.

O Playwright transpila TypeScript, mas não substitui a checagem de tipos; por isso a estrutura separa os scripts de teste e de verificação. Referência: [documentação oficial de TypeScript no Playwright](https://playwright.dev/docs/test-typescript).

## Autorizações separadas, somente com -Aplicar

`-Aplicar` não autoriza silenciosamente todas as etapas. O fluxo exige console interativo, sem entrada redirecionada:

1. Mostra o plano e pede a frase `CRIAR ESTRUTURA <nome>` antes de criar arquivos/pastas. Qualquer outra resposta cancela sem escrita.
2. Para **cada arquivo existente diferente**, mostra diff de linhas e pede `SUBSTITUIR <caminho-relativo>`. Sem essa aprovação individual, preserva o arquivo e não executa npm. Outros arquivos já autorizados podem ter sido criados; o resultado informa a preservação parcial.
3. Reavalia os pacotes locais. Se houver ausentes e Node/npm utilizáveis, mostra os argumentos npm e pede outra frase: `INSTALAR DEPENDENCIAS <nome>`. Cancelar aqui mantém a estrutura criada, mas não instala pacotes.

O desenvolvimento e a suíte não executaram aplicação real; autorizações são testadas com funções falsas. Posteriormente, o usuário relatou em **17/11/2026** a aplicação com confirmação de estrutura e recusa de `package.json`, resultado `ARQUIVOS_PRESERVADOS; DEPENDENCIAS_NAO_EXECUTADAS` e seis presenças confirmadas por Test-Path. Esse registro é **REAL_CONTROLADO / RELATADO**, sem log anexado ou reprodução independente. Ver [histórico](historico-execucoes.md). Não valida substituição aprovada nem npm real.

## Preservação e repetição

- Arquivos iguais, inclusive com diferença apenas CRLF/LF, recebem `MANTER` e não são regravados.
- `package.json` existente mantém nome, tipo, licença, scripts e dependências do aluno. Somente scripts auxiliares ausentes são propostos; o conteúdo proposto ainda exige diff e aprovação.
- O gerador não escreve diretamente `package-lock.json` nem toca `node_modules`. A etapa npm, se futuramente autorizada, pode modificá-los, assim como `package.json`.
- Escrita de arquivo novo usa `CreateNew`; não substitui arquivo surgido após o plano. Substituição confere SHA256 do arquivo antes de uma troca por arquivo temporário; mudanças concorrentes detectadas exigem novo plano.
- O temporário próprio, na mesma pasta, é removido após a troca. Não existe exclusão recursiva, limpeza de projeto ou rollback automático. Em caso de falha, inspecionar o que já foi criado; nunca presumir reversão.
- Repetir em estrutura já preparada não duplica arquivos. Configurações existentes diferentes continuam preservadas até aprovação individual; a execução não usa marcadores para assumir propriedade de arquivos do aluno.

## Detecção e dependências

O script procura Node/npm no PATH e no caminho padrão do Node em Program Files. Rejeita aliases WindowsApps como comprovação. Usa metadados do executável e, se necessário, apenas `node --version` para obter versão. A criação de arquivos não depende de Node; a instalação exige versão identificável a partir de 20 e npm localizado. Isso é um requisito mínimo de entrada, não garantia de compatibilidade com qualquer futura versão npm de pacotes.

Playwright, TypeScript e `@types/node` são detectados pela leitura de seus `package.json` locais. Não se usa `npx` para detectar ou baixar nada. Pacotes já presentes não são solicitados novamente. A presença local e a declaração no manifesto são exibidas separadamente; não há resolução completa de compatibilidade semver.

Para ausentes, a etapa opcional usa `npm install --save-dev --ignore-scripts --no-audit --no-fund` com nomes autorizados fixos. Versões declaradas em formato suportado são incluídas nos argumentos; especificações complexas ou suspeitas exigem revisão. O comando exato aparece antes da autorização. [As opções npm](https://docs.npmjs.com/cli/v11/commands/npm-install/) evitam lifecycle scripts nesta etapa, mas o resolvedor ainda pode ajustar o lockfile e dependências transitivas; não se promete imutabilidade dessas estruturas quando a instalação é autorizada. Não se usa npm global, `npm ci`, init ou install de navegadores.

A descoberta de diretórios em cache de navegadores é só indício de presença: não comprova compatibilidade com a revisão requerida e não abre navegadores. O PATH é ajustado temporariamente apenas no processo da eventual chamada npm e restaurado em `finally`, assim como a pasta corrente. Não altera PATH persistente nem configurações do Windows.

## Projeto existente observado

Em `C:\Dev\qa-playwright`, foram observados por leitura `package.json`, `package-lock.json`, `node_modules` e Playwright `1.65.1`, declarado como `^1.65.1`. TypeScript e `@types/node` não estavam presentes localmente na análise. O cache continha diretórios Chromium; os navegadores não foram executados.

O plano mostra explicitamente a presença de manifesto, lockfile e node_modules no próprio destino final. A regressão usa uma fixture de pasta final já existente com nome igual à identificação, assegurando que a busca de Playwright não ocorra em uma subpasta duplicada.

A simulação propôs revisão do manifesto para acrescentar apenas scripts auxiliares e criação dos seis arquivos ausentes. Nenhuma mudança foi aplicada. O [histórico](historico-execucoes.md) registra os resultados efetivamente obtidos e a conferência do projeto por hash.

## Resultados e limites

Saída `0`: simulação, conclusão ou cancelamento explícito; `1`: erro de leitura/escrita/npm; `2`: revisão ou verificação pendente. Cancelar dependências depois de criar a estrutura não apaga os arquivos criados.

A criação parcial autorizada tem um relato do usuário, sem comprovação independente de conteúdo ou hashes antes/depois. Instalação npm real, substituição aprovada, restauração pós-falha, concorrência, todos os discos/antivírus e versões futuras continuam sem validação real. Junctions e casos ambíguos são bloqueados de forma conservadora. O caminho de substituição não elimina toda corrida concorrente; não editar arquivos em paralelo durante futura aplicação.

Melhorias registradas, sem alteração de código: **MEL-001**, contagens claras de criados/preservados, e **MEL-002**, diff legível de package.json. Consulte o [registro de melhorias](defeitos.md).
