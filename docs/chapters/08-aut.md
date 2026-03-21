# Capítulo 8 — Autenticação e Autorização

---

## 8.1 Introdução

Toda aplicação que lida com dados de usuários precisa responder a duas perguntas fundamentais antes de processar qualquer requisição: *quem está fazendo essa requisição?* e *essa pessoa tem permissão para fazer o que está pedindo?* A primeira pergunta é o domínio da **autenticação**; a segunda, da **autorização**. Embora frequentemente confundidos, esses dois conceitos são distintos e independentes — é perfeitamente possível autenticar um usuário sem autorizá-lo a acessar um recurso específico.

A **autenticação** é o processo de verificar a identidade de um usuário — confirmar que ele é quem diz ser. O mecanismo mais comum é a combinação de e-mail e senha, mas existem alternativas como biometria, autenticação por token de e-mail e login via redes sociais (Social Login). A **autorização** é o processo subsequente: dado que a identidade foi verificada, determinar quais recursos e operações esse usuário específico pode acessar. Um usuário comum pode listar seus próprios pedidos; um administrador pode listar os pedidos de todos os usuários.

Este capítulo constrói, passo a passo, um sistema completo de autenticação e autorização para a API desenvolvida nos capítulos anteriores. O ponto de partida é uma revisão dos mecanismos de gerenciamento de estado em HTTP — cookies, sessões e tokens — para que a escolha por JWT seja compreendida em seu contexto histórico e técnico. Em seguida, são implementados o hash de senha com bcrypt, a geração e validação de JWT, os middlewares de proteção de rotas, o controle de acesso por papel (RBAC), o padrão de Refresh Token e, por fim, o Social Login com Passport.js.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o Capítulo 4 (arquitetura em camadas, injeção de dependência), o Capítulo 5 (Prisma e banco de dados) e o Capítulo 7 (comunicação HTTP entre frontend e backend, interceptors do Axios).

---

## 8.2 Gerenciamento de Estado em HTTP: Cookies, Sessões e Tokens

### 8.2.1 O problema: HTTP é stateless

Como estabelecido no Capítulo 1, o HTTP é um protocolo **sem estado** (*stateless*): cada requisição é completamente independente das anteriores. O servidor não tem memória intrínseca de que o cliente fez uma requisição anterior, de que ele se autenticou com sucesso ou de quais recursos ele acessou. Cada requisição chega ao servidor como se fosse a primeira interação com aquele cliente.

Esse design é deliberado e traz vantagens importantes — escalabilidade, simplicidade, paralelismo — mas cria um desafio fundamental para aplicações que precisam manter o contexto do usuário entre requisições. Se o usuário faz login e em seguida solicita seu perfil, como o servidor sabe, na segunda requisição, que é o mesmo usuário que acabou de se autenticar?

Ao longo da história da Web, três abordagens principais foram desenvolvidas para resolver esse problema: cookies, sessões e tokens.

### 8.2.2 Cookies

Um **cookie** é um pequeno fragmento de dado que o servidor envia ao navegador através do cabeçalho `Set-Cookie` em uma resposta HTTP. O navegador armazena esse dado e o reenvia automaticamente em **todas as requisições subsequentes** para o mesmo domínio, através do cabeçalho `Cookie`. Esse mecanismo de reenvio automático é o que permite ao servidor "reconhecer" o cliente entre requisições.

```
// Servidor → Navegador (resposta HTTP)
Set-Cookie: sessionId=abc123; HttpOnly; Secure; SameSite=Strict; Max-Age=3600

// Navegador → Servidor (requisições subsequentes, automático)
Cookie: sessionId=abc123
```

Os atributos do cookie controlam seu comportamento de segurança:

**`HttpOnly`** impede que JavaScript do lado do cliente acesse o cookie via `document.cookie`. Isso é fundamental para prevenir ataques de XSS (*Cross-Site Scripting*) que tentam roubar o cookie de sessão.

**`Secure`** garante que o cookie só seja enviado em conexões HTTPS, impedindo interceptação em redes inseguras.

**`SameSite`** controla quando o cookie é enviado em requisições cross-site. `Strict` bloqueia o envio em qualquer requisição originada de outro domínio; `Lax` permite em navegações top-level (clicar em um link); `None` permite sempre (requer `Secure`). Essa proteção mitiga ataques CSRF (*Cross-Site Request Forgery*).

**`Max-Age`** e **`Expires`** definem a validade do cookie. Cookies sem esses atributos são *cookies de sessão* — expiram quando o navegador é fechado.

**`Domain`** e **`Path`** limitam em quais URLs o cookie é enviado.

Cookies são o mecanismo de transporte — eles carregam algum dado que identifica o cliente. O que esse dado representa é o que diferencia sessões de tokens.

### 8.2.3 Sessões baseadas em servidor

Na abordagem clássica de **sessão**, o servidor mantém um armazenamento interno (em memória, Redis ou banco de dados) onde guarda o estado de cada usuário autenticado. O cookie carrega apenas um identificador de sessão — uma string opaca e aleatória, como `abc123` — que serve como chave para recuperar o estado correspondente no servidor.

O fluxo é o seguinte: o usuário faz login com e-mail e senha; o servidor verifica as credenciais, cria uma entrada no armazenamento de sessões com os dados do usuário e retorna ao navegador um cookie com o `sessionId`. Em cada requisição subsequente, o navegador envia o cookie; o servidor usa o `sessionId` para recuperar o estado da sessão do armazenamento e sabe quem é o usuário.

```javascript
// Express com express-session
import session from 'express-session';

app.use(session({
  secret:            process.env.SESSION_SECRET,
  resave:            false,
  saveUninitialized: false,
  cookie:            { httpOnly: true, secure: true, maxAge: 3600000 },
}));

// Na rota de login
app.post('/login', async (req, res) => {
  const usuario = await verificarCredenciais(req.body.email, req.body.senha);
  req.session.usuarioId = usuario.id;   // armazena na sessão
  req.session.papel     = usuario.papel;
  res.json({ mensagem: 'Login realizado' });
});

// Em rotas protegidas
app.get('/perfil', (req, res) => {
  if (!req.session.usuarioId) {
    return res.status(401).json({ erro: 'Não autenticado' });
  }
  res.json({ usuarioId: req.session.usuarioId });
});
```

Essa abordagem funciona bem para aplicações web tradicionais com um único servidor, mas apresenta limitações relevantes em arquiteturas modernas:

O **armazenamento de sessões é stateful no servidor**: o servidor precisa manter o estado de todos os usuários autenticados. Se a aplicação escala horizontalmente com múltiplos servidores (load balancing), uma requisição que chega ao Servidor B não encontra a sessão criada pelo Servidor A — a menos que as sessões sejam armazenadas em um serviço centralizado como o Redis, o que adiciona complexidade e um ponto de falha.

As sessões também são **difíceis de compartilhar entre domínios**: cookies são enviados automaticamente apenas para o domínio que os criou, o que complica cenários onde múltiplos frontends (web, mobile, parceiros) consomem a mesma API.

### 8.2.4 Armazenamento no cliente: localStorage e sessionStorage

Uma alternativa ao cookie para armazenar dados de autenticação no navegador é a **Web Storage API**, disponível em dois sabores:

**`localStorage`** persiste os dados mesmo após o navegador ser fechado. Os dados só são removidos explicitamente pelo código JavaScript ou pelo usuário através das ferramentas do navegador. É acessível por qualquer script JavaScript no mesmo domínio.

**`sessionStorage`** persiste os dados apenas durante a sessão atual da aba do navegador. Fechar a aba apaga os dados. Cada aba tem seu próprio `sessionStorage` independente.

```javascript
// Armazenando um token JWT no localStorage
localStorage.setItem('token', jwt);

// Recuperando
const token = localStorage.getItem('token');

// Removendo (logout)
localStorage.removeItem('token');
```

A principal vantagem dessas APIs é a simplicidade de uso via JavaScript — não há envio automático em requisições, o que dá ao desenvolvedor controle total. A principal desvantagem é exatamente essa: por ser acessível via JavaScript, o conteúdo é vulnerável a ataques XSS. Se um script malicioso for injetado na página, ele pode ler e exfiltrar todos os dados do `localStorage`.

A decisão de armazenar tokens em cookies `HttpOnly` versus `localStorage` é um dos debates mais recorrentes em segurança web. A posição mais segura é a de cookies `HttpOnly` com `SameSite=Strict` — inacessíveis ao JavaScript e, portanto, imunes a XSS. O `localStorage` é mais conveniente para SPAs mas requer atenção redobrada à prevenção de XSS.

### 8.2.5 Tokens JWT — motivação e posicionamento

Os **tokens** surgem como uma alternativa *stateless* às sessões. Em vez de armazenar o estado do usuário no servidor e usar um identificador opaco, o servidor codifica as informações do usuário diretamente em um token assinado que é enviado ao cliente. Em cada requisição subsequente, o cliente envia o token; o servidor verifica a assinatura e extrai as informações — sem nenhuma consulta a um armazenamento de sessões.

Essa abordagem resolve os problemas de escalabilidade e compatibilidade cross-domain das sessões: qualquer servidor que conheça a chave de assinatura pode validar o token sem coordenação com outros servidores. O **JWT** (*JSON Web Token*) é o formato padronizado mais utilizado para essa finalidade e é o objeto de estudo das próximas seções.

### 8.2.6 Comparativo das abordagens

| Critério | Sessão + Cookie | Token JWT (localStorage) | Token JWT (cookie HttpOnly) |
|---|---|---|---|
| Armazenamento no servidor | Sim (stateful) | Não (stateless) | Não (stateless) |
| Escalabilidade horizontal | Requer Redis | Nativa | Nativa |
| Vulnerabilidade a XSS | Baixa (HttpOnly) | Alta | Baixa (HttpOnly) |
| Vulnerabilidade a CSRF | Moderada (mitigada por SameSite) | Nenhuma | Moderada (mitigada por SameSite) |
| Uso em APIs cross-domain | Complexo | Simples | Requer configuração de CORS |
| Revogação imediata | Simples (apagar sessão) | Complexa (requer blocklist) | Complexa (requer blocklist) |
| Adequado para | Apps web tradicionais, SSR | SPAs, APIs públicas | SPAs com alta necessidade de segurança |

---

## 8.3 Hash de Senha com bcrypt

### 8.3.1 Por que nunca armazenar senhas em texto puro

Armazenar senhas em texto puro é uma falha de segurança grave e indesculpável. Se o banco de dados for comprometido — por injeção SQL, backup exposto, acesso indevido de funcionário ou qualquer outra vulnerabilidade — todas as senhas dos usuários são imediatamente conhecidas pelo atacante. Como a maioria das pessoas reutiliza senhas em múltiplos serviços, uma única violação pode comprometer contas de e-mail, bancos e outros sistemas sensíveis do usuário.

A solução é armazenar não a senha, mas o resultado de uma **função de hash criptográfica** aplicada à senha. Uma função de hash é uma função unidirecional: dado o hash, é computacionalmente inviável recuperar a senha original. Na autenticação, o servidor aplica a mesma função ao que o usuário digitou e compara o resultado com o hash armazenado.

Funções de hash genéricas como MD5 e SHA-256 são inadequadas para senhas por dois motivos: são muito rápidas (permitindo bilhões de tentativas por segundo em ataques de força bruta) e são determinísticas (a mesma entrada sempre produz a mesma saída, tornando ataques de dicionário pré-computado — *rainbow tables* — viáveis).

### 8.3.2 O bcrypt e seu custo computacional

O **bcrypt** foi projetado especificamente para hash de senhas. Ele resolve os problemas das funções genéricas de duas formas: é **deliberadamente lento** — o custo computacional é configurável através de um fator de trabalho (*work factor* ou *cost*) — e incorpora um **salt** aleatório em cada hash, tornando impossível o uso de rainbow tables.

O salt é um valor aleatório gerado para cada senha antes do hash. Duas senhas idênticas produzem hashes diferentes porque os salts são diferentes. O salt é armazenado junto ao hash (não é um segredo), e o bcrypt o usa automaticamente na comparação.

O fator de custo determina quantas iterações o algoritmo executa. O valor padrão recomendado é **12** — resulta em um hash que leva aproximadamente 300ms para ser calculado, o que é imperceptível para o usuário mas torna ataques de força bruta impraticáveis (300ms × bilhões de tentativas = décadas).

```bash
npm install bcrypt
```

```javascript
import bcrypt from 'bcrypt';

const CUSTO = 12; // fator de trabalho — aumente com o tempo conforme o hardware evolui

// ── Hash de senha (no cadastro) ──────────────────────────
const senhaTexto = 'minhasenha123';
const hash = await bcrypt.hash(senhaTexto, CUSTO);
// hash: '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/DewokTRn...'
// O hash inclui o algoritmo ($2b$), o custo ($12$) e o salt (próximos 22 chars)

// ── Verificação (no login) ───────────────────────────────
const senhaCorreta = await bcrypt.compare('minhasenha123', hash); // true
const senhaErrada  = await bcrypt.compare('outrasenha',   hash); // false
```

!!! warning "bcrypt.compare é assíncrono por design"
    Nunca compare hashes com `===`. A função `bcrypt.compare()` é a única forma correta — ela extrai o salt do hash armazenado, aplica o mesmo processo à senha fornecida e compara os resultados de forma segura contra *timing attacks* (ataques que medem diferenças de tempo na comparação para inferir informações).

### 8.3.3 Protegendo o campo senha nas respostas da API

Um detalhe importante: o campo `senha` (hash) nunca deve ser retornado em respostas da API. O Prisma facilita isso com `select` parcial:

```javascript
// src/repositories/usuarios.repository.prisma.js

async listarTodos() {
  return prisma.usuario.findMany({
    select: { id: true, nome: true, email: true, papel: true, criadoEm: true },
    // senha deliberadamente omitida
  });
}

async buscarPorEmail(email) {
  // Este método é usado APENAS internamente para autenticação
  // retorna o hash da senha para comparação
  return prisma.usuario.findUnique({ where: { email } });
}
```

---

## 8.4 JSON Web Tokens (JWT)

### 8.4.1 Anatomia de um JWT

Um **JWT** (*JSON Web Token*, pronunciado "jot") é uma string compacta composta por três partes separadas por pontos: `header.payload.signature`.

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOjEsImVtYWlsIjoiYW5hQGV4LmNvbSIsInBhcGVsIjoidXNlciIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDg2NDAwfQ.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

**Header** — metadados do token, codificados em Base64URL:
```json
{ "alg": "HS256", "typ": "JWT" }
```

**Payload** — as *claims* (afirmações) sobre o usuário, codificadas em Base64URL:
```json
{
  "sub": 1,                   // subject: ID do usuário
  "email": "ana@exemplo.com",
  "papel": "user",
  "iat": 1700000000,          // issued at: timestamp de emissão
  "exp": 1700086400           // expiration: timestamp de expiração
}
```

**Signature** — garante a integridade do token:
```
HMACSHA256(
  base64url(header) + "." + base64url(payload),
  SECRET_KEY
)
```

O servidor assina o token com uma chave secreta conhecida apenas por ele. Qualquer alteração no header ou payload invalida a assinatura, pois o cliente não conhece a chave para recalculá-la.

!!! warning "O payload do JWT não é criptografado"
    O JWT é **assinado**, não **criptografado**. Qualquer pessoa que possua o token pode decodificar o payload e ler seu conteúdo (basta fazer `atob()` da segunda parte em JavaScript). Nunca coloque informações sensíveis no payload — senhas, números de cartão, dados médicos. O payload é público; apenas sua integridade é protegida.

### 8.4.2 Fluxo de autenticação com JWT

```
Cliente                                    Servidor
  │                                           │
  │  POST /auth/login {email, senha}          │
  │──────────────────────────────────────────▶│
  │                                           │ 1. Busca usuário por email
  │                                           │ 2. bcrypt.compare(senha, hash)
  │                                           │ 3. jwt.sign({sub, email, papel})
  │  200 OK { accessToken, refreshToken }     │
  │◀──────────────────────────────────────────│
  │                                           │
  │  GET /api/perfil                          │
  │  Authorization: Bearer <accessToken>      │
  │──────────────────────────────────────────▶│
  │                                           │ 4. jwt.verify(token, SECRET)
  │                                           │ 5. Extrai sub, papel do payload
  │  200 OK { id, nome, email }              │
  │◀──────────────────────────────────────────│
```

### 8.4.3 Claims padrão (Registered Claims)

O padrão JWT (RFC 7519) define um conjunto de claims reservadas com semântica bem definida:

| Claim | Nome | Descrição |
|-------|------|-----------|
| `sub` | Subject | Identificador único do sujeito (usuário) |
| `iss` | Issuer | Quem emitiu o token (ex: `"minha-api"`) |
| `aud` | Audience | Para quem o token se destina |
| `iat` | Issued At | Timestamp Unix de emissão |
| `exp` | Expiration | Timestamp Unix de expiração |
| `nbf` | Not Before | Token não é válido antes deste timestamp |
| `jti` | JWT ID | Identificador único do token (útil para blocklist) |

### 8.4.4 Tempo de expiração e segurança

O tempo de expiração do `accessToken` é uma decisão de segurança com trade-offs:

Tokens de **longa duração** (dias, semanas) são convenientes mas perigosos — se um token for comprometido, o atacante tem acesso prolongado sem que o servidor possa revogá-lo facilmente (JWT é stateless — não há como "apagar" um token válido).

Tokens de **curta duração** (15 minutos a 1 hora) limitam a janela de exposição mas exigem que o cliente obtenha novos tokens frequentemente, o que é resolvido pelo padrão Refresh Token (seção 8.9).

A recomendação para `accessToken` é **15 a 60 minutos**. Para `refreshToken`, **7 a 30 dias**.

---

## 8.5 Implementando Cadastro e Login

### 8.5.1 Instalação das dependências

```bash
npm install jsonwebtoken bcrypt
npm install --save-dev @types/jsonwebtoken  # apenas se usar TypeScript
```

### 8.5.2 Configuração das variáveis de ambiente

```bash
# .env
JWT_SECRET=seu_segredo_muito_longo_e_aleatorio_aqui_minimo_32_chars
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=outro_segredo_diferente_para_refresh_token
JWT_REFRESH_EXPIRES_IN=7d
```

!!! warning "Segredos JWT"
    O `JWT_SECRET` deve ser uma string longa (mínimo 32 caracteres), aleatória e diferente entre ambientes (dev, staging, produção). Nunca use valores previsíveis como `"secret"` ou `"minha-api"`. Gere com `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"`.

### 8.5.3 Utilitários de token

```javascript
// src/utils/jwt.js
import jwt from 'jsonwebtoken';

const SECRET         = process.env.JWT_SECRET;
const EXPIRES_IN     = process.env.JWT_EXPIRES_IN     || '15m';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;
const REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

export function gerarAccessToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN });
}

export function gerarRefreshToken(payload) {
  return jwt.sign(payload, REFRESH_SECRET, { expiresIn: REFRESH_EXPIRES });
}

export function verificarAccessToken(token) {
  return jwt.verify(token, SECRET); // lança erro se inválido ou expirado
}

export function verificarRefreshToken(token) {
  return jwt.verify(token, REFRESH_SECRET);
}
```

### 8.5.4 Schema Prisma atualizado

O model `Usuario` precisa de um campo `papel` para RBAC e de uma tabela para armazenar refresh tokens:

```prisma
// prisma/schema.prisma

enum Papel {
  USER
  ADMIN
}

model Usuario {
  id           Int            @id @default(autoincrement())
  nome         String
  email        String         @unique
  senha        String
  papel        Papel          @default(USER)
  criadoEm    DateTime       @default(now()) @map("criado_em")
  refreshTokens RefreshToken[]

  @@map("usuarios")
}

model RefreshToken {
  id        Int      @id @default(autoincrement())
  token     String   @unique
  usuarioId Int      @map("usuario_id")
  expiresAt DateTime @map("expires_at")
  criadoEm DateTime @default(now()) @map("criado_em")
  usuario   Usuario  @relation(fields: [usuarioId], references: [id], onDelete: Cascade)

  @@map("refresh_tokens")
}
```

```bash
npx prisma migrate dev --name adicionar_auth
```

### 8.5.5 AuthService

```javascript
// src/services/auth.service.js
import bcrypt                                 from 'bcrypt';
import { AppError }                           from '../utils/AppError.js';
import { gerarAccessToken, gerarRefreshToken } from '../utils/jwt.js';

const CUSTO_BCRYPT = 12;

export class AuthService {
  constructor(authRepository) {
    this.repository = authRepository;
  }

  async registrar({ nome, email, senha }) {
    const jaExiste = await this.repository.buscarUsuarioPorEmail(email);
    if (jaExiste) throw new AppError('E-mail já cadastrado', 409);

    const senhaHash = await bcrypt.hash(senha, CUSTO_BCRYPT);
    const usuario   = await this.repository.criarUsuario({ nome, email, senha: senhaHash });

    // Não retorna a senha no objeto de resposta
    const { senha: _, ...usuarioSemSenha } = usuario;
    return usuarioSemSenha;
  }

  async login({ email, senha }) {
    // Busca com senha para comparação
    const usuario = await this.repository.buscarUsuarioPorEmail(email);

    // Mensagem genérica — não revela se o e-mail existe ou não
    if (!usuario) throw new AppError('Credenciais inválidas', 401);

    const senhaCorreta = await bcrypt.compare(senha, usuario.senha);
    if (!senhaCorreta) throw new AppError('Credenciais inválidas', 401);

    const payload = { sub: usuario.id, email: usuario.email, papel: usuario.papel };

    const accessToken  = gerarAccessToken(payload);
    const refreshToken = gerarRefreshToken({ sub: usuario.id });

    // Persiste o refresh token no banco
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 dias
    await this.repository.salvarRefreshToken({
      token:     refreshToken,
      usuarioId: usuario.id,
      expiresAt,
    });

    const { senha: _, ...usuarioSemSenha } = usuario;
    return { accessToken, refreshToken, usuario: usuarioSemSenha };
  }

  async logout(refreshToken) {
    await this.repository.revogarRefreshToken(refreshToken);
  }
}
```

### 8.5.6 AuthRepository

```javascript
// src/repositories/auth.repository.prisma.js
import { prisma } from '../config/database.js';

export class AuthRepositoryPrisma {

  async buscarUsuarioPorEmail(email) {
    // Inclui a senha — usado apenas internamente para autenticação
    return prisma.usuario.findUnique({ where: { email } });
  }

  async criarUsuario(dados) {
    return prisma.usuario.create({ data: dados });
  }

  async salvarRefreshToken({ token, usuarioId, expiresAt }) {
    return prisma.refreshToken.create({
      data: { token, usuarioId, expiresAt },
    });
  }

  async buscarRefreshToken(token) {
    return prisma.refreshToken.findUnique({
      where:   { token },
      include: { usuario: true },
    });
  }

  async revogarRefreshToken(token) {
    return prisma.refreshToken.deleteMany({ where: { token } });
  }

  async revogarTodosTokensDoUsuario(usuarioId) {
    return prisma.refreshToken.deleteMany({ where: { usuarioId } });
  }
}
```

### 8.5.7 AuthController e rotas

```javascript
// src/controllers/auth.controller.js
export class AuthController {
  constructor(service) {
    this.service  = service;
    this.registrar = this.registrar.bind(this);
    this.login     = this.login.bind(this);
    this.logout    = this.logout.bind(this);
  }

  async registrar(req, res, next) {
    try {
      const usuario = await this.service.registrar(req.body);
      res.status(201).json(usuario);
    } catch (err) { next(err); }
  }

  async login(req, res, next) {
    try {
      const resultado = await this.service.login(req.body);
      res.json(resultado);
    } catch (err) { next(err); }
  }

  async logout(req, res, next) {
    try {
      const { refreshToken } = req.body;
      if (refreshToken) await this.service.logout(refreshToken);
      res.status(204).send();
    } catch (err) { next(err); }
  }
}
```

```javascript
// src/routes/auth.routes.js
import { Router }               from 'express';
import { AuthRepositoryPrisma } from '../repositories/auth.repository.prisma.js';
import { AuthService }          from '../services/auth.service.js';
import { AuthController }       from '../controllers/auth.controller.js';
import { body }                 from 'express-validator';
import { verificarValidacao }   from '../middlewares/validacao.middleware.js';

const repository = new AuthRepositoryPrisma();
const service    = new AuthService(repository);
const controller = new AuthController(service);

const router = Router();

router.post('/register',
  [
    body('nome').trim().notEmpty().withMessage('Nome é obrigatório'),
    body('email').isEmail().withMessage('E-mail inválido').normalizeEmail(),
    body('senha').isLength({ min: 8 }).withMessage('Senha deve ter ao menos 8 caracteres'),
  ],
  verificarValidacao,
  controller.registrar
);

router.post('/login',
  [
    body('email').isEmail().withMessage('E-mail inválido'),
    body('senha').notEmpty().withMessage('Senha é obrigatória'),
  ],
  verificarValidacao,
  controller.login
);

router.post('/logout', controller.logout);

export default router;
```

```javascript
// src/routes/index.js
import authRouter    from './auth.routes.js';
import usuariosRouter from './usuarios.routes.js';

export const router = Router();
router.use('/auth',     authRouter);
router.use('/usuarios', usuariosRouter);
```

---

## 8.6 Middleware de Autenticação

### 8.6.1 Extraindo e validando o token

O cliente envia o JWT no cabeçalho `Authorization` com o prefixo `Bearer`:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

O middleware de autenticação extrai o token, verifica a assinatura e popula `req.usuario` com o payload decodificado:

```javascript
// src/middlewares/autenticacao.middleware.js
import { verificarAccessToken } from '../utils/jwt.js';
import { AppError }             from '../utils/AppError.js';

export const autenticar = (req, res, next) => {
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AppError('Token de acesso não fornecido', 401));
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload  = verificarAccessToken(token);
    req.usuario    = payload; // { sub, email, papel, iat, exp }
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return next(new AppError('Token expirado', 401));
    }
    if (err.name === 'JsonWebTokenError') {
      return next(new AppError('Token inválido', 401));
    }
    next(err);
  }
};
```

### 8.6.2 Middleware de autenticação opcional

Em alguns endpoints, o servidor pode se comportar diferentemente dependendo de o usuário estar autenticado ou não (ex: retornar mais campos para usuários autenticados). O middleware opcional tenta verificar o token mas não bloqueia se ele estiver ausente:

```javascript
// src/middlewares/autenticacao.middleware.js
export const autenticarOpcional = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) return next(); // sem token — continua

  const token = authHeader.split(' ')[1];
  try {
    req.usuario = verificarAccessToken(token);
  } catch {
    // Token inválido ou expirado — ignora e continua sem usuário
  }
  next();
};
```

---

## 8.7 Protegendo Rotas

### 8.7.1 Aplicação seletiva do middleware

O middleware `autenticar` pode ser aplicado a rotas individuais, a grupos de rotas via `router.use()` ou globalmente. A abordagem mais flexível é aplicá-lo nas rotas que precisam de proteção:

```javascript
// src/routes/usuarios.routes.js
import { autenticar } from '../middlewares/autenticacao.middleware.js';

const router = Router();

// Rotas públicas
router.get('/',    controller.index);
router.get('/:id', controller.show);

// Rotas protegidas — requerem token válido
router.post('/',      autenticar, controller.create);
router.put('/:id',    autenticar, controller.update);
router.delete('/:id', autenticar, controller.destroy);

export default router;
```

Para proteger todas as rotas de um módulo de uma vez:

```javascript
// Protege TODAS as rotas deste router
router.use(autenticar);

router.get('/',    controller.index);
router.post('/',   controller.create);
// ...
```

### 8.7.2 Acessando o usuário autenticado no controller

Com o middleware configurado, `req.usuario` estará disponível em qualquer handler após `autenticar`:

```javascript
// src/controllers/usuarios.controller.js
async show(req, res, next) {
  try {
    const id      = Number(req.params.id);
    const usuario = await this.service.buscarPorId(id);

    // Usuário só pode ver seu próprio perfil (a menos que seja admin)
    if (req.usuario.sub !== id && req.usuario.papel !== 'ADMIN') {
      throw new AppError('Acesso negado', 403);
    }

    res.json(usuario);
  } catch (err) { next(err); }
}
```

---

## 8.8 Autorização e RBAC

### 8.8.1 Autenticação vs. autorização — revisão

A autenticação confirmou *quem* é o usuário. A autorização determina *o que* esse usuário pode fazer. Um usuário autenticado com papel `USER` não deve conseguir acessar endpoints administrativos — mesmo que possua um token válido.

### 8.8.2 Middleware de autorização por papel

```javascript
// src/middlewares/autorizacao.middleware.js
import { AppError } from '../utils/AppError.js';

// Factory function: retorna um middleware configurado para os papéis aceitos
export const exigirPapel = (...papeisPermitidos) => (req, res, next) => {
  if (!req.usuario) {
    return next(new AppError('Não autenticado', 401));
  }

  if (!papeisPermitidos.includes(req.usuario.papel)) {
    return next(new AppError(
      `Acesso negado. Requer papel: ${papeisPermitidos.join(' ou ')}`, 403
    ));
  }

  next();
};
```

```javascript
// src/routes/usuarios.routes.js
import { autenticar }  from '../middlewares/autenticacao.middleware.js';
import { exigirPapel } from '../middlewares/autorizacao.middleware.js';

router.get('/',
  autenticar,
  exigirPapel('ADMIN'),          // apenas admins listam todos os usuários
  controller.index
);

router.delete('/:id',
  autenticar,
  exigirPapel('ADMIN'),
  controller.destroy
);

router.put('/:id',
  autenticar,
  exigirPapel('ADMIN', 'USER'),  // admins e o próprio usuário podem editar
  controller.update
);
```

### 8.8.3 Autorização baseada em propriedade do recurso

Além do papel, é comum verificar se o usuário é o proprietário do recurso que está tentando modificar:

```javascript
// src/middlewares/autorizacao.middleware.js

// Verifica se o usuário é dono do recurso OU tem papel admin
export const exigirProprietarioOuAdmin = (req, res, next) => {
  const idRecurso = Number(req.params.id);
  const { sub: idUsuario, papel } = req.usuario;

  if (papel === 'ADMIN' || idUsuario === idRecurso) {
    return next();
  }

  next(new AppError('Você não tem permissão para modificar este recurso', 403));
};
```

```javascript
router.put('/:id',
  autenticar,
  exigirProprietarioOuAdmin,  // dono ou admin pode editar
  controller.update
);
```

---

## 8.9 Refresh Token

### 8.9.1 O problema da expiração do accessToken

Com accessTokens de 15 minutos, o usuário seria desconectado da aplicação 15 minutos após o login — uma experiência inaceitável. A solução é o padrão **Refresh Token**: dois tokens com papéis complementares.

O **accessToken** tem vida curta (15–60 minutos) e é enviado em todas as requisições autenticadas. O **refreshToken** tem vida longa (7–30 dias), é armazenado de forma mais segura e serve exclusivamente para obter novos accessTokens quando o anterior expira. O servidor armazena os refreshTokens no banco de dados, o que permite revogá-los individualmente (logout de um dispositivo específico) ou em massa (logout de todos os dispositivos).

### 8.9.2 Fluxo completo com Refresh Token

```
Login
  │── accessToken  (15min)  → armazenado no cliente (localStorage ou memória)
  └── refreshToken (7 dias) → armazenado no cliente (cookie HttpOnly ou localStorage)

Requisição normal:
  Authorization: Bearer <accessToken>

Quando accessToken expira (servidor retorna 401):
  POST /auth/refresh
  Body: { refreshToken }
  Resposta: { accessToken (novo), refreshToken (novo — rotação) }

Logout:
  POST /auth/logout
  Body: { refreshToken }
  Servidor: deleta o refreshToken do banco → token não pode mais ser usado
```

### 8.9.3 Implementação do endpoint de refresh

```javascript
// src/services/auth.service.js — adicionar ao AuthService

async refresh(refreshTokenAntigo) {
  // 1. Busca o refresh token no banco
  const registro = await this.repository.buscarRefreshToken(refreshTokenAntigo);

  if (!registro) throw new AppError('Refresh token inválido', 401);

  // 2. Verifica se não expirou no banco
  if (new Date() > registro.expiresAt) {
    await this.repository.revogarRefreshToken(refreshTokenAntigo);
    throw new AppError('Refresh token expirado. Faça login novamente.', 401);
  }

  // 3. Verifica a assinatura criptográfica
  try {
    verificarRefreshToken(refreshTokenAntigo);
  } catch {
    await this.repository.revogarRefreshToken(refreshTokenAntigo);
    throw new AppError('Refresh token inválido', 401);
  }

  const { usuario } = registro;

  // 4. Rotação: revoga o token antigo e gera um novo par
  await this.repository.revogarRefreshToken(refreshTokenAntigo);

  const payload      = { sub: usuario.id, email: usuario.email, papel: usuario.papel };
  const accessToken  = gerarAccessToken(payload);
  const novoRefresh  = gerarRefreshToken({ sub: usuario.id });

  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  await this.repository.salvarRefreshToken({
    token: novoRefresh, usuarioId: usuario.id, expiresAt,
  });

  return { accessToken, refreshToken: novoRefresh };
}
```

```javascript
// src/routes/auth.routes.js — adicionar
router.post('/refresh', controller.refresh);
```

### 8.9.4 Rotação de Refresh Tokens

A **rotação** é uma prática de segurança importante: a cada uso do refreshToken, um novo é emitido e o anterior é revogado. Isso significa que um refreshToken só pode ser usado uma vez. Se um atacante roubar e usar o refreshToken antes do usuário legítimo, o próximo uso pelo usuário legítimo falhará (o token já foi revogado), alertando para uma possível comprometimento. Implementações mais sofisticadas detectam esse reuso e revogam toda a família de tokens do usuário.

---

## 8.10 Social Login com Passport.js

### 8.10.1 OAuth 2.0 e OpenID Connect — conceitos

O **OAuth 2.0** é um protocolo de autorização que permite que uma aplicação (o "cliente") acesse recursos em nome de um usuário em outro serviço (o "provedor"), sem que o usuário precise revelar suas credenciais à aplicação. No contexto de Social Login, o fluxo mais utilizado é o **Authorization Code**:

1. O usuário clica em "Entrar com Google"
2. A aplicação redireciona o usuário para o servidor de autorização do Google com um `client_id`, `redirect_uri` e `scope`
3. O usuário se autentica no Google e concede permissão
4. O Google redireciona de volta para a aplicação com um `code` temporário
5. A aplicação troca o `code` por um `access_token` (e opcionalmente um `id_token`) chamando a API do Google com o `client_secret`
6. A aplicação usa o `access_token` para obter o perfil do usuário

O **OpenID Connect** é uma camada de identidade sobre o OAuth 2.0 que padroniza como obter informações do usuário (nome, e-mail, foto). O `id_token` retornado é um JWT que contém essas informações.

### 8.10.2 Passport.js

O **Passport.js** é o middleware de autenticação mais utilizado no ecossistema Node.js. Ele funciona através de **estratégias** (*strategies*) — plugins que implementam diferentes mecanismos de autenticação. Existem estratégias para mais de 500 provedores, incluindo Google, GitHub, Facebook, Twitter e dezenas de outros.

```bash
npm install passport passport-google-oauth20 passport-github2
```

### 8.10.3 Configurando as credenciais OAuth

Para usar o OAuth, é necessário registrar a aplicação no painel de desenvolvedor de cada provedor e obter um `clientId` e `clientSecret`:

- **Google:** [console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → Credentials
- **GitHub:** GitHub → Settings → Developer settings → OAuth Apps

```bash
# .env
GOOGLE_CLIENT_ID=seu_google_client_id
GOOGLE_CLIENT_SECRET=seu_google_client_secret
GITHUB_CLIENT_ID=seu_github_client_id
GITHUB_CLIENT_SECRET=seu_github_client_secret

# URL de redirecionamento configurada no painel do provedor
CALLBACK_BASE_URL=http://localhost:3000
```

### 8.10.4 Configuração do Passport

```javascript
// src/config/passport.js
import passport          from 'passport';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';
import { Strategy as GitHubStrategy } from 'passport-github2';
import { prisma }        from './database.js';

passport.use(new GoogleStrategy(
  {
    clientID:     process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL:  `${process.env.CALLBACK_BASE_URL}/auth/google/callback`,
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      // Tenta encontrar o usuário pelo e-mail do Google
      const email = profile.emails[0].value;
      let usuario = await prisma.usuario.findUnique({ where: { email } });

      if (!usuario) {
        // Primeiro acesso: cria o usuário automaticamente
        usuario = await prisma.usuario.create({
          data: {
            nome:  profile.displayName,
            email,
            senha: '',           // senha vazia — login é via OAuth
            papel: 'USER',
          },
        });
      }

      return done(null, usuario);
    } catch (err) {
      return done(err, null);
    }
  }
));

passport.use(new GitHubStrategy(
  {
    clientID:     process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    callbackURL:  `${process.env.CALLBACK_BASE_URL}/auth/github/callback`,
    scope:        ['user:email'],
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      const email = profile.emails?.[0]?.value;
      if (!email) return done(new Error('E-mail não disponível no perfil GitHub'), null);

      let usuario = await prisma.usuario.findUnique({ where: { email } });

      if (!usuario) {
        usuario = await prisma.usuario.create({
          data: {
            nome:  profile.displayName || profile.username,
            email,
            senha: '',
            papel: 'USER',
          },
        });
      }

      return done(null, usuario);
    } catch (err) {
      return done(err, null);
    }
  }
));

export default passport;
```

### 8.10.5 Rotas de Social Login

```javascript
// src/routes/auth.routes.js — adicionar ao router existente
import passport from '../config/passport.js';
import { gerarAccessToken, gerarRefreshToken } from '../utils/jwt.js';

// ── Google ──────────────────────────────────────────────
// Redireciona para a tela de login do Google
router.get('/google',
  passport.authenticate('google', { scope: ['profile', 'email'], session: false })
);

// Google redireciona de volta aqui após o login
router.get('/google/callback',
  passport.authenticate('google', { session: false, failureRedirect: '/login?erro=google' }),
  (req, res) => {
    const usuario     = req.user;
    const payload     = { sub: usuario.id, email: usuario.email, papel: usuario.papel };
    const accessToken = gerarAccessToken(payload);

    // Redireciona para o frontend com o token na query string
    // Em produção: use uma URL mais segura ou um cookie HttpOnly
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${accessToken}`);
  }
);

// ── GitHub ──────────────────────────────────────────────
router.get('/github',
  passport.authenticate('github', { scope: ['user:email'], session: false })
);

router.get('/github/callback',
  passport.authenticate('github', { session: false, failureRedirect: '/login?erro=github' }),
  (req, res) => {
    const usuario     = req.user;
    const payload     = { sub: usuario.id, email: usuario.email, papel: usuario.papel };
    const accessToken = gerarAccessToken(payload);
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?token=${accessToken}`);
  }
);
```

```javascript
// src/app.js — registrar o Passport
import './config/passport.js'; // inicializa as estratégias

// Passport não precisa de app.use(passport.initialize()) no modo stateless (session: false)
```

### 8.10.6 Tratamento no frontend (Vue/React)

```javascript
// No frontend — botão de Social Login
function LoginPage() {
  function loginComGoogle() {
    // Redireciona para o backend, que inicia o fluxo OAuth
    window.location.href = 'http://localhost:3000/api/auth/google';
  }

  return <button onClick={loginComGoogle}>Entrar com Google</button>;
}

// Página de callback — recebe o token via query string
// src/pages/AuthCallbackPage.jsx
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

export default function AuthCallbackPage() {
  const navigate = useNavigate();

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const token  = params.get('token');

    if (token) {
      localStorage.setItem('token', token);
      navigate('/');
    } else {
      navigate('/login?erro=social');
    }
  }, [navigate]);

  return <p>Autenticando...</p>;
}
```

---

## 8.11 Segurança Adicional

### 8.11.1 Rate limiting em rotas de autenticação

Rotas de login e cadastro são alvos naturais de ataques de força bruta. O `express-rate-limit` — apresentado no Capítulo 3 — deve ser aplicado com limites mais restritivos nessas rotas:

```javascript
// src/middlewares/rateLimiter.middleware.js
import rateLimit from 'express-rate-limit';

export const limiteLogin = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutos
  max: 10,                    // 10 tentativas por IP
  message: { erro: 'Muitas tentativas de login. Tente novamente em 15 minutos.' },
  standardHeaders: true,
  legacyHeaders: false,
});

export const limiteCadastro = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hora
  max: 5,                     // 5 cadastros por IP por hora
  message: { erro: 'Limite de cadastros atingido. Tente novamente mais tarde.' },
});
```

```javascript
router.post('/login',    limiteLogin,    validacao, controller.login);
router.post('/register', limiteCadastro, validacao, controller.registrar);
```

### 8.11.2 Proteção contra timing attacks

Um **timing attack** é um ataque em que o atacante mede o tempo de resposta do servidor para inferir informações. Por exemplo: se a busca pelo e-mail retorna imediatamente quando o usuário não existe, mas leva 300ms quando existe (porque o bcrypt é executado), o atacante pode enumerar e-mails válidos medindo o tempo de resposta.

A solução é garantir tempo de resposta constante — executar o bcrypt mesmo quando o usuário não existe:

```javascript
// src/services/auth.service.js
const HASH_FICTICIO = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/lewokTRnhypqoo'; // hash válido qualquer

async login({ email, senha }) {
  const usuario = await this.repository.buscarUsuarioPorEmail(email);

  // Se o usuário não existe, compara com um hash fictício
  // Isso garante que o tempo de resposta seja sempre ~300ms
  const hashParaComparar = usuario?.senha ?? HASH_FICTICIO;
  const senhaCorreta = await bcrypt.compare(senha, hashParaComparar);

  // Só depois de executar o bcrypt verificamos se o usuário existe
  if (!usuario || !senhaCorreta) {
    throw new AppError('Credenciais inválidas', 401);
  }

  // ...resto do login
}
```

### 8.11.3 Boas práticas de armazenamento do token no cliente

O debate entre armazenar o accessToken em `localStorage` versus em cookies `HttpOnly` não tem uma resposta universal. A tabela abaixo resume as considerações:

| Armazenamento | Proteção XSS | Proteção CSRF | Uso em SPA | Recomendado para |
|---|---|---|---|---|
| `localStorage` | Vulnerável | Imune | Simples | Protótipos, apps internos |
| `sessionStorage` | Vulnerável | Imune | Moderado | Sessões de curta duração |
| Cookie `HttpOnly` | Imune | Vulnerável (mitigado por `SameSite`) | Requer configuração | Aplicações com alto requisito de segurança |
| Memória (variável JS) | Imune | Imune | Perde ao recarregar | accessToken de vida curta |

O padrão mais seguro para SPAs modernas é: **accessToken em memória** (variável JavaScript — perde ao recarregar, mas tem vida curta de 15min) + **refreshToken em cookie `HttpOnly; SameSite=Strict`** (persiste entre recarregamentos, inacessível ao JavaScript).

---

## 8.12 Integração com o Frontend

### 8.12.1 Fluxo completo no frontend (Vue/React)

O frontend precisa lidar com quatro responsabilidades relacionadas à autenticação: realizar o login e armazenar o token, adicionar o token automaticamente em todas as requisições, lidar com tokens expirados (chamando o endpoint de refresh) e proteger rotas que exigem autenticação.

### 8.12.2 Serviço de autenticação

```javascript
// src/services/auth.service.js (frontend)
import { api } from './api.js';

export const authService = {
  async login(email, senha) {
    const { data } = await api.post('/auth/login', { email, senha });
    localStorage.setItem('accessToken',  data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    return data.usuario;
  },

  async registrar(dados) {
    const { data } = await api.post('/auth/register', dados);
    return data;
  },

  logout() {
    const refreshToken = localStorage.getItem('refreshToken');
    if (refreshToken) api.post('/auth/logout', { refreshToken }).catch(() => {});
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
  },

  getToken() {
    return localStorage.getItem('accessToken');
  },

  isAutenticado() {
    return !!this.getToken();
  },
};
```

### 8.12.3 Interceptors do Axios para refresh automático

```javascript
// src/services/api.js (frontend)
import axios from 'axios';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000/api',
});

// Adiciona o token em todas as requisições
api.interceptors.request.use(config => {
  const token = localStorage.getItem('accessToken');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Tenta renovar o token automaticamente quando recebe 401
let renovando = false;
let filaEspera = [];

api.interceptors.response.use(
  resposta => resposta,
  async erro => {
    const requisicaoOriginal = erro.config;

    if (erro.response?.status !== 401 || requisicaoOriginal._retry) {
      return Promise.reject(erro);
    }

    if (renovando) {
      // Coloca na fila enquanto já está renovando
      return new Promise((resolve, reject) => {
        filaEspera.push({ resolve, reject });
      }).then(token => {
        requisicaoOriginal.headers.Authorization = `Bearer ${token}`;
        return api(requisicaoOriginal);
      });
    }

    requisicaoOriginal._retry = true;
    renovando = true;

    try {
      const refreshToken = localStorage.getItem('refreshToken');
      if (!refreshToken) throw new Error('Sem refresh token');

      const { data } = await axios.post(
        `${import.meta.env.VITE_API_URL}/auth/refresh`,
        { refreshToken }
      );

      localStorage.setItem('accessToken',  data.accessToken);
      localStorage.setItem('refreshToken', data.refreshToken);

      // Resolve a fila de requisições pendentes com o novo token
      filaEspera.forEach(({ resolve }) => resolve(data.accessToken));
      filaEspera = [];

      requisicaoOriginal.headers.Authorization = `Bearer ${data.accessToken}`;
      return api(requisicaoOriginal);
    } catch {
      filaEspera.forEach(({ reject }) => reject(erro));
      filaEspera = [];
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      window.location.href = '/login'; // redireciona para o login
      return Promise.reject(erro);
    } finally {
      renovando = false;
    }
  }
);
```

### 8.12.4 Rotas protegidas no Vue Router

```javascript
// src/router/index.js (frontend Vue)
import { authService } from '../services/auth.service.js';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login',    component: () => import('../views/LoginView.vue') },
    { path: '/register', component: () => import('../views/RegisterView.vue') },
    {
      path:      '/usuarios',
      component: () => import('../views/UsuariosView.vue'),
      meta:      { requerAutenticacao: true },
    },
    {
      path:      '/admin',
      component: () => import('../views/AdminView.vue'),
      meta:      { requerAutenticacao: true, papel: 'ADMIN' },
    },
  ],
});

// Guard de navegação
router.beforeEach((to, from, next) => {
  if (!to.meta.requerAutenticacao) return next();

  if (!authService.isAutenticado()) {
    return next({ path: '/login', query: { redirect: to.fullPath } });
  }

  // Verificação de papel (decodifica o payload do JWT no cliente)
  if (to.meta.papel) {
    const token   = authService.getToken();
    const payload = JSON.parse(atob(token.split('.')[1]));
    if (payload.papel !== to.meta.papel) {
      return next({ path: '/' }); // sem permissão — redireciona para home
    }
  }

  next();
});

export default router;
```

### 8.12.5 Rotas protegidas no React Router

```jsx
// src/components/RotaProtegida.jsx
import { Navigate, useLocation } from 'react-router-dom';
import { authService }           from '../services/auth.service.js';

export function RotaProtegida({ children, papel }) {
  const location = useLocation();

  if (!authService.isAutenticado()) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (papel) {
    const token   = authService.getToken();
    const payload = JSON.parse(atob(token.split('.')[1]));
    if (payload.papel !== papel) {
      return <Navigate to="/" replace />;
    }
  }

  return children;
}

// src/App.jsx — uso
<Routes>
  <Route path="/login"    element={<LoginPage />} />
  <Route path="/usuarios" element={
    <RotaProtegida>
      <UsuariosPage />
    </RotaProtegida>
  } />
  <Route path="/admin" element={
    <RotaProtegida papel="ADMIN">
      <AdminPage />
    </RotaProtegida>
  } />
</Routes>
```

---

## 8.13 Exercícios Práticos

### Exercício 8.1 — Hash e verificação de senha

Implemente uma função `testarBcrypt()` que receba uma senha em texto puro, gere um hash com custo 12, imprima o hash no console, e em seguida verifique três cenários: a senha correta, a senha com uma letra diferente e a senha em maiúsculas. Observe que `bcrypt.compare` retorna `false` nos dois últimos casos — bcrypt é sensível a maiúsculas e minúsculas.

### Exercício 8.2 — Registro e login

Implemente os endpoints `POST /api/auth/register` e `POST /api/auth/login` no projeto dos capítulos anteriores. O registro deve retornar `201` com o usuário criado (sem o hash da senha). O login deve retornar `200` com `accessToken`, `refreshToken` e o objeto do usuário. Teste com o Insomnia ou curl.

### Exercício 8.3 — Middleware de autenticação

Implemente o middleware `autenticar` e aplique-o às rotas `POST`, `PUT` e `DELETE` de usuários. Verifique que: (a) uma requisição sem token retorna `401`; (b) uma requisição com token expirado retorna `401` com mensagem "Token expirado"; (c) uma requisição com token válido é processada normalmente.

### Exercício 8.4 — RBAC

Adicione o campo `papel` ao model `Usuario` com os valores `USER` e `ADMIN`. Implemente o middleware `exigirPapel` e proteja o endpoint `GET /api/usuarios` (listagem de todos) para que apenas admins possam acessá-lo. Crie dois usuários — um com papel `USER` e outro com `ADMIN` — e verifique o comportamento.

### Exercício 8.5 — Refresh Token

Implemente o endpoint `POST /api/auth/refresh`. Gere um par `accessToken` (1 minuto de duração para facilitar o teste) e `refreshToken`. Aguarde o accessToken expirar e verifique que: (a) a requisição retorna `401`; (b) chamar `/auth/refresh` com o refreshToken retorna um novo par de tokens; (c) o refreshToken antigo não pode mais ser usado (rotação).

### Exercício 8.6 — Social Login

Configure o Social Login com GitHub. Crie um aplicativo OAuth em Settings → Developer settings → OAuth Apps no GitHub, configure as variáveis de ambiente e implemente as rotas `/auth/github` e `/auth/github/callback`. Teste o fluxo completo no navegador.

---

## 8.14 Referências e Leituras Complementares

- [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [JWT.io — debugger e documentação](https://jwt.io/)
- [bcrypt — documentação npm](https://www.npmjs.com/package/bcrypt)
- [jsonwebtoken — documentação npm](https://www.npmjs.com/package/jsonwebtoken)
- [Passport.js — documentação oficial](https://www.passportjs.org/)
- [OAuth 2.0 — RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [OWASP — Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP — JWT Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [The Copenhagen Book — guia de segurança web](https://thecopenhagenbook.com/)

---

!!! note "Próximo Capítulo"
    No **Capítulo 9 — Testes Automatizados**, construiremos uma suíte de testes para a API desenvolvida ao longo do curso, utilizando Jest para testes unitários dos services e Supertest para testes de integração dos endpoints HTTP. O sistema de autenticação implementado neste capítulo será coberto por testes que verificam os cenários de sucesso, falha de credenciais, token expirado e acesso negado por papel.
