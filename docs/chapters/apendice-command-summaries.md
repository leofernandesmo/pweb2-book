# Apêndice B — Command Summaries

Referência consolidada de todos os comandos de terminal utilizados ao longo do semestre, organizados por ferramenta. Os comandos marcados com `*` são os mais frequentemente utilizados no dia a dia de desenvolvimento.

---

## B.1 NPM

| Comando | Descrição |
|---------|-----------|
| `npm init -y` * | Inicializa um projeto com `package.json` padrão |
| `npm install <pacote>` * | Instala pacote como dependência de produção |
| `npm install --save-dev <pacote>` * | Instala pacote como dependência de desenvolvimento |
| `npm install` | Instala todas as dependências listadas no `package.json` |
| `npm uninstall <pacote>` | Remove um pacote do projeto |
| `npm run <script>` * | Executa um script definido em `package.json` |
| `npm list --depth=0` | Lista dependências instaladas no nível raiz |
| `npm outdated` | Lista pacotes com versões desatualizadas |
| `npm update` | Atualiza pacotes respeitando o range do `package.json` |
| `npm audit` | Verifica vulnerabilidades de segurança nas dependências |
| `npm audit fix` | Corrige automaticamente vulnerabilidades corrigíveis |

---

## B.2 Node.js

| Comando | Descrição |
|---------|-----------|
| `node server.js` * | Executa um arquivo JavaScript |
| `node --watch server.js` * | Executa com reinício automático ao salvar (Node 18+) |
| `node -e "console.log('ok')"` | Executa uma expressão JavaScript inline |
| `node --version` | Exibe a versão do Node.js instalada |

---

## B.3 Pacotes de Produção — Instalação

| Comando | Pacote(s) instalado(s) |
|---------|------------------------|
| `npm install express` * | Framework web |
| `npm install helmet cors morgan` * | Segurança, CORS e logging |
| `npm install compression` | Compressão gzip de respostas |
| `npm install express-rate-limit` | Limitação de taxa de requisições |
| `npm install multer` | Upload de arquivos |
| `npm install dotenv` | Carregamento de variáveis de ambiente |
| `npm install jsonwebtoken bcrypt` | JWT e hash de senha |
| `npm install @prisma/client` | Cliente Prisma ORM |
| `npm install sequelize pg pg-hstore` | Sequelize ORM + driver PostgreSQL |

---

## B.4 Pacotes de Desenvolvimento — Instalação

| Comando | Pacote(s) instalado(s) |
|---------|------------------------|
| `npm install --save-dev jest` * | Framework de testes |
| `npm install --save-dev supertest` * | Testes de integração HTTP |
| `npm install --save-dev prisma` | CLI do Prisma (migrations, codegen) |
| `npm install --save-dev sequelize-cli` | CLI do Sequelize (migrations, seeders) |

---

## B.5 Prisma

| Comando | Descrição |
|---------|-----------|
| `npx prisma init` * | Inicializa o Prisma no projeto (cria `schema.prisma` e `.env`) |
| `npx prisma migrate dev --name <nome>` * | Cria e aplica uma nova migration em desenvolvimento |
| `npx prisma migrate deploy` | Aplica migrations pendentes em produção |
| `npx prisma generate` * | Gera o cliente TypeScript/JavaScript a partir do schema |
| `npx prisma studio` | Abre interface visual para navegar no banco de dados |
| `npx prisma db push` | Sincroniza o schema sem criar migration (prototipagem) |
| `npx prisma db seed` | Executa o script de seed definido no `package.json` |
| `npx prisma migrate reset` | Apaga o banco e reaplica todas as migrations (⚠️ destrutivo) |
| `npx prisma format` | Formata o arquivo `schema.prisma` |

---

## B.6 Sequelize CLI

| Comando | Descrição |
|---------|-----------|
| `npx sequelize-cli init` * | Cria estrutura inicial (config, models, migrations, seeders) |
| `npx sequelize-cli model:generate --name <Nome> --attributes <campos>` * | Gera model e migration |
| `npx sequelize-cli db:migrate` * | Executa migrations pendentes |
| `npx sequelize-cli db:migrate:undo` | Desfaz a última migration |
| `npx sequelize-cli db:migrate:undo:all` | Desfaz todas as migrations (⚠️ destrutivo) |
| `npx sequelize-cli db:seed:all` | Executa todos os seeders |
| `npx sequelize-cli db:seed:undo:all` | Desfaz todos os seeders |
| `npx sequelize-cli seed:generate --name <nome>` | Gera um arquivo de seeder |

---

## B.7 Jest

| Comando | Descrição |
|---------|-----------|
| `npx jest` * | Executa todos os testes |
| `npx jest --watch` * | Executa em modo watch (re-executa ao salvar) |
| `npx jest --coverage` | Executa e gera relatório de cobertura de código |
| `npx jest <arquivo>` | Executa apenas os testes de um arquivo específico |
| `npx jest -t "<nome do teste>"` | Executa apenas testes cujo nome corresponde ao padrão |
| `npx jest --verbose` | Exibe o nome de cada teste individualmente |
| `npx jest --bail` | Para a execução no primeiro teste que falhar |

---

## B.8 Git — Fluxo Básico de Desenvolvimento

| Comando | Descrição |
|---------|-----------|
| `git init` | Inicializa repositório Git |
| `git clone <url>` * | Clona repositório remoto |
| `git status` * | Exibe arquivos modificados e staged |
| `git add .` * | Adiciona todas as alterações ao stage |
| `git commit -m "<mensagem>"` * | Cria um commit com mensagem descritiva |
| `git push origin <branch>` * | Envia commits para o repositório remoto |
| `git pull` * | Baixa e integra alterações remotas |
| `git checkout -b <branch>` | Cria e muda para uma nova branch |
| `git log --oneline` | Exibe histórico de commits resumido |

---

## B.9 Deploy — Railway

| Comando | Descrição |
|---------|-----------|
| `npm install -g @railway/cli` | Instala a CLI do Railway globalmente |
| `railway login` * | Autentica na conta Railway |
| `railway init` * | Vincula o diretório local a um projeto Railway |
| `railway up` * | Realiza o deploy da aplicação |
| `railway logs` * | Exibe logs da aplicação em produção |
| `railway variables set <CHAVE>=<valor>` | Define variável de ambiente no serviço |
| `railway variables` | Lista todas as variáveis de ambiente configuradas |
| `railway open` | Abre o painel do projeto no navegador |
| `railway run <comando>` | Executa um comando no contexto do serviço remoto |

---

## B.10 Deploy — Render

| Comando / Ação | Descrição |
|----------------|-----------|
| Deploy via GitHub | Conectar repositório no painel — deploy automático a cada push |
| `Build Command` | `npm install` |
| `Start Command` | `node server.js` |
| Environment Variables | Configuradas no painel em *Environment > Environment Variables* |
| `render.yaml` | Arquivo de configuração declarativa do serviço (Infrastructure as Code) |

```yaml
# render.yaml — exemplo de configuração
services:
  - type: web
    name: minha-api
    env: node
    buildCommand: npm install
    startCommand: node server.js
    envVars:
      - key: NODE_ENV
        value: production
      - key: JWT_SECRET
        sync: false  # Valor definido manualmente no painel
```

---

## B.11 Variáveis de Ambiente

| Comando | Descrição |
|---------|-----------|
| `npm install dotenv` | Instala o pacote dotenv |
| `cp .env.example .env` * | Cria arquivo `.env` local a partir do modelo |
| `echo ".env" >> .gitignore` | Garante que `.env` não seja versionado |
| `node -e "require('dotenv').config(); console.log(process.env.PORT)"` | Testa carregamento de variável |

```bash
# Conteúdo mínimo do .gitignore
node_modules/
.env
dist/
coverage/
```
