#requires -Version 5.1
# Sintaxe de assercoes Pester 3/4, sem instalacao de modulos.
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'TestSupport.ps1')
Import-QAFunctions (Join-Path $repo 'scripts\instalar.ps1') 'QaInstalador'
Import-QAFunctions (Join-Path $repo 'scripts\verificar.ps1') 'QaDiagnostico'
$catalog = Get-Content (Join-Path $repo 'config\ferramentas.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$worker = Join-Path $PSScriptRoot 'Invoke-SafeScenario.ps1'
$git = $catalog.ferramentas | Where-Object nome -eq 'Git'
$node = $catalog.ferramentas | Where-Object nome -eq 'Node.js LTS'

Describe 'Estrutura e barreiras de seguranca' {
    It 'QA-001 scripts e testes possuem sintaxe PowerShell valida' {
        $paths = @(Get-ChildItem (Join-Path $repo 'scripts') -Filter '*.ps1') + @(Get-ChildItem $PSScriptRoot -Filter '*.ps1')
        foreach ($path in $paths) {
            $t = $null; $e = $null
            [Management.Automation.Language.Parser]::ParseFile($path.FullName, [ref]$t, [ref]$e) | Out-Null
            $e.Count | Should Be 0
        }
        # Contrato estatico dos metadados: nao executar o runner dentro da suite.
        $reportSource = Get-Content (Join-Path $repo 'scripts\testar.ps1') -Raw -Encoding UTF8
        $reportSource | Should Match "tipo_execucao = 'MOCKADO'"
        $reportSource | Should Match "WriteStartElement\('properties'\)"
        $reportSource | Should Match "WriteAttributeString\('name', 'tipo_execucao'\)"
        $reportSource | Should Match 'tecnicas = @\(Get-QATecnicas'
    }
    It 'QA-002 barreira nativa rejeita instalar consultar e executar versoes sem mock' {
        { QaInstalador\Invoke-InstalacaoNode 'NAO_EXECUTAR' } | Should Throw 'BARREIRA_QA'
        { QaInstalador\Invoke-ConsultaWinGet 'NAO_EXECUTAR' 'Listar' 'Git.Git' } | Should Throw 'BARREIRA_QA'
        { QaInstalador\Invoke-VersaoNode 'node.exe' 'NAO_EXECUTAR' } | Should Throw 'BARREIRA_QA'
    }
    It 'QA-003 chamada install e fixa sem upgrade forca silencio ou aceite automatico' {
        $t = $null; $e = $null
        $a = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts\instalar.ps1'), [ref]$t, [ref]$e)
        $calls = @($a.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.Extent.Text -match '^& \$CaminhoWinGet install\b' }, $true))
        $calls.Count | Should Be 1
        $calls[0].Extent.Text | Should Match 'install --id OpenJS.NodeJS.LTS --exact --source winget --interactive --no-upgrade --skip-dependencies'
        $calls[0].Extent.Text | Should Not Match '--silent|--force|--accept-'
    }
    It 'QA-004 upgrade nao recebe ID query all ou force' {
        $text = Get-Content (Join-Path $repo 'scripts\instalar.ps1') -Raw -Encoding UTF8
        $text | Should Match '& \$Caminho upgrade --source winget --disable-interactivity'
        $text | Should Not Match '(?m)^\s*& .*upgrade.*(?:--id|--all|--force)'
        $text | Should Not Match '--disable-source-update'
    }
}

Describe 'Catalogo e selecao' {
    It 'QA-005 catalogo real tem 25 nomes unicos e nove IDs null' {
        $catalog.ferramentas.Count | Should Be 25
        @($catalog.ferramentas | Group-Object nome | Where-Object Count -gt 1).Count | Should Be 0
        @($catalog.ferramentas | Where-Object { $null -eq $_.winget_id }).Count | Should Be 9
        foreach ($item in $catalog.ferramentas) {
            foreach ($field in @('nome','categoria','winget_id','metodo_instalacao','obrigatoriedade','descricao')) {
                ($item.PSObject.Properties.Name -contains $field) | Should Be $true
            }
        }
    }
    It 'QA-006 Read-Catalogo aceita fixture com ID null' {
        Mock Test-Path { $true } -ModuleName QaInstalador
        Mock Get-Content { '{"ferramentas":[{"nome":"Fixture","categoria":"CLI","winget_id":null,"metodo_instalacao":"manual_site_oficial","obrigatoriedade":"opcional","descricao":"Fixture"}]}' } -ModuleName QaInstalador
        $r = QaInstalador\Read-Catalogo
        $r.ferramentas.Count | Should Be 1
        ($null -eq $r.ferramentas[0].winget_id) | Should Be $true
    }
    It 'QA-007 catalogo inexistente ou JSON invalido e rejeitado' {
        Mock Test-Path { $false } -ModuleName QaInstalador
        { QaInstalador\Read-Catalogo } | Should Throw 'Catalogo nao encontrado'
        Mock Test-Path { $true } -ModuleName QaInstalador
        Mock Get-Content { '{invalido' } -ModuleName QaInstalador
        { QaInstalador\Read-Catalogo } | Should Throw 'interpretar'
    }
    It 'QA-008 campo ausente e nome duplicado sao rejeitados' {
        Mock Test-Path { $true } -ModuleName QaInstalador
        Mock Get-Content { '{"ferramentas":[{"nome":"Fixture"}]}' } -ModuleName QaInstalador
        { QaInstalador\Read-Catalogo } | Should Throw 'campo ausente'
        Mock Get-Content { '{"ferramentas":[{"nome":"A","categoria":"CLI","winget_id":null,"metodo_instalacao":"manual","obrigatoriedade":"opcional","descricao":"Fixture"},{"nome":"A","categoria":"CLI","winget_id":null,"metodo_instalacao":"manual","obrigatoriedade":"opcional","descricao":"Fixture"}]}' } -ModuleName QaInstalador
        { QaInstalador\Read-Catalogo } | Should Throw 'duplicado'
    }
    It 'QA-009 selecao individual array CSV espacos e duplicatas' {
        @(QaInstalador\Select-Ferramentas $catalog.ferramentas @('Git') $false).Count | Should Be 1
        @(QaInstalador\Select-Ferramentas $catalog.ferramentas @('Git','VS Code') $false).Count | Should Be 2
        @(QaInstalador\Select-Ferramentas $catalog.ferramentas @(' Git, VS Code , Git ') $false).Count | Should Be 2
    }
    It 'QA-010 nomes desconhecidos e elementos vazios sao rejeitados' {
        { QaInstalador\Select-Ferramentas $catalog.ferramentas @('Inexistente') $false } | Should Throw 'nao encontrada'
        { QaInstalador\Select-Ferramentas $catalog.ferramentas @('Git, ') $false } | Should Throw 'vazio'
    }
    It 'QA-011 Todas preserva os 25 itens' {
        @(QaInstalador\Select-Ferramentas $catalog.ferramentas @() $true).Count | Should Be 25
    }
    It 'QA-012 perfil essencial seleciona somente cinco membros' {
        $r = @(QaInstalador\Select-Perfil $catalog 'essencial')
        $r.Count | Should Be 5
        @($r | Where-Object { $_.perfis -notcontains 'essencial' }).Count | Should Be 0
    }
    It 'QA-013 perfil apis-bancos seleciona somente treze membros' {
        $r = @(QaInstalador\Select-Perfil $catalog 'apis-bancos')
        $r.Count | Should Be 13
        @($r | Where-Object { $_.perfis -notcontains 'apis-bancos' }).Count | Should Be 0
    }
    It 'QA-014 perfil avancado seleciona somente quinze membros' {
        $r = @(QaInstalador\Select-Perfil $catalog 'avancado')
        $r.Count | Should Be 15
        @($r | Where-Object { $_.perfis -notcontains 'avancado' }).Count | Should Be 0
    }
    It 'QA-015 perfil desconhecido e referencia invalida sao rejeitados' {
        { QaInstalador\Select-Perfil $catalog 'desconhecido' } | Should Throw 'Perfil inexistente'
        $fake = Get-Content (Join-Path $fixtures 'catalogo-minimo.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $fake.ferramentas[0].perfis = @('nao-definido')
        { QaInstalador\Select-Perfil $fake 'essencial' } | Should Throw 'Referencia de perfil invalida'
    }
}

Describe 'Interpretacao WinGet e planejamento sem acesso nativo' {
    It 'QA-016 tabelas com um espaco sao interpretadas pelo ID exato' {
        $data = Get-Content (Join-Path $fixtures 'winget-cenarios.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $r = @(QaInstalador\Read-LinhasWinGet $data.lista_git 'Git.Git')
        $r.Count | Should Be 1
        $r[0].Instalada | Should Be '2.0.0'
        @(QaInstalador\Read-LinhasWinGet $data.lista_id_semelhante 'Git.Git').Count | Should Be 0
    }
    It 'QA-017 versao instalada e atualizacao disponivel geram ATUALIZAR' {
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Git Git.Git 2.0.0')} } -ModuleName QaInstalador
        $wg = @{Disponivel=$true;Caminho='mock';Atualizacoes=[PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Name Id Version Available','---------------------','Git Git.Git 2.0.0 3.0.0')}}
        $state = QaInstalador\Get-EstadoWinGet $git $wg
        $state.Instalada | Should Be '2.0.0'
        $state.Disponivel | Should Be '3.0.0'
        (QaInstalador\Get-AcaoPlano $git ([PSCustomObject]@{Status='CONFIRMADA';Evidencias=@()}) $state).Acao | Should Be 'ATUALIZAR'
    }
    It 'QA-018 lista completa sem atualizacao do ID gera MANTER' {
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Git Git.Git 2.0.0')} } -ModuleName QaInstalador
        $wg = @{Disponivel=$true;Caminho='mock';Atualizacoes=[PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Name Id Version Available','---------------------','Outro Outro.Produto 1.0 2.0')}}
        $state = QaInstalador\Get-EstadoWinGet $git $wg
        (QaInstalador\Get-AcaoPlano $git ([PSCustomObject]@{Status='CONFIRMADA';Evidencias=@()}) $state).Acao | Should Be 'MANTER'
    }
    It 'QA-019 consulta falha versao desconhecida e fonte indisponivel geram REVISAR' {
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=1;Erro='Falha ficticia';Linhas=@()} } -ModuleName QaInstalador
        $state = QaInstalador\Get-EstadoWinGet $git @{Disponivel=$true;Caminho='mock'}
        (QaInstalador\Get-AcaoPlano $git ([PSCustomObject]@{Evidencias=@()}) $state).Acao | Should Be 'REVISAR'
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Git Git.Git Unknown')} } -ModuleName QaInstalador
        (QaInstalador\Get-EstadoWinGet $git @{Disponivel=$true;Caminho='mock'}).Instalacao | Should Be 'INCONCLUSIVA'
        (QaInstalador\Get-EstadoWinGet $git @{Disponivel=$false;Motivo='Sandbox ficticia'}).Instalacao | Should Be 'INCONCLUSIVA'
    }
    It 'QA-020 ausencia sem evidencia local gera INSTALAR e conflito local gera REVISAR' {
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=-1978335212;Erro='';Linhas=@()} } -ModuleName QaInstalador
        $state = QaInstalador\Get-EstadoWinGet $git @{Disponivel=$true;Caminho='mock'}
        (QaInstalador\Get-AcaoPlano $git ([PSCustomObject]@{Status='NAO LOCALIZADA';Evidencias=@()}) $state).Acao | Should Be 'INSTALAR'
        (QaInstalador\Get-AcaoPlano $git ([PSCustomObject]@{Status='CONFIRMADA';Evidencias=@()}) $state).Acao | Should Be 'REVISAR'
    }
    It 'QA-021 atualizacoes de Java MySQL e MongoDB exigem revisao manual' {
        foreach ($name in @('Java JDK LTS','MySQL Server','MongoDB Community Server')) {
            $item = $catalog.ferramentas | Where-Object nome -eq $name
            $state = [PSCustomObject]@{Instalacao='CONFIRMADA';Atualizacao='DISPONIVEL'}
            (QaInstalador\Get-AcaoPlano $item ([PSCustomObject]@{Evidencias=@()}) $state).Acao | Should Be 'REVISAR'
        }
    }
    It 'QA-022 bibliotecas npm Maven e modulo PowerShell nao consultam WinGet' {
        Mock Invoke-ConsultaWinGet { throw 'Nao deveria ser chamado' } -ModuleName QaInstalador
        foreach ($name in @('Cypress','JUnit 5','REST Assured','Pester')) {
            $item = $catalog.ferramentas | Where-Object nome -eq $name
            (QaInstalador\Get-EstadoWinGet $item @{Disponivel=$true}).Instalacao | Should Be 'INCONCLUSIVA'
        }
        Assert-MockCalled -Scope It Invoke-ConsultaWinGet -ModuleName QaInstalador -Times 0 -Exactly
    }
    It 'QA-023 WindowsApps isolado nao confirma instalacao' {
        Mock Get-Command { [PSCustomObject]@{Source='C:\fixture\WindowsApps\git.exe'} } -ModuleName QaInstalador
        $r = @(QaInstalador\Get-EvidenciasArquivos $git (QaInstalador\Get-RegraDeteccao $git))
        $r[0].Status | Should Be 'INCONCLUSIVA'
        $r[0].Detalhe | Should Match 'WindowsApps'
    }
    It 'QA-024 VS Code do usuario e localizado por metadados e caminho padrao' {
        Mock Get-Command { @() } -ModuleName QaInstalador
        Mock Test-Path { $true } -ModuleName QaInstalador
        Mock Get-Item { [PSCustomObject]@{Attributes=[IO.FileAttributes]::Normal;FullName='C:\fixture\Code.exe';VersionInfo=[PSCustomObject]@{ProductName='Visual Studio Code';ProductVersion='1.0.0'}} } -ModuleName QaInstalador
        $item = $catalog.ferramentas | Where-Object nome -eq 'VS Code'
        $r = @(QaInstalador\Get-EvidenciasArquivos $item (QaInstalador\Get-RegraDeteccao $item))
        $r.Count | Should Be 1
        $r[0].Status | Should Be 'CONFIRMADA'
        $r[0].Fonte | Should Match 'LOCALAPPDATA'
        $r[0].Versao | Should Be '1.0.0'
    }
}

Describe 'Aplicacao Node somente com mocks' {
    BeforeEach {
        Mock Write-Host { } -ModuleName QaInstalador
        Mock Get-PlanoNodeAtual { New-QANodePlan $Item } -ModuleName QaInstalador
        Mock Confirm-InstalacaoNode { $true } -ModuleName QaInstalador
        Mock Invoke-InstalacaoNode { [PSCustomObject]@{Codigo=0;Erro=''} } -ModuleName QaInstalador
        Mock Get-VerificacaoNode { [PSCustomObject]@{Concluida=$true;Node=[PSCustomObject]@{Versao='v24.0.0';Codigo=0};Npm=[PSCustomObject]@{Versao='11.0.0';Codigo=0};WinGet=[PSCustomObject]@{Codigo=0};Linhas=@()} } -ModuleName QaInstalador
    }
    It 'QA-025 selecao mista e IDs nao autorizados sao bloqueados integralmente' {
        { QaInstalador\Invoke-AplicacaoNode @($node,$git) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'} } | Should Throw 'integralmente'
        $fake = [PSCustomObject]@{nome='Node.js LTS';winget_id='OpenJS.NodeJS';metodo_instalacao='winget'}
        { QaInstalador\Assert-SelecaoAplicacao @($fake) } | Should Throw
        Assert-MockCalled -Scope It Invoke-InstalacaoNode -ModuleName QaInstalador -Times 0 -Exactly
        Assert-MockCalled -Scope It Confirm-InstalacaoNode -ModuleName QaInstalador -Times 0 -Exactly
    }
    It 'QA-026 Node existente ou inconclusivo bloqueia antes da confirmacao' {
        { QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node 'INCONCLUSIVA' 'REVISAR')) @{Disponivel=$true;Caminho='mock'} } | Should Throw 'bloqueado'
        { QaInstalador\Assert-AusenciaNode (New-QANodePlan $node 'CONFIRMADA' 'ATUALIZAR') } | Should Throw 'bloqueado'
        Assert-MockCalled -Scope It Invoke-InstalacaoNode -ModuleName QaInstalador -Times 0 -Exactly
    }
    It 'QA-027 cancelamento nao chama instalador nem verificacao' {
        Mock Confirm-InstalacaoNode { $false } -ModuleName QaInstalador
        $r = QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'}
        $r.Status | Should Be 'CANCELADO'
        Assert-MockCalled -Scope It Invoke-InstalacaoNode -ModuleName QaInstalador -Times 0 -Exactly
        Assert-MockCalled -Scope It Get-VerificacaoNode -ModuleName QaInstalador -Times 0 -Exactly
    }
    It 'QA-028 sucesso exige confirmacao duas revalidacoes e verificacao' {
        $r = QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'}
        $r.Status | Should Be 'SUCESSO'
        Assert-MockCalled -Scope It Confirm-InstalacaoNode -ModuleName QaInstalador -Times 1 -Exactly
        Assert-MockCalled -Scope It Get-PlanoNodeAtual -ModuleName QaInstalador -Times 2 -Exactly
        Assert-MockCalled -Scope It Invoke-InstalacaoNode -ModuleName QaInstalador -Times 1 -Exactly
        Assert-MockCalled -Scope It Get-VerificacaoNode -ModuleName QaInstalador -Times 1 -Exactly
    }
    It 'QA-029 falha do instalador nao e mascarada por verificacao positiva' {
        Mock Invoke-InstalacaoNode { [PSCustomObject]@{Codigo=1603;Erro='Falha ficticia'} } -ModuleName QaInstalador
        $r = QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'}
        $r.Status | Should Be 'FALHA'
        $r.CodigoSaida | Should Be 1
    }
    It 'QA-030 retorno zero sem verificacao completa gera pendencia' {
        Mock Get-VerificacaoNode { [PSCustomObject]@{Concluida=$false} } -ModuleName QaInstalador
        $r = QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'}
        $r.Status | Should Be 'VERIFICACAO PENDENTE'
        $r.CodigoSaida | Should Be 2
    }
    It 'QA-031 reinicio necessario permanece pendente' {
        Mock Invoke-InstalacaoNode { [PSCustomObject]@{Codigo=3010;Erro=''} } -ModuleName QaInstalador
        (QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'}).Status | Should Be 'VERIFICACAO PENDENTE'
    }
    It 'QA-032 mudanca apos confirmacao bloqueia instalacao' {
        Mock Get-PlanoNodeAtual { New-QANodePlan $Item 'INCONCLUSIVA' 'REVISAR' } -ModuleName QaInstalador
        # Primeiro retorno ausente, segundo inconclusivo; contador limitado ao teste.
        & (Get-Module QaInstalador) { $script:QARechecks = 0 }
        Mock Get-PlanoNodeAtual {
            $module = Get-Module QaInstalador
            $count = & $module { $script:QARechecks++; $script:QARechecks }
            if ($count -eq 1) { New-QANodePlan $Item } else { New-QANodePlan $Item 'INCONCLUSIVA' 'REVISAR' }
        } -ModuleName QaInstalador
        { QaInstalador\Invoke-AplicacaoNode @($node) @((New-QANodePlan $node)) @{Disponivel=$true;Caminho='mock'} } | Should Throw 'bloqueado'
        Assert-MockCalled -Scope It Invoke-InstalacaoNode -ModuleName QaInstalador -Times 0 -Exactly
    }
}

Describe 'Verificacao posterior sem executaveis reais' {
    BeforeEach {
        Mock Get-PathVerificacao { 'C:\fixture' } -ModuleName QaInstalador
        Mock Get-Command { [PSCustomObject]@{Source='C:\fixture\node.exe'} } -ModuleName QaInstalador
        Mock Invoke-VersaoNode { [PSCustomObject]@{Valida=$true;Versao='v24.0.0';Codigo=0} } -ModuleName QaInstalador
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Node.js OpenJS.NodeJS.LTS 24.0.0')} } -ModuleName QaInstalador
    }
    It 'QA-033 node npm e inventario sao verificados e PATH restaurado' {
        $before = $env:PATH
        $r = QaInstalador\Get-VerificacaoNode 'mock'
        $r.Concluida | Should Be $true
        $env:PATH | Should BeExactly $before
        Assert-MockCalled -Scope It Invoke-VersaoNode -ModuleName QaInstalador -Times 2 -Exactly
        Assert-MockCalled -Scope It Invoke-ConsultaWinGet -ModuleName QaInstalador -Times 1 -Exactly -ParameterFilter { $Id -eq 'OpenJS.NodeJS.LTS' -and $Operacao -eq 'Listar' }
    }
    It 'QA-034 versoes divergentes impedem sucesso' {
        Mock Invoke-ConsultaWinGet { [PSCustomObject]@{Codigo=0;Erro='';Linhas=@('Node.js OpenJS.NodeJS.LTS 22.0.0')} } -ModuleName QaInstalador
        (QaInstalador\Get-VerificacaoNode 'mock').Concluida | Should Be $false
    }
    It 'QA-035 excecao restaura PATH' {
        Mock Invoke-ConsultaWinGet { throw 'Falha ficticia' } -ModuleName QaInstalador
        $before = $env:PATH
        { QaInstalador\Get-VerificacaoNode 'mock' } | Should Throw 'Falha ficticia'
        $env:PATH | Should BeExactly $before
    }
}

Describe 'Diagnostico por leitura de fixtures' {
    It 'QA-036 projeto nao informado e caminho inexistente tem status distintos' {
        @(QaDiagnostico\Get-DependenciasProjeto '')[0].Status | Should Be 'NAO INFORMADO'
        @(QaDiagnostico\Get-DependenciasProjeto (Join-Path $fixtures 'pasta-inexistente'))[0].Status | Should Be 'CAMINHO INVALIDO'
    }
    It 'QA-037 dependencias Node sao declaracoes sem executar npm' {
        $r = @(QaDiagnostico\Get-DependenciasProjeto (Join-Path $fixtures 'projeto-node'))
        @($r | Where-Object Status -eq 'DECLARADO').Count | Should Be 2
    }
    It 'QA-038 Java apresenta indicios textuais sem executar Maven' {
        $r = @(QaDiagnostico\Get-DependenciasProjeto (Join-Path $fixtures 'projeto-java'))
        @($r | Where-Object Status -eq 'INDICIO ENCONTRADO').Count | Should Be 2
    }
}

Describe 'Fluxo principal em worker isolado e integralmente falso' {
    It 'QA-039 single multiple array Todas e interativo preservados' {
        foreach ($case in @(@('single',1),@('multiple',2),@('array',2),@('all',25),@('interactive',2))) {
            $r = Invoke-QAScenario $worker $case[0]
            $r.Codigo | Should Be 0
            $r.Texto | Should Match "Simulacao concluida: $($case[1]) ferramenta"
            $r.Texto | Should Not Match 'QA_INSTALACAO_FALSA'
        }
    }
    It 'QA-040 tres perfis exibem nome e contagem correta' {
        foreach ($case in @(@('essencial',5),@('apis-bancos',13),@('avancado',15))) {
            $r = Invoke-QAScenario $worker $case[0]
            $r.Codigo | Should Be 0
            $r.Texto | Should Match "Perfil: $($case[0]) \| Ferramentas selecionadas: $($case[1])"
            $r.Texto | Should Not Match 'QA_INSTALACAO_FALSA'
        }
    }
    It 'QA-041 seletores conflitantes perfil e ferramenta invalidos retornam erro' {
        foreach ($case in @('invalid-profile','invalid-tool','conflict')) {
            $r = Invoke-QAScenario $worker $case
            $r.Codigo | Should Be 1
            $r.Texto | Should Not Match 'QA_INSTALACAO_FALSA'
        }
    }
    It 'QA-042 Aplicar instrumentado retorna sucesso cancelamento falha ou pendencia' {
        foreach ($case in @(@('apply-success',0,'SUCESSO'),@('apply-cancel',0,'CANCELADO'),@('apply-failure',1,'FALHA'),@('apply-pending',2,'VERIFICACAO PENDENTE'))) {
            $r = Invoke-QAScenario $worker $case[0]
            $r.Codigo | Should Be $case[1]
            $r.Texto | Should Match "Resultado: $($case[2])"
            if ($case[0] -eq 'apply-cancel') { $r.Texto | Should Not Match 'QA_INSTALACAO_FALSA' }
        }
    }
    It 'QA-043 Aplicar misto existente ou inconclusivo nao chama instalador falso' {
        foreach ($case in @('apply-mixed','apply-existing','apply-inconclusive')) {
            $r = Invoke-QAScenario $worker $case
            $r.Codigo | Should Be 1
            $r.Texto | Should Match 'bloqueado'
            $r.Texto | Should Not Match 'QA_INSTALACAO_FALSA'
        }
    }
}
