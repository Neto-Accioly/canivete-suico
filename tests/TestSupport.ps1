#requires -Version 5.1
# Este arquivo nao importa nem executa o bloco principal da producao.
function Get-QASafeSource {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$FunctionsOnly)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Sintaxe invalida em $Path" }
    $functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] })
    $blocked = @('Invoke-ConsultaWinGet', 'Invoke-InstalacaoNode', 'Invoke-VersaoNode',
        'Get-RegistrosInstalacao', 'Get-ConsultaWinGet', 'Get-IndiciosNode',
        'Invoke-VersaoAmbienteProjeto', 'Invoke-DependenciasProjeto', 'New-PastaProjeto',
        'Write-ArquivoProjeto', 'Confirm-AcaoProjeto')
    # Se surgir outra invocacao nativa, falhar fechado antes de carregar funcoes.
    foreach ($command in $ast.FindAll({ param($n)
        $n -is [Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq 'Ampersand'
    }, $true)) {
        $owner = $command.Parent
        while ($owner -and $owner -isnot [Management.Automation.Language.FunctionDefinitionAst]) { $owner = $owner.Parent }
        if (-not $owner -or $blocked -notcontains $owner.Name) {
            throw 'Nova invocacao nativa sem barreira de QA. Revise o isolamento antes de testar.'
        }
    }
    $source = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $definitions = @()
    foreach ($function in ($functions | Sort-Object { $_.Extent.StartOffset } -Descending)) {
        $text = $function.Extent.Text
        if ($blocked -contains $function.Name) {
            $parameters = if ($function.Body.ParamBlock) { $function.Body.ParamBlock.Extent.Text } else { '' }
            $text = "function $($function.Name) {`n$parameters`nthrow 'BARREIRA_QA: $($function.Name) exige mock isolado.'`n}"
            $source = $source.Remove($function.Extent.StartOffset, $function.Extent.EndOffset - $function.Extent.StartOffset).Insert($function.Extent.StartOffset, $text)
        }
        $definitions += $text
    }
    if ($FunctionsOnly) { return ($definitions -join "`n") }
    return $source
}

function Import-QAFunctions {
    param([string]$Path, [string]$Name)
    $safe = Get-QASafeSource -Path $Path -FunctionsOnly
    if ($Name -eq 'QaInstalador') {
        # Mocks Pester 3 executam no contexto do modulo, nao no arquivo de teste.
        $builder = (Get-Command New-QANodePlan -CommandType Function).Definition
        $safe += "`nfunction New-QANodePlan {`n$builder`n}"
    }
    $safe += "`nExport-ModuleMember -Function *"
    $tokens = $null
    $errors = $null
    # Manter o nome de arquivo para PSScriptRoot das funcoes de leitura.
    $ast = [Management.Automation.Language.Parser]::ParseInput($safe, $Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Erro na instrumentacao segura.' }
    $module = New-Module -Name $Name -ScriptBlock $ast.GetScriptBlock()
    Import-Module $module -Global -Force
}

function New-QANodePlan {
    param($Item, [string]$Status = 'NAO LOCALIZADA', [string]$Action = 'INSTALAR')
    [PSCustomObject]@{
        Item = $Item
        Estado = [PSCustomObject]@{ Instalacao = $Status; Atualizacao = 'NAO APLICAVEL'; Evidencia = 'Fixture ficticia: ID exato'; Instalada = 'nao obtida'; Disponivel = 'nao obtida' }
        Deteccao = [PSCustomObject]@{ Status = $Status; Evidencias = @([PSCustomObject]@{ Status = $Status; Fonte = 'Fixture'; Detalhe = 'Dado ficticio'; Caminho = '' }) }
        Plano = [PSCustomObject]@{ Acao = $Action }
    }
}

function Invoke-QAScenario {
    param([string]$Worker, [string]$Scenario)
    if ($Scenario -notmatch '^[a-z-]+$') { throw 'Cenario de QA invalido.' }
    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    # Politica apenas do filho; nenhuma gravacao da politica de usuario/maquina.
    $process.StartInfo.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $Worker + '" -Scenario ' + $Scenario
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Worker seguro excedeu 30 segundos.' }
        [PSCustomObject]@{ Codigo = $process.ExitCode; Texto = ($stdout.Result + $stderr.Result) }
    }
    finally { $process.Dispose() }
}
