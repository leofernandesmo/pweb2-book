# Atividade 07 — Delivery Tracker: Persistência com PostgreSQL e SQL Puro

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 5 — Banco de Dados: Modelagem Relacional e SQL sem ORM  
**Modalidade:** Em sala / Casa  
**Carga horária estimada:** 4h  

---

## Contexto do Problema

O cliente registrou uma reclamação formal: toda vez que o servidor é reiniciado para manutenção, todos os dados de entregas e motoristas desaparecem. O sistema precisa de persistência real. O Tech Lead decidiu começar pela base — implementar persistência com **SQL puro** usando o driver `pg` — antes de adotar qualquer abstração de ORM. O objetivo é que o time compreenda o que acontece por baixo dos panos antes de delegar esse trabalho a uma biblioteca.

> **Pré-requisito:** Atividade 06 concluída (arquitetura com contratos de repository explícitos).

---

## Objetivos de Aprendizagem

- Modelar um banco de dados relacional a partir de um domínio existente
- Escrever migrations SQL manualmente (`CREATE TABLE`, constraints, índices)
- Reimplementar um repository usando `pg.Pool` sem alterar os contratos
- Tratar erros do driver como erros de domínio na camada correta
- Escrever queries com `JOIN` e `GROUP BY`

---

## Requisitos Funcionais

### RF-01 — Modelagem do Banco

- O banco deve conter as tabelas: `entregas`, `eventos_entrega`, `motoristas`
- A tabela `eventos_entrega` deve ter chave estrangeira para `entregas` com `ON DELETE CASCADE`
- O campo `status` deve usar `CHECK CONSTRAINT` com os valores válidos do domínio (`CRIADA`, `EM_TRANSITO`, `ENTREGUE`, `CANCELADA`)
- O campo `cpf` na tabela `motoristas` deve ter constraint `UNIQUE`
- Todos os campos obrigatórios do domínio devem ter `NOT NULL`

### RF-02 — Migration Manual

- Deve existir um arquivo `migration.sql` na raiz do projeto com todos os `CREATE TABLE` e constraints
- O arquivo deve poder ser executado do zero em um banco vazio sem erros
- Deve usar `CREATE TABLE IF NOT EXISTS` para ser idempotente

### RF-03 — Repositories com `pg.Pool`

- `EntregasRepository` e `MotoristasRepository` devem ser **reimplementados** usando `pg.Pool`
- Os **contratos da Atividade 06 não devem ser alterados**
- Os **services não devem ser modificados** — apenas os repositories

### RF-04 — Tratamento de Erros do Banco

- Violação de `UNIQUE` (CPF duplicado) deve ser capturada no repository e relançada como erro de domínio com mensagem legível
- Registro não encontrado deve retornar `null`, não lançar exceção
- Erros brutos do driver `pg` não devem vazar para o cliente em nenhuma circunstância

### RF-05 — Relatórios Agregados (novo requisito de negócio)

- `GET /api/relatorios/entregas-por-status` deve retornar a contagem de entregas agrupadas por status
- `GET /api/relatorios/motoristas-ativos` deve retornar motoristas que possuam ao menos uma entrega com status diferente de `ENTREGUE` ou `CANCELADA`, com a contagem de entregas em aberto

---

## Modelo de Dados Esperado

```sql
-- Estrutura mínima esperada (o aluno define os tipos exatos)

entregas (
  id          SERIAL PRIMARY KEY,
  descricao   TEXT NOT NULL,
  origem      TEXT NOT NULL,
  destino     TEXT NOT NULL,
  status      TEXT NOT NULL CHECK (status IN ('CRIADA','EM_TRANSITO','ENTREGUE','CANCELADA')),
  motorista_id INT REFERENCES motoristas(id),
  criado_em   TIMESTAMP DEFAULT NOW()
)

eventos_entrega (
  id          SERIAL PRIMARY KEY,
  entrega_id  INT NOT NULL REFERENCES entregas(id) ON DELETE CASCADE,
  descricao   TEXT NOT NULL,
  ocorrido_em TIMESTAMP DEFAULT NOW()
)

motoristas (
  id           SERIAL PRIMARY KEY,
  nome         TEXT NOT NULL,
  cpf          TEXT NOT NULL UNIQUE,
  placa_veiculo TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'ATIVO'
)
```

---

## Rotas Novas

```
GET /api/relatorios/entregas-por-status
    → { "CRIADA": 5, "EM_TRANSITO": 3, "ENTREGUE": 12, "CANCELADA": 2 }

GET /api/relatorios/motoristas-ativos
    → [{ "motoristaId": 1, "nome": "João", "entregasEmAberto": 2 }, ...]
```

---

## Variáveis de Ambiente

```
DATABASE_URL=postgresql://usuario:senha@localhost:5432/delivery_tracker
```

---

## Restrição de Avaliação

> ⚠️ **Os services `EntregasService` e `MotoristasService` não podem ter nenhuma linha modificada.** Esta restrição é verificada via `git diff` entre a Atividade 06 e esta entrega. Se o aluno precisou alterar o service para adaptar ao banco, a arquitetura da atividade anterior estava incorreta.

---

## Cenários de Teste Esperados

1. Reiniciar o servidor → dados persistem no banco
2. Inserir entrega, reiniciar, consultar por ID → retorna corretamente
3. `POST /api/motoristas` com CPF já cadastrado → **409** com mensagem de domínio (não erro bruto do pg)
4. `GET /api/relatorios/entregas-por-status` após operações → contagens corretas
5. `GET /api/relatorios/motoristas-ativos` → motorista sem entregas em aberto não aparece

---

## Entregável

- `migration.sql` funcional e idempotente
- Código-fonte com repositories reimplementados
- `.env.example` com todas as variáveis necessárias

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: Modelagem correta das 3 tabelas com constraints | 20% | Verificar FK, NOT NULL, CHECK |
| RF-02: `migration.sql` idempotente e executável do zero | 10% | Testar em banco limpo |
| RF-03: Repositories com `pg.Pool` sem alterar services | 25% | `git diff` contra Atividade 06 |
| RF-04: Erros do banco tratados como erros de domínio | 15% | Mensagem legível, sem stack trace exposto |
| RF-05: Relatórios com `GROUP BY` e `JOIN` corretos | 20% | Testar com dados cobrindo todos os status |
| `.env.example` completo e funcional | 5% | |
| Dados persistem após reinício do servidor | 5% | Teste funcional obrigatório |

**Total: 100%**

## Queries de Referência para os Relatórios

```sql
-- RF-05a: entregas-por-status
SELECT status, COUNT(*) AS total
FROM entregas
GROUP BY status;

-- RF-05b: motoristas-ativos
SELECT m.id AS "motoristaId", m.nome, COUNT(e.id) AS "entregasEmAberto"
FROM motoristas m
JOIN entregas e ON e.motorista_id = m.id
WHERE e.status NOT IN ('ENTREGUE', 'CANCELADA')
GROUP BY m.id, m.nome
HAVING COUNT(e.id) > 0;
```

## Pontos de Atenção

- **Critério principal:** verificar `git diff` antes de avaliar qualquer outra coisa. Services alterados = dedução de 25 pontos independentemente do restante.
- Erro bruto do PostgreSQL chegando ao cliente (ex: `duplicate key value violates unique constraint`) sem tratamento = penalização total no RF-04.
- Para RF-05b: testar com um motorista sem entregas em aberto e verificar que ele não aparece na resposta.
- A query de `eventos_entrega` deve usar `JOIN` — não duas queries separadas.
