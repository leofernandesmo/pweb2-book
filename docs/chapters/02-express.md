# Capítulo 2 – Express: Rotas, Middlewares, Controllers e Estrutura de Projeto

---

## 2.1 Introdução

O Express é, até o momento presente, o framework web mais amplamente adotado no ecossistema Node.js. Sua popularidade decorre não de uma coleção exaustiva de funcionalidades embutidas, mas justamente do oposto: trata-se de um framework minimalista, que delega ao desenvolvedor a responsabilidade de compor a aplicação a partir de peças independentes e bem definidas. Essa filosofia de design, comumente denominada *unopinionated* (sem opinião), oferece liberdade arquitetural considerável, ao mesmo tempo em que exige um entendimento sólido dos conceitos fundamentais sobre os quais o framework se apoia.

Este capítulo explora quatro desses conceitos de forma aprofundada: o sistema de **rotas**, o mecanismo de **middlewares**, o padrão de **controllers** e a **estrutura de projeto** que emerge da composição desses elementos. Compreendê-los de maneira integrada é condição necessária para o desenvolvimento de APIs REST robustas, legíveis e de fácil manutenção.

> 💡 **Pré-requisito:** Este capítulo pressupõe que o leitor já possui familiaridade com os fundamentos do Node.js (Capítulo 1), incluindo o modelo de módulos CommonJS/ESM, o gerenciador de pacotes npm e a criação de um servidor HTTP básico com o módulo nativo `http`.

---

> "Instalando o Express"
> 
>    Antes de escrever qualquer código, é necessário instalar o Express como dependência. Com um terminal aberto na raiz do projeto, execute:
>
>    ```bash
>    npm install express
>    ```
>    A partir desse ponto, é possível importar o Express com `import express from 'express'` em qualquer arquivo do projeto.

---

## 2.2 O Sistema de Rotas

### 2.2.1 O que é uma rota?

No contexto de aplicações web, uma **rota** é a associação entre um método HTTP, um padrão de URL e uma função responsável por processar a requisição correspondente. Quando um cliente envia uma requisição HTTP para o servidor, o Express percorre suas rotas registradas em ordem de declaração e, ao encontrar aquela cujo método e padrão coincidem com a requisição recebida, executa a função associada. Esse processo é denominado *roteamento*.

A forma mais elementar de definir uma rota em Express é a seguinte:

```javascript
import express from 'express';       // (1) Importa o framework Express

const app = express();                // (2) Cria a instância da aplicação

app.get('/usuarios', (req, res) => { // (3) Define uma rota GET
  res.json({ mensagem: '...' });      // (4) Envia a resposta em JSON
});

app.listen(3000);                     // (5) Inicia o servidor na porta 3000
```

Neste exemplo, a aplicação responde às requisições `GET /usuarios` com um objeto JSON. Os objetos `req` e `res` são, respectivamente, representações da requisição recebida e da resposta que será enviada ao cliente — ambos enriquecidos pelo Express com métodos e propriedades adicionais em relação ao Node.js puro.


> Possíveis Erros:
> Caso apareça o erro:  _Failed to load the ES module: /server.js. Make sure to set "type": "module" in the nearest package.json file or use the .mjs extension._
>
> Altere o package.json, atributo "type" de "commonjs" para "module".
> 

### 2.2.2 Métodos HTTP e semântica REST

O Express expõe métodos correspondentes aos verbos HTTP mais utilizados: `app.get()`, `app.post()`, `app.put()`, `app.patch()` e `app.delete()`. Em uma API REST bem projetada, cada verbo carrega uma semântica específica que deve ser respeitada, conforme descrito a seguir.

O método `GET` é utilizado para a recuperação de recursos, sem produzir efeitos colaterais no servidor. O `POST` destina-se à criação de novos recursos. O `PUT` realiza a substituição completa de um recurso existente, ao passo que o `PATCH` aplica modificações parciais. Por fim, o `DELETE` remove um recurso identificado.

O exemplo abaixo demonstra a definição de rotas para um recurso `produtos`, seguindo a semântica REST:

```javascript
// Listagem de todos os produtos
app.get('/produtos', (req, res) => {
  res.json([]);
});

// Criação de um novo produto
app.post('/produtos', (req, res) => {
  const novoProduto = req.body;
  res.status(201).json(novoProduto);
});

// Atualização completa de um produto
app.put('/produtos/:id', (req, res) => {
  const { id } = req.params;
  res.json({ id, ...req.body });
});

// Remoção de um produto
app.delete('/produtos/:id', (req, res) => {
  res.status(204).send();
});
```

### 2.2.3 Parâmetros de rota, de consulta e corpo da requisição

O Express oferece três mecanismos distintos para o recebimento de dados provenientes do cliente, cada um adequado a uma situação específica.

Os **parâmetros de rota** (*route params*) são segmentos dinâmicos da URL, delimitados por dois-pontos na definição da rota. São acessados através de `req.params` e tipicamente utilizados para identificar recursos específicos.

```javascript
// URL: GET /usuarios/42
app.get('/usuarios/:id', (req, res) => {
  const { id } = req.params; // "42"
  res.json({ usuarioId: id });
});
```

Os **parâmetros de consulta** (*query params*) são pares chave-valor transmitidos na URL após o caractere `?`. São acessados via `req.query` e frequentemente empregados em operações de filtragem, ordenação ou paginação.

```javascript
// URL: GET /produtos?categoria=eletronicos&pagina=2
app.get('/produtos', (req, res) => {
  const { categoria, pagina } = req.query;
  res.json({ categoria, pagina });
});
```

O **corpo da requisição** (*request body*) é utilizado em operações de escrita (`POST`, `PUT`, `PATCH`) para transmitir dados estruturados. O acesso ocorre via `req.body`, mas requer a utilização de um middleware de parsing — tópico detalhado na seção seguinte.

```javascript
// POST /usuarios com body: { "nome": "Ana", "email": "ana@exemplo.com" }
app.post('/usuarios', (req, res) => {
  const { nome, email } = req.body;
  res.status(201).json({ nome, email });
});
```

### 2.2.4 O objeto Router

À medida que a aplicação cresce, concentrar todas as rotas no arquivo principal torna-se inviável. O Express oferece o objeto `Router`, que permite organizar rotas relacionadas em módulos independentes.

Um `Router` se comporta como uma mini-aplicação Express: aceita rotas e middlewares, podendo ser montado em qualquer prefixo de URL da aplicação principal.

```javascript
// src/routes/usuarios.routes.js
import { Router } from 'express';

const router = Router();

router.get('/', (req, res) => {
  res.json({ mensagem: 'Lista de usuários' });
});

router.get('/:id', (req, res) => {
  res.json({ id: req.params.id });
});

router.post('/', (req, res) => {
  res.status(201).json(req.body);
});

export default router;
```

```javascript
// src/app.js
import express from 'express';
import usuariosRouter from './routes/usuarios.routes.js';

const app = express();
app.use(express.json());

app.use('/usuarios', usuariosRouter);

export default app;
```

Ao montar o router em `/usuarios`, todas as rotas definidas nele herdam esse prefixo. Assim, `router.get('/')` responde a `GET /usuarios`, e `router.get('/:id')` responde a `GET /usuarios/:id`.

> 📷 **Sugestão de imagem:** Diagrama ilustrando o fluxo de uma requisição HTTP desde o cliente até o router, passando pelo `app.use()`, e o roteamento para o handler correto com base no método e URL.

---

## 2.3 Middlewares

### 2.3.1 A natureza do middleware

O conceito de **middleware** é o mais fundamental de toda a arquitetura Express. Um middleware é uma função que possui acesso ao objeto de requisição (`req`), ao objeto de resposta (`res`) e a uma função especial denominada `next`. Quando chamada, `next()` transfere o controle para o próximo middleware na cadeia de execução.

A assinatura de um middleware é a seguinte:

```javascript
(req, res, next) => {
  // lógica do middleware
  next(); // passa o controle adiante
}
```

Toda aplicação Express é, em sua essência, uma sequência de chamadas de middleware. Quando uma requisição chega ao servidor, ela percorre essa sequência de cima para baixo até que uma função envie uma resposta ao cliente — ou até que ocorra um erro.

> 🎥 **Sugestão de vídeo:** [Fireship – Express.js in 100 Seconds](https://www.youtube.com/watch?v=SccSCuHhOw0) — apresenta de forma visual e concisa o modelo de pipeline de middlewares do Express.

### 2.3.2 O pipeline de execução

Considere a seguinte sequência de middlewares:

```javascript
const app = express();

// Middleware 1: log da requisição
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Middleware 2: parsing de JSON
app.use(express.json());

// Middleware 3: rota final
app.get('/saude', (req, res) => {
  res.json({ status: 'ok' });
});
```

Para cada requisição `GET /saude`, a execução ocorre na seguinte ordem: o primeiro middleware registra a requisição no console e chama `next()`; o segundo realiza o parsing do corpo JSON e chama `next()`; o terceiro, sendo a rota correspondente, envia a resposta e encerra o ciclo.

É crucial compreender que **se um middleware não chamar `next()` e também não enviar uma resposta**, a requisição ficará suspensa indefinidamente. Esse é um erro comum em aplicações iniciantes e resulta em timeouts do lado do cliente.

### 2.3.3 Tipos de middleware

O Express reconhece quatro categorias principais de middleware, diferenciadas pelo escopo e pela forma de registro.

**Middlewares de aplicação** são registrados com `app.use()` ou com um método HTTP específico sem especificação de rota, sendo executados para todas as requisições (ou para as que correspondem a um prefixo de URL).

```javascript
// Executado para todas as requisições
app.use((req, res, next) => {
  req.timestampInicio = Date.now();
  next();
});

// Executado apenas para rotas que começam com /api
app.use('/api', (req, res, next) => {
  console.log('Requisição para a API');
  next();
});
```

**Middlewares de rota** são associados a um router específico, limitando seu escopo às rotas daquele módulo.

```javascript
const router = Router();

router.use((req, res, next) => {
  console.log('Middleware exclusivo deste router');
  next();
});
```

**Middlewares de tratamento de erros** possuem quatro parâmetros: `(err, req, res, next)`. O Express os identifica automaticamente pela assinatura de quatro argumentos e os invoca quando um erro é passado para `next(err)`.

```javascript
// Middleware de erro — DEVE ter 4 parâmetros
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.statusCode || 500).json({
    erro: err.message || 'Erro interno do servidor',
  });
});
```

**Middlewares de terceiros** são pacotes npm que encapsulam funcionalidades transversais reutilizáveis. Os mais comuns incluem `morgan` (logging), `cors` (controle de origem cruzada) e `helmet` (cabeçalhos de segurança HTTP).

```javascript
import morgan from 'morgan';
import cors from 'cors';
import helmet from 'helmet';

app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
```

### 2.3.4 Criando middlewares customizados

A criação de middlewares próprios é uma prática recorrente no desenvolvimento com Express. A seguir, dois exemplos representativos de casos de uso reais.

**Middleware de autenticação por token:**

```javascript
// src/middlewares/autenticacao.middleware.js
export const verificarToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ erro: 'Token não fornecido' });
  }

  const token = authHeader.split(' ')[1];

  try {
    // Supondo verificação com JWT (detalhado no Capítulo 5)
    const payload = verificarJwt(token);
    req.usuario = payload;
    next();
  } catch {
    res.status(401).json({ erro: 'Token inválido ou expirado' });
  }
};
```

```javascript
// Uso seletivo: aplica o middleware apenas à rota de perfil
app.get('/perfil', verificarToken, (req, res) => {
  res.json({ usuario: req.usuario });
});
```

**Middleware de validação de dados de entrada:**

```javascript
// src/middlewares/validacao.middleware.js
export const validarCriacaoUsuario = (req, res, next) => {
  const { nome, email, senha } = req.body;

  if (!nome || typeof nome !== 'string' || nome.trim().length < 2) {
    return res.status(400).json({ erro: 'Nome inválido' });
  }

  if (!email || !email.includes('@')) {
    return res.status(400).json({ erro: 'E-mail inválido' });
  }

  if (!senha || senha.length < 8) {
    return res.status(400).json({ erro: 'Senha deve ter ao menos 8 caracteres' });
  }

  next();
};
```

```javascript
// Aplicado inline na rota
router.post('/', validarCriacaoUsuario, criarUsuario);
```

> 📷 **Sugestão de imagem:** Diagrama de pipeline mostrando a cadeia de middlewares — `helmet → cors → morgan → autenticação → validação → controller` — com setas indicando o fluxo de `next()` e os pontos onde a requisição pode ser interrompida com uma resposta de erro.

### 2.3.5 Propagação de erros

Uma prática essencial no desenvolvimento com Express é a propagação correta de erros assíncronos. Em rotas assíncronas, exceções não capturadas não são automaticamente interceptadas pelo middleware de erro — é necessário capturá-las e passá-las para `next`.

```javascript
// ❌ Forma incorreta: erro assíncrono não tratado
app.get('/usuarios', async (req, res) => {
  const usuarios = await buscarUsuariosNoBanco(); // Pode lançar exceção
  res.json(usuarios);
});

// ✅ Forma correta com try/catch
app.get('/usuarios', async (req, res, next) => {
  try {
    const usuarios = await buscarUsuariosNoBanco();
    res.json(usuarios);
  } catch (err) {
    next(err); // Delega ao middleware de erro
  }
});
```

Uma alternativa elegante é criar um wrapper que aplica esse padrão automaticamente:

```javascript
// src/utils/asyncHandler.js
export const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Uso
app.get('/usuarios', asyncHandler(async (req, res) => {
  const usuarios = await buscarUsuariosNoBanco();
  res.json(usuarios);
}));
```

---

## 2.4 Controllers

### 2.4.1 A separação de responsabilidades

À medida que a lógica de cada rota se torna mais complexa, inserir todo o código diretamente nas definições de rota resulta em arquivos extensos, difíceis de testar e de manter. O padrão de **controllers** surge como solução para esse problema, aplicando o princípio da separação de responsabilidades (*Separation of Concerns*).

Um controller é um módulo que agrupa as funções responsáveis por processar requisições de um determinado recurso. Sua responsabilidade é exclusivamente coordenar o fluxo: receber os dados da requisição (`req`), delegar o processamento à camada de serviço e enviar a resposta apropriada ao cliente (`res`). O controller **não deve** conter lógica de negócio nem acesso direto ao banco de dados — essas responsabilidades pertencem a camadas distintas.

### 2.4.2 Implementação de um controller

Considere um controller para o recurso `usuarios`:

```javascript
// src/controllers/usuarios.controller.js
import { UsuariosService } from '../services/usuarios.service.js';

const service = new UsuariosService();

export const listarUsuarios = async (req, res, next) => {
  try {
    const usuarios = await service.listarTodos();
    res.json(usuarios);
  } catch (err) {
    next(err);
  }
};

export const obterUsuario = async (req, res, next) => {
  try {
    const { id } = req.params;
    const usuario = await service.buscarPorId(Number(id));

    if (!usuario) {
      return res.status(404).json({ erro: 'Usuário não encontrado' });
    }

    res.json(usuario);
  } catch (err) {
    next(err);
  }
};

export const criarUsuario = async (req, res, next) => {
  try {
    const dados = req.body;
    const novoUsuario = await service.criar(dados);
    res.status(201).json(novoUsuario);
  } catch (err) {
    next(err);
  }
};

export const atualizarUsuario = async (req, res, next) => {
  try {
    const { id } = req.params;
    const dados = req.body;
    const usuarioAtualizado = await service.atualizar(Number(id), dados);
    res.json(usuarioAtualizado);
  } catch (err) {
    next(err);
  }
};

export const removerUsuario = async (req, res, next) => {
  try {
    const { id } = req.params;
    await service.remover(Number(id));
    res.status(204).send();
  } catch (err) {
    next(err);
  }
};
```

### 2.4.3 Integração com o router

Com o controller definido, o arquivo de rotas torna-se declarativo e extremamente enxuto:

```javascript
// src/routes/usuarios.routes.js
import { Router } from 'express';
import { validarCriacaoUsuario } from '../middlewares/validacao.middleware.js';
import {
  listarUsuarios,
  obterUsuario,
  criarUsuario,
  atualizarUsuario,
  removerUsuario,
} from '../controllers/usuarios.controller.js';

const router = Router();

router.get('/', listarUsuarios);
router.get('/:id', obterUsuario);
router.post('/', validarCriacaoUsuario, criarUsuario);
router.put('/:id', atualizarUsuario);
router.delete('/:id', removerUsuario);

export default router;
```

Essa separação revela uma divisão clara de papéis: o arquivo de rotas declara *quais* caminhos existem e *quais* middlewares os protegem; o controller define *como* cada requisição é processada; e a camada de serviço (tratada no Capítulo 3) encapsula *o que* a aplicação faz do ponto de vista do negócio.

---

## 2.5 Estrutura de Projeto

### 2.5.1 A importância da organização

A estrutura de diretórios de um projeto é uma decisão arquitetural com impactos duradouros sobre a produtividade da equipe, a facilidade de onboarding de novos membros e a manutenibilidade do código ao longo do tempo. Uma organização bem pensada torna implícita a separação de responsabilidades: ao abrir qualquer arquivo, o desenvolvedor sabe imediatamente qual é o seu papel na aplicação.

Existem duas filosofias predominantes de organização de projetos Express: a **organização por tipo de arquivo** e a **organização por funcionalidade** (feature-based). A primeira agrupa todos os controllers juntos, todos os services juntos e assim por diante. A segunda agrupa por domínio — tudo relacionado a `usuarios` fica em um mesmo módulo. Para aplicações de pequeno e médio porte, a organização por tipo é mais comum e será adotada neste material.

### 2.5.2 Estrutura recomendada

A estrutura a seguir representa uma organização matura e amplamente adotada para APIs Express de médio porte:

```
minha-api/
├── src/
│   ├── config/
│   │   ├── database.js        # Configuração da conexão com o banco de dados
│   │   └── env.js             # Carregamento e validação de variáveis de ambiente
│   │
│   ├── controllers/
│   │   ├── usuarios.controller.js
│   │   └── produtos.controller.js
│   │
│   ├── middlewares/
│   │   ├── autenticacao.middleware.js
│   │   ├── validacao.middleware.js
│   │   └── erros.middleware.js
│   │
│   ├── models/                # Modelos de dados / entidades (ORM – Cap. 4)
│   │   ├── usuario.model.js
│   │   └── produto.model.js
│   │
│   ├── repositories/          # Acesso ao banco de dados (Cap. 3)
│   │   ├── usuarios.repository.js
│   │   └── produtos.repository.js
│   │
│   ├── routes/
│   │   ├── index.js           # Agregador de todos os routers
│   │   ├── usuarios.routes.js
│   │   └── produtos.routes.js
│   │
│   ├── services/              # Lógica de negócio (Cap. 3)
│   │   ├── usuarios.service.js
│   │   └── produtos.service.js
│   │
│   ├── utils/
│   │   ├── asyncHandler.js
│   │   └── AppError.js        # Classe de erro customizado
│   │
│   └── app.js                 # Configuração do Express
│
├── tests/                     # Testes automatizados (Cap. 7)
│   ├── integration/
│   └── unit/
│
├── .env                       # Variáveis de ambiente (não versionar)
├── .env.example               # Modelo de variáveis de ambiente
├── .gitignore
├── package.json
└── server.js                  # Ponto de entrada — inicializa o servidor
```

### 2.5.3 Separação entre `app.js` e `server.js`

Um detalhe frequentemente negligenciado é a separação entre o arquivo de configuração da aplicação (`app.js`) e o ponto de entrada do servidor (`server.js`). Essa separação tem uma razão técnica relevante: durante os testes automatizados, importa-se `app.js` diretamente, sem iniciar o servidor HTTP. Isso permite testar as rotas com supertest sem conflitos de porta.

```javascript
// src/app.js
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import { router } from './routes/index.js';
import { middlewareDeErros } from './middlewares/erros.middleware.js';

const app = express();

// Middlewares globais
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// Rotas
app.use('/api', router);

// Middleware de erros (sempre por último)
app.use(middlewareDeErros);

export default app;
```

```javascript
// server.js
import app from './src/app.js';

const PORTA = process.env.PORT || 3000;

app.listen(PORTA, () => {
  console.log(`Servidor iniciado na porta ${PORTA}`);
});
```

### 2.5.4 O agregador de rotas

O arquivo `src/routes/index.js` funciona como ponto central de registro de todos os routers. Sua responsabilidade é exclusivamente importar e montar cada router no prefixo correspondente, mantendo o `app.js` desacoplado dos detalhes de cada recurso.

```javascript
// src/routes/index.js
import { Router } from 'express';
import usuariosRouter from './usuarios.routes.js';
import produtosRouter from './produtos.routes.js';

export const router = Router();

router.use('/usuarios', usuariosRouter);
router.use('/produtos', produtosRouter);
```

### 2.5.5 Classe de erro customizado

Uma prática recomendada é criar uma classe de erro que carrega, além da mensagem, o código de status HTTP associado. Isso permite que o middleware de erros construa respostas padronizadas sem lógica condicional dispersa.

```javascript
// src/utils/AppError.js
export class AppError extends Error {
  constructor(mensagem, statusCode = 500) {
    super(mensagem);
    this.statusCode = statusCode;
    this.name = 'AppError';
  }
}
```

```javascript
// Uso em qualquer camada da aplicação
import { AppError } from '../utils/AppError.js';

if (!usuario) {
  throw new AppError('Usuário não encontrado', 404);
}
```

```javascript
// src/middlewares/erros.middleware.js
import { AppError } from '../utils/AppError.js';

export const middlewareDeErros = (err, req, res, next) => {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ erro: err.message });
  }

  console.error(err);
  res.status(500).json({ erro: 'Erro interno do servidor' });
};
```

---

## 2.6 Exercícios Práticos

### Exercício 2.1 — Router independente

Crie um router para o recurso `tarefas` com as seguintes rotas: listagem de todas as tarefas, obtenção de uma tarefa por ID, criação, atualização parcial (PATCH) e remoção. As funções handler podem retornar dados fictícios (hardcoded) por enquanto. Monte o router em `/api/tarefas` na aplicação principal.

### Exercício 2.2 — Middleware de log com tempo de resposta

Implemente um middleware de aplicação que registre no console, ao final de cada requisição, o método HTTP, a URL, o código de status da resposta e o tempo total de processamento em milissegundos. **Dica:** o Express possui o evento `res.on('finish', ...)` que é emitido quando a resposta é enviada ao cliente.

### Exercício 2.3 — Tratamento centralizado de erros

Partindo da estrutura apresentada na seção 2.5, implemente a classe `AppError`, o middleware `middlewareDeErros` e refatore as rotas do Exercício 2.1 para que todos os erros sejam propagados via `next(err)`. Verifique que uma rota inexistente resulta em uma resposta JSON com status 404 e mensagem padronizada.

### Exercício 2.4 — Estrutura completa de projeto

Organize os arquivos dos exercícios anteriores seguindo a estrutura de diretórios apresentada na seção 2.5.2. Ao final, o projeto deve conter: `server.js`, `src/app.js`, `src/routes/index.js`, `src/routes/tarefas.routes.js`, `src/controllers/tarefas.controller.js` e `src/middlewares/erros.middleware.js`.

---

## 2.7 Referências e Leituras Complementares

- [Documentação oficial do Express — Routing](https://expressjs.com/en/guide/routing.html)
- [Documentação oficial do Express — Writing middleware](https://expressjs.com/en/guide/writing-middleware.html)
- [MDN Web Docs — HTTP request methods](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods)
- [Node.js Best Practices — Error Handling](https://github.com/goldbergyoni/nodebestpractices#2-error-handling-practices)
- 📖 Brown, E. *Web Development with Node and Express*. 2ª ed. O'Reilly Media, 2019. — Capítulos 10 e 14.

---

!!! note "Próximo Capítulo"
    No **Capítulo 3 – Arquitetura MVC**, aprofundaremos a camada de serviços e o padrão Repository, completando a separação de responsabilidades iniciada aqui. A estrutura de projeto apresentada neste capítulo será expandida para acomodar essas novas camadas.


[⬅ Back to Chapter 1](01-introducao.md)
