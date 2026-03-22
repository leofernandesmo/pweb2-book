# Atividade 12 — Delivery Tracker: Testes Automatizados com Jest e Supertest

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 9 — Testes Automatizados: Jest, Supertest e Playwright  
**Modalidade:** Em sala / Casa  
**Carga horária estimada:** 5h  

---

## Contexto do Problema

O time precisa refatorar o `EntregasService` para suportar um novo requisito de negócio. Antes de qualquer alteração, o Tech Lead exige que toda a lógica existente esteja coberta por testes — nenhuma regressão pode passar despercebida. Para dificultar a tarefa de forma pedagógica: **o professor entrega uma versão do `EntregasService` com um bug deliberado introduzido em uma das regras de transição de estado.** O aluno deve escrever os testes, deixar que eles revelem o bug e documentar o achado.

> **Pré-requisito:** Atividade 11 concluída (autenticação JWT, Prisma, RBAC).

---

## Objetivos de Aprendizagem

- Compreender a pirâmide de testes e a responsabilidade de cada camada
- Escrever testes unitários de services com mocks de repository (sem banco)
- Escrever testes de integração de rotas HTTP com Supertest
- Testar mecanismos de autenticação e autorização
- Identificar e eliminar acoplamento entre testes (testes flaky)
- Calcular e interpretar cobertura de código com Jest

---

## Requisitos Funcionais

### RF-01 — Testes Unitários do `EntregasService`

- Arquivo: `tests/unit/EntregasService.test.js`
- O repository deve ser **mockado com `jest.fn()`** — nenhuma conexão com banco nos testes unitários
- Cobertura obrigatória:
  - Criação com validação de origem igual ao destino
  - Criação com entrega duplicada em aberto
  - Todas as transições de status **válidas**: `CRIADA → EM_TRANSITO`, `EM_TRANSITO → ENTREGUE`
  - Todas as transições de status **inválidas**: tentar avançar de `ENTREGUE`, tentar ir de `CRIADA` direto para `ENTREGUE`
  - Cancelamento permitido (`CRIADA`, `EM_TRANSITO`)
  - Cancelamento negado (`ENTREGUE`)
  - Geração de evento no histórico em cada operação relevante

### RF-02 — Testes Unitários do `MotoristasService`

- Arquivo: `tests/unit/MotoristasService.test.js`
- Cobertura obrigatória:
  - Criação com CPF duplicado
  - Atribuição a entrega com status inválido
  - Atribuição de motorista com status `INATIVO`

### RF-03 — Testes de Integração das Rotas

- Arquivo: `tests/integration/entregas.routes.test.js`
- Usar **Supertest** com a instância do `app` Express (sem chamar `app.listen`)
- O banco de dados nos testes de integração deve ser um banco **isolado** (`DATABASE_URL` no `.env.test`)
- Cobertura obrigatória:
  - `POST /api/entregas` autenticado → **201**
  - `POST /api/entregas` sem token → **401**
  - `GET /api/entregas?status=CRIADA` → filtragem correta
  - `PATCH /api/entregas/:id/avancar` com usuário `OPERADOR` → sucesso
  - `PATCH /api/entregas/:id/cancelar` com usuário `OPERADOR` → **403**
  - `PATCH /api/entregas/:id/cancelar` com usuário `GESTOR` → sucesso

### RF-04 — Testes de Autenticação

- Arquivo: `tests/integration/auth.routes.test.js`
- Cobertura obrigatória:
  - Registro com dados válidos → **201**
  - Registro com email duplicado → **409**
  - Login com senha correta → token JWT
  - Login com senha errada → **401**
  - Acesso com token expirado → **401** com mensagem `"Token expirado"`

### RF-05 — Diagnóstico e Correção do Bug

- O aluno deve identificar qual teste falha na versão com bug fornecida pelo professor
- Deve documentar no `README.md`:
  - Qual regra de negócio estava sendo violada
  - Qual teste evidenciou o bug (nome do arquivo e do `it()`)
  - Qual linha foi corrigida e por quê

### RF-06 — Qualidade da Suíte

- Nenhum teste deve depender da ordem de execução
- Nenhum teste deve compartilhar estado com outro (`beforeEach` deve limpar o estado)
- Mocks devem ser resetados entre testes (`jest.clearAllMocks()` ou equivalente)
- O banco de teste deve ser limpo antes de cada arquivo de integração (`beforeAll` com truncate ou `prisma.$transaction`)

---

## Estrutura Esperada

```
tests/
  unit/
    EntregasService.test.js
    MotoristasService.test.js
  integration/
    entregas.routes.test.js
    auth.routes.test.js
.env.test          ← DATABASE_URL apontando para banco de teste separado
jest.config.js
```

---

## Restrição de Avaliação

> ⚠️ **O professor fornece o arquivo `EntregasService.bugado.js` com um bug deliberado na validação de transição de status.** O aluno deve substituir o service original por este arquivo, executar `npm test` e identificar qual teste falhou. A documentação do bug no `README.md` é **obrigatória** e vale 15% da nota.

---

## Cenários de Teste Esperados

1. `npm test` executa toda a suíte sem erros de configuração
2. `npm test -- --coverage` reporta cobertura ≥ 80% em `src/services/`
3. Executar `npm test -- --runInBand` (sequencial) e `npm test` (paralelo) deve produzir o mesmo resultado
4. Trocar `EntregasService` pelo arquivo com bug → ao menos um teste deve falhar com mensagem descritiva

---

## Entregável

- Suíte de testes completa
- `.env.test` com banco separado
- `README.md` com documentação do bug identificado e corrigido

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: Testes unitários do `EntregasService` com mock (sem banco) | 25% | Verificar que nenhum `await prisma` ocorre nos testes unitários |
| RF-02: Testes unitários do `MotoristasService` | 10% | |
| RF-03: Testes de integração das rotas com Supertest | 20% | Verificar que `app.listen` não é chamado nos testes |
| RF-04: Testes de autenticação cobrindo token expirado | 15% | Usar `JWT_EXPIRES_IN=1s` no `.env.test` |
| RF-05: Documentação do bug no README | 15% | Nome do teste que falhou + linha corrigida |
| RF-06: Ausência de acoplamento entre testes | 10% | Rodar `--runInBand` e embaralhar ordem manualmente |
| `.env.test` com banco separado | 5% | |

**Total: 100%**

## Bug Sugerido para o Professor Introduzir

No método `avancarStatus()` do `EntregasService`, inverter a condição de guarda da transição `EM_TRANSITO → ENTREGUE`:

```js
// ❌ Versão com bug (entregar ao aluno)
if (entrega.status !== 'EM_TRANSITO') {
  // Esta condição está INVERTIDA — permite avançar de qualquer status exceto EM_TRANSITO
  throw new Error('...');
}

// ✅ Versão correta
if (entrega.status === 'EM_TRANSITO') {
  throw new Error('...');
}
```

Isso fará com que `CRIADA → ENTREGUE` seja aceito (violando a sequência obrigatória), mas `EM_TRANSITO → ENTREGUE` seja rejeitado.

## Pontos de Atenção

- Verificar que os testes de integração usam `request(app)` do Supertest, não `request('http://localhost:3000')`.
- Para o teste de token expirado: configurar `JWT_EXPIRES_IN=1s` no `.env.test`, gerar um token, esperar com `await new Promise(r => setTimeout(r, 1100))` e então usar o token.
- Testes que fazem `beforeAll(async () => { await prisma.entrega.deleteMany() })` são aceitáveis para limpeza, mas verificar que usam o banco de **teste**, não o de desenvolvimento.
