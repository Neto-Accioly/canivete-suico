#requires -Version 5.1
<#
.SYNOPSIS
Gera um plano em simulacao por padrao; aplicacao opcional somente de Node.js LTS ausente.
.EXAMPLE
.\scripts\instalar.ps1 -Todas
.EXAMPLE
.\scripts\instalar.ps1 -Perfil apis-bancos
.EXAMPLE
.\scripts\instalar.ps1 -Ferramentas 'Node.js LTS' -Aplicar
.EXAMPLE
.\scripts\instalar.ps1 -Ferramentas 'Git', 'VS Code'
.EXAMPLE
powershell.exe -File .\scripts\instalar.ps1 -Ferramentas "Git, VS Code"
.NOTES
Com -File, passe a lista em uma unica string separada por virgulas.
Chamadas diretas tambem aceitam arrays de strings.
Use apenas uma selecao: -Perfil, -Todas ou -Ferramentas.
Perfis sao independentes, sem heranca; membros vem do JSON.
Sem parametros, apresenta selecao por numeros. Consulta Registro, PATH e
WinGet em leitura; nao executa os programas detectados para obter versoes.
WinGet list usa ID exato. Upgrade e usado apenas sem selecao de pacote,
para listar; o ID e filtrado em memoria. Nao aceita acordos nem atualiza
programas. O cliente WinGet pode manter logs/cache das consultas.
Detectar uma instalacao nao comprova funcionamento nem versao atualizada.
-Aplicar exige selecao exclusiva de OpenJS.NodeJS.LTS, ausencia confirmada
no escopo consultado e confirmacao digitada em console interativo.
Nao implementa upgrades reais. Nao eleva permissoes nem aceita contratos.
Saida: 0 simulacao/sucesso/cancelamento, 1 bloqueio/falha, 2 verificacao pendente.
#>
[CmdletBinding()]
param(
    [switch]$Todas,

    [ValidateNotNullOrEmpty()]
    [string[]]$Ferramentas,

    [ValidateNotNullOrEmpty()]
    [string]$Perfil,

    [switch]$Aplicar
)

function Read-Catalogo {
    $caminho = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\ferramentas.json'
    if (-not (Test-Path -LiteralPath $caminho -PathType Leaf)) {
        throw "Catalogo nao encontrado: $caminho"
    }
    try {
        $catalogo = Get-Content -LiteralPath $caminho -Encoding UTF8 -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
    }
    catch { throw "Nao foi possivel ler ou interpretar o catalogo JSON: $($_.Exception.Message)" }

    if ($null -eq $catalogo -or $catalogo -isnot [PSCustomObject] -or
        $catalogo.ferramentas -isnot [System.Array] -or $catalogo.ferramentas.Count -eq 0) {
        throw 'O catalogo deve conter um objeto com a lista ferramentas nao vazia.'
    }
    $nomes = @{}
    foreach ($item in $catalogo.ferramentas) {
        if ($null -eq $item -or $item -isnot [PSCustomObject]) {
            throw 'Cada ferramenta deve ser um objeto JSON.'
        }
        foreach ($campo in @('nome', 'categoria', 'winget_id', 'metodo_instalacao', 'obrigatoriedade', 'descricao')) {
            if ($item.PSObject.Properties.Name -notcontains $campo) {
                throw "Ferramenta com campo ausente: $campo"
            }
            $valor = $item.$campo
            if ($campo -eq 'winget_id') {
                if ($null -ne $valor -and ($valor -isnot [string] -or
                    $valor -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$')) {
                    throw "winget_id invalido em '$($item.nome)': use identificador ou null."
                }
            }
            elseif ($valor -isnot [string] -or [string]::IsNullOrWhiteSpace($valor)) {
                throw "Campo '$campo' deve conter texto nao vazio."
            }
        }
        $chave = $item.nome.Trim()
        if ($nomes.ContainsKey($chave)) { throw "Nome duplicado no catalogo: $chave" }
        $nomes[$chave] = $true
    }
    return $catalogo
}

function Select-Perfil {
    param($Catalogo, [string]$Nome)
    if ($Catalogo.perfis -isnot [PSCustomObject]) {
        throw 'Catalogo sem objeto perfis valido.'
    }
    $disponiveis = @($Catalogo.perfis.PSObject.Properties.Name)
    $perfilEncontrado = @($disponiveis | Where-Object { $_ -eq $Nome.Trim() })
    if ($perfilEncontrado.Count -ne 1) {
        throw "Perfil inexistente: '$Nome'. Perfis disponiveis: $($disponiveis -join ', ')."
    }
    foreach ($item in $Catalogo.ferramentas) {
        if ($item.perfis -isnot [System.Array]) {
            throw "Ferramenta '$($item.nome)' sem lista perfis valida."
        }
        foreach ($membro in $item.perfis) {
            if ($membro -isnot [string] -or $disponiveis -notcontains $membro) {
                throw "Referencia de perfil invalida em '$($item.nome)'."
            }
        }
    }
    $itens = @($Catalogo.ferramentas | Where-Object { $_.perfis -contains $perfilEncontrado[0] })
    if ($itens.Count -eq 0) { throw "Perfil '$Nome' nao possui ferramentas no catalogo." }
    return $itens
}

function Show-Catalogo {
    param([object[]]$Itens)
    for ($i = 0; $i -lt $Itens.Count; $i++) {
        $item = $Itens[$i]
        $id = if ($null -eq $item.winget_id) { '(ausente)' } else { $item.winget_id }
        Write-Host ("[{0}] {1} | Categoria: {2} | Metodo: {3} | WinGet: {4}" -f
            ($i + 1), $item.nome, $item.categoria, $item.metodo_instalacao, $id)
    }
}

function Select-Ferramentas {
    param([object[]]$Itens, [string[]]$Nomes, [bool]$SelecionarTodas)
    if ($SelecionarTodas) { return $Itens }
    if ($Nomes.Count -gt 0) {
        $selecionadas = @()
        # -File recebe argumentos nativos, sem preservar arrays do PowerShell.
        # Normalizar cada elemento atende tanto a string CSV quanto ao array direto.
        $nomesNormalizados = @(foreach ($entrada in $Nomes) {
            foreach ($parte in ($entrada -split ',')) {
                $nome = $parte.Trim()
                if ([string]::IsNullOrWhiteSpace($nome)) {
                    throw 'Nome de ferramenta vazio. Informe nomes separados por virgulas, por exemplo: Git, VS Code.'
                }
                $nome
            }
        })
        foreach ($nome in $nomesNormalizados) {
            $encontrada = @($Itens | Where-Object { $_.nome -eq $nome })
            if ($encontrada.Count -ne 1) { throw "Ferramenta nao encontrada no catalogo: '$nome'. Consulte os nomes exibidos acima." }
            if ($selecionadas -notcontains $encontrada[0]) { $selecionadas += $encontrada[0] }
        }
        return $selecionadas
    }
    while ($true) {
        $resposta = Read-Host 'Selecione numeros separados por virgula, T para todas ou Q para sair'
        if ($resposta -eq 'Q') { return }
        if ($resposta -eq 'T') { return $Itens }
        $indices = @()
        $valida = -not [string]::IsNullOrWhiteSpace($resposta)
        foreach ($parte in ($resposta -split ',')) {
            $numero = 0
            if (-not [int]::TryParse($parte.Trim(), [ref]$numero) -or
                $numero -lt 1 -or $numero -gt $Itens.Count) {
                $valida = $false
                break
            }
            if ($indices -notcontains $numero) { $indices += $numero }
        }
        if ($valida) {
            foreach ($indice in $indices) { $Itens[$indice - 1] }
            return
        }
        Write-Host 'Selecao invalida. Use os numeros exibidos no catalogo.' -ForegroundColor Yellow
    }
}

function Get-RegistrosInstalacao {
    $registros = @()
    $falhas = @()
    # Consulta explicita das duas visoes, inclusive quando o PowerShell e de 32 bits.
    foreach ($hive in @([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryHive]::CurrentUser)) {
        foreach ($visao in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
            $base = $null
            $chave = $null
            try {
                $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $visao)
                $chave = $base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', $false)
                if ($null -eq $chave) { continue }
                foreach ($nomeChave in $chave.GetSubKeyNames()) {
                    $subchave = $null
                    try {
                        $subchave = $chave.OpenSubKey($nomeChave, $false)
                        if ($null -eq $subchave) { throw 'Registro indisponivel durante a consulta.' }
                        $displayName = $subchave.GetValue('DisplayName')
                        if ($displayName -is [string] -and $displayName.Trim()) {
                            $registros += [PSCustomObject]@{
                                Nome = $displayName
                                Versao = $subchave.GetValue('DisplayVersion')
                                Caminho = $subchave.GetValue('InstallLocation')
                                Editor = $subchave.GetValue('Publisher')
                                Fonte = "$hive/$visao/Uninstall/$nomeChave"
                            }
                        }
                    }
                    catch { $falhas += "$hive/$visao/${nomeChave}: $($_.Exception.Message)" }
                    finally { if ($null -ne $subchave) { $subchave.Dispose() } }
                }
            }
            catch { $falhas += "$hive/${visao}: $($_.Exception.Message)" }
            finally {
                if ($null -ne $chave) { $chave.Dispose() }
                if ($null -ne $base) { $base.Dispose() }
            }
        }
    }
    [PSCustomObject]@{ Registros = $registros; Falhas = $falhas }
}

function Get-RegraDeteccao {
    param($Item)
    # Regras de evidencia, nao um segundo catalogo de instalacao.
    # Variantes (JDK LTS, Node LTS, Community) exigem validacao especifica.
    switch ($Item.nome) {
        'Git' { return @{ Nome = '^Git(?: version)?(?:\s+\d[\w.()-]*)?$'; Editor = '^The Git Development Community$'; Comandos = @('git.exe'); Produto = '^Git$' } }
        'VS Code' { return @{ Nome = '^Microsoft Visual Studio Code(?: \(User\))?$'; Editor = '^Microsoft Corporation$'; Comandos = @('code.cmd'); Produto = '^Visual Studio Code$' } }
        'Node.js LTS' { return @{ Nome = '^Node\.js$'; Comandos = @('node.exe'); Variante = $true } }
        'Java JDK LTS' { return @{ Nome = '^(?:Eclipse Temurin|Temurin).*(?:JDK|Development Kit).*$'; Comandos = @('javac.exe'); Variante = $true } }
        'Maven' { return @{ Nome = '^Apache Maven(?:\s+\d[\w.-]*)?$'; Comandos = @('mvn.cmd') } }
        'IntelliJ IDEA' { return @{ Nome = '^IntelliJ IDEA Community Edition(?:\s+\d[\w.-]*)?$' } }
        'MongoDB Community Server' { return @{ Nome = '^MongoDB \d[\w. -]*\(64 bit\)$'; Variante = $true } }
        'MongoDB Shell (mongosh)' { return @{ Nome = '^(?:MongoDB Shell|mongosh)(?:\s+\d[\w.-]*)?$'; Comandos = @('mongosh.exe') } }
        'DBeaver Community' { return @{ Nome = '^DBeaver Community(?:\s+\d[\w.-]*)?$' } }
        'GitHub CLI' { return @{ Nome = '^GitHub CLI(?:\s+\d[\w.-]*)?$'; Comandos = @('gh.exe'); Produto = '^GitHub CLI$' } }
        'k6' { return @{ Nome = '^k6(?:\s+v?\d[\w.-]*)?$'; Comandos = @('k6.exe') } }
        'SQLite' { return @{ Nome = '^SQLite(?:\s+\d[\w.-]*)?$'; Comandos = @('sqlite3.exe') } }
        default { return @{ Nome = '^' + [regex]::Escape($Item.nome.Trim()) + '(?:\s+\d[\w.-]*)?$' } }
    }
}

function New-Evidencia {
    param([string]$Status, [string]$Versao, [string]$Caminho, [string]$Fonte, [string]$Detalhe)
    if ([string]::IsNullOrWhiteSpace($Versao)) { $Versao = 'nao obtida' }
    if ([string]::IsNullOrWhiteSpace($Caminho)) { $Caminho = 'nao obtido' }
    [PSCustomObject]@{ Status = $Status; Versao = $Versao; Caminho = $Caminho; Fonte = $Fonte; Detalhe = $Detalhe }
}

function Test-WindowsApps {
    param([string]$Caminho)
    return $Caminho -match '(?i)[\\/]WindowsApps[\\/]'
}

function Get-EvidenciasRegistro {
    param($Item, $Consulta, $Regra)
    foreach ($registro in $Consulta.Registros) {
        if ($registro.Nome -notmatch $Regra.Nome) { continue }
        $status = 'CONFIRMADA'
        $detalhe = "Registro de instalacao: $($registro.Nome). Nao comprova funcionamento ou identidade WinGet."
        if (($Regra.Editor -and $registro.Editor -notmatch $Regra.Editor) -or $Regra.Variante) {
            $status = 'INCONCLUSIVA'
            $detalhe = 'Nome compativel; editor ou variante exigem confirmacao (LTS, JDK ou edicao).'
        }
        if ($registro.Caminho -and (Test-WindowsApps $registro.Caminho)) {
            $status = 'INCONCLUSIVA'
            $detalhe = 'Caminho WindowsApps nao e aceito como comprovacao de instalacao.'
        }
        try {
            if ([string]::IsNullOrWhiteSpace($registro.Caminho) -or
                -not (Test-Path -LiteralPath $registro.Caminho -ErrorAction Stop)) {
                $status = 'INCONCLUSIVA'
                $detalhe = 'Registro localizado, mas sem caminho existente para corroborar; pode ser registro residual.'
            }
        }
        catch {
            $status = 'INCONCLUSIVA'
            $detalhe = "Nao foi possivel conferir o caminho do Registro: $($_.Exception.Message)"
        }
        New-Evidencia $status $registro.Versao $registro.Caminho $registro.Fonte $detalhe
    }
}

function Get-EvidenciasArquivos {
    param($Item, $Regra)
    $candidatos = @()
    foreach ($comando in $Regra.Comandos) {
        try {
            foreach ($cmd in @(Get-Command -Name $comando -CommandType Application -All -ErrorAction SilentlyContinue)) {
                $candidatos += [PSCustomObject]@{ Caminho = $cmd.Source; Fonte = "PATH: $comando" }
            }
        }
        catch { New-Evidencia 'INCONCLUSIVA' '' '' 'PATH' $_.Exception.Message }
    }
    if ($Item.nome -eq 'VS Code' -and $env:LOCALAPPDATA) {
        $candidatos += [PSCustomObject]@{
            Caminho = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'
            Fonte = 'Perfil do usuario: LOCALAPPDATA'
        }
    }
    foreach ($candidato in $candidatos) {
        $caminho = $candidato.Caminho
        if (Test-WindowsApps $caminho) {
            New-Evidencia 'INCONCLUSIVA' '' $caminho $candidato.Fonte 'Alias/caminho WindowsApps ignorado; nao confirma instalacao.'
            continue
        }
        # code.cmd e um wrapper; validar o executavel adjacente, sem executa-lo.
        if ($Item.nome -eq 'VS Code' -and [IO.Path]::GetFileName($caminho) -eq 'code.cmd') {
            $caminho = Join-Path (Split-Path -Parent (Split-Path -Parent $caminho)) 'Code.exe'
        }
        try {
            if (-not (Test-Path -LiteralPath $caminho -PathType Leaf -ErrorAction Stop)) { continue }
            $arquivo = Get-Item -LiteralPath $caminho -ErrorAction Stop
            if (($arquivo.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                New-Evidencia 'INCONCLUSIVA' '' $caminho $candidato.Fonte 'Link/reparse point exige verificacao do destino.'
                continue
            }
            $info = $arquivo.VersionInfo
            $status = 'INCONCLUSIVA'
            $detalhe = 'Arquivo localizado; nome no PATH isoladamente nao comprova produto, variante ou pacote WinGet.'
            if ($Regra.Produto -and $info.ProductName -match $Regra.Produto -and -not $Regra.Variante) {
                $status = 'CONFIRMADA'
                $detalhe = "Executavel com metadados do produto: $($info.ProductName). Nao comprova funcionamento ou identidade WinGet."
            }
            New-Evidencia $status $info.ProductVersion $arquivo.FullName $candidato.Fonte $detalhe
        }
        catch { New-Evidencia 'INCONCLUSIVA' '' $caminho $candidato.Fonte $_.Exception.Message }
    }
}

function Invoke-ConsultaWinGet {
    param($Caminho, [ValidateSet('Listar', 'Atualizacoes')][string]$Operacao, [string]$Id)
    # Ponto de consultas nativas. Nunca passar ID/query/all a upgrade:
    # upgrade --id executaria uma atualizacao, mesmo com --disable-interactivity.
    try {
        if ($Operacao -eq 'Listar') {
            if ($Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'ID WinGet invalido.' }
            $saida = @(& $Caminho list --id $Id --exact --source winget --disable-interactivity 2>&1)
        }
        else {
            $saida = @(& $Caminho upgrade --source winget --disable-interactivity 2>&1)
        }
        $codigo = $LASTEXITCODE
        [PSCustomObject]@{ Codigo = $codigo; Linhas = @($saida | ForEach-Object { [string]$_ }); Erro = '' }
    }
    catch {
        [PSCustomObject]@{ Codigo = $null; Linhas = @(); Erro = $_.Exception.Message }
    }
}

function Get-ConsultaWinGet {
    $cmd = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $cmd) { return @{ Disponivel = $false; Motivo = 'WinGet nao localizado no PATH.' } }
    # Uma unica listagem de atualizacoes por execucao. Nunca tentar contornar
    # sandbox, elevar privilegios ou alterar politicas dentro deste script.
    $atualizacoes = Invoke-ConsultaWinGet $cmd.Source 'Atualizacoes'
    return @{
        Disponivel = $true
        Caminho = $cmd.Source
        Atualizacoes = $atualizacoes
        Motivo = ''
    }
}

function Read-LinhasWinGet {
    param([string[]]$Linhas, [string]$Id, [switch]$Atualizacoes)
    # Nao depender da lingua do cabecalho. A tabela pode usar um unico espaco
    # entre colunas; exigir o ID inteiro e tokens de versao, nunca substring.
    $versao = '(?:[vV]?\d[^\s]*|Unknown|Desconhecid[ao]|<[^>]+>)'
    $padrao = '^\s*.+?\s+' + [regex]::Escape($Id) + '\s+(?<instalada>' + $versao + ')'
    if ($Atualizacoes) { $padrao += '\s+(?<disponivel>[vV]?\d[^\s]*)' }
    $padrao += '(?:\s+winget)?\s*$'
    foreach ($linha in $Linhas) {
        if ($linha -match $padrao) {
            $disponivel = if ($Atualizacoes) { $Matches.disponivel } else { '' }
            [PSCustomObject]@{ Instalada = $Matches.instalada; Disponivel = $disponivel; Linha = $linha }
        }
    }
}

function Get-EstadoWinGet {
    param($Item, $WinGet)
    $resultado = [PSCustomObject]@{
        Instalacao = 'INCONCLUSIVA'; Atualizacao = 'INCONCLUSIVA'
        Instalada = 'nao obtida'; Disponivel = 'nao obtida'; Evidencia = ''
    }
    if ($Item.metodo_instalacao -ne 'winget' -or $null -eq $Item.winget_id) {
        $resultado.Evidencia = 'Metodo fora do WinGet ou ID ausente; requer analise propria.'
        return $resultado
    }
    if (-not $WinGet.Disponivel) {
        $resultado.Evidencia = $WinGet.Motivo
        return $resultado
    }
    $lista = Invoke-ConsultaWinGet $WinGet.Caminho 'Listar' $Item.winget_id
    $resultado.Evidencia = "winget list --id $($Item.winget_id) --exact --source winget; codigo=$($lista.Codigo)."
    if ($lista.Erro) {
        $resultado.Evidencia += " $($lista.Erro) Se bloqueado pela sandbox, solicitar autorizacao pontual de leitura ao Codex; nao executar como administrador automaticamente."
        return $resultado
    }
    if ($lista.Codigo -eq -1978335212) {
        $resultado.Instalacao = 'NAO LOCALIZADA'
        $resultado.Atualizacao = 'NAO APLICAVEL'
        return $resultado
    }
    if ($lista.Codigo -ne 0) { return $resultado }
    $linhas = @(Read-LinhasWinGet $lista.Linhas $Item.winget_id)
    # list tambem pode trazer coluna Available. Interpretar explicitamente.
    if ($linhas.Count -eq 0) { $linhas = @(Read-LinhasWinGet $lista.Linhas $Item.winget_id -Atualizacoes) }
    if ($linhas.Count -ne 1 -or $linhas[0].Instalada -notmatch '^[vV]?\d') {
        $resultado.Evidencia += ' Linha ambigua, versao desconhecida ou formato nao reconhecido.'
        return $resultado
    }
    $resultado.Instalacao = 'CONFIRMADA'
    $resultado.Instalada = $linhas[0].Instalada
    $resultado.Evidencia += " Linha: $($linhas[0].Linha)"
    $upgrades = $WinGet.Atualizacoes
    $resultado.Evidencia += " Consulta upgrade sem selecao, filtro exato em memoria; codigo=$($upgrades.Codigo)."
    if ($upgrades.Erro -or $upgrades.Codigo -ne 0) {
        $resultado.Evidencia += " $($upgrades.Erro) Consulta de atualizacoes inconclusiva."
        return $resultado
    }
    # Exigir tabela completa, sem aviso de falha parcial. Cabecalhos nao sao
    # evidencia de ausencia de atualizacoes quando a resposta e desconhecida.
    if (($upgrades.Linhas -join "`n") -notmatch '(?m)^\s*-{5,}\s*$' -or
        ($upgrades.Linhas -join "`n") -match '(?i)failed|failure|error|falha|erro|agreement|acordo|truncat|warning|aviso|pinned|fixad|unknown|desconhecid') {
        $resultado.Evidencia += ' Listagem ausente, parcial, com avisos ou formato nao reconhecido.'
        return $resultado
    }
    $updates = @(Read-LinhasWinGet $upgrades.Linhas $Item.winget_id -Atualizacoes)
    if ($updates.Count -gt 1) { return $resultado }
    if ($updates.Count -eq 1) {
        if ($updates[0].Instalada -ne $resultado.Instalada) {
            $resultado.Evidencia += ' Versoes instaladas divergentes entre consultas.'
            return $resultado
        }
        $resultado.Atualizacao = 'DISPONIVEL'
        $resultado.Disponivel = $updates[0].Disponivel
        $resultado.Evidencia += " Linha: $($updates[0].Linha)"
    }
    else {
        # Se o ID aparece em linha nao interpretavel, nao inferir MANTER.
        if (($upgrades.Linhas -join "`n") -match ('(?<![\w.])' + [regex]::Escape($Item.winget_id) + '(?![\w.])')) { return $resultado }
        if ($linhas[0].Disponivel) { return $resultado }
        $resultado.Atualizacao = 'SEM ATUALIZACAO LISTADA'
        $resultado.Disponivel = 'nenhuma listada na fonte winget'
    }
    return $resultado
}

function Get-EvidenciaWinGet {
    param($Item, $WinGet)
    if ($null -eq $Item.winget_id -or $Item.metodo_instalacao -ne 'winget') { return }
    $estado = $WinGet.Estado
    New-Evidencia $estado.Instalacao $estado.Instalada '' 'WinGet list / upgrade (consulta)' $estado.Evidencia
}

function Get-AcaoPlano {
    param($Item, $Deteccao, $Estado)
    $acao = 'REVISAR'
    $motivo = 'Consulta inconclusiva, metodo nao WinGet ou evidencia insuficiente.'
    if ($Item.metodo_instalacao -eq 'winget' -and $Item.winget_id) {
        $incertas = @($Deteccao.Evidencias | Where-Object Status -eq 'INCONCLUSIVA').Count
        if ($Estado.Instalacao -eq 'NAO LOCALIZADA' -and $Deteccao.Status -eq 'NAO LOCALIZADA' -and -not $incertas) {
            $acao = 'INSTALAR'; $motivo = 'ID nao localizado no inventario nem nas evidencias locais consultadas; ausencia global nao garantida.'
        }
        elseif ($Estado.Instalacao -eq 'CONFIRMADA' -and -not $incertas) {
            if ($Estado.Atualizacao -eq 'DISPONIVEL') {
                if ($Item.nome -in @('Java JDK LTS','MySQL Server','MongoDB Community Server') -or
                    $Item.winget_id -match '^(?:EclipseAdoptium\..*\.JDK|Oracle\.JDK(?:\.|$)|Microsoft\.OpenJDK|Oracle\.MySQL$|MongoDB\.Server$)') {
                    $motivo = 'Atualizacao de Java/servidor exige revisao manual de compatibilidade, dados e servicos.'
                }
                else { $acao = 'ATUALIZAR'; $motivo = 'Atualizacao listada para o ID exato; apenas recomendacao simulada.' }
            }
            elseif ($Estado.Atualizacao -eq 'SEM ATUALIZACAO LISTADA') {
                $acao = 'MANTER'; $motivo = 'Instalacao confirmada; nenhuma atualizacao listada nesta consulta/fonte. Nao garante versao mais recente em outras fontes.'
            }
        }
    }
    [PSCustomObject]@{ Acao = $acao; Motivo = $motivo }
}

function Get-Deteccao {
    param($Item, $Consulta, $WinGet)
    if ($Item.tipo -in @('biblioteca_projeto', 'modulo_powershell') -or
        $Item.metodo_instalacao -in @('dependencia_npm', 'dependencia_maven', 'modulo_powershell', 'configuracao_projeto')) {
        return [PSCustomObject]@{
            Status = 'INCONCLUSIVA'
            Evidencias = @(New-Evidencia 'INCONCLUSIVA' '' '' 'Escopo da consulta' 'Dependencia/modulo exige analise propria do projeto ou sessao; nao procurar como aplicativo Windows.')
        }
    }
    $regra = Get-RegraDeteccao $Item
    $evidencias = @(
        Get-EvidenciasRegistro $Item $Consulta $regra
        Get-EvidenciasArquivos $Item $regra
        Get-EvidenciaWinGet $Item $WinGet
    )
    foreach ($falha in $Consulta.Falhas) {
        $evidencias += New-Evidencia 'INCONCLUSIVA' '' '' 'Registro' $falha
    }
    $status = 'NAO LOCALIZADA'
    if (@($evidencias | Where-Object Status -eq 'CONFIRMADA').Count) { $status = 'CONFIRMADA' }
    elseif (@($evidencias | Where-Object Status -eq 'INCONCLUSIVA').Count) { $status = 'INCONCLUSIVA' }
    elseif ($evidencias.Count -eq 0) {
        $evidencias = @(New-Evidencia 'NAO LOCALIZADA' '' '' 'Registro/PATH consultados' 'Nenhuma evidencia no escopo pesquisado; nao comprova ausencia em todo o computador.')
    }
    [PSCustomObject]@{ Status = $status; Evidencias = $evidencias }
}

function Show-Plano {
    param([object[]]$Itens, $Consulta, $WinGet, [switch]$PrepararAplicacao)
    $modo = if ($PrepararAplicacao) { 'APLICACAO SOLICITADA; AGUARDANDO VALIDACAO E CONFIRMACAO' } else { 'SOMENTE SIMULACAO' }
    Write-Host "`nPLANO DE INSTALACAO - $modo" -ForegroundColor Cyan
    Write-Host 'Confirmacao por evidencia local ou inventario WinGet; nao valida funcionamento nem atualizacao.'
    foreach ($item in $Itens) {
        $estado = Get-EstadoWinGet $item $WinGet
        $WinGet.Estado = $estado
        $deteccao = Get-Deteccao -Item $item -Consulta $Consulta -WinGet $WinGet
        $plano = Get-AcaoPlano $item $deteccao $estado
        $id = if ($null -eq $item.winget_id) { '(ausente)' } else { $item.winget_id }
        Write-Host "`nFerramenta: $($item.nome)"
        Write-Host "Categoria: $($item.categoria) | Metodo: $($item.metodo_instalacao) | WinGet: $id"
        Write-Host "Deteccao: $($deteccao.Status)"
        foreach ($evidencia in $deteccao.Evidencias) {
            Write-Host "Evidencia [$($evidencia.Status)]: $($evidencia.Detalhe)"
            Write-Host "Versao: $($evidencia.Versao) | Caminho: $($evidencia.Caminho) | Fonte: $($evidencia.Fonte)"
        }
        Write-Host "Versao instalada (ID exato): $($estado.Instalada) | Disponivel: $($estado.Disponivel)"
        Write-Host "Atualizacao: $($estado.Atualizacao)"
        Write-Host "Plano: $($plano.Acao) - $($plano.Motivo)"
        Write-Host "Fonte da decisao: $($estado.Evidencia)"
        if ($PrepararAplicacao) {
            [PSCustomObject]@{ Item = $item; Estado = $estado; Deteccao = $deteccao; Plano = $plano }
        }
    }
    foreach ($falha in $Consulta.Falhas) { Write-Warning "Falha na deteccao: $falha" }
    if ($PrepararAplicacao) {
        Write-Host "`nPlanejamento concluido: $($Itens.Count) ferramenta(s). Nenhuma instalacao executada ate aqui."
    }
    else { Write-Host "`nSimulacao concluida: $($Itens.Count) ferramenta(s). Nenhuma instalacao executada." }
}

function Assert-SelecaoAplicacao {
    param([object[]]$Itens)
    if ($Itens.Count -ne 1 -or $Itens[0].nome -cne 'Node.js LTS' -or
        $Itens[0].winget_id -cne 'OpenJS.NodeJS.LTS' -or $Itens[0].metodo_instalacao -ne 'winget') {
        throw '-Aplicar bloqueado integralmente: selecione somente Node.js LTS (OpenJS.NodeJS.LTS). Nenhuma instalacao parcial e permitida.'
    }
}

function Get-PathVerificacao {
    # Leitura dos valores persistidos; nunca escrever PATH de usuario/maquina.
    $partes = @(
        [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        [Environment]::GetEnvironmentVariable('PATH', 'User')
        $env:PATH
    )
    return (($partes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ';')
}

function Get-IndiciosNode {
    # Procurar tambem fora do PATH antigo. Qualquer indicio bloqueia instalar:
    # outra linha Node, gerenciadores de versao e aliases nao provam ausencia.
    $pathAnterior = $env:PATH
    try {
        $env:PATH = Get-PathVerificacao
        foreach ($nome in @('node.exe', 'npm.cmd')) {
            try {
                foreach ($cmd in @(Get-Command $nome -CommandType Application -All -ErrorAction Stop)) {
                    New-Evidencia 'INCONCLUSIVA' '' $cmd.Source 'PATH atual/persistido' 'Comando Node/npm existente; ausencia nao comprovada (inclusive alias WindowsApps).'
                }
            }
            catch [System.Management.Automation.CommandNotFoundException] { }
            catch { New-Evidencia 'INCONCLUSIVA' '' '' "PATH: $nome" $_.Exception.Message }
        }
        $pastas = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
        $candidatos = @($pastas | ForEach-Object { Join-Path $_ 'nodejs\node.exe' })
        if ($env:LOCALAPPDATA) { $candidatos += Join-Path $env:LOCALAPPDATA 'Programs\nodejs\node.exe' }
        foreach ($caminho in $candidatos) {
            if (Test-Path -LiteralPath $caminho -ErrorAction Stop) {
                New-Evidencia 'INCONCLUSIVA' '' $caminho 'Diretorio padrao Node.js' 'Arquivo Node existente; nao instalar sobre uma possivel instalacao.'
            }
        }
    }
    catch { New-Evidencia 'INCONCLUSIVA' '' '' 'Busca complementar Node.js' $_.Exception.Message }
    finally { $env:PATH = $pathAnterior }
}

function Get-PlanoNodeAtual {
    param($Item, $WinGet)
    $consulta = Get-RegistrosInstalacao
    $estado = Get-EstadoWinGet $Item $WinGet
    $WinGet.Estado = $estado
    $deteccao = Get-Deteccao $Item $consulta $WinGet
    $extras = @(Get-IndiciosNode)
    if ($extras.Count) {
        $deteccao.Evidencias = @($deteccao.Evidencias) + $extras
        if ($deteccao.Status -ne 'CONFIRMADA') { $deteccao.Status = 'INCONCLUSIVA' }
    }
    [PSCustomObject]@{
        Item = $Item; Estado = $estado; Deteccao = $deteccao
        Plano = (Get-AcaoPlano $Item $deteccao $estado)
    }
}

function Assert-AusenciaNode {
    param($RegistroPlano)
    Assert-SelecaoAplicacao @($RegistroPlano.Item)
    if ($RegistroPlano.Plano.Acao -ne 'INSTALAR' -or
        $RegistroPlano.Estado.Instalacao -ne 'NAO LOCALIZADA' -or
        $RegistroPlano.Deteccao.Status -ne 'NAO LOCALIZADA' -or
        @($RegistroPlano.Deteccao.Evidencias | Where-Object Status -ne 'NAO LOCALIZADA').Count) {
        throw '-Aplicar bloqueado: Node.js deve estar comprovadamente ausente no escopo consultado. Instalacao existente, atualizacao ou deteccao inconclusiva exige REVISAR.'
    }
}

function Confirm-InstalacaoNode {
    # Sem -Confirm:$false, variavel de ambiente ou resposta automatica.
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        throw 'Confirmacao interativa obrigatoria: execute em terminal com entrada interativa, sem pipe ou redirecionamento.'
    }
    $resposta = Read-Host 'Para instalar somente Node.js LTS, digite exatamente INSTALAR OpenJS.NodeJS.LTS (qualquer outra resposta cancela)'
    return $resposta -ceq 'INSTALAR OpenJS.NodeJS.LTS'
}

function Invoke-InstalacaoNode {
    param([string]$CaminhoWinGet)
    # Unico comando de instalacao. ID/fonte/opcoes fixos, sem argumentos do JSON.
    # Nao chamar esta funcao em testes: substituir em memoria por um mock.
    try {
        & $CaminhoWinGet install --id OpenJS.NodeJS.LTS --exact --source winget --interactive --no-upgrade --skip-dependencies | Out-Host
        $codigo = $LASTEXITCODE
        [PSCustomObject]@{ Codigo = $codigo; Erro = '' }
    }
    catch { [PSCustomObject]@{ Codigo = $null; Erro = $_.Exception.Message } }
}

function Invoke-VersaoNode {
    param([ValidateSet('node.exe', 'npm.cmd')][string]$Nome, [string]$PastaNode)
    try {
        $caminho = Join-Path $PastaNode $Nome
        if ((Test-WindowsApps $caminho) -or -not (Test-Path -LiteralPath $caminho -PathType Leaf -ErrorAction Stop)) {
            throw "Arquivo real nao localizado: $caminho"
        }
        $arquivo = Get-Item -LiteralPath $caminho -ErrorAction Stop
        if (($arquivo.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Link/reparse point nao validado.' }
        $saida = @(& $arquivo.FullName --version 2>&1)
        $codigo = $LASTEXITCODE
        $versao = ($saida -join "`n").Trim()
        $padrao = if ($Nome -eq 'node.exe') { '^v\d+\.\d+\.\d+$' } else { '^\d+\.\d+\.\d+(?:-[\w.-]+)?$' }
        [PSCustomObject]@{ Valida = ($codigo -eq 0 -and $versao -match $padrao); Versao = $versao; Caminho = $caminho; Codigo = $codigo; Erro = '' }
    }
    catch { [PSCustomObject]@{ Valida = $false; Versao = ''; Caminho = ''; Codigo = $null; Erro = $_.Exception.Message } }
}

function Get-VerificacaoNode {
    param([string]$CaminhoWinGet)
    $pathAnterior = $env:PATH
    try {
        $env:PATH = Get-PathVerificacao
        $node = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $pasta = if ($node) { Split-Path -Parent $node.Source } else { '' }
        # npm.cmd evita npm.ps1 e nao exige mudar a politica de execucao.
        $nodeVersao = Invoke-VersaoNode 'node.exe' $pasta
        $npmVersao = Invoke-VersaoNode 'npm.cmd' $pasta
        $lista = Invoke-ConsultaWinGet $CaminhoWinGet 'Listar' 'OpenJS.NodeJS.LTS'
        $linhas = @(Read-LinhasWinGet $lista.Linhas 'OpenJS.NodeJS.LTS')
        if (-not $linhas.Count) { $linhas = @(Read-LinhasWinGet $lista.Linhas 'OpenJS.NodeJS.LTS' -Atualizacoes) }
        $inventarioValido = $lista.Codigo -eq 0 -and -not $lista.Erro -and $linhas.Count -eq 1
        $concluida = $inventarioValido -and $nodeVersao.Valida -and $npmVersao.Valida -and
            $linhas[0].Instalada -eq ($nodeVersao.Versao -replace '^v', '')
        [PSCustomObject]@{
            Concluida = $concluida; Node = $nodeVersao; Npm = $npmVersao
            WinGet = $lista; Linhas = $linhas
        }
    }
    finally { $env:PATH = $pathAnterior }
}

function Invoke-AplicacaoNode {
    param([object[]]$Itens, [object[]]$Planos, $WinGet)
    Assert-SelecaoAplicacao $Itens
    if ($Planos.Count -ne 1) { throw 'Plano de aplicacao deve conter exatamente uma ferramenta.' }
    Assert-AusenciaNode $Planos[0]
    if (-not $WinGet.Disponivel -or [string]::IsNullOrWhiteSpace($WinGet.Caminho)) { throw 'WinGet indisponivel; aplicacao bloqueada.' }
    $atual = Get-PlanoNodeAtual $Itens[0] $WinGet
    Write-Host "`nPlano revalidado: $($atual.Plano.Acao) | ID: OpenJS.NodeJS.LTS | Fonte: winget"
    Write-Host "Evidencia: $($atual.Estado.Evidencia)"
    foreach ($ev in $atual.Deteccao.Evidencias) { Write-Host "Fonte: $($ev.Fonte) | $($ev.Detalhe) | Caminho: $($ev.Caminho)" }
    Assert-AusenciaNode $atual
    Write-Host 'Comando previsto: winget install --id OpenJS.NodeJS.LTS --exact --source winget --interactive --no-upgrade --skip-dependencies'
    Write-Host 'Contratos serao apresentados pelo WinGet/instalador, sem aceite automatico. Upgrades reais nao sao permitidos.'
    if (-not (Confirm-InstalacaoNode)) {
        return [PSCustomObject]@{ Status = 'CANCELADO'; CodigoSaida = 0; Detalhe = 'Confirmacao nao fornecida; nenhuma instalacao executada.' }
    }
    # Fechar a janela entre a confirmacao e a execucao. --no-upgrade tambem
    # impede que uma instalacao concorrente seja atualizada pelo WinGet.
    $ultima = Get-PlanoNodeAtual $Itens[0] $WinGet
    Assert-AusenciaNode $ultima
    $execucao = Invoke-InstalacaoNode $WinGet.Caminho
    Write-Host "Codigo de saida da instalacao: $($execucao.Codigo) | Erro: $($execucao.Erro)"
    try { $verificacao = Get-VerificacaoNode $WinGet.Caminho }
    catch {
        $verificacao = $null
        Write-Warning "Verificacao nao concluida: $($_.Exception.Message)"
    }
    if ($verificacao) {
        Write-Host "node --version: $($verificacao.Node.Versao) | codigo: $($verificacao.Node.Codigo) | caminho: $($verificacao.Node.Caminho) | erro: $($verificacao.Node.Erro)"
        Write-Host "npm --version: $($verificacao.Npm.Versao) | codigo: $($verificacao.Npm.Codigo) | caminho: $($verificacao.Npm.Caminho) | erro: $($verificacao.Npm.Erro)"
        Write-Host "winget list --id OpenJS.NodeJS.LTS --exact: codigo $($verificacao.WinGet.Codigo) | erro: $($verificacao.WinGet.Erro)"
        foreach ($linha in $verificacao.Linhas) { Write-Host "Inventario: $($linha.Linha)" }
    }
    if ($execucao.Erro -or $null -eq $execucao.Codigo -or $execucao.Codigo -notin @(0, 3010, 1641)) {
        return [PSCustomObject]@{ Status = 'FALHA'; CodigoSaida = 1; Detalhe = 'Instalador falhou ou foi cancelado. Pode haver alteracoes parciais; nao ha repeticao ou remocao automatica.' }
    }
    if ($execucao.Codigo -eq 0 -and $verificacao -and $verificacao.Concluida) {
        return [PSCustomObject]@{ Status = 'SUCESSO'; CodigoSaida = 0; Detalhe = 'Node e npm responderam com versao; Node corresponde ao ID exato no inventario WinGet.' }
    }
    [PSCustomObject]@{ Status = 'VERIFICACAO PENDENTE'; CodigoSaida = 2; Detalhe = 'Instalador retornou sucesso ou reinicio necessario, mas a validacao nao esta completa. Abra novo terminal e confira Node, npm e inventario. Nao reinstalar automaticamente.' }
}

try {
    # Validacao explicita permite mensagem em portugues com as opcoes conflitantes.
    $modos = @('Todas', 'Ferramentas', 'Perfil' | Where-Object { $PSBoundParameters.ContainsKey($_) })
    if ($modos.Count -gt 1) {
        throw "Parametros incompativeis: -$($modos -join ', -'). Use apenas um entre -Perfil, -Todas e -Ferramentas."
    }
    $catalogo = Read-Catalogo
    $modoExecucao = if ($Aplicar) { 'aplicacao restrita solicitada; exige confirmacao' } else { 'simulacao' }
    Write-Host "NETO-LAB - Catalogo de ferramentas ($modoExecucao)" -ForegroundColor Cyan
    if ($PSBoundParameters.ContainsKey('Perfil')) {
        $selecionadas = @(Select-Perfil -Catalogo $catalogo -Nome $Perfil)
        $perfilExibido = $Perfil.Trim().ToLowerInvariant()
        Show-Catalogo -Itens $selecionadas
    }
    else {
        Show-Catalogo -Itens $catalogo.ferramentas
        $selecionadas = @(Select-Ferramentas -Itens $catalogo.ferramentas -Nomes $Ferramentas -SelecionarTodas $Todas.IsPresent)
        $perfilExibido = 'nenhum (selecao por nomes, todas ou interativa)'
    }
    if ($selecionadas.Count -eq 0) { Write-Host 'Simulacao cancelada, sem alteracoes.'; return }
    Write-Host "Perfil: $perfilExibido | Ferramentas selecionadas: $($selecionadas.Count)"
    if ($Aplicar) { Assert-SelecaoAplicacao $selecionadas }
    $consulta = Get-RegistrosInstalacao
    $winget = @{ Disponivel = $false; Motivo = 'Nenhuma ferramenta selecionada usa WinGet.' }
    if (@($selecionadas | Where-Object { $_.metodo_instalacao -eq 'winget' -and $_.winget_id }).Count) {
        $winget = Get-ConsultaWinGet
    }
    $planos = @(Show-Plano -Itens $selecionadas -Consulta $consulta -WinGet $winget -PrepararAplicacao:$Aplicar)
    if ($Aplicar) {
        $resultado = Invoke-AplicacaoNode -Itens $selecionadas -Planos $planos -WinGet $winget
        Write-Host "Resultado: $($resultado.Status) - $($resultado.Detalhe)"
        if ($resultado.CodigoSaida -ne 0) { exit $resultado.CodigoSaida }
    }
}
catch {
    Write-Error "Nao foi possivel concluir a operacao: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
