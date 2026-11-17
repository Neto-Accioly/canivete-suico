# Fixtures

Dados fictícios e mínimos. Não representam instalações reais e não são evidências de execução.

- `catalogo-minimo.json`: catálogo válido com ID nulo e perfis independentes.
- `json-invalido.txt`: conteúdo deliberadamente inválido, mantido fora da extensão `.json`.
- `winget-cenarios.json`: tabelas sintéticas com versões, ausência e IDs parecidos.
- `projeto-node/` e `projeto-java/`: manifestos para leitura textual do diagnóstico. Não instalar pacotes, não executar npm nem Maven; versões e POM não servem para build.

Novas fixtures devem remover dados pessoais, tokens, caminhos reais e nomes de máquinas. Não adicionar executáveis, scripts de instalação ou credenciais.
