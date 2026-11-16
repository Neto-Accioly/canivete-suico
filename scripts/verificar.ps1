param([string]$Projeto = '')

# Coletores retornam objetos; somente Show-Diagnostico escreve na tela.
function New-Resultado {
    param([string]$Nome, [string]$Categoria, [string]$Status,
        [string]$Versao = '-', [string]$Caminho = '-',
        [string]$Fonte = '-', [string]$Observacao = '')
    [PSCustomObject][ordered]@{
        Nome = $Nome
        Categoria = $Categoria
        Status = $Status
        Versao = $(if ($Versao) { $Versao } else { '-' })
        Caminho = $(if ($Caminho) { $Caminho } else { '-' })
        Fonte = $Fonte
        Observacao = $Observacao
    }
}

function Get-FerramentasTerminal {
$comandos = @(
    @{Nome="Git"; Cmd="git"},
    @{Nome="WinGet"; Cmd="winget"},
    @{Nome="VS Code"; Cmd="code.cmd"},
    @{Nome="Node.js"; Cmd="node"},
    @{Nome="npm"; Cmd="npm.cmd"},
    @{Nome="Java JDK/JRE"; Cmd="java"},
    @{Nome="Java Compiler"; Cmd="javac"},
    @{Nome="Maven"; Cmd="mvn.cmd"},
    @{Nome="Python"; Cmd="python"},
    @{Nome="TypeScript CLI"; Cmd="tsc.cmd"},
    @{Nome="k6"; Cmd="k6"},
    @{Nome="Docker CLI"; Cmd="docker"},
    @{Nome="MySQL CLI"; Cmd="mysql"},
    @{Nome="MongoDB Shell"; Cmd="mongosh"}
)
    foreach ($item in $comandos) {
        try {
            $cmd = Get-Command -Name $item.Cmd -CommandType Application -ErrorAction Stop | Select-Object -First 1
            New-Resultado -Nome $item.Nome -Categoria 'Terminal' -Status 'ENCONTRADO' -Caminho $cmd.Source -Fonte 'Get-Command' -Observacao 'Comando localizado; versao e funcionamento nao verificados.'
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            New-Resultado -Nome $item.Nome -Categoria 'Terminal' -Status 'NAO LOCALIZADO' -Fonte 'Get-Command' -Observacao 'Comando ausente do PATH consultado.'
        }
        catch {
            New-Resultado -Nome $item.Nome -Categoria 'Terminal' -Status 'ERRO NA CONSULTA' -Fonte 'Get-Command' -Observacao $_.Exception.Message
        }
    }
}

function Get-AplicativosInstalados {
    $chaves = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $falhas = @()
    $instalados = @(foreach ($chave in $chaves) {
        try {
            if (Test-Path -LiteralPath $chave -ErrorAction Stop) {
                Get-ItemProperty -Path "$chave\*" -ErrorAction Stop | Where-Object { $_.DisplayName }
            }
        }
        catch { $falhas += "${chave}: $($_.Exception.Message)" }
    })
$aplicativos = @(
    @{Nome="IntelliJ IDEA"; Padrao="IntelliJ IDEA"},
    @{Nome="Postman"; Padrao="Postman"},
    @{Nome="Insomnia"; Padrao="Insomnia"},
    @{Nome="Mockoon"; Padrao="Mockoon"},
    @{Nome="MySQL Workbench"; Padrao="MySQL Workbench"},
    @{Nome="MySQL Server"; Padrao="MySQL Server"},
    @{Nome="MongoDB Server"; Padrao="MongoDB Server"},
    @{Nome="MongoDB Compass"; Padrao="MongoDB Compass"},
    @{Nome="Docker Desktop"; Padrao="Docker Desktop"},
    @{Nome="JMeter"; Padrao="Apache JMeter"},
    @{Nome="GitHub Desktop"; Padrao="GitHub Desktop"}
)
    foreach ($falha in $falhas) {
        New-Resultado -Nome 'Consulta de aplicativos' -Categoria 'Aplicativo' -Status 'ERRO NA CONSULTA' -Fonte 'Registro do Windows' -Observacao $falha
    }
    foreach ($app in $aplicativos) {
        $registros = @($instalados | Where-Object { $_.DisplayName -match $app.Padrao })
        if ($registros.Count -gt 0) {
            foreach ($registro in $registros) {
                New-Resultado -Nome $app.Nome -Categoria 'Aplicativo' -Status 'ENCONTRADO' -Versao $registro.DisplayVersion -Caminho $registro.InstallLocation -Fonte $registro.PSPath -Observacao 'Versao informada pelo Registro.'
            }
        }
        else {
            $status = if ($falhas.Count -gt 0) { 'ERRO NA CONSULTA' } else { 'NAO LOCALIZADO' }
            New-Resultado -Nome $app.Nome -Categoria 'Aplicativo' -Status $status -Fonte 'Registro do Windows' -Observacao 'Sem registro localizado; instalacoes portateis nao verificadas. Consulte eventuais erros de consulta.'
        }
    }
}

function Get-ServicosBanco {
    try {
        $servicos = @(Get-Service -ErrorAction Stop | Where-Object {
            $_.Name -match '^(MySQL|MariaDB|MongoDB|MSSQL)' -or
            $_.DisplayName -match '^(MySQL|MariaDB|MongoDB|SQL Server)'
        })
        foreach ($servico in $servicos) {
            New-Resultado -Nome $servico.Name -Categoria 'Servico' -Status 'ENCONTRADO' -Fonte 'Get-Service' -Observacao "$($servico.DisplayName); estado: $($servico.Status). Conexao nao verificada."
        }
        if ($servicos.Count -eq 0) {
            New-Resultado -Nome 'Servicos de banco de dados' -Categoria 'Servico' -Status 'NAO LOCALIZADO' -Fonte 'Get-Service' -Observacao 'Nenhum servico corresponde aos padroes pesquisados.'
        }
    }
    catch {
        New-Resultado -Nome 'Servicos de banco de dados' -Categoria 'Servico' -Status 'ERRO NA CONSULTA' -Fonte 'Get-Service' -Observacao $_.Exception.Message
    }
}

function Get-DependenciasProjeto {
    param([string]$CaminhoProjeto)
    if ([string]::IsNullOrWhiteSpace($CaminhoProjeto)) {
        New-Resultado -Nome 'Projeto' -Categoria 'Projeto' -Status 'NAO INFORMADO' -Fonte 'Parametro -Projeto'
        return
    }
    try {
        if (-not (Test-Path -LiteralPath $CaminhoProjeto -PathType Container -ErrorAction Stop)) {
            New-Resultado -Nome 'Projeto' -Categoria 'Projeto' -Status 'CAMINHO INVALIDO' -Caminho $CaminhoProjeto -Fonte 'Parametro -Projeto' -Observacao 'Pasta inexistente ou caminho nao aponta para uma pasta.'
            return
        }
        $raiz = (Get-Item -LiteralPath $CaminhoProjeto -ErrorAction Stop).FullName
    }
    catch {
        New-Resultado -Nome 'Projeto' -Categoria 'Projeto' -Status 'ERRO NA CONSULTA' -Caminho $CaminhoProjeto -Fonte 'Parametro -Projeto' -Observacao $_.Exception.Message
        return
    }
    $pacote = Join-Path $raiz 'package.json'
    try {
        if (Test-Path -LiteralPath $pacote -PathType Leaf -ErrorAction Stop) {
            $json = Get-Content -LiteralPath $pacote -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $encontradas = 0
            foreach ($secao in @('dependencies', 'devDependencies')) {
                if ($null -ne $json.$secao) {
                    foreach ($dependencia in $json.$secao.PSObject.Properties) {
                        if ($dependencia.Name -match 'playwright|cypress|typescript|selenium') {
                            $encontradas++
                            New-Resultado -Nome $dependencia.Name -Categoria 'Dependencia do projeto' -Status 'DECLARADO' -Versao ([string]$dependencia.Value) -Caminho $pacote -Fonte "package.json ($secao)" -Observacao 'Versao ou faixa declarada; instalacao nao verificada.'
                        }
                    }
                }
            }
            if ($encontradas -eq 0) {
                New-Resultado -Nome 'Dependencias Node de QA' -Categoria 'Dependencia do projeto' -Status 'NAO LOCALIZADO' -Caminho $pacote -Fonte 'package.json' -Observacao 'Nenhuma dependencia corresponde aos padroes pesquisados.'
            }
        }
        else {
            New-Resultado -Nome 'Manifesto Node' -Categoria 'Projeto' -Status 'NAO LOCALIZADO' -Caminho $pacote -Fonte 'Sistema de arquivos'
        }
    }
    catch {
        New-Resultado -Nome 'Manifesto Node' -Categoria 'Projeto' -Status 'ERRO NA CONSULTA' -Caminho $pacote -Fonte 'package.json' -Observacao $_.Exception.Message
    }
    $pom = Join-Path $raiz 'pom.xml'
    try {
        if (Test-Path -LiteralPath $pom -PathType Leaf -ErrorAction Stop) {
            $conteudo = Get-Content -LiteralPath $pom -Raw -ErrorAction Stop
            foreach ($nome in @('selenium-java', 'junit')) {
                $status = if ($conteudo -match $nome) { 'INDICIO ENCONTRADO' } else { 'NAO LOCALIZADO' }
                New-Resultado -Nome $nome -Categoria 'Dependencia do projeto' -Status $status -Caminho $pom -Fonte 'pom.xml' -Observacao 'Busca textual; pode incluir comentarios. Versao, heranca e instalacao nao verificadas.'
            }
        }
        else {
            New-Resultado -Nome 'Manifesto Maven' -Categoria 'Projeto' -Status 'NAO LOCALIZADO' -Caminho $pom -Fonte 'Sistema de arquivos'
        }
    }
    catch {
        New-Resultado -Nome 'Manifesto Maven' -Categoria 'Projeto' -Status 'ERRO NA CONSULTA' -Caminho $pom -Fonte 'pom.xml' -Observacao $_.Exception.Message
    }
    $workflows = Join-Path $raiz '.github\workflows'
    try {
        $status = if (Test-Path -LiteralPath $workflows -PathType Container -ErrorAction Stop) { 'ENCONTRADO' } else { 'NAO LOCALIZADO' }
        New-Resultado -Nome 'GitHub Actions' -Categoria 'Projeto' -Status $status -Caminho $workflows -Fonte 'Sistema de arquivos' -Observacao 'Verifica somente a existencia da pasta de workflows.'
    }
    catch {
        New-Resultado -Nome 'GitHub Actions' -Categoria 'Projeto' -Status 'ERRO NA CONSULTA' -Caminho $workflows -Fonte 'Sistema de arquivos' -Observacao $_.Exception.Message
    }
}

function Show-Diagnostico {
    param([object[]]$Resultados)
    Write-Host "`n=======================================" -ForegroundColor Cyan
    Write-Host ' CANIVETE SUICO - DIAGNOSTICO NETO-LAB' -ForegroundColor Cyan
    Write-Host '=======================================' -ForegroundColor Cyan
    foreach ($grupo in ($Resultados | Group-Object -Property Categoria)) {
        Write-Host "`n=== $($grupo.Name) ===" -ForegroundColor Yellow
        $grupo.Group | Format-Table Nome, Categoria, Status, Versao, Caminho, Fonte, Observacao -AutoSize -Wrap | Out-Host
    }
    $erros = @($Resultados | Where-Object { $_.Status -eq 'ERRO NA CONSULTA' }).Count
    if ($erros -gt 0) {
        Write-Host "`nDiagnostico concluido com $erros resultado(s) com erro de consulta." -ForegroundColor Yellow
    }
    else { Write-Host "`nDiagnostico concluido." -ForegroundColor Green }
}

$resultados = @(
    Get-FerramentasTerminal
    Get-AplicativosInstalados
    Get-ServicosBanco
    Get-DependenciasProjeto -CaminhoProjeto $Projeto
)
Show-Diagnostico -Resultados $resultados
