# Atividade 10 — Delivery Tracker: Dashboard Frontend com Vue.js

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 7 — Integração com Frontend Moderno: Vue.js  
**Modalidade:** Em sala / Casa  
**Carga horária estimada:** 4h  

---

## Contexto do Problema

A equipe de operações adorou o painel EJS, mas os usuários de campo — motoristas e coordenadores que acessam o sistema pelo celular — precisam de uma interface mais responsiva e fluida. O cliente aprovou o desenvolvimento de um **dashboard SPA** em Vue.js que consome a API REST existente. O backend não muda — esta atividade é sobre configurar o Express para servir o frontend e construir a interface Vue que se comunica com a API.

> **Pré-requisito:** Atividade 09 concluída. A API REST deve estar funcionando com autenticação (Atividade 11 será construída sobre esta base — por ora, as rotas ainda são abertas).

---

## Objetivos de Aprendizagem

- Compreender a separação de responsabilidades entre backend (API) e frontend (SPA)
- Configurar CORS no Express para permitir requisições do frontend em desenvolvimento
- Configurar o Express para servir o build estático do Vue em produção
- Construir componentes Vue com reatividade (`ref`, `reactive`), diretivas e ciclo de vida
- Consumir a API com Axios, tratar erros HTTP e exibir feedback ao usuário

---

## Requisitos Funcionais

### RF-01 — Configuração de CORS no Express

- O Express deve configurar CORS para aceitar requisições da origem `http://localhost:5173` (dev do Vite) durante o desenvolvimento
- Em produção, o CORS deve ser restrito à origem configurada por variável de ambiente `FRONTEND_URL`
- O middleware CORS deve ser aplicado antes das rotas

### RF-02 — Servindo o Build do Frontend

- O Express deve servir os arquivos estáticos do build Vue (diretório `frontend/dist`) na rota raiz
- A rota `GET *` deve retornar `index.html` para suportar o roteamento client-side do Vue Router
- Essa configuração deve ser aplicada **apenas** quando `NODE_ENV=production`

### RF-03 — Projeto Vue com Vite

- O projeto Vue deve ser criado dentro de um diretório `frontend/` na raiz do repositório (estrutura monorepo)
- Deve usar **Composition API** com `<script setup>`
- O Axios deve estar configurado em um arquivo `frontend/src/services/api.js` com `baseURL` lida de variável de ambiente Vite (`VITE_API_URL`)

### RF-04 — Página de Listagem de Entregas

- A rota `/entregas` do Vue Router deve exibir a listagem de entregas consumida da API
- A listagem deve mostrar: descrição, origem → destino, status com badge colorido, motorista atribuído
- Deve haver um filtro reativo por status (alteração no `<select>` deve refazer a requisição imediatamente)
- Deve exibir estado de carregamento (`loading`) e mensagem de erro quando a API não responder

### RF-05 — Formulário de Nova Entrega

- A rota `/entregas/nova` deve exibir o formulário de criação com validação reativa no cliente
- Campos obrigatórios devem ser validados antes do envio
- Em caso de erro da API (ex: origem igual ao destino), a mensagem de erro da API deve ser exibida na interface
- Após criação bem-sucedida, redirecionar para `/entregas` com mensagem de sucesso

### RF-06 — Página de Detalhe

- A rota `/entregas/:id` deve exibir o detalhe completo da entrega com o histórico de eventos
- Deve conter botões para avançar status e cancelar, com confirmação antes da ação
- Após a ação, os dados devem ser recarregados automaticamente (sem reload da página)

---

## Estrutura Esperada do Monorepo

```
/
  src/                  ← backend Express (existente)
  frontend/
    src/
      services/
        api.js          ← instância Axios com baseURL
      components/
        StatusBadge.vue
        LoadingSpinner.vue
      views/
        EntregasListagem.vue
        EntregasNova.vue
        EntregaDetalhe.vue
      router/
        index.js
      App.vue
      main.js
    .env.development    ← VITE_API_URL=http://localhost:3000
```

---

## Restrição de Avaliação

> ⚠️ **O backend não pode ser modificado para acomodar limitações do frontend.** Se o frontend precisar de dados em formato diferente do que a API retorna, o componente Vue deve transformar os dados — não o controller da API.

---

## Cenários de Teste Esperados

1. `npm run dev` no frontend e `npm run dev` no backend rodam simultaneamente sem conflito de porta
2. Listagem carrega os dados da API e o badge de status tem cor correspondente
3. Alterar o filtro de status atualiza a listagem sem recarregar a página
4. Criar entrega com dados válidos → redireciona com mensagem de sucesso
5. Criar entrega com origem igual ao destino → exibe mensagem de erro da API na interface
6. Avançar status na página de detalhe → histórico é recarregado automaticamente

---

## Entregável

- Diretório `frontend/` com projeto Vue configurado
- Backend com CORS e configuração de build estático
- `README.md` atualizado com instruções para executar frontend e backend

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: CORS configurado com origem correta e variável de ambiente | 15% | Testar requisição do Vite sem erro de CORS |
| RF-02: Express serve build estático e suporta client-side routing | 10% | Verificar `GET *` retornando `index.html` |
| RF-03: Projeto Vue com Composition API e Axios centralizado | 15% | Verificar `<script setup>` e `api.js` |
| RF-04: Listagem com filtro reativo e tratamento de loading/erro | 25% | Testar filtro e simular falha da API |
| RF-05: Formulário com validação reativa e exibição de erro da API | 20% | Testar erro de domínio vindo do backend |
| RF-06: Detalhe com ações e reload automático sem page refresh | 15% | Avançar status e verificar que histórico atualiza |

**Total: 100%**

## Pontos de Atenção

- **Erro mais comum:** fazer `window.location.reload()` após uma ação em vez de refazer a requisição ao estado reativamente. O objetivo é demonstrar a reatividade do Vue.
- Verificar que a `baseURL` do Axios está em variável de ambiente Vite e não hardcoded.
- O badge de status deve usar classes CSS condicionais com `v-bind:class` ou `:class` — não concatenação de strings.
- CORS com `origin: '*'` em produção deve ser penalizado — deve usar `FRONTEND_URL`.

## Configuração de CORS de Referência

```js
import cors from 'cors';

const allowedOrigins = process.env.NODE_ENV === 'production'
  ? [process.env.FRONTEND_URL]
  : ['http://localhost:5173'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) callback(null, true);
    else callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));
```
