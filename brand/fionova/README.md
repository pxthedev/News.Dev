# Fionova

Proposta de nome que combina fio de informação com nova: novidade e inovação.
O F geométrico usa recortes digitais e um pequeno terminal de circuito. O jornal
com dobra em ciano identifica a proposta de notícias sem competir com o monograma.

## Arquivos

- `fionova-brand-preview.png`: apresentação visual da marca.
- `fionova-logo-horizontal.svg`: assinatura com nome, em curvas e fundo transparente.
- `fionova-logo-on-light.svg`: assinatura para fundos claros.
- `fionova-symbol.svg`: símbolo vetorial editável.
- `fionova-app-icon.svg`: ícone quadrado com fundo grafite.
- `fionova-symbol.png`: símbolo com transparência.
- `palette.json`: cores da identidade.

Grafite #10141E, verde-lima #D4FF3A, ciano #57DEED, branco #F5F7FA.

## Regenerar

Na raiz do projeto, execute `npm ci --prefix tools/branding` e
`node tools/branding/generate.mjs`. O script atualiza as exportações e os ícones
Android, iOS e web. Usa Segoe UI Bold instalada no Windows para converter o nome
em curvas; a fonte não é distribuída. Uma fonte alternativa pode ser indicada
pela variável `BRAND_FONT` com o caminho de um arquivo TTF.

O nome visível foi atualizado, mantendo os identificadores técnicos do app para
compatibilidade com instalações existentes.
