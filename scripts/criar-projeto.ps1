#requires -Version 5.1
<#
.SYNOPSIS
Prepara estrutura basica comentada; o aluno cria seus proprios testes.
.EXAMPLE
.\scripts\criar-projeto.ps1 -Tipo playwright-typescript -Nome qa-playwright -Destino C:\Dev\qa-playwright
.NOTES
Destino e a pasta final do projeto, absoluta ou relativa a localizacao atual
do PowerShell. Nome e somente identificacao/metadados, nunca sufixo do caminho.
Simulacao por padrao. -Aplicar solicita autorizacoes separadas para estrutura,
substituicao de cada arquivo e npm. Nao inicializa Git nem instala navegadores.
Saidas: 0 simulacao/conclusao/cancelamento; 1 falha; 2 revisao/pendencia.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('playwright-typescript')][string]$Tipo,
    [Parameter(Mandatory = $true)][string]$Nome,
    [Parameter(Mandatory = $true)][string]$Destino,
    [switch]$Aplicar
)

function Assert-RotaProjeto {
    param([string]$Raiz, [string]$Caminho)
    $root = [IO.Path]::GetFullPath($Raiz).TrimEnd('\')
    $full = [IO.Path]::GetFullPath($Caminho)
    if ($full -ine $root -and -not $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Caminho fora da raiz autorizada do projeto.'
    }
    $current = $full
    while ($current) {
        if (Test-Path -LiteralPath $current -ErrorAction Stop) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Link/junction nao permitido no caminho: $current"
            }
            if ($current -ine $full -and -not $item.PSIsContainer) { throw 'Um ancestral do caminho e um arquivo.' }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Resolve-RaizProjeto {
    param([string]$Nome, [string]$Destino)
    if ($Nome -cnotmatch '^[a-z0-9][a-z0-9-]{0,63}$' -or
        $Nome -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])$') {
        throw 'Nome invalido: use identificacao com letras minusculas, numeros e hifens; sem nomes reservados.'
    }
    if ([string]::IsNullOrWhiteSpace($Destino) -or $Destino -match '[*?<>|"\x00-\x1f]' -or
        $Destino -match '^[\\/]' -or ($Destino.Contains(':') -and $Destino -notmatch '^[a-zA-Z]:[\\/][^:]*$')) {
        throw 'Destino invalido: use pasta final local absoluta ou relativa; UNC, drive relativo, provedores, ADS e curingas nao sao aceitos.'
    }
    foreach ($segment in ($Destino.Replace('/','\') -split '\\')) {
        if ($segment -and $segment -notin @('.','..') -and
            ($segment -match '[. ]$' -or $segment -match '^(?i:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)')) {
            throw 'Destino contem segmento ambiguo ou reservado do Windows.'
        }
    }
    $provider = $null
    $drive = $null
    # Resolver a partir da localizacao PowerShell, nao do cwd do processo .NET.
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destino, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'FileSystem' -or $resolved -notmatch '^[a-zA-Z]:[\\/]') { throw 'Destino deve pertencer ao sistema de arquivos local.' }
    $root = [IO.Path]::GetFullPath($resolved)
    if ($root.TrimEnd('\') -ieq [IO.Path]::GetPathRoot($root).TrimEnd('\')) { throw 'A raiz de um disco nao pode ser o projeto.' }
    $root = $root.TrimEnd('\')
    Assert-RotaProjeto $root $root
    if ((Test-Path -LiteralPath $root) -and -not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'A raiz do projeto existe como arquivo.'
    }
    return $root
}

function Read-JsonProjeto {
    param([string]$Caminho)
    $value = Get-Content -LiteralPath $Caminho -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($value -isnot [PSCustomObject]) { throw "JSON deve conter objeto: $Caminho" }
    return $value
}

function Get-AmbienteProjeto {
    $node = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $nodePath = if ($node) { $node.Source } else { '' }
    if (-not $nodePath -and $env:ProgramFiles) {
        $candidate = Join-Path $env:ProgramFiles 'nodejs\node.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $nodePath = $candidate }
    }
    $version = ''
    $npmPath = ''
    if ($nodePath -and $nodePath -notmatch '(?i)[\\/]WindowsApps[\\/]') {
        $file = Get-Item -LiteralPath $nodePath -ErrorAction Stop
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
            $version = [string]$file.VersionInfo.ProductVersion
            if (-not $version) { $version = Invoke-VersaoAmbienteProjeto $nodePath }
            $candidate = Join-Path $file.DirectoryName 'npm.cmd'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $npmPath = $candidate }
        }
    }
    $npmCommand = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $npmPath -and $npmCommand -and $npmCommand.Source -notmatch '(?i)[\\/]WindowsApps[\\/]') { $npmPath = $npmCommand.Source }
    $usable = $false
    if ($version -match '^v?(\d+)\.') { $usable = [int]$Matches[1] -ge 20 -and -not [string]::IsNullOrWhiteSpace($npmPath) }
    [PSCustomObject]@{ Node = $nodePath; Npm = $npmPath; VersaoNode = $version; PodeInstalar = $usable }
}

function Invoke-VersaoAmbienteProjeto {
    param([string]$Caminho)
    # Somente consulta de versao; nunca npm/npx para detectar Playwright.
    try {
        $output = @(& $Caminho --version 2>&1)
        if ($LASTEXITCODE -eq 0 -and ($output -join '').Trim() -match '^v\d+\.\d+\.\d+$') { return ($output -join '').Trim() }
    }
    catch { return '' }
    return ''
}

function Get-DependenciasProjeto {
    param([string]$Raiz)
    $manifest = Join-Path $Raiz 'package.json'
    $package = if (Test-Path -LiteralPath $manifest) { Read-JsonProjeto $manifest } else { $null }
    foreach ($name in @('@playwright/test', 'typescript', '@types/node')) {
        $declared = ''
        foreach ($section in @('devDependencies','dependencies')) {
            if ($package -and $package.$section -and $package.$section.PSObject.Properties[$name]) { $declared = [string]$package.$section.$name }
        }
        $local = Join-Path $Raiz ('node_modules\' + $name.Replace('/', '\') + '\package.json')
        $installed = $false
        $version = ''
        if (Test-Path -LiteralPath $local -PathType Leaf) {
            Assert-RotaProjeto $Raiz $local
            $module = Read-JsonProjeto $local
            if ($module.name -ne $name -or $module.version -notmatch '^\d+\.\d+\.\d+') { throw "Pacote local inconsistente: $name" }
            $installed = $true
            $version = $module.version
        }
        [PSCustomObject]@{ Nome = $name; Declarada = $declared; Instalada = $installed; Versao = $version }
    }
}

function Get-NavegadoresProjeto {
    param([string]$Raiz)
    $cache = if ($env:PLAYWRIGHT_BROWSERS_PATH -eq '0') { Join-Path $Raiz 'node_modules\playwright-core\.local-browsers' }
        elseif ($env:PLAYWRIGHT_BROWSERS_PATH) { $env:PLAYWRIGHT_BROWSERS_PATH }
        elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'ms-playwright' }
        else { '' }
    $names = @()
    if ($cache -and (Test-Path -LiteralPath $cache -PathType Container)) {
        $names = @(Get-ChildItem -LiteralPath $cache -Directory -ErrorAction Stop | Where-Object Name -match '^(chromium|firefox|webkit)' | Select-Object -ExpandProperty Name)
    }
    [PSCustomObject]@{ Cache = $cache; Diretorios = $names; Nota = 'Presenca de diretorios apenas; nao valida versao compativel nem executa navegadores.' }
}

function Get-ModelosProjeto {
    param([string]$Raiz, [string]$Nome)
    $manifest = Join-Path $Raiz 'package.json'
    if (Test-Path -LiteralPath $manifest) {
        $original = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
        $package = Read-JsonProjeto $manifest
        if ($package.PSObject.Properties['scripts'] -and $package.scripts -isnot [PSCustomObject]) { throw 'scripts deve ser um objeto no package.json.' }
        $changed = $false
        if (-not $package.PSObject.Properties['scripts']) { $package | Add-Member -NotePropertyName scripts -NotePropertyValue ([PSCustomObject]@{}); $changed = $true }
        if ($null -eq $package.scripts) { throw 'scripts nulo: revisar package.json manualmente.' }
        foreach ($entry in @(@('test:e2e','playwright test'), @('typecheck','tsc --noEmit'))) {
            if (-not $package.scripts.PSObject.Properties[$entry[0]]) { $package.scripts | Add-Member -NotePropertyName $entry[0] -NotePropertyValue $entry[1]; $changed = $true }
        }
        $packageText = if ($changed) { ($package | ConvertTo-Json -Depth 64) + "`n" } else { $original }
    }
    else {
        $packageText = ([ordered]@{ name=$Nome; version='0.1.0'; private=$true; scripts=[ordered]@{'test:e2e'='playwright test';typecheck='tsc --noEmit'}; devDependencies=[ordered]@{} } | ConvertTo-Json -Depth 8) + "`n"
    }
    # Nenhum teste, assertion, Page Object ou exercicio resolvido e gerado.
    [ordered]@{
        'package.json' = $packageText
        'README.md' = @'
# Estrutura basica comentada de Playwright + TypeScript

O Canivete prepara o ambiente; voce escreve seus testes.

- tests/: crie seus proprios testes quando compreender o requisito.
- docs/: registre duvidas, plano e observacoes do aprendizado.
- playwright.config.ts: configuracao minima do executor, sem cenarios.
- tsconfig.json: configuracao de tipos; Playwright transpila TS mas nao substitui a verificacao de tipos.

As dependencias sao locais ao projeto. Sua instalacao exige autorizacao separada.
Nao foi instalado navegador automaticamente. Um cache encontrado nao comprova compatibilidade.
Depois de escrever seus testes e preparar dependencias, os scripts test:e2e e typecheck podem ser usados.
Sem testes escritos pelo aluno, o executor pode informar que nao encontrou testes.
Git nao foi inicializado. Nenhum Page Object, assertion ou exercicio pronto foi criado.
'@
        'tests/README.md' = "# Seus testes`n`nEsta pasta comeca sem testes. Leia o requisito, planeje seus cenarios e escreva sua propria implementacao. Nenhum exercicio foi resolvido pelo gerador.`n"
        'docs/README.md' = "# Aprendizado`n`nRegistre aqui seu plano, duvidas e evidencias reais. Nao confunda uma estrutura criada com testes executados.`n"
        'playwright.config.ts' = @'
import { defineConfig } from '@playwright/test';

// Configuracao do ambiente: o aluno criara os testes em tests/.
export default defineConfig({
  testDir: './tests',
  use: { headless: true },
});
'@
        'tsconfig.json' = @'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "noEmit": true,
    "types": ["node"]
  },
  "include": ["playwright.config.ts", "tests/**/*.ts"]
}
'@
        '.gitignore' = "node_modules/`nplaywright-report/`ntest-results/`n.env`n.env.*`n!.env.example`n*.log`n"
    }
}

function Get-PlanoProjeto {
    param([string]$Nome, [string]$Destino)
    $root = Resolve-RaizProjeto $Nome $Destino
    $models = Get-ModelosProjeto $root $Nome
    $items = @()
    foreach ($relative in $models.Keys) {
        $path = Join-Path $root $relative
        Assert-RotaProjeto $root $path
        $before = ''
        $hash = ''
        $action = 'CRIAR'
        if (Test-Path -LiteralPath $path) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Arquivo esperado e uma pasta: $relative" }
            if ((Get-Item -LiteralPath $path).Length -gt 1MB) { throw "Arquivo grande exige revisao manual: $relative" }
            $before = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            $action = if ($before.Replace("`r`n","`n") -ceq $models[$relative].Replace("`r`n","`n")) { 'MANTER' } else { 'REVISAR' }
        }
        $items += [PSCustomObject]@{ Relativo=$relative; Caminho=$path; Acao=$action; Antes=$before; Depois=$models[$relative]; HashAntes=$hash }
    }
    $existing = [PSCustomObject]@{
        PackageJson = [bool](Test-Path -LiteralPath (Join-Path $root 'package.json') -PathType Leaf)
        PackageLock = [bool](Test-Path -LiteralPath (Join-Path $root 'package-lock.json') -PathType Leaf)
        NodeModules = [bool](Test-Path -LiteralPath (Join-Path $root 'node_modules') -PathType Container)
    }
    [PSCustomObject]@{ Raiz=$root; Nome=$Nome; Itens=$items; Existente=$existing; Dependencias=@(Get-DependenciasProjeto $root); Ambiente=(Get-AmbienteProjeto); Navegadores=(Get-NavegadoresProjeto $root) }
}

function Show-PlanoProjeto {
    param($Plano)
    Write-Host "Projeto: $($Plano.Raiz) | Estrutura basica comentada Playwright + TypeScript"
    Write-Host "Existente: package.json=$($Plano.Existente.PackageJson) | package-lock.json=$($Plano.Existente.PackageLock) | node_modules=$($Plano.Existente.NodeModules)"
    foreach ($item in $Plano.Itens) { Write-Host "$($item.Acao): $($item.Relativo)" }
    Write-Host "Node: $($Plano.Ambiente.Node) | versao de arquivo: $($Plano.Ambiente.VersaoNode) | npm: $($Plano.Ambiente.Npm)"
    foreach ($dep in $Plano.Dependencias) { Write-Host "Dependencia: $($dep.Nome) | instalada: $($dep.Instalada) | versao: $($dep.Versao) | declarada: $($dep.Declarada)" }
    Write-Host "Cache navegadores: $($Plano.Navegadores.Diretorios -join ', ') | $($Plano.Navegadores.Nota)"
    Write-Host 'Nao criar testes prontos; nao inicializar Git; nao instalar navegadores. Alteracoes e npm exigem confirmacoes distintas.'
}

function Confirm-AcaoProjeto {
    param([string]$Frase)
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) { throw 'Autorizacao interativa obrigatoria; entrada redirecionada nao permitida.' }
    return (Read-Host "Digite exatamente $Frase para autorizar; outra resposta cancela") -ceq $Frase
}

function Show-DiffProjeto {
    param($Item)
    Write-Host "Diff individual: $($Item.Relativo) | - atual / + proposto"
    $old = @($Item.Antes -split '\r?\n')
    $new = @($Item.Depois -split '\r?\n')
    for ($i=0; $i -lt [Math]::Max($old.Count,$new.Count); $i++) {
        if ($i -lt $old.Count -and $i -lt $new.Count -and $old[$i] -ceq $new[$i]) { continue }
        if ($i -lt $old.Count) { Write-Host "- $($i+1): $($old[$i])" }
        if ($i -lt $new.Count) { Write-Host "+ $($i+1): $($new[$i])" }
    }
}

function New-PastaProjeto {
    param([string]$Raiz, [string]$Caminho)
    Assert-RotaProjeto $Raiz $Caminho
    if (-not (Test-Path -LiteralPath $Caminho -PathType Container)) { [void][IO.Directory]::CreateDirectory($Caminho) }
}

function Write-ArquivoProjeto {
    param([string]$Raiz, $Item)
    Assert-RotaProjeto $Raiz $Item.Caminho
    $encoding = New-Object Text.UTF8Encoding($false)
    if (-not $Item.HashAntes) {
        # CreateNew impede sobrescrever arquivo criado depois do plano.
        $stream = [IO.File]::Open($Item.Caminho,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $bytes=$encoding.GetBytes($Item.Depois); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
        return
    }
    if ((Get-FileHash -LiteralPath $Item.Caminho).Hash -ne $Item.HashAntes) { throw 'Arquivo mudou depois do diff; gere novo plano antes de substituir.' }
    $temp = Join-Path ([IO.Path]::GetDirectoryName($Item.Caminho)) ('.canivete-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temp,$Item.Depois,$encoding)
        [IO.File]::Replace($temp,$Item.Caminho,$null)
    }
    finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Get-ArgumentosNpmProjeto {
    param([object[]]$Ausentes)
    if (-not $Ausentes.Count) { throw 'Nenhuma dependencia ausente; nao executar npm install generico.' }
    $argsNpm = @('install','--save-dev','--ignore-scripts','--no-audit','--no-fund')
    foreach ($dep in $Ausentes) {
        if ($dep.Nome -notin @('@playwright/test','typescript','@types/node')) { throw 'Dependencia nao autorizada.' }
        if ($dep.Declarada -and $dep.Declarada -notmatch '^[~^]?\d+(?:\.\d+){0,2}(?:-[A-Za-z0-9.-]+)?$') { throw 'Versao declarada exige revisao manual; nao alterar automaticamente.' }
        $argsNpm += $(if ($dep.Declarada) { $dep.Nome+'@'+$dep.Declarada } else { $dep.Nome })
    }
    return $argsNpm
}

function Invoke-DependenciasProjeto {
    param($Plano, [object[]]$Ausentes)
    $argsNpm = @(Get-ArgumentosNpmProjeto $Ausentes)
    $pathAntes = $env:PATH
    Push-Location -LiteralPath $Plano.Raiz
    try {
        $env:PATH = (Split-Path -Parent $Plano.Ambiente.Node) + ';' + $env:PATH
        & $Plano.Ambiente.Npm @argsNpm | Out-Host
        return $LASTEXITCODE
    }
    finally { $env:PATH=$pathAntes; Pop-Location }
}

function Invoke-PreparacaoProjeto {
    param($Plano, [bool]$Autorizado = $false)
    if (-not $Autorizado) { return [PSCustomObject]@{Status='SIMULACAO';Codigo=0} }
    $changes = @($Plano.Itens | Where-Object Acao -ne 'MANTER')
    if ($changes.Count -and -not (Confirm-AcaoProjeto "CRIAR ESTRUTURA $($Plano.Nome)")) { return [PSCustomObject]@{Status='CANCELADO';Codigo=0} }
    $preserved = $false
    foreach ($item in $changes) {
        Assert-RotaProjeto $Plano.Raiz $item.Caminho
        if ($item.Acao -eq 'REVISAR') {
            Show-DiffProjeto $item
            if (-not (Confirm-AcaoProjeto "SUBSTITUIR $($item.Relativo)")) { $preserved=$true; continue }
        }
        New-PastaProjeto $Plano.Raiz ([IO.Path]::GetDirectoryName($item.Caminho))
        Write-ArquivoProjeto $Plano.Raiz $item
    }
    if ($preserved) { return [PSCustomObject]@{Status='ARQUIVOS_PRESERVADOS; DEPENDENCIAS_NAO_EXECUTADAS';Codigo=2} }
    $missing = @(Get-DependenciasProjeto $Plano.Raiz | Where-Object { -not $_.Instalada })
    if (-not $missing.Count) { return [PSCustomObject]@{Status='ESTRUTURA_PRONTA; DEPENDENCIAS_JA_PRESENTES';Codigo=0} }
    $Plano.Ambiente = Get-AmbienteProjeto
    if (-not $Plano.Ambiente.PodeInstalar) { return [PSCustomObject]@{Status='ESTRUTURA_PRONTA; NODE_NPM_EXIGEM_REVISAO';Codigo=2} }
    $argsNpm = @(Get-ArgumentosNpmProjeto $missing)
    Write-Host "Etapa separada: npm.cmd $($argsNpm -join ' ')"
    Write-Host 'npm pode modificar package.json, package-lock.json e node_modules. Versoes declaradas serao preservadas; browsers nao serao instalados.'
    if (-not (Confirm-AcaoProjeto "INSTALAR DEPENDENCIAS $($Plano.Nome)")) { return [PSCustomObject]@{Status='ESTRUTURA_PRONTA; DEPENDENCIAS_CANCELADAS';Codigo=0} }
    $missing = @(Get-DependenciasProjeto $Plano.Raiz | Where-Object { -not $_.Instalada })
    if ($missing.Count) {
        $code = Invoke-DependenciasProjeto $Plano $missing
        if ($code -ne 0) { return [PSCustomObject]@{Status="FALHA_NPM ($code); SEM_REPETICAO_OU_LIMPEZA_AUTOMATICA";Codigo=1} }
        if (@(Get-DependenciasProjeto $Plano.Raiz | Where-Object { -not $_.Instalada }).Count) { return [PSCustomObject]@{Status='DEPENDENCIAS_VERIFICACAO_PENDENTE';Codigo=2} }
    }
    [PSCustomObject]@{Status='ESTRUTURA_PRONTA';Codigo=0}
}

try {
    $plano = Get-PlanoProjeto -Nome $Nome -Destino $Destino
    Show-PlanoProjeto $plano
    $resultado = Invoke-PreparacaoProjeto $plano -Autorizado:$Aplicar
    Write-Host "Resultado: $($resultado.Status)"
    if ($resultado.Codigo -ne 0) { exit $resultado.Codigo }
}
catch {
    Write-Error "Preparacao interrompida: $($_.Exception.Message). Nao ha rollback ou exclusao automatica de arquivos do projeto." -ErrorAction Continue
    exit 1
}
