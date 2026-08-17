# Portabilidade: o que prende o BSNutri ao Supabase

> Levantado em 2026-08-16 no worktree `integrar-redesign-app-real`, contra 57
> migrations e `supabase/schema.sql` (47 tabelas, 130 policies, 59 funções).
> Este documento é um mapa, não um plano de refatoração. Nada de código foi
> alterado para produzi-lo.

O objetivo é responder uma pergunta só: **se amanhã o banco virar um Postgres em
servidor próprio, o que quebra?**

Resumo em uma linha: o *schema* é praticamente Postgres puro; o que prende é a
**identidade** (`auth.uid()`), o **transporte** (PostgREST via `supabase-js`) e a
**emissão de token** (GoTrue).

---

## 1. Já é Postgres puro (migra sem tocar)

| Peça | Onde | Observação |
|---|---|---|
| 47 tabelas, chaves, constraints, índices | `supabase/schema.sql` | DDL padrão |
| 59 funções e triggers de regra de negócio | schema `private` e `public` | PL/pgSQL padrão |
| Guardas de workflow (`guard_plan_workflow`, `days_lock_guard`, …) | schema `private` | Regra vive no banco, não no cliente. Isso é portabilidade ganha |
| Extensões `pgcrypto` e `btree_gist` | migrations `20260713031356`, initial | Existem em qualquer Postgres |
| Seeds de catálogo (alimentos, nutrientes, modelos) | migrations de seed | SQL padrão |
| Histórico de migrations | `supabase/migrations/` | Formato é `<timestamp>_<nome>.sql`; qualquer runner lê |

O RLS em si (`enable row level security`, `create policy`) **é Postgres puro**. O
que não é puro é a *função* usada dentro das policies — ver abaixo.

## 2. Específico do Supabase (precisa de substituto)

### 2.1 `auth.uid()` e `auth.jwt()` — o acoplamento mais espalhado

- 147 ocorrências de `auth.uid()` e 10 de `auth.jwt()` nas migrations.
- São funções do schema `auth`, criadas pelo GoTrue, que leem
  `current_setting('request.jwt.claims')`.
- Duas chaves estrangeiras apontam para `auth.users`:
  `profiles.id` (migration inicial) e `catalog_discovery_preferences.user_id`
  (`20260724145952`).

**Substituto num servidor próprio:** criar um schema `auth` com uma tabela `users`
e funções `auth.uid()` / `auth.jwt()` equivalentes lendo a mesma variável de
sessão. É a via de menor atrito — as 147 ocorrências continuam válidas sem edição.
O custo real não é o SQL, é o emissor do token.

### 2.2 GoTrue (autenticação)

Usado em `src/pages/Login.tsx`, `src/App.tsx` e `src/pages/Portal.tsx`:
`signInWithPassword`, `signUp`, `resetPasswordForEmail`, `updateUser`,
`getSession`, `onAuthStateChange`, `signOut`.

**Substituto:** qualquer emissor de JWT (Keycloak, Auth.js, serviço próprio) que
coloque `sub` e `email` nos claims e que a camada de dados repasse ao Postgres via
`set_config('request.jwt.claims', ...)`. Reset de senha e confirmação por e-mail
teriam de ser reimplementados — hoje são serviço gerenciado.

### 2.3 PostgREST (transporte de dados)

- 32 chamadas `supabase.from(...)` em 16 arquivos de `src/`.
- 14 RPCs chamadas por `supabase.rpc(...)`:
  `apply_plan_template_to_patient`, `autosave_plan_version`,
  `bootstrap_organization`, `claim_patient_access`, `create_patient_intake`,
  `get_current_shopping_list`, `get_patient_drive_status`,
  `get_patient_weekly_summary`, `publish_plan_version`, `review_clinical_draft`,
  `review_plan_template`, `review_plan_version`, `save_form_response`,
  `save_plan_draft`.
- Só 3 pontos usam *embedded resources* (`select('a, b(c)')`), a sintaxe mais
  difícil de reproduzir fora do PostgREST.

**Substituto:** PostgREST é open source e roda em qualquer servidor — é o caminho
de menor custo, porque preserva a API e o `supabase-js` pode ser trocado por um
cliente REST fino. As 14 RPCs são o ativo aqui: como a lógica está em funções
Postgres, não em código de aplicação, uma API própria só precisa expor 14
endpoints, não reimplementar regra clínica.

Os `grant execute` do projeto vão para os papéis `authenticated` (206 grants) e
`public` (117). Não há nada concedido a `anon` nem a `service_role` nas migrations —
o que significa que a matriz de papéis a recriar é pequena.

### 2.4 Extensões instaladas pela plataforma

`pg_net`, `pg_stat_statements` e `supabase_vault` aparecem no dump porque o
Supabase as instala, **não porque o projeto as use**. Nenhuma migration as
referencia. Num Postgres próprio, simplesmente não instale: só `pgcrypto` e
`btree_gist` são requisito real.

### 2.5 Storage e Realtime: não usados

- **Nenhuma** chamada a `supabase.storage` em `src/`. As fotos do diário vão para o
  Google Drive por um endpoint próprio (`POST /api/drive/diary-photo`, ver
  `src/lib/driveClient.ts`) e o banco guarda só metadados
  (`20260717141500_diary_photo_drive_metadata.sql`). Isso já está desacoplado.
- **Nenhum** uso de Realtime (`.channel(...)`) nem de Edge Functions
  (`functions.invoke`). O único hit de "edge" no código é ruído em
  `database.types.ts`.

Ou seja: dos quatro produtos do Supabase, o projeto usa dois (Postgres e Auth) e
meio (PostgREST como transporte).

## 3. Ordem sugerida numa migração futura

Ordem por custo crescente, cada passo entregando valor sozinho:

1. **Manter `supabase/schema.sql` em dia** (já garantido por `npm run db:push`).
   Sem isso nada abaixo é possível.
2. **Subir um Postgres próprio a partir de `supabase/schema.sql` + as migrations**,
   com um schema `auth` mínimo. Prova que a estrutura é portável.
3. **Trocar o emissor de token**, mantendo os mesmos claims (`sub`, `email`).
   As policies não mudam.
4. **Subir PostgREST próprio** apontando para esse banco. `src/lib/supabase.ts` é
   o único ponto de criação do cliente — trocar a URL e o esquema de token cobre a
   maior parte do frontend.
5. **Reavaliar os 3 pontos de embedded select** e os fluxos de e-mail do GoTrue,
   que são o resto do trabalho.

## 4. O que não fazer

- Não migrar regra de negócio das funções Postgres para o frontend "para ficar mais
  portável". A portabilidade real vem de a regra estar no banco.
- Não substituir RLS por filtro só no cliente. `docs/rls-test-matrix.md` e
  `supabase/tests/rls_isolation.test.sql` existem porque essa é a linha de defesa.
- Não aplicar nada direto no painel do Supabase: o que não passa por migration não
  chega ao banco local nem ao `schema.sql`, e a portabilidade some em silêncio.
