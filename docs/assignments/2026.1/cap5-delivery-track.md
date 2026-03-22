# ATIVIDADE 05 — Sistema de Rastreamento de Entregas  
## Delivery Tracker API

## Contexto

Você foi contratado como desenvolvedor backend por uma empresa de logística em crescimento que atua no transporte de encomendas entre cidades. Atualmente, a empresa enfrenta dificuldades para acompanhar o status das entregas e garantir consistência nas informações operacionais.

Seu objetivo é projetar e implementar uma **API REST** para rastreamento de entregas, garantindo controle rigoroso do ciclo de vida das encomendas, rastreabilidade de eventos e consistência das regras de negócio.

A solução deve seguir boas práticas de engenharia de software, incluindo separação de responsabilidades e arquitetura em camadas.

---

## Objetivo Técnico

Desenvolver uma API REST aplicando:

- Arquitetura em camadas (**Controller, Service, Repository**)
- **Injeção de Dependência**
- Separação entre **lógica de domínio** e **transporte HTTP**

---

## Requisitos Funcionais (Visão do Cliente)

O sistema deve permitir o gerenciamento completo do ciclo de vida de entregas.

### Cadastro de Entregas

O sistema deve permitir o cadastro de novas entregas contendo:

- descrição
- cidade de origem
- cidade de destino

---

### Ciclo de Vida da Entrega

Cada entrega deve seguir um fluxo controlado de estados:

- `CRIADA`
- `EM_TRANSITO`
- `ENTREGUE`
- `CANCELADA`

#### Regras de transição:

- CRIADA → EM_TRANSITO  
- EM_TRANSITO → ENTREGUE  
- CANCELAMENTO só é permitido antes da entrega  

---

### Consistência e Validações

O sistema deve garantir:

- Origem e destino **não podem ser iguais**
- Transições de estado devem ser **válidas**
- Não é permitido:
  - avançar após `ENTREGUE` ou `CANCELADA`
  - cancelar uma entrega já finalizada
- Não podem existir entregas duplicadas ativas com:
  - mesma descrição
  - mesma origem
  - mesmo destino

(considerando entregas que ainda não foram finalizadas ou canceladas)

---

### Histórico de Eventos

Cada entrega deve manter um histórico auditável contendo:

- Criação
- Mudanças de status
- Cancelamento

---

### Consultas

O sistema deve permitir:

- Listar todas as entregas
- Buscar entrega por ID
- Filtrar entregas por status
- Consultar histórico de uma entrega

---

## Modelo de Dados

```json
{
  "id": number,
  "descricao": string,
  "origem": string,
  "destino": string,
  "status": "CRIADA" | "EM_TRANSITO" | "ENTREGUE" | "CANCELADA",
  "historico": [
    {
      "data": string,
      "descricao": string
    }
  ]
}
````

---

## Estrutura do Projeto

```
src/
├── controllers/
├── services/
├── repositories/
├── database/
├── routes/
├── utils/
```

---

## Persistência (Simulada)

Implemente uma classe para simular um banco de dados em memória:

```javascript
// src/database/database.js

export class Database {
  constructor() {
    this.entregas = [];
    this.nextId = 1;
  }

  getEntregas() {
    return this.entregas;
  }

  generateId() {
    return this.nextId++;
  }
}
```

**Importante:**

* O repository deve utilizar essa classe
* Não acessar arrays diretamente fora da camada de persistência

---

## Repository

Implemente `EntregasRepository` com os métodos:

* `listarTodos()`
* `buscarPorId(id)`
* `criar(dados)`
* `atualizar(id, dados)`

---

## Service (Regras de Negócio)

Toda a lógica deve estar centralizada na camada de service.

### Regras básicas

* Origem ≠ destino
* Status inicial obrigatório: `CRIADA`
* Criar evento no histórico ao cadastrar entrega

---

### Transições de Status

* CRIADA → EM_TRANSITO
* EM_TRANSITO → ENTREGUE
* Não permitir avanço inválido

---

### Cancelamento

* Só permitido se status ≠ `ENTREGUE`

---

### Regras adicionais

* Evitar duplicidade ativa
* Respeitar sequência de estados
* Não permitir marcar como `ENTREGUE` sem passar por `EM_TRANSITO`

---

### Tempo lógico (simulado)

* Não permitir entrega imediata após criação
* Deve existir pelo menos uma transição intermediária

---

### Histórico

Cada ação relevante deve gerar registro:

* Criação
* Avanço de status
* Cancelamento

---

## Rotas da API

```
POST   /api/entregas
GET    /api/entregas
GET    /api/entregas/:id
PATCH  /api/entregas/:id/avancar
PATCH  /api/entregas/:id/cancelar
GET    /api/entregas/:id/historico
GET    /api/entregas?status=EM_TRANSITO
```

---

## Injeção de Dependência

A composição deve ocorrer nas rotas:

```javascript
const database = new Database();
const repository = new EntregasRepository(database);
const service = new EntregasService(repository);
const controller = new EntregasController(service);
```

---

## Cenários de Teste Esperados

O sistema deve permitir:

* Criar uma entrega
* Listar todas as entregas
* Buscar entrega por ID
* Tentar criar entrega duplicada (erro esperado)
* Avançar status para `EM_TRANSITO`
* Avançar para `ENTREGUE`
* Tentar avançar após finalização (erro)
* Tentar cancelar entrega já finalizada (erro)
* Consultar histórico
* Filtrar entregas por status

---

## Diretrizes de Implementação

* Não utilizar banco de dados real
* Não utilizar ORM
* Não colocar regras de negócio no controller
* Centralizar lógica no service
* Manter repository simples e focado em dados

---

