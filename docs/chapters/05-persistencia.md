# Capítulo 5 — Banco de Dados e ORM: Prisma e Sequelize

---

## 5.1 Introdução

O Capítulo 4 encerrou com uma arquitetura bem estruturada: controllers que orquestram, services que guardam a lógica de negócio e repositórios que abstraem a persistência. No entanto, toda aquela persistência ainda era simulada — os dados viviam em arrays na memória e desapareciam a cada reinicialização do servidor. Este capítulo resolve esse problema de forma definitiva, substituindo os repositórios em memória por implementações reais apoiadas em banco de dados relacional.

O ponto de partida é uma revisão dos fundamentos de bancos de dados relacionais e da linguagem SQL, incluindo uma seção dedicada à persistência com SQL puro — antes de qualquer abstração — para que o funcionamento interno dos ORMs seja compreendido com clareza. Em seguida, o capítulo apresenta dois dos ORMs mais relevantes do ecossistema Node.js: o **Prisma**, com sua abordagem declarativa e fortemente tipada, e o **Sequelize**, o ORM mais maduro e amplamente adotado no ecossistema. Para cada um, são cobertos: instalação e configuração, definição de modelos, migrations e CRUD completo. Uma seção dedicada aprofunda os relacionamentos 1:N, N:1 e N:M em ambos os ORMs, seguida de uma seção completa sobre filtros, ordenação e paginação. O capítulo encerra com a substituição do `UsuariosRepository` em memória pelas implementações Prisma e Sequelize, uma introdução aos bancos de dados não relacionais (MongoDB, Redis) e um comparativo final para orientar a escolha em projetos reais.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o Capítulo 4, especialmente o Repository Pattern e a injeção de dependência. O conhecimento básico de SQL é útil mas não obrigatório — os conceitos essenciais são revisados nas seções 5.2 e 5.3.

---

## 5.2 Fundamentos de Banco de Dados Relacional

### 5.2.1 Por que bancos relacionais?

Um **banco de dados relacional** organiza os dados em **tabelas** — estruturas bidimensionais compostas por linhas (registros) e colunas (atributos). Cada tabela representa uma entidade do domínio: `usuarios`, `produtos`, `pedidos`. As tabelas se relacionam entre si por meio de **chaves estrangeiras** (*foreign keys*), que criam referências explícitas entre registros de tabelas distintas.

A principal vantagem dos bancos relacionais é a **integridade referencial**: o banco de dados garante que uma chave estrangeira sempre aponte para um registro existente, impedindo dados órfãos e inconsistências. Além disso, a linguagem **SQL** (*Structured Query Language*) oferece um vocabulário declarativo poderoso para consultas complexas, filtragens, ordenações e agregações — operações que seriam custosas de implementar em memória.

No contexto deste curso, o banco de dados utilizado é o **PostgreSQL** para ambiente de produção/desenvolvimento e o **SQLite** para testes e exercícios locais, por não exigir instalação de servidor.

### 5.2.2 Conceitos essenciais

**Chave primária (Primary Key):** identificador único de cada registro em uma tabela. Convencionalmente, utiliza-se uma coluna `id` do tipo inteiro com auto-incremento, ou um UUID gerado automaticamente.

**Chave estrangeira (Foreign Key):** coluna que armazena o valor da chave primária de outra tabela, estabelecendo um vínculo entre os registros. Por exemplo, uma tabela `pedidos` pode ter uma coluna `usuario_id` que referencia a chave primária da tabela `usuarios`.

**Índice:** estrutura auxiliar que acelera consultas em colunas frequentemente utilizadas em filtros. Colunas que são chaves estrangeiras ou utilizadas em cláusulas `WHERE` são boas candidatas a índices.

**Transação:** conjunto de operações que são executadas atomicamente — ou todas têm sucesso, ou nenhuma é aplicada. Essencial para operações que envolvem múltiplas tabelas.

**Migration:** arquivo versionado que descreve uma alteração incremental no esquema do banco de dados (criação de tabela, adição de coluna, criação de índice). Migrations permitem que o esquema evolua de forma controlada e reproduzível em todos os ambientes.

### 5.2.3 SQL essencial para desenvolvedores Node.js

Os ORMs abstraem o SQL, mas compreender as operações fundamentais é indispensável para depurar consultas geradas, otimizar performance e entender o que ocorre por baixo dos panos.

```sql
-- Criação de tabela
CREATE TABLE usuarios (
  id        SERIAL PRIMARY KEY,
  nome      VARCHAR(100) NOT NULL,
  email     VARCHAR(150) NOT NULL UNIQUE,
  senha     TEXT         NOT NULL,
  criado_em TIMESTAMP    DEFAULT NOW()
);

-- Inserção
INSERT INTO usuarios (nome, email, senha)
VALUES ('Ana Silva', 'ana@exemplo.com', 'hash_da_senha');

-- Consulta com filtro
SELECT id, nome, email FROM usuarios WHERE email = 'ana@exemplo.com';

-- Atualização
UPDATE usuarios SET nome = 'Ana Lima' WHERE id = 1;

-- Remoção
DELETE FROM usuarios WHERE id = 1;

-- Consulta com JOIN (relacionamento)
SELECT p.id, p.titulo, u.nome AS autor
FROM posts p
JOIN usuarios u ON p.usuario_id = u.id
WHERE u.id = 1;
```

Cada uma dessas operações tem um equivalente direto nas APIs dos ORMs que serão estudados nas seções seguintes.

---

## 5.3 Persistindo Dados Diretamente com SQL

Antes de introduzir os ORMs, vale compreender como a persistência funciona sem nenhuma abstração: conectando-se ao banco de dados diretamente e executando SQL puro a partir do Node.js. Essa abordagem é denominada **acesso direto** ou *raw SQL*, e é importante por duas razões: ela revela o que os ORMs fazem por baixo dos panos, e é a única opção disponível quando a complexidade da consulta supera o que a API do ORM consegue expressar.

### 5.3.1 O driver `pg` para PostgreSQL

Para conectar uma aplicação Node.js a um banco PostgreSQL sem ORM, utiliza-se o pacote `pg` (também chamado de *node-postgres*):

```bash
npm install pg
```

A conexão é gerenciada por um **pool** — um conjunto de conexões reutilizáveis que evita a sobrecarga de abrir e fechar uma nova conexão a cada query:

```javascript
// src/config/database.js
import pg from 'pg';

const { Pool } = pg;

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max:     10,   // máximo de conexões simultâneas no pool
  idleTimeoutMillis: 30000,
});
```

### 5.3.2 CRUD com SQL puro

Com o pool configurado, as queries são executadas via `pool.query()`. O segundo argumento é um array de valores parametrizados — prática essencial para prevenir **SQL Injection**:

```javascript
import { pool } from '../config/database.js';

// ── CREATE ──────────────────────────────────────────────
const resultado = await pool.query(
  `INSERT INTO usuarios (nome, email, senha)
   VALUES ($1, $2, $3)
   RETURNING *`,
  [nome, email, senhaHash]
);
const novoUsuario = resultado.rows[0];

// ── READ ────────────────────────────────────────────────
const todos = await pool.query('SELECT * FROM usuarios ORDER BY criado_em DESC');
const usuarios = todos.rows;

const res = await pool.query('SELECT * FROM usuarios WHERE id = $1', [id]);
const usuario = res.rows[0] ?? null;

// ── UPDATE ──────────────────────────────────────────────
const upd = await pool.query(
  'UPDATE usuarios SET nome = $1 WHERE id = $2 RETURNING *',
  [novoNome, id]
);

// ── DELETE ──────────────────────────────────────────────
await pool.query('DELETE FROM usuarios WHERE id = $1', [id]);
```

!!! warning "SQL Injection"
    Nunca interpole valores diretamente na string SQL com template literals. Use sempre os parâmetros posicionais `$1`, `$2`, ... — o driver `pg` os escapa automaticamente, prevenindo injeção de SQL.

### 5.3.3 Repositório com SQL puro

O Repository Pattern funciona igualmente bem com SQL direto. O `UsuariosRepositorySQL` a seguir implementa o mesmo contrato dos repositórios em memória do Capítulo 4, agora persistindo no banco:

```javascript
// src/repositories/usuarios.repository.sql.js
import { pool } from '../config/database.js';

export class UsuariosRepositorySQL {

  async listarTodos() {
    const { rows } = await pool.query(
      'SELECT id, nome, email, criado_em FROM usuarios ORDER BY criado_em DESC'
    );
    return rows;
  }

  async buscarPorId(id) {
    const { rows } = await pool.query(
      'SELECT * FROM usuarios WHERE id = $1', [id]
    );
    return rows[0] ?? null;
  }

  async buscarPorEmail(email) {
    const { rows } = await pool.query(
      'SELECT * FROM usuarios WHERE email = $1', [email]
    );
    return rows[0] ?? null;
  }

  async criar(dados) {
    const { nome, email, senha } = dados;
    const { rows } = await pool.query(
      `INSERT INTO usuarios (nome, email, senha)
       VALUES ($1, $2, $3) RETURNING *`,
      [nome, email, senha]
    );
    return rows[0];
  }

  async atualizar(id, dados) {
    const { nome, email } = dados;
    const { rows } = await pool.query(
      'UPDATE usuarios SET nome = $1, email = $2 WHERE id = $3 RETURNING *',
      [nome, email, id]
    );
    return rows[0] ?? null;
  }

  async remover(id) {
    const { rowCount } = await pool.query(
      'DELETE FROM usuarios WHERE id = $1', [id]
    );
    return rowCount > 0;
  }
}
```

### 5.3.4 Quando usar SQL direto vs. ORM

O acesso direto via SQL é adequado em cenários específicos: consultas analíticas muito complexas com múltiplos JOINs e agregações, operações de alta performance onde cada milissegundo importa, ou integração com bancos legados que possuem stored procedures e triggers específicos. Para a grande maioria dos casos em APIs REST, porém, os ORMs oferecem produtividade, segurança e manutenibilidade superiores.


---

## 5.4 O que é um ORM?

Um **ORM** (*Object-Relational Mapper*, ou Mapeador Objeto-Relacional) é uma biblioteca que estabelece uma ponte entre o modelo de objetos da linguagem de programação e o modelo relacional do banco de dados. Em vez de escrever SQL diretamente, o desenvolvedor trabalha com objetos e métodos JavaScript — e o ORM se encarrega de traduzir essas operações para as queries SQL equivalentes.

A analogia mais direta é a do intérprete: o ORM fala tanto "JavaScript" quanto "SQL", traduzindo um para o outro em tempo real. Quando se chama `usuario.save()`, o ORM gera e executa o `INSERT` ou `UPDATE` apropriado; quando se chama `Usuario.findAll({ where: { ativo: true } })`, o ORM produz `SELECT * FROM usuarios WHERE ativo = true`.

### 5.4.1 Vantagens e limitações

As principais vantagens de um ORM são a produtividade — escrever menos SQL boilerplate —, a portabilidade entre bancos de dados diferentes, e a integração natural com o sistema de tipos da linguagem. No caso do Prisma, essa integração vai além: o TypeScript (e o JavaScript com JSDoc) obtém autocompletar e verificação de tipos para todas as operações do banco.

As limitações surgem em cenários de alta complexidade: consultas muito específicas, otimizações finas de performance ou uso de funcionalidades avançadas do banco podem exigir SQL bruto (*raw queries*), que todos os ORMs suportam como válvula de escape.

### 5.4.2 Prisma vs. Sequelize: visão geral comparativa

| Característica | Prisma | Sequelize |
|---|---|---|
| Paradigma | Schema-first (arquivo `.prisma`) | Code-first (models em JS/TS) |
| Tipagem | Excelente (geração automática) | Boa (com TypeScript) |
| Migrations | Automáticas a partir do schema | Manuais ou com CLI |
| API de consulta | Fluente e previsível | Fluente, mais verbosa |
| Maturidade | Moderna (2019+) | Consolidada (2011+) |
| Comunidade | Crescente e muito ativa | Grande e estabelecida |
| Curva de aprendizado | Baixa | Moderada |

A escolha entre os dois depende do contexto: o Prisma é recomendado para projetos novos que valorizam produtividade e tipagem; o Sequelize é frequentemente encontrado em projetos existentes e equipes com experiência prévia em ORMs tradicionais. Este capítulo cobre ambos para que o desenvolvedor possa atuar em qualquer cenário.

---

## 5.5 Prisma

### 5.5.1 Instalação e configuração inicial

O Prisma é composto por três partes: o **Prisma Client** (a biblioteca de acesso ao banco, usada no código da aplicação), o **Prisma CLI** (ferramenta de linha de comando para migrations e geração de código) e o **Prisma Schema** (arquivo declarativo que define os modelos e a conexão).

```bash
# Instalar as dependências
npm install @prisma/client
npm install --save-dev prisma

# Inicializar o Prisma no projeto (cria prisma/schema.prisma e .env)
npx prisma init --datasource-provider postgresql
```

O comando `prisma init` cria dois arquivos: o arquivo de schema em `prisma/schema.prisma` e uma entrada no `.env` com a variável `DATABASE_URL`. Para desenvolvimento local com SQLite, a configuração é ainda mais simples:

```bash
npx prisma init --datasource-provider sqlite
```

O arquivo `.env` gerado deve ser adaptado com a URL de conexão real:

```bash
# PostgreSQL
DATABASE_URL="postgresql://usuario:senha@localhost:5432/minha_api"

# SQLite (arquivo local — ideal para desenvolvimento)
DATABASE_URL="file:./dev.db"
```

### 5.5.2 O Prisma Schema

O **Prisma Schema** (`prisma/schema.prisma`) é o coração do Prisma. Nele são definidos o provider do banco de dados, a URL de conexão e os **models** — representações das entidades do domínio. A sintaxe é declarativa e fortemente tipada:

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"   // ou "sqlite"
  url      = env("DATABASE_URL")
}

model Usuario {
  id        Int      @id @default(autoincrement())
  nome      String
  email     String   @unique
  senha     String
  criadoEm DateTime @default(now()) @map("criado_em")
  posts     Post[]   // relação 1:N com Post

  @@map("usuarios")  // nome da tabela no banco
}

model Post {
  id         Int      @id @default(autoincrement())
  titulo     String
  conteudo   String?
  publicado  Boolean  @default(false)
  criadoEm  DateTime @default(now()) @map("criado_em")
  autor      Usuario  @relation(fields: [autorId], references: [id])
  autorId    Int      @map("autor_id")

  @@map("posts")
}
```

Cada campo do model corresponde a uma coluna da tabela. Os decoradores (`@id`, `@unique`, `@default`, `@map`) controlam o comportamento do campo no banco. A diretiva `@@map` define o nome da tabela, permitindo usar convenções diferentes no código e no banco (camelCase no código, snake_case no banco).

### 5.5.3 Migrations com Prisma

Uma **migration** é a tradução das alterações no schema para comandos SQL que modificam o banco de dados. O Prisma gera as migrations automaticamente a partir das diferenças entre o schema atual e o estado do banco:

```bash
# Cria a migration e aplica ao banco de desenvolvimento
npx prisma migrate dev --name criar_tabelas_iniciais

# Aplica migrations pendentes (produção)
npx prisma migrate deploy

# Visualiza o estado atual do banco
npx prisma migrate status

# Reseta o banco e reaplica todas as migrations (cuidado: apaga dados)
npx prisma migrate reset
```

O comando `migrate dev` gera um arquivo SQL na pasta `prisma/migrations/` e o executa. Esse arquivo deve ser versionado no Git — ele é o registro histórico de todas as alterações no schema do banco.

Após qualquer alteração no schema, é necessário regenerar o Prisma Client:

```bash
npx prisma generate
```

### 5.5.4 Configurando o Prisma Client

O Prisma Client deve ser instanciado uma única vez na aplicação e reutilizado por todos os módulos. O padrão recomendado é criar um singleton:

```javascript
// src/config/database.js
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development'
    ? ['query', 'info', 'warn', 'error']
    : ['error'],
});

export { prisma };
```

!!! note "Por que um singleton?"
    O `PrismaClient` mantém um pool de conexões com o banco. Instanciar múltiplos clients desperdiça conexões e pode causar erros de limite de conexões em produção. O singleton garante que toda a aplicação compartilhe o mesmo pool.

### 5.5.5 CRUD completo com Prisma

Com o client configurado, as operações de CRUD são realizadas através de métodos tipados gerados automaticamente para cada model:

```javascript
import { prisma } from '../config/database.js';

// ── CREATE ──────────────────────────────────────────────
const novoUsuario = await prisma.usuario.create({
  data: {
    nome:  'Ana Silva',
    email: 'ana@exemplo.com',
    senha: 'hash_da_senha',
  },
});

// ── READ ────────────────────────────────────────────────
// Buscar todos
const usuarios = await prisma.usuario.findMany();

// Buscar com filtro e ordenação
const ativos = await prisma.usuario.findMany({
  where:   { ativo: true },
  orderBy: { criadoEm: 'desc' },
  take:    10,   // LIMIT
  skip:    0,    // OFFSET
});

// Buscar um único registro
const usuario = await prisma.usuario.findUnique({
  where: { id: 1 },
});

// Buscar por campo único (e-mail, slug, etc.)
const porEmail = await prisma.usuario.findUnique({
  where: { email: 'ana@exemplo.com' },
});

// ── UPDATE ──────────────────────────────────────────────
const atualizado = await prisma.usuario.update({
  where: { id: 1 },
  data:  { nome: 'Ana Lima' },
});

// ── DELETE ──────────────────────────────────────────────
await prisma.usuario.delete({
  where: { id: 1 },
});

// ── COUNT ───────────────────────────────────────────────
const total = await prisma.usuario.count({
  where: { ativo: true },
});
```

### 5.5.6 Relacionamentos com Prisma

O Prisma torna os relacionamentos de primeira classe. O campo `posts` no model `Usuario` e o campo `autor` no model `Post` definem um relacionamento **1:N** (um usuário tem muitos posts). Para incluir dados relacionados em uma consulta, usa-se `include`:

```javascript
// Buscar usuário com seus posts
const usuarioComPosts = await prisma.usuario.findUnique({
  where:   { id: 1 },
  include: { posts: true },
});
// Resultado: { id: 1, nome: 'Ana', posts: [{ id: 1, titulo: '...' }, ...] }

// Criar post já vinculado ao autor
const novoPost = await prisma.post.create({
  data: {
    titulo:   'Meu primeiro post',
    conteudo: 'Conteúdo do post',
    autor:    { connect: { id: 1 } }, // vincula ao usuário existente
  },
});

// Filtrar posts de um usuário específico
const postsDoUsuario = await prisma.post.findMany({
  where:   { autorId: 1 },
  include: { autor: { select: { nome: true, email: true } } }, // select parcial
});
```

**Relacionamento N:M** requer uma tabela de junção, declarada explicitamente no schema:

```prisma
model Post {
  id   Int   @id @default(autoincrement())
  tags Tag[] @relation("PostTags")
  // ...
}

model Tag {
  id    Int    @id @default(autoincrement())
  nome  String @unique
  posts Post[] @relation("PostTags")
}
```

```javascript
// Criar post com tags
const postComTags = await prisma.post.create({
  data: {
    titulo: 'Post com tags',
    tags: {
      connectOrCreate: [
        { where: { nome: 'nodejs' },  create: { nome: 'nodejs'  } },
        { where: { nome: 'backend' }, create: { nome: 'backend' } },
      ],
    },
  },
  include: { tags: true },
});
```

---

## 5.6 Sequelize

### 5.6.1 Instalação e configuração inicial

O Sequelize é instalado junto com o driver específico do banco de dados. Para PostgreSQL, usa-se o `pg`; para SQLite, o `better-sqlite3`:

```bash
# PostgreSQL
npm install sequelize pg pg-hstore

# SQLite (desenvolvimento/testes)
npm install sequelize better-sqlite3

# CLI para migrations e seeders
npm install --save-dev sequelize-cli
```

A CLI é inicializada com:

```bash
npx sequelize-cli init
```

Esse comando cria a estrutura de diretórios padrão do Sequelize:

```
config/
  config.json          # configuração de conexão por ambiente
migrations/            # arquivos de migration gerados pela CLI
models/
  index.js             # inicialização da instância Sequelize
seeders/               # dados iniciais para o banco
```

### 5.6.2 Configuração da conexão

O arquivo `config/config.json` (ou `config/config.js` para suportar variáveis de ambiente) define as conexões por ambiente:

```javascript
// config/config.js
export default {
  development: {
    dialect:  'sqlite',
    storage:  './dev.db',   // caminho do arquivo SQLite
    logging:  console.log,
  },
  test: {
    dialect: 'sqlite',
    storage: ':memory:',    // banco em memória para testes
    logging: false,
  },
  production: {
    dialect:          'postgres',
    url:              process.env.DATABASE_URL,
    dialectOptions: {
      ssl: { require: true, rejectUnauthorized: false },
    },
    logging: false,
  },
};
```

A instância do Sequelize é criada e exportada a partir de `src/config/database.js`:

```javascript
// src/config/database.js
import { Sequelize } from 'sequelize';
import config from '../../config/config.js';

const env    = process.env.NODE_ENV || 'development';
const dbConfig = config[env];

export const sequelize = dbConfig.url
  ? new Sequelize(dbConfig.url, dbConfig)
  : new Sequelize(dbConfig);
```

### 5.6.3 Definição de Models

No Sequelize, os models são definidos com `sequelize.define()` ou estendendo a classe `Model`. A abordagem com classe é mais moderna e recomendada:

```javascript
// src/models/usuario.model.js
import { Model, DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

export class Usuario extends Model {}

Usuario.init(
  {
    id: {
      type:          DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey:    true,
    },
    nome: {
      type:      DataTypes.STRING(100),
      allowNull: false,
    },
    email: {
      type:      DataTypes.STRING(150),
      allowNull: false,
      unique:    true,
      validate:  { isEmail: true },
    },
    senha: {
      type:      DataTypes.TEXT,
      allowNull: false,
    },
  },
  {
    sequelize,
    modelName:  'Usuario',
    tableName:  'usuarios',
    timestamps: true,          // createdAt e updatedAt automáticos
    underscored: true,         // snake_case nas colunas do banco
  }
);
```

### 5.6.4 Migrations com Sequelize

As migrations do Sequelize são criadas manualmente pela CLI ou escritas à mão:

```bash
# Gerar arquivo de migration em branco
npx sequelize-cli migration:generate --name criar-tabela-usuarios

# Aplicar migrations pendentes
npx sequelize-cli db:migrate

# Desfazer a última migration
npx sequelize-cli db:migrate:undo

# Desfazer todas as migrations
npx sequelize-cli db:migrate:undo:all
```

O arquivo de migration gerado segue o padrão `up` (aplicar) / `down` (reverter):

```javascript
// migrations/20250101000000-criar-tabela-usuarios.js
export async function up(queryInterface, Sequelize) {
  await queryInterface.createTable('usuarios', {
    id: {
      type:          Sequelize.INTEGER,
      autoIncrement: true,
      primaryKey:    true,
    },
    nome: {
      type:      Sequelize.STRING(100),
      allowNull: false,
    },
    email: {
      type:      Sequelize.STRING(150),
      allowNull: false,
      unique:    true,
    },
    senha: {
      type:      Sequelize.TEXT,
      allowNull: false,
    },
    created_at: {
      type:      Sequelize.DATE,
      allowNull: false,
      defaultValue: Sequelize.literal('CURRENT_TIMESTAMP'),
    },
    updated_at: {
      type:      Sequelize.DATE,
      allowNull: false,
      defaultValue: Sequelize.literal('CURRENT_TIMESTAMP'),
    },
  });

  await queryInterface.addIndex('usuarios', ['email']);
}

export async function down(queryInterface) {
  await queryInterface.dropTable('usuarios');
}
```

### 5.6.5 CRUD completo com Sequelize

```javascript
import { Usuario } from '../models/usuario.model.js';

// ── CREATE ──────────────────────────────────────────────
const novoUsuario = await Usuario.create({
  nome:  'Ana Silva',
  email: 'ana@exemplo.com',
  senha: 'hash_da_senha',
});

// ── READ ────────────────────────────────────────────────
// Buscar todos
const usuarios = await Usuario.findAll();

// Buscar com filtro
import { Op } from 'sequelize';

const recentes = await Usuario.findAll({
  where:   { createdAt: { [Op.gte]: new Date('2025-01-01') } },
  order:   [['createdAt', 'DESC']],
  limit:   10,
  offset:  0,
});

// Buscar por chave primária
const usuario = await Usuario.findByPk(1);

// Buscar um único registro por critério
const porEmail = await Usuario.findOne({
  where: { email: 'ana@exemplo.com' },
});

// ── UPDATE ──────────────────────────────────────────────
// Atualizar via instância
const u = await Usuario.findByPk(1);
u.nome = 'Ana Lima';
await u.save();

// Atualizar em massa (retorna [linhasAfetadas])
await Usuario.update(
  { nome: 'Ana Lima' },
  { where: { id: 1 } }
);

// ── DELETE ──────────────────────────────────────────────
// Deletar via instância
const u2 = await Usuario.findByPk(1);
await u2.destroy();

// Deletar em massa
await Usuario.destroy({ where: { id: 1 } });

// ── COUNT ───────────────────────────────────────────────
const total = await Usuario.count({ where: { ativo: true } });
```

### 5.6.6 Relacionamentos com Sequelize

Os relacionamentos são definidos chamando métodos de associação após a definição dos models. O padrão recomendado é centralizar as associações em um arquivo dedicado ou no próprio model:

```javascript
// src/models/post.model.js
import { Model, DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';

export class Post extends Model {}

Post.init(
  {
    id:        { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    titulo:    { type: DataTypes.STRING,  allowNull: false },
    conteudo:  { type: DataTypes.TEXT },
    publicado: { type: DataTypes.BOOLEAN, defaultValue: false },
    autorId:   { type: DataTypes.INTEGER, allowNull: false, field: 'autor_id' },
  },
  { sequelize, modelName: 'Post', tableName: 'posts', timestamps: true, underscored: true }
);
```

```javascript
// src/models/associations.js — centraliza todos os relacionamentos
import { Usuario } from './usuario.model.js';
import { Post }    from './post.model.js';
import { Tag }     from './tag.model.js';

// 1:N — um usuário tem muitos posts
Usuario.hasMany(Post,    { foreignKey: 'autorId', as: 'posts'  });
Post.belongsTo(Usuario,  { foreignKey: 'autorId', as: 'autor'  });

// N:M — posts têm muitas tags e vice-versa
Post.belongsToMany(Tag,  { through: 'post_tags', as: 'tags' });
Tag.belongsToMany(Post,  { through: 'post_tags', as: 'posts' });
```

```javascript
// Consultar com relacionamento (include = JOIN)
import { Usuario } from '../models/usuario.model.js';
import { Post }    from '../models/post.model.js';
import '../models/associations.js'; // garante que as associações estejam carregadas

const usuarioComPosts = await Usuario.findByPk(1, {
  include: [{ model: Post, as: 'posts' }],
});

// Criar post vinculado
const u = await Usuario.findByPk(1);
await u.createPost({ titulo: 'Meu post', conteudo: 'Conteúdo' });

// Consultar posts com autor
const posts = await Post.findAll({
  include: [{ model: Usuario, as: 'autor', attributes: ['nome', 'email'] }],
});
```

---

## 5.7 Substituindo o Repository em Memória

O benefício central do Repository Pattern — demonstrado no Capítulo 4 — materializa-se agora: basta criar novas implementações do repositório, uma para Prisma e outra para Sequelize, sem alterar uma linha do `UsuariosService`.

### 5.7.1 UsuariosRepositoryPrisma

```javascript
// src/repositories/usuarios.repository.prisma.js
import { prisma } from '../config/database.js';

export class UsuariosRepositoryPrisma {

  async listarTodos() {
    return prisma.usuario.findMany({
      orderBy: { criadoEm: 'desc' },
    });
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

### 5.7.2 UsuariosRepositorySequelize

```javascript
// src/repositories/usuarios.repository.sequelize.js
import { Usuario } from '../models/usuario.model.js';

export class UsuariosRepositorySequelize {

  async listarTodos() {
    return Usuario.findAll({ order: [['createdAt', 'DESC']] });
  }

  async buscarPorId(id) {
    return Usuario.findByPk(id);
  }

  async buscarPorEmail(email) {
    return Usuario.findOne({ where: { email } });
  }

  async criar(dados) {
    return Usuario.create(dados);
  }

  async atualizar(id, dados) {
    const usuario = await Usuario.findByPk(id);
    if (!usuario) return null;
    return usuario.update(dados);
  }

  async remover(id) {
    const usuario = await Usuario.findByPk(id);
    if (!usuario) return false;
    await usuario.destroy();
    return true;
  }
}
```

### 5.7.3 Trocando a implementação no Composition Root

Para alternar entre as implementações, basta mudar uma linha no arquivo de rotas — o service e o controller não são tocados:

```javascript
// src/routes/usuarios.routes.js
import { Router } from 'express';

// ── Escolha a implementação aqui ──────────────────────
// import { UsuariosRepository }           from '../repositories/usuarios.repository.js';
// import { UsuariosRepositorySequelize }  from '../repositories/usuarios.repository.sequelize.js';
import { UsuariosRepositoryPrisma }     from '../repositories/usuarios.repository.prisma.js';
// ──────────────────────────────────────────────────────

import { UsuariosService }    from '../services/usuarios.service.js';
import { UsuariosController } from '../controllers/usuarios.controller.js';

const repository = new UsuariosRepositoryPrisma();   // ← única linha que muda
const service    = new UsuariosService(repository);
const controller = new UsuariosController(service);

const router = Router();
router.get('/',       controller.listarTodos);
router.get('/:id',    controller.buscarPorId);
router.post('/',      controller.criar);
router.put('/:id',    controller.atualizar);
router.delete('/:id', controller.remover);

export default router;
```

Esta é a prova concreta do valor do Repository Pattern: quatro capítulos de construção arquitetural resultam em uma troca de implementação de banco de dados que afeta exatamente **uma linha** de código.

---

## 5.8 Persistindo Relacionamentos: 1:N, N:1 e N:M

Os relacionamentos entre entidades são um dos pontos em que os ORMs entregam mais valor em relação ao SQL puro. Esta seção consolida os padrões de relacionamento para Prisma e Sequelize lado a lado, usando o domínio `Usuario → Post → Tag` como fio condutor.

### 5.8.1 Relacionamento 1:N e N:1 (Um para Muitos / Muitos para Um)

Um **relacionamento 1:N** existe quando um registro de uma tabela pode se associar a muitos registros de outra. No domínio do curso, um `Usuario` tem muitos `Post`s; inversamente, cada `Post` pertence a um único `Usuario` — esse lado inverso é o **N:1**.

**Schema Prisma:**

```prisma
model Usuario {
  id    Int    @id @default(autoincrement())
  nome  String
  posts Post[]          // lado "1" — array de posts
}

model Post {
  id      Int     @id @default(autoincrement())
  titulo  String
  autor   Usuario @relation(fields: [autorId], references: [id], onDelete: Cascade)
  autorId Int     @map("autor_id")  // lado "N" — chave estrangeira
}
```

**Model Sequelize:**

```javascript
// Definição da associação (associations.js)
Usuario.hasMany(Post,   { foreignKey: 'autorId', as: 'posts'  });  // 1:N
Post.belongsTo(Usuario, { foreignKey: 'autorId', as: 'autor'  });  // N:1
```

**Consultas com Prisma:**

```javascript
// Buscar usuário com todos os seus posts (1:N)
const usuario = await prisma.usuario.findUnique({
  where:   { id: 1 },
  include: { posts: { orderBy: { criadoEm: 'desc' } } },
});

// Buscar post com o autor (N:1)
const post = await prisma.post.findUnique({
  where:   { id: 1 },
  include: { autor: { select: { id: true, nome: true } } },
});

// Criar post já vinculado ao autor existente
await prisma.post.create({
  data: {
    titulo:  'Novo post',
    autor:   { connect: { id: 1 } },
  },
});
```

**Consultas com Sequelize:**

```javascript
import { Usuario } from '../models/usuario.model.js';
import { Post }    from '../models/post.model.js';
import '../models/associations.js';

// Buscar usuário com posts (1:N)
const usuario = await Usuario.findByPk(1, {
  include: [{ model: Post, as: 'posts', order: [['createdAt', 'DESC']] }],
});

// Buscar post com autor (N:1)
const post = await Post.findByPk(1, {
  include: [{ model: Usuario, as: 'autor', attributes: ['id', 'nome'] }],
});

// Criar post via método de instância
const u = await Usuario.findByPk(1);
await u.createPost({ titulo: 'Novo post' });
```

### 5.8.2 Relacionamento N:M (Muitos para Muitos)

Um **relacionamento N:M** existe quando muitos registros de uma tabela podem se associar a muitos registros de outra — e vice-versa. O exemplo clássico é `Post` ↔ `Tag`: um post tem muitas tags, e uma tag aparece em muitos posts. Esse relacionamento exige uma **tabela de junção** intermediária (`post_tags`).

**Schema Prisma — N:M implícito (Prisma gerencia a tabela de junção):**

```prisma
model Post {
  id   Int   @id @default(autoincrement())
  tags Tag[]
}

model Tag {
  id    Int    @id @default(autoincrement())
  nome  String @unique
  posts Post[]
}
// Prisma cria automaticamente a tabela _PostToTag
```

**Schema Prisma — N:M explícito (tabela de junção com campos extras):**

```prisma
model Post {
  id       Int       @id @default(autoincrement())
  postTags PostTag[]
}

model Tag {
  id       Int       @id @default(autoincrement())
  nome     String    @unique
  postTags PostTag[]
}

// Tabela de junção explícita — permite campos adicionais
model PostTag {
  postId    Int      @map("post_id")
  tagId     Int      @map("tag_id")
  atribuido DateTime @default(now())

  post Post @relation(fields: [postId], references: [id])
  tag  Tag  @relation(fields: [tagId],  references: [id])

  @@id([postId, tagId])
  @@map("post_tags")
}
```

**Consultas N:M com Prisma:**

```javascript
// Criar post e conectar tags existentes (ou criar novas)
const post = await prisma.post.create({
  data: {
    titulo: 'Post com tags',
    tags: {
      connectOrCreate: [
        { where: { nome: 'nodejs'  }, create: { nome: 'nodejs'  } },
        { where: { nome: 'backend' }, create: { nome: 'backend' } },
      ],
    },
  },
  include: { tags: true },
});

// Buscar todos os posts de uma tag
const postsNodejs = await prisma.tag.findUnique({
  where:   { nome: 'nodejs' },
  include: { posts: true },
});

// Adicionar tag a post existente
await prisma.post.update({
  where: { id: 1 },
  data:  { tags: { connect: { nome: 'prisma' } } },
});

// Remover tag de post
await prisma.post.update({
  where: { id: 1 },
  data:  { tags: { disconnect: { nome: 'prisma' } } },
});
```

**Associação e consultas N:M com Sequelize:**

```javascript
// associations.js
Post.belongsToMany(Tag, { through: 'post_tags', as: 'tags'  });
Tag.belongsToMany(Post, { through: 'post_tags', as: 'posts' });
```

```javascript
// Buscar post com suas tags
const post = await Post.findByPk(1, {
  include: [{ model: Tag, as: 'tags' }],
});

// Adicionar tags a um post
const p = await Post.findByPk(1);
const tag = await Tag.findOne({ where: { nome: 'nodejs' } });
await p.addTag(tag);          // método gerado automaticamente pela associação

// Definir tags (substitui todas as anteriores)
const tags = await Tag.findAll({ where: { nome: ['nodejs', 'backend'] } });
await p.setTags(tags);

// Remover uma tag
await p.removeTag(tag);
```

### 5.8.3 Boas práticas com relacionamentos

**`onDelete` e `onUpdate`:** defina o comportamento ao deletar ou atualizar o registro pai. `Cascade` remove os filhos automaticamente; `Restrict` impede a remoção do pai enquanto houver filhos; `SetNull` atribui `NULL` à chave estrangeira dos filhos.

**Evite o problema N+1:** buscar um usuário e depois fazer um `findMany` de posts para cada usuário resulta em N+1 queries. Use sempre `include` / `eager loading` para trazer os dados relacionados em uma única query com JOIN.

**`select` parcial em includes:** nunca faça `include: { autor: true }` quando só precisa do nome. Use `include: { autor: { select: { nome: true } } }` para evitar trazer campos desnecessários (especialmente `senha`).

---

## 5.9 Filtros, Ordenação e Paginação

Qualquer API REST de produção precisa suportar filtragem, ordenação e paginação nos endpoints de listagem. Esta seção apresenta as APIs de Prisma e Sequelize para esses casos de uso, cobrindo desde os casos mais simples até combinações avançadas.

### 5.9.1 Filtros com Prisma

O Prisma usa a chave `where` com operadores de comparação nativos:

```javascript
import { prisma } from '../config/database.js';

// Igualdade simples
const usuarios = await prisma.usuario.findMany({
  where: { ativo: true },
});

// Comparações numéricas e de data
const recentes = await prisma.post.findMany({
  where: {
    criadoEm: { gte: new Date('2025-01-01') }, // >=
    visualizacoes: { gt: 100 },                  // >
  },
});

// Busca textual (LIKE)
const resultado = await prisma.usuario.findMany({
  where: {
    nome: { contains: 'silva', mode: 'insensitive' }, // ILIKE '%silva%'
  },
});

// Operadores lógicos AND, OR, NOT
const filtrado = await prisma.post.findMany({
  where: {
    AND: [
      { publicado: true },
      { OR: [
        { titulo:   { contains: 'node' } },
        { conteudo: { contains: 'node' } },
      ]},
    ],
    NOT: { autorId: 99 },
  },
});

// Filtro por campo de relacionamento (JOIN implícito)
const postsDeAna = await prisma.post.findMany({
  where: { autor: { nome: { contains: 'Ana' } } },
});
```

### 5.9.2 Filtros com Sequelize

O Sequelize usa a chave `where` com operadores importados de `sequelize`:

```javascript
import { Op } from 'sequelize';
import { Usuario } from '../models/usuario.model.js';

// Igualdade simples
const ativos = await Usuario.findAll({ where: { ativo: true } });

// Comparações
const recentes = await Post.findAll({
  where: {
    createdAt:      { [Op.gte]: new Date('2025-01-01') },
    visualizacoes:  { [Op.gt]: 100 },
  },
});

// Busca textual (LIKE / ILIKE)
const resultado = await Usuario.findAll({
  where: {
    nome: { [Op.iLike]: '%silva%' },  // case-insensitive (PostgreSQL)
  },
});

// Operadores lógicos
const filtrado = await Post.findAll({
  where: {
    [Op.and]: [
      { publicado: true },
      { [Op.or]: [
        { titulo:   { [Op.like]: '%node%' } },
        { conteudo: { [Op.like]: '%node%' } },
      ]},
    ],
    autorId: { [Op.ne]: 99 }, // != 99
  },
});

// IN — buscar por lista de valores
const selecionados = await Usuario.findAll({
  where: { id: { [Op.in]: [1, 2, 3] } },
});
```

### 5.9.3 Ordenação

**Prisma:**

```javascript
// Ordenação simples
const posts = await prisma.post.findMany({
  orderBy: { criadoEm: 'desc' },
});

// Múltiplos critérios de ordenação
const usuarios = await prisma.usuario.findMany({
  orderBy: [
    { nome:     'asc'  },
    { criadoEm: 'desc' },
  ],
});

// Ordenar por campo de relacionamento
const posts2 = await prisma.post.findMany({
  orderBy: { autor: { nome: 'asc' } },
});
```

**Sequelize:**

```javascript
// Ordenação simples
const posts = await Post.findAll({
  order: [['createdAt', 'DESC']],
});

// Múltiplos critérios
const usuarios = await Usuario.findAll({
  order: [
    ['nome',      'ASC' ],
    ['createdAt', 'DESC'],
  ],
});

// Ordenar por campo de relacionamento (com include)
import '../models/associations.js';
const posts2 = await Post.findAll({
  include: [{ model: Usuario, as: 'autor' }],
  order:   [[{ model: Usuario, as: 'autor' }, 'nome', 'ASC']],
});
```

### 5.9.4 Paginação

A paginação baseada em **offset** é a mais comum em APIs REST: o cliente envia `pagina` e `por_pagina`, e o servidor retorna a fatia correspondente.

**Função utilitária para calcular offset:**

```javascript
// src/utils/paginacao.js
export function calcularPaginacao(pagina = 1, porPagina = 10) {
  const paginaNum  = Math.max(1, Number(pagina));
  const limite     = Math.min(100, Math.max(1, Number(porPagina))); // máx 100
  const offset     = (paginaNum - 1) * limite;
  return { limite, offset, pagina: paginaNum };
}
```

**Paginação com Prisma:**

```javascript
import { calcularPaginacao } from '../utils/paginacao.js';

// No repositório
async listarTodos({ pagina, porPagina } = {}) {
  const { limite, offset } = calcularPaginacao(pagina, porPagina);

  const [dados, total] = await Promise.all([
    prisma.usuario.findMany({
      skip:    offset,
      take:    limite,
      orderBy: { criadoEm: 'desc' },
    }),
    prisma.usuario.count(),
  ]);

  return {
    dados,
    paginacao: {
      total,
      pagina:    calcularPaginacao(pagina, porPagina).pagina,
      porPagina: limite,
      paginas:   Math.ceil(total / limite),
    },
  };
}
```

**Paginação com Sequelize:**

```javascript
async listarTodos({ pagina, porPagina } = {}) {
  const { limite, offset } = calcularPaginacao(pagina, porPagina);

  const { count: total, rows: dados } = await Usuario.findAndCountAll({
    limit:  limite,
    offset: offset,
    order:  [['createdAt', 'DESC']],
  });

  return {
    dados,
    paginacao: {
      total,
      pagina:    calcularPaginacao(pagina, porPagina).pagina,
      porPagina: limite,
      paginas:   Math.ceil(total / limite),
    },
  };
}
```

**Controller e rota correspondente:**

```javascript
// No controller
async listarTodos(req, res, next) {
  try {
    const { pagina, por_pagina } = req.query;
    const resultado = await this.service.listarTodos({
      pagina,
      porPagina: por_pagina,
    });
    res.json(resultado);
  } catch (err) { next(err); }
}
```

```bash
# Exemplos de uso
GET /api/usuarios?pagina=1&por_pagina=10
GET /api/usuarios?pagina=2&por_pagina=20
```

O objeto de resposta retornado inclui tanto os dados quanto os metadados de paginação, padrão amplamente adotado em APIs REST:

```json
{
  "dados": [...],
  "paginacao": {
    "total": 87,
    "pagina": 2,
    "porPagina": 20,
    "paginas": 5
  }
}
```


---

## 5.10 Comparativo Final: Prisma vs. Sequelize

Após explorar ambos os ORMs em profundidade, é possível traçar um comparativo mais detalhado para orientar a escolha em projetos reais:

**Schema e migrations:** o Prisma adota uma abordagem *schema-first* — o arquivo `schema.prisma` é a única fonte de verdade, e as migrations são geradas automaticamente. O Sequelize adota uma abordagem *code-first* com migrations manuais, o que oferece mais controle mas exige mais disciplina.

**Experiência de desenvolvimento:** o Prisma Client oferece autocompletar rico e verificação de tipos em tempo de compilação, o que reduz erros e melhora a produtividade especialmente em editores como VS Code. O Sequelize também suporta TypeScript, mas a inferência de tipos é menos precisa para consultas complexas.

**Consultas complexas:** ambos suportam SQL bruto para casos que escapam da API de alto nível. O Sequelize oferece mais opções nativas para consultas agregadas; o Prisma é mais opinativo, o que resulta em uma API mais consistente mas ocasionalmente menos flexível.

**Adoção em projetos existentes:** o Sequelize é encontrado em projetos Node.js desde 2011 e tem presença massiva em bases de código legadas. Saber trabalhar com ele é uma habilidade profissional relevante. O Prisma, por ser mais recente, é encontrado em projetos modernos que valorizam produtividade e tipagem.

A recomendação para este curso é usar **Prisma** como ORM principal nos exercícios e no projeto final, por sua menor curva de aprendizado e melhor experiência de desenvolvimento. O Sequelize é apresentado como referência para que o estudante esteja preparado para encontrá-lo em ambientes de trabalho reais.

---

---

## 5.11 Bancos de Dados Não Relacionais

Até este ponto, todo o material trabalhou exclusivamente com bancos relacionais. No entanto, o ecossistema de persistência de dados é mais amplo: os **bancos de dados não relacionais** (também chamados de *NoSQL*) representam uma família de sistemas de armazenamento que abandonam o modelo de tabelas e SQL em favor de outros paradigmas de organização dos dados. Conhecê-los é essencial para escolher a ferramenta certa para cada problema.

### 5.11.1 Por que existem bancos NoSQL?

Os bancos relacionais foram concebidos em uma era em que a consistência e a integridade dos dados eram as prioridades absolutas. Com a explosão da Web nos anos 2000, surgiram requisitos novos: volumes de dados na ordem de petabytes, leituras e escritas em milhões por segundo, esquemas que mudam frequentemente e dados naturalmente hierárquicos (documentos JSON, grafos de amigos, séries temporais de sensores). Os bancos relacionais, otimizados para consistência e joins, mostram limitações de escala e flexibilidade nesses cenários — o que impulsionou o surgimento dos bancos NoSQL.

O termo *NoSQL* não significa "sem SQL" mas sim "Not Only SQL": muitos desses bancos oferecem uma linguagem de consulta própria, e alguns até suportam um subconjunto de SQL.

### 5.11.2 Principais categorias

**Bancos de documentos** armazenam dados como documentos semi-estruturados, geralmente em formato JSON ou BSON. Cada documento pode ter um esquema diferente dos demais — não há necessidade de definir colunas com antecedência. O **MongoDB** é o representante mais popular desta categoria, amplamente utilizado com Node.js através do driver nativo ou do ODM *Mongoose*. São especialmente adequados para catálogos de produtos com atributos variáveis, perfis de usuário e conteúdo de CMS.

**Bancos chave-valor** armazenam pares chave → valor, análogos a um `Map` gigante e persistente. O **Redis** é o representante dominante: além de persistência, oferece estruturas de dados avançadas (listas, sets, hashes) e operações atômicas. É amplamente utilizado como **cache** (armazenar resultados de queries caras), **sessões** (armazenar tokens JWT ou dados de sessão) e **filas** (pub/sub para comunicação entre serviços).

**Bancos de colunas largas** (*wide column*) armazenam dados em famílias de colunas, otimizados para escritas massivas e leituras por chave em escala de petabytes. O **Apache Cassandra** e o **Google Bigtable** são os representantes mais conhecidos. São utilizados em sistemas de monitoramento, dados de IoT e histórico de eventos em larga escala.

**Bancos de grafos** modelam os dados como nós e arestas, tornando triviais consultas que envolvem múltiplos relacionamentos (como "amigos de amigos", recomendações ou detecção de fraude). O **Neo4j** é o banco de grafos mais utilizado. Consultas que exigiriam múltiplos JOINs em SQL são expressas naturalmente em *Cypher*, a linguagem de consulta do Neo4j.

### 5.11.3 Comparativo: SQL vs. NoSQL

| Aspecto | Bancos Relacionais | Bancos NoSQL |
|---|---|---|
| Estrutura | Tabelas fixas com schema | Flexível (documento, chave-valor, grafo…) |
| Consistência | ACID por padrão | Eventual ou configurável (BASE) |
| Escala | Vertical (scale-up) | Horizontal (scale-out) nativa |
| Consultas | SQL poderoso (JOINs, agregações) | API específica de cada banco |
| Relacionamentos | Nativos (chaves estrangeiras) | Embutidos no documento ou gerenciados na aplicação |
| Casos de uso | Sistemas financeiros, ERPs, APIs REST | Redes sociais, IoT, cache, dados de log |

### 5.11.4 MongoDB e Mongoose com Node.js

O MongoDB merece destaque por ser o banco NoSQL mais utilizado em conjunto com Node.js e Express. O **Mongoose** é o ODM (*Object Document Mapper*) que fornece uma camada de abstração semelhante ao que os ORMs oferecem para bancos relacionais.

```bash
npm install mongoose
```

```javascript
// src/config/database.js (MongoDB)
import mongoose from 'mongoose';

export async function conectarMongoDB() {
  await mongoose.connect(process.env.MONGODB_URL);
  console.log('MongoDB conectado');
}
```

**Definição de schema e model no Mongoose:**

```javascript
// src/models/usuario.model.js
import mongoose from 'mongoose';

const usuarioSchema = new mongoose.Schema(
  {
    nome:  { type: String, required: true },
    email: { type: String, required: true, unique: true, lowercase: true },
    senha: { type: String, required: true },
    ativo: { type: Boolean, default: true },
  },
  { timestamps: true }  // createdAt e updatedAt automáticos
);

export const Usuario = mongoose.model('Usuario', usuarioSchema);
```

**CRUD com Mongoose:**

```javascript
import { Usuario } from '../models/usuario.model.js';

// CREATE
const novo = await Usuario.create({ nome: 'Ana', email: 'ana@ex.com', senha: 'hash' });

// READ
const todos     = await Usuario.find();
const porEmail  = await Usuario.findOne({ email: 'ana@ex.com' });
const porId     = await Usuario.findById('64a1f...');

// UPDATE
const atualizado = await Usuario.findByIdAndUpdate(
  '64a1f...',
  { nome: 'Ana Lima' },
  { new: true }   // retorna o documento já atualizado
);

// DELETE
await Usuario.findByIdAndDelete('64a1f...');
```

O Repository Pattern funciona com Mongoose da mesma forma que com Prisma e Sequelize — basta implementar a mesma interface de contrato.

### 5.11.5 Redis como cache em APIs Express

O **Redis** merece menção especial no contexto de APIs Express por ser uma ferramenta transversal: não substitui o banco principal, mas complementa-o atuando como camada de cache de alta velocidade.

```bash
npm install ioredis
```

```javascript
// src/config/cache.js
import Redis from 'ioredis';

export const redis = new Redis(process.env.REDIS_URL);
```

**Padrão cache-aside em um service:**

```javascript
async buscarPorId(id) {
  const chave = `usuario:${id}`;

  // 1. Tentar o cache primeiro
  const cached = await redis.get(chave);
  if (cached) return JSON.parse(cached);

  // 2. Cache miss — buscar no banco
  const usuario = await this.repository.buscarPorId(id);
  if (!usuario) throw new AppError('Usuário não encontrado', 404);

  // 3. Salvar no cache por 5 minutos (TTL = 300 segundos)
  await redis.set(chave, JSON.stringify(usuario), 'EX', 300);
  return usuario;
}
```

Esse padrão reduz drasticamente a carga sobre o banco de dados para recursos consultados com frequência (perfis de usuário, configurações, listas de categorias), sem sacrificar a consistência — a entrada do cache expira automaticamente após o TTL configurado.

### 5.11.6 Quando usar cada paradigma

A escolha do banco de dados deve ser guiada pelos requisitos do domínio, não por tendências tecnológicas. Como regra geral: use bancos relacionais (PostgreSQL, SQLite) como padrão — eles resolvem bem 90% dos casos de uso em APIs REST. Complemente com Redis para cache, sessões ou filas. Avalie MongoDB quando os dados forem naturalmente hierárquicos, o esquema mudar frequentemente, ou a escala de escrita exigir flexibilidade. Reserve Cassandra e Neo4j para casos de uso muito específicos que justifiquem a complexidade operacional adicional.


## 5.12 Exercícios Práticos

### Exercício 5.1 — Schema Prisma com relacionamento

Crie um schema Prisma com três models: `Usuario`, `Post` e `Categoria`. Um usuário tem muitos posts; um post pertence a uma categoria. Defina os campos apropriados, execute `prisma migrate dev` e verifique o schema gerado no banco com `prisma studio`.

### Exercício 5.2 — CRUD com Prisma

Implemente o `UsuariosRepositoryPrisma` completo e substitua o repositório em memória no projeto do Capítulo 4. Verifique que todos os endpoints de `GET /usuarios`, `POST /usuarios`, `PUT /usuarios/:id` e `DELETE /usuarios/:id` funcionam corretamente com o banco real. Use o SQLite para simplificar o ambiente.

### Exercício 5.3 — CRUD com Sequelize

Repita o exercício anterior usando `UsuariosRepositorySequelize`. Observe que o `UsuariosService` não precisa de qualquer modificação — apenas o repositório muda no composition root.

### Exercício 5.4 — Relacionamento com include

Adicione um model `Post` ao projeto (Prisma ou Sequelize, à sua escolha) com os campos `id`, `titulo`, `conteudo` e `autorId`. Implemente um endpoint `GET /usuarios/:id/posts` que retorna todos os posts de um usuário, utilizando `include` para trazer o nome do autor junto a cada post.

### Exercício 5.5 — Paginação

Implemente paginação no endpoint `GET /usuarios`, aceitando os query params `pagina` (número da página, padrão 1) e `por_pagina` (itens por página, padrão 10). Use `skip`/`take` no Prisma ou `offset`/`limit` no Sequelize para implementar a lógica no repositório.

---

## 5.13 Referências e Leituras Complementares

- [Documentação oficial do Prisma](https://www.prisma.io/docs)
- [Documentação oficial do Sequelize](https://sequelize.org/docs/v6/)
- [Prisma vs. Sequelize — comparativo oficial](https://www.prisma.io/docs/concepts/more/comparisons/prisma-and-sequelize)
- [PostgreSQL — documentação oficial](https://www.postgresql.org/docs/)
- [Prisma Schema Reference](https://www.prisma.io/docs/reference/api-reference/prisma-schema-reference)
- 📖 Elmasri, R.; Navathe, S. B. *Sistemas de Banco de Dados*. 7ª ed. Pearson, 2018. — Capítulos 1–3 (fundamentos relacionais).

---

!!! note "Próximo Capítulo"
    No **Capítulo 6 — Autenticação e Autorização**, integraremos o banco de dados real ao fluxo de login: hash de senha com bcrypt, geração e validação de JWT, e middlewares de proteção de rotas. O `UsuariosRepositoryPrisma` construído neste capítulo será a base para o sistema de autenticação.
