# Capítulo 3 — Arquitetura de Software: MVC, Services e Repository Pattern

---

## 3.1 Introdução

O Capítulo 2 estabeleceu os fundamentos operacionais do Express: como definir rotas, encadear middlewares e organizar handlers em controllers. O código resultante já é funcional — mas funcionalidade não é sinônimo de boa arquitetura. À medida que uma aplicação cresce, a ausência de uma separação clara entre camadas se manifesta em problemas concretos: controllers que acumulam lógica de negócio, services que constroem queries SQL diretamente, testes que dependem de banco de dados real para verificar regras simples.

Este capítulo aborda os padrões arquiteturais que resolvem esses problemas de forma sistemática. O ponto de partida é o padrão **MVC** adaptado ao contexto de APIs REST; em seguida, aprofunda-se o papel da camada de **Service** como guardiã da lógica de negócio; depois, introduz-se o **Repository Pattern** como mecanismo de abstração do acesso a dados; e, por fim, apresenta-se o princípio de **Inversão de Dependência** em sua forma mais elementar. O capítulo encerra com a refatoração completa do projeto construído no Capítulo 2, consolidando todos esses conceitos em uma base sólida para a introdução do ORM no Capítulo 4.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o conteúdo do Capítulo 2, especialmente controllers, a estrutura de projeto proposta e a classe `AppError`.

---

## 3.2 O Padrão MVC no Contexto de APIs REST

### 3.2.1 Origem e propósito

O padrão **MVC** (*Model-View-Controller*) foi concebido na década de 1970 por Trygve Reenskaug, durante seu trabalho na Xerox PARC com a linguagem Smalltalk. Sua motivação original era separar a interface gráfica (*View*) da lógica de negócio (*Model*), conectando-as por meio de um coordenador (*Controller*) que respondesse às ações do usuário. Durante décadas, o padrão dominou o desenvolvimento de aplicações desktop e, posteriormente, frameworks web como Ruby on Rails, Laravel e Django.

📖 Leitura de referência: [Model–view–controller — Wikipedia](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller)

### 3.2.2 MVC adaptado para APIs REST

Em aplicações web tradicionais, a *View* é responsável por renderizar HTML que será exibido no navegador. Em APIs REST, não existe renderização de interface — o servidor produz dados estruturados (tipicamente JSON) que serão consumidos por um cliente independente: um front-end em React, um aplicativo móvel ou outro serviço. Essa diferença fundamental implica uma adaptação do padrão original.

No contexto de APIs Express, as três camadas do MVC assumem os seguintes papéis:

A camada **Model** representa as entidades do domínio e as regras de acesso aos dados. Em projetos com ORM, os models são as definições de tabelas e seus relacionamentos (Capítulo 4). Por enquanto, pode-se pensar no Model como a estrutura de dados que descreve um recurso — um `Usuario`, um `Produto` — e o mecanismo responsável por persistir e recuperar esses dados.

A camada **View** é substituída, na prática, pela resposta JSON produzida pelo servidor. Não existe um arquivo de template ou componente visual — `res.json()` cumpre o papel de serializar o modelo para o formato que o cliente espera.

A camada **Controller** permanece com seu papel original: receber a requisição, coordenar o fluxo entre as camadas e devolver a resposta. Sua responsabilidade é exclusivamente orquestrar — nunca processar lógica de negócio diretamente.

> 📷 **Sugestão de imagem:** Diagrama comparativo entre o MVC tradicional (com View renderizando HTML) e o MVC para APIs (com res.json() no lugar da View), evidenciando a substituição da camada de apresentação.

### 3.2.3 O problema do controller gordo

Um antipadrão recorrente em projetos Express iniciantes é o chamado *fat controller* (controller gordo): um controller que acumula validação de entrada, regras de negócio, acesso direto ao banco de dados e montagem da resposta — tudo em uma única função. O exemplo abaixo ilustra esse problema:

```javascript
// ❌ Antipadrão: controller gordo
export const criarUsuario = async (req, res) => {
  const { nome, email, senha } = req.body;

  // Validação de entrada misturada com lógica de negócio
  if (!email.includes('@')) return res.status(400).json({ erro: 'E-mail inválido' });
  if (senha.length < 8) return res.status(400).json({ erro: 'Senha muito curta' });

  // Acesso direto ao banco misturado com regra de negócio
  const existe = await db.query('SELECT id FROM usuarios WHERE email = $1', [email]);
  if (existe.rows.length > 0) return res.status(409).json({ erro: 'E-mail já cadastrado' });

  const hash = await bcrypt.hash(senha, 10);
  const result = await db.query(
    'INSERT INTO usuarios (nome, email, senha) VALUES ($1, $2, $3) RETURNING *',
    [nome, email, hash]
  );

  res.status(201).json(result.rows[0]);
};
```

Este controller é impossível de testar sem um banco de dados real, não pode ser reutilizado em outros contextos (como um job em background) e qualquer alteração na regra de negócio exige modificar o controller — violando o princípio da separação de responsabilidades estudado no Capítulo 2. A solução passa pela distribuição dessas responsabilidades entre camadas bem definidas, como será detalhado nas seções seguintes.

---

## 3.3 A Camada de Service em Profundidade

### 3.3.1 Responsabilidades do service

A camada de **Service** é a guardiã da lógica de negócio da aplicação. Ela reside entre o controller e o repositório de dados, e sua responsabilidade central é expressar *o que a aplicação faz* — independentemente de *como* os dados chegam (HTTP, fila de mensagens, CLI) e de *onde* são armazenados (PostgreSQL, MongoDB, memória).

Uma regra fundamental decorre dessa definição: **um service não deve conhecer os objetos `req` e `res`**. Se um método de service recebe ou retorna objetos do Express, ele está acoplado à camada de transporte HTTP, o que impede sua reutilização em outros contextos e dificulta os testes. O controller é o único responsável por extrair dados do `req` e construir o `res` — o service opera apenas com dados puros.

```javascript
// ❌ Service acoplado ao Express
async criarUsuario(req) {
  const { nome, email } = req.body; // Conhece req — acoplamento indevido
  // ...
}

// ✅ Service independente de transporte
async criarUsuario({ nome, email, senha }) {
  // Opera apenas com dados primitivos — pode ser chamado de qualquer contexto
  // ...
}
```

### 3.3.2 Validações de domínio versus validações de entrada

Um aspecto importante da camada de service é a distinção entre dois tipos de validação. As **validações de entrada** — formato de e-mail, tamanho mínimo de senha, campos obrigatórios — pertencem aos middlewares de validação, pois dizem respeito ao contrato da API. As **validações de domínio** — um usuário não pode ter dois endereços de e-mail cadastrados, um produto com estoque zero não pode ser vendido — pertencem ao service, pois expressam regras do negócio.

```javascript
// src/services/usuarios.service.js
export class UsuariosService {

  constructor(usuariosRepository) {
    this.repository = usuariosRepository;
  }

  async criar({ nome, email, senha }) {
    // Validação de domínio: unicidade de e-mail é uma regra de negócio
    const jaExiste = await this.repository.buscarPorEmail(email);
    if (jaExiste) throw new AppError('E-mail já cadastrado', 409);

    // Regra de negócio: senha deve ser armazenada como hash
    const senhaHash = await bcrypt.hash(senha, 10);

    return this.repository.criar({ nome, email, senha: senhaHash });
  }

  async buscarPorId(id) {
    const usuario = await this.repository.buscarPorId(id);
    if (!usuario) throw new AppError('Usuário não encontrado', 404);
    return usuario;
  }
}
```

Observe que o service não sabe *como* o repositório armazena os dados — ele apenas chama métodos bem definidos. Essa abstração é o objeto de estudo da próxima seção.

### 3.3.3 O service como ponto de reutilização

Uma consequência natural da independência do service em relação ao transporte HTTP é sua reutilizabilidade. O mesmo `UsuariosService.criar()` pode ser invocado a partir de um controller HTTP, de um comando CLI de seed de banco de dados, de um worker que processa uma fila de novos cadastros ou de um teste automatizado — sem qualquer modificação. Essa flexibilidade é um dos principais argumentos em favor da arquitetura em camadas.

---

## 3.4 O Repository Pattern

### 3.4.1 O problema do acoplamento direto à persistência

Sem o Repository Pattern, a camada de service acessa diretamente o mecanismo de persistência — seja um ORM, queries SQL brutas ou chamadas a uma API externa. Isso cria um acoplamento que torna o código difícil de testar e de evoluir: trocar o banco de dados de PostgreSQL para MongoDB, por exemplo, exigiria modificar todos os services que constroem queries diretamente.

### 3.4.2 O repositório como contrato

O **Repository Pattern** resolve esse problema introduzindo uma camada de abstração entre o service e o mecanismo de persistência. Um repositório é um objeto que expõe uma interface orientada ao domínio — `buscarPorId`, `criar`, `listarTodos` — ocultando completamente os detalhes de como esses dados são recuperados ou armazenados.

Do ponto de vista do service, um repositório é simplesmente um colaborador que sabe *onde* os dados vivem. O service não precisa saber se os dados estão em um banco relacional, em memória ou em uma API externa — ele apenas chama os métodos do repositório.

> 📷 **Sugestão de imagem:** Diagrama em camadas mostrando: Controller → Service → Repository → Banco de Dados, com setas indicando o sentido das dependências e destacando que o service conhece apenas a interface do repositório, não sua implementação.

### 3.4.3 Implementação de um repositório em memória

O repositório a seguir é funcionalmente equivalente ao array em memória utilizado no Capítulo 2, mas agora encapsulado em uma classe com interface bem definida:

```javascript
// src/repositories/usuarios.repository.js

export class UsuariosRepository {
  constructor() {
    // Dados em memória — será substituído pelo ORM no Capítulo 4
    this.usuarios = [
      { id: 1, nome: 'Ana Silva',   email: 'ana@exemplo.com',   senha: 'hash1' },
      { id: 2, nome: 'Bruno Costa', email: 'bruno@exemplo.com', senha: 'hash2' },
    ];
    this.proximoId = 3;
  }

  async listarTodos() {
    return this.usuarios;
  }

  async buscarPorId(id) {
    return this.usuarios.find((u) => u.id === id) ?? null;
  }

  async buscarPorEmail(email) {
    return this.usuarios.find((u) => u.email === email) ?? null;
  }

  async criar(dados) {
    const novoUsuario = { id: this.proximoId++, ...dados };
    this.usuarios.push(novoUsuario);
    return novoUsuario;
  }

  async atualizar(id, dados) {
    const indice = this.usuarios.findIndex((u) => u.id === id);
    if (indice === -1) return null;
    this.usuarios[indice] = { ...this.usuarios[indice], ...dados, id };
    return this.usuarios[indice];
  }

  async remover(id) {
    const indice = this.usuarios.findIndex((u) => u.id === id);
    if (indice === -1) return false;
    this.usuarios.splice(indice, 1);
    return true;
  }
}
```

A interface desse repositório — seus nomes de método e suas assinaturas — é o *contrato* que o service depende. Quando o Prisma for introduzido no Capítulo 4, será criado um `UsuariosRepositoryPrisma` que implementa exatamente os mesmos métodos, e o service não precisará ser alterado.

### 3.4.4 O repositório Prisma (prévia do Capítulo 4)

Para antecipar como a substituição ocorrerá, o repositório baseado em Prisma terá a seguinte estrutura — que pode ser ignorada por ora e retomada no Capítulo 4:

```javascript
// src/repositories/usuarios.repository.prisma.js
import { prisma } from '../config/database.js';

export class UsuariosRepositoryPrisma {

  async listarTodos() {
    return prisma.usuario.findMany();
  }

  async buscarPorId(id) {
    return prisma.usuario.findUnique({ where: { id } });
  }

  async buscarPorEmail(email) {
    return prisma.usuario.findUnique({ where: { email } });
  }

  async criar(dados) {
    return prisma.usuario.create({ data: dados });
  }

  async atualizar(id, dados) {
    return prisma.usuario.update({ where: { id }, data: dados });
  }

  async remover(id) {
    await prisma.usuario.delete({ where: { id } });
    return true;
  }
}
```

A identidade entre as interfaces dos dois repositórios é proposital. O service depende do *contrato*, não da *implementação* — e é exatamente esse princípio que a próxima seção formaliza.

---

## 3.5 Inversão de Dependência

### 3.5.1 O problema do acoplamento estático

Quando um objeto instancia diretamente suas dependências com `new`, ele se torna responsável não apenas por usá-las, mas também por criá-las. Isso gera acoplamento estático: mudar a implementação exige alterar o código do objeto que depende dela.

```javascript
// ❌ Acoplamento estático: o service cria seu próprio repositório
export class UsuariosService {
  constructor() {
    this.repository = new UsuariosRepository(); // Acoplado à implementação concreta
  }
}
```

Nessa forma, é impossível substituir o repositório por outro — seja para testes, seja para trocar o banco de dados — sem modificar o service.

### 3.5.2 Injeção de dependência manual

A solução mais simples é a **injeção de dependência**: em vez de criar o repositório internamente, o service o recebe como parâmetro do construtor. Quem instancia o service é responsável por fornecer a implementação correta.

```javascript
// ✅ Dependência injetada pelo construtor
export class UsuariosService {
  constructor(repository) {
    this.repository = repository; // Desacoplado — aceita qualquer implementação
  }
}
```

```javascript
// Composição na camada de inicialização (app.js ou arquivo de rotas)
import { UsuariosRepository } from '../repositories/usuarios.repository.js';
import { UsuariosService } from '../services/usuarios.service.js';
import { UsuariosController } from '../controllers/usuarios.controller.js';

const repository  = new UsuariosRepository();
const service     = new UsuariosService(repository);
const controller  = new UsuariosController(service);
```

Essa composição é realizada uma única vez, no ponto de entrada da aplicação. Controllers, services e repositórios permanecem completamente desacoplados uns dos outros — cada um conhece apenas a interface do colaborador que precisa, não sua implementação concreta.

### 3.5.3 Benefício direto: testabilidade

O benefício mais imediato da injeção de dependência é a facilidade de teste. Em vez de um banco de dados real, é possível injetar um repositório falso (*mock* ou *stub*) que simula o comportamento esperado:

```javascript
// Teste do service sem banco de dados
it('deve lançar erro 409 se e-mail já existir', async () => {
  // Repositório falso que simula e-mail já cadastrado
  const repositorioFalso = {
    buscarPorEmail: async () => ({ id: 1, email: 'ana@exemplo.com' }),
    criar: async () => {},
  };

  const service = new UsuariosService(repositorioFalso);

  await expect(
    service.criar({ nome: 'Ana', email: 'ana@exemplo.com', senha: '12345678' })
  ).rejects.toThrow('E-mail já cadastrado');
});
```

O teste acima verifica uma regra de negócio real — unicidade de e-mail — sem abrir nenhuma conexão com banco de dados, sem configurar fixtures e sem depender de estado externo. Ele é rápido, determinístico e isolado. Esse é o padrão que será aprofundado no Capítulo 7, dedicado a testes automatizados.

---

## 3.6 Refatorando o Projeto do Capítulo 2

### 3.6.1 Visão geral da refatoração

O projeto do Capítulo 2 terminou com um `UsuariosService` que operava diretamente sobre um array em memória. Aplicando os padrões deste capítulo, a responsabilidade de persistência será extraída para um `UsuariosRepository`, o service passará a depender do repositório via injeção, e o controller será refatorado para usar injeção de dependência no construtor.

A estrutura de arquivos resultante é a seguinte:

```
src/
├── controllers/
│   └── usuarios.controller.js   ← Recebe service via construtor
├── services/
│   └── usuarios.service.js      ← Recebe repository via construtor
├── repositories/
│   └── usuarios.repository.js   ← Encapsula a persistência em memória
├── routes/
│   ├── index.js
│   └── usuarios.routes.js       ← Realiza a composição das dependências
└── utils/
    └── AppError.js
```

### 3.6.2 O repositório

```javascript
// src/repositories/usuarios.repository.js
export class UsuariosRepository {
  constructor() {
    this.usuarios = [
      { id: 1, nome: 'Ana Silva',   email: 'ana@exemplo.com',   senha: 'hash1' },
      { id: 2, nome: 'Bruno Costa', email: 'bruno@exemplo.com', senha: 'hash2' },
    ];
    this.proximoId = 3;
  }

  async listarTodos() {
    return this.usuarios;
  }

  async buscarPorId(id) {
    return this.usuarios.find((u) => u.id === id) ?? null;
  }

  async buscarPorEmail(email) {
    return this.usuarios.find((u) => u.email === email) ?? null;
  }

  async criar(dados) {
    const novo = { id: this.proximoId++, ...dados };
    this.usuarios.push(novo);
    return novo;
  }

  async atualizar(id, dados) {
    const i = this.usuarios.findIndex((u) => u.id === id);
    if (i === -1) return null;
    this.usuarios[i] = { ...this.usuarios[i], ...dados, id };
    return this.usuarios[i];
  }

  async remover(id) {
    const i = this.usuarios.findIndex((u) => u.id === id);
    if (i === -1) return false;
    this.usuarios.splice(i, 1);
    return true;
  }
}
```

### 3.6.3 O service refatorado

```javascript
// src/services/usuarios.service.js
import bcrypt from 'bcrypt';
import { AppError } from '../utils/AppError.js';

export class UsuariosService {
  constructor(repository) {
    this.repository = repository; // Dependência injetada
  }

  async listarTodos() {
    return this.repository.listarTodos();
  }

  async buscarPorId(id) {
    const usuario = await this.repository.buscarPorId(id);
    if (!usuario) throw new AppError('Usuário não encontrado', 404);
    return usuario;
  }

  async criar({ nome, email, senha }) {
    const jaExiste = await this.repository.buscarPorEmail(email);
    if (jaExiste) throw new AppError('E-mail já cadastrado', 409);

    const senhaHash = await bcrypt.hash(senha, 10);
    return this.repository.criar({ nome, email, senha: senhaHash });
  }

  async atualizar(id, dados) {
    await this.buscarPorId(id); // Reutiliza a validação de existência
    return this.repository.atualizar(id, dados);
  }

  async remover(id) {
    await this.buscarPorId(id); // Reutiliza a validação de existência
    return this.repository.remover(id);
  }
}
```

### 3.6.4 O controller refatorado

```javascript
// src/controllers/usuarios.controller.js
export class UsuariosController {
  constructor(service) {
    this.service = service; // Dependência injetada

    // Binding necessário para preservar o contexto de `this` nos handlers
    this.listarTodos   = this.listarTodos.bind(this);
    this.buscarPorId   = this.buscarPorId.bind(this);
    this.criar         = this.criar.bind(this);
    this.atualizar     = this.atualizar.bind(this);
    this.remover       = this.remover.bind(this);
  }

  async listarTodos(req, res, next) {
    try {
      const usuarios = await this.service.listarTodos();
      res.json(usuarios);
    } catch (err) { next(err); }
  }

  async buscarPorId(req, res, next) {
    try {
      const usuario = await this.service.buscarPorId(Number(req.params.id));
      res.json(usuario);
    } catch (err) { next(err); }
  }

  async criar(req, res, next) {
    try {
      const novoUsuario = await this.service.criar(req.body);
      res.status(201).json(novoUsuario);
    } catch (err) { next(err); }
  }

  async atualizar(req, res, next) {
    try {
      const atualizado = await this.service.atualizar(Number(req.params.id), req.body);
      res.json(atualizado);
    } catch (err) { next(err); }
  }

  async remover(req, res, next) {
    try {
      await this.service.remover(Number(req.params.id));
      res.status(204).send();
    } catch (err) { next(err); }
  }
}
```

> 💡 **Por que o `.bind(this)`?** Quando o Express invoca um método de classe como handler de rota (`router.get('/', controller.listarTodos)`), ele o chama sem o contexto do objeto original — o `this` dentro do método seria `undefined`. O `.bind(this)` no construtor garante que cada método sempre execute no contexto correto da instância.

### 3.6.5 A composição no arquivo de rotas

O arquivo de rotas é o único lugar onde as dependências são instanciadas e compostas. Essa concentração da composição em um único ponto é denominada *composition root* — um princípio que facilita a localização e a troca de implementações.

```javascript
// src/routes/usuarios.routes.js
import { Router } from 'express';
import { UsuariosRepository }  from '../repositories/usuarios.repository.js';
import { UsuariosService }     from '../services/usuarios.service.js';
import { UsuariosController }  from '../controllers/usuarios.controller.js';
import { validarCriacaoUsuario } from '../middlewares/validacao.middleware.js';

// Composição das dependências
const repository = new UsuariosRepository();
const service    = new UsuariosService(repository);
const controller = new UsuariosController(service);

const router = Router();

router.get('/',    controller.listarTodos);
router.get('/:id', controller.buscarPorId);
router.post('/',   validarCriacaoUsuario, controller.criar);
router.put('/:id', controller.atualizar);
router.delete('/:id', controller.remover);

export default router;
```

---

## 3.7 Exercícios Práticos

### Exercício 3.1 — Repository para Produtos

Implemente um `ProdutosRepository` em memória com os métodos `listarTodos`, `buscarPorId`, `criar`, `atualizar` e `remover`. Crie em seguida um `ProdutosService` que receba o repositório via construtor e implemente as seguintes regras de negócio: o preço de um produto não pode ser negativo (lançar `AppError` com status 400); dois produtos não podem ter o mesmo nome (lançar `AppError` com status 409).

### Exercício 3.2 — Controller com injeção de dependência

Implemente um `ProdutosController` que receba o service via construtor e exponha os cinco handlers de CRUD. Realize a composição no arquivo `produtos.routes.js` e monte o router em `/api/produtos` na aplicação principal.

### Exercício 3.3 — Teste unitário do service

Escreva dois testes unitários para o `ProdutosService` utilizando repositórios falsos injetados:

O primeiro deve verificar que a criação de um produto com preço negativo lança `AppError` com status 400. O segundo deve verificar que a criação de um produto com nome duplicado lança `AppError` com status 409. Nenhum dos testes deve instanciar o `ProdutosRepository` real.

### Exercício 3.4 — Refatoração completa

Partindo do código do Exercício 2.4 (Capítulo 2), aplique todos os padrões deste capítulo ao recurso `tarefas`: extraia um `TarefasRepository`, refatore o `TarefasService` para usar injeção de dependência e converta o controller para uma classe. Ao final, a estrutura de arquivos deve refletir fielmente a apresentada na seção 3.6.1.

---

## 3.8 Resumo do Capítulo

O MVC adaptado para APIs distribui as responsabilidades entre três camadas: o controller coordena o fluxo da requisição, o service encapsula a lógica de negócio e o model/repositório abstrai o acesso aos dados. O service é a camada mais importante dessa tríade — é nele que residem as regras que definem o comportamento da aplicação, e ele deve ser completamente independente do transporte HTTP. O Repository Pattern formaliza a separação entre lógica de negócio e persistência, definindo um contrato estável que permite trocar o mecanismo de armazenamento sem alterar o service. A injeção de dependência, por sua vez, é o mecanismo que torna essa substituição possível na prática — e que abre caminho para testes rápidos, isolados e confiáveis. A arquitetura resultante é a base sobre a qual o ORM será integrado no Capítulo 4.

---

## 3.9 Referências e Leituras Complementares

- [Model–view–controller — Wikipedia](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller)
- [Repository Pattern — Martin Fowler, Patterns of Enterprise Application Architecture](https://www.martinfowler.com/eaaCatalog/repository.html)
- [Inversion of Control — Martin Fowler](https://martinfowler.com/articles/injection.html)
- [Node.js Best Practices — Project Structure](https://github.com/goldbergyoni/nodebestpractices#1-project-structure-practices)
- 📖 Martin, R. C. *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall, 2017. — Capítulos 5 e 22.

---

!!! note "Próximo Capítulo"
    No **Capítulo 4 — Banco de Dados e ORM**, o `UsuariosRepository` em memória será substituído por uma implementação real com **Prisma**, conectada a um banco de dados PostgreSQL. Graças à arquitetura construída neste capítulo, essa substituição exigirá a criação de um único arquivo novo — sem qualquer alteração no service ou no controller.
