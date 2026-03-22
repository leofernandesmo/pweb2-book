# Atividade 06 — Delivery Tracker: Motoristas e Contratos de Repository

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 4 — Arquitetura: Repository Pattern e Inversão de Dependência  
**Modalidade:** Em sala (duplas)  
**Carga horária estimada:** 3h  

---

## Contexto do Problema

O cliente de logística expandiu as operações. Agora cada entrega deve ser atribuída a um motorista cadastrado no sistema. O Tech Lead identificou um problema crítico no código entregue na Atividade 05: diferentes membros do time estavam acessando arrays diretamente nos services, contornando os repositories. A equipe decidiu que todos os repositories precisam expor **contratos explícitos** — interfaces documentadas — e que nenhum service pode depender de uma implementação concreta, apenas do contrato.

> **Pré-requisito:** Atividade 05 concluída (arquitetura Controller → Service → Repository com persistência em memória).

---

## Objetivos de Aprendizagem

- Compreender o Repository Pattern como abstração de persistência
- Aplicar inversão de dependência programando contra contratos (interfaces)
- Compor múltiplos aggregates com repositories independentes
- Identificar o ponto único e correto de composição das dependências

---

## Requisitos Funcionais

### RF-01 — Cadastro de Motoristas

- O sistema deve permitir o cadastro de motoristas informando `nome`, `cpf` e `placaVeiculo`
- O `cpf` deve ser único no sistema; tentativa de cadastro com CPF duplicado deve retornar **409 Conflict** com mensagem descritiva
- O motorista é criado com `status: "ATIVO"` por padrão

### RF-02 — Atribuição de Motorista a Entrega

- O sistema deve permitir a atribuição de um motorista a uma entrega com status `CRIADA`
- Não é permitido atribuir motorista a entrega em qualquer outro status
- Não é permitido atribuir motorista com status `INATIVO`
- Uma entrega só pode ter um motorista por vez; nova atribuição substitui a anterior e gera evento no histórico

### RF-03 — Consulta de Entregas por Motorista

- O sistema deve listar todas as entregas atribuídas a um motorista específico
- O filtro por `status` existente deve funcionar em combinação com o filtro por motorista

### RF-04 — Contratos de Repository (Restrição Arquitetural)

- Cada repository deve ter seu contrato documentado em JSDoc ou em arquivo de tipos separado
- Os services **não devem referenciar classes concretas** de repository — apenas os contratos
- A composição das dependências deve ocorrer exclusivamente no arquivo de rotas ou em um arquivo de bootstrap dedicado

---

## Contratos Esperados

```js
// IEntregasRepository
listarTodos(filtros?)  → Entrega[]
buscarPorId(id)        → Entrega | null
criar(dados)           → Entrega
atualizar(id, dados)   → Entrega

// IMotoristasRepository
listarTodos()          → Motorista[]
buscarPorId(id)        → Motorista | null
buscarPorCPF(cpf)      → Motorista | null
criar(dados)           → Motorista
atualizar(id, dados)   → Motorista
```

---

## Rotas Obrigatórias

```
POST   /api/motoristas
GET    /api/motoristas
GET    /api/motoristas/:id
GET    /api/motoristas/:id/entregas
PATCH  /api/entregas/:id/atribuir       body: { motoristaId }
```

Todas as rotas existentes da Atividade 05 devem ser mantidas sem alteração de comportamento.

---

## Composição de Dependências

A composição deve ocorrer em um único ponto — nunca dentro de services ou controllers:

```js
const database        = new Database();
const entregasRepo    = new EntregasRepository(database);
const motoristasRepo  = new MotoristasRepository(database);
const entregasService = new EntregasService(entregasRepo, motoristasRepo);
const motoristasService = new MotoristasService(motoristasRepo);
```

---

## Restrição de Avaliação

> ⚠️ **O professor substituirá a implementação `InMemory` de ambos os repositories por uma implementação `Mock` durante a correção.** Se o código quebrar com a troca, o service está acoplado à implementação concreta — e o critério de arquitetura será zerado.

---

## Cenários de Teste Esperados

1. `POST /api/motoristas` com dados válidos → **201** com motorista criado
2. `POST /api/motoristas` com CPF já cadastrado → **409** com mensagem descritiva
3. `PATCH /api/entregas/:id/atribuir` com entrega `CRIADA` e motorista `ATIVO` → sucesso + evento no histórico
4. `PATCH /api/entregas/:id/atribuir` com entrega `EM_TRANSITO` → **422** com mensagem de erro
5. `PATCH /api/entregas/:id/atribuir` com motorista `INATIVO` → **422** com mensagem de erro
6. `GET /api/motoristas/:id/entregas` → retorna apenas as entregas daquele motorista
7. `GET /api/motoristas/:id/entregas?status=CRIADA` → filtragem combinada funciona

---

## Entregável

- Repositório Git com código-fonte completo
- `README.md` com instruções de execução e exemplos de requisição (curl ou collection Postman/Insomnia)
- Diagrama simples (texto ASCII é aceito) mostrando a composição das dependências

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: Cadastro de motorista com validação de CPF único | 15% | Verificar status 409 e mensagem descritiva |
| RF-02: Atribuição com todas as validações de negócio | 20% | Testar os 3 casos de erro separadamente |
| RF-03: Consulta de entregas por motorista com filtro combinado | 15% | Verificar que não retorna entregas de outros motoristas |
| RF-04: Contratos documentados (JSDoc ou types) | 15% | Avaliar se o contrato cobre todos os métodos obrigatórios |
| Services dependem apenas dos contratos, não de concretos | 20% | **Trocar a implementação e verificar que não quebra** |
| Composição ocorre em ponto único | 10% | `new` dentro de service ou controller = penalização total |
| README com instruções e exemplos funcionais | 5% | |

**Total: 100%**

## Procedimento de Verificação do Critério Principal

Criar a classe abaixo e substituir no arquivo de bootstrap:

```js
class EntregasRepositoryMock {
  constructor() { this._data = []; }
  listarTodos(f) { return f?.status ? this._data.filter(e => e.status === f.status) : [...this._data]; }
  buscarPorId(id) { return this._data.find(e => e.id === id) ?? null; }
  criar(dados) { const e = { id: Date.now(), ...dados }; this._data.push(e); return e; }
  atualizar(id, dados) {
    const i = this._data.findIndex(e => e.id === id);
    if (i === -1) return null;
    this._data[i] = { ...this._data[i], ...dados };
    return this._data[i];
  }
}
```

Se o sistema funcionar normalmente após a troca → **arquitetura correta**.  
Se lançar `TypeError` ou comportamento inesperado → **service acoplado à implementação concreta**.

## Pontos de Atenção

- Penalizar soluções que colocam a lógica de atribuição diretamente no Controller
- Aceitar tanto JSDoc quanto TypeScript para os contratos — o que importa é que seja explícito
- A regra "motorista inativo não pode ser atribuído" deve estar no `EntregasService`, não no `MotoristasService`
