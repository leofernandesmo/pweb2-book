# Capítulo 11 — Deploy e Infraestrutura

---

## 11.1 Introdução

Ao longo dos dez capítulos anteriores, a API construída neste curso evoluiu de um servidor Express elementar para um sistema completo: arquitetura em camadas, persistência com ORM, autenticação JWT, testes automatizados e uma postura de segurança consistente. Todo esse trabalho, no entanto, só adquire valor real quando a aplicação é colocada em produção — quando deixa de existir apenas em `localhost:3000` e passa a ser acessível por usuários reais, em qualquer lugar do mundo, de forma confiável e segura.

O processo de tornar uma aplicação operacional em produção — denominado **deploy** ou **implantação** — envolve um conjunto de decisões e práticas que vão muito além de copiar arquivos para um servidor. Envolve preparar a aplicação para um ambiente radicalmente diferente do desenvolvimento: sem hot reload, sem mensagens de erro detalhadas expostas ao cliente, com recursos de hardware compartilhados, com a necessidade de persistir entre reinicializações e de se recuperar automaticamente de falhas. Envolve também automatizar o processo de forma que cada alteração no código possa ser verificada e implantada de forma reproduzível, sem intervenção manual.

Este capítulo percorre o caminho completo do deploy: da preparação da aplicação Express para produção, passando pela configuração do banco de dados gerenciado, pelo deploy em plataformas de nuvem acessíveis (Railway e Render), pela containerização com Docker, pela automação com GitHub Actions, pela configuração de proxy reverso com Nginx, pelo monitoramento e logging estruturado, até as estratégias de deploy sem downtime e escalabilidade com PM2. O foco é em práticas diretamente aplicáveis ao projeto desenvolvido ao longo do curso, com ênfase nas ferramentas mais adotadas pelo mercado brasileiro.

> 💡 **Pré-requisito:** Este capítulo pressupõe familiaridade com o Capítulo 3 (estrutura do projeto Express, separação entre `app.js` e `server.js`), o Capítulo 5 (Prisma e migrations) e o Capítulo 10 (variáveis de ambiente obrigatórias, Dockerfile seguro). Uma conta no GitHub é necessária para as seções de CI/CD.

---

## 11.2 Preparando a Aplicação para Produção

### 11.2.1 As diferenças entre desenvolvimento e produção

O ambiente de desenvolvimento é projetado para a produtividade do desenvolvedor: hot reload, mensagens de erro detalhadas com stack traces, logs verbosos, banco de dados local. O ambiente de produção é projetado para o usuário final: desempenho, confiabilidade, segurança e observabilidade. A variável `NODE_ENV` é o mecanismo convencional para distinguir os dois contextos, e muitas bibliotecas — Express, Prisma, Helmet — alteram seu comportamento com base nela.

Em produção, o Express desabilita o cache de views (irrelevante para APIs JSON), habilita o cache de respostas de erro e ativa otimizações de performance. O Prisma desabilita os logs de query. O Helmet aplica configurações mais restritivas de CSP. O `NODE_ENV=production` não é apenas uma convenção — é um sinal que afeta o comportamento de dezenas de dependências.

### 11.2.2 Script de inicialização de produção

A separação entre `app.js` e `server.js` estabelecida no Capítulo 3 é precisamente o que permite ter scripts de inicialização diferentes para cada ambiente:

```json
// package.json
{
  "scripts": {
    "dev":     "node --watch src/server.js",
    "start":   "NODE_ENV=production node src/server.js",
    "build":   "npx prisma generate",
    "migrate": "npx prisma migrate deploy",
    "postinstall": "npx prisma generate"
  }
}
```

O script `postinstall` garante que o Prisma Client seja gerado automaticamente após `npm install` — necessário em plataformas de nuvem que executam `npm install` como parte do processo de build.

### 11.2.3 Tratamento de erros em produção

Em desenvolvimento, stack traces completos no terminal são úteis. Em produção, expô-los nas respostas HTTP é um vetor de informação para atacantes — revelam a estrutura interna do código, as versões de bibliotecas e os caminhos do sistema de arquivos. O middleware de erros do Capítulo 3 deve ser adaptado:

```javascript
// src/middlewares/erros.middleware.js
import { AppError } from '../utils/AppError.js';

export const middlewareDeErros = (err, req, res, next) => {
  const ehProducao = process.env.NODE_ENV === 'production';

  // Loga o erro internamente em qualquer ambiente
  console.error({
    message:    err.message,
    stack:      err.stack,
    statusCode: err.statusCode,
    url:        req.url,
    method:     req.method,
  });

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      erro: err.message,
    });
  }

  // Erro inesperado — não vaza detalhes em produção
  res.status(500).json({
    erro: ehProducao
      ? 'Ocorreu um erro interno. Nossa equipe foi notificada.'
      : err.message,
    ...(ehProducao ? {} : { stack: err.stack }),
  });
};
```

### 11.2.4 Graceful shutdown

Em produção, o processo Node.js pode ser interrompido a qualquer momento — por um deploy, por uma reinicialização do servidor ou por um sinal do sistema operacional. Um encerramento abrupto pode deixar requisições em andamento sem resposta e conexões com o banco de dados abertas. O **graceful shutdown** garante que o servidor pare de aceitar novas requisições, aguarde as requisições em andamento terminarem e feche as conexões ordenadamente:

```javascript
// src/server.js
import app     from './app.js';
import { prisma } from './config/database.js';

const PORTA  = process.env.PORT || 3000;
const server = app.listen(PORTA, () => {
  console.log(`Servidor iniciado na porta ${PORTA} [${process.env.NODE_ENV}]`);
});

// Tempo máximo para encerramento gracioso
const TIMEOUT_SHUTDOWN = 10_000; // 10 segundos

async function encerrar(sinal) {
  console.log(`Sinal ${sinal} recebido. Encerrando graciosamente...`);

  // Para de aceitar novas conexões
  server.close(async () => {
    console.log('Servidor HTTP fechado.');
    await prisma.$disconnect();
    console.log('Conexão com banco encerrada.');
    process.exit(0);
  });

  // Força encerramento se demorar mais que o timeout
  setTimeout(() => {
    console.error('Encerramento forçado por timeout.');
    process.exit(1);
  }, TIMEOUT_SHUTDOWN);
}

// SIGTERM: enviado por orquestradores (Docker, Kubernetes, Railway) ao parar o container
// SIGINT:  enviado pelo Ctrl+C no terminal
process.on('SIGTERM', () => encerrar('SIGTERM'));
process.on('SIGINT',  () => encerrar('SIGINT'));

// Captura exceções não tratadas — evita crash silencioso
process.on('uncaughtException', (err) => {
  console.error('Exceção não capturada:', err);
  encerrar('uncaughtException');
});

process.on('unhandledRejection', (reason) => {
  console.error('Promise rejeitada sem tratamento:', reason);
  encerrar('unhandledRejection');
});
```

### 11.2.5 Health check endpoint

Plataformas de nuvem, load balancers e orquestradores de containers precisam verificar periodicamente se a aplicação está saudável e pronta para receber tráfego. O endpoint de **health check** fornece essa informação:

```javascript
// src/routes/health.routes.js
import { Router } from 'express';
import { prisma } from '../config/database.js';

const router = Router();

router.get('/health', async (req, res) => {
  try {
    // Verifica conectividade com o banco de dados
    await prisma.$queryRaw`SELECT 1`;

    res.json({
      status:    'ok',
      timestamp: new Date().toISOString(),
      uptime:    process.uptime(),
      env:       process.env.NODE_ENV,
    });
  } catch (err) {
    res.status(503).json({
      status:  'degraded',
      erro:    'Banco de dados indisponível',
    });
  }
});

export default router;
```

```javascript
// src/app.js — registrado fora do prefixo /api para acesso simples
import healthRouter from './routes/health.routes.js';
app.use(healthRouter);
```

---

## 11.3 Variáveis de Ambiente e Configuração

### 11.3.1 Centralização da configuração

À medida que a aplicação cresce em ambientes (desenvolvimento, staging, produção), gerenciar variáveis de ambiente espalhadas pelo código torna-se problemático. A solução é centralizar toda a configuração em um único módulo, que valida as variáveis obrigatórias na inicialização e exporta os valores tipados para o restante da aplicação:

```javascript
// src/config/env.js
function obrigatorio(nome) {
  const valor = process.env[nome];
  if (!valor) {
    throw new Error(
      `[Config] Variável de ambiente obrigatória não definida: ${nome}\n` +
      `Copie o arquivo .env.example para .env e preencha os valores.`
    );
  }
  return valor;
}

function opcional(nome, padrao) {
  return process.env[nome] ?? padrao;
}

export const env = {
  node:        opcional('NODE_ENV', 'development'),
  porta:       Number(opcional('PORT', '3000')),
  database:    obrigatorio('DATABASE_URL'),
  jwtSecret:         obrigatorio('JWT_SECRET'),
  jwtExpiresIn:      opcional('JWT_EXPIRES_IN', '15m'),
  jwtRefreshSecret:  obrigatorio('JWT_REFRESH_SECRET'),
  jwtRefreshExpires: opcional('JWT_REFRESH_EXPIRES_IN', '7d'),
  frontendUrl:       opcional('FRONTEND_URL', 'http://localhost:5173'),
  encryptionKey:     process.env.ENCRYPTION_KEY ?? null,

  get ehProducao()  { return this.node === 'production';  },
  get ehTeste()     { return this.node === 'test';        },
  get ehDesenv()    { return this.node === 'development'; },
};
```

```javascript
// Uso em qualquer módulo
import { env } from '../config/env.js';

app.listen(env.porta);
if (env.ehProducao) { /* configurações específicas de produção */ }
```

### 11.3.2 Arquivo `.env.example`

O arquivo `.env.example` documenta todas as variáveis necessárias com valores de exemplo ou placeholders, sem revelar segredos reais. Deve ser versionado no Git; o `.env` real nunca deve ser:

```bash
# .env.example — versionar este arquivo
NODE_ENV=development
PORT=3000

# Banco de dados
DATABASE_URL="postgresql://usuario:senha@localhost:5432/minha_api"

# JWT — gerar com: node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
JWT_SECRET=GERAR_VALOR_ALEATORIO_AQUI
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=GERAR_OUTRO_VALOR_ALEATORIO_AQUI
JWT_REFRESH_EXPIRES_IN=7d

# Frontend
FRONTEND_URL=http://localhost:5173

# Criptografia (opcional — necessário apenas se usar criptografia de campos)
# ENCRYPTION_KEY=GERAR_32_BYTES_HEX_AQUI
```

```bash
# .gitignore — garantir que segredos nunca sejam versionados
.env
.env.local
.env.production
*.env
```

### 11.3.3 Ambientes múltiplos

Para projetos com ambientes distintos (desenvolvimento, staging, produção), a convenção é ter arquivos `.env` específicos por ambiente — carregados explicitamente, não automaticamente:

```javascript
// src/config/env.js — carregamento explícito por ambiente
import dotenv from 'dotenv';

const arquivoEnv = {
  test:        '.env.test',
  staging:     '.env.staging',
  development: '.env',
}[process.env.NODE_ENV] ?? '.env';

dotenv.config({ path: arquivoEnv });
```

Em plataformas de nuvem (Railway, Render, Vercel), as variáveis de ambiente são configuradas diretamente na interface da plataforma — não há arquivo `.env` em produção, e isso é intencional.

---

## 11.4 Banco de Dados em Produção

### 11.4.1 PostgreSQL gerenciado

O SQLite, utilizado nos exercícios ao longo do curso por sua simplicidade de configuração, não é adequado para produção em aplicações multiusuário: suporta apenas uma escrita simultânea, não tem servidor dedicado e não oferece os mecanismos de backup, replicação e monitoramento necessários em ambientes reais. Em produção, o banco de dados relacional recomendado é o **PostgreSQL**.

Gerenciar um servidor PostgreSQL próprio exige conhecimento de administração de sistemas — instalação, configuração de autenticação, backups, atualizações de segurança. Para a maioria dos projetos, a alternativa mais prática é utilizar um **PostgreSQL gerenciado** — um serviço de banco de dados como serviço (*Database as a Service*, DBaaS) que delega toda essa responsabilidade operacional ao provedor.

As opções mais relevantes para o contexto do curso são:

**Railway** — o mesmo provedor utilizado para o backend; oferece PostgreSQL com provisionamento em um clique, dashboard visual e a `DATABASE_URL` já formatada para o Prisma. Indicado para projetos do curso por manter tudo em uma única plataforma.

**Neon** — PostgreSQL serverless com free tier generoso, branching de banco de dados (ideal para testar migrations), e integração nativa com Vercel. Recomendado para projetos que usam Next.js ou Vercel.

**Supabase** — PostgreSQL com APIs REST e realtime geradas automaticamente, autenticação integrada e storage. Adequado quando o projeto necessita de funcionalidades além do banco relacional puro.

**PlanetScale** — MySQL gerenciado com branching e deploy sem downtime nativo. Adequado para projetos que preferem MySQL ao PostgreSQL.

### 11.4.2 Migrations em produção

A estratégia de execução de migrations difere entre desenvolvimento e produção. Em desenvolvimento, `prisma migrate dev` cria e aplica migrations interativamente, podendo resetar o banco. Em produção, apenas `prisma migrate deploy` deve ser utilizado — ele aplica as migrations pendentes sem resetar dados e sem criar novas migrations:

```bash
# Fluxo de deploy com migrations
npx prisma migrate deploy   # aplica migrations pendentes
node src/server.js           # inicia o servidor
```

O momento correto para executar as migrations é **antes** de iniciar a nova versão do servidor — especialmente em deploys que adicionam colunas `NOT NULL` sem valor padrão, que causariam falhas se o servidor novo tentasse inserir registros antes da migration. Plataformas como Railway permitem configurar um `startCommand` que executa migrations automaticamente:

```json
// package.json
{
  "scripts": {
    "start": "npx prisma migrate deploy && node src/server.js"
  }
}
```

### 11.4.3 Backups e recuperação

Provedores de banco de dados gerenciado oferecem backups automáticos com diferentes políticas de retenção. Em Railway e Neon, o free tier inclui backups diários com retenção de 7 dias. Para projetos em produção real, backups manuais periódicos são uma camada adicional de segurança:

```bash
# Backup manual com pg_dump (PostgreSQL)
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# Restauração
psql $DATABASE_URL < backup_20250101_120000.sql
```

Uma prática importante frequentemente negligenciada é o **teste de restauração**: um backup que nunca foi restaurado com sucesso não é um backup confiável. A restauração deve ser testada periodicamente em um ambiente de staging para validar a integridade dos dados.

---

## 11.5 Deploy no Railway

### 11.5.1 Visão geral da plataforma

O **Railway** é uma plataforma de infraestrutura como serviço (*Platform as a Service*, PaaS) que simplifica radicalmente o processo de deploy de aplicações Node.js. Diferentemente de provedores de nuvem como AWS ou GCP, que exigem configuração extensiva de servidores, redes e permissões, o Railway detecta automaticamente o tipo de projeto, instala as dependências, executa o build e expõe a aplicação em uma URL pública — tudo a partir de um push no Git.

### 11.5.2 Configuração inicial

```bash
# Instalar a CLI do Railway
npm install -g @railway/cli

# Autenticar
railway login

# Inicializar o projeto Railway na pasta do backend
railway init
```

Alternativamente, pelo dashboard web em `railway.app`:

1. Criar novo projeto → Deploy from GitHub repo
2. Selecionar o repositório e a branch (`main`)
3. Railway detecta automaticamente o Node.js e executa `npm install && npm start`

### 11.5.3 Configuração de variáveis de ambiente

No dashboard do Railway: projeto → Variables → adicionar cada variável:

```bash
NODE_ENV=production
JWT_SECRET=<valor gerado>
JWT_REFRESH_SECRET=<valor gerado>
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
FRONTEND_URL=https://meu-frontend.vercel.app
```

A `DATABASE_URL` é gerada automaticamente pelo Railway ao adicionar um serviço PostgreSQL ao projeto e vinculá-lo à aplicação — ela aparece como variável de referência que pode ser adicionada ao serviço Node.js com um clique.

### 11.5.4 Arquivo de configuração Railway

O arquivo `railway.json` (ou `nixpacks.toml`) permite personalizar o processo de build e start:

```json
// railway.json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder":      "NIXPACKS",
    "buildCommand": "npm ci && npm run build"
  },
  "deploy": {
    "startCommand":  "npm run migrate && npm start",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 30,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

### 11.5.5 Domínio customizado

O Railway fornece automaticamente um subdomínio em `railway.app`. Para usar um domínio próprio:

1. Dashboard → projeto → Settings → Domains → Add Custom Domain
2. Adicionar registro CNAME no DNS do domínio apontando para o endereço fornecido pelo Railway
3. Railway provisiona automaticamente o certificado TLS via Let's Encrypt

---

## 11.6 Deploy no Render

### 11.6.1 Visão geral e diferenças em relação ao Railway

O **Render** é outra plataforma PaaS com proposta similar ao Railway, com algumas diferenças relevantes: oferece um free tier com serviços web que adormecem após 15 minutos de inatividade (o que introduz latência na primeira requisição após o período de inatividade), tem suporte nativo a deploy de imagens Docker e oferece serviços de background (*Background Workers*) e *Cron Jobs* nativamente na interface.

### 11.6.2 Configuração via `render.yaml`

O Render suporta Infrastructure as Code através do arquivo `render.yaml`, que descreve todos os serviços do projeto:

```yaml
# render.yaml — na raiz do repositório
services:
  - type: web
    name: minha-api
    env:  node
    plan: free
    buildCommand: npm ci && npx prisma generate
    startCommand: npx prisma migrate deploy && node src/server.js
    healthCheckPath: /health
    envVars:
      - key:   NODE_ENV
        value: production
      - key:   PORT
        value: 10000
      - key:   DATABASE_URL
        fromDatabase:
          name: minha-api-db
          property: connectionString
      - key:   JWT_SECRET
        generateValue: true        # Render gera automaticamente
      - key:   JWT_REFRESH_SECRET
        generateValue: true
      - key:   FRONTEND_URL
        value: https://meu-frontend.vercel.app

databases:
  - name:       minha-api-db
    databaseName: minha_api
    user:       minha_api_user
    plan:       free
```

Com esse arquivo no repositório, o Render provisiona toda a infraestrutura automaticamente ao criar o projeto — incluindo o banco PostgreSQL e as variáveis de ambiente geradas.

### 11.6.3 Deploy de imagem Docker no Render

Para projetos que utilizam Docker, o Render pode fazer o build e deploy da imagem diretamente:

1. Dashboard → New → Web Service → Connect a repository
2. Environment: Docker
3. Render usa o `Dockerfile` na raiz do repositório para build e deploy

---

## 11.7 Containerização com Docker

### 11.7.1 Docker como padrão de portabilidade

O Dockerfile de produção seguro foi apresentado na seção 10.13.3 do Capítulo 10. Esta seção complementa esse conhecimento com a configuração do `docker-compose` para desenvolvimento local e com o processo de publicação no Docker Hub.

### 11.7.2 Docker Compose para desenvolvimento local

O `docker-compose` permite definir e executar múltiplos containers em conjunto — ideal para replicar localmente o ambiente de produção com banco de dados PostgreSQL:

```yaml
# docker-compose.yml — para desenvolvimento local
services:
  api:
    build:
      context: .
      target:  builder          # usa o estágio de build, não de produção
    ports:
      - "3000:3000"
    environment:
      NODE_ENV:          development
      DATABASE_URL:      postgresql://postgres:postgres@db:5432/minha_api
      JWT_SECRET:        segredo_dev_nao_usar_em_producao
      JWT_REFRESH_SECRET: refresh_dev_nao_usar_em_producao
    volumes:
      - ./src:/app/src           # hot reload via bind mount
    depends_on:
      db:
        condition: service_healthy
    command: node --watch src/server.js

  db:
    image:   postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB:       minha_api
      POSTGRES_USER:     postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test:     ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout:  5s
      retries:  5

volumes:
  postgres_data:
```

```bash
# Iniciar o ambiente completo
docker compose up -d

# Executar migrations no container
docker compose exec api npx prisma migrate dev

# Ver logs da API
docker compose logs -f api

# Parar tudo
docker compose down

# Parar e remover volumes (reseta o banco)
docker compose down -v
```

### 11.7.3 Publicando no Docker Hub

O Docker Hub é o registro de imagens Docker público mais utilizado. Publicar a imagem permite que qualquer servidor a baixe e execute sem precisar do código-fonte:

```bash
# Fazer login
docker login

# Build da imagem de produção com tag versionada
docker build -t meuusuario/minha-api:1.0.0 -t meuusuario/minha-api:latest .

# Publicar
docker push meuusuario/minha-api:1.0.0
docker push meuusuario/minha-api:latest
```

Em ambientes de produção, é recomendável usar o **GitHub Container Registry** (`ghcr.io`) em vez do Docker Hub para manter a imagem no mesmo ecossistema do repositório, com controle de acesso integrado ao GitHub.

---

## 11.8 CI/CD com GitHub Actions

### 11.8.1 O que é CI/CD e por que automatizar

**CI** (*Continuous Integration*) é a prática de integrar e verificar automaticamente cada alteração no código assim que ela é enviada ao repositório. **CD** (*Continuous Deployment* ou *Continuous Delivery*) é a extensão dessa prática ao processo de implantação — cada alteração verificada com sucesso é automaticamente implantada em produção (Deployment) ou disponibilizada para deploy manual (Delivery).

A automação desse ciclo elimina a inconsistência dos processos manuais, garante que nenhum deploy seja feito sem que os testes passem, e fornece um registro auditável de quando cada versão foi implantada e por quem.

O **GitHub Actions** é o serviço de CI/CD integrado ao GitHub. Pipelines são definidos como arquivos YAML em `.github/workflows/`, versionados junto ao código e executados em resposta a eventos do repositório (push, pull request, tag).

### 11.8.2 Pipeline completo: testes → build → deploy

```yaml
# .github/workflows/deploy.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  # ── JOB 1: Testes ────────────────────────────────────────────────────
  testes:
    name: Executar testes
    runs-on: ubuntu-latest

    services:
      postgres:
        image:   postgres:16-alpine
        env:
          POSTGRES_DB:       test_db
          POSTGRES_USER:     postgres
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    env:
      NODE_ENV:          test
      DATABASE_URL:      postgresql://postgres:postgres@localhost:5432/test_db
      JWT_SECRET:        segredo_ci_apenas
      JWT_REFRESH_SECRET: refresh_ci_apenas

    steps:
      - name: Checkout do código
        uses: actions/checkout@v4

      - name: Configurar Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Instalar dependências
        run: npm ci

      - name: Gerar Prisma Client
        run: npx prisma generate

      - name: Executar migrations de teste
        run: npx prisma migrate deploy

      - name: Executar testes unitários e de integração
        run: npm test -- --coverage

      - name: Verificar vulnerabilidades
        run: npm audit --audit-level=high

      - name: Fazer upload do relatório de cobertura
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: coverage/

  # ── JOB 2: Build da imagem Docker ────────────────────────────────────
  build:
    name: Build e push da imagem
    runs-on: ubuntu-latest
    needs: testes                    # só executa se os testes passarem
    if: github.ref == 'refs/heads/main'  # apenas na branch main

    steps:
      - uses: actions/checkout@v4

      - name: Login no GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extrair metadados (tag da imagem)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags:   |
            type=sha,prefix=sha-
            type=raw,value=latest

      - name: Build e push
        uses: docker/build-push-action@v5
        with:
          context: .
          push:    true
          tags:    ${{ steps.meta.outputs.tags }}
          labels:  ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to:   type=gha,mode=max

  # ── JOB 3: Deploy no Railway ─────────────────────────────────────────
  deploy:
    name: Deploy em produção
    runs-on: ubuntu-latest
    needs: build
    environment: production          # requer aprovação manual (configurável)

    steps:
      - uses: actions/checkout@v4

      - name: Instalar Railway CLI
        run: npm install -g @railway/cli

      - name: Deploy no Railway
        run: railway up --service minha-api
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### 11.8.3 Configurando secrets no GitHub

Os secrets do GitHub Actions são variáveis criptografadas acessíveis nos workflows sem expô-las no código:

1. Repositório → Settings → Secrets and variables → Actions → New repository secret
2. Adicionar `RAILWAY_TOKEN` com o token gerado em `railway.app/account/tokens`

### 11.8.4 Ambientes com aprovação manual

Para deploys em produção que exigem revisão humana antes de prosseguir, o GitHub Actions oferece o conceito de **environments** com regras de proteção:

1. Repositório → Settings → Environments → New environment → `production`
2. Adicionar *Required reviewers* (revisores obrigatórios)
3. O job de deploy ficará pausado até que um revisor aprove

Essa configuração é especialmente importante em projetos com múltiplos colaboradores — evita que um push acidental em `main` seja imediatamente implantado em produção.

### 11.8.5 Estratégia de branches e pipeline

Uma estratégia de branches comum para projetos web é o **GitHub Flow**:

```
feature/* → (pull request) → main → (deploy automático) → produção
```

Cada feature é desenvolvida em uma branch separada. A criação de um pull request dispara o job de testes. O merge para `main` dispara o pipeline completo (testes + build + deploy). Essa estratégia é simples, adequada para equipes pequenas e garante que `main` sempre contenha código testado e implantável.

---

## 11.9 Proxy Reverso com Nginx

### 11.9.1 O papel do proxy reverso

Quando uma aplicação Node.js é hospedada em um servidor próprio (VPS na DigitalOcean, Linode ou AWS EC2), o **proxy reverso** é um componente essencial da arquitetura. Um proxy reverso recebe as requisições dos clientes e as encaminha para a aplicação backend, adicionando uma camada de funcionalidades: terminação TLS, compressão gzip, cache de arquivos estáticos, rate limiting no nível de rede, e balanceamento de carga entre múltiplas instâncias.

O **Nginx** é o proxy reverso mais utilizado no ecossistema web por sua performance, confiabilidade e flexibilidade de configuração.

### 11.9.2 Configuração básica como reverse proxy

```nginx
# /etc/nginx/sites-available/minha-api
server {
    listen 80;
    server_name api.meudominio.com;

    # Redireciona todo HTTP para HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name api.meudominio.com;

    # Certificado TLS gerenciado pelo Certbot
    ssl_certificate     /etc/letsencrypt/live/api.meudominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.meudominio.com/privkey.pem;

    # Configurações TLS seguras
    ssl_protocols      TLSv1.2 TLSv1.3;
    ssl_ciphers        ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache  shared:SSL:10m;
    ssl_session_timeout 1d;

    # HSTS — instrui browsers a usar HTTPS por 1 ano
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Compressão gzip
    gzip on;
    gzip_types application/json application/javascript text/css;
    gzip_min_length 1024;

    # Tamanho máximo do corpo da requisição
    client_max_body_size 10M;

    # Proxy para a aplicação Node.js
    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host       $host;
        proxy_set_header   X-Real-IP  $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }

    # Cache de arquivos estáticos (se servindo frontend)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2)$ {
        expires    1y;
        add_header Cache-Control "public, immutable";
    }
}
```

```bash
# Ativar a configuração
sudo ln -s /etc/nginx/sites-available/minha-api /etc/nginx/sites-enabled/
sudo nginx -t        # verificar sintaxe
sudo nginx -s reload # recarregar sem downtime
```

### 11.9.3 Certificado TLS com Certbot e Let's Encrypt

O **Certbot** automatiza a obtenção e renovação de certificados TLS gratuitos emitidos pela **Let's Encrypt**:

```bash
# Instalar Certbot com plugin Nginx
sudo apt install certbot python3-certbot-nginx

# Obter certificado e configurar Nginx automaticamente
sudo certbot --nginx -d api.meudominio.com

# Verificar renovação automática
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

O Certbot configura automaticamente uma tarefa cron para renovar os certificados antes do vencimento (90 dias). Após a primeira configuração, o processo é inteiramente automático.

---

## 11.10 Monitoramento, Logs e Alertas

### 11.10.1 Logging estruturado com Pino

O `console.log` em texto livre não é adequado para produção: não é pesquisável, não tem níveis de severidade, não é parseável por ferramentas de análise e tem performance inferior a loggers dedicados. O **Pino** é o logger Node.js de maior performance, produzindo logs em formato JSON estruturado:

```bash
npm install pino pino-pretty
```

```javascript
// src/config/logger.js
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
  // Em produção: JSON puro (processado por ferramentas)
  // Em desenvolvimento: formatado e colorido via pino-pretty
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
  base: {
    pid:     process.pid,
    env:     process.env.NODE_ENV,
    version: process.env.npm_package_version,
  },
  redact: ['req.headers.authorization', 'body.senha', 'body.token'],
  // redact: remove campos sensíveis dos logs automaticamente
});
```

```javascript
// Middleware de logging de requisições
export const loggerMiddleware = (req, res, next) => {
  const inicio  = Date.now();
  const reqId   = crypto.randomUUID();
  req.id        = reqId;
  req.log       = logger.child({ reqId });

  res.on('finish', () => {
    req.log.info({
      method:     req.method,
      url:        req.url,
      statusCode: res.statusCode,
      duracaoMs:  Date.now() - inicio,
      ip:         req.ip,
    }, 'Requisição processada');
  });

  next();
};
```

```json
// Exemplo de log em produção (JSON estruturado)
{
  "level": 30,
  "time":  1700000000000,
  "pid":   12345,
  "env":   "production",
  "reqId": "a1b2c3d4-...",
  "method": "POST",
  "url":    "/api/auth/login",
  "statusCode": 200,
  "duracaoMs":  312
}
```

### 11.10.2 Rastreamento de erros com Sentry

Logs de erro em arquivos ou stdout são úteis para debugging, mas não notificam a equipe quando um erro ocorre. O **Sentry** é uma plataforma de monitoramento de erros que captura exceções não tratadas, as agrupa por tipo, exibe o stack trace completo com contexto (usuário, request, variáveis locais) e envia notificações por e-mail ou Slack:

```bash
npm install @sentry/node
```

```javascript
// src/config/sentry.js
import * as Sentry from '@sentry/node';

export function inicializarSentry() {
  if (!process.env.SENTRY_DSN || process.env.NODE_ENV === 'development') return;

  Sentry.init({
    dsn:         process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    release:     process.env.npm_package_version,

    // Captura 10% das transações para performance monitoring
    tracesSampleRate: 0.1,

    // Não captura dados pessoais
    beforeSend(event) {
      if (event.user) {
        delete event.user.email;  // remove e-mail do contexto do usuário
        delete event.user.ip_address;
      }
      return event;
    },
  });
}
```

```javascript
// src/app.js
import { inicializarSentry } from './config/sentry.js';
import * as Sentry from '@sentry/node';

inicializarSentry();

// Middleware de rastreamento de requisições (antes das rotas)
app.use(Sentry.Handlers.requestHandler());

// ... rotas ...

// Middleware de captura de erros (antes do middleware de erros customizado)
app.use(Sentry.Handlers.errorHandler());
app.use(middlewareDeErros);
```

### 11.10.3 Alertas e métricas básicas

Para aplicações em produção, alguns alertas mínimos devem ser configurados:

**Alertas de erro 5xx** — um pico de erros 500 indica um bug ou falha de infraestrutura. Plataformas como Railway e Render exibem métricas de status HTTP no dashboard; o Sentry envia alertas automáticos para novos tipos de erro.

**Alertas de disponibilidade (uptime)** — serviços como **UptimeRobot** (gratuito) ou **Better Uptime** verificam o endpoint `/health` a cada minuto e enviam notificações por e-mail ou SMS quando a aplicação fica indisponível.

**Métricas de performance** — tempo de resposta médio, pico de uso de memória e CPU. Plataformas gerenciadas expõem essas métricas nativamente; para servidores próprios, ferramentas como **Prometheus** + **Grafana** ou o **New Relic** (tem free tier) são as opções padrão.

---

## 11.11 Estratégias de Deploy sem Downtime

### 11.11.1 O problema do downtime em deploys

No modelo mais simples de deploy — parar o servidor, atualizar o código, reiniciar — existe uma janela de indisponibilidade entre o stop e o start. Para APIs com usuários ativos, mesmo poucos segundos de downtime são perceptíveis e inaceitáveis em produção. As estratégias a seguir eliminam ou minimizam essa janela.

### 11.11.2 Rolling deployment

No **rolling deployment**, as instâncias da aplicação são atualizadas progressivamente: uma instância por vez é parada, atualizada e reiniciada, enquanto as demais continuam servindo tráfego. O load balancer redireciona o tráfego apenas para as instâncias saudáveis.

Plataformas como Railway e Render implementam rolling deployment automaticamente: ao detectar um novo deploy, sobem a nova versão da aplicação, aguardam o health check passar, e só então direcionam o tráfego para a nova instância e encerram a antiga. Do ponto de vista do desenvolvedor, nenhuma configuração adicional é necessária — basta que o endpoint `/health` funcione corretamente.

### 11.11.3 Blue-Green deployment

No **blue-green deployment**, dois ambientes idênticos são mantidos em paralelo: o ambiente **blue** (produção atual) e o ambiente **green** (nova versão). O deploy ocorre no ambiente green; após verificação, o tráfego é redirecionado instantaneamente do blue para o green. O ambiente blue permanece disponível como fallback imediato em caso de problema.

```bash
# Exemplo com Railway CLI
# 1. Deploy da nova versão em um serviço separado (green)
railway up --service minha-api-green

# 2. Verificação manual ou automatizada
curl https://minha-api-green.railway.app/health

# 3. Redirecionamento do domínio customizado para o novo serviço
# (feito via dashboard ou CLI do Railway)

# 4. Manter o serviço blue disponível por 24h como rollback
```

### 11.11.4 Migrations sem downtime

O maior desafio no deploy sem downtime não é a aplicação em si, mas o banco de dados. Migrations que adicionam colunas `NOT NULL` sem valor padrão, renomeiam colunas ou alteram tipos de dados são **breaking changes** que podem causar falhas se a nova versão da aplicação tentar usar o banco antes da migration completar, ou se a versão antiga ainda estiver rodando após a migration.

A estratégia para migrations sem downtime segue o padrão **expand-contract**:

**Fase 1 — Expand (deploy 1):** adicionar a nova coluna como `NULL` (opcional), manter compatibilidade com a versão antiga:

```prisma
// Migration segura: nova coluna nullable
model Usuario {
  telefone String? // NULL permitido — versão antiga funciona sem o campo
}
```

**Fase 2 — Migrate data (script de migração):** popular a nova coluna com dados existentes, se necessário.

**Fase 3 — Contract (deploy 2):** após confirmar que a versão nova está estável, aplicar as restrições finais (NOT NULL, índices, remoção de colunas antigas).

```prisma
// Migration final: torna a coluna obrigatória
model Usuario {
  telefone String  // NOT NULL — versão antiga já não está em execução
}
```

Essa abordagem garante que em nenhum momento uma versão em execução seja incompatível com o estado atual do banco de dados.

---

## 11.12 Escalabilidade Básica com PM2

### 11.12.1 O event loop e suas limitações em produção

Como estabelecido no Capítulo 2, o Node.js opera em um único thread — o event loop. Em um servidor com 8 núcleos de CPU, uma instância Node.js utiliza apenas 1 núcleo, deixando 7 ociosos. Para operações puramente assíncronas (I/O de rede, banco de dados), essa limitação raramente é o gargalo. Para operações com uso intensivo de CPU (processamento de imagem, criptografia pesada, relatórios complexos), o event loop pode bloquear e degradar a performance de todas as requisições concorrentes.

O **PM2** (*Process Manager 2*) é o gerenciador de processos padrão do ecossistema Node.js para produção. Ele oferece reinicialização automática em caso de falha, modo cluster para utilizar todos os núcleos disponíveis, monitoramento de processos, logs centralizados e deploy com zero downtime.

### 11.12.2 Configuração do PM2

```bash
npm install -g pm2
```

```javascript
// ecosystem.config.cjs
module.exports = {
  apps: [{
    name:         'minha-api',
    script:       'src/server.js',

    // Modo cluster: um worker por núcleo de CPU
    instances:    'max',     // ou um número específico: 4
    exec_mode:    'cluster',

    // Reinicialização automática
    watch:        false,     // não usar watch em produção
    max_memory_restart: '500M', // reinicia se consumir mais de 500MB

    // Variáveis de ambiente por ambiente
    env: {
      NODE_ENV: 'development',
      PORT:     3000,
    },
    env_production: {
      NODE_ENV: 'production',
      PORT:     3000,
    },

    // Logs
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    error_file:      'logs/pm2-erro.log',
    out_file:        'logs/pm2-saida.log',
    merge_logs:      true,

    // Graceful shutdown
    kill_timeout:    5000,   // aguarda 5s antes de forçar encerramento
    listen_timeout:  3000,   // aguarda 3s para a aplicação subir
  }],
};
```

```bash
# Iniciar em modo produção
pm2 start ecosystem.config.cjs --env production

# Monitoramento em tempo real
pm2 monit

# Status de todos os processos
pm2 status

# Logs em tempo real
pm2 logs minha-api

# Reiniciar sem downtime (reload gracioso)
pm2 reload minha-api

# Salvar configuração para reinicialização automática no boot
pm2 save
pm2 startup   # gera o comando para configurar o systemd

# Atualização com zero downtime
pm2 reload ecosystem.config.cjs --env production
```

### 11.12.3 Modo cluster e sessões stateless

O modo cluster cria múltiplos processos Node.js, cada um com seu próprio event loop e memória. Requisições são distribuídas entre os workers pelo load balancer interno do Node.js. Esse modelo funciona corretamente apenas para aplicações **stateless** — que não mantêm estado em memória entre requisições.

A arquitetura de autenticação baseada em JWT implementada no Capítulo 8 é naturalmente stateless: o token é verificado pela chave secreta em qualquer worker, sem necessidade de compartilhamento de estado. Se a aplicação utilizasse sessões baseadas em memória (não recomendado para produção), o modo cluster exigiria um armazenamento de sessão centralizado (Redis) para que todos os workers compartilhassem o estado de sessão.

### 11.12.4 Quando escalar horizontalmente

O PM2 em modo cluster resolve o problema de subutilização de CPU em um único servidor. Quando o servidor atinge seus limites — CPU ou memória saturados, latência crescente sob carga — a próxima etapa é o **scaling horizontal**: adicionar mais servidores e distribuir o tráfego entre eles com um load balancer externo.

Plataformas gerenciadas como Railway e Render oferecem scaling horizontal como um recurso de planos pagos — é possível aumentar o número de réplicas da aplicação com um clique ou com uma configuração no `railway.json`. Para servidores próprios, ferramentas como Nginx (já apresentado) ou HAProxy atuam como load balancers.

O scaling horizontal pressupõe que a aplicação é completamente stateless e que todos os estados persistentes (sessões, uploads, jobs) estão em serviços externos (banco de dados, Redis, object storage). A arquitetura construída ao longo deste curso satisfaz esse requisito.

---

## 11.13 Exercícios Práticos

### Exercício 11.1 — Preparação para produção

Aplique as seguintes melhorias ao projeto desenvolvido no curso: (a) implemente o módulo `src/config/env.js` com validação de variáveis obrigatórias; (b) adapte o middleware de erros para não expor stack traces quando `NODE_ENV=production`; (c) adicione o endpoint `GET /health` com verificação de conectividade ao banco; (d) implemente o graceful shutdown no `server.js`. Verifique que a aplicação inicia corretamente com `NODE_ENV=production` e encerra graciosamente ao receber `SIGTERM`.

### Exercício 11.2 — Docker Compose para desenvolvimento

Crie um `docker-compose.yml` que suba a API Express e um container PostgreSQL em conjunto. O serviço da API deve depender do healthcheck do banco antes de iniciar. Verifique que `docker compose up` sobe o ambiente completo e que `docker compose exec api npx prisma migrate dev` executa as migrations corretamente.

### Exercício 11.3 — Deploy no Railway

Faça o deploy da API no Railway: (a) crie um novo projeto conectado ao repositório GitHub; (b) adicione um serviço PostgreSQL e vincule a `DATABASE_URL` à aplicação; (c) configure todas as variáveis de ambiente de produção; (d) verifique que o endpoint `/health` responde com status 200 na URL pública gerada pelo Railway; (e) faça uma alteração no código, faça push para `main` e observe o redeploy automático.

### Exercício 11.4 — Pipeline CI/CD com GitHub Actions

Implemente o workflow `.github/workflows/deploy.yml` com três jobs: testes (com banco PostgreSQL de serviço), build de imagem Docker (publicada no GitHub Container Registry) e deploy no Railway. Configure o secret `RAILWAY_TOKEN` no repositório. Verifique que: (a) um pull request dispara apenas os testes; (b) um push para `main` dispara o pipeline completo; (c) uma falha nos testes bloqueia o deploy.

### Exercício 11.5 — Logging estruturado com Pino

Substitua todos os `console.log` e `console.error` do projeto pelo logger Pino. Configure o middleware de logging de requisições e o `redact` para remover `authorization` e `senha` dos logs. Em desenvolvimento, use `pino-pretty` para output formatado. Verifique no terminal que as requisições são logadas em JSON com os campos `method`, `url`, `statusCode` e `duracaoMs`.

### Exercício 11.6 — PM2 em modo cluster

Em um servidor VPS ou na própria máquina, instale o PM2 e configure o `ecosystem.config.cjs` com modo cluster (`instances: 'max'`). Inicie a aplicação com `pm2 start ecosystem.config.cjs --env production`, verifique com `pm2 status` que múltiplos workers estão rodando e teste o reload sem downtime com `pm2 reload minha-api`. Observe no `pm2 monit` a distribuição de requisições entre os workers.

---

## 11.14 Referências e Leituras Complementares

- [Railway — documentação](https://docs.railway.app/)
- [Render — documentação](https://render.com/docs)
- [GitHub Actions — documentação](https://docs.github.com/en/actions)
- [Docker — documentação oficial](https://docs.docker.com/)
- [PM2 — documentação oficial](https://pm2.keymetrics.io/docs/)
- [Nginx — guia de configuração como reverse proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Certbot — Let's Encrypt](https://certbot.eff.org/)
- [Pino — documentação](https://getpino.io/)
- [Sentry para Node.js — documentação](https://docs.sentry.io/platforms/node/)
- [Prisma — deploy e migrations em produção](https://www.prisma.io/docs/guides/deployment)
- [The Twelve-Factor App](https://12factor.net/) — metodologia para construção de aplicações SaaS portáteis e escaláveis
- HUMBLE, J.; FARLEY, D. *Continuous Delivery: Reliable Software Releases through Build, Test, and Deployment Automation*. Addison-Wesley, 2010.
- BURNS, B.; BEDA, J.; HIGHTOWER, K. *Kubernetes: Up and Running*. 3ª ed. O'Reilly Media, 2022. — Capítulos 1–3 (introdução à orquestração de containers, leitura complementar).
