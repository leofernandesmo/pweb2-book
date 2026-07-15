# Slides (Reveal.js)

Slides de aula da disciplina **Programação Web 2** (Node/Express), em HTML/CSS/JS com
[Reveal.js](https://revealjs.com). O Reveal está **embutido** em `assets/reveal/` (não
depende de internet — pode apresentar offline em sala).

Publicados junto do site em **`/pweb2-book/slides/`** (índice em `index.html`).

## Estrutura

```
slides/
  index.html              # página inicial com a lista de decks
  README.md               # este arquivo
  assets/
    reveal/               # Reveal.js 5.1 (vendorizado: dist + plugins notes/highlight)
    css/course-theme.css  # identidade visual do curso (verde/âmbar)
  01-revisao-web/index.html   # deck do Capítulo 1
  ...                         # um deck por capítulo (NN-slug/, igual aos capítulos)
```

## Como apresentar

Abra o `index.html` do deck no navegador (duplo clique). Navegação:

- **Setas** / **Espaço**: avançar e voltar
- **Esc** ou **O**: visão geral (grade de slides)
- **S**: modo apresentador (com notas e cronômetro)
- **F**: tela cheia
- **B** ou **.**: escurecer a tela (pausa)

Alguns decks têm slides **verticais** (aprofundamentos): use as setas para baixo.

## Criar um novo deck

Copie `01-revisao-web/index.html` para uma nova pasta `NN-slug/` (o mesmo slug do capítulo
em `docs/chapters/`) e edite o conteúdo. Os caminhos `../assets/...` continuam válidos por
estar um nível abaixo de `slides/`. Depois, ative o cartão correspondente em `index.html`
(remova a classe `pendente` e ajuste o `href`).

## Estilo (Presentation Zen)

- Uma ideia por slide; título curto + apoio visual.
- Pouco texto: frases, não parágrafos. Os detalhes ficam no livro (MkDocs).
- Fundos escuros, código e tabelas como evidência, não como parede de texto.
- Use `<aside class="notes">` para o roteiro do professor (tecla **S**).

## Notas do apresentador

Adicione dentro de uma `<section>`:

```html
<aside class="notes">Texto que só aparece no modo apresentador (tecla S).</aside>
```
