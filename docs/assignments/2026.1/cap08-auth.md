# Atividade 11 — Delivery Tracker: Autenticação e Autorização com JWT

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 8 — Autenticação e Autorização  
**Modalidade:** Em sala  
**Carga horária estimada:** 4h  

---

## Contexto do Problema

O sistema foi exposto publicamente como parte de um piloto e, em menos de 24 horas, registros fictícios foram criados por usuários não autorizados e entregas reais foram canceladas indevidamente. O cliente exige que apenas usuários autenticados possam operar o sistema, e que operadores de campo não possam cancelar entregas — essa ação deve ser restrita a gestores.

> **Pré-requisito:** Atividades 08 e 10 concluídas (Prisma ORM, API REST e frontend Vue básico).

---

## Objetivos de Aprendizagem

- Compreender a diferença conceitual entre autenticação e autorização
- Implementar hash de senha com bcrypt (custo ≥ 10)
- Gerar e validar JSON Web Tokens
- Escrever middleware de autenticação como camada transversal
- Implementar RBAC com middleware parametrizável `autorizar(...papeis)`
- Proteger rotas no Vue Router com navigation guards

---

## Requisitos Funcionais

### RF-01 — Cadastro e Login

- `POST /api/auth/registrar` deve criar usuário com `nome`, `email` e `senha`
  - A senha deve ser armazenada como hash bcrypt com custo mínimo de **10**
  - O email deve ser único; duplicata retorna **409**
  - O papel (`papel`) padrão é `OPERADOR`
- `POST /api/auth/login` deve validar credenciais e retornar um `accessToken` JWT
  - O payload do token deve conter: `id`, `nome`, `email`, `papel`
  - O token **não deve conter** `senhaHash` nem qualquer dado sensível
  - A expiração deve ser configurada pela variável de ambiente `JWT_EXPIRES_IN` (padrão: `8h`)

### RF-02 — Middleware de Autenticação

- O middleware `autenticar` deve ser aplicado nas rotas, **não** nos controllers
- Comportamentos obrigatórios:
  - Token ausente → **401** `{ erro: "Token não fornecido" }`
  - Token inválido ou malformado → **401** `{ erro: "Token inválido" }`
  - Token expirado → **401** `{ erro: "Token expirado" }`
  - Token válido → injeta `req.usuario` com os dados do payload e chama `next()`
- O middleware **não deve conter lógica de negócio** — apenas extração, validação e injeção

### RF-03 — Papéis e Autorização (RBAC)

- O model `Usuario` deve ter campo `papel` com valores `OPERADOR` e `GESTOR`
- Deve existir um middleware `autorizar(...papeis)` parametrizável aplicado nas rotas
- Usuário sem papel suficiente → **403** `{ erro: "Acesso negado" }`
- Distribuição de permissões:
  - `PATCH /api/entregas/:id/cancelar` → apenas `GESTOR`
  - `GET /api/relatorios/*` → apenas `GESTOR`
  - `POST /api/motoristas`, `PATCH /api/motoristas/:id` → apenas `GESTOR`
  - Demais rotas → qualquer usuário autenticado

### RF-04 — Registro do Criador

- Ao criar uma entrega, o `id` do usuário autenticado deve ser registrado como `criadorId`
- O campo `criadorId` deve aparecer na resposta de `GET /api/entregas/:id`

### RF-05 — Integração com o Frontend Vue

- O frontend Vue deve armazenar o token em `localStorage`
- O Axios deve enviar o token no header `Authorization: Bearer <token>` em todas as requisições (via interceptor)
- Rotas Vue que exigem autenticação devem usar navigation guard para redirecionar para `/login` quando não há token

---

## Variáveis de Ambiente

```
JWT_SECRET=chave_secreta_minimo_32_caracteres
JWT_EXPIRES_IN=8h
```

---

## Restrição de Avaliação

> ⚠️ **O middleware `autenticar` não pode conter lógica de negócio.** Deve apenas extrair, validar e injetar. Qualquer `if` de domínio encontrado no middleware será penalizado. O middleware `autorizar` **não pode fazer consultas ao banco** — deve trabalhar apenas com `req.usuario.papel`.

---

## Cenários de Teste Esperados

1. `POST /api/auth/registrar` com dados válidos → **201**
2. `POST /api/auth/registrar` com email duplicado → **409**
3. `POST /api/auth/login` com senha correta → token JWT
4. `GET /api/entregas` sem token → **401** `"Token não fornecido"`
5. `GET /api/entregas` com token expirado → **401** `"Token expirado"`
6. `GET /api/entregas` com token válido → **200**
7. `PATCH /api/entregas/:id/cancelar` com usuário `OPERADOR` → **403**
8. `PATCH /api/entregas/:id/cancelar` com usuário `GESTOR` → sucesso
9. Decodificar o token em [jwt.io](https://jwt.io) → `senhaHash` não deve estar presente

---

## Entregável

- Backend com autenticação, autorização e model `Usuario` no Prisma
- Frontend Vue com interceptor Axios e navigation guards
- Migration do Prisma para o model `Usuario`

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: Hash bcrypt custo ≥ 10 e unicidade de email | 15% | Verificar custo no código; testar duplicata |
| RF-01: Payload JWT sem dados sensíveis | 10% | Decodificar em jwt.io e inspecionar campos |
| RF-02: Middleware distingue token ausente / inválido / expirado | 20% | Testar os 3 cenários com mensagens distintas |
| RF-02: Todas as rotas protegidas (sem exceções) | 10% | Testar `GET /api/motoristas` e `/api/relatorios` sem token |
| RF-02: Middleware sem lógica de negócio | 10% | Inspeção de código |
| RF-03: Middleware `autorizar` parametrizável sem consulta ao banco | 15% | Inspecionar código — `await` no middleware = penalização |
| RF-03: Distribuição de permissões correta em todas as rotas | 10% | Testar cada rota restrita com `OPERADOR` |
| RF-04: `criadorId` registrado e retornado | 5% | |
| RF-05: Interceptor Axios e navigation guard no Vue | 5% | |

**Total: 100%**

## Procedimento para Testar Expiração

Definir `JWT_EXPIRES_IN=5s` no `.env`, fazer login, aguardar 6 segundos e tentar usar o token. Deve retornar **401** com mensagem `"Token expirado"`.

## Pontos de Atenção

- `bcrypt.compare` é assíncrono — verificar uso correto de `await`.
- O erro `JsonWebTokenError` do pacote `jsonwebtoken` corresponde a token inválido/malformado; `TokenExpiredError` corresponde a token expirado. Os dois casos devem retornar mensagens **distintas**.
- Navigation guard no Vue: verificar se redireciona para `/login` quando `localStorage.getItem('token')` é nulo **e** quando o token está expirado (decodificar no cliente com `jwt-decode` para verificar `exp`).
