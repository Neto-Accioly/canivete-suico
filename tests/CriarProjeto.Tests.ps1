#requires -Version 5.1
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'TestSupport.ps1')
Import-QAFunctions (Join-Path $repo 'scripts\criar-projeto.ps1') 'QaProjeto'

Describe 'Estrutura didatica e caminhos controlados' {
    BeforeEach {
        Mock Get-AmbienteProjeto { [PSCustomObject]@{Node='fixture/node.exe';Npm='fixture/npm.cmd';VersaoNode='26.0.0';PodeInstalar=$true} } -ModuleName QaProjeto
        Mock Get-NavegadoresProjeto { [PSCustomObject]@{Cache='fixture';Diretorios=@('chromium-ficticio');Nota='Somente fixture'} } -ModuleName QaProjeto
    }
    It 'PRJ-001 nomes e destinos invalidos sao rejeitados' {
        foreach($name in @('../fora','con','nome com espaco','UpperCase','a:b')) {
            { QaProjeto\Resolve-RaizProjeto $name $TestDrive } | Should Throw
        }
        { QaProjeto\Resolve-RaizProjeto 'aluno' 'C:relativo' } | Should Throw
        { QaProjeto\Resolve-RaizProjeto 'aluno' '\\servidor\pasta' } | Should Throw
        { QaProjeto\Assert-RotaProjeto 'C:\fixture\aluno' 'C:\fixture\aluno-outro\x' } | Should Throw
    }
    It 'PRJ-002 junctions sao rejeitadas sem criar links reais' {
        # Modulo separado: mocks de leitores nao vazam para os outros casos.
        Import-QAFunctions (Join-Path $repo 'scripts\criar-projeto.ps1') 'QaProjetoLink'
        Mock Test-Path { $true } -ModuleName QaProjetoLink
        Mock Get-Item { [PSCustomObject]@{Attributes=[IO.FileAttributes]::ReparsePoint;PSIsContainer=$true} } -ModuleName QaProjetoLink
        { QaProjetoLink\Resolve-RaizProjeto 'aluno' 'C:\fixture' } | Should Throw 'Link/junction'
    }
    It 'PRJ-003 somente sete arquivos basicos sem exercicios sao propostos' {
        $p = QaProjeto\Get-PlanoProjeto 'aluno' (Join-Path $TestDrive 'aluno')
        $p.Itens.Count | Should Be 7
        @($p.Itens | Where-Object {$_.Relativo -match '\.spec\.|page.?objects?|^\.git/'}).Count | Should Be 0
        ($p.Itens | Where-Object Relativo -eq 'playwright.config.ts').Depois | Should Not Match '\bexpect\(|\btest\('
        ($p.Itens | Where-Object Relativo -eq 'tsconfig.json').Depois | ConvertFrom-Json | Out-Null
        ($p.Itens | Where-Object Relativo -eq 'package.json').Depois | ConvertFrom-Json | Out-Null
    }
    It 'PRJ-004 package existente preserva metadados dependencias e script do aluno' {
        $root=Join-Path $TestDrive 'existente'
        [void][IO.Directory]::CreateDirectory($root)
        Copy-Item (Join-Path $PSScriptRoot 'fixtures\projeto-playwright\package.json') (Join-Path $root 'package.json')
        $p=QaProjeto\Get-PlanoProjeto 'existente' (Join-Path $TestDrive 'existente')
        $item=$p.Itens | Where-Object Relativo -eq 'package.json'
        $item.Acao | Should Be 'REVISAR'
        $candidate=$item.Depois | ConvertFrom-Json
        $candidate.scripts.test | Should Be 'echo fixture-sem-testes'
        $candidate.type | Should Be 'commonjs'
        $candidate.license | Should Be 'ISC'
        $candidate.devDependencies.'@playwright/test' | Should Be '^1.65.1'
        $candidate.scripts.'test:e2e' | Should Be 'playwright test'
    }
    It 'PRJ-005 segunda execucao nao duplica arquivos nem muda plano igual' {
        $p=QaProjeto\Get-PlanoProjeto 'repetido' (Join-Path $TestDrive 'repetido')
        foreach($item in $p.Itens){
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Caminho))
            [IO.File]::WriteAllText($item.Caminho,$item.Depois,(New-Object Text.UTF8Encoding($false)))
        }
        $again=QaProjeto\Get-PlanoProjeto 'repetido' (Join-Path $TestDrive 'repetido')
        @($again.Itens | Where-Object Acao -ne 'MANTER').Count | Should Be 0
        @(Get-ChildItem -LiteralPath $p.Raiz -File -Recurse).Count | Should Be 7
    }
    It 'PRJ-006 manifestos invalidos e colisoes arquivo-pasta bloqueiam' {
        $root=Join-Path $TestDrive 'invalido'
        [void][IO.Directory]::CreateDirectory($root)
        [IO.File]::WriteAllText((Join-Path $root 'package.json'),'{invalido')
        { QaProjeto\Get-PlanoProjeto 'invalido' (Join-Path $TestDrive 'invalido') } | Should Throw
        [IO.File]::WriteAllText((Join-Path $TestDrive 'ocupado'),'fixture')
        { QaProjeto\Resolve-RaizProjeto 'ocupado' (Join-Path $TestDrive 'ocupado') } | Should Throw 'arquivo'
    }
    It 'PRJ-007 Playwright instalado e detectado por leitura sem npm' {
        $root=Join-Path $TestDrive 'deps'
        $dir=Join-Path $root 'node_modules\@playwright\test'
        [void][IO.Directory]::CreateDirectory($dir)
        [IO.File]::WriteAllText((Join-Path $dir 'package.json'),'{"name":"@playwright/test","version":"1.65.1"}')
        $r=@(QaProjeto\Get-DependenciasProjeto $root)
        ($r | Where-Object Nome -eq '@playwright/test').Instalada | Should Be $true
        @($r | Where-Object {-not $_.Instalada}).Count | Should Be 2
    }
    It 'PRJ-008 IO e npm permanecem bloqueados sem mock' {
        { QaProjeto\New-PastaProjeto 'C:\fixture' 'C:\fixture\aluno' } | Should Throw 'BARREIRA_QA'
        { QaProjeto\Write-ArquivoProjeto 'C:\fixture' $null } | Should Throw 'BARREIRA_QA'
        { QaProjeto\Invoke-DependenciasProjeto $null @() } | Should Throw 'BARREIRA_QA'
    }
    It 'PRJ-009 guardas de escrita protegem arquivo novo e alterado apos diff' {
        $source=Get-Content (Join-Path $repo 'scripts\criar-projeto.ps1') -Raw -Encoding UTF8
        $source | Should Match '\[IO.FileMode\]::CreateNew'
        $source | Should Match 'Hash -ne \$Item.HashAntes'
        $source | Should Match '\[IO.File\]::Replace'
    }
    It 'PRJ-010 comandos nao inicializam Git nem instalam browsers e ignoram lifecycle' {
        $source=Get-Content (Join-Path $repo 'scripts\criar-projeto.ps1') -Raw -Encoding UTF8
        $source | Should Match "'--ignore-scripts'"
        $source | Should Not Match '(?m)^\s*(?:&\s+)?(?:git\s+init|npx\s+|playwright\s+install)'
        $argsNpm=@(QaProjeto\Get-ArgumentosNpmProjeto @([PSCustomObject]@{Nome='typescript';Declarada='^5.0.0'}))
        $argsNpm[-1] | Should Be 'typescript@^5.0.0'
        { QaProjeto\Get-ArgumentosNpmProjeto @() } | Should Throw
        { QaProjeto\Get-ArgumentosNpmProjeto @([PSCustomObject]@{Nome='typescript';Declarada='x & comando'}) } | Should Throw
    }
    It 'PRJ-021 destino final existente nao duplica Nome e detecta projeto correto' {
        $root=Join-Path $TestDrive 'qa-playwright'
        [void][IO.Directory]::CreateDirectory((Join-Path $root 'node_modules\@playwright\test'))
        Copy-Item (Join-Path $PSScriptRoot 'fixtures\projeto-playwright\package.json') (Join-Path $root 'package.json')
        [IO.File]::WriteAllText((Join-Path $root 'package-lock.json'),'{"lockfileVersion":3}')
        [IO.File]::WriteAllText((Join-Path $root 'node_modules\@playwright\test\package.json'),'{"name":"@playwright/test","version":"1.65.1"}')
        $before=(Get-FileHash (Join-Path $root 'package.json')).Hash
        $p=QaProjeto\Get-PlanoProjeto 'qa-playwright' $root
        $p.Raiz | Should Be $root
        $p.Raiz | Should Not Match 'qa-playwright[\\/]qa-playwright'
        $p.Existente.PackageJson | Should Be $true
        $p.Existente.PackageLock | Should Be $true
        $p.Existente.NodeModules | Should Be $true
        ($p.Dependencias | Where-Object Nome -eq '@playwright/test').Instalada | Should Be $true
        ($p.Dependencias | Where-Object Nome -eq '@playwright/test').Versao | Should Be '1.65.1'
        (Get-FileHash (Join-Path $root 'package.json')).Hash | Should Be $before
    }
    It 'PRJ-022 projeto novo usa Destino exato e Nome somente como metadado' {
        $root=Join-Path $TestDrive 'pasta-final'
        $p=QaProjeto\Get-PlanoProjeto 'identificacao' $root
        $p.Raiz | Should Be $root
        (($p.Itens | Where-Object Relativo -eq 'package.json').Depois | ConvertFrom-Json).name | Should Be 'identificacao'
        @($p.Itens | Where-Object Acao -eq 'CRIAR').Count | Should Be 7
        (Test-Path -LiteralPath $root) | Should Be $false
    }
    It 'PRJ-023 relativos usam localizacao PowerShell e equivalem ao absoluto' {
        Push-Location -LiteralPath $TestDrive
        try {
            $expected=Join-Path $TestDrive 'relativo'
            (QaProjeto\Resolve-RaizProjeto 'identificacao' '.\relativo') | Should Be $expected
            (QaProjeto\Resolve-RaizProjeto 'outro-nome' 'sub/../relativo/') | Should Be $expected
            (QaProjeto\Resolve-RaizProjeto 'outro-nome' $expected) | Should Be $expected
        }
        finally { Pop-Location }
    }
    It 'PRJ-024 caminhos ambiguos provedores ADS e raiz de disco sao rejeitados' {
        foreach($dest in @('',' ', 'C:relativo', '\ambigua', '\\servidor\share',
            'HKLM:\Software', 'C:\fixture:stream', 'C:\fixture\pasta.', 'C:\fixture\con', 'C:\')) {
            { QaProjeto\Resolve-RaizProjeto 'aluno' $dest } | Should Throw
        }
    }
}

Describe 'Autorizacoes e falhas com IO e npm falsos' {
    BeforeEach {
        Mock Write-Host { } -ModuleName QaProjeto
        Mock Get-AmbienteProjeto { [PSCustomObject]@{Node='fixture/node.exe';Npm='fixture/npm.cmd';PodeInstalar=$true} } -ModuleName QaProjeto
        Mock Get-NavegadoresProjeto { [PSCustomObject]@{Cache='fixture';Diretorios=@();Nota='Fixture'} } -ModuleName QaProjeto
        Mock Confirm-AcaoProjeto { $true } -ModuleName QaProjeto
        Mock Confirm-AcaoProjeto { $true } -ModuleName QaProjeto -ParameterFilter {$Frase -like 'SUBSTITUIR *'}
        Mock Confirm-AcaoProjeto { $true } -ModuleName QaProjeto -ParameterFilter {$Frase -like 'INSTALAR DEPENDENCIAS *'}
        Mock New-PastaProjeto { } -ModuleName QaProjeto
        Mock Write-ArquivoProjeto { } -ModuleName QaProjeto
        Mock Show-DiffProjeto { } -ModuleName QaProjeto
        Mock Invoke-DependenciasProjeto { 0 } -ModuleName QaProjeto
        Mock Get-DependenciasProjeto { @([PSCustomObject]@{Nome='@playwright/test';Instalada=$true;Declarada='';Versao='1.65.1'}) } -ModuleName QaProjeto
    }
    It 'PRJ-011 simulacao nunca confirma escreve ou instala' {
        $p=QaProjeto\Get-PlanoProjeto 'simulado' (Join-Path $TestDrive 'simulado')
        (QaProjeto\Invoke-PreparacaoProjeto $p).Status | Should Be 'SIMULACAO'
        Assert-MockCalled Confirm-AcaoProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
        Assert-MockCalled Write-ArquivoProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-012 cancelamento da estrutura impede qualquer escrita ou npm' {
        Mock Confirm-AcaoProjeto { $false } -ModuleName QaProjeto
        $p=QaProjeto\Get-PlanoProjeto 'cancelado' (Join-Path $TestDrive 'cancelado')
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Status | Should Be 'CANCELADO'
        Assert-MockCalled New-PastaProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-013 criacao autorizada nao reinstala dependencia presente' {
        $p=QaProjeto\Get-PlanoProjeto 'criado' (Join-Path $TestDrive 'criado')
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Codigo | Should Be 0
        Assert-MockCalled Write-ArquivoProjeto -ModuleName QaProjeto -Scope It -Times 7 -Exactly
        Assert-MockCalled Confirm-AcaoProjeto -ModuleName QaProjeto -Scope It -Times 1 -Exactly
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-014 dependencia exige autorizacao separada e pode ser cancelada' {
        Mock Get-DependenciasProjeto { @([PSCustomObject]@{Nome='typescript';Instalada=$false;Declarada=''}) } -ModuleName QaProjeto
        Mock Confirm-AcaoProjeto { $false } -ModuleName QaProjeto -ParameterFilter {$Frase -like 'INSTALAR DEPENDENCIAS *'}
        $p=QaProjeto\Get-PlanoProjeto 'separado' (Join-Path $TestDrive 'separado')
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Status | Should Match 'DEPENDENCIAS_CANCELADAS'
        Assert-MockCalled Confirm-AcaoProjeto -ModuleName QaProjeto -Scope It -Times 2 -Exactly
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-015 recusar substituicao preserva arquivo e bloqueia npm' {
        Mock Confirm-AcaoProjeto { $false } -ModuleName QaProjeto -ParameterFilter {$Frase -like 'SUBSTITUIR *'}
        $p=QaProjeto\Get-PlanoProjeto 'preservado' (Join-Path $TestDrive 'preservado')
        $p.Itens=@($p.Itens[0]);$p.Itens[0].Acao='REVISAR'
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Codigo | Should Be 2
        Assert-MockCalled Show-DiffProjeto -ModuleName QaProjeto -Scope It -Times 1 -Exactly
        Assert-MockCalled Write-ArquivoProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-016 aceitar substituicao exige diff e aprovacao individual' {
        $p=QaProjeto\Get-PlanoProjeto 'diff' (Join-Path $TestDrive 'diff')
        $p.Itens=@($p.Itens[0]);$p.Itens[0].Acao='REVISAR'
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Codigo | Should Be 0
        Assert-MockCalled Show-DiffProjeto -ModuleName QaProjeto -Scope It -Times 1 -Exactly
        Assert-MockCalled Confirm-AcaoProjeto -ModuleName QaProjeto -Scope It -Times 1 -Exactly -ParameterFilter {$Frase -eq 'SUBSTITUIR package.json'}
    }
    It 'PRJ-017 falha de escrita interrompe antes de npm' {
        Mock Write-ArquivoProjeto { throw 'Falha de IO ficticia' } -ModuleName QaProjeto
        $p=QaProjeto\Get-PlanoProjeto 'falha' (Join-Path $TestDrive 'falha')
        { QaProjeto\Invoke-PreparacaoProjeto $p $true } | Should Throw 'Falha de IO'
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-018 falha npm e reportada sem repeticao' {
        Mock Get-DependenciasProjeto { @([PSCustomObject]@{Nome='typescript';Instalada=$false;Declarada=''}) } -ModuleName QaProjeto
        Mock Invoke-DependenciasProjeto { 7 } -ModuleName QaProjeto
        $p=QaProjeto\Get-PlanoProjeto 'npm-falha' (Join-Path $TestDrive 'npm-falha')
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Codigo | Should Be 1
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 1 -Exactly
    }
    It 'PRJ-019 sem Node/npm confirmado cria apenas estrutura e pede revisao' {
        Mock Get-DependenciasProjeto { @([PSCustomObject]@{Nome='typescript';Instalada=$false;Declarada=''}) } -ModuleName QaProjeto
        Mock Get-AmbienteProjeto { [PSCustomObject]@{PodeInstalar=$false;Node='';Npm=''} } -ModuleName QaProjeto
        $p=QaProjeto\Get-PlanoProjeto 'sem-node' (Join-Path $TestDrive 'sem-node')
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Status | Should Match 'EXIGEM_REVISAO'
        Assert-MockCalled Invoke-DependenciasProjeto -ModuleName QaProjeto -Scope It -Times 0 -Exactly
    }
    It 'PRJ-020 npm zero sem pacotes locais gera verificacao pendente' {
        Mock Get-DependenciasProjeto { @([PSCustomObject]@{Nome='typescript';Instalada=$false;Declarada=''}) } -ModuleName QaProjeto
        $p=QaProjeto\Get-PlanoProjeto 'pendente' (Join-Path $TestDrive 'pendente')
        (QaProjeto\Invoke-PreparacaoProjeto $p $true).Status | Should Be 'DEPENDENCIAS_VERIFICACAO_PENDENTE'
    }
}
