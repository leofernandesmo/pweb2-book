# Capítulo 1 — Fundamentos do Node.js

> **Vídeo curto explicativo**  
> *(link será adicionado posteriormente)*

## 1. O Node.js como Ambiente de Execução para APIs

O Node.js deve ser compreendido como um ambiente de execução orientado a eventos, cujo modelo de concorrência é baseado em I/O não bloqueante. Essa característica o torna particularmente adequado para sistemas cuja principal carga está na comunicação com bancos de dados, serviços externos e sistemas distribuídos — cenário típico de APIs REST institucionais.

Em um contexto como o de uma API acadêmica do IFAL — responsável por autenticar usuários, consultar dados em banco relacional e devolver respostas estruturadas em JSON — o tempo de espera por operações externas é significativamente maior que o tempo de processamento local. O Node.js explora exatamente esse padrão de carga.

O entendimento técnico do runtime é pré-requisito para decisões arquiteturais corretas nos capítulos seguintes.

---

> ### 📜 Breve Histórico do Node.js
> 
> O Node.js foi criado em 2009 por Ryan Dahl com o objetivo de resolver limitações observadas em servidores web baseados em múltiplas threads, especialmente no que diz respeito à escalabilidade sob alta concorrência. Sua proposta central consistiu em utilizar JavaScript no lado do servidor, executado sobre o motor V8, adotando um modelo orientado a eventos e I/O não bloqueante.
> A introdução do npm consolidou rapidamente um ecossistema robusto de bibliotecas, impulsionando sua adoção em aplicações de rede, sistemas em tempo real e APIs REST. Ao longo dos anos, o projeto amadureceu tecnicamente e institucionalmente, passando a ser mantido sob governança da OpenJS Foundation, com ciclos regulares de versões LTS e suporte a padrões modernos da linguagem, como `async/await` e ECMAScript Modules.
> Para aprofundamento histórico e técnico, recomenda-se a leitura da documentação oficial do projeto:
> Referência: [https://nodejs.org/en/about](https://nodejs.org/en/about)
> Esse material apresenta detalhes sobre a evolução do runtime, sua governança e marcos arquiteturais relevantes.


---

## 2. Gerenciamento de Projetos com NPM

O **npm** (Node Package Manager) é mais do que um repositório de bibliotecas. Ele é o mecanismo formal de declaração de dependências, scripts e metadados do projeto.

### 2.1 Inicialização de um Projeto

A criação de um novo projeto Node inicia-se com:

```bash
npm init
```

Esse comando cria interativamente o arquivo `package.json`. Para uma inicialização rápida com valores padrão:

```bash
npm init -y
```

O arquivo gerado pode assumir a seguinte forma:

```json
{
  "name": "api-academica",
  "version": "1.0.0",
  "description": "API REST para consulta de dados acadêmicos",
  "main": "src/server.js",
  "type": "module",
  "scripts": {
    "start": "node src/server.js"
  },
  "author": "Curso BSI - IFAL",
  "license": "ISC"
}
```

O campo `"type": "module"` define que o projeto utilizará o padrão ECMAScript Modules (ESM).

---

### 2.2 Instalação de Dependências

Para instalar uma dependência de produção:

```bash
npm install express
```

Ou de forma abreviada:

```bash
npm i express
```

Isso gera duas modificações:

1. Adiciona a dependência em `"dependencies"` no `package.json`.
2. Cria o diretório `node_modules/`.
3. Gera ou atualiza o `package-lock.json`.

Para instalar dependências de desenvolvimento (exemplo: biblioteca de testes):

```bash
npm install --save-dev jest
```

ou

```bash
npm i -D jest
```

A distinção entre dependências de produção e desenvolvimento é relevante em ambientes de deploy, pois apenas as primeiras são necessárias em execução.

---

### 2.3 Atualização e Remoção

Atualizar uma dependência:

```bash
npm update express
```

Remover uma dependência:

```bash
npm uninstall express
```

Auditoria de segurança:

```bash
npm audit
npm audit fix
```

---

### 2.4 Scripts de Execução

O campo `"scripts"` permite definir comandos padronizados.

Exemplo:

```json
"scripts": {
  "start": "node src/server.js",
  "dev": "node --watch src/server.js",
  "test": "jest"
}
```

Execução:

```bash
npm run dev
```

Ou, no caso do script `start`, simplesmente:

```bash
npm start
```

Essa funcionalidade é fundamental para padronização de execução em equipes.

---

## 3. Organização de Módulos no Node.js

Uma aplicação real não deve concentrar toda a lógica em um único arquivo. A modularização permite separação de responsabilidades.

Considere a seguinte estrutura de diretórios:

```
api-academica/
│
├── src/
│   ├── server.js
│   ├── routes/
│   │   └── studentRoutes.js
│   ├── controllers/
│   │   └── studentController.js
│   └── services/
│       └── studentService.js
│
└── package.json
```

### 3.1 Exportando um Módulo (ESM)

Arquivo `studentService.js`:

```javascript
export function findStudentById(id) {
  return {
    id,
    name: "Maria Oliveira",
    course: "Sistemas de Informação"
  };
}
```

Arquivo `studentController.js`:

```javascript
import { findStudentById } from "../services/studentService.js";

export function getStudent(req, res) {
  const student = findStudentById(req.params.id);
  res.json(student);
}
```

Arquivo `studentRoutes.js`:

```javascript
import { getStudent } from "../controllers/studentController.js";

export function registerStudentRoutes(app) {
  app.get("/students/:id", getStudent);
}
```

Arquivo `server.js`:

```javascript
import express from "express";
import { registerStudentRoutes } from "./routes/studentRoutes.js";

const app = express();
app.use(express.json());

registerStudentRoutes(app);

app.listen(3000, () => {
  console.log("Servidor executando em http://localhost:3000");
});
```

Esse modelo já antecipa princípios da arquitetura MVC, mesmo antes de formalizá-la conceitualmente.

---

## 4. Construção de um Servidor HTTP com Módulo Nativo

Antes de utilizar frameworks como Express, é fundamental compreender o funcionamento do módulo HTTP nativo do Node.js. 
Um servidor HTTP básico pode ser construído da seguinte forma:

Arquivo `server.js`:

```javascript
const http = require('http');

// 2. Define o endereço e a porta
const hostname = '127.0.0.1'; // localhost
const port = 3000;

// 3. Cria o servidor web
const server = http.createServer((req, res) => {
  // Configura o status HTTP (200 = OK) e o tipo de conteúdo (texto simples)
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html;');
  
  // Envia a resposta "Olá Mundo!"
  res.end('<h1>Olá, Mundo! Servidor Node.js simples rodando.</h1>');
});

// 4. Inicia o servidor e escuta na porta definida
server.listen(port, hostname, () => {
  console.log(`Servidor rodando em http://${hostname}:${port}/`);
});
```

- require('http'): Carrega o módulo HTTP, que permite ao Node.js transferir dados por HTTP.
- http.createServer(): Cria um servidor TCP que ouve requisições na porta especificada.
- req (request): O objeto de requisição, usado para ler dados vindo do cliente.
- res (response): O objeto de resposta, usado para enviar dados de volta ao cliente.
- res.end(): Encerra a resposta e envia o conteúdo.

para executar o código acima, digite no terminal:

```
node server.js
```

Abra o seu navegador e acesse: http://localhost:3000 

Vamos ver agora um segundo exemplo:

```javascript
import http from 'http'; // Importa o módulo HTTP nativo do Node.js

const server = http.createServer((req, res) => { // Cria o servidor e define o callback para cada requisição

  if (req.url === '/health') { // Verifica se a rota solicitada é "/health"

    res.writeHead(200, { 'Content-Type': 'application/json' }); // Define status 200 e cabeçalho JSON

    res.end(JSON.stringify({ status: 'ok' })); // Envia resposta JSON e encerra a requisição

    return; // Interrompe a execução para evitar cair no 404

  }

  res.writeHead(404); // Define status 404 para rota não encontrada

  res.end(); // Finaliza a resposta sem corpo

});

server.listen(3000); // Inicia o servidor na porta 3000
```

Aqui, vemos alguns elementos centrais:

O servidor é orientado a eventos.

Cada requisição gera um objeto req e res.

O roteamento é manual.

O protocolo HTTP é manipulado explicitamente.

Em aplicações reais, esse modelo rapidamente se torna complexo. A ausência de abstrações para roteamento estruturado, middlewares e tratamento centralizado de erros motiva o uso de frameworks como Express, que serão abordados posteriormente.

Veja um terceiro exemplo abaixo.


```javascript
import http from "http"; // Importa o módulo HTTP nativo

const server = http.createServer((req, res) => { // Cria o servidor e define a função para cada requisição

  if (req.method === "GET" && req.url === "/health") { // Verifica rota GET /health
    res.writeHead(200, { "Content-Type": "application/json" }); // Define status 200 e tipo JSON
    res.end(JSON.stringify({ status: "ok" })); // Envia JSON e encerra
    return; // Interrompe execução
  }

  if (req.method === "GET" && req.url.startsWith("/student")) { // Verifica rota GET /student
    res.writeHead(200, { "Content-Type": "application/json" }); // Define status 200 e tipo JSON
    res.end(JSON.stringify({ id: 1, name: "João Silva" })); // Retorna estudante fictício
    return; // Interrompe execução
  }

  if (req.method === "POST" && req.url === "/student") { // Verifica rota POST /student
    res.writeHead(201, { "Content-Type": "text/html" }); // Define status 201 e tipo HTML
    res.end("<h1>Estudante cadastrado com sucesso</h1>"); // Retorna mensagem HTML
    return; // Interrompe execução
  }

  res.writeHead(404); // Define status 404 para rota inexistente
  res.end(); // Finaliza resposta
});

server.listen(3000, () => { // Inicia o servidor na porta 3000
  console.log("Servidor HTTP executando na porta 3000"); // Log informativo
});
```

Consegue observar como começa a ficar complexo gerenciar mais rotas?


---

## 5. Testando a API com cURL

Após iniciar o servidor:

```bash
node server.js
```

ou

```bash
npm start
```

Pode-se realizar requisições HTTP diretamente pelo terminal usando `cURL`.

### 5.1 Teste da Rota /health

```bash
curl http://localhost:3000/health
```

Resposta esperada:

```json
{"status":"ok"}
```

### 5.2 Requisição com Método Explícito

```bash
curl -X GET http://localhost:3000/student
```

```bash
curl -X POST http://localhost:3000/student -H "Content-Type: application/json" -d '{"name":"Maria"}'
```

### 5.3 Visualizando Cabeçalhos

```bash
curl -i http://localhost:3000/health
```

O parâmetro `-i` exibe cabeçalhos HTTP, permitindo observar código de status e tipo de conteúdo.

---

## 6. Contextualização em Problema Real

Considere um cenário institucional: um sistema que fornece dados de matrícula para integração com outro serviço governamental. Esse sistema precisa:

1. Receber requisição HTTP.
2. Validar dados en entrada e regras de negócio.
3. Consultar base de dados.
4. Serializar resultado.
5. Retornar código HTTP apropriado.

O servidor HTTP nativo demonstra como cada etapa é manualmente controlada. Já o Express abstrairá roteamento e middlewares, mas os fundamentos permanecem os mesmos.

Compreender essa base evita que o desenvolvedor trate frameworks como “caixas-pretas”.

---



[:material-arrow-left: Back to Preface](../preface.md)
[:material-arrow-right: Go to Chapter 2 – First Steps](02-first-steps.md)

