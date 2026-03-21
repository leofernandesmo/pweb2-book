# Capítulo 6 — Renderização no Servidor com EJS

---

## 6.1 Introdução

Até este ponto do curso, o Express foi utilizado exclusivamente como motor de uma API REST: todas as rotas respondem com JSON, e a responsabilidade de construir a interface visual é delegada integralmente ao cliente. Essa arquitetura — denominada *Single Page Application* (SPA) — é hoje predominante em projetos de grande porte, mas não é a única nem, necessariamente, a mais adequada para todos os casos.

A **renderização no servidor** (*Server-Side Rendering*, ou SSR) é a abordagem histórica da Web e continua sendo a escolha mais prática em uma série de contextos: painéis administrativos internos, protótipos rápidos, sistemas de conteúdo sem equipe de frontend dedicada, ou situações em que SEO (*Search Engine Optimization*) e tempo de carregamento inicial são critérios críticos. Nessa abordagem, o servidor monta o HTML completo antes de enviá-lo ao navegador — o cliente recebe uma página pronta para exibição, sem depender de JavaScript para construir a interface.

Este capítulo apresenta o **EJS** (*Embedded JavaScript Templates*), o motor de templates mais direto e amplamente utilizado no ecossistema Express. Ao final, o leitor será capaz de configurar o EJS em um projeto Express existente, construir templates com layouts e componentes reutilizáveis, processar formulários HTML, validar dados de entrada e fornecer feedback visual de erro e sucesso ao usuário — tudo isso sem uma linha de código de frontend separado.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o Capítulo 3 (Express: rotas, middlewares e controllers) e o Capítulo 4 (arquitetura em camadas). O conhecimento de HTML e CSS básico é necessário para acompanhar os exemplos de templates.

---

## 6.2 SSR vs. SPA: quando usar cada abordagem

Antes de escrever qualquer código, vale estabelecer com clareza o que diferencia as duas arquiteturas e em que situações cada uma é mais adequada.

### 6.2.1 Como funciona a renderização no servidor

Em uma aplicação SSR clássica, o fluxo de uma requisição é o seguinte: o navegador solicita uma URL ao servidor; o servidor executa a lógica necessária (consulta ao banco, validação de autenticação, preparação dos dados), combina esses dados com um template HTML e devolve o documento HTML completo ao navegador. O navegador então renderiza esse HTML diretamente, sem precisar executar JavaScript para montar a interface.

Esse modelo tem implicações importantes. O navegador exibe conteúdo imediatamente ao receber a resposta — não há uma tela em branco enquanto o JavaScript é carregado e executa suas requisições iniciais à API. Além disso, motores de busca indexam o HTML completo sem dificuldade, o que favorece o SEO. A contrapartida é que cada navegação para uma nova página implica uma requisição completa ao servidor e o carregamento de um novo documento HTML.

### 6.2.2 Como funciona uma SPA

Em uma SPA, o servidor entrega um documento HTML mínimo — essencialmente uma casca vazia com uma tag `<div id="app">` e referências a arquivos JavaScript. O framework de frontend (React, Vue, Angular) assume o controle no navegador, faz requisições à API para obter dados e constrói a interface dinamicamente. As navegações subsequentes são interceptadas pelo roteador do frontend, que troca apenas os componentes relevantes sem recarregar a página.

O resultado é uma experiência mais fluida para o usuário após o carregamento inicial, mas às custas de um tempo de carregamento inicial maior e de maior complexidade no projeto — é necessário manter um servidor de API e uma aplicação de frontend como entidades separadas.

### 6.2.3 Comparativo e critérios de escolha

| Critério | SSR (EJS + Express) | SPA (React/Vue + API) |
|---|---|---|
| SEO | Excelente | Requer configuração extra |
| Tempo de carregamento inicial | Rápido | Mais lento (bundle JS) |
| Experiência de navegação | Recarregamentos de página | Fluida (sem recarregar) |
| Complexidade do projeto | Baixa (um único servidor) | Alta (dois projetos separados) |
| Adequado para | Admin panels, MVPs, CMS | Dashboards interativos, apps complexos |
| Equipe necessária | Backend apenas | Backend + Frontend |

A escolha não é excludente: aplicações híbridas — como Next.js para React e Nuxt para Vue — combinam SSR e SPA, renderizando o HTML inicial no servidor e assumindo o controle no cliente após o carregamento. Esse modelo é abordado no Capítulo 7. Por ora, o foco é na SSR pura com EJS.

---

## 6.3 Configurando EJS no Express

### 6.3.1 Instalação

O EJS é um pacote npm independente. A instalação é feita com um único comando:

```bash
npm install ejs
```

Nenhuma configuração adicional é necessária além de informar ao Express que o EJS é o motor de templates a ser utilizado.

### 6.3.2 Configuração do Express

Duas linhas são suficientes para habilitar o EJS em uma aplicação Express existente:

```javascript
// src/app.js
import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join }  from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const app = express();

// ── Motor de templates ──────────────────────────────────
app.set('view engine', 'ejs');
app.set('views', join(__dirname, 'views')); // diretório dos templates

// ── Middlewares ─────────────────────────────────────────
app.use(express.urlencoded({ extended: true })); // parse de formulários HTML
app.use(express.json());
app.use(express.static(join(__dirname, '..', 'public'))); // arquivos estáticos

export default app;
```

!!! note "ESM e `__dirname`"
    Em módulos ES (`"type": "module"` no `package.json`), as variáveis `__dirname` e `__filename` não estão disponíveis nativamente. A combinação `dirname(fileURLToPath(import.meta.url))` reproduz o comportamento equivalente ao CommonJS.

### 6.3.3 Estrutura de diretórios

A estrutura recomendada para um projeto Express com EJS é a seguinte:

```
minha-app/
├── public/
│   ├── css/
│   │   └── styles.css          # Folha de estilos global
│   └── js/
│       └── main.js             # JavaScript do cliente (opcional)
├── src/
│   ├── controllers/
│   ├── routes/
│   ├── services/
│   ├── views/
│   │   ├── partials/
│   │   │   ├── header.ejs      # Cabeçalho reutilizável
│   │   │   ├── footer.ejs      # Rodapé reutilizável
│   │   │   └── navbar.ejs      # Barra de navegação
│   │   ├── layouts/
│   │   │   └── base.ejs        # Layout principal
│   │   ├── usuarios/
│   │   │   ├── index.ejs       # Listagem de usuários
│   │   │   ├── show.ejs        # Detalhe de um usuário
│   │   │   ├── new.ejs         # Formulário de criação
│   │   │   └── edit.ejs        # Formulário de edição
│   │   └── index.ejs           # Página inicial
│   └── app.js
├── server.js
└── package.json
```

### 6.3.4 Renderizando a primeira view

Com o Express configurado, a renderização de um template é feita com `res.render()`. O primeiro argumento é o caminho do arquivo (relativo ao diretório `views`, sem a extensão `.ejs`); o segundo é um objeto com os dados que serão disponibilizados ao template:

```javascript
// src/routes/index.routes.js
import { Router } from 'express';

const router = Router();

router.get('/', (req, res) => {
  res.render('index', {
    titulo:   'Bem-vindo',
    mensagem: 'Aplicação Express com EJS funcionando.',
  });
});

export default router;
```

```html
<!-- src/views/index.ejs -->
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title><%= titulo %></title>
</head>
<body>
  <h1><%= titulo %></h1>
  <p><%= mensagem %></p>
</body>
</html>
```

A tag `<%= expressão %>` avalia a expressão JavaScript e insere o resultado no HTML, escapando automaticamente caracteres especiais para prevenir XSS. Essa é a tag de saída padrão e a mais utilizada.

---

## 6.4 Sintaxe EJS

O EJS introduz um conjunto pequeno e intuitivo de tags que permitem incorporar lógica JavaScript diretamente no HTML.

### 6.4.1 Tags essenciais

| Tag | Comportamento |
|---|---|
| `<%= expressão %>` | Avalia e insere o valor com escape HTML (seguro) |
| `<%- expressão %>` | Avalia e insere o valor **sem** escape (para HTML literal) |
| `<% código %>` | Executa código JavaScript sem produzir saída |
| `<%# comentário %>` | Comentário — não é enviado ao cliente |
| `<%- include('parcial') %>` | Inclui outro arquivo EJS |

```html
<!-- Saída com escape (padrão — use para dados do usuário) -->
<p>Olá, <%= usuario.nome %></p>

<!-- Saída sem escape (use apenas para HTML confiável) -->
<div><%- conteudoHtml %></div>

<!-- Código JavaScript (condicionais, loops) -->
<% if (usuario.admin) { %>
  <span class="badge">Administrador</span>
<% } %>

<!-- Loop sobre array -->
<ul>
  <% produtos.forEach(produto => { %>
    <li><%= produto.nome %> — R$ <%= produto.preco.toFixed(2) %></li>
  <% }); %>
</ul>

<!-- Comentário (não aparece no HTML enviado) -->
<%# Esta linha não será enviada ao navegador %>
```

### 6.4.2 Condicionais e loops

O EJS não introduz uma sintaxe própria para condicionais e loops — utiliza diretamente o JavaScript. Isso é ao mesmo tempo sua maior vantagem (sem nova sintaxe para aprender) e seu principal risco (lógica de negócio pode vazar para os templates). A regra é: templates devem conter apenas lógica de apresentação; toda lógica de negócio pertence ao service.

```html
<!-- Renderização condicional -->
<% if (flash && flash.tipo === 'erro') { %>
  <div class="alerta alerta-erro">
    <p><%= flash.mensagem %></p>
  </div>
<% } else if (flash && flash.tipo === 'sucesso') { %>
  <div class="alerta alerta-sucesso">
    <p><%= flash.mensagem %></p>
  </div>
<% } %>

<!-- Verificação de array vazio -->
<% if (usuarios.length === 0) { %>
  <p class="vazio">Nenhum usuário cadastrado.</p>
<% } else { %>
  <table>
    <thead>
      <tr><th>Nome</th><th>E-mail</th><th>Ações</th></tr>
    </thead>
    <tbody>
      <% usuarios.forEach(u => { %>
        <tr>
          <td><%= u.nome %></td>
          <td><%= u.email %></td>
          <td>
            <a href="/usuarios/<%= u.id %>/edit">Editar</a>
            <form method="POST" action="/usuarios/<%= u.id %>?_method=DELETE" style="display:inline">
              <button type="submit">Excluir</button>
            </form>
          </td>
        </tr>
      <% }); %>
    </tbody>
  </table>
<% } %>
```

---

## 6.5 Layouts e Partials

À medida que a aplicação cresce, repetir o `<head>`, a navbar e o rodapé em cada template torna-se impraticável. O EJS resolve isso com **partials** — fragmentos de template reutilizáveis incluídos com a tag `<%- include() %>`.

### 6.5.1 Criando partials

```html
<!-- src/views/partials/header.ejs -->
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><%= typeof titulo !== 'undefined' ? titulo : 'Minha App' %></title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
```

```html
<!-- src/views/partials/navbar.ejs -->
<nav class="navbar">
  <a href="/" class="navbar-brand">Minha App</a>
  <ul class="navbar-links">
    <li><a href="/usuarios">Usuários</a></li>
    <li><a href="/produtos">Produtos</a></li>
  </ul>
</nav>
```

```html
<!-- src/views/partials/footer.ejs -->
  <footer class="footer">
    <p>&copy; <%= new Date().getFullYear() %> Minha App</p>
  </footer>
</body>
</html>
```

### 6.5.2 Usando partials nos templates

Com os partials criados, qualquer template pode incluí-los com `<%- include() %>`. O caminho é relativo ao arquivo que faz a inclusão:

```html
<!-- src/views/usuarios/index.ejs -->
<%- include('../partials/header', { titulo: 'Usuários' }) %>
<%- include('../partials/navbar') %>

<main class="container">
  <div class="page-header">
    <h1>Usuários</h1>
    <a href="/usuarios/new" class="btn btn-primary">Novo Usuário</a>
  </div>

  <% if (usuarios.length === 0) { %>
    <p class="empty-state">Nenhum usuário cadastrado ainda.</p>
  <% } else { %>
    <table class="table">
      <thead>
        <tr><th>Nome</th><th>E-mail</th><th></th></tr>
      </thead>
      <tbody>
        <% usuarios.forEach(u => { %>
          <tr>
            <td><%= u.nome %></td>
            <td><%= u.email %></td>
            <td class="actions">
              <a href="/usuarios/<%= u.id %>">Ver</a>
              <a href="/usuarios/<%= u.id %>/edit">Editar</a>
            </td>
          </tr>
        <% }); %>
      </tbody>
    </table>
  <% } %>
</main>

<%- include('../partials/footer') %>
```

### 6.5.3 Layout com conteúdo dinâmico

Para projetos maiores, uma estratégia mais robusta é criar um partial de layout que recebe o conteúdo da página como variável. O pacote `express-ejs-layouts` formaliza esse padrão:

```bash
npm install express-ejs-layouts
```

```javascript
// src/app.js
import expressLayouts from 'express-ejs-layouts';

app.use(expressLayouts);
app.set('layout', 'layouts/base'); // layout padrão
```

```html
<!-- src/views/layouts/base.ejs -->
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title><%= typeof titulo !== 'undefined' ? titulo : 'Minha App' %></title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <%- include('../partials/navbar') %>

  <main class="container">
    <%- body %>   <!-- O conteúdo de cada página é injetado aqui -->
  </main>

  <%- include('../partials/footer') %>
</body>
</html>
```

Com o layout configurado, cada view passa a conter apenas seu próprio conteúdo — sem repetir o `<head>` e o `<body>`:

```html
<!-- src/views/usuarios/index.ejs — só o conteúdo da página -->
<div class="page-header">
  <h1>Usuários</h1>
  <a href="/usuarios/new" class="btn btn-primary">Novo Usuário</a>
</div>
<!-- ... restante do conteúdo ... -->
```

---

## 6.6 Passando Dados do Controller para a View

A comunicação entre o controller e o template ocorre inteiramente através do objeto de dados passado como segundo argumento de `res.render()`. Qualquer chave desse objeto torna-se uma variável disponível no template.

### 6.6.1 Padrão de controller para views

O controller de uma aplicação SSR tem a mesma estrutura do controller de uma API REST do Capítulo 3, com uma diferença: em vez de `res.json()`, utiliza-se `res.render()`, e em vez de retornar dados brutos, prepara-se um objeto de contexto adequado para a view:

```javascript
// src/controllers/usuarios.controller.js
export class UsuariosController {
  constructor(service) {
    this.service = service;
    this.index   = this.index.bind(this);
    this.show    = this.show.bind(this);
    this.new     = this.new.bind(this);
    this.create  = this.create.bind(this);
    this.edit    = this.edit.bind(this);
    this.update  = this.update.bind(this);
    this.destroy = this.destroy.bind(this);
  }

  // GET /usuarios
  async index(req, res, next) {
    try {
      const usuarios = await this.service.listarTodos();
      res.render('usuarios/index', { titulo: 'Usuários', usuarios });
    } catch (err) { next(err); }
  }

  // GET /usuarios/:id
  async show(req, res, next) {
    try {
      const usuario = await this.service.buscarPorId(Number(req.params.id));
      res.render('usuarios/show', { titulo: usuario.nome, usuario });
    } catch (err) { next(err); }
  }

  // GET /usuarios/new
  async new(req, res) {
    res.render('usuarios/new', {
      titulo: 'Novo Usuário',
      erros:  [],          // sem erros na exibição inicial
      dados:  {},          // sem dados pré-preenchidos
    });
  }

  // POST /usuarios
  async create(req, res, next) {
    try {
      await this.service.criar(req.body);
      res.redirect('/usuarios');  // redireciona após criação bem-sucedida
    } catch (err) {
      // Em caso de erro, reexibe o formulário com os dados e erros
      if (err.statusCode < 500) {
        return res.status(err.statusCode).render('usuarios/new', {
          titulo: 'Novo Usuário',
          erros:  [err.message],
          dados:  req.body,        // repovoar o formulário com o que o usuário digitou
        });
      }
      next(err);
    }
  }

  // GET /usuarios/:id/edit
  async edit(req, res, next) {
    try {
      const usuario = await this.service.buscarPorId(Number(req.params.id));
      res.render('usuarios/edit', {
        titulo:  'Editar Usuário',
        usuario,
        erros:   [],
      });
    } catch (err) { next(err); }
  }

  // POST /usuarios/:id  (ou PUT com method override)
  async update(req, res, next) {
    try {
      await this.service.atualizar(Number(req.params.id), req.body);
      res.redirect('/usuarios');
    } catch (err) {
      if (err.statusCode < 500) {
        const usuario = { id: Number(req.params.id), ...req.body };
        return res.status(err.statusCode).render('usuarios/edit', {
          titulo:  'Editar Usuário',
          usuario,
          erros:   [err.message],
        });
      }
      next(err);
    }
  }

  // POST /usuarios/:id/delete  (ou DELETE com method override)
  async destroy(req, res, next) {
    try {
      await this.service.remover(Number(req.params.id));
      res.redirect('/usuarios');
    } catch (err) { next(err); }
  }
}
```

### 6.6.2 Variáveis locais globais com `res.locals`

Algumas variáveis precisam estar disponíveis em **todos** os templates — o usuário autenticado, mensagens flash, metadados da aplicação. O `res.locals` é o mecanismo do Express para isso: qualquer propriedade atribuída a `res.locals` em um middleware fica automaticamente acessível em todas as views da mesma requisição:

```javascript
// src/middlewares/locals.middleware.js
export const injetarLocals = (req, res, next) => {
  res.locals.appNome    = 'Minha App';
  res.locals.anoAtual   = new Date().getFullYear();
  res.locals.usuarioLogado = req.session?.usuario ?? null;
  next();
};
```

```javascript
// src/app.js
import { injetarLocals } from './middlewares/locals.middleware.js';

app.use(injetarLocals); // antes das rotas
```

Agora qualquer template pode usar `<%= appNome %>` ou `<%= anoAtual %>` sem que o controller precise passá-los explicitamente.

---

## 6.7 Formulários, Validação e Feedback ao Usuário

O processamento de formulários é um dos pontos em que o desenvolvimento SSR difere mais significativamente do desenvolvimento de APIs REST. Em vez de receber JSON e retornar JSON, o servidor recebe dados `application/x-www-form-urlencoded` e responde com um redirecionamento (em caso de sucesso) ou com o formulário reexibido com mensagens de erro (em caso de falha).

### 6.7.1 O padrão Post-Redirect-Get (PRG)

O **Post-Redirect-Get** é o padrão canônico para processamento de formulários na Web. Seu objetivo é evitar o problema de reenvio duplo: se o servidor respondesse diretamente ao POST com um HTML, o usuário ao pressionar F5 reenviaria o formulário. O PRG resolve isso assim:

1. O usuário submete o formulário (`POST /usuarios`)
2. O servidor processa os dados
3. Em caso de **sucesso**: o servidor responde com `302 Found` apontando para a página de listagem (`GET /usuarios`)
4. O navegador segue o redirecionamento e exibe a página de listagem
5. F5 agora reexecuta o `GET /usuarios`, não o `POST`

Em caso de **erro de validação**, o padrão não redireciona — o servidor responde diretamente com `400 Bad Request` e reexibe o formulário preenchido com os dados que o usuário inseriu e com as mensagens de erro destacadas.

### 6.7.2 Formulário de criação com EJS

```html
<!-- src/views/usuarios/new.ejs -->
<div class="form-container">
  <h1>Novo Usuário</h1>

  <!-- Exibição de erros -->
  <% if (erros && erros.length > 0) { %>
    <div class="alert alert-error">
      <ul>
        <% erros.forEach(erro => { %>
          <li><%= erro %></li>
        <% }); %>
      </ul>
    </div>
  <% } %>

  <form method="POST" action="/usuarios" novalidate>
    <div class="form-group <% if (erros && erros.some(e => e.includes('nome'))) { %>has-error<% } %>">
      <label for="nome">Nome</label>
      <input
        type="text"
        id="nome"
        name="nome"
        value="<%= dados.nome || '' %>"
        placeholder="Nome completo"
        required
      >
    </div>

    <div class="form-group">
      <label for="email">E-mail</label>
      <input
        type="email"
        id="email"
        name="email"
        value="<%= dados.email || '' %>"
        placeholder="usuario@exemplo.com"
        required
      >
    </div>

    <div class="form-group">
      <label for="senha">Senha</label>
      <input
        type="password"
        id="senha"
        name="senha"
        placeholder="Mínimo 8 caracteres"
        required
      >
    </div>

    <div class="form-actions">
      <a href="/usuarios" class="btn btn-secondary">Cancelar</a>
      <button type="submit" class="btn btn-primary">Criar Usuário</button>
    </div>
  </form>
</div>
```

Dois pontos merecem atenção neste template. Primeiro, o atributo `value="<%= dados.nome || '' %>"` repovoar o campo com o que o usuário digitou antes do erro, evitando que ele precise redigitar tudo. Segundo, o atributo `novalidate` desativa a validação nativa do navegador — isso dá ao servidor o controle completo sobre as mensagens de erro, mantendo uma experiência consistente.

### 6.7.3 Validação no middleware

A validação de entrada pertence aos middlewares, conforme estabelecido no Capítulo 4. Para aplicações SSR, o middleware de validação pode usar o pacote `express-validator`, que oferece uma API fluente para definir regras de validação:

```bash
npm install express-validator
```

```javascript
// src/middlewares/validacao.middleware.js
import { body, validationResult } from 'express-validator';

// Regras de validação para criação de usuário
export const regrasUsuario = [
  body('nome')
    .trim()
    .notEmpty().withMessage('O nome é obrigatório')
    .isLength({ min: 2 }).withMessage('O nome deve ter ao menos 2 caracteres'),

  body('email')
    .trim()
    .notEmpty().withMessage('O e-mail é obrigatório')
    .isEmail().withMessage('Informe um e-mail válido')
    .normalizeEmail(),

  body('senha')
    .notEmpty().withMessage('A senha é obrigatória')
    .isLength({ min: 8 }).withMessage('A senha deve ter ao menos 8 caracteres'),
];

// Middleware que verifica o resultado da validação
export const verificarValidacao = (viewName) => (req, res, next) => {
  const erros = validationResult(req);

  if (!erros.isEmpty()) {
    const mensagens = erros.array().map(e => e.msg);
    return res.status(400).render(viewName, {
      titulo: 'Novo Usuário',
      erros:  mensagens,
      dados:  req.body,  // repovoar o formulário
    });
  }

  next();
};
```

```javascript
// src/routes/usuarios.routes.js
import { Router } from 'express';
import { regrasUsuario, verificarValidacao } from '../middlewares/validacao.middleware.js';
// ... imports do repository, service, controller

const router = Router();

router.get('/',         controller.index);
router.get('/new',      controller.new);
router.get('/:id',      controller.show);
router.get('/:id/edit', controller.edit);

router.post(
  '/',
  regrasUsuario,                          // 1. valida os campos
  verificarValidacao('usuarios/new'),     // 2. reexibe o form se inválido
  controller.create                       // 3. processa se válido
);

router.post('/:id',        controller.update);
router.post('/:id/delete', controller.destroy);

export default router;
```

### 6.7.4 Mensagens flash

As **mensagens flash** são notificações temporárias que persistem por apenas uma requisição — exibidas após um redirecionamento e descartadas em seguida. São ideais para confirmar ações como "Usuário criado com sucesso" ou "Registro excluído". O pacote `connect-flash` implementa esse padrão em conjunto com sessões:

```bash
npm install express-session connect-flash
```

```javascript
// src/app.js
import session      from 'express-session';
import flash        from 'connect-flash';

app.use(session({
  secret:            process.env.SESSION_SECRET || 'segredo-dev',
  resave:            false,
  saveUninitialized: false,
  cookie:            { secure: false }, // true em produção com HTTPS
}));

app.use(flash());

// Injeta as mensagens flash em res.locals para todos os templates
app.use((req, res, next) => {
  res.locals.flash = {
    sucesso: req.flash('sucesso'),
    erro:    req.flash('erro'),
  };
  next();
});
```

```javascript
// No controller, após uma operação bem-sucedida:
async create(req, res, next) {
  try {
    await this.service.criar(req.body);
    req.flash('sucesso', 'Usuário criado com sucesso!');
    res.redirect('/usuarios');
  } catch (err) { next(err); }
}

async destroy(req, res, next) {
  try {
    await this.service.remover(Number(req.params.id));
    req.flash('sucesso', 'Usuário excluído.');
    res.redirect('/usuarios');
  } catch (err) { next(err); }
}
```

```html
<!-- src/views/partials/flash.ejs — incluído no layout base -->
<% if (flash.sucesso && flash.sucesso.length > 0) { %>
  <div class="alert alert-success">
    <% flash.sucesso.forEach(msg => { %><p><%= msg %></p><% }); %>
  </div>
<% } %>

<% if (flash.erro && flash.erro.length > 0) { %>
  <div class="alert alert-error">
    <% flash.erro.forEach(msg => { %><p><%= msg %></p><% }); %>
  </div>
<% } %>
```

### 6.7.5 Method Override (PUT e DELETE em formulários HTML)

Formulários HTML suportam apenas os métodos `GET` e `POST`. Para simular `PUT`, `PATCH` e `DELETE` — necessários para um CRUD semântico — utiliza-se o pacote `method-override`, que lê um campo oculto `_method` no corpo do formulário:

```bash
npm install method-override
```

```javascript
// src/app.js
import methodOverride from 'method-override';

// Lê o campo _method do body do formulário
app.use(methodOverride('_method'));
```

```html
<!-- Formulário de exclusão com method override -->
<form method="POST" action="/usuarios/<%= usuario.id %>?_method=DELETE">
  <button type="submit" class="btn btn-danger"
    onclick="return confirm('Tem certeza que deseja excluir?')">
    Excluir
  </button>
</form>

<!-- Formulário de edição com method override -->
<form method="POST" action="/usuarios/<%= usuario.id %>?_method=PUT">
  <!-- campos do formulário -->
  <button type="submit" class="btn btn-primary">Salvar</button>
</form>
```

```javascript
// As rotas podem então usar os métodos corretos:
router.put('/:id',    controller.update);
router.delete('/:id', controller.destroy);
```

---

## 6.8 CRUD Completo: Exemplo Integrado

Esta seção apresenta a integração completa de todos os conceitos anteriores em um CRUD funcional de usuários, com templates para cada operação.

### 6.8.1 Rotas completas

```javascript
// src/routes/usuarios.routes.js
import { Router }                         from 'express';
import { UsuariosRepositoryPrisma }       from '../repositories/usuarios.repository.prisma.js';
import { UsuariosService }                from '../services/usuarios.service.js';
import { UsuariosController }             from '../controllers/usuarios.controller.js';
import { regrasUsuario, verificarValidacao } from '../middlewares/validacao.middleware.js';
import methodOverride                      from 'method-override';

const repository = new UsuariosRepositoryPrisma();
const service    = new UsuariosService(repository);
const controller = new UsuariosController(service);

const router = Router();
router.use(methodOverride('_method'));

router.get('/',         controller.index);
router.get('/new',      controller.new);      // ATENÇÃO: /new antes de /:id
router.get('/:id/edit', controller.edit);
router.get('/:id',      controller.show);

router.post('/',
  regrasUsuario,
  verificarValidacao('usuarios/new'),
  controller.create
);

router.put('/:id',    controller.update);
router.delete('/:id', controller.destroy);

export default router;
```

!!! warning "Ordem das rotas"
    A rota `/new` deve ser declarada **antes** de `/:id`. Caso contrário, uma requisição para `/usuarios/new` seria capturada pelo padrão dinâmico `/:id`, com `id = 'new'`, resultando em uma tentativa de buscar um usuário com ID `'new'` no banco.

### 6.8.2 Template de detalhe e edição

```html
<!-- src/views/usuarios/show.ejs -->
<div class="card">
  <div class="card-header">
    <h1><%= usuario.nome %></h1>
    <div class="actions">
      <a href="/usuarios/<%= usuario.id %>/edit" class="btn btn-secondary">Editar</a>
      <form method="POST" action="/usuarios/<%= usuario.id %>?_method=DELETE" style="display:inline">
        <button type="submit" class="btn btn-danger"
          onclick="return confirm('Excluir <%= usuario.nome %>?')">
          Excluir
        </button>
      </form>
    </div>
  </div>
  <dl class="details">
    <dt>E-mail</dt><dd><%= usuario.email %></dd>
    <dt>Cadastrado em</dt><dd><%= new Date(usuario.criadoEm).toLocaleDateString('pt-BR') %></dd>
  </dl>
  <a href="/usuarios" class="btn btn-link">← Voltar</a>
</div>
```

```html
<!-- src/views/usuarios/edit.ejs -->
<div class="form-container">
  <h1>Editar: <%= usuario.nome %></h1>

  <% if (erros && erros.length > 0) { %>
    <div class="alert alert-error">
      <% erros.forEach(e => { %><p><%= e %></p><% }); %>
    </div>
  <% } %>

  <form method="POST" action="/usuarios/<%= usuario.id %>?_method=PUT" novalidate>
    <div class="form-group">
      <label for="nome">Nome</label>
      <input type="text" id="nome" name="nome"
             value="<%= usuario.nome %>" required>
    </div>
    <div class="form-group">
      <label for="email">E-mail</label>
      <input type="email" id="email" name="email"
             value="<%= usuario.email %>" required>
    </div>
    <div class="form-actions">
      <a href="/usuarios/<%= usuario.id %>" class="btn btn-secondary">Cancelar</a>
      <button type="submit" class="btn btn-primary">Salvar</button>
    </div>
  </form>
</div>
```

### 6.8.3 CSS mínimo de suporte

```css
/* public/css/styles.css */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body { font-family: system-ui, sans-serif; color: #1a1a2e; background: #f8f9fa; }

.container  { max-width: 900px; margin: 0 auto; padding: 2rem 1rem; }
.navbar     { background: #2563eb; padding: 1rem 2rem; display: flex; align-items: center; gap: 2rem; }
.navbar a   { color: #fff; text-decoration: none; font-weight: 500; }

.btn              { display: inline-block; padding: .5rem 1.25rem; border-radius: 6px;
                    font-size: .9rem; cursor: pointer; border: none; text-decoration: none; }
.btn-primary      { background: #2563eb; color: #fff; }
.btn-secondary    { background: #e5e7eb; color: #374151; }
.btn-danger       { background: #dc2626; color: #fff; }
.btn-link         { background: none; color: #2563eb; padding: 0; }

.form-container   { max-width: 480px; }
.form-group       { margin-bottom: 1.25rem; }
.form-group label { display: block; margin-bottom: .4rem; font-weight: 500; font-size: .9rem; }
.form-group input { width: 100%; padding: .6rem .8rem; border: 1px solid #d1d5db;
                    border-radius: 6px; font-size: 1rem; }
.form-group.has-error input { border-color: #dc2626; }
.form-actions     { display: flex; gap: .75rem; margin-top: 1.5rem; }

.alert            { padding: .75rem 1rem; border-radius: 6px; margin-bottom: 1rem; }
.alert-success    { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
.alert-error      { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }

.table            { width: 100%; border-collapse: collapse; }
.table th, .table td { padding: .75rem 1rem; text-align: left;
                       border-bottom: 1px solid #e5e7eb; }
.table th         { background: #f9fafb; font-weight: 600; font-size: .85rem; }

.page-header      { display: flex; justify-content: space-between; align-items: center;
                    margin-bottom: 1.5rem; }
.card             { background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 1.5rem; }
.card-header      { display: flex; justify-content: space-between; align-items: flex-start;
                    margin-bottom: 1rem; }
.details          { display: grid; grid-template-columns: auto 1fr; gap: .5rem 1.5rem; }
.details dt       { font-weight: 600; color: #6b7280; font-size: .85rem; }

.footer           { text-align: center; padding: 2rem; color: #9ca3af; font-size: .85rem;
                    border-top: 1px solid #e5e7eb; margin-top: 3rem; }
```

---

## 6.9 Tratamento de Erros em Aplicações SSR

Em APIs REST, os erros são retornados como JSON com código de status. Em aplicações SSR, o usuário deve ver uma página de erro amigável, não um objeto JSON bruto.

### 6.9.1 Middleware de erros para views

```javascript
// src/middlewares/erros.middleware.js
import { AppError } from '../utils/AppError.js';

// Página 404 para rotas não encontradas
export const naoEncontrado = (req, res) => {
  res.status(404).render('erros/404', {
    titulo:   'Página não encontrada',
    mensagem: `A página "${req.path}" não existe.`,
  });
};

// Middleware de erro geral (4 parâmetros)
export const middlewareDeErros = (err, req, res, next) => {
  console.error(err);

  // Decidir se a resposta deve ser JSON ou HTML
  const aceitaJson = req.headers['accept']?.includes('application/json');

  if (aceitaJson) {
    const status  = err instanceof AppError ? err.statusCode : 500;
    return res.status(status).json({ erro: err.message });
  }

  if (err instanceof AppError) {
    return res.status(err.statusCode).render('erros/erro', {
      titulo:  `Erro ${err.statusCode}`,
      codigo:  err.statusCode,
      mensagem: err.message,
    });
  }

  res.status(500).render('erros/erro', {
    titulo:   'Erro interno',
    codigo:   500,
    mensagem: process.env.NODE_ENV === 'production'
      ? 'Ocorreu um erro inesperado. Tente novamente.'
      : err.message,
  });
};
```

```javascript
// src/app.js — as rotas de erro ficam por último
import { naoEncontrado, middlewareDeErros } from './middlewares/erros.middleware.js';

// ... rotas da aplicação ...

app.use(naoEncontrado);      // 404
app.use(middlewareDeErros);  // 500
```

```html
<!-- src/views/erros/erro.ejs -->
<div class="error-page">
  <h1 class="error-code"><%= codigo %></h1>
  <p class="error-message"><%= mensagem %></p>
  <a href="/" class="btn btn-primary">Voltar ao início</a>
</div>
```

---

## 6.10 Exercícios Práticos

### Exercício 6.1 — Configuração inicial

Configure o EJS em um projeto Express existente (pode ser o projeto do Capítulo 4). Crie os partials de `header`, `navbar` e `footer`, e configure o layout base com `express-ejs-layouts`. Verifique que a rota `GET /` renderiza a página inicial com o layout aplicado.

### Exercício 6.2 — CRUD completo de Tarefas

Implemente um CRUD completo para o recurso `tarefas` com os campos `titulo` (obrigatório), `descricao` (opcional) e `concluida` (boolean, padrão `false`). Crie as views para listagem, detalhe, formulário de criação e formulário de edição. Use o repositório em memória do Capítulo 4 como camada de persistência.

### Exercício 6.3 — Validação e feedback

Adicione validação com `express-validator` ao formulário de criação de tarefas: o `titulo` deve ter entre 3 e 100 caracteres. Em caso de erro, reexiba o formulário com a mensagem de erro e os dados que o usuário havia inserido. Em caso de sucesso, exiba uma mensagem flash de confirmação na página de listagem.

### Exercício 6.4 — Paginação na listagem

Adicione paginação à listagem de tarefas, exibindo 5 itens por página. Crie um partial de paginação reutilizável que exiba os botões "Anterior" e "Próximo" e o número da página atual. O número da página deve ser passado como query param (`?pagina=2`).

### Exercício 6.5 — Integração com banco de dados

Substitua o repositório em memória pelo `TarefasRepositoryPrisma`, integrando o CRUD com um banco SQLite. Adicione uma migration que crie a tabela `tarefas` e verifique que os dados persistem entre reinicializações do servidor.

---

## 6.11 Referências e Leituras Complementares

- [Documentação oficial do EJS](https://ejs.co/)
- [express-ejs-layouts — npm](https://www.npmjs.com/package/express-ejs-layouts)
- [express-validator — documentação](https://express-validator.github.io/docs/)
- [connect-flash — npm](https://www.npmjs.com/package/connect-flash)
- [method-override — npm](https://www.npmjs.com/package/method-override)
- [MDN — Sending form data](https://developer.mozilla.org/en-US/docs/Learn/Forms/Sending_and_retrieving_form_data)
- [The Post/Redirect/Get Pattern — Wikipedia](https://en.wikipedia.org/wiki/Post/Redirect/Get)

---

!!! note "Próximo Capítulo"
    No **Capítulo 7 — Integração com Frontend Moderno**, o Express deixa de renderizar HTML e volta ao papel de servidor de API REST — mas desta vez servindo uma aplicação Vue.js ou React que roda no navegador. Serão abordados a configuração de CORS, o serving de arquivos estáticos da build do frontend, a comunicação via `fetch`/`axios` e o comparativo entre SSR, SPA e abordagens híbridas como Next.js e Nuxt.
