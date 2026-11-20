# Nexora Tech

Nova identidade do aplicativo: tecnologia, conexão e notícias.
O símbolo reúne um N geométrico, terminal de circuito e pequena página de notícias.
Paleta: grafite, verde-lima e ciano.

- nexora-tech-symbol-original.png: arte original gerada por imagegen, preservada.
- nexora-tech-logo.png: apresentação com nome e símbolo.
- nexora-tech-logo-transparent.png: assinatura com fundo externo transparente.
- nexora-tech-logo.svg: tipografia em contornos com símbolo raster incorporado.
- nexora-tech-icon.png: ícone para prévia.

Geração: ferramenta image_gen integrada, seguida de exportação dos recursos nativos.
O gerador usa Resvg/PNG e fonte Segoe UI Bold local; nenhum arquivo de fonte é distribuído.
Para regenerar os tamanhos: node tools/branding/generate.mjs, na raiz do projeto.
A versão anterior permanece em brand/fionova e tools/branding/generate-fionova.mjs.

Prompt final: recriar um ícone limpo sobre grafite, com N verde-lima geométrico,
terminal de circuito ciano e pequena notícia dobrada, sem texto no símbolo.
Os SVGs de assinatura incorporam o PNG; o símbolo não foi vetorizado manualmente.

Nome público alterado para Nexora Tech, preservando package ID, URLs e schema do banco.
O nome no consentimento Google deve ser atualizado em Google Auth Platform > Branding.

Prompt completo utilizado: [prompt.txt](prompt.txt).
