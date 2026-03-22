# Atividade 14 — Delivery Tracker: Deploy em Produção

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 11 — Deploy e Infraestrutura  
**Modalidade:** Casa  
**Carga horária estimada:** 4h  

---

## Contexto do Problema

O cliente aprovou o sistema após o ciclo completo de desenvolvimento. A API precisa ser implantada em produção: acessível publicamente, com banco de dados real provisionado, variáveis de ambiente gerenciadas de forma segura, pipeline de CI que garante que nenhuma regressão chegue ao ar e um endpoint de saúde que permita monitorar a disponibilidade do serviço.

> **Pré-requisito:** Atividades 11, 12 e 13 concluídas (autenticação, testes e hardening).

---

## Objetivos de Aprendizagem

- Preparar uma aplicação Node.js para o ambiente de produção
- Configurar variáveis de ambiente de forma segura (sem expor segredos no Git)
- Executar migrations Prisma automaticamente no processo de deploy
- Implementar health check com verificação real do banco
- Automatizar o pipeline de CI com GitHub Actions
- Realizar deploy em plataforma cloud (Railway ou Render)

---

## Requisitos Funcionais

### RF-01 — Variáveis de Ambiente

- Nenhuma credencial ou secret deve estar no código-fonte ou no histórico Git
- O arquivo `.env` deve estar no `.gitignore`
- Deve existir `.env.example` com **todas** as variáveis necessárias (sem valores reais), incluindo comentários explicativos
- Variáveis obrigatórias em produção: `DATABASE_URL`, `JWT_SECRET`, `NODE_ENV=production`, `PORT`, `FRONTEND_URL`

### RF-02 — Script de Inicialização de Produção

- O `package.json` deve ter script `start` que **primeiro** executa `prisma migrate deploy` e depois sobe o servidor
- O servidor deve escutar na porta definida por `process.env.PORT` (fornecida pela plataforma), com fallback para `3000`
- `NODE_ENV=production` deve desabilitar stack traces em respostas de erro

```json
{
  "scripts": {
    "start": "prisma migrate deploy && node src/server.js"
  }
}
```

### RF-03 — Health Check

- `GET /health` deve retornar **200** com:
  ```json
  {
    "status": "ok",
    "timestamp": "2025-06-15T10:30:00.000Z",
    "database": "ok",
    "versao": "1.0.0"
  }
  ```
- O campo `database` deve refletir o estado **real** da conexão (testar com `SELECT 1` via Prisma ou `pg`)
- Se o banco estiver inacessível: `{ "status": "degraded", "database": "error" }` com HTTP **503**
- Esta rota **não deve exigir autenticação**

### RF-04 — Deploy no Railway ou Render

- A API deve estar acessível em uma URL pública com HTTPS
- O banco PostgreSQL deve ser provisionado na própria plataforma
- As variáveis de ambiente devem ser configuradas no painel da plataforma (não em arquivos commitados)
- O deploy deve ser disparado automaticamente a partir de push na branch `main`

### RF-05 — CI com GitHub Actions

- Deve existir `.github/workflows/ci.yml` que executa em todo push e pull request
- O pipeline deve conter os steps: `npm ci`, execução da suíte de testes (`npm test`)
- O `README.md` deve conter o badge de status do CI

### RF-06 — Graceful Shutdown

- O servidor deve capturar os sinais `SIGTERM` e `SIGINT`
- Ao receber o sinal, deve parar de aceitar novas conexões, aguardar as requisições em andamento finalizarem e então encerrar o processo
- Deve fechar a conexão do Prisma com `prisma.$disconnect()` antes de encerrar

---

## Restrição de Avaliação

> ⚠️ **Qualquer repositório com credenciais reais no histórico Git (mesmo em commits antigos) receberá nota zero.** O aluno deve verificar com `git log --all --full-history -- .env` e, se necessário, usar `git filter-branch` ou `BFG Repo Cleaner` para expurgar o histórico antes de entregar. Além disso, revogar imediatamente as credenciais expostas.

---

## Cenários de Teste Esperados

1. `GET /health` na URL de produção → **200** com `database: "ok"`
2. `git log --all --full-history -- .env` → nenhum resultado (`.env` nunca foi commitado)
3. Push para `main` → GitHub Actions executa e fica verde
4. `npm run start` localmente com banco parado → `GET /health` retorna **503** com `database: "error"`
5. Os 10 cenários de teste da Atividade 05 executados contra a URL de produção → todos funcionam

---

## Entregável

- URL pública da API em produção (funcional no momento da correção)
- Link para o repositório com o workflow de CI visível
- `README.md` com: URL de produção, badge de CI, instruções para executar localmente e instruções para executar os testes

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01: Sem credenciais no Git (verificar histórico completo) | 20% | `git log --all --full-history -- .env` e inspecionar commits |
| RF-02: Script `start` com `prisma migrate deploy` antes do servidor | 10% | Verificar `package.json` |
| RF-02: Servidor usa `process.env.PORT` | 5% | Porta hardcoded = penalização |
| RF-03: `GET /health` com estado real do banco | 20% | Testar com banco parado se possível |
| RF-04: API acessível em URL pública com HTTPS | 20% | Testar os cenários da Atividade 05 em produção |
| RF-05: GitHub Actions executando testes com sucesso | 15% | Badge verde no README |
| RF-06: Graceful shutdown implementado | 5% | Inspecionar código; verificar `prisma.$disconnect()` |
| `.env.example` completo e documentado | 5% | |

**Total: 100%**

## Checklist de Correção

1. Acessar a URL pública e verificar `GET /health` → **200**
2. Executar `git log --all --full-history -- .env` no repositório do aluno
3. Verificar última execução do GitHub Actions → verde
4. Executar os 10 cenários da Atividade 05 contra a URL de produção
5. Verificar `package.json` → `start` deve conter `prisma migrate deploy`
6. Verificar `process.env.PORT` no código de inicialização do servidor

## Workflow de CI de Referência

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: delivery_tracker_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Run migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/delivery_tracker_test

      - name: Run tests
        run: npm test
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/delivery_tracker_test
          JWT_SECRET: chave_secreta_para_ci_minimo_32_chars
          JWT_EXPIRES_IN: 1h
          NODE_ENV: test
```

## Pontos de Atenção

- `JWT_SECRET` em produção deve ter no mínimo 32 caracteres e ser gerado aleatoriamente (ex: `openssl rand -hex 32`).
- Verificar que o `GET /health` não está protegido pelo middleware `autenticar` — deve ser acessível sem token.
- O graceful shutdown deve usar `server.close()` (do `http.createServer`) antes de `prisma.$disconnect()`.
