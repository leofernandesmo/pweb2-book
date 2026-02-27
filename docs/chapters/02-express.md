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

O método `GET` é utilizado para a recuperação de **recursos**, sem produzir efeitos colaterais no servidor. O `POST` destina-se à criação de **novos recursos**. O `PUT` realiza a substituição completa de um **recurso existente**, ao passo que o `PATCH` aplica modificações parciais. Por fim, o `DELETE` remove um **recurso** identificado.

O exemplo abaixo demonstra a definição de rotas para um recurso `produtos`, seguindo a semântica REST:

```javascript
// Define uma rota POST em /produtos — usada para criar novos recursos
app.post('/produtos', (req, res) => {
  const novoProduto = req.body; // Lê o corpo da requisição (ex: { nome: 'Cadeira', preco: 299 })                                
  res.status(201).json(novoProduto); // 201 Created: convenção HTTP para criação bem-sucedida
                                     // Retorna o recurso criado como confirmação ao cliente
});

// Define uma rota PUT em /produtos/:id — substitui completamente um recurso existente
app.put('/produtos/:id', (req, res) => {
  const { id } = req.params; // Extrai o segmento dinâmico da URL
                             // Ex: PUT /produtos/42  →  id === "42"
                             // Atenção: params sempre retorna string, mesmo que o valor seja numérico
  res.json({ id, ...req.body }); // Combina o id com os dados recebidos no corpo
                                 // Ex: { id: "42", nome: "Cadeira", preco: 350 }
                                 // O spread ...req.body "espalha" as propriedades do objeto recebido (ver explicação abaixo)
});

// Define uma rota DELETE em /produtos/:id — remove o recurso identificado pelo id
app.delete('/produtos/:id', (req, res) => {
  res.status(204).send(); // 204 No Content: operação bem-sucedida, sem corpo na resposta
                          // Usar res.json() aqui seria incorreto — 204 não deve ter body
});

```

Veja alguns comentários abaixo sobre o código.

A semântica em relação as respostas de status segue a especificação HTTP:

- **POST** cria um recurso que ainda não existia → **201 Created** — um novo estado surgiu no servidor, portanto o código deve comunicar algo além do simples "deu certo".
- **PUT** substitui um recurso que já existia → **200 OK** — o recurso já estava lá, foi atualizado, e a resposta devolve sua representação atual. Nada de novo foi criado.
- **DELETE** conclui com sucesso mas não tem nada a devolver → **204 No Content** — exige declaração explícita justamente por fugir do padrão 200.

**Atenção ao PUT**. Como 200 é o padrão do Express, omitir `res.status()` no PUT é uma escolha consciente, não um esquecimento. Escrever `res.status(200).json(...)` seria válido, porém redundante — a convenção entre desenvolvedores Express é omitir o status quando ele é 200, reservando a chamada explícita apenas para os casos que se desviam desse padrão.


O operador spread (`...`) copia todas as propriedades enumeráveis de um objeto para dentro de outro. No contexto da rota PUT, ele é usado assim:

```javascript
res.json({ id, ...req.body });
```

Suponha que o cliente envie no corpo da requisição:

```json
{ "nome": "Cadeira", "preco": 350 }
```

O spread "espalha" essas propriedades dentro do novo objeto literal, produzindo o resultado equivalente a:

```javascript
res.json({ id: "42", nome: "Cadeira", preco: 350 });
```

Sem o spread, seria necessário construir esse objeto manualmente, propriedade por propriedade — o que é inviável quando o corpo da requisição tem estrutura variável ou muitos campos. O spread resolve isso de forma genérica, independentemente de quantas ou quais propriedades `req.body` contenha.

Vale observar um detalhe importante de ordem: se `req.body` contiver uma propriedade chamada `id`, ela **sobrescreveria** o `id` vindo de `req.params`, pois propriedades declaradas depois prevalecem sobre as anteriores. Por isso, em situações reais, é recomendável colocar o `id` do params **após** o spread, garantindo que ele sempre prevaleça:

```javascript
res.json({ ...req.body, id }); // id de req.params nunca será sobrescrito
```

O código anterior pode dar erro, porque ainda não foi feito o registro do midleware _express.json_ não foi registrado. Veja na próxima seção para entender melhor.


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

Para que `req.body` esteja disponível nas rotas, é necessário registrar o middleware de parsing de JSON **antes** das definições de rota, por meio de `app.use(express.json())`:

```javascript
const app = express();

app.use(express.json()); // Habilita a leitura do corpo da requisição em formato JSON

app.post('/produtos', (req, res) => {
  console.log(req.body); // Agora acessível. Sem a linha acima, seria undefined.
  res.status(201).json(req.body);
});
```

> O conceito de middleware — o que é, como funciona internamente e como criar os seus próprios — será explicado em profundidade na seção 2.3 deste capítulo.

Os **parâmetros de consulta** (*query params*) são pares chave-valor transmitidos na URL após o caractere `?`. São acessados via `req.query` e frequentemente empregados em operações de filtragem, ordenação ou paginação.

```javascript
// URL: GET /produtos?categoria=eletronicos&pagina=2
app.get('/produtos', (req, res) => {
  const { categoria, pagina } = req.query;
  res.json({ categoria, pagina });
});
```

A URL `/produtos?categoria=eletronicos&pagina=2` possui dois query params: `categoria` com valor `"eletronicos"` e `pagina` com valor `"2"`. Eles são separados do caminho (_path_) pelo caractere `?` e entre si pelo caractere `&`.

No Express, todos esses pares chave-valor são automaticamente parseados e disponibilizados em `req.query` como um objeto JavaScript — no caso, `{ categoria: "eletronicos", pagina: "2" }`. A desestruturação na primeira linha do handler simplesmente extrai essas duas propriedades em variáveis independentes.

Um ponto que merece atenção: assim como `req.params`, os valores de `req.query` chegam **sempre como string**, mesmo quando representam números. O valor de `pagina` é `"2"`, não `2`. Caso seja necessário utilizá-lo como número em alguma operação — uma consulta ao banco de dados com `LIMIT` e `OFFSET`, por exemplo — a conversão explícita é obrigatória: `Number(pagina)` ou `parseInt(pagina, 10)`.


O **corpo da requisição** (*request body*) é utilizado em operações de escrita (`POST`, `PUT`, `PATCH`) para transmitir dados estruturados. O acesso ocorre via `req.body`, mas requer a utilização de um middleware de parsing — tópico detalhado na seção seguinte.

```javascript
// POST /usuarios com body: { "nome": "Ana", "email": "ana@exemplo.com" }
app.post('/usuarios', (req, res) => {
  const { nome, email } = req.body;
  res.status(201).json({ nome, email });
});
```

> **Em síntese:** uma rota no Express é sempre a combinação de três elementos — um verbo HTTP, um caminho e uma função handler. Os dados de uma requisição chegam por três canais distintos: `req.params` para identificadores na URL, `req.query` para filtros e parâmetros opcionais, e `req.body` para dados estruturados no corpo. O objeto `Router` permite modularizar essas rotas por recurso, mantendo o código organizado e de fácil navegação. Por fim, cada verbo HTTP carrega uma semântica precisa que deve ser respeitada: GET para leitura, POST para criação (201), PUT para substituição (200), PATCH para atualização parcial e DELETE para remoção (204) — seguir essa convenção torna a API previsível para qualquer cliente que a consuma.


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

Atenção para a última linha do código anterior que exporta o objeto router e para import no próximo código que usa este objeto para gerenciar a rota. 

```javascript
// src/app.js
import usuariosRouter from './routes/usuarios.routes.js';
import express from 'express';

const app = express();
app.use(express.json());

app.use('/usuarios', usuariosRouter);

export default app;
```

**IMPORTANTE**: Ao montar o router em `/usuarios`, todas as rotas definidas nele herdam esse prefixo. Assim, `router.get('/')` responde a `GET /usuarios`, e `router.get('/:id')` responde a `GET /usuarios/:id`. Logo, ao dividir a responsabilidade, você gerencia melhor as rotas. 


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

Toda aplicação Express é, em sua essência, uma sequência de chamadas de middleware. Quando uma requisição chega ao servidor, ela percorre essa sequência de cima para baixo até que uma função envie uma resposta ao cliente — ou até que ocorra um erro. É crucial compreender que **se um middleware não chamar `next()` e também não enviar uma resposta**, a requisição ficará suspensa indefinidamente, resultando em timeout do lado do cliente.


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

### 2.3.3 Tipos de middleware

O Express reconhece quatro categorias principais de middleware, diferenciadas pelo escopo e pela forma de registro.

**Middlewares de aplicação** são registrados com `app.use()` e executados para todas as requisições, ou para as que correspondem a um prefixo de URL específico.

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

**Middlewares de rota** são associados a um `Router` específico, limitando seu escopo às rotas daquele módulo.

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

**Middlewares de terceiros** são pacotes npm que encapsulam funcionalidades transversais reutilizáveis. Constituem uma parte essencial do ecossistema Express e serão detalhados na seção seguinte.

### 2.3.4 Middlewares de terceiros amplamente utilizados

Uma das grandes vantagens do Express é a disponibilidade de middlewares de terceiros bem mantidos e amplamente adotados pela comunidade. A seguir, os mais relevantes para o desenvolvimento de APIs em ambiente de produção.

#### helmet

O `helmet` é um conjunto de middlewares de segurança que configura automaticamente diversos cabeçalhos HTTP com o objetivo de proteger a aplicação contra vulnerabilidades conhecidas. Entre os cabeçalhos que ele gerencia estão `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security` e `Content-Security-Policy`, cada um mitigando um vetor de ataque distinto. Sua adoção é considerada uma prática mínima de segurança em qualquer API exposta publicamente.

```bash
npm install helmet
```

```javascript
import helmet from 'helmet';

app.use(helmet()); // Aplica todos os cabeçalhos de segurança com configurações padrão

// Ou com configuração personalizada
app.use(
  helmet({
    contentSecurityPolicy: false, // Desativa Content Security Policy (CSP) se a API servir HTML
    crossOriginEmbedderPolicy: false,
  })
);
```

#### cors

O `cors` gerencia a política de mesma origem (*Same-Origin Policy*), controlando quais domínios externos têm permissão para consumir a API. Sem ele, navegadores bloqueiam requisições de front-ends hospedados em domínios diferentes do servidor. Em desenvolvimento, é comum liberar todas as origens; em produção, a configuração deve ser restritiva, listando explicitamente os domínios autorizados.

```bash
npm install cors
```

```javascript
import cors from 'cors';

// Desenvolvimento: libera todas as origens
app.use(cors());

// Produção: restringe a origens específicas
app.use(
  cors({
    origin: ['https://meuapp.com', 'https://admin.meuapp.com'],
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);
```

#### morgan

O `morgan` é um middleware de logging de requisições HTTP. Ele intercepta cada requisição e registra informações como método, URL, status da resposta, tempo de processamento e tamanho do corpo. Possui formatos predefinidos — `dev`, `combined`, `short`, `tiny` — cada um com nível de detalhe distinto. O formato `dev` é o mais utilizado durante o desenvolvimento por ser colorido e conciso; o `combined` (no padrão Apache) é preferido em produção por ser compatível com ferramentas de análise de logs.

```bash
npm install morgan
```

```javascript
import morgan from 'morgan';

// Desenvolvimento: saída colorida e resumida
app.use(morgan('dev'));
// Exemplo de saída: GET /usuarios 200 4.321 ms - 148

// Produção: formato Apache, compatível com ferramentas de log
app.use(morgan('combined'));
// Exemplo de saída: ::1 - - [10/Jan/2025:14:22:01 +0000] "GET /usuarios HTTP/1.1" 200 148
```

#### express-rate-limit

O `express-rate-limit` implementa limitação de taxa de requisições (*rate limiting*), uma medida essencial para proteger a API contra ataques de força bruta, enumeração de recursos e abuso de endpoints públicos. Ele rastreia o número de requisições por IP em uma janela de tempo configurável e rejeita as que excedem o limite com status `429 Too Many Requests`.

```bash
npm install express-rate-limit
```

```javascript
import rateLimit from 'express-rate-limit';

// Limite geral: 100 requisições por IP a cada 15 minutos
const limiteGeral = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos em milissegundos
  max: 100,
  message: { erro: 'Muitas requisições. Tente novamente em 15 minutos.' },
  standardHeaders: true,  // Inclui headers RateLimit-* na resposta
  legacyHeaders: false,
});

// Limite mais restritivo para rotas de autenticação
const limiteLogin = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10, // Apenas 10 tentativas de login por janela
  message: { erro: 'Muitas tentativas de login. Tente novamente mais tarde.' },
});

app.use('/api', limiteGeral);
app.use('/api/auth/login', limiteLogin);
```

#### multer

O `multer` é o middleware padrão para o tratamento de uploads de arquivos em Express. Ele processa requisições do tipo `multipart/form-data` — o formato utilizado por formulários HTML que incluem arquivos — e disponibiliza os arquivos recebidos em `req.file` (upload único) ou `req.files` (múltiplos uploads). Suporta armazenamento em disco ou em memória, e pode ser configurado com validações de tipo MIME e tamanho máximo.

```bash
npm install multer
```

```javascript
import multer from 'multer';
import path from 'path';

// Configuração de armazenamento em disco
const armazenamento = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/'); // Diretório de destino
  },
  filename: (req, file, cb) => {
    const extensao = path.extname(file.originalname);
    const nomeUnico = `${Date.now()}-${Math.round(Math.random() * 1e9)}${extensao}`;
    cb(null, nomeUnico);
  },
});

const upload = multer({
  storage: armazenamento,
  limits: { fileSize: 5 * 1024 * 1024 }, // Limite de 5 MB
  fileFilter: (req, file, cb) => {
    const tiposPermitidos = /jpeg|jpg|png|webp/;
    const valido = tiposPermitidos.test(file.mimetype);
    cb(null, valido); // true = aceita, false = rejeita
  },
});

// Upload de arquivo único no campo "foto"
app.post('/usuarios/:id/foto', upload.single('foto'), (req, res) => {
  res.json({ caminho: req.file.path });
});

// Upload de múltiplos arquivos
app.post('/galeria', upload.array('imagens', 5), (req, res) => {
  const caminhos = req.files.map((f) => f.path);
  res.json({ arquivos: caminhos });
});
```

#### compression

O `compression` aplica compressão gzip ou deflate nas respostas HTTP, reduzindo significativamente o tamanho dos dados transmitidos — especialmente em respostas JSON extensas. A compressão ocorre de forma transparente: o middleware verifica o cabeçalho `Accept-Encoding` da requisição e, se o cliente suportar, comprime a resposta automaticamente antes de enviá-la. Em APIs que retornam listas grandes de dados, a redução no tamanho da resposta pode chegar a 70–80%.

```bash
npm install compression
```

```javascript
import compression from 'compression';

// Aplica compressão em todas as respostas acima de 1 KB (padrão)
app.use(compression());

// Com configuração personalizada
app.use(
  compression({
    level: 6,        // Nível de compressão: 0 (nenhum) a 9 (máximo). 6 é o padrão.
    threshold: 1024, // Só comprime respostas maiores que 1 KB
    filter: (req, res) => {
      // Não comprime se o cliente enviar o cabeçalho x-no-compression
      if (req.headers['x-no-compression']) return false;
      return compression.filter(req, res); // Comportamento padrão para os demais casos
    },
  })
);
```

#### Composição em app.js

Na prática, todos esses middlewares são registrados em sequência no `app.js`, antes das definições de rota. A ordem importa: `helmet` e `cors` devem vir primeiro, pois atuam nos cabeçalhos da resposta; `compression` deve preceder o envio de qualquer corpo; `morgan` pode vir em qualquer posição antes das rotas, mas convencionalmente é registrado logo no início para capturar todas as requisições.

```javascript
// src/app.js
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { router } from './routes/index.js';
import { middlewareDeErros } from './middlewares/erros.middleware.js';

const app = express();

// Segurança e cabeçalhos
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));

// Performance
app.use(compression());

// Logging
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting
app.use('/api', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));

// Rotas
app.use('/api', router);

// Tratamento de erros (sempre por último)
app.use(middlewareDeErros);

export default app;
```

### 2.3.5 Criando middlewares customizados

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

> 📷 **Sugestão de imagem:** Diagrama de pipeline mostrando a cadeia de middlewares — `helmet → cors → compression → morgan → rate-limit → autenticação → validação → controller` — com setas indicando o fluxo de `next()` e os pontos onde a requisição pode ser interrompida com uma resposta de erro.

### 2.3.6 Propagação de erros

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
