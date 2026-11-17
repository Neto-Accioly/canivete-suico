#requires -Version 5.1
<#
.SYNOPSIS
Executa somente a suite QA isolada e gera relatorios locais.
.NOTES
Requer Pester 3.4 ou 4.x ja disponivel; nao instala/atualiza modulos.
Nao aceita -Aplicar e nao executa os scripts de producao diretamente.
Saida: 0 aprovado, 1 testes falhos/incompletos, 2 erro de infraestrutura.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$protectedPaths = @('scripts/instalar.ps1', 'scripts/verificar.ps1', 'config/ferramentas.json')
$before = [ordered]@{}
$runDirectory = $null
function Get-QATecnicas {
    param([string]$Caso)
    # Tecnica individual nao altera a classificacao global MOCKADO da suite.
    if ($Caso -notmatch '^QA-(\d{3})\b') { throw "Caso sem ID de classificacao: $Caso" }
    $id = [int]$Matches[1]
    if ($id -in @(1, 3, 4)) { return @('ANALISE_ESTATICA', 'LEITURA_CONTROLADA') }
    if ($id -eq 2) { return @('BARREIRA_SEGURANCA') }
    if ($id -eq 5) { return @('LEITURA_CONTROLADA') }
    if ($id -ge 6 -and $id -le 8) { return @('MOCK') }
    if ($id -ge 9 -and $id -le 16) { return @('FUNCAO_ISOLADA', 'LEITURA_CONTROLADA') }
    if ($id -ge 17 -and $id -le 32) { return @('MOCK') }
    if ($id -ge 33 -and $id -le 35) { return @('MOCK', 'AMBIENTE_PROCESSO_TEMPORARIO') }
    if ($id -ge 36 -and $id -le 38) { return @('FUNCAO_ISOLADA', 'LEITURA_CONTROLADA') }
    if ($id -ge 39 -and $id -le 43) { return @('MOCK', 'PROCESSO_FILHO_INSTRUMENTADO', 'LEITURA_CONTROLADA') }
    throw "Caso nao mapeado: $Caso. Atualize tecnicas e plano antes de publicar."
}

function Export-QANUnit {
    param($Result, [string]$Path)
    # Exportacao propria: o exportador do Pester 3 consulta CIM/WMI e pode
    # falhar na sandbox. Aqui nao ha inventario da maquina nem hostname.
    $settings = New-Object Xml.XmlWriterSettings
    $settings.Indent = $true
    $writer = [Xml.XmlWriter]::Create($Path, $settings)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('test-results')
        $writer.WriteAttributeString('name', 'NETO-LAB-QA')
        $writer.WriteAttributeString('total', [string]$Result.TotalCount)
        $writer.WriteAttributeString('failures', [string]$Result.FailedCount)
        $writer.WriteAttributeString('errors', '0')
        $writer.WriteAttributeString('not-run', [string]($Result.SkippedCount + $Result.PendingCount))
        $writer.WriteStartElement('test-suite')
        $writer.WriteAttributeString('name', 'QA isolado')
        $writer.WriteAttributeString('executed', 'True')
        $writer.WriteAttributeString('success', [string]($Result.FailedCount -eq 0))
        # Metadado NUnit da suite: preservar raiz, atributos e test-cases.
        $writer.WriteStartElement('properties')
        $writer.WriteStartElement('property')
        $writer.WriteAttributeString('name', 'tipo_execucao')
        $writer.WriteAttributeString('value', 'MOCKADO')
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteStartElement('results')
        foreach ($test in $Result.TestResult) {
            $writer.WriteStartElement('test-case')
            $writer.WriteAttributeString('name', [string]$test.Name)
            $writer.WriteAttributeString('executed', 'True')
            $writer.WriteAttributeString('success', [string]$test.Passed)
            $writer.WriteAttributeString('result', [string]$test.Result)
            if ($test.FailureMessage) {
                $writer.WriteStartElement('failure')
                $writer.WriteElementString('message', [string]$test.FailureMessage)
                $writer.WriteElementString('stack-trace', [string]$test.StackTrace)
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()
        }
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndDocument()
    }
    finally { $writer.Dispose() }
}
try {
    $pester = Get-Module -ListAvailable Pester |
        Where-Object { $_.Version -ge [version]'3.4.0' -and $_.Version.Major -lt 5 } |
        Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pester) {
        throw 'Pester 3.4/4.x nao disponivel. Nenhum modulo sera instalado. Consulte docs/qa.md.'
    }
    Import-Module $pester.Path -Force -ErrorAction Stop
    foreach ($relative in $protectedPaths) {
        $before[$relative] = (Get-FileHash (Join-Path $repo $relative) -Algorithm SHA256).Hash
    }
    $startUtc = [DateTimeOffset]::UtcNow
    $startLocal = [TimeZoneInfo]::ConvertTime($startUtc, [TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time'))
    $runId = $startLocal.ToString('yyyyMMdd-HHmmssfff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $runDirectory = Join-Path $repo "evidencias\execucoes\$runId"
    [void](New-Item -ItemType Directory -Path $runDirectory -Force)
    $xmlPath = Join-Path $runDirectory 'pester.nunit.xml'
    $result = Invoke-Pester -Script (Join-Path $repo 'tests\QA.Tests.ps1') -PassThru -Quiet -Strict
    Export-QANUnit $result $xmlPath
    $intact = $true
    foreach ($relative in $protectedPaths) {
        if ((Get-FileHash (Join-Path $repo $relative) -Algorithm SHA256).Hash -ne $before[$relative]) { $intact = $false }
    }
    $complete = $result.TotalCount -gt 0 -and $result.FailedCount -eq 0 -and
        $result.SkippedCount -eq 0 -and $result.PendingCount -eq 0 -and $intact
    $hashes = [ordered]@{}
    foreach ($relative in @($protectedPaths) + @('scripts/testar.ps1', 'tests/QA.Tests.ps1', 'tests/TestSupport.ps1', 'tests/Invoke-SafeScenario.ps1')) {
        $hashes[$relative] = (Get-FileHash (Join-Path $repo $relative) -Algorithm SHA256).Hash
    }
    $cases = @($result.TestResult | ForEach-Object {
        # Nao exportar stacktrace, erro, caminho absoluto, PATH, usuario ou hostname.
        [PSCustomObject]@{ caso = $_.Name; resultado = [string]$_.Result; tecnicas = @(Get-QATecnicas $_.Name) }
    })
    $summary = [ordered]@{
        execucao = $runId
        inicio_utc = $startUtc.ToString('o')
        inicio_sao_paulo = $startLocal.ToString('o')
        duracao_segundos = [math]::Round(([DateTimeOffset]::UtcNow - $startUtc).TotalSeconds, 3)
        ambiente = [ordered]@{
            powershell = $PSVersionTable.PSVersion.ToString()
            pester = $pester.Version.ToString()
            windows_runtime = [Environment]::OSVersion.Version.ToString()
            processo_bits = [IntPtr]::Size * 8
        }
        tipo_execucao = 'MOCKADO'
        tipo = 'Execucao isolada: mocks nas operacoes externas, analise estatica e leitura controlada de arquivos; nenhuma instalacao real'
        resultado = $(if ($complete) { 'APROVADO' } else { 'REPROVADO_OU_INCOMPLETO' })
        total = $result.TotalCount
        aprovados = $result.PassedCount
        falhos = $result.FailedCount
        ignorados = $result.SkippedCount
        pendentes = $result.PendingCount
        producao_preservada = $intact
        arquivos_sha256 = $hashes
        nunit_sha256 = (Get-FileHash $xmlPath -Algorithm SHA256).Hash
        casos = $cases
        limites = @('WinGet/Registro/PATH simulados; nao comprova estado do computador',
            'Instalacao real nao executada; confirmacao fisica e UI/EULA nao exercitadas',
            'Worker usa bloco principal instrumentado; nao e execucao direta do instalador',
            'Pester 3/4; outros ambientes requerem nova validacao')
    }
    $json = $summary | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $runDirectory 'resumo.json'), $json, (New-Object Text.UTF8Encoding($false)))
    $history = [PSCustomObject]@{ execucao = $runId; data = $startLocal.ToString('o'); tipo_execucao = 'MOCKADO'; resultado = $summary.resultado; total = $summary.total; falhos = $summary.falhos }
    $history | ConvertTo-Json -Compress | Add-Content (Join-Path $repo 'evidencias\execucoes\historico-local.jsonl') -Encoding UTF8
    Write-Host "Execucao: $runId | MOCKADO | $($summary.resultado)"
    Write-Host "Testes: $($result.TotalCount) | aprovados: $($result.PassedCount) | falhos: $($result.FailedCount) | pendentes: $($result.PendingCount) | ignorados: $($result.SkippedCount)"
    Write-Host 'Producao preservada:' $intact
    Write-Host "Relatorios locais: evidencias/execucoes/$runId/ (ignorados pelo Git)."
    Write-Host 'Antes de versionar resumo, revisar dados e atualizar docs/historico-execucoes.md.'
    if (-not $complete) { exit 1 }
}
catch {
    if ($runDirectory) {
        $_ | Out-String | Set-Content (Join-Path $runDirectory 'infraestrutura.txt') -Encoding UTF8
    }
    Write-Error "Falha de infraestrutura de QA: $($_.Exception.Message)" -ErrorAction Continue
    exit 2
}
finally {
    Remove-Module QaInstalador, QaDiagnostico -ErrorAction SilentlyContinue
}
