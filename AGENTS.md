# Trabalho e QA neste repositório

- Preserve alterações do usuário. Não faça commit ou push sem autorização.
- Ao modificar funcionalidades, atualize os casos correspondentes em `docs/plano-testes.md`, os testes em `tests/` e o registro em `docs/historico-execucoes.md`. Registre defeitos reproduzidos em `docs/defeitos.md`; não declare correção sem regressão.
- Leia `docs/qa.md` antes de executar a suíte. Use `scripts/testar.ps1` com Pester local; não instale dependências automaticamente.
- Nunca execute instalações reais, upgrades, remoções ou `-Aplicar` não instrumentado para validar alterações. Nos testes, mantenha as barreiras nativas de `tests/TestSupport.ps1` e os mocks isolados do worker.
- Preserve Windows PowerShell 5.1. Não altere política de execução persistente, PATH persistente, Registro ou serviços para testar.
- Separe resultados comprovados por artefatos, observações da sessão, relatos e cenários não executados. Fixtures são dados fictícios, nunca evidências de instalações reais.
- Relatórios brutos ficam em `evidencias/execucoes/`, ignorados pelo Git. Antes de versionar um resumo em `evidencias/resumos/`, confira que não contém usuário, hostname, PATH, credenciais ou caminhos absolutos.
- Preserve XML/JSON originais localmente. Registre sanitização e proveniência em uma cópia derivada; nunca edite o original para publicá-lo.
- Classifique execuções como MOCKADO, REAL_CONTROLADO, MANUAL ou NAO_EXECUTADO. A suíte atual é globalmente MOCKADO, mas inclui análise estática e leitura controlada de arquivos reais; técnicas individuais não a transformam em validação de instalação real.
- Só associe commit de origem quando houver prova. HEAD observado durante revisão não prova qual commit foi testado; para fontes não commitadas, use SHA256 e commit de origem null.
- Ao preparar QA para versionamento, use a lista revisada de `docs/versionamento-qa.md`. Não inclua alterações anteriores de produção sem revisão específica; não use adição indiscriminada ou force arquivos ignorados.
