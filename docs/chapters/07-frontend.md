# Capítulo 7 — Integração com Frontend Moderno: Vue.js e React

---

## 7.1 Introdução

O Capítulo 6 demonstrou como o Express pode assumir a responsabilidade de renderizar HTML diretamente no servidor, entregando páginas prontas ao navegador. Essa abordagem é válida e elegante para muitos contextos — mas existe um cenário crescentemente comum no desenvolvimento web moderno em que ela não é suficiente: aplicações altamente interativas, com atualizações em tempo real, transições fluidas e experiências ricas que exigem que a interface responda imediatamente às ações do usuário, sem aguardar uma ida ao servidor a cada interação.

Para esses cenários, a arquitetura predominante separa completamente o backend do frontend: o Express atua como um servidor de API REST — retornando JSON, exatamente como foi estudado nos Capítulos 3 a 5 — e uma aplicação JavaScript independente, executando no navegador, consome essa API e constrói a interface dinamicamente. Essa aplicação frontend é denominada **SPA** (*Single Page Application*), e os frameworks mais utilizados para construí-la são o **Vue.js** e o **React**.

Este capítulo tem dois objetivos complementares. O primeiro é ensinar a configurar o Express para servir corretamente uma aplicação frontend — configurando CORS, servindo os arquivos estáticos da build e garantindo que o roteamento client-side funcione. O segundo, e mais extenso, é introduzir Vue.js e React com profundidade suficiente para que o aluno de Sistemas de Informação do IFAL compreenda os conceitos fundamentais desses frameworks e seja capaz de construir aplicações frontend que se comunicam com a API desenvolvida ao longo do curso.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o Capítulo 3 (Express e rotas), o Capítulo 5 (banco de dados com Prisma) e conhecimento básico de HTML, CSS e JavaScript — especialmente `fetch`, Promises e `async/await`.

---

## 7.2 Como Express e uma SPA se Relacionam

### 7.2.1 A separação de responsabilidades

Em uma arquitetura SPA, existem dois projetos distintos que colaboram:

O **projeto backend** (Express) é responsável por toda a lógica de negócio, acesso ao banco de dados, autenticação e persistência. Ele expõe uma API REST que responde exclusivamente com JSON. O Express não sabe nada sobre Vue ou React — ele não renderiza HTML de interface, não conhece componentes e não gerencia estado de interface. Sua responsabilidade termina em `res.json()`.

O **projeto frontend** (Vue ou React) é uma aplicação JavaScript independente que roda integralmente no navegador. Ele é responsável por construir a interface visual, gerenciar o estado da aplicação no lado do cliente, reagir às interações do usuário e se comunicar com a API do Express via HTTP. O frontend não acessa o banco de dados diretamente — ele consome os endpoints da API.

Essa separação tem implicações práticas importantes para o desenvolvimento: os dois projetos podem ser desenvolvidos por equipes diferentes, em repositórios diferentes, com pipelines de deploy independentes. Em produção, é comum o frontend ser servido por um CDN enquanto o backend roda em um servidor de aplicação.

### 7.2.2 O fluxo de uma requisição na arquitetura SPA

O fluxo de uma interação típica em uma SPA difere fundamentalmente do fluxo SSR estudado no Capítulo 6:

1. O navegador faz uma requisição inicial ao servidor (ou CDN) e recebe o `index.html` com referências aos bundles JavaScript e CSS.
2. O browser baixa e executa o bundle JavaScript — o framework de frontend assume o controle e renderiza a interface inicial.
3. O usuário interage com a interface (clica em um botão, preenche um formulário).
4. O framework faz uma requisição HTTP à API do Express (`fetch('/api/usuarios')`).
5. O Express processa a requisição, consulta o banco via Prisma e retorna um JSON.
6. O framework recebe o JSON, atualiza o estado interno da aplicação e re-renderiza os componentes afetados — sem recarregar a página.
7. O usuário vê a interface atualizada em milissegundos.

### 7.2.3 Desenvolvimento local: dois servidores

Durante o desenvolvimento, os dois projetos rodam em portas diferentes:

- Backend (Express): `http://localhost:3000`
- Frontend (Vite dev server): `http://localhost:5173`

Isso significa que o frontend em `localhost:5173` faz requisições para `localhost:3000` — uma **origem diferente**. O navegador, por segurança, bloqueia essas requisições por padrão através da política de mesma origem (*Same-Origin Policy*). A solução é configurar o CORS no Express, como detalhado na próxima seção.

---

## 7.3 Configurando CORS no Express

### 7.3.1 O que é CORS

**CORS** (*Cross-Origin Resource Sharing*) é um mecanismo de segurança implementado pelos navegadores que controla quais origens externas podem fazer requisições a um servidor. Uma "origem" é a combinação de protocolo, domínio e porta (`https://meuapp.com:443`). Quando o frontend em `localhost:5173` tenta acessar a API em `localhost:3000`, o navegador detecta origens diferentes e verifica se o servidor autoriza esse acesso.

O servidor comunica sua política de CORS através de cabeçalhos HTTP na resposta. O cabeçalho mais importante é `Access-Control-Allow-Origin`, que especifica quais origens são permitidas.

### 7.3.2 Configuração básica com o pacote `cors`

O pacote `cors`, já apresentado no Capítulo 3, é a forma mais prática de configurar CORS no Express:

```bash
npm install cors
```

```javascript
// src/app.js
import cors from 'cors';

// ── Desenvolvimento: permite apenas o Vite dev server ──
app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? process.env.FRONTEND_URL          // ex: 'https://meuapp.vercel.app'
    : 'http://localhost:5173',          // Vite dev server
  methods:     ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  credentials: true,                   // necessário para cookies/JWT em cookies
}));
```

Para múltiplas origens permitidas (útil quando há ambientes de staging):

```javascript
const origensPermitidas = [
  'http://localhost:5173',
  'http://localhost:4173',             // Vite preview
  'https://meuapp.vercel.app',
];

app.use(cors({
  origin: (origin, callback) => {
    // Permite também requisições sem origin (ex: curl, Insomnia)
    if (!origin || origensPermitidas.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`Origem ${origin} não permitida por CORS`));
    }
  },
  credentials: true,
}));
```

### 7.3.3 Requisições preflight

Para requisições com métodos não-simples (`PUT`, `DELETE`, `PATCH`) ou com cabeçalhos customizados (como `Authorization` para JWT), o navegador envia primeiro uma requisição **preflight** — um `OPTIONS` automático que pergunta ao servidor quais operações são permitidas. O pacote `cors` trata essas requisições automaticamente, mas é importante garantir que o middleware esteja registrado **antes** de qualquer rota:

```javascript
// src/app.js — ordem importa
app.use(cors(opcoesCorS));   // 1. CORS — antes de tudo
app.use(helmet());
app.use(express.json());
app.use('/api', router);     // 2. Rotas — depois
```

---

## 7.4 Servindo a Build do Frontend com Express

### 7.4.1 O processo de build

Frameworks como Vue e React utilizam ferramentas de build (Vite, Webpack) para transformar o código-fonte em arquivos otimizados para produção: JavaScript minificado e dividido em chunks, CSS otimizado, assets com hash de conteúdo para cache eficiente. O resultado é uma pasta `dist/` com arquivos estáticos que podem ser servidos por qualquer servidor HTTP.

Em produção, é possível — e muitas vezes desejável — fazer o Express servir esses arquivos diretamente, eliminando a necessidade de um servidor de frontend separado.

### 7.4.2 Configuração do Express para servir o frontend

```javascript
// src/app.js
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Servir os arquivos estáticos da build do frontend
app.use(express.static(join(__dirname, '..', 'frontend', 'dist')));

// API routes
app.use('/api', router);

// Fallback: qualquer rota não reconhecida retorna o index.html
// Isso permite que o roteamento client-side funcione
app.get('*', (req, res) => {
  res.sendFile(join(__dirname, '..', 'frontend', 'dist', 'index.html'));
});
```

!!! warning "A ordem dos middlewares é crítica"
    O fallback `app.get('*', ...)` deve ser registrado **após** todas as rotas da API. Caso contrário, todas as requisições à API retornarão o `index.html` em vez do JSON esperado.

### 7.4.3 Estrutura de projeto monorepo

Uma organização comum para projetos com Express + SPA é o monorepo:

```
projeto/
├── backend/          # Projeto Express (Capítulos 3–6)
│   ├── src/
│   ├── package.json
│   └── server.js
├── frontend/         # Projeto Vue ou React
│   ├── src/
│   ├── dist/         # Build gerada pelo Vite
│   └── package.json
└── package.json      # Scripts de build integrados
```

```json
// package.json (raiz) — scripts de conveniência
{
  "scripts": {
    "dev:backend":  "cd backend  && npm run dev",
    "dev:frontend": "cd frontend && npm run dev",
    "build":        "cd frontend && npm run build",
    "start":        "cd backend  && npm start"
  }
}
```

---

## 7.5 Comunicação via Fetch e Axios

### 7.5.1 A Fetch API nativa

A **Fetch API** é a interface nativa do navegador para requisições HTTP. Ela retorna Promises e é compatível com `async/await`:

```javascript
// Requisição GET
const resposta = await fetch('http://localhost:3000/api/usuarios');
const usuarios = await resposta.json();

// Verificação de erro HTTP (fetch não lança erro para 4xx/5xx)
if (!resposta.ok) {
  throw new Error(`Erro ${resposta.status}: ${resposta.statusText}`);
}

// Requisição POST com JSON
const novoUsuario = await fetch('http://localhost:3000/api/usuarios', {
  method:  'POST',
  headers: { 'Content-Type': 'application/json' },
  body:    JSON.stringify({ nome: 'Ana', email: 'ana@ex.com', senha: '12345678' }),
});

// Requisição PUT
await fetch(`http://localhost:3000/api/usuarios/${id}`, {
  method:  'PUT',
  headers: { 'Content-Type': 'application/json' },
  body:    JSON.stringify(dados),
});

// Requisição DELETE
await fetch(`http://localhost:3000/api/usuarios/${id}`, {
  method: 'DELETE',
});
```

### 7.5.2 Axios — cliente HTTP com mais recursos

O **Axios** é uma biblioteca que simplifica o trabalho com requisições HTTP, adicionando recursos ausentes na Fetch API nativa: lança exceções automaticamente para respostas 4xx e 5xx, serializa e desserializa JSON automaticamente, e suporta interceptors para adicionar cabeçalhos globais (como tokens JWT):

```bash
npm install axios
```

```javascript
import axios from 'axios';

// Instância configurada com URL base
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000/api',
  headers: { 'Content-Type': 'application/json' },
});

// Interceptor para adicionar o token JWT automaticamente
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Uso — muito mais limpo que fetch
const { data: usuarios } = await api.get('/usuarios');
const { data: novo }     = await api.post('/usuarios', { nome, email, senha });
const { data: atualizado } = await api.put(`/usuarios/${id}`, dados);
await api.delete(`/usuarios/${id}`);
```

### 7.5.3 Tratamento de erros HTTP no cliente

```javascript
// Padrão de tratamento de erros com Axios
try {
  const { data } = await api.get('/usuarios');
  return data;
} catch (erro) {
  if (erro.response) {
    // Servidor respondeu com status de erro (4xx, 5xx)
    const { status, data } = erro.response;
    console.error(`Erro ${status}:`, data.erro);
    throw new Error(data.erro || 'Erro na requisição');
  } else if (erro.request) {
    // Requisição enviada mas sem resposta (servidor offline, rede)
    throw new Error('Servidor indisponível. Verifique sua conexão.');
  } else {
    // Erro na configuração da requisição
    throw new Error('Erro ao configurar a requisição.');
  }
}
```

---

## 7.6 Vue.js — Fundamentos

### 7.6.1 O que é Vue.js e por que ele existe

O **Vue.js** é um framework JavaScript progressivo para construção de interfaces de usuário. Foi criado por Evan You em 2014 e encontra-se atualmente na versão 3 (Vue 3). O adjetivo "progressivo" é intencional: Vue pode ser adotado incrementalmente, desde a adição de interatividade a uma página HTML existente até a construção de uma SPA completa com roteamento e gerenciamento de estado.

O problema central que Vue — e frameworks de frontend em geral — resolve é o **gerenciamento da sincronização entre dados e interface**. Em JavaScript puro, quando um dado muda, o desenvolvedor precisa selecionar manualmente os elementos do DOM e atualizá-los. Em aplicações complexas, esse processo se torna tedioso, propenso a erros e difícil de manter. Vue introduz o conceito de **reatividade declarativa**: o desenvolvedor descreve *como* a interface deve parecer para um dado estado, e o framework se encarrega de atualizar o DOM automaticamente sempre que o estado muda.

```javascript
// JavaScript puro — imperativo, manual
const contador = 0;
document.getElementById('valor').textContent = contador;

function incrementar() {
  contador++;
  document.getElementById('valor').textContent = contador; // atualização manual
}

// Vue — declarativo, automático
const contador = ref(0); // estado reativo

// O template declara a aparência para qualquer valor de contador
// Vue atualiza o DOM automaticamente quando contador muda
```

### 7.6.2 Criando um projeto Vue com Vite

O **Vite** é a ferramenta de build recomendada para projetos Vue. Ele oferece um servidor de desenvolvimento extremamente rápido com Hot Module Replacement (HMR) — o navegador atualiza apenas o componente modificado sem recarregar a página:

```bash
# Cria um novo projeto Vue 3 com Vite
npm create vue@latest

# O assistente pergunta:
# ✔ Project name: frontend
# ✔ Add TypeScript? No
# ✔ Add JSX Support? No
# ✔ Add Vue Router? Yes
# ✔ Add Pinia? Yes
# ✔ Add Vitest? No (coberto no Cap. 9)
# ✔ Add ESLint? Yes

cd frontend
npm install
npm run dev   # inicia em http://localhost:5173
```

A estrutura gerada é a seguinte:

```
frontend/
├── public/             # Arquivos estáticos (favicon, etc.)
├── src/
│   ├── assets/         # CSS, imagens, fontes
│   ├── components/     # Componentes reutilizáveis
│   ├── router/
│   │   └── index.js    # Configuração do Vue Router
│   ├── stores/         # Stores do Pinia (estado global)
│   ├── views/          # Componentes de página (usados pelo router)
│   ├── App.vue         # Componente raiz
│   └── main.js         # Ponto de entrada
├── index.html
└── vite.config.js
```

### 7.6.3 Componentes de arquivo único (SFC)

A unidade fundamental do Vue é o **Single File Component** (SFC) — um arquivo `.vue` que encapsula template, lógica e estilo em um único lugar:

```vue
<!-- src/components/CartaoUsuario.vue -->
<template>
  <div class="cartao">
    <h3>{{ usuario.nome }}</h3>
    <p>{{ usuario.email }}</p>
    <button @click="$emit('excluir', usuario.id)">Excluir</button>
  </div>
</template>

<script setup>
// Composition API com <script setup> — forma recomendada no Vue 3
defineProps({
  usuario: {
    type:     Object,
    required: true,
  },
});

defineEmits(['excluir']);
</script>

<style scoped>
/* scoped: estilos se aplicam APENAS a este componente */
.cartao {
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 1rem;
}
</style>
```

A tag `<script setup>` é a sintaxe moderna da **Composition API** — ela simplifica a escrita de componentes e é a abordagem recomendada para projetos Vue 3 novos.

### 7.6.4 Reatividade: `ref` e `reactive`

O sistema de reatividade do Vue é o coração do framework. Quando um valor reativo muda, todos os templates e computed values que dependem dele são automaticamente atualizados.

`ref()` é usado para valores primitivos (números, strings, booleans) e para qualquer valor que precise ser substituído por completo:

```vue
<script setup>
import { ref } from 'vue';

const contador = ref(0);
const nome     = ref('');
const carregando = ref(false);

// Acessar ou modificar o valor: use .value em JS
function incrementar() {
  contador.value++;
}
</script>

<template>
  <!-- No template, .value é desnecessário — Vue desempacota automaticamente -->
  <p>Contador: {{ contador }}</p>
  <button @click="incrementar">+1</button>
  <input v-model="nome" placeholder="Seu nome">
  <p>Olá, {{ nome }}!</p>
</template>
```

`reactive()` é usado para objetos — a reatividade se propaga para todas as propriedades aninhadas:

```vue
<script setup>
import { reactive } from 'vue';

const form = reactive({
  nome:  '',
  email: '',
  senha: '',
});

function limparForm() {
  // Modifica propriedades diretamente — sem .value
  form.nome  = '';
  form.email = '';
  form.senha = '';
}
</script>

<template>
  <input v-model="form.nome"  placeholder="Nome">
  <input v-model="form.email" placeholder="E-mail">
  <input v-model="form.senha" type="password">
</template>
```

### 7.6.5 Computed e Watch

**`computed()`** cria valores derivados que são recalculados automaticamente quando suas dependências mudam, com cache:

```vue
<script setup>
import { ref, computed } from 'vue';

const usuarios = ref([
  { id: 1, nome: 'Ana Silva',   ativo: true  },
  { id: 2, nome: 'Bruno Costa', ativo: false },
  { id: 3, nome: 'Carla Dias',  ativo: true  },
]);

const busca = ref('');

// Recalculado apenas quando usuarios ou busca mudam
const usuariosFiltrados = computed(() =>
  usuarios.value.filter(u =>
    u.nome.toLowerCase().includes(busca.value.toLowerCase()) && u.ativo
  )
);
</script>

<template>
  <input v-model="busca" placeholder="Buscar...">
  <p>{{ usuariosFiltrados.length }} usuários encontrados</p>
</template>
```

**`watch()`** executa uma função quando um valor reativo muda — ideal para efeitos colaterais como requisições à API:

```vue
<script setup>
import { ref, watch } from 'vue';

const pagina = ref(1);
const usuarios = ref([]);

// Executa a busca sempre que a página muda
watch(pagina, async (novaPagina) => {
  const { data } = await api.get(`/usuarios?pagina=${novaPagina}`);
  usuarios.value = data.dados;
});
</script>
```

### 7.6.6 Diretivas essenciais

As **diretivas** são atributos especiais com prefixo `v-` que adicionam comportamento reativo aos elementos HTML:

```vue
<template>
  <!-- v-bind: vincula um atributo a uma expressão JS (forma abreviada: :) -->
  <img :src="usuario.avatar" :alt="usuario.nome">
  <button :disabled="carregando">Salvar</button>

  <!-- v-model: two-way binding para inputs -->
  <input v-model="nome">
  <select v-model="categoria">
    <option value="admin">Admin</option>
    <option value="user">Usuário</option>
  </select>

  <!-- v-if / v-else-if / v-else: renderização condicional -->
  <div v-if="carregando">Carregando...</div>
  <div v-else-if="erro">Erro: {{ erro }}</div>
  <div v-else>
    <!-- conteúdo principal -->
  </div>

  <!-- v-show: alterna visibilidade (mantém no DOM — mais eficiente para toggle frequente) -->
  <div v-show="menuAberto">Menu</div>

  <!-- v-for: renderização de listas (sempre use :key) -->
  <ul>
    <li v-for="usuario in usuarios" :key="usuario.id">
      {{ usuario.nome }}
    </li>
  </ul>

  <!-- v-on: escuta eventos (forma abreviada: @) -->
  <button @click="salvar">Salvar</button>
  <form @submit.prevent="enviarForm">  <!-- .prevent chama event.preventDefault() -->
    <input @keyup.enter="buscar">      <!-- .enter filtra pelo código da tecla Enter -->
  </form>
</template>
```

### 7.6.7 Ciclo de vida do componente

O Vue oferece hooks de ciclo de vida que permitem executar código em momentos específicos da vida de um componente. O mais utilizado é `onMounted`, que executa após o componente ser inserido no DOM — ideal para carregar dados da API:

```vue
<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { api } from '../services/api.js';

const usuarios = ref([]);
const carregando = ref(true);
const erro = ref(null);

onMounted(async () => {
  try {
    const { data } = await api.get('/usuarios');
    usuarios.value = data;
  } catch (e) {
    erro.value = e.message;
  } finally {
    carregando.value = false;
  }
});

// Executado quando o componente é removido do DOM
onUnmounted(() => {
  // Cancelar timers, subscriptions, etc.
});
</script>
```

### 7.6.8 Props e Emits — comunicação entre componentes

A comunicação entre componentes segue um fluxo unidirecional: o pai passa dados para o filho via **props**, e o filho notifica o pai via **emits**:

```vue
<!-- Componente pai: VisualizacaoUsuarios.vue -->
<template>
  <CartaoUsuario
    v-for="u in usuarios"
    :key="u.id"
    :usuario="u"
    @excluir="excluirUsuario"
    @editar="abrirEdicao"
  />
</template>

<script setup>
import CartaoUsuario from './CartaoUsuario.vue';

async function excluirUsuario(id) {
  await api.delete(`/usuarios/${id}`);
  usuarios.value = usuarios.value.filter(u => u.id !== id);
}
</script>
```

```vue
<!-- Componente filho: CartaoUsuario.vue -->
<script setup>
const props = defineProps({
  usuario: { type: Object, required: true },
});

const emit = defineEmits(['excluir', 'editar']);
</script>

<template>
  <div class="cartao">
    <h3>{{ usuario.nome }}</h3>
    <button @click="emit('editar', usuario)">Editar</button>
    <button @click="emit('excluir', usuario.id)">Excluir</button>
  </div>
</template>
```

### 7.6.9 Vue Router

O **Vue Router** é o roteador oficial do Vue. Ele mapeia URLs a componentes de página, permitindo navegação sem recarregamento:

```javascript
// src/router/index.js
import { createRouter, createWebHistory } from 'vue-router';
import HomeView      from '../views/HomeView.vue';
import UsuariosView  from '../views/UsuariosView.vue';
import UsuarioView   from '../views/UsuarioView.vue';

const router = createRouter({
  history: createWebHistory(),  // URLs limpas: /usuarios em vez de /#/usuarios
  routes: [
    { path: '/',              component: HomeView      },
    { path: '/usuarios',      component: UsuariosView  },
    { path: '/usuarios/:id',  component: UsuarioView   },
    { path: '/:pathMatch(.*)*', redirect: '/' },  // 404 → home
  ],
});

export default router;
```

```vue
<!-- Navegação em templates -->
<template>
  <nav>
    <RouterLink to="/">Home</RouterLink>
    <RouterLink to="/usuarios">Usuários</RouterLink>
  </nav>

  <!-- Onde o componente da rota atual é renderizado -->
  <RouterView />
</template>

<script setup>
// Acesso ao router e à rota atual em componentes
import { useRouter, useRoute } from 'vue-router';

const router = useRouter();
const route  = useRoute();

const id = route.params.id;           // parâmetro da URL

router.push('/usuarios');             // navegação programática
router.push(`/usuarios/${novoId}`);   // com parâmetro
</script>
```

### 7.6.10 Pinia — gerenciamento de estado global

O **Pinia** é a biblioteca oficial de gerenciamento de estado do Vue 3. Enquanto props/emits são suficientes para comunicação entre componentes próximos, o Pinia resolve o problema do estado compartilhado entre partes distantes da aplicação (como o usuário autenticado, que precisa estar disponível em qualquer componente):

```javascript
// src/stores/usuarios.store.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { api } from '../services/api.js';

export const useUsuariosStore = defineStore('usuarios', () => {
  // Estado
  const lista       = ref([]);
  const carregando  = ref(false);
  const erro        = ref(null);

  // Getters (computed)
  const total = computed(() => lista.value.length);

  // Actions
  async function buscarTodos() {
    carregando.value = true;
    erro.value = null;
    try {
      const { data } = await api.get('/usuarios');
      lista.value = data;
    } catch (e) {
      erro.value = e.message;
    } finally {
      carregando.value = false;
    }
  }

  async function criar(dados) {
    const { data } = await api.post('/usuarios', dados);
    lista.value.push(data);
    return data;
  }

  async function remover(id) {
    await api.delete(`/usuarios/${id}`);
    lista.value = lista.value.filter(u => u.id !== id);
  }

  return { lista, carregando, erro, total, buscarTodos, criar, remover };
});
```

```vue
<!-- Usando a store em qualquer componente -->
<script setup>
import { onMounted }         from 'vue';
import { useUsuariosStore }  from '../stores/usuarios.store.js';

const store = useUsuariosStore();
onMounted(() => store.buscarTodos());
</script>

<template>
  <p v-if="store.carregando">Carregando...</p>
  <p v-else-if="store.erro">{{ store.erro }}</p>
  <ul v-else>
    <li v-for="u in store.lista" :key="u.id">
      {{ u.nome }}
      <button @click="store.remover(u.id)">Excluir</button>
    </li>
  </ul>
</template>
```

### 7.6.11 Options API vs. Composition API

O Vue oferece duas formas de escrever componentes, e é importante conhecer ambas pois você as encontrará em projetos reais:

A **Options API** organiza o código em opções predefinidas (`data`, `methods`, `computed`, `watch`). É a forma clássica, mais familiar para quem vem de orientação a objetos, e ainda amplamente utilizada em projetos Vue 2 e Vue 3 legados:

```vue
<!-- Options API — Vue 2 e Vue 3 -->
<script>
export default {
  name: 'ListaUsuarios',
  data() {
    return { usuarios: [], carregando: true };
  },
  computed: {
    total() { return this.usuarios.length; }
  },
  methods: {
    async buscar() {
      const { data } = await api.get('/usuarios');
      this.usuarios = data;
    }
  },
  async mounted() {
    await this.buscar();
    this.carregando = false;
  }
};
</script>
```

A **Composition API** com `<script setup>` organiza o código por **funcionalidade lógica**, não por tipo. É a forma recomendada para Vue 3 — mais flexível, mais testável e com melhor suporte a TypeScript:

```vue
<!-- Composition API com <script setup> — Vue 3 recomendado -->
<script setup>
import { ref, computed, onMounted } from 'vue';

const usuarios   = ref([]);
const carregando = ref(true);
const total      = computed(() => usuarios.value.length);

onMounted(async () => {
  const { data } = await api.get('/usuarios');
  usuarios.value = data;
  carregando.value = false;
});
</script>
```

Para projetos novos, utilize sempre a Composition API com `<script setup>`. Para manutenção de projetos existentes com Options API, o conhecimento de ambas é necessário.

---

## 7.7 Vue.js — Consumindo a API do Express

Esta seção implementa um CRUD completo de usuários em Vue.js, consumindo a API construída nos Capítulos 3 a 5. O backend permanece inalterado.

### 7.7.1 Configuração do serviço de API

```javascript
// src/services/api.js
import axios from 'axios';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000/api',
});
```

```bash
# frontend/.env.local (não versionar)
VITE_API_URL=http://localhost:3000/api
```

### 7.7.2 Store de usuários

```javascript
// src/stores/usuarios.store.js
import { defineStore } from 'pinia';
import { ref }         from 'vue';
import { api }         from '../services/api.js';

export const useUsuariosStore = defineStore('usuarios', () => {
  const lista      = ref([]);
  const carregando = ref(false);
  const erro       = ref(null);

  async function buscarTodos() {
    carregando.value = true;
    erro.value = null;
    try {
      const { data } = await api.get('/usuarios');
      lista.value = data;
    } catch (e) {
      erro.value = e.response?.data?.erro ?? e.message;
    } finally {
      carregando.value = false;
    }
  }

  async function buscarPorId(id) {
    const { data } = await api.get(`/usuarios/${id}`);
    return data;
  }

  async function criar(dados) {
    const { data } = await api.post('/usuarios', dados);
    lista.value.push(data);
    return data;
  }

  async function atualizar(id, dados) {
    const { data } = await api.put(`/usuarios/${id}`, dados);
    const idx = lista.value.findIndex(u => u.id === id);
    if (idx !== -1) lista.value[idx] = data;
    return data;
  }

  async function remover(id) {
    await api.delete(`/usuarios/${id}`);
    lista.value = lista.value.filter(u => u.id !== id);
  }

  return { lista, carregando, erro, buscarTodos, buscarPorId, criar, atualizar, remover };
});
```

### 7.7.3 Listagem de usuários

```vue
<!-- src/views/UsuariosView.vue -->
<script setup>
import { onMounted, ref }       from 'vue';
import { useRouter }            from 'vue-router';
import { useUsuariosStore }     from '../stores/usuarios.store.js';

const store  = useUsuariosStore();
const router = useRouter();

onMounted(() => store.buscarTodos());

async function confirmarExclusao(usuario) {
  if (!confirm(`Excluir ${usuario.nome}?`)) return;
  try {
    await store.remover(usuario.id);
  } catch (e) {
    alert(e.response?.data?.erro ?? 'Erro ao excluir');
  }
}
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Usuários</h1>
      <RouterLink to="/usuarios/novo" class="btn btn-primary">
        Novo Usuário
      </RouterLink>
    </div>

    <div v-if="store.carregando" class="estado-vazio">Carregando...</div>
    <div v-else-if="store.erro"  class="alerta alerta-erro">{{ store.erro }}</div>
    <div v-else-if="store.lista.length === 0" class="estado-vazio">
      Nenhum usuário cadastrado.
    </div>
    <table v-else class="tabela">
      <thead>
        <tr><th>Nome</th><th>E-mail</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="u in store.lista" :key="u.id">
          <td>{{ u.nome }}</td>
          <td>{{ u.email }}</td>
          <td class="acoes">
            <RouterLink :to="`/usuarios/${u.id}/editar`">Editar</RouterLink>
            <button @click="confirmarExclusao(u)" class="btn-link-perigo">
              Excluir
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
```

### 7.7.4 Formulário de criação e edição

```vue
<!-- src/views/UsuarioFormView.vue — usado para criar e editar -->
<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter }      from 'vue-router';
import { useUsuariosStore }         from '../stores/usuarios.store.js';

const route  = useRoute();
const router = useRouter();
const store  = useUsuariosStore();

const modoEdicao = computed(() => !!route.params.id);
const titulo     = computed(() => modoEdicao.value ? 'Editar Usuário' : 'Novo Usuário');

const form = ref({ nome: '', email: '', senha: '' });
const erros = ref([]);
const salvando = ref(false);

onMounted(async () => {
  if (modoEdicao.value) {
    const usuario = await store.buscarPorId(Number(route.params.id));
    form.value.nome  = usuario.nome;
    form.value.email = usuario.email;
    // senha não é pré-preenchida por segurança
  }
});

async function salvar() {
  erros.value = [];
  salvando.value = true;
  try {
    if (modoEdicao.value) {
      await store.atualizar(Number(route.params.id), form.value);
    } else {
      await store.criar(form.value);
    }
    router.push('/usuarios');
  } catch (e) {
    const msg = e.response?.data?.erro ?? e.message;
    erros.value = [msg];
  } finally {
    salvando.value = false;
  }
}
</script>

<template>
  <div class="form-container">
    <h1>{{ titulo }}</h1>

    <div v-if="erros.length > 0" class="alerta alerta-erro">
      <p v-for="erro in erros" :key="erro">{{ erro }}</p>
    </div>

    <form @submit.prevent="salvar" novalidate>
      <div class="form-grupo">
        <label for="nome">Nome</label>
        <input id="nome" v-model="form.nome" type="text" required>
      </div>
      <div class="form-grupo">
        <label for="email">E-mail</label>
        <input id="email" v-model="form.email" type="email" required>
      </div>
      <div class="form-grupo" v-if="!modoEdicao">
        <label for="senha">Senha</label>
        <input id="senha" v-model="form.senha" type="password" required>
      </div>
      <div class="form-acoes">
        <RouterLink to="/usuarios" class="btn btn-secundario">Cancelar</RouterLink>
        <button type="submit" class="btn btn-primario" :disabled="salvando">
          {{ salvando ? 'Salvando...' : 'Salvar' }}
        </button>
      </div>
    </form>
  </div>
</template>
```

### 7.7.5 Configuração das rotas

```javascript
// src/router/index.js
import { createRouter, createWebHistory } from 'vue-router';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/',                    redirect: '/usuarios' },
    { path: '/usuarios',            component: () => import('../views/UsuariosView.vue') },
    { path: '/usuarios/novo',       component: () => import('../views/UsuarioFormView.vue') },
    { path: '/usuarios/:id/editar', component: () => import('../views/UsuarioFormView.vue') },
    { path: '/:pathMatch(.*)*',     redirect: '/usuarios' },
  ],
});

export default router;
```

!!! note "Lazy loading com `import()`"
    O uso de `() => import(...)` nas rotas habilita o **code splitting** automático do Vite: cada view é carregada apenas quando o usuário navega para ela, reduzindo o tamanho do bundle inicial.

---

## 7.8 React — Fundamentos

### 7.8.1 O que é React e por que ele existe

O **React** é uma biblioteca JavaScript para construção de interfaces de usuário criada pelo Facebook (Meta) em 2013 e mantida como open source. Diferentemente do Vue, que se apresenta como um framework progressivo com opiniões sobre roteamento e estado, o React é deliberadamente focado apenas na **camada de view** — deixando decisões como roteamento e gerenciamento de estado para bibliotecas de terceiros.

O conceito central do React é o **componente**: uma função JavaScript que recebe dados de entrada (denominados *props*) e retorna uma descrição da interface que deve ser renderizada. Essa descrição é escrita em **JSX** — uma extensão de sintaxe que permite escrever HTML dentro do JavaScript. O React compara a descrição anterior com a nova (através de um algoritmo denominado *reconciliação* com o *Virtual DOM*) e atualiza apenas as partes do DOM real que mudaram.

```jsx
// React — componente é uma função que retorna JSX
function CartaoUsuario({ usuario, onExcluir }) {
  return (
    <div className="cartao">
      <h3>{usuario.nome}</h3>
      <p>{usuario.email}</p>
      <button onClick={() => onExcluir(usuario.id)}>Excluir</button>
    </div>
  );
}
```

### 7.8.2 Criando um projeto React com Vite

```bash
# Cria um projeto React com Vite
npm create vite@latest frontend -- --template react

cd frontend
npm install
npm install react-router-dom axios  # bibliotecas essenciais
npm run dev   # inicia em http://localhost:5173
```

A estrutura gerada:

```
frontend/
├── public/
├── src/
│   ├── assets/
│   ├── components/   # Componentes reutilizáveis
│   ├── pages/        # Componentes de página (convenção comum)
│   ├── services/     # Configuração do Axios
│   ├── App.jsx       # Componente raiz com rotas
│   └── main.jsx      # Ponto de entrada
├── index.html
└── vite.config.js
```

### 7.8.3 JSX — HTML dentro do JavaScript

O **JSX** é uma extensão de sintaxe que parece HTML mas é compilada para chamadas JavaScript. Algumas diferenças importantes em relação ao HTML:

```jsx
// Diferenças JSX vs HTML
function Exemplo({ usuario, ativo }) {
  return (
    <div
      className="cartao"          // class → className (class é palavra reservada em JS)
      style={{ color: 'blue' }}   // style recebe objeto JS, não string CSS
    >
      {/* Comentários em JSX são assim */}
      <h3>{usuario.nome}</h3>                     {/* expressões JS entre chaves */}
      <p>{ativo ? 'Ativo' : 'Inativo'}</p>        {/* ternário para condicionais */}
      <input htmlFor="nome" />                     {/* for → htmlFor */}
      <img src={usuario.avatar} alt={usuario.nome} /> {/* tags self-closing */}
    </div>
  );
}
```

Um componente React deve sempre retornar **um único elemento raiz**. Para evitar `<div>` desnecessárias no DOM, usa-se o **Fragment**:

```jsx
// Fragment: agrupa sem adicionar elemento ao DOM
function ListaInfo({ usuario }) {
  return (
    <>
      <dt>Nome</dt>
      <dd>{usuario.nome}</dd>
      <dt>E-mail</dt>
      <dd>{usuario.email}</dd>
    </>
  );
}
```

### 7.8.4 useState — estado local do componente

O hook `useState` adiciona estado a um componente funcional. Ele retorna um par: o valor atual e uma função para atualizá-lo:

```jsx
import { useState } from 'react';

function Contador() {
  // [valorAtual, funcaoDeAtualização] = useState(valorInicial)
  const [contador, setContador] = useState(0);
  const [nome, setNome]         = useState('');

  return (
    <div>
      <p>Contador: {contador}</p>
      <button onClick={() => setContador(c => c + 1)}>+1</button>

      <input
        value={nome}
        onChange={e => setNome(e.target.value)}  // onChange é obrigatório para inputs controlados
        placeholder="Seu nome"
      />
      <p>Olá, {nome}!</p>
    </div>
  );
}
```

!!! warning "Nunca mute o estado diretamente"
    Em React, o estado é imutável. Nunca faça `lista.push(item)` — crie sempre um novo array: `setLista([...lista, item])`. A imutabilidade é o que permite ao React detectar mudanças eficientemente.

```jsx
// ❌ Mutação direta — React não detecta a mudança
usuarios.push(novoUsuario);
setUsuarios(usuarios);

// ✅ Novo array — React detecta e re-renderiza
setUsuarios([...usuarios, novoUsuario]);

// ✅ Remoção imutável
setUsuarios(usuarios.filter(u => u.id !== id));

// ✅ Atualização imutável
setUsuarios(usuarios.map(u => u.id === id ? { ...u, ...dados } : u));
```

### 7.8.5 useEffect — efeitos colaterais

O hook `useEffect` executa código após a renderização — é o lugar correto para buscar dados da API, configurar timers ou se inscrever em eventos externos:

```jsx
import { useState, useEffect } from 'react';

function ListaUsuarios() {
  const [usuarios,   setUsuarios]   = useState([]);
  const [carregando, setCarregando] = useState(true);
  const [erro,       setErro]       = useState(null);

  useEffect(() => {
    // A função passada para useEffect NÃO pode ser async diretamente
    // Declara e chama uma função async dentro
    async function buscar() {
      try {
        const { data } = await api.get('/usuarios');
        setUsuarios(data);
      } catch (e) {
        setErro(e.response?.data?.erro ?? e.message);
      } finally {
        setCarregando(false);
      }
    }

    buscar();
  }, []); // Array de dependências vazio → executa apenas na montagem (equivale ao onMounted do Vue)

  if (carregando) return <p>Carregando...</p>;
  if (erro)       return <p className="erro">{erro}</p>;

  return (
    <ul>
      {usuarios.map(u => <li key={u.id}>{u.nome}</li>)}
    </ul>
  );
}
```

O segundo argumento de `useEffect` é o **array de dependências**:

```jsx
useEffect(() => { /* executa uma vez na montagem */ }, []);
useEffect(() => { /* executa quando pagina muda  */ }, [pagina]);
useEffect(() => { /* executa após toda renderização */ });        // sem array
```

### 7.8.6 Props — comunicação pai → filho

Em React, os dados fluem do pai para o filho através de **props** — atributos passados ao componente como se fossem atributos HTML:

```jsx
// Componente filho
function CartaoUsuario({ usuario, onEditar, onExcluir }) {
  return (
    <div className="cartao">
      <h3>{usuario.nome}</h3>
      <p>{usuario.email}</p>
      <button onClick={() => onEditar(usuario)}>Editar</button>
      <button onClick={() => onExcluir(usuario.id)}>Excluir</button>
    </div>
  );
}

// Componente pai
function ListaUsuarios() {
  const [usuarios, setUsuarios] = useState([]);

  function handleExcluir(id) {
    setUsuarios(prev => prev.filter(u => u.id !== id));
  }

  return (
    <div>
      {usuarios.map(u => (
        <CartaoUsuario
          key={u.id}
          usuario={u}
          onEditar={handleEditar}
          onExcluir={handleExcluir}
        />
      ))}
    </div>
  );
}
```

### 7.8.7 Renderização condicional e listas

```jsx
function ConteudoUsuarios({ carregando, erro, usuarios }) {
  // Retorno antecipado para estados especiais
  if (carregando) return <div className="spinner">Carregando...</div>;
  if (erro)       return <div className="alerta-erro">{erro}</div>;
  if (usuarios.length === 0) return <p>Nenhum usuário cadastrado.</p>;

  return (
    <table>
      <tbody>
        {usuarios.map(u => (
          <tr key={u.id}>
            <td>{u.nome}</td>
            <td>{u.email}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// Condicional inline com && (cuidado: 0 && <X/> renderiza 0)
{usuarios.length > 0 && <p>{usuarios.length} usuários</p>}

// Ternário para duas alternativas
{modoEdicao ? <FormularioEdicao /> : <FormularioCriacao />}
```

### 7.8.8 React Router DOM

O **React Router** é a biblioteca de roteamento mais utilizada no ecossistema React:

```jsx
// src/App.jsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import UsuariosPage    from './pages/UsuariosPage.jsx';
import UsuarioFormPage from './pages/UsuarioFormPage.jsx';
import Navbar          from './components/Navbar.jsx';

function App() {
  return (
    <BrowserRouter>
      <Navbar />
      <main className="container">
        <Routes>
          <Route path="/"                      element={<Navigate to="/usuarios" replace />} />
          <Route path="/usuarios"              element={<UsuariosPage />} />
          <Route path="/usuarios/novo"         element={<UsuarioFormPage />} />
          <Route path="/usuarios/:id/editar"   element={<UsuarioFormPage />} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}

export default App;
```

```jsx
// Navegação e acesso a parâmetros em componentes
import { Link, useNavigate, useParams } from 'react-router-dom';

function UsuarioFormPage() {
  const { id }     = useParams();     // parâmetro da URL
  const navigate   = useNavigate();   // navegação programática
  const modoEdicao = !!id;

  async function salvar(dados) {
    // ...
    navigate('/usuarios');            // redireciona após salvar
  }

  return (
    <div>
      <Link to="/usuarios">← Voltar</Link>
      {/* ... */}
    </div>
  );
}
```

### 7.8.9 Context API — estado global sem biblioteca extra

O **Context** do React permite compartilhar dados entre componentes sem passar props manualmente em cada nível da árvore. É adequado para dados simples como o tema, o idioma ou o usuário autenticado:

```jsx
// src/contexts/UsuariosContext.jsx
import { createContext, useContext, useState, useCallback } from 'react';
import { api } from '../services/api.js';

const UsuariosContext = createContext(null);

// Provider — envolve os componentes que precisam do contexto
export function UsuariosProvider({ children }) {
  const [lista,      setLista]      = useState([]);
  const [carregando, setCarregando] = useState(false);
  const [erro,       setErro]       = useState(null);

  const buscarTodos = useCallback(async () => {
    setCarregando(true);
    setErro(null);
    try {
      const { data } = await api.get('/usuarios');
      setLista(data);
    } catch (e) {
      setErro(e.response?.data?.erro ?? e.message);
    } finally {
      setCarregando(false);
    }
  }, []);

  const criar = useCallback(async (dados) => {
    const { data } = await api.post('/usuarios', dados);
    setLista(prev => [...prev, data]);
    return data;
  }, []);

  const remover = useCallback(async (id) => {
    await api.delete(`/usuarios/${id}`);
    setLista(prev => prev.filter(u => u.id !== id));
  }, []);

  return (
    <UsuariosContext.Provider value={{ lista, carregando, erro, buscarTodos, criar, remover }}>
      {children}
    </UsuariosContext.Provider>
  );
}

// Hook customizado para consumir o contexto
export function useUsuarios() {
  const ctx = useContext(UsuariosContext);
  if (!ctx) throw new Error('useUsuarios deve ser usado dentro de UsuariosProvider');
  return ctx;
}
```

```jsx
// src/main.jsx — envolve a aplicação com o Provider
import { UsuariosProvider } from './contexts/UsuariosContext.jsx';

ReactDOM.createRoot(document.getElementById('root')).render(
  <UsuariosProvider>
    <App />
  </UsuariosProvider>
);
```

---

## 7.9 React — Consumindo a API do Express

Esta seção implementa o mesmo CRUD de usuários do item 7.7, desta vez em React. O backend Express não muda — apenas o cliente é diferente.

### 7.9.1 Página de listagem

```jsx
// src/pages/UsuariosPage.jsx
import { useEffect }     from 'react';
import { Link }          from 'react-router-dom';
import { useUsuarios }   from '../contexts/UsuariosContext.jsx';

export default function UsuariosPage() {
  const { lista, carregando, erro, buscarTodos, remover } = useUsuarios();

  useEffect(() => { buscarTodos(); }, [buscarTodos]);

  async function handleExcluir(usuario) {
    if (!confirm(`Excluir ${usuario.nome}?`)) return;
    try {
      await remover(usuario.id);
    } catch (e) {
      alert(e.message);
    }
  }

  if (carregando) return <p>Carregando...</p>;
  if (erro)       return <p className="alerta-erro">{erro}</p>;

  return (
    <div>
      <div className="page-header">
        <h1>Usuários</h1>
        <Link to="/usuarios/novo" className="btn btn-primario">Novo Usuário</Link>
      </div>

      {lista.length === 0 ? (
        <p>Nenhum usuário cadastrado.</p>
      ) : (
        <table className="tabela">
          <thead>
            <tr><th>Nome</th><th>E-mail</th><th></th></tr>
          </thead>
          <tbody>
            {lista.map(u => (
              <tr key={u.id}>
                <td>{u.nome}</td>
                <td>{u.email}</td>
                <td className="acoes">
                  <Link to={`/usuarios/${u.id}/editar`}>Editar</Link>
                  <button onClick={() => handleExcluir(u)} className="btn-link-perigo">
                    Excluir
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
```

### 7.9.2 Formulário de criação e edição

```jsx
// src/pages/UsuarioFormPage.jsx
import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useUsuarios } from '../contexts/UsuariosContext.jsx';
import { api }         from '../services/api.js';

export default function UsuarioFormPage() {
  const { id }     = useParams();
  const navigate   = useNavigate();
  const { criar }  = useUsuarios();

  const modoEdicao = !!id;

  const [form, setForm]       = useState({ nome: '', email: '', senha: '' });
  const [erros, setErros]     = useState([]);
  const [salvando, setSalvando] = useState(false);

  useEffect(() => {
    if (!modoEdicao) return;
    api.get(`/usuarios/${id}`).then(({ data }) => {
      setForm({ nome: data.nome, email: data.email, senha: '' });
    });
  }, [id, modoEdicao]);

  function handleChange(e) {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setErros([]);
    setSalvando(true);
    try {
      if (modoEdicao) {
        await api.put(`/usuarios/${id}`, form);
      } else {
        await criar(form);
      }
      navigate('/usuarios');
    } catch (e) {
      setErros([e.response?.data?.erro ?? e.message]);
    } finally {
      setSalvando(false);
    }
  }

  return (
    <div className="form-container">
      <h1>{modoEdicao ? 'Editar Usuário' : 'Novo Usuário'}</h1>

      {erros.length > 0 && (
        <div className="alerta alerta-erro">
          {erros.map(e => <p key={e}>{e}</p>)}
        </div>
      )}

      <form onSubmit={handleSubmit} noValidate>
        <div className="form-grupo">
          <label htmlFor="nome">Nome</label>
          <input id="nome" name="nome" value={form.nome} onChange={handleChange} required />
        </div>
        <div className="form-grupo">
          <label htmlFor="email">E-mail</label>
          <input id="email" name="email" type="email" value={form.email} onChange={handleChange} required />
        </div>
        {!modoEdicao && (
          <div className="form-grupo">
            <label htmlFor="senha">Senha</label>
            <input id="senha" name="senha" type="password" value={form.senha} onChange={handleChange} required />
          </div>
        )}
        <div className="form-acoes">
          <Link to="/usuarios" className="btn btn-secundario">Cancelar</Link>
          <button type="submit" className="btn btn-primario" disabled={salvando}>
            {salvando ? 'Salvando...' : 'Salvar'}
          </button>
        </div>
      </form>
    </div>
  );
}
```

---

## 7.10 Variáveis de Ambiente e Configuração

### 7.10.1 Variáveis de ambiente no backend

```bash
# backend/.env
NODE_ENV=development
PORT=3000
DATABASE_URL="file:./dev.db"
FRONTEND_URL=http://localhost:5173
```

```javascript
// backend/src/app.js
app.use(cors({
  origin: process.env.FRONTEND_URL,
  credentials: true,
}));
```

### 7.10.2 Variáveis de ambiente no frontend (Vite)

No Vite, variáveis de ambiente devem ter o prefixo `VITE_` para serem expostas ao código do frontend. Variáveis sem esse prefixo são invisíveis ao bundle:

```bash
# frontend/.env.local (nunca versionar — adicionar ao .gitignore)
VITE_API_URL=http://localhost:3000/api

# frontend/.env.production
VITE_API_URL=https://minha-api.railway.app/api
```

```javascript
// Acesso no código do frontend
const baseURL = import.meta.env.VITE_API_URL;
const isDev   = import.meta.env.DEV;    // true em desenvolvimento
const isProd  = import.meta.env.PROD;   // true na build de produção
```

!!! warning "Segurança nas variáveis de ambiente"
    Variáveis com prefixo `VITE_` são embutidas no bundle JavaScript e ficam visíveis no código do navegador. Nunca coloque segredos (chaves de API, senhas) em variáveis `VITE_`. Segredos pertencem exclusivamente ao backend.

---

## 7.11 Comparativo: SSR · SPA · Híbrido

Com os três capítulos de frontend concluídos, é possível traçar um comparativo abrangente entre as arquiteturas estudadas e as soluções híbridas que combinam suas vantagens:

### 7.11.1 Quadro comparativo

| Critério | SSR com EJS (Cap. 6) | SPA com Vue/React (Cap. 7) | Híbrido (Next.js / Nuxt) |
|---|---|---|---|
| Carregamento inicial | Rápido (HTML pronto) | Mais lento (bundle JS) | Rápido (SSR no 1º acesso) |
| Navegação subsequente | Recarrega a página | Fluida, sem recarga | Fluida (hidratação) |
| SEO | Excelente | Requer configuração | Excelente por padrão |
| Complexidade | Baixa (1 projeto) | Média (2 projetos) | Alta (1 projeto integrado) |
| Equipe | Só backend | Backend + Frontend | Full-stack |
| Interatividade | Limitada | Rica e responsiva | Rica e responsiva |
| Estado global | Sessão no servidor | Pinia / Context API | Depende da implementação |
| Deploy | Servidor único | Frontend em CDN + API | Plataforma específica (Vercel, Netlify) |

### 7.11.2 Quando escolher cada arquitetura

**SSR com EJS** é a escolha certa quando a equipe é predominantemente backend, o projeto tem prazo curto, a interatividade necessária é mínima (formulários simples, listagens) e SEO é crítico. Painéis administrativos internos, CMSs simples e MVPs de validação são casos de uso ideais.

**SPA com Vue.js ou React** é a escolha certa quando a interface precisa ser altamente responsiva e interativa, quando a equipe é dividida entre frontend e backend, ou quando o mesmo backend precisa servir múltiplos clientes (web, mobile, parceiros via API). Dashboards em tempo real, aplicações de produtividade e marketplaces são exemplos adequados.

**Frameworks híbridos** — Next.js para React, Nuxt para Vue — combinam SSR e SPA em um único projeto. A primeira renderização ocorre no servidor (excelente para SEO e performance percebida), e as navegações subsequentes são gerenciadas pelo cliente (experiência fluida). São a escolha para projetos que exigem ao mesmo tempo alta interatividade e SEO — e-commerces, portais de notícias e plataformas SaaS públicas.

### 7.11.3 A posição do Express em cada cenário

Independentemente da arquitetura de frontend escolhida, o Express permanece relevante:

- Em SSR com EJS, o Express renderiza o HTML completo.
- Em SPA, o Express serve como API REST pura.
- Em frameworks híbridos, o Express pode ser substituído pelo servidor interno do Next.js/Nuxt, mas continua sendo uma opção válida como API separada.

O conhecimento de Express construído ao longo deste curso é, portanto, aplicável a qualquer uma dessas arquiteturas.

---

## 7.12 Exercícios Práticos

### Exercício 7.1 — Configuração de CORS

Configure o CORS no projeto backend do Capítulo 5 para aceitar requisições de `http://localhost:5173`. Verifique a configuração usando o DevTools do navegador (aba Network) para confirmar que os cabeçalhos `Access-Control-Allow-Origin` aparecem nas respostas da API.

### Exercício 7.2 — Vue.js: listagem de produtos

Crie um projeto Vue com Vite e implemente uma página que liste os produtos retornados pelo endpoint `GET /api/produtos` da sua API. A página deve exibir um indicador de carregamento enquanto os dados chegam e uma mensagem amigável caso a lista esteja vazia. Use Pinia para gerenciar o estado.

### Exercício 7.3 — Vue.js: formulário de criação

Adicione ao exercício anterior um formulário para criar um novo produto com os campos `nome` e `preco`. O formulário deve exibir os erros retornados pela API (por exemplo, nome duplicado) e redirecionar para a listagem após a criação bem-sucedida.

### Exercício 7.4 — React: listagem de produtos

Reimplemente os exercícios 7.2 e 7.3 usando React. Utilize `useState` e `useEffect` para gerenciar o estado e o ciclo de vida, e Context API para compartilhar os dados entre os componentes. Observe que o backend não precisa ser modificado.

### Exercício 7.5 — Comparativo Vue vs. React

Após implementar os exercícios 7.2–7.4, escreva um texto de 300 a 500 palavras comparando sua experiência com Vue e React. Considere: curva de aprendizado, legibilidade do código, volume de código necessário, preferências pessoais e cenários em que escolheria cada um.

### Exercício 7.6 — Build e deploy integrado

Faça a build de produção do projeto Vue (`npm run build`) e configure o Express para servir os arquivos gerados na pasta `dist/`. Verifique que a aplicação funciona completa acessando apenas a porta do Express (`localhost:3000`) — sem o servidor Vite.

---

## 7.13 Referências e Leituras Complementares

**Vue.js**
- [Documentação oficial do Vue 3](https://vuejs.org/guide/introduction.html)
- [Vue Router — documentação](https://router.vuejs.org/)
- [Pinia — documentação](https://pinia.vuejs.org/)
- [Vue 3 Migration Guide (de Options API para Composition API)](https://v3-migration.vuejs.org/)

**React**
- [Documentação oficial do React](https://react.dev/)
- [React Router DOM — documentação](https://reactrouter.com/en/main)
- [Thinking in React — guia oficial de mentalidade](https://react.dev/learn/thinking-in-react)

**Integração e ferramentas**
- [Vite — documentação](https://vitejs.dev/)
- [Axios — documentação](https://axios-http.com/docs/intro)
- [MDN — Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch)
- [MDN — CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)

**Frameworks híbridos (leitura complementar)**
- [Next.js — documentação](https://nextjs.org/docs)
- [Nuxt — documentação](https://nuxt.com/docs)

---

!!! note "Próximo Capítulo"
    No **Capítulo 8 — Autenticação e Autorização**, implementaremos o fluxo completo de login: hash de senha com bcrypt, geração e validação de tokens JWT, middlewares de proteção de rotas e controle de acesso por papel (*Role-Based Access Control*). Os repositórios Prisma construídos no Capítulo 5 e a API REST consolidada nos capítulos anteriores serão a base desse sistema.
