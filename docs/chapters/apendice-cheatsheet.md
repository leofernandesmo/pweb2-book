# Apêndice A — Cheatsheet

Referência rápida dos principais padrões, sintaxes e configurações abordados ao longo do semestre. Organizado por tema para consulta pontual durante o desenvolvimento.

---

## A.1 Node.js & NPM

```bash
# Inicializar projeto
npm init -y

# Instalar dependência de produção
npm install express

# Instalar dependência de desenvolvimento
npm install --save-dev jest

# Executar script definido no package.json
npm run dev

# Listar dependências instaladas
npm list --depth=0
```

```json
// package.json — configurações essenciais
{
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "dev": "node --watch server.js",
    "test": "node --experimental-vm-modules node_modules/.bin/jest"
  }
}
```

```javascript
// Importação de módulos (ESM)
import express from 'express';
import { Router } from 'express';
import { readFile } from 'fs/promises';

// Importação de arquivo local
import { UsuariosService } from './services/usuarios.service.js';

// __dirname equivalente em ESM
import { fileURLToPath } from 'url';
import path from 'path';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
```

---

## A.2 Express — Fundamentos

```javascript
import express from 'express';
const app = express();

// Middlewares globais essenciais
app.use(express.json());                         // Parsing de JSON no body
app.use(express.urlencoded({ extended: true })); // Parsing de form data

// Iniciar servidor
app.listen(3000, () => console.log('Rodando na porta 3000'));
```

---

## A.3 Rotas

```javascript
// Verbos HTTP
app.get('/recursos', handler);
app.post('/recursos', handler);
app.put('/recursos/:id', handler);
app.patch('/recursos/:id', handler);
app.delete('/recursos/:id', handler);

// Parâmetros de rota
req.params.id           // GET /usuarios/42  →  "42"

// Query params
req.query.pagina        // GET /usuarios?pagina=2  →  "2"
Number(req.query.pagina) // Conversão para número

// Corpo da requisição
req.body.nome           // POST com { "nome": "Ana" }

// Cabeçalhos
req.headers['authorization']

// Router modular
const router = Router();
router.get('/', handler);
router.get('/:id', handler);
export default router;

// Montar router
app.use('/usuarios', usuariosRouter);
```

---

## A.4 Middlewares

```javascript
// Estrutura básica
(req, res, next) => {
  // lógica
  next(); // OBRIGATÓRIO se não enviar resposta
}

// Middleware de erro (4 parâmetros)
(err, req, res, next) => {
  res.status(err.statusCode || 500).json({ erro: err.message });
}

// Aplicação global
app.use(meuMiddleware);

// Aplicação em rota específica
app.get('/rota', middleware1, middleware2, handler);

// Middlewares de terceiros
app.use(helmet());
app.use(cors({ origin: 'https://meuapp.com' }));
app.use(morgan('dev'));
app.use(compression());
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
```

```javascript
// asyncHandler — evita try/catch repetitivo
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Uso
router.get('/', asyncHandler(async (req, res) => {
  const dados = await servico.listar();
  res.json(dados);
}));
```

---

## A.5 Respostas HTTP

```javascript
res.json({ chave: 'valor' })       // 200 + JSON
res.status(201).json(novoRecurso)  // 201 Created
res.status(204).send()             // 204 No Content
res.status(400).json({ erro: '' }) // 400 Bad Request
res.status(401).json({ erro: '' }) // 401 Unauthorized
res.status(403).json({ erro: '' }) // 403 Forbidden
res.status(404).json({ erro: '' }) // 404 Not Found
res.status(500).json({ erro: '' }) // 500 Internal Server Error
```

---

## A.6 AppError — Erro customizado

```javascript
// src/utils/AppError.js
export class AppError extends Error {
  constructor(mensagem, statusCode = 500) {
    super(mensagem);
    this.statusCode = statusCode;
  }
}

// Lançar erro em qualquer camada
throw new AppError('Recurso não encontrado', 404);

// Middleware de erros captura automaticamente
app.use((err, req, res, next) => {
  if (err instanceof AppError)
    return res.status(err.statusCode).json({ erro: err.message });
  res.status(500).json({ erro: 'Erro interno do servidor' });
});
```

---

## A.7 Autenticação JWT

```bash
npm install jsonwebtoken bcrypt
```

```javascript
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';

// Hash de senha
const hash = await bcrypt.hash(senha, 10);
const valido = await bcrypt.compare(senhaDigitada, hash);

// Gerar token
const token = jwt.sign(
  { id: usuario.id, papel: usuario.papel }, // payload
  process.env.JWT_SECRET,                   // chave secreta
  { expiresIn: '1d' }                       // expiração
);

// Verificar token
const payload = jwt.verify(token, process.env.JWT_SECRET);

// Middleware de autenticação
export const autenticar = (req, res, next) => {
  const auth = req.headers['authorization'];
  if (!auth?.startsWith('Bearer '))
    return res.status(401).json({ erro: 'Token não fornecido' });
  try {
    req.usuario = jwt.verify(auth.split(' ')[1], process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ erro: 'Token inválido' });
  }
};
```

---

## A.8 ORM — Prisma

```bash
npm install prisma @prisma/client
npx prisma init
npx prisma migrate dev --name nome_da_migration
npx prisma generate
npx prisma studio                # Interface visual
```

```prisma
// prisma/schema.prisma
model Usuario {
  id        Int      @id @default(autoincrement())
  nome      String
  email     String   @unique
  senha     String
  criadoEm DateTime @default(now())
  posts     Post[]
}
```

```javascript
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

// CRUD
const todos    = await prisma.usuario.findMany();
const um       = await prisma.usuario.findUnique({ where: { id } });
const criado   = await prisma.usuario.create({ data: { nome, email, senha } });
const atualiz  = await prisma.usuario.update({ where: { id }, data: { nome } });
const removido = await prisma.usuario.delete({ where: { id } });

// Filtros e relações
await prisma.usuario.findMany({
  where: { nome: { contains: 'Ana' } },
  include: { posts: true },
  orderBy: { criadoEm: 'desc' },
  skip: 0,
  take: 10,
});
```

---

## A.9 ORM — Sequelize

```bash
npm install sequelize sequelize-cli pg pg-hstore
npx sequelize-cli init
npx sequelize-cli model:generate --name Usuario --attributes nome:string,email:string
npx sequelize-cli db:migrate
```

```javascript
import { DataTypes } from 'sequelize';

const Usuario = sequelize.define('Usuario', {
  nome:  { type: DataTypes.STRING, allowNull: false },
  email: { type: DataTypes.STRING, allowNull: false, unique: true },
  senha: { type: DataTypes.STRING, allowNull: false },
});

// CRUD
await Usuario.findAll();
await Usuario.findByPk(id);
await Usuario.create({ nome, email, senha });
await Usuario.update({ nome }, { where: { id } });
await Usuario.destroy({ where: { id } });
```

---

## A.10 Testes — Jest & Supertest

```bash
npm install --save-dev jest supertest @types/jest
```

```javascript
// Teste unitário de service
import { UsuariosService } from '../src/services/usuarios.service.js';

describe('UsuariosService', () => {
  it('deve lançar erro se email já existir', async () => {
    const service = new UsuariosService();
    await expect(service.criar({ email: 'existente@teste.com' }))
      .rejects.toThrow('E-mail já cadastrado');
  });
});
```

```javascript
// Teste de integração com Supertest
import request from 'supertest';
import app from '../src/app.js';

describe('GET /api/usuarios', () => {
  it('deve retornar 200 e lista de usuários', async () => {
    const res = await request(app).get('/api/usuarios');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('deve retornar 404 para usuário inexistente', async () => {
    const res = await request(app).get('/api/usuarios/99999');
    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('erro');
  });
});
```

```javascript
// Matchers mais usados
expect(valor).toBe(42)
expect(objeto).toEqual({ id: 1 })
expect(array).toHaveLength(3)
expect(objeto).toHaveProperty('nome')
expect(fn).toThrow('mensagem')
expect(fn).rejects.toThrow()
expect(fn).toHaveBeenCalledWith(arg)

// Mock de função
jest.fn()
jest.spyOn(objeto, 'metodo').mockResolvedValue(retorno)
```

---

## A.11 Variáveis de Ambiente & Deploy

```bash
# .env (nunca versionar)
PORT=3000
NODE_ENV=development
DATABASE_URL=postgresql://user:pass@localhost:5432/meubanco
JWT_SECRET=minha_chave_secreta_longa
CORS_ORIGIN=https://meuapp.com
```

```javascript
// src/config/env.js — carregamento e validação
import 'dotenv/config';

const obrigatorias = ['DATABASE_URL', 'JWT_SECRET'];
for (const variavel of obrigatorias) {
  if (!process.env[variavel])
    throw new Error(`Variável de ambiente ausente: ${variavel}`);
}

export const config = {
  porta:       process.env.PORT || 3000,
  nodeEnv:     process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret:   process.env.JWT_SECRET,
  corsOrigin:  process.env.CORS_ORIGIN || '*',
};
```

```bash
# Railway / Render — deploy via CLI
railway login
railway init
railway up

# Variáveis no serviço de deploy
railway variables set JWT_SECRET=valor

# Verificar logs em produção
railway logs
```

---

## A.12 Status HTTP — Referência Rápida

| Código | Nome | Uso típico |
|--------|------|------------|
| 200 | OK | GET, PUT, PATCH bem-sucedidos |
| 201 | Created | POST que criou um recurso |
| 204 | No Content | DELETE bem-sucedido |
| 400 | Bad Request | Dados de entrada inválidos |
| 401 | Unauthorized | Token ausente ou inválido |
| 403 | Forbidden | Token válido, mas sem permissão |
| 404 | Not Found | Recurso não encontrado |
| 409 | Conflict | Recurso já existe (e-mail duplicado) |
| 422 | Unprocessable Entity | Validação de negócio falhou |
| 429 | Too Many Requests | Rate limit atingido |
| 500 | Internal Server Error | Erro inesperado no servidor |
