# Canivete Suíço — NETO-LAB

O Canivete Suíço é um utilitário de diagnóstico do NETO-LAB, voltado à organização e à verificação de um ambiente de estudos e práticas de desenvolvimento e garantia da qualidade de software (QA). Ajuda a identificar ferramentas disponíveis no Windows e a distinguir aplicativos do ambiente das dependências declaradas em cada projeto.

**O projeto está em desenvolvimento. O instalador automático ainda não foi implementado.** O diagnóstico consulta informações e apresenta resultados; não instala programas, altera configurações do Windows ou inicia serviços.

## Requisitos

- Windows 11.
- Windows PowerShell 5.1.
- Permissão de leitura dos arquivos analisados, das chaves do Registro consultadas e das informações de serviços.
- Política de execução do ambiente que permita executar o script. O projeto não altera essa política automaticamente.

As ferramentas monitoradas não precisam estar instaladas: sua ausência é um dos resultados possíveis.

## Categorias monitoradas

| Categoria | Ferramentas e verificações |
| --- | --- |
| Terminal | Git, WinGet, VS Code, Node.js, npm, Java JDK/JRE, compilador Java (`javac`), Maven, Python, TypeScript CLI, k6, Docker CLI, MySQL CLI e MongoDB Shell (`mongosh`). |
| Aplicativo | IntelliJ IDEA, Postman, Insomnia, Mockoon, MySQL Workbench, MySQL Server, MongoDB Server, MongoDB Compass, Docker Desktop, JMeter e GitHub Desktop, conforme os registros de instalação do Windows. |
| Serviço | Serviços com nomes associados a MySQL, MariaDB, MongoDB e SQL Server, incluindo seu estado atual. |
| Dependência do projeto | Dependências Node cujos nomes contenham Playwright, Cypress, TypeScript ou Selenium; indícios de Selenium Java e JUnit no `pom.xml`. |
| Projeto | Presença de `package.json`, `pom.xml` e da pasta `.github\workflows`, além da validação do caminho informado. |

Cliente, servidor e aplicativo gráfico são componentes diferentes. Por exemplo, localizar o cliente MySQL no terminal não confirma a instalação do servidor nem o estado de seu serviço.

## Como executar

Abra o Windows PowerShell 5.1 e acesse a raiz do repositório:

```powershell
Set-Location -LiteralPath 'C:\Dev\canivete-suico'
.\scripts\verificar.ps1
```

Sem parâmetros, o script consulta ferramentas de terminal, aplicativos e serviços. A análise do projeto fica marcada como `NAO INFORMADO`; a pasta atual não é selecionada automaticamente como projeto.

### Parâmetro opcional `-Projeto`

Informe a pasta raiz do projeto que deseja inspecionar:

```powershell
.\scripts\verificar.ps1 -Projeto 'C:\Dev\meu-projeto-qa'
```

Substitua o caminho do exemplo por uma pasta existente. Use aspas em caminhos com espaços. Caminhos relativos são interpretados a partir da pasta atual do PowerShell.

O parâmetro acrescenta a leitura dos manifestos e a verificação da pasta de workflows. Ele não executa testes, instala dependências ou executa comandos do projeto analisado.

## Como interpretar os resultados

A coleta de dados é separada da apresentação. As tabelas são agrupadas por categoria e usam os campos `Nome`, `Categoria`, `Status`, `Versao`, `Caminho`, `Fonte` e `Observacao`.

| Status | Significado |
| --- | --- |
| `ENCONTRADO` | O comando, registro, serviço ou caminho foi localizado pela fonte consultada. |
| `NAO LOCALIZADO` | O item não foi localizado no escopo da consulta; isso não comprova sua ausência em todo o computador. |
| `ERRO NA CONSULTA` | Houve uma falha na leitura ou consulta. Se a consulta ao Registro for incompleta, aplicativos sem correspondência também recebem esse status. Consulte a observação. |
| `NAO INFORMADO` | O parâmetro `-Projeto` não foi fornecido ou está vazio. |
| `CAMINHO INVALIDO` | O caminho informado não existe ou não aponta para uma pasta. |
| `DECLARADO` | Uma dependência foi encontrada no manifesto Node; sua instalação não foi confirmada. |
| `INDICIO ENCONTRADO` | Um texto associado à dependência foi encontrado no manifesto Maven; exige confirmação. |

O valor `-` indica informação não obtida ou não verificada, inclusive versões.

## Limitações atuais

- **Terminal:** a descoberta depende do ambiente de busca de comandos da sessão. Localizar um executável não confirma funcionamento ou versão. Instalações fora desse alcance podem não aparecer; apenas o primeiro comando encontrado é apresentado por ferramenta.
- **Aplicativos:** a consulta usa chaves de desinstalação do Registro em `HKLM` e `HKCU`. Instalações portáteis ou sem registro nessas chaves podem passar despercebidas. Versão e caminho dependem dos metadados registrados. Múltiplos registros podem gerar múltiplos resultados.
- **Versões:** aplicativos exibem a versão informada pelo Registro. Dependências Node exibem o valor declarado, que pode ser uma faixa ou referência, e não uma versão exata instalada. Versões de executáveis e dependências Maven ainda não são identificadas.
- **Dependências Node:** somente `dependencies` e `devDependencies` do `package.json` da pasta informada são analisadas, por correspondência parcial dos nomes. Arquivos de lock, `node_modules`, dependências transitivas, navegadores do Playwright e binários do Cypress não são verificados.
- **Maven:** a busca por `selenium-java` e `junit` é textual e pode encontrar comentários. Não há resolução de propriedades, herança, perfis ou dependências transitivas.
- **Serviços:** a identificação depende de padrões de nome. O estado do serviço não confirma conectividade, autenticação ou funcionamento do banco. Bancos remotos ou em contêineres não são inspecionados por essa verificação.
- **GitHub Actions:** somente a existência da pasta `.github\workflows` é verificada; seus arquivos e sua validade não são analisados.
- **Escopo:** não há busca recursiva por subprojetos. Erros de acesso são apresentados como falhas de consulta. O relatório é exibido no terminal, sem exportação estruturada ou código de saída específico para falhas do diagnóstico.

Melhorias na identificação de versões, na descoberta de instalações e na análise das dependências ficam para etapas futuras. Nenhuma instalação automática está disponível nesta versão.
