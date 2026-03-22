# Atividade 09 — Delivery Tracker: Painel Administrativo com EJS

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 6 — Renderização no Servidor com EJS  
**Modalidade:** Em sala / Casa  
**Carga horária estimada:** 3h  

---

## Contexto do Problema

O cliente solicitou um **painel administrativo interno** para que a equipe de operações possa gerenciar entregas e motoristas sem precisar usar ferramentas como Postman ou Insomnia. O painel não precisa ser uma SPA sofisticada — uma interface renderizada no servidor com EJS é suficiente para este público interno, e o Tech Lead preferiu manter a simplicidade do stack sem adicionar um projeto frontend separado.

A API REST construída nas atividades anteriores **deve ser mantida integralmente**. O painel é uma camada adicional que reutiliza os mesmos services, com controllers específicos para views.

> **Pré-requisito:** Atividade 08 concluída (Prisma ORM, paginação e filtros).

---

## Objetivos de Aprendizagem

- Configurar o EJS como motor de templates no Express
- Compreender a diferença entre SSR e SPA e quando cada abordagem é adequada
- Criar layouts com partials reutilizáveis (header, nav, footer)
- Implementar o padrão Post-Redirect-Get (PRG) em formulários
- Exibir mensagens de feedback (flash) ao usuário após operações
- Usar `method-override` para simular `PUT` e `DELETE` em formulários HTML

---

## Requisitos Funcionais

### RF-01 — Configuração do EJS

- O EJS deve ser configurado como `view engine` do Express
- A estrutura de diretórios deve seguir o padrão:

```
src/
  views/
    layouts/
      base.ejs          ← layout principal com <head>, nav e footer
    partials/
      nav.ejs
      flash.ejs         ← exibe mensagens de sucesso e erro
    entregas/
      index.ejs
      nova.ejs
      detalhe.ejs
      editar.ejs
    motoristas/
      index.ejs
      novo.ejs
```

### RF-02 — Listagem de Entregas (SSR)

- `GET /painel/entregas` deve renderizar a listagem de entregas com paginação visual
- A listagem deve exibir: descrição, origem, destino, status (com badge colorido), motorista atribuído e data de criação
- Deve haver um filtro por status acessível via `<select>` no formulário da página

### RF-03 — Formulário de Nova Entrega

- `GET /painel/entregas/nova` deve exibir o formulário de criação
- `POST /painel/entregas` deve processar o formulário aplicando o padrão **PRG**:
  - Em caso de sucesso: redirecionar para `/painel/entregas` com mensagem flash de sucesso
  - Em caso de erro de validação ou regra de negócio: re-renderizar o formulário com as mensagens de erro exibidas inline e os campos preenchidos com os valores enviados

### RF-04 — Detalhe e Histórico

- `GET /painel/entregas/:id` deve renderizar a página de detalhe com o histórico completo de eventos em ordem cronológica
- O histórico deve exibir data, hora e descrição de cada evento

### RF-05 — Ações de Status no Painel

- A página de detalhe deve conter botões para avançar status e cancelar, implementados como formulários com `method-override`
- As ações devem seguir o padrão PRG, exibindo mensagem flash adequada após cada operação

### RF-06 — Listagem de Motoristas

- `GET /painel/motoristas` deve renderizar a listagem de motoristas com nome, CPF, placa e status
- `GET /painel/motoristas/novo` e `POST /painel/motoristas` devem implementar o cadastro com PRG e validação

---

## Separação de Responsabilidades

Os controllers de painel devem ser **distintos** dos controllers da API REST:

```
src/
  controllers/
    api/
      EntregasController.js     ← responde JSON (existente)
      MotoristasController.js   ← responde JSON (existente)
    painel/
      EntregasController.js     ← responde com res.render()
      MotoristasController.js   ← responde com res.render()
```

Ambos os conjuntos de controllers **devem usar os mesmos services** — nenhuma lógica de negócio nos controllers de painel.

---

## Restrição de Avaliação

> ⚠️ **A API REST (rotas `/api/*`) não pode ser modificada nem ter seu comportamento alterado.** O painel é uma adição, não uma substituição. O professor testará as rotas da API separadamente após avaliar o painel.

---

## Cenários de Teste Esperados

1. `GET /painel/entregas` renderiza listagem com os dados do banco
2. `POST /painel/entregas` com dados válidos → redireciona com flash de sucesso
3. `POST /painel/entregas` com origem igual ao destino → re-renderiza formulário com erro inline e campos preenchidos
4. `GET /painel/entregas/:id` exibe histórico de eventos em ordem cronológica
5. Avançar status via botão no painel → atualiza e exibe flash de sucesso
6. Tentar avançar status de entrega `ENTREGUE` → exibe flash de erro
7. `GET /painel/motoristas` lista todos os motoristas corretamente

---

## Entregável

- Código-fonte completo com views EJS, controllers de painel e rotas separadas
- API REST preservada e funcional

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: EJS configurado com estrutura de diretórios correta | 10% | Verificar `app.set('view engine', 'ejs')` e diretórios |
| RF-02: Listagem com paginação visual e filtro por status | 20% | Testar filtro via `<select>` |
| RF-03: Formulário de nova entrega com PRG e erros inline | 25% | Testar o caso de erro — campos devem manter os valores |
| RF-04: Detalhe com histórico cronológico | 10% | Verificar ordenação dos eventos |
| RF-05: Ações de status via `method-override` com PRG | 20% | Testar avanço e cancelamento no painel |
| RF-06: Listagem e cadastro de motoristas | 10% | |
| API REST preservada e funcional | 5% | Testar `GET /api/entregas` após as alterações |

**Total: 100%**

## Pontos de Atenção

- **Erro mais comum:** colocar lógica de negócio no controller de painel (ex: verificar status diretamente no controller). Deve delegar ao service e capturar a exceção.
- O padrão PRG é obrigatório: um `POST` que renderiza diretamente (sem redirect) causa duplicação de operação ao recarregar a página.
- As mensagens flash podem ser implementadas com `express-flash` + `express-session` ou via `res.locals` manual com query string — ambas as abordagens são aceitas.
- Verificar que `method-override` está configurado para ler o campo `_method` do body do formulário.

## Exemplo de Flash Manual (sem biblioteca)

```js
// Redirect com mensagem via query string
res.redirect('/painel/entregas?sucesso=Entrega criada com sucesso');

// No controller de listagem
const flash = { sucesso: req.query.sucesso, erro: req.query.erro };
res.render('entregas/index', { entregas, flash });
```
