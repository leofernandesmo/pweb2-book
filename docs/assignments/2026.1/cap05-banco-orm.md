# Atividade 08 — Delivery Tracker: Migração para Prisma ORM

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 5 — Banco de Dados: ORM, Migrations Versionadas e Queries Avançadas  
**Modalidade:** Em sala / Casa  
**Carga horária estimada:** 4h  

---

## Contexto do Problema

O time de desenvolvimento cresceu. Dois desenvolvedores modificaram o esquema do banco manualmente em ambientes diferentes e o banco ficou inconsistente entre desenvolvimento e staging. O Tech Lead decidiu adotar o **Prisma** para que todas as mudanças no banco sejam versionadas como código e rastreáveis no repositório Git. O cliente também solicitou busca por intervalo de datas e paginação nas listagens — funcionalidades impossíveis de implementar de forma eficiente com os arrays anteriores.

> **Pré-requisito:** Atividade 07 concluída (repositories com `pg.Pool` e `migration.sql`).

---

## Objetivos de Aprendizagem

- Modelar o esquema de banco com Prisma Schema Language
- Gerenciar o ciclo de vida do banco com `prisma migrate dev`
- Reimplementar repositories usando `PrismaClient` sem alterar services
- Utilizar relações (`include`), filtros avançados (`where`) e paginação (`skip`/`take`)
- Compreender a diferença entre `prisma migrate dev` e `prisma db push`

---

## Requisitos Funcionais

### RF-01 — Schema Prisma

- O arquivo `prisma/schema.prisma` deve modelar os models `Entrega`, `EventoEntrega` e `Motorista` com todos os campos e relações
- A relação entre `Entrega` e `EventoEntrega` deve ser `1:N` com `onDelete: Cascade`
- O campo `status` deve usar `enum` do Prisma
- Todos os models devem ter `createdAt` e `updatedAt` gerenciados automaticamente (`@default(now())` e `@updatedAt`)

### RF-02 — Migrations Versionadas

- O diretório `prisma/migrations` deve existir e conter ao menos uma migration gerada por `prisma migrate dev`
- É **proibido** usar `prisma db push` — apenas `prisma migrate dev` para garantir o histórico versionado
- O histórico de migrations deve ser commitado no repositório

### RF-03 — Repositories com Prisma

- `EntregasRepository` e `MotoristasRepository` devem ser reimplementados usando `PrismaClient`
- Os contratos da Atividade 06 não devem ser alterados
- Os services não devem ser modificados

### RF-04 — Paginação

- `GET /api/entregas` deve aceitar os parâmetros `page` (padrão `1`) e `limit` (padrão `10`, máximo `50`)
- A resposta deve incluir: `data`, `total`, `page`, `limit`, `totalPages`

### RF-05 — Filtro por Intervalo de Datas

- `GET /api/entregas` deve aceitar os parâmetros opcionais `createdDe` e `createdAte` (formato ISO 8601)
- Os parâmetros combinam com os demais filtros existentes (`status`, `motoristaId`)

### RF-06 — Seed

- Deve existir um script `prisma/seed.js` que popula o banco com dados de demonstração: ao menos 3 motoristas, 10 entregas distribuídas em diferentes status e com histórico de eventos registrado

---

## Exemplos de Query Esperados

```
GET /api/entregas?status=EM_TRANSITO&page=2&limit=5
GET /api/entregas?createdDe=2025-01-01&createdAte=2025-06-30
GET /api/entregas?motoristaId=3&status=CRIADA&page=1&limit=10
```

---

## Restrição de Avaliação

> ⚠️ **Os services permanecem inalterados pela terceira vez consecutiva.** Esta sequência de atividades (06 → 07 → 08) demonstra empiricamente o valor da arquitetura em camadas: a lógica de negócio sobreviveu a duas trocas completas de infraestrutura de dados. Verificar via `git diff`.

---

## Cenários de Teste Esperados

1. `npx prisma migrate dev` executa sem erros em banco limpo
2. `node prisma/seed.js` popula o banco corretamente
3. `GET /api/entregas?page=1&limit=3` retorna no máximo 3 registros e metadados corretos (`totalPages`, `total`)
4. `GET /api/entregas?createdDe=2025-01-01` filtra por data corretamente
5. `GET /api/entregas/:id` retorna a entrega com `historico` (eventos) incluídos via `include`
6. Dados persistem após reinício; migrations estão presentes no repositório Git

---

## Entregável

- `prisma/schema.prisma` com models, relações e enums
- Diretório `prisma/migrations` com ao menos uma migration
- `prisma/seed.js` funcional
- Código-fonte com repositories reimplementados
- `.env.example` atualizado

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: Schema com models, relações, enum e timestamps automáticos | 20% | Verificar `onDelete: Cascade`, `@updatedAt` |
| RF-02: Migrations com `prisma migrate dev`, não `db push` | 10% | Checar diretório `prisma/migrations` no Git |
| RF-03: Repositories reimplementados sem alterar services | 20% | `git diff` contra Atividade 07 |
| RF-04: Paginação com todos os metadados na resposta | 20% | Testar `page=1` e `page=2` com `limit=3` |
| RF-05: Filtro por intervalo de datas funcional | 15% | Testar intervalo que exclui alguns registros do seed |
| RF-06: Script de seed cobrindo todos os status com histórico | 10% | Executar e verificar os dados no banco |
| Resposta paginada com estrutura consistente | 5% | `data`, `total`, `page`, `limit`, `totalPages` presentes |

**Total: 100%**

## Schema Prisma de Referência

```prisma
enum StatusEntrega {
  CRIADA
  EM_TRANSITO
  ENTREGUE
  CANCELADA
}

enum StatusMotorista {
  ATIVO
  INATIVO
}

model Motorista {
  id           Int        @id @default(autoincrement())
  nome         String
  cpf          String     @unique
  placaVeiculo String
  status       StatusMotorista @default(ATIVO)
  entregas     Entrega[]
  createdAt    DateTime   @default(now())
  updatedAt    DateTime   @updatedAt
}

model Entrega {
  id          Int            @id @default(autoincrement())
  descricao   String
  origem      String
  destino     String
  status      StatusEntrega  @default(CRIADA)
  motorista   Motorista?     @relation(fields: [motoristaId], references: [id])
  motoristaId Int?
  historico   EventoEntrega[]
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt
}

model EventoEntrega {
  id         Int      @id @default(autoincrement())
  descricao  String
  entrega    Entrega  @relation(fields: [entregaId], references: [id], onDelete: Cascade)
  entregaId  Int
  createdAt  DateTime @default(now())
}
```

## Pontos de Atenção

- Verificar que `GET /api/entregas/:id` usa `include: { historico: true }` — sem o `include` o histórico não retorna.
- Para a paginação: `totalPages = Math.ceil(total / limit)`. Verificar que `total` vem de `prisma.entrega.count({ where })` com os mesmos filtros aplicados ao `findMany`.
- O uso de `prisma db push` no lugar de `prisma migrate dev` deve ser penalizado independentemente do resultado final — o histórico de migrations é parte do entregável.
