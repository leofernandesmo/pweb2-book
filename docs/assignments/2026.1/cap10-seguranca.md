# Atividade 13 — Delivery Tracker: Hardening e Segurança da API

**Disciplina:** Programação Web 2 — Backend  
**Capítulo:** 10 — Segurança de Aplicações Web  
**Modalidade:** Casa  
**Carga horária estimada:** 3h  

---

## Contexto do Problema

O time de segurança realizou um pentest na API antes do lançamento em produção e produziu o relatório abaixo. Todas as vulnerabilidades devem ser corrigidas. A restrição crítica: **nenhum teste existente da Atividade 12 pode ser quebrado pelas correções.**

> **Pré-requisito:** Atividade 12 concluída (suíte de testes passando).

---

## Objetivos de Aprendizagem

- Reconhecer e corrigir vulnerabilidades do OWASP API Security Top 10
- Aplicar rate limiting, validação de input e sanitização
- Configurar cabeçalhos HTTP de segurança com Helmet
- Remover dados sensíveis de respostas e payloads
- Entender o mecanismo do CSRF e quando APIs JWT são imunes

---

## Relatório de Pentest (Fictício)

| # | Achado | Descrição | Severidade |
|---|---|---|---|
| P-01 | Sem rate limiting em `/auth/login` | Brute force irrestrito na rota de autenticação | **CRÍTICA** |
| P-02 | Headers expõem tecnologia | `X-Powered-By: Express` visível em todas as respostas | MÉDIA |
| P-03 | Campos extras persistidos | `POST /entregas` aceita e persiste campos arbitrários no body | ALTA |
| P-04 | Dados sensíveis no payload JWT | Hash da senha presente no token decodificado | **CRÍTICA** |
| P-05 | Sem paginação obrigatória | `GET /entregas` pode retornar 100k+ registros (DoS por exaustão de memória) | ALTA |
| P-06 | IDOR em histórico | `GET /api/entregas/:id/historico` não valida se a entrega pertence ao usuário autenticado | ALTA |

---

## Requisitos Funcionais

### RF-01 — Rate Limiting (P-01)

- `POST /api/auth/login` deve aceitar no máximo **10 requisições por IP** a cada 15 minutos
- Ao exceder o limite: **429** com `{ erro: "Muitas tentativas. Tente novamente em 15 minutos." }`
- O limite deve ser aplicado **apenas** nessa rota, não em toda a aplicação

### RF-02 — Headers de Segurança (P-02)

- O header `X-Powered-By` deve ser removido de **todas** as respostas
- Os headers de segurança padrão do `helmet` devem estar presentes (`X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security`, etc.)

### RF-03 — Validação de Input (P-03)

- Todas as rotas de escrita (`POST` e `PATCH`) devem validar o body com **Zod** ou **Joi**
- Campos não previstos no schema devem ser **descartados** (strip) antes de chegar ao service
- Campos obrigatórios ausentes → **400** com lista estruturada dos campos com erro:
  ```json
  { "erro": "Dados inválidos", "campos": ["descricao", "origem"] }
  ```

### RF-04 — Limpeza do Payload JWT (P-04)

- O payload do JWT **não deve conter** `senhaHash`, `senha` ou qualquer campo sensível
- A função de geração do token deve selecionar explicitamente os campos permitidos: `id`, `nome`, `email`, `papel`

### RF-05 — Paginação Obrigatória (P-05)

- Todas as rotas de listagem devem retornar no máximo **100 registros por requisição**
- Requisições sem `page` e `limit` devem usar os defaults: `page=1`, `limit=20`
- Tentar `limit=200` deve retornar exatamente 100 registros (limite aplicado silenciosamente)

### RF-06 — Correção de IDOR (P-06)

- `GET /api/entregas/:id` deve verificar se a entrega pertence ao usuário autenticado (via `criadorId`) **ou** se o usuário tem papel `GESTOR`
- Usuário `OPERADOR` tentando acessar entrega de outro usuário → **403**
- A verificação deve estar no **service**, não no middleware nem no controller

---

## Restrição de Avaliação

> ⚠️ **Todos os testes da Atividade 12 devem continuar passando após as correções.** Executar `npm test` antes de entregar — se algum teste quebrou por conta do hardening, o aluno deve corrigir o teste e documentar o motivo no `README.md`.

---

## Cenários de Teste Esperados

1. 11 requisições seguidas para `POST /api/auth/login` → a 11ª retorna **429**
2. `curl -I /api/entregas` → `X-Powered-By` ausente, `X-Frame-Options` presente
3. `POST /api/entregas` com campo extra `{ "descricao": "...", "campoFalso": "xxx" }` → entregue sem `campoFalso` no banco
4. `POST /api/entregas` sem `descricao` → **400** com `campos: ["descricao"]`
5. Decodificar o token em [jwt.io](https://jwt.io) → `senhaHash` ausente
6. `GET /api/entregas?limit=200` → retorna no máximo 100 registros
7. Usuário A tenta `GET /api/entregas/:id` de entrega criada pelo usuário B → **403**
8. `npm test` → todos os testes passam

---

## Entregável

- Código com todas as correções de segurança
- `README.md` atualizado documentando os testes ajustados (se houver)

---

---

# Gabarito — Uso Exclusivo do Professor

## Rubrica de Avaliação

| Critério | Peso | Observação |
|---|---|---|
| RF-01 (P-01): Rate limiting funcional apenas em `/auth/login` | 20% | Testar 11 requisições rápidas; verificar que outras rotas não são afetadas |
| RF-02 (P-02): Helmet ativo, `X-Powered-By` ausente | 10% | `curl -I` e inspecionar headers |
| RF-03 (P-03): Validação com Zod/Joi em todas as rotas de escrita | 25% | Testar campos extras e campos obrigatórios ausentes |
| RF-04 (P-04): Payload JWT sem dados sensíveis | 15% | Decodificar token e inspecionar |
| RF-05 (P-05): Paginação máxima de 100 registros | 15% | `?limit=200` deve retornar 100 |
| RF-06 (P-06): IDOR corrigido com verificação no service | 10% | Verificar que a lógica não está no middleware |
| Testes da Atividade 12 continuam passando | 5% | `npm test` deve passar integralmente |

**Total: 100%**

## Pontos de Atenção

- **RF-01:** `express-rate-limit` aplicado como middleware na rota específica, não globalmente. Verificar que `GET /api/entregas` não é limitado.
- **RF-03:** Diferenciar *strip* (descartar campos extras silenciosamente, recomendado) de *strict* (rejeitar com 400). Ambos são aceitos, mas *strip* é preferível para APIs — menos breaking changes.
- **RF-06:** A regra de ownership deve estar em `EntregasService.buscarPorId()` ou em um método específico `verificarAcesso()` — não em um middleware genérico que não conhece o domínio.

## Exemplo de Validação com Zod

```js
import { z } from 'zod';

const criarEntregaSchema = z.object({
  descricao:   z.string().min(1),
  origem:      z.string().min(1),
  destino:     z.string().min(1),
}).strict(); // ou .strip() para descartar campos extras

// Middleware de validação reutilizável
const validar = (schema) => (req, res, next) => {
  const resultado = schema.safeParse(req.body);
  if (!resultado.success) {
    const campos = resultado.error.issues.map(i => i.path.join('.'));
    return res.status(400).json({ erro: 'Dados inválidos', campos });
  }
  req.body = resultado.data; // body sanitizado (sem campos extras)
  next();
};
```
