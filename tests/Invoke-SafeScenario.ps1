#requires -Version 5.1
# Worker privado de testes. Nunca executa o arquivo de producao com -File.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('single', 'multiple', 'array', 'all', 'essencial', 'apis-bancos', 'avancado',
        'invalid-profile', 'invalid-tool', 'conflict', 'interactive', 'apply-success',
        'apply-cancel', 'apply-failure', 'apply-pending', 'apply-inconclusive', 'apply-existing', 'apply-mixed')]
    [string]$Scenario
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestSupport.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repo 'scripts\instalar.ps1'
$script:QACatalog = Get-Content (Join-Path $repo 'config\ferramentas.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:QAScenario = $Scenario
$script:QAInstallCalls = 0
$script:QAConfirmCalls = 0
$safe = Get-QASafeSource $path
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($safe, [ref]$tokens, [ref]$errors)
if ($errors.Count -or $ast.EndBlock.Statements[-1] -isnot [Management.Automation.Language.TryStatementAst]) {
    throw 'Bloco principal mudou; revisar worker antes de executar.'
}
$offset = $ast.EndBlock.Statements[-1].Extent.StartOffset
# Todas as interacoes externas sao falsas, mesmo nas simulacoes.
$mocks = @'
function Read-Catalogo { $script:QACatalog }
function Get-RegistrosInstalacao { [PSCustomObject]@{Registros=@();Falhas=@()} }
function Get-EvidenciasArquivos { }
function Get-IndiciosNode { }
function Get-ConsultaWinGet {
    @{Disponivel=$true;Caminho='QA_NUNCA_EXECUTAR';Atualizacoes=[PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Name Id Version Available','-------------------------','Outro Outro.Produto 1.0 2.0')}}
}
function Invoke-ConsultaWinGet {
    param($Caminho,$Operacao,$Id)
    if($script:QAScenario -eq 'apply-existing') { return [PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Node.js (LTS) OpenJS.NodeJS.LTS 24.0.0')} }
    if($script:QAScenario -eq 'apply-inconclusive') { return [PSCustomObject]@{Codigo=1;Erro='Falha ficticia';Linhas=@()} }
    [PSCustomObject]@{Codigo=-1978335212;Erro='';Linhas=@('No packages found')}
}
function Read-Host { '1,2' }
function Confirm-InstalacaoNode {
    $script:QAConfirmCalls++
    return $script:QAScenario -ne 'apply-cancel'
}
function Invoke-InstalacaoNode {
    param($CaminhoWinGet)
    $script:QAInstallCalls++
    Write-Host 'QA_INSTALACAO_FALSA'
    $code=if($script:QAScenario -eq 'apply-failure'){1603}else{0}
    [PSCustomObject]@{Codigo=$code;Erro=''}
}
function Get-VerificacaoNode {
    param($CaminhoWinGet)
    [PSCustomObject]@{
        Concluida=($script:QAScenario -ne 'apply-pending')
        Node=[PSCustomObject]@{Versao='v24.0.0';Codigo=0;Caminho='fixture/node.exe';Erro=''}
        Npm=[PSCustomObject]@{Versao='11.0.0';Codigo=0;Caminho='fixture/npm.cmd';Erro=''}
        WinGet=[PSCustomObject]@{Codigo=0;Erro=''};Linhas=@()
    }
}
'@
$safe = $safe.Substring(0, $offset) + $mocks + "`n" + $safe.Substring($offset)
$arguments = @{}
switch ($Scenario) {
    'single' { $arguments.Ferramentas = 'Git' }
    'multiple' { $arguments.Ferramentas = 'Git, VS Code' }
    'array' { $arguments.Ferramentas = @('Git', 'VS Code') }
    'all' { $arguments.Todas = $true }
    { $_ -in @('essencial', 'apis-bancos', 'avancado') } { $arguments.Perfil = $Scenario }
    'invalid-profile' { $arguments.Perfil = 'inexistente' }
    'invalid-tool' { $arguments.Ferramentas = 'FerramentaInexistente' }
    'conflict' { $arguments.Perfil = 'essencial'; $arguments.Todas = $true }
    'interactive' { }
    default { $arguments.Ferramentas = 'Node.js LTS'; $arguments.Aplicar = $true }
}
if ($Scenario -eq 'apply-mixed') { $arguments.Ferramentas = 'Node.js LTS, Git' }
& ([scriptblock]::Create($safe)) @arguments
Write-Host "QA_CONTADORES: instalar=$script:QAInstallCalls; confirmar=$script:QAConfirmCalls"
