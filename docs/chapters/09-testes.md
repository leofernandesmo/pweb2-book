# Capítulo 9 — Testes Automatizados: Jest, Supertest e Playwright

---

## 9.1 Introdução

A qualidade de um sistema de software não se mede apenas pela ausência aparente de defeitos no momento de sua entrega — mede-se, sobretudo, pela capacidade de o sistema evoluir com segurança ao longo do tempo. À medida que uma base de código cresce, a probabilidade de que uma modificação em uma parte do sistema introduza uma regressão em outra parte cresce de forma não linear. Sem mecanismos formais de verificação, o desenvolvedor é forçado a depender de testes manuais repetitivos, de memória institucional ou de simples esperança — nenhuma dessas alternativas é escalável ou confiável.

Os **testes automatizados** constituem o principal instrumento de engenharia para lidar com essa complexidade. Diferentemente dos testes manuais, testes automatizados são executados de forma determinística, repetível e em questão de segundos, fornecendo feedback imediato sobre o comportamento do sistema a cada alteração. Do ponto de vista da Engenharia de Software, a ausência de uma suíte de testes adequada não representa uma economia de tempo — representa uma dívida técnica que se paga com juros crescentes à medida que o sistema evolui (FOWLER, 2018).

Este capítulo apresenta os fundamentos teóricos e práticos dos testes automatizados no contexto da API e das interfaces desenvolvidas ao longo do curso. O percurso parte dos princípios da pirâmide de testes, avança pela configuração e uso do Jest para testes unitários dos services, pelo Supertest para testes de integração dos endpoints HTTP — incluindo os cenários de autenticação e autorização implementados no Capítulo 8 — e culmina na introdução ao Playwright para testes funcionais *end-to-end* das interfaces construídas nos Capítulos 6 e 7. A seção sobre TDD (*Test-Driven Development*) posiciona os testes não apenas como mecanismo de verificação, mas como instrumento de design. O capítulo encerra com uma discussão crítica sobre cobertura de código — métrica frequentemente mal interpretada.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com a arquitetura em camadas do Capítulo 4 (especialmente injeção de dependência e o Repository Pattern), com o sistema de autenticação do Capítulo 8 e com os conceitos básicos de Node.js assíncrono (`async/await`, Promises).

---

## 9.2 A Pirâmide de Testes

### 9.2.1 Fundamentos conceituais

A **pirâmide de testes** é um modelo conceitual proposto por Mike Cohn em *Succeeding with Agile* (2009) e posteriormente refinado por Martin Fowler, que orienta a distribuição quantitativa e qualitativa dos testes automatizados de um sistema. O modelo estabelece três camadas hierárquicas — testes unitários na base, testes de integração no meio e testes de interface ou *end-to-end* no topo — e prescreve que a quantidade de testes em cada camada deve ser inversamente proporcional à sua posição na hierarquia.

Essa distribuição não é arbitrária. Ela reflete uma relação fundamental entre velocidade de execução, custo de manutenção, granularidade do diagnóstico e confiabilidade em isolamento, atributos que variam sistematicamente entre as camadas.

### 9.2.2 Testes unitários

Os **testes unitários** (*unit tests*) verificam o comportamento de uma unidade isolada de código — tipicamente uma função, um método ou uma classe — sem dependências externas reais. No contexto da arquitetura estudada neste curso, a unidade mais relevante para testes unitários é o **service**: a camada que encapsula a lógica de negócio e que, graças ao padrão de injeção de dependência introduzido no Capítulo 4, pode ser testada com repositórios falsos (*mocks* ou *stubs*) sem nenhuma conexão com banco de dados ou infraestrutura externa.

Testes unitários são caracterizados por velocidade extrema de execução (tipicamente na ordem de milissegundos), isolamento total das dependências, diagnóstico preciso de falhas (a falha aponta exatamente qual unidade está com comportamento incorreto) e facilidade de manutenção. São a fundação da pirâmide — devem ser numerosos e executados continuamente durante o desenvolvimento.

### 9.2.3 Testes de integração

Os **testes de integração** (*integration tests*) verificam o comportamento de múltiplos componentes trabalhando em conjunto. No contexto de uma API REST, o objeto mais relevante de testes de integração é o **endpoint HTTP completo**: a requisição entra pelo Express, percorre os middlewares, chega ao controller, é delegada ao service, acessa o banco de dados (real, mas em ambiente controlado) e produz uma resposta HTTP. Esse tipo de teste verifica que a composição das camadas funciona corretamente — algo que os testes unitários, por definição, não testam.

Testes de integração são mais lentos que unitários (envolvem I/O real, mesmo que em banco de testes) e menos granulares no diagnóstico de falhas. São necessários em menor quantidade, mas cobrem um espectro de comportamento que os testes unitários não alcançam.

### 9.2.4 Testes end-to-end

Os **testes end-to-end** (*E2E tests*), também denominados testes funcionais ou de aceitação, verificam o sistema a partir da perspectiva do usuário final — simulando interações com a interface visual em um navegador real. Eles percorrem o caminho completo: do clique no botão de login ao retorno dos dados na tela, passando pelo frontend, pela API, pelo banco de dados e de volta. São os testes de maior valor de negócio (verificam o que o usuário realmente experimenta) e de maior custo: lentos, frágeis (sensíveis a mudanças de layout e de seletores CSS), difíceis de depurar e custosos de manter.

A prescrição da pirâmide é clara: poucos testes E2E, cobrindo os fluxos críticos do negócio (login, cadastro, operação principal da aplicação), não cada permutação possível da interface.

### 9.2.5 O antipadrão do cone de sorvete

O antipadrão inverso à pirâmide — denominado *ice cream cone* (cone de sorvete) por Alister Scott — ocorre quando a equipe inverte a proporção: muitos testes E2E, poucos testes de integração e praticamente nenhum teste unitário. Esse cenário é comum em equipes que chegam aos testes automatizados pelo caminho das ferramentas de automação de interface (Selenium, Cypress) sem antes estabelecer uma base de testes unitários. O resultado é uma suíte lenta, frágil, que consome horas em pipelines de CI/CD e cuja manutenção se torna proibitiva.

A pirâmide de testes não é uma lei imutável — algumas arquiteturas (microserviços com interfaces simples, por exemplo) podem justificar proporções diferentes. Mas é o ponto de partida correto para a grande maioria dos sistemas web.

---

## 9.3 Configurando o Jest

### 9.3.1 O Jest como framework de testes

O **Jest** é um framework de testes JavaScript desenvolvido e mantido pela Meta (anteriormente Facebook). Ele integra em um único pacote as funcionalidades que em outras linguagens são distribuídas entre ferramentas separadas: o *test runner* (executor de testes), a biblioteca de asserções (*assertion library*), o motor de mocks e stubs, e o módulo de cobertura de código. Essa integração reduz a fricção de configuração e garante compatibilidade entre os componentes.

O Jest é compatível com projetos Node.js (backend) e com projetos de frontend (React, Vue), o que o torna uma escolha coerente para um curso que cobre ambas as camadas.

### 9.3.2 Instalação e configuração

```bash
npm install --save-dev jest @jest/globals
```

Para projetos que utilizam módulos ES (`"type": "module"` no `package.json`), é necessário configurar o Jest para suportar ESM. A abordagem mais direta utiliza o pacote `--experimental-vm-modules` do Node.js:

```json
// package.json
{
  "scripts": {
    "test":          "node --experimental-vm-modules node_modules/.bin/jest",
    "test:watch":    "node --experimental-vm-modules node_modules/.bin/jest --watch",
    "test:coverage": "node --experimental-vm-modules node_modules/.bin/jest --coverage"
  }
}
```

```javascript
// jest.config.js
export default {
  testEnvironment:    'node',
  transform:          {},              // sem transpilação — Node nativo com ESM
  testMatch:          ['**/__tests__/**/*.test.js', '**/*.spec.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/config/**',                  // exclui arquivos de configuração
    '!src/server.js',                  // exclui ponto de entrada
  ],
  coverageThresholds: {
    global: {
      statements: 80,
      branches:   75,
      functions:  80,
      lines:      80,
    },
  },
  setupFilesAfterFramework: ['./tests/setup.js'],
};
```

### 9.3.3 Estrutura de diretórios de testes

A organização dos testes deve espelhar a estrutura do código de produção, facilitando a localização dos arquivos correspondentes:

```
src/
├── services/
│   └── usuarios.service.js
├── controllers/
│   └── usuarios.controller.js
└── app.js

tests/
├── unit/
│   ├── services/
│   │   ├── usuarios.service.test.js
│   │   └── auth.service.test.js
│   └── middlewares/
│       └── autenticacao.middleware.test.js
├── integration/
│   ├── usuarios.routes.test.js
│   └── auth.routes.test.js
├── e2e/
│   ├── login.spec.js
│   └── usuarios.spec.js
└── setup.js                  # configuração global dos testes
```

### 9.3.4 Anatomia de um teste Jest

A terminologia do Jest segue o padrão BDD (*Behavior-Driven Development*), com blocos `describe` para agrupamento e `it` (ou `test`) para casos individuais:

```javascript
// tests/unit/services/usuarios.service.test.js
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { UsuariosService } from '../../../src/services/usuarios.service.js';

describe('UsuariosService', () => {
  // beforeEach: executado antes de cada teste — garante isolamento de estado
  beforeEach(() => { /* setup */ });
  afterEach(()  => { jest.clearAllMocks(); });

  describe('buscarPorId', () => {
    it('deve retornar o usuário quando o ID existe', async () => {
      // Arrange — preparar os dados e colaboradores
      const usuarioEsperado = { id: 1, nome: 'Ana Silva', email: 'ana@ex.com' };
      const repositorioFalso = {
        buscarPorId: jest.fn().mockResolvedValue(usuarioEsperado),
      };
      const service = new UsuariosService(repositorioFalso);

      // Act — executar a operação sob teste
      const resultado = await service.buscarPorId(1);

      // Assert — verificar o resultado
      expect(resultado).toEqual(usuarioEsperado);
      expect(repositorioFalso.buscarPorId).toHaveBeenCalledWith(1);
      expect(repositorioFalso.buscarPorId).toHaveBeenCalledTimes(1);
    });

    it('deve lançar AppError com status 404 quando o usuário não existe', async () => {
      const repositorioFalso = {
        buscarPorId: jest.fn().mockResolvedValue(null),
      };
      const service = new UsuariosService(repositorioFalso);

      await expect(service.buscarPorId(999))
        .rejects
        .toMatchObject({ message: 'Usuário não encontrado', statusCode: 404 });
    });
  });
});
```

O padrão **Arrange-Act-Assert** (AAA), também conhecido como **Given-When-Then** na nomenclatura BDD, estrutura cada teste em três etapas bem delimitadas: preparação do contexto, execução da operação e verificação do resultado. Esse padrão melhora a legibilidade e a manutenibilidade dos testes.

---

## 9.4 Testes Unitários de Services

### 9.4.1 A testabilidade como propriedade arquitetural

A facilidade com que os services do projeto podem ser testados de forma isolada não é acidental — é uma consequência direta das decisões arquiteturais tomadas no Capítulo 4. A injeção de dependência via construtor, a definição de interfaces de repositório bem estabelecidas e a separação estrita entre lógica de negócio e mecanismo de transporte HTTP tornam os services naturalmente testáveis: qualquer colaborador pode ser substituído por um dublê de teste (*test double*) sem modificar o código de produção.

Esse é um dos argumentos mais concretos em favor de uma boa arquitetura: código bem estruturado é código testável, e código testável tende a ser código com responsabilidades bem definidas e acoplamento reduzido.

### 9.4.2 Suíte completa para UsuariosService

```javascript
// tests/unit/services/usuarios.service.test.js
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { UsuariosService } from '../../../src/services/usuarios.service.js';
import { AppError }        from '../../../src/utils/AppError.js';

// Factory de repositório falso — evita repetição em cada teste
function criarRepositorioFalso(overrides = {}) {
  return {
    listarTodos:      jest.fn().mockResolvedValue([]),
    buscarPorId:      jest.fn().mockResolvedValue(null),
    buscarPorEmail:   jest.fn().mockResolvedValue(null),
    criar:            jest.fn(),
    atualizar:        jest.fn(),
    remover:          jest.fn(),
    ...overrides,
  };
}

describe('UsuariosService', () => {

  describe('listarTodos', () => {
    it('deve retornar a lista de usuários fornecida pelo repositório', async () => {
      const usuarios = [
        { id: 1, nome: 'Ana',   email: 'ana@ex.com'   },
        { id: 2, nome: 'Bruno', email: 'bruno@ex.com' },
      ];
      const repo    = criarRepositorioFalso({ listarTodos: jest.fn().mockResolvedValue(usuarios) });
      const service = new UsuariosService(repo);

      const resultado = await service.listarTodos();

      expect(resultado).toHaveLength(2);
      expect(resultado).toEqual(usuarios);
    });

    it('deve retornar array vazio quando não há usuários', async () => {
      const repo    = criarRepositorioFalso();
      const service = new UsuariosService(repo);

      const resultado = await service.listarTodos();
      expect(resultado).toEqual([]);
    });
  });

  describe('buscarPorId', () => {
    it('deve retornar o usuário correspondente ao ID fornecido', async () => {
      const usuario = { id: 42, nome: 'Carla', email: 'carla@ex.com' };
      const repo    = criarRepositorioFalso({ buscarPorId: jest.fn().mockResolvedValue(usuario) });
      const service = new UsuariosService(repo);

      const resultado = await service.buscarPorId(42);

      expect(resultado).toEqual(usuario);
      expect(repo.buscarPorId).toHaveBeenCalledWith(42);
    });

    it('deve lançar AppError 404 quando o usuário não é encontrado', async () => {
      const repo    = criarRepositorioFalso({ buscarPorId: jest.fn().mockResolvedValue(null) });
      const service = new UsuariosService(repo);

      await expect(service.buscarPorId(999))
        .rejects
        .toMatchObject({ statusCode: 404, message: 'Usuário não encontrado' });
    });
  });

  describe('criar', () => {
    it('deve criar e retornar o usuário quando o e-mail não está cadastrado', async () => {
      const dados   = { nome: 'Diana', email: 'diana@ex.com', senha: 'senha123' };
      const criado  = { id: 3, ...dados };
      const repo    = criarRepositorioFalso({
        buscarPorEmail: jest.fn().mockResolvedValue(null),
        criar:          jest.fn().mockResolvedValue(criado),
      });
      const service = new UsuariosService(repo);

      const resultado = await service.criar(dados);

      expect(resultado).toEqual(criado);
      expect(repo.buscarPorEmail).toHaveBeenCalledWith(dados.email);
      expect(repo.criar).toHaveBeenCalledTimes(1);
    });

    it('deve lançar AppError 409 quando o e-mail já está cadastrado', async () => {
      const repo    = criarRepositorioFalso({
        buscarPorEmail: jest.fn().mockResolvedValue({ id: 1, email: 'diana@ex.com' }),
      });
      const service = new UsuariosService(repo);

      await expect(service.criar({ nome: 'Diana', email: 'diana@ex.com', senha: 'senha123' }))
        .rejects
        .toMatchObject({ statusCode: 409, message: 'E-mail já cadastrado' });

      // O repositório de criação NÃO deve ter sido chamado
      expect(repo.criar).not.toHaveBeenCalled();
    });
  });

  describe('atualizar', () => {
    it('deve atualizar o usuário quando ele existe', async () => {
      const existente  = { id: 1, nome: 'Ana',      email: 'ana@ex.com' };
      const atualizado = { id: 1, nome: 'Ana Lima',  email: 'ana@ex.com' };
      const repo       = criarRepositorioFalso({
        buscarPorId: jest.fn().mockResolvedValue(existente),
        atualizar:   jest.fn().mockResolvedValue(atualizado),
      });
      const service = new UsuariosService(repo);

      const resultado = await service.atualizar(1, { nome: 'Ana Lima' });

      expect(resultado.nome).toBe('Ana Lima');
      expect(repo.atualizar).toHaveBeenCalledWith(1, { nome: 'Ana Lima' });
    });

    it('deve lançar AppError 404 quando o usuário a ser atualizado não existe', async () => {
      const repo    = criarRepositorioFalso({ buscarPorId: jest.fn().mockResolvedValue(null) });
      const service = new UsuariosService(repo);

      await expect(service.atualizar(999, { nome: 'X' }))
        .rejects
        .toMatchObject({ statusCode: 404 });

      expect(repo.atualizar).not.toHaveBeenCalled();
    });
  });

  describe('remover', () => {
    it('deve remover o usuário quando ele existe', async () => {
      const repo    = criarRepositorioFalso({
        buscarPorId: jest.fn().mockResolvedValue({ id: 1 }),
        remover:     jest.fn().mockResolvedValue(true),
      });
      const service = new UsuariosService(repo);

      await expect(service.remover(1)).resolves.not.toThrow();
      expect(repo.remover).toHaveBeenCalledWith(1);
    });
  });
});
```

### 9.4.3 Boas práticas em testes unitários

**Cada teste deve verificar exatamente uma coisa.** Um teste que falha deve revelar imediatamente *qual comportamento* está incorreto, não apenas *que algo* está incorreto. Testes com múltiplas asserções sobre comportamentos distintos obscurecem o diagnóstico.

**Os testes devem ser independentes entre si.** A execução de um teste não deve alterar o estado que afeta outro. O uso de `beforeEach` para reinicializar mocks e dados de teste é a prática padrão para garantir essa independência.

**Os nomes dos testes devem descrever o comportamento esperado.** A convenção `deve [resultado esperado] quando [condição]` produz mensagens de falha informativas e documenta o comportamento do sistema de forma legível.

**Não teste detalhes de implementação.** Testes que verificam se um método interno foi chamado com determinados argumentos intermediários são frágeis — quebram com refatorações que preservam o comportamento externo. Prefira testar entradas e saídas observáveis.

---

## 9.5 Mocks, Stubs e Spies

### 9.5.1 Taxonomia dos dublês de teste

O termo **test double** (dublê de teste), cunhado por Gerard Meszaros em *xUnit Test Patterns* (2007), é o nome genérico para qualquer objeto que substitui um colaborador real em um teste. Dentro dessa categoria, Meszaros distingue cinco tipos, dos quais três são de uso cotidiano no Jest:

**Stub** é um dublê que retorna respostas pré-configuradas para chamadas específicas. Não verifica como foi chamado — apenas fornece os dados necessários para que o código sob teste possa executar. No Jest, stubs são criados com `jest.fn().mockReturnValue()` ou `jest.fn().mockResolvedValue()`.

**Mock** é um dublê que também verifica as interações — quantas vezes foi chamado, com quais argumentos, em qual ordem. No contexto Jest, a mesma função criada com `jest.fn()` pode ser usada tanto como stub (configurando valores de retorno) quanto como mock (verificando chamadas com `expect(fn).toHaveBeenCalledWith()`).

**Spy** é um dublê que envolve (*wraps*) um objeto real, interceptando as chamadas para verificação sem substituir o comportamento original. No Jest, `jest.spyOn(objeto, 'metodo')` cria um spy que registra as chamadas mas continua delegando ao método original, a menos que o comportamento seja explicitamente sobrescrito.

### 9.5.2 Uso prático no Jest

```javascript
import { jest } from '@jest/globals';
import bcrypt    from 'bcrypt';

// ── Stub: define o valor de retorno ────────────────────────────────────
const repositorioFalso = {
  buscarPorEmail: jest.fn().mockResolvedValue(null),   // async stub
  criar:          jest.fn().mockReturnValue({ id: 1 }), // sync stub
};

// Configurações encadeadas para cenários diferentes
repositorioFalso.buscarPorEmail
  .mockResolvedValueOnce(null)              // primeira chamada: não existe
  .mockResolvedValueOnce({ id: 1 });        // segunda chamada: existe

// ── Mock: verificação de interações ────────────────────────────────────
expect(repositorioFalso.criar).toHaveBeenCalledTimes(1);
expect(repositorioFalso.criar).toHaveBeenCalledWith(
  expect.objectContaining({ email: 'ana@ex.com' }) // verifica subconjunto do argumento
);
expect(repositorioFalso.criar).not.toHaveBeenCalled();

// ── Spy: intercepta método de módulo real ───────────────────────────────
const spyHash = jest.spyOn(bcrypt, 'hash').mockResolvedValue('hash_falso');

await service.criar({ nome: 'Ana', email: 'ana@ex.com', senha: 'senha123' });

expect(spyHash).toHaveBeenCalledWith('senha123', 12);

// Restaura a implementação original após o teste
spyHash.mockRestore();
```

### 9.5.3 Simulação de módulos inteiros

Para substituir módulos externos por completo — útil para dependências como `jsonwebtoken` ou `nodemailer` — o Jest oferece `jest.mock()`:

```javascript
// Substitui o módulo jsonwebtoken por uma versão controlada
jest.mock('jsonwebtoken', () => ({
  sign:   jest.fn().mockReturnValue('token_falso_123'),
  verify: jest.fn().mockReturnValue({ sub: 1, email: 'ana@ex.com', papel: 'USER' }),
}));

import jwt from 'jsonwebtoken';

// jwt.sign e jwt.verify agora são funções controladas pelo teste
```

### 9.5.4 Quando não usar mocks

O uso excessivo de mocks pode produzir uma suíte de testes que passa integralmente mas não detecta regressões reais — fenômeno denominado *over-mocking*. Se um teste mocka todos os colaboradores de uma função exceto a própria função sob teste, ele verifica apenas que a função chama seus colaboradores na sequência esperada, não que o resultado final é correto.

A regra prática é: mock o que está além da fronteira da unidade testada (banco de dados, serviços externos, sistema de arquivos), mas evite mockar colaboradores internos da mesma camada de abstração. Se dois componentes precisam ser testados em conjunto para que o comportamento faça sentido, um teste de integração é mais adequado do que um teste unitário com mocks profusamente injetados.

---

## 9.6 Testes de Integração com Supertest

### 9.6.1 O papel dos testes de integração em APIs REST

Enquanto os testes unitários verificam o comportamento isolado dos services, os testes de integração verificam o comportamento do sistema como um todo — da entrada HTTP à saída HTTP, passando por todas as camadas da arquitetura. Eles respondem perguntas que os testes unitários não conseguem: os middlewares estão na ordem correta? A validação de entrada está funcionando? O middleware de autenticação intercepta corretamente os tokens inválidos? O código de status da resposta está correto para cada cenário?

O **Supertest** é uma biblioteca que permite fazer requisições HTTP programáticas a uma aplicação Express sem iniciar um servidor real — ela usa o módulo HTTP interno do Node.js para criar uma instância temporária. Isso torna os testes de integração rápidos e sem efeitos colaterais de porta ocupada.

### 9.6.2 Instalação e configuração

```bash
npm install --save-dev supertest
```

A separação entre `app.js` (configuração do Express) e `server.js` (inicialização do servidor HTTP), estabelecida no Capítulo 3, é precisamente o que permite ao Supertest importar `app` sem iniciar o servidor:

```javascript
// tests/setup.js
import { prisma } from '../src/config/database.js';

// Executado uma vez antes de todos os testes
beforeAll(async () => {
  // Para testes de integração, usa-se um banco SQLite em memória
  // configurado via variável de ambiente no ambiente de teste
});

afterAll(async () => {
  await prisma.$disconnect();
});
```

```bash
# .env.test
DATABASE_URL="file:./test.db"
NODE_ENV=test
JWT_SECRET=segredo_para_testes_apenas
JWT_REFRESH_SECRET=refresh_segredo_para_testes
```

```javascript
// jest.config.js — carrega o .env.test
import dotenv from 'dotenv';
dotenv.config({ path: '.env.test' });
```

### 9.6.3 Suíte de integração para endpoints de usuários

```javascript
// tests/integration/usuarios.routes.test.js
import { describe, it, expect, beforeAll, afterAll, beforeEach } from '@jest/globals';
import request  from 'supertest';
import app      from '../../src/app.js';
import { prisma } from '../../src/config/database.js';

// Função auxiliar para obter um token de autenticação nos testes
async function obterToken(papel = 'USER') {
  const email = `teste_${Date.now()}@ex.com`;
  await request(app)
    .post('/api/auth/register')
    .send({ nome: 'Usuário Teste', email, senha: 'senha12345' });

  if (papel === 'ADMIN') {
    await prisma.usuario.update({
      where: { email },
      data:  { papel: 'ADMIN' },
    });
  }

  const resposta = await request(app)
    .post('/api/auth/login')
    .send({ email, senha: 'senha12345' });

  return resposta.body.accessToken;
}

beforeEach(async () => {
  // Limpa a base entre testes — garante isolamento
  await prisma.refreshToken.deleteMany();
  await prisma.usuario.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('GET /api/usuarios', () => {
  it('deve retornar 401 quando nenhum token é fornecido', async () => {
    const resposta = await request(app).get('/api/usuarios');

    expect(resposta.status).toBe(401);
    expect(resposta.body).toHaveProperty('erro');
  });

  it('deve retornar 403 quando o token pertence a um usuário sem papel ADMIN', async () => {
    const token    = await obterToken('USER');
    const resposta = await request(app)
      .get('/api/usuarios')
      .set('Authorization', `Bearer ${token}`);

    expect(resposta.status).toBe(403);
  });

  it('deve retornar 200 com a lista de usuários para um ADMIN autenticado', async () => {
    const token    = await obterToken('ADMIN');
    const resposta = await request(app)
      .get('/api/usuarios')
      .set('Authorization', `Bearer ${token}`);

    expect(resposta.status).toBe(200);
    expect(Array.isArray(resposta.body)).toBe(true);
  });
});

describe('POST /api/usuarios', () => {
  it('deve retornar 400 quando o e-mail é inválido', async () => {
    const token    = await obterToken('ADMIN');
    const resposta = await request(app)
      .post('/api/usuarios')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Teste', email: 'email_invalido', senha: 'senha12345' });

    expect(resposta.status).toBe(400);
    expect(resposta.body).toHaveProperty('erros');
  });

  it('deve retornar 201 com o usuário criado quando os dados são válidos', async () => {
    const token    = await obterToken('ADMIN');
    const dados    = { nome: 'Novo Usuário', email: 'novo@ex.com', senha: 'senha12345' };
    const resposta = await request(app)
      .post('/api/usuarios')
      .set('Authorization', `Bearer ${token}`)
      .send(dados);

    expect(resposta.status).toBe(201);
    expect(resposta.body).toMatchObject({ nome: dados.nome, email: dados.email });
    expect(resposta.body).not.toHaveProperty('senha'); // hash nunca é exposto
  });

  it('deve retornar 409 quando o e-mail já está cadastrado', async () => {
    const token = await obterToken('ADMIN');
    const dados = { nome: 'Duplicado', email: 'dup@ex.com', senha: 'senha12345' };

    await request(app)
      .post('/api/usuarios')
      .set('Authorization', `Bearer ${token}`)
      .send(dados);

    const resposta = await request(app)
      .post('/api/usuarios')
      .set('Authorization', `Bearer ${token}`)
      .send(dados);

    expect(resposta.status).toBe(409);
  });
});

describe('DELETE /api/usuarios/:id', () => {
  it('deve retornar 404 quando o usuário a ser excluído não existe', async () => {
    const token    = await obterToken('ADMIN');
    const resposta = await request(app)
      .delete('/api/usuarios/99999')
      .set('Authorization', `Bearer ${token}`);

    expect(resposta.status).toBe(404);
  });

  it('deve retornar 204 e remover o usuário quando ele existe', async () => {
    const token = await obterToken('ADMIN');

    const criacao = await request(app)
      .post('/api/usuarios')
      .set('Authorization', `Bearer ${token}`)
      .send({ nome: 'Para Excluir', email: 'excluir@ex.com', senha: 'senha12345' });

    const resposta = await request(app)
      .delete(`/api/usuarios/${criacao.body.id}`)
      .set('Authorization', `Bearer ${token}`);

    expect(resposta.status).toBe(204);
  });
});
```

---

## 9.7 Testando Autenticação e Autorização

### 9.7.1 A importância de testar os mecanismos de segurança

O sistema de autenticação e autorização implementado no Capítulo 8 concentra alguns dos comportamentos mais críticos de toda a aplicação. Uma falha nos middlewares de autenticação pode expor dados de todos os usuários; uma falha na lógica de autorização pode permitir que um usuário comum execute operações administrativas. Esses cenários justificam uma cobertura de testes particularmente rigorosa.

### 9.7.2 Testes unitários do AuthService

```javascript
// tests/unit/services/auth.service.test.js
import { describe, it, expect, jest } from '@jest/globals';
import bcrypt       from 'bcrypt';
import { AuthService } from '../../../src/services/auth.service.js';

jest.mock('bcrypt');

function criarAuthRepositorioFalso(overrides = {}) {
  return {
    buscarUsuarioPorEmail: jest.fn().mockResolvedValue(null),
    criarUsuario:          jest.fn(),
    salvarRefreshToken:    jest.fn().mockResolvedValue({}),
    buscarRefreshToken:    jest.fn().mockResolvedValue(null),
    revogarRefreshToken:   jest.fn().mockResolvedValue({}),
    ...overrides,
  };
}

describe('AuthService.login', () => {
  it('deve lançar AppError 401 com mensagem genérica quando o e-mail não existe', async () => {
    // A mensagem deve ser idêntica à de senha incorreta — não revela se o e-mail existe
    bcrypt.compare.mockResolvedValue(false);
    const repo    = criarAuthRepositorioFalso({ buscarUsuarioPorEmail: jest.fn().mockResolvedValue(null) });
    const service = new AuthService(repo);

    await expect(service.login({ email: 'inexistente@ex.com', senha: 'qualquer' }))
      .rejects
      .toMatchObject({ statusCode: 401, message: 'Credenciais inválidas' });
  });

  it('deve lançar AppError 401 com mensagem genérica quando a senha está incorreta', async () => {
    bcrypt.compare.mockResolvedValue(false);
    const repo    = criarAuthRepositorioFalso({
      buscarUsuarioPorEmail: jest.fn().mockResolvedValue({
        id: 1, email: 'ana@ex.com', senha: 'hash', papel: 'USER',
      }),
    });
    const service = new AuthService(repo);

    await expect(service.login({ email: 'ana@ex.com', senha: 'errada' }))
      .rejects
      .toMatchObject({ statusCode: 401, message: 'Credenciais inválidas' });
  });

  it('deve retornar accessToken, refreshToken e usuário (sem senha) quando as credenciais são válidas', async () => {
    bcrypt.compare.mockResolvedValue(true);
    const usuario = { id: 1, nome: 'Ana', email: 'ana@ex.com', senha: 'hash', papel: 'USER' };
    const repo    = criarAuthRepositorioFalso({
      buscarUsuarioPorEmail: jest.fn().mockResolvedValue(usuario),
    });
    const service = new AuthService(repo);

    const resultado = await service.login({ email: 'ana@ex.com', senha: 'correta' });

    expect(resultado).toHaveProperty('accessToken');
    expect(resultado).toHaveProperty('refreshToken');
    expect(resultado.usuario).not.toHaveProperty('senha');
    expect(resultado.usuario.email).toBe('ana@ex.com');
  });
});

describe('AuthService.registrar', () => {
  it('deve lançar AppError 409 quando o e-mail já está cadastrado', async () => {
    const repo    = criarAuthRepositorioFalso({
      buscarUsuarioPorEmail: jest.fn().mockResolvedValue({ id: 1 }),
    });
    const service = new AuthService(repo);

    await expect(service.registrar({ nome: 'Ana', email: 'ana@ex.com', senha: 'senha12345' }))
      .rejects
      .toMatchObject({ statusCode: 409 });

    expect(repo.criarUsuario).not.toHaveBeenCalled();
  });
});
```

### 9.7.3 Testes de integração para autenticação

```javascript
// tests/integration/auth.routes.test.js
import { describe, it, expect, beforeEach, afterAll } from '@jest/globals';
import request    from 'supertest';
import app        from '../../src/app.js';
import { prisma } from '../../src/config/database.js';
import jwt        from 'jsonwebtoken';

beforeEach(async () => {
  await prisma.refreshToken.deleteMany();
  await prisma.usuario.deleteMany();
});

afterAll(async () => { await prisma.$disconnect(); });

describe('POST /api/auth/register', () => {
  it('deve retornar 201 com o usuário criado e sem o campo senha', async () => {
    const resposta = await request(app)
      .post('/api/auth/register')
      .send({ nome: 'Ana Silva', email: 'ana@ex.com', senha: 'senha12345' });

    expect(resposta.status).toBe(201);
    expect(resposta.body).toHaveProperty('id');
    expect(resposta.body).toHaveProperty('email', 'ana@ex.com');
    expect(resposta.body).not.toHaveProperty('senha');
  });

  it('deve retornar 400 quando a senha tem menos de 8 caracteres', async () => {
    const resposta = await request(app)
      .post('/api/auth/register')
      .send({ nome: 'Ana', email: 'ana@ex.com', senha: '123' });

    expect(resposta.status).toBe(400);
  });
});

describe('POST /api/auth/login', () => {
  beforeEach(async () => {
    await request(app)
      .post('/api/auth/register')
      .send({ nome: 'Ana', email: 'ana@ex.com', senha: 'senha12345' });
  });

  it('deve retornar 200 com accessToken e refreshToken válidos', async () => {
    const resposta = await request(app)
      .post('/api/auth/login')
      .send({ email: 'ana@ex.com', senha: 'senha12345' });

    expect(resposta.status).toBe(200);
    expect(resposta.body).toHaveProperty('accessToken');
    expect(resposta.body).toHaveProperty('refreshToken');

    // Verifica que o accessToken é um JWT válido e bem-formado
    const payload = jwt.decode(resposta.body.accessToken);
    expect(payload).toHaveProperty('sub');
    expect(payload).toHaveProperty('email', 'ana@ex.com');
    expect(payload).not.toHaveProperty('senha');
  });

  it('deve retornar 401 com mensagem genérica para senha incorreta', async () => {
    const resposta = await request(app)
      .post('/api/auth/login')
      .send({ email: 'ana@ex.com', senha: 'senhaerrada' });

    expect(resposta.status).toBe(401);
    expect(resposta.body.erro).toBe('Credenciais inválidas');
  });

  it('deve retornar 401 com a mesma mensagem genérica para e-mail inexistente', async () => {
    const resposta = await request(app)
      .post('/api/auth/login')
      .send({ email: 'inexistente@ex.com', senha: 'qualquer' });

    // Mensagem idêntica — não revela ao atacante se o e-mail existe
    expect(resposta.status).toBe(401);
    expect(resposta.body.erro).toBe('Credenciais inválidas');
  });
});

describe('Middleware de autenticação', () => {
  it('deve retornar 401 com mensagem "Token expirado" para token com exp no passado', async () => {
    const tokenExpirado = jwt.sign(
      { sub: 1, email: 'ana@ex.com', papel: 'USER' },
      process.env.JWT_SECRET,
      { expiresIn: -1 }  // expirado imediatamente
    );

    const resposta = await request(app)
      .get('/api/usuarios')
      .set('Authorization', `Bearer ${tokenExpirado}`);

    expect(resposta.status).toBe(401);
    expect(resposta.body.erro).toMatch(/expirado/i);
  });

  it('deve retornar 401 para token com assinatura inválida', async () => {
    const tokenFalsificado = jwt.sign(
      { sub: 1, email: 'ana@ex.com', papel: 'ADMIN' },
      'segredo_errado'  // chave diferente da usada pelo servidor
    );

    const resposta = await request(app)
      .get('/api/usuarios')
      .set('Authorization', `Bearer ${tokenFalsificado}`);

    expect(resposta.status).toBe(401);
  });

  it('deve retornar 403 quando o papel do usuário é insuficiente para o recurso', async () => {
    // Registra e autentica um usuário com papel USER
    await request(app)
      .post('/api/auth/register')
      .send({ nome: 'Usuário Comum', email: 'user@ex.com', senha: 'senha12345' });

    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: 'user@ex.com', senha: 'senha12345' });

    const resposta = await request(app)
      .get('/api/usuarios')  // rota que exige ADMIN
      .set('Authorization', `Bearer ${login.body.accessToken}`);

    expect(resposta.status).toBe(403);
  });
});
```

---

## 9.8 TDD — Test-Driven Development

### 9.8.1 Fundamentos e ciclo Red-Green-Refactor

O **Test-Driven Development** (TDD) é uma prática de desenvolvimento de software proposta por Kent Beck no contexto da metodologia *Extreme Programming* (BECK, 2002) e amplamente disseminada por sua obra *Test-Driven Development: By Example*. A premissa central do TDD inverte a ordem convencional de trabalho: em vez de escrever o código de produção e depois verificá-lo com testes, o desenvolvedor escreve o teste *antes* do código que o satisfará.

O ciclo do TDD é composto por três fases iterativas, comumente denominadas **Red-Green-Refactor**:

**Red** — o desenvolvedor escreve um teste que descreve o comportamento desejado. Como o código de produção correspondente ainda não existe, o teste falha (a barra de testes fica vermelha). Essa etapa força o desenvolvedor a pensar no comportamento esperado antes de pensar na implementação.

**Green** — o desenvolvedor escreve o código de produção mínimo necessário para fazer o teste passar. "Mínimo" é deliberado: não se trata de escrever a solução mais elegante, mas a mais simples possível que satisfaça o teste. A barra fica verde.

**Refactor** — com a segurança de que os testes estão passando, o desenvolvedor melhora o código — elimina duplicações, renomeia variáveis, extrai funções — sem alterar o comportamento. Os testes garantem que a refatoração não introduziu regressões.

### 9.8.2 TDD como instrumento de design

Um insight fundamental sobre o TDD, frequentemente subestimado em apresentações superficiais da técnica, é que seus benefícios primários não são sobre verificação — são sobre **design**. Escrever o teste antes força o desenvolvedor a pensar na interface pública da unidade (quais argumentos recebe, o que retorna, quais exceções lança) antes de se perder nos detalhes da implementação. Código difícil de testar é código com design problemático: acoplamento excessivo, responsabilidades misturadas, dependências hardcoded. O TDD torna esses problemas visíveis imediatamente.

### 9.8.3 Exemplo prático: desenvolvendo uma nova regra de negócio com TDD

Suponha que seja necessário adicionar ao `UsuariosService` uma regra de negócio: um usuário não pode alterar seu próprio papel para `ADMIN`. O ciclo TDD seria:

```javascript
// FASE RED — escreve o teste antes de implementar a regra

describe('UsuariosService.atualizar', () => {
  it('deve lançar AppError 403 quando um USER tenta promover a si mesmo para ADMIN', async () => {
    const existente = { id: 1, nome: 'Ana', email: 'ana@ex.com', papel: 'USER' };
    const repo      = criarRepositorioFalso({
      buscarPorId: jest.fn().mockResolvedValue(existente),
    });
    const service = new UsuariosService(repo);

    // O service recebe o usuário que está fazendo a requisição como contexto
    await expect(
      service.atualizar(1, { papel: 'ADMIN' }, { id: 1, papel: 'USER' })
    ).rejects.toMatchObject({
      statusCode: 403,
      message:    'Usuários não podem alterar seu próprio papel',
    });

    expect(repo.atualizar).not.toHaveBeenCalled();
  });
});
// Executar: npm test → FALHA (o comportamento ainda não existe)
```

```javascript
// FASE GREEN — implementação mínima para satisfazer o teste

async atualizar(id, dados, usuarioRequisitante) {
  await this.buscarPorId(id); // verifica existência — lança 404 se não encontrar

  // Nova regra: usuário não pode promover a si mesmo
  if (
    dados.papel &&
    dados.papel !== usuarioRequisitante.papel &&
    usuarioRequisitante.id === id
  ) {
    throw new AppError('Usuários não podem alterar seu próprio papel', 403);
  }

  return this.repository.atualizar(id, dados);
}
// Executar: npm test → PASSA
```

```javascript
// FASE REFACTOR — melhora a clareza sem alterar o comportamento

async atualizar(id, dados, usuarioRequisitante) {
  await this.buscarPorId(id);
  this.#validarAlteracaoDePapel(dados, id, usuarioRequisitante);
  return this.repository.atualizar(id, dados);
}

#validarAlteracaoDePapel(dados, idAlvo, requisitante) {
  const tentaAlterarPapel  = !!dados.papel && dados.papel !== requisitante.papel;
  const alterandoASiMesmo  = requisitante.id === idAlvo;

  if (tentaAlterarPapel && alterandoASiMesmo) {
    throw new AppError('Usuários não podem alterar seu próprio papel', 403);
  }
}
// Executar: npm test → AINDA PASSA (comportamento preservado)
```

### 9.8.4 Quando TDD ajuda — e quando não ajuda

O TDD entrega seu maior valor em contextos onde a lógica de negócio é rica e bem definida previamente — validações, regras de domínio, algoritmos com múltiplos casos de borda. Nesses cenários, o ciclo Red-Green-Refactor força uma especificação precisa do comportamento e produz código naturalmente testável.

O TDD é menos produtivo — e às vezes contraproducente — em contextos exploratórios, onde o desenvolvedor ainda não sabe qual a forma correta da solução. Tentar escrever testes para uma interface que ainda está sendo descoberta resulta em testes que precisam ser reescritos constantemente. A abordagem mais pragmática nesses casos é explorar a solução livremente e adicionar os testes após a forma da solução estar clara — uma prática denominada *test-after* ou *test-last*, que, embora menos rigorosa que o TDD puro, é preferível à ausência de testes.

---

## 9.9 Testes End-to-End com Playwright

### 9.9.1 Fundamentos dos testes E2E

Os **testes end-to-end** (E2E) verificam o sistema a partir da perspectiva do usuário final, simulando interações reais com a interface em um navegador. Eles atravessam a pilha completa da aplicação — do clique em um botão na interface Vue ou React ao retorno dos dados do banco de dados e à atualização visual correspondente — sem qualquer substituição por dublês de teste. São os testes de maior valor de negócio e de maior custo de manutenção.

O posicionamento dos testes E2E no topo da pirâmide reflete essa característica dual: são indispensáveis para verificar que as camadas se integram corretamente do ponto de vista do usuário, mas devem ser utilizados com moderação, cobrindo os fluxos críticos do negócio — login, cadastro, operação principal da aplicação — e não cada permutação possível da interface.

### 9.9.2 Por que Playwright

O **Playwright** é um framework de automação de browsers desenvolvido e mantido pela Microsoft, lançado em 2020 como evolução das lições aprendidas com o Puppeteer. Ele suporta os três principais motores de renderização — Chromium (Chrome, Edge), Firefox e WebKit (Safari) — a partir de uma única API unificada, permitindo que os testes sejam executados nos mesmos motores utilizados pelos usuários finais.

Três características o distinguem para o contexto deste curso. Primeiro, sua API é integralmente baseada em `async/await`, o mesmo padrão que os alunos já utilizam extensivamente no backend e no frontend — a curva de aprendizado é mínima. Segundo, o Playwright adota por padrão a estratégia de **auto-waiting**: antes de interagir com um elemento, ele aguarda automaticamente que o elemento esteja visível, habilitado e estável na tela, eliminando a necessidade de `sleep()` e waits arbitrários que tornam os testes E2E frágeis e não-determinísticos. Terceiro, ele oferece um modo de depuração visual (*Playwright Inspector*) que permite executar testes passo a passo, inspecionando o estado da página em cada instrução.

### 9.9.3 Instalação e configuração

```bash
# Instala o Playwright e baixa os binários dos browsers
npm install --save-dev @playwright/test
npx playwright install
```

```javascript
// playwright.config.js
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir:      './tests/e2e',
  testMatch:    '**/*.spec.js',
  timeout:      30_000,           // timeout por teste: 30 segundos
  retries:      process.env.CI ? 2 : 0, // retenta em CI para mitigar flakiness
  reporter:     [['html', { outputFolder: 'tests/e2e/report' }]],

  use: {
    baseURL:     'http://localhost:5173', // URL do frontend (Vite dev server)
    trace:       'on-first-retry',       // grava trace ao retentar
    screenshot:  'only-on-failure',      // captura screenshot em falhas
    video:       'retain-on-failure',    // grava vídeo em falhas
  },

  // Executa backend e frontend antes dos testes
  webServer: [
    {
      command:            'npm run dev --prefix backend',
      url:                'http://localhost:3000/api/health',
      reuseExistingServer: !process.env.CI,
    },
    {
      command:            'npm run dev --prefix frontend',
      url:                'http://localhost:5173',
      reuseExistingServer: !process.env.CI,
    },
  ],

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox',  use: { ...devices['Desktop Firefox'] } },
  ],
});
```

### 9.9.4 Anatomia de um teste Playwright

```javascript
// tests/e2e/login.spec.js
import { test, expect } from '@playwright/test';

test.describe('Fluxo de autenticação', () => {

  test.beforeEach(async ({ page }) => {
    // Garante estado limpo antes de cada teste
    await page.goto('/login');
  });

  test('deve exibir mensagem de erro para credenciais inválidas', async ({ page }) => {
    // Arrange — preenche o formulário com credenciais inválidas
    await page.fill('#email', 'inexistente@ex.com');
    await page.fill('#senha', 'senhaerrada');

    // Act — submete o formulário
    await page.click('button[type="submit"]');

    // Assert — verifica a mensagem de erro visível ao usuário
    await expect(page.locator('.alerta-erro')).toBeVisible();
    await expect(page.locator('.alerta-erro')).toContainText('Credenciais inválidas');

    // Verifica que a URL não mudou — não houve redirecionamento
    await expect(page).toHaveURL('/login');
  });

  test('deve redirecionar para /usuarios após login bem-sucedido', async ({ page }) => {
    // Pressupõe que um usuário com essas credenciais existe no banco de testes
    await page.fill('#email', 'teste@ex.com');
    await page.fill('#senha', 'senha12345');
    await page.click('button[type="submit"]');

    // Playwright aguarda automaticamente a navegação completar
    await expect(page).toHaveURL('/usuarios');
    await expect(page.locator('h1')).toContainText('Usuários');
  });

  test('deve redirecionar para /login ao tentar acessar rota protegida sem autenticação', async ({ page }) => {
    await page.goto('/usuarios');
    await expect(page).toHaveURL(/\/login/);
  });

});
```

### 9.9.5 Seletores e estratégias de localização de elementos

A escolha dos seletores é um dos fatores mais determinantes para a resiliência dos testes E2E. Seletores frágeis — baseados em classes CSS ou em posição no DOM — quebram com qualquer refatoração de estilo, mesmo quando o comportamento permanece correto. O Playwright recomenda uma hierarquia de preferência para seletores:

**Atributos `data-testid`** são a estratégia mais robusta. São adicionados explicitamente para fins de teste, não são alterados por mudanças de estilo e comunicam claramente a intenção de uso:

```html
<!-- No template Vue/React -->
<button data-testid="btn-login" type="submit">Entrar</button>
<div data-testid="alerta-erro" class="alert alert-error">...</div>
```

```javascript
// No teste Playwright
await page.click('[data-testid="btn-login"]');
await expect(page.locator('[data-testid="alerta-erro"]')).toBeVisible();
```

**Roles ARIA** são a segunda melhor opção — são semanticamente significativos e resistentes a mudanças de implementação:

```javascript
await page.getByRole('button', { name: 'Entrar' }).click();
await page.getByRole('textbox', { name: 'E-mail' }).fill('ana@ex.com');
await page.getByLabel('Senha').fill('senha12345');
```

**Texto visível** funciona bem para elementos cujo conteúdo é estável:

```javascript
await page.getByText('Novo Usuário').click();
await expect(page.getByText('Usuário criado com sucesso')).toBeVisible();
```

Seletores CSS genéricos (`.btn-primary`, `div:nth-child(3)`) devem ser evitados em testes E2E por sua fragilidade intrínseca.

### 9.9.6 Suíte E2E para o CRUD de usuários

```javascript
// tests/e2e/usuarios.spec.js
import { test, expect } from '@playwright/test';

// Helper: realiza login e retorna a página autenticada
async function loginComoAdmin(page) {
  await page.goto('/login');
  await page.getByLabel('E-mail').fill('admin@ex.com');
  await page.getByLabel('Senha').fill('admin12345');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL('/usuarios');
}

test.describe('CRUD de Usuários', () => {

  test.beforeEach(async ({ page }) => {
    await loginComoAdmin(page);
  });

  test('deve exibir a listagem de usuários após autenticação', async ({ page }) => {
    await expect(page.getByRole('heading', { name: 'Usuários' })).toBeVisible();
    await expect(page.getByRole('table')).toBeVisible();
  });

  test('deve criar um novo usuário e exibi-lo na listagem', async ({ page }) => {
    const emailNovo = `e2e_${Date.now()}@ex.com`;

    // Navega para o formulário de criação
    await page.getByRole('link', { name: 'Novo Usuário' }).click();
    await expect(page).toHaveURL('/usuarios/novo');

    // Preenche o formulário
    await page.getByLabel('Nome').fill('Usuário E2E');
    await page.getByLabel('E-mail').fill(emailNovo);
    await page.getByLabel('Senha').fill('senha12345');

    // Submete
    await page.getByRole('button', { name: 'Salvar' }).click();

    // Verifica redirecionamento e presença na listagem
    await expect(page).toHaveURL('/usuarios');
    await expect(page.getByText(emailNovo)).toBeVisible();
  });

  test('deve exibir erros de validação quando o formulário é submetido incompleto', async ({ page }) => {
    await page.getByRole('link', { name: 'Novo Usuário' }).click();

    // Submete sem preencher os campos
    await page.getByRole('button', { name: 'Salvar' }).click();

    // Verificações de validação devem aparecer
    await expect(page.locator('[data-testid="alerta-erro"]')).toBeVisible();
    await expect(page).toHaveURL('/usuarios/novo'); // não navegou
  });

  test('deve excluir um usuário após confirmação', async ({ page }) => {
    // Encontra o primeiro usuário que não é o admin
    const linhas = page.getByRole('row').filter({ hasText: /e2e_/i });
    const primeiraLinha = linhas.first();
    const emailExcluir  = await primeiraLinha.getByRole('cell').nth(1).textContent();

    // Configura o diálogo de confirmação para aceitar automaticamente
    page.on('dialog', dialog => dialog.accept());

    await primeiraLinha.getByRole('button', { name: 'Excluir' }).click();

    // Verifica que o usuário não aparece mais na listagem
    await expect(page.getByText(emailExcluir)).not.toBeVisible();
  });

});
```

### 9.9.7 Page Object Model (POM)

À medida que a suíte E2E cresce, a duplicação de lógica de interação com a interface torna-se um problema de manutenção — uma mudança no seletor do botão de login precisa ser atualizada em todos os testes que fazem login. O **Page Object Model** (POM) é o padrão de design que resolve esse problema: cada página da interface é representada por uma classe que encapsula os seletores e as interações, e os testes usam essa classe em vez de manipular a página diretamente.

```javascript
// tests/e2e/pages/LoginPage.js
export class LoginPage {
  constructor(page) {
    this.page         = page;
    this.campoEmail   = page.getByLabel('E-mail');
    this.campoSenha   = page.getByLabel('Senha');
    this.botaoEntrar  = page.getByRole('button', { name: 'Entrar' });
    this.alertaErro   = page.locator('[data-testid="alerta-erro"]');
  }

  async navegar()             { await this.page.goto('/login'); }
  async preencherEmail(email) { await this.campoEmail.fill(email); }
  async preencherSenha(senha) { await this.campoSenha.fill(senha); }
  async submeter()            { await this.botaoEntrar.click(); }

  async login(email, senha) {
    await this.navegar();
    await this.preencherEmail(email);
    await this.preencherSenha(senha);
    await this.submeter();
  }
}
```

```javascript
// tests/e2e/login.spec.js — com POM
import { test, expect }  from '@playwright/test';
import { LoginPage }     from './pages/LoginPage.js';

test('deve redirecionar após login bem-sucedido', async ({ page }) => {
  const loginPage = new LoginPage(page);
  await loginPage.login('admin@ex.com', 'admin12345');
  await expect(page).toHaveURL('/usuarios');
});
```

O POM centraliza o conhecimento sobre a interface em um único lugar. Quando a interface muda, apenas a classe Page Object precisa ser atualizada — os testes permanecem intactos.

### 9.9.8 Execução, relatórios e depuração

```bash
# Executa todos os testes E2E
npx playwright test

# Executa em modo interativo (abre o browser visualmente)
npx playwright test --headed

# Executa um arquivo específico
npx playwright test tests/e2e/login.spec.js

# Abre o Playwright Inspector (depurador visual passo a passo)
npx playwright test --debug

# Gera e abre o relatório HTML
npx playwright show-report tests/e2e/report
```

O relatório HTML do Playwright apresenta o resultado de cada teste com screenshots, vídeos (em caso de falha) e traces interativos — uma linha do tempo navegável que mostra exatamente o que aconteceu em cada etapa do teste, incluindo os requests HTTP feitos pelo browser.

---

## 9.10 Cobertura de Código

### 9.10.1 O que é cobertura de código

A **cobertura de código** (*code coverage*) é uma métrica que quantifica a proporção do código de produção que é exercitada durante a execução dos testes. O Jest gera relatórios de cobertura utilizando a ferramenta Istanbul, que instrumenta o código e rastreia quais linhas, branches, funções e statements foram executados.

```bash
npm run test:coverage
# Gera o relatório em coverage/lcov-report/index.html
```

O relatório apresenta quatro métricas distintas:

**Statement coverage** — porcentagem de instruções (*statements*) executadas. Uma instrução é uma unidade sintática de código, como uma atribuição ou uma chamada de função.

**Branch coverage** — porcentagem de ramos de decisão executados. Para cada `if/else`, `switch` ou operador ternário, ambos os caminhos (verdadeiro e falso) devem ser exercitados para atingir 100% de cobertura de branches.

**Function coverage** — porcentagem de funções definidas que foram chamadas durante os testes.

**Line coverage** — porcentagem de linhas executadas. Difere do statement coverage em situações onde múltiplos statements compartilham uma linha.

### 9.10.2 Limitações da cobertura como métrica de qualidade

A cobertura de código é uma métrica necessária mas não suficiente para avaliar a qualidade de uma suíte de testes. Essa distinção é fundamental e frequentemente negligenciada.

É trivial atingir 100% de cobertura sem testar nada de útil. O trecho a seguir demonstra como um teste pode cobrir integralmente uma função sem verificar seu comportamento:

```javascript
// Código de produção
function dividir(a, b) {
  if (b === 0) throw new Error('Divisão por zero');
  return a / b;
}

// Teste com 100% de cobertura mas sem asserções úteis
it('cobre a função dividir', () => {
  dividir(10, 2); // executa o código — sem expect()
  try { dividir(10, 0); } catch {}  // cobre o branch do throw
});
```

Esse teste cobre 100% das linhas, 100% dos branches e 100% das funções — e não verifica absolutamente nada. Uma suíte assim passou de forma enganosa enquanto a função retorna valores incorretos.

A cobertura mede o que foi *executado*, não o que foi *verificado*. Testes sem asserções, ou com asserções trivialmente verdadeiras, inflam a cobertura sem adicionar valor real.

### 9.10.3 Metas razoáveis de cobertura

A meta de 100% de cobertura é, em geral, contraproducente. Perseguir essa meta leva ao problema descrito acima — testes vazios para cobrir código difícil de testar — e desvia o esforço de engenharia da criação de testes que verificam comportamentos relevantes.

As recomendações práticas convergem para metas entre 70% e 85% para projetos em produção, com atenção especial às camadas de maior risco:

- **Services** (lógica de negócio): 85-90% — é onde os bugs têm maior impacto
- **Controllers**: 70-80% — verificados pelos testes de integração
- **Middlewares de autenticação**: 90%+ — código de segurança crítico
- **Utilitários**: 80-90% — funções puras são fáceis de testar exaustivamente
- **Configuração e infraestrutura**: excluir da métrica

A configuração `coverageThresholds` no `jest.config.js` permite que o pipeline de CI/CD falhe automaticamente se a cobertura cair abaixo dos limites estabelecidos — garantindo que a qualidade seja mantida ao longo do tempo.

### 9.10.4 Cobertura de código como instrumento de descoberta

O uso mais valioso da cobertura de código não é como meta a atingir, mas como instrumento de descoberta. O relatório de cobertura revela com precisão quais partes do código *nunca* são exercitadas pelos testes existentes — o que pode indicar código morto (que pode ser removido), código de tratamento de erro que nunca foi testado (e que pode conter bugs latentes) ou funcionalidades que simplesmente foram esquecidas na suíte de testes.

Revisar o relatório de cobertura periodicamente com essa perspectiva — *"o que esse código não coberto está fazendo e por que não testamos?"* — é mais produtivo do que a busca mecânica por percentuais altos.

---

## 9.11 Exercícios Práticos

### Exercício 9.1 — Suíte unitária para AuthService

Implemente uma suíte completa de testes unitários para o `AuthService` do Capítulo 8, cobrindo os seguintes cenários: (a) registro bem-sucedido; (b) registro com e-mail duplicado; (c) login com credenciais válidas — verificando que o token não contém o campo `senha`; (d) login com e-mail inexistente; (e) login com senha incorreta. Verifique que os cenários (d) e (e) retornam a mesma mensagem de erro genérica.

### Exercício 9.2 — Mocks avançados com Jest

Escreva testes unitários para um `PedidosService` hipotético que possua as seguintes dependências: `PedidosRepository`, `EstoqueService` e um serviço de notificação por e-mail. Use `jest.fn()` para simular os três colaboradores e verifique: (a) que a criação de um pedido falha com `AppError 409` quando o estoque é insuficiente; (b) que o serviço de e-mail é chamado exatamente uma vez após a criação bem-sucedida; (c) que o repositório não é chamado quando o estoque é insuficiente.

### Exercício 9.3 — Testes de integração com Supertest

Implemente uma suíte de testes de integração para o endpoint `POST /api/auth/refresh`. Cubra os cenários: (a) refresh com token válido — retorna novo par de tokens; (b) refresh com token inexistente no banco — retorna 401; (c) refresh com token expirado — retorna 401; (d) o token antigo não pode ser usado após a rotação.

### Exercício 9.4 — TDD para uma nova regra de negócio

Utilize o ciclo Red-Green-Refactor para implementar a seguinte regra no `UsuariosService`: um usuário desativado (`ativo: false`) não pode fazer login. Escreva primeiro o teste que documenta esse comportamento, verifique que ele falha (*Red*), implemente a regra mínima para fazê-lo passar (*Green*), e então refatore o código mantendo os testes passando (*Refactor*).

### Exercício 9.5 — Testes E2E com Playwright

Configure o Playwright no projeto e implemente os seguintes testes E2E para a aplicação Vue ou React do Capítulo 7: (a) acesso a `/usuarios` sem autenticação redireciona para `/login`; (b) login com credenciais inválidas exibe mensagem de erro; (c) login com credenciais válidas redireciona para `/usuarios`; (d) criação de um novo usuário via formulário aparece na listagem. Use o Page Object Model para encapsular as interações com as páginas de login e de usuários.

### Exercício 9.6 — Cobertura e análise crítica

Execute `npm run test:coverage` no projeto e analise o relatório gerado. Identifique três trechos de código com cobertura zero ou muito baixa. Para cada um, responda: (a) por que esse código não está sendo testado? (b) Qual seria o impacto de um bug nesse trecho? (c) Vale a pena escrever um teste para ele, ou é código que pode ser removido? Escreva os testes para pelo menos dois dos três trechos identificados.

---

## 9.12 Referências e Leituras Complementares

- BECK, K. *Test-Driven Development: By Example*. Addison-Wesley, 2002.
- FOWLER, M. *Refactoring: Improving the Design of Existing Code*. 2ª ed. Addison-Wesley, 2018.
- MESZAROS, G. *xUnit Test Patterns: Refactoring Test Code*. Addison-Wesley, 2007.
- COHN, M. *Succeeding with Agile: Software Development Using Scrum*. Addison-Wesley, 2009.
- [Jest — documentação oficial](https://jestjs.io/docs/getting-started)
- [Supertest — repositório e documentação](https://github.com/ladjs/supertest)
- [Playwright — documentação oficial](https://playwright.dev/docs/intro)
- [Playwright — Page Object Model](https://playwright.dev/docs/pom)
- [Martin Fowler — Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [OWASP — Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)

---

!!! note "Próximo Capítulo"
    No **Capítulo 10 — Segurança**, aprofundaremos as práticas de segurança em APIs Express para além do que foi introduzido nos capítulos anteriores: as principais vulnerabilidades do OWASP Top 10 no contexto de APIs REST, sanitização de entradas, proteção contra injeção de SQL e NoSQL, configuração segura de cabeçalhos HTTP com Helmet, e estratégias de rate limiting avançadas. A suíte de testes construída neste capítulo será estendida para cobrir cenários de ataque.
