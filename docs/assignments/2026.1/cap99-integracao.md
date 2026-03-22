# Atividade 15 — Delivery Tracker: Projeto Final

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** Integração de todos os capítulos  
**Modalidade:** Projeto individual ou em dupla  
**Carga horária estimada:** 10h  

---

## Contexto

Esta atividade é a consolidação de todo o semestre. O aluno entrega o sistema Delivery Tracker em sua versão final: arquitetado, documentado, testado, seguro e em produção. O produto entregue deve ser algo que um cliente real poderia usar.

---

## Requisitos de Entrega

### RE-01 — API REST Completa

A API deve implementar integralmente todos os requisitos funcionais das Atividades 05 a 13:

- Arquitetura em camadas com contratos de repository (Cap. 4)
- Persistência com Prisma e migrations versionadas (Cap. 5)
- Autenticação JWT com bcrypt e RBAC (Cap. 8)
- Suíte de testes com cobertura ≥ 70% em `src/services/` (Cap. 9)
- Hardening: rate limiting, Helmet, validação com Zod/Joi, sem IDOR (Cap. 10)
- Em produção com CI e health check (Cap. 11)

### RE-02 — Interface (escolher uma)

O aluno deve entregar **uma** das interfaces abaixo:

**Opção A — Painel SSR com EJS (Cap. 6)**
- Painel administrativo completo com CRUD de entregas e motoristas
- Formulários com PRG, mensagens flash e validação inline

**Opção B — Dashboard SPA com Vue.js (Cap. 7)**
- Dashboard com listagem reativa, formulários e detalhe de entrega
- Interceptor Axios com token JWT e navigation guards

### RE-03 — Documentação Swagger

- `GET /api/docs` deve expor a documentação interativa da API via Swagger UI
- Todas as rotas devem estar documentadas com: descrição, parâmetros, body schema e respostas possíveis (200, 201, 400, 401, 403, 404, 409, 429)
- O esquema de autenticação Bearer deve estar configurado no Swagger

### RE-04 — README Técnico

O `README.md` deve conter:

- Descrição do sistema
- **Decisões arquiteturais:** ao menos duas decisões tomadas ao longo do semestre com justificativa (ex: por que o service não depende do ORM diretamente; por que o middleware de autorização não consulta o banco)
- Instruções para executar localmente (passo a passo)
- Instruções para executar os testes
- Link para a URL de produção
- Link para a documentação Swagger
- Badge de CI (GitHub Actions)

### RE-05 — Apresentação Presencial

- Duração: **10 a 12 minutos**
- Demonstração ao vivo obrigatória:
  1. Registro de usuário e login
  2. Criação de entrega
  3. Ciclo completo de status (CRIADA → EM_TRANSITO → ENTREGUE)
  4. Tentativa de cancelamento por OPERADOR → 403
  5. Cancelamento por GESTOR → sucesso
  6. `GET /health` mostrando banco operacional
- Explicar **duas decisões de arquitetura** tomadas ao longo do semestre
- O professor fará no mínimo **duas perguntas técnicas** sobre o código

---

## Critérios de Excelência (Bônus)

| Critério | Bônus |
|---|---|
| Cobertura de testes ≥ 85% em `src/services/` | +3 pontos |
| CI/CD com deploy automático para produção após push na `main` | +5 pontos |
| Refresh Token implementado (Cap. 8, seção 8.9) | +4 pontos |
| Testes E2E com Playwright cobrindo ao menos o fluxo de login + criação de entrega | +5 pontos |

---

## O Que NÃO Será Avaliado

- Estética ou design visual da interface
- Quantidade de features além das especificadas
- Perfeição no código — decisões conscientes e justificadas valem mais que código sem explicação

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RE-01: API completa com todos os RFs das Atividades 05–13 | 30% | Testar os 10 cenários da Atividade 05 em produção |
| RE-02: Interface (EJS ou Vue) funcional e integrada | 15% | Verificar PRG/guards e que usa os mesmos services |
| RE-03: Swagger UI com todas as rotas e auth Bearer | 15% | Testar autenticação no Swagger interativo |
| RE-04: README com decisões arquiteturais justificadas | 10% | Avaliar profundidade da justificativa |
| RE-05: Demonstração ao vivo sem falhas técnicas | 20% | Penalizar falhas graves na demo |
| RE-05: Respostas às perguntas técnicas | 10% | Avaliar compreensão do próprio código |

**Total: 100%** (+ até 17 pontos de bônus)

## Perguntas Técnicas Sugeridas

1. *"Por que você colocou a regra X no service e não no controller? O que aconteceria se estivesse no controller?"*
2. *"Se eu trocar sua implementação de repository por uma diferente que respeite o contrato, o sistema continua funcionando? Me mostre como você garantiu isso."*
3. *"Mostre no código a diferença entre o middleware de autenticação e o de autorização. Por que essa separação importa?"*
4. *"Se o banco cair agora, o que acontece com o `GET /health`? Como você sabe isso sem derrubar o banco?"*
5. *"Como seus testes unitários garantem que o service funciona sem banco de dados? Me mostre um mock no código."*
6. *"Seu token JWT expira em X horas. O que acontece quando um usuário tenta usar um token expirado? Me mostre o teste que cobre esse cenário."*

## Critério de Excelência — Pontuação Final

A pontuação máxima possível com todos os bônus é **117 pontos**. O professor pode normalizar para 100 ou manter a pontuação acima de 100 como distinção — a critério institucional.
