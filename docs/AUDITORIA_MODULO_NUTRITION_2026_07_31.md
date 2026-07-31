# Auditoria do módulo Nutrition — 31 de julho de 2026

Escopo: `src/NutritionWorkspace.tsx`, `src/lib/nutrition.ts`, `src/lib/catalog.ts`, `src/lib/planAssistant.ts`, `src/lib/planDrafts.ts`, `src/lib/planRanges.ts`, `src/lib/planComparison.ts`, `src/lib/planModels.ts`, e o contexto de `src/PatientDetail.tsx` e `src/App.tsx` onde eles se conectam.

Esta auditoria foi feita por leitura de código, não pela aplicação rodando. O acesso ao ambiente publicado exige login (e-mail e senha), e criar conta ou autenticar em nome do usuário é ação que este agente não realiza. Achados de UX descrevem o que o código produz na tela, sem captura de tela do app ao vivo.

## Resumo do estado atual

O plano de redesign V2 (`docs/PLANO_REDESIGN_DESENVOLVIMENTO_AUTONOMO_BSNUTRI_V2.md`) e o plano de auditoria V1 já existem desde 30 de julho de 2026, 17:23, e foram copiados para `G:\Meu Drive\0.Auditoria\BSNutri`. Nenhum dos dois foi aplicado ao código até agora. Os commits posteriores à criação dos planos (`65c3452`, `15bf979`, `742e6d0`, `2d9d096`, `1300e26`) adicionaram funcionalidade nova sobre a mesma estrutura, sem separar responsabilidades. O diagnóstico registrado no handoff de 30/07 sobre `NutritionWorkspace.tsx` concentrar editor, catálogo, modelos, persistência, revisão e publicação continua verdadeiro.

## Achados por trilha

### 1. Segurança explorável

Nenhum achado confirmado nesta leitura. Um ponto precisa de verificação direta no banco, não é vulnerabilidade confirmada:

- **Hipótese, não confirmada**: todo o isolamento entre organizações depende de `.eq('organization_id', ...)` no client (`NutritionWorkspace.tsx:76`, `App.tsx:152-159`, `PatientDetail.tsx:39-47`). Isso só é seguro se houver RLS equivalente no Postgres. Sem acesso ao schema/policies não dá para confirmar. Ação: rodar `ecc:database-reviewer` contra o schema do Supabase.

### 2. Correção funcional

- **Confirmado**: `save()` em `NutritionWorkspace.tsx:119-134` grava plano, versão, dias, refeições e itens em cinco `insert` sequenciais sem transação de banco. O rollback é manual via array `cleanup` e `delete` em ordem reversa. Se a conexão cair no meio da cadeia, o `catch` não executa e os inserts parciais ficam órfãos no banco. Mover essa lógica para uma função RPC transacional (mesmo padrão já usado em `publish_plan_version` e `review_plan_version`) resolve pela raiz.
- **Confirmado**: `addFood` (`NutritionWorkspace.tsx:98-118`) tem o mesmo padrão de insert-então-reverte para `foods`, `food_nutrient_values` e `food_components`. Mesma correção se aplica.
- **Confirmado**: em `EditableMealCard` (`NutritionWorkspace.tsx:230`), a troca de alimento de um item já lançado (`onChange` do `select`) atualiza `foodId` e `name` mas não recalcula `hasReviewedSubstitution`. Um item que já tinha substituição revisada continua marcado como revisado após trocar de alimento, o que corrompe o aviso de publicação em `publish()` (`NutritionWorkspace.tsx:88`).

### 3. Confiabilidade clínica e proveniência

- **Confirmado**: o glossário do domínio (`CONTEXTO_DOMINIO_BSNUTRI.md`) define estimativa nutricional, meta nutricional, modelo dietético e modelo de plano como conceitos distintos, mas o código trata tudo como `targets: Record<string, number>` (`NutritionWorkspace.tsx:47`) e `ModelRules` (`lib/planModels.ts`). Não há campo de método de cálculo, versão ou fonte associado a uma meta. A entrada é sempre manual do profissional, o que é aceitável para MVP, mas nada no schema atual impede confundir estimativa com meta se um método automático for adicionado depois.
- **Confirmado**: `builtInPlanModels` aplicam `targets` fixos (`applyBuiltInModel`, `NutritionWorkspace.tsx:92`) sem vínculo a fonte técnica, população ou data de revisão, apesar da regra 8 da memória permanente exigir isso para PDFs e livros de referência.

### 4. Privacidade e acesso

- **Confirmado, gravidade baixa**: `PatientDetail.tsx:141` mostra `patient.full_name` e `anonymous_code` diretamente no DOM sem nenhum controle adicional de mascaramento client-side. Isso é esperado para o papel do profissional, mas confirma que qualquer XSS futuro no bundle exporia nome completo de paciente — reforça a importância de CSP e sanitização de entrada em outros pontos (ex.: `renderPath`, que aceita string livre validada só por `pattern` HTML, não no servidor, em `NutritionWorkspace.tsx:217`).
- **Hipótese, não confirmada**: anexos de exame (`lab_results.attachment_url`, `PatientDetail.tsx:12,95,149`) aceitam qualquer URL sem checagem de domínio. Não é vulnerabilidade em si, mas um link malicioso cadastrado por alguém com acesso à conta abre em `target="_blank"` com `rel="noreferrer"` (correto), então o risco de `window.opener` já está mitigado.

### 5. UX e acessibilidade

- **Confirmado**: `NutritionWorkspace.tsx:207-226` (`Catalog`) e `NutritionWorkspace.tsx:145-161` (colunas de contexto e análise) só têm rótulos ARIA nos elementos interativos, não em textos derivados como o resumo de nutrientes (`NutritionWorkspace.tsx:225`, linha longa com kcal/proteína/carboidrato/gordura concatenados em `<div>` sem `aria-label` nem estrutura de lista). Leitor de tela vai ler tudo como texto corrido.
- **Confirmado**: o modo "Consulta rápida" (`editorMode==='quick'`) esconde painéis com `aria-hidden` (`NutritionWorkspace.tsx:158-160`) mas os campos continuam no DOM e navegáveis por teclado (falta `tabIndex={-1}` ou `inert`), quebrando a promessa de simplificação do modo rápido para quem usa teclado ou leitor de tela.
- **Confirmado, complexidade de leitura**: formulário de cadastro de alimento (`NutritionWorkspace.tsx:211-223`) mistura nome, procedência, componentes e render em um único `<form>` sem indicação de progresso, o tipo de jornada que a V2 já aponta para revisar.

### 6. Desempenho e operação

- **Confirmado**: `filteredFoods` em `Catalog` (`NutritionWorkspace.tsx:206`) refiltra a lista inteira de alimentos a cada tecla digitada em `query`, sem debounce. Com catálogo pequeno é imperceptível, mas a seed provisional (`supabase/migrations/20260724180500_diet_catalog_foods_seed.sql`) já está expandindo a base, e a rota de leitura em `load()` (`NutritionWorkspace.tsx:76`) traz o catálogo inteiro de uma vez, sem paginação.
- **Confirmado**: `useEffect` de autosave (`NutritionWorkspace.tsx:80`) roda a cada mudança de `days`, `targets`, `assistant` etc. e grava no `localStorage` de forma síncrona. Em planos com muitos dias e itens isso serializa o objeto inteiro a cada tecla.

### 7. Excesso de complexidade (Ponytail)

- **Confirmado**: `NutritionWorkspace.tsx` é um componente de 231 linhas com 8 componentes internos (`EditorModeSwitch`, `TechnicalChecklist`, `TargetRangeInputs`, `MealDistributionInputs`, `PlanAssistant`, `ModelGallery`, `Catalog`, `EditableMealCard`) e mais de 15 `useState` no componente principal. Já existe separação lógica em funções e subcomponentes, mas todos vivem no mesmo arquivo e compartilham um único componente pai que faz fetch, mutação, autosave e renderização.
- **Confirmado**: tipos como `CatalogFood` (linha 19) e `LocalPlanDraft` (linha 22) são declarados só dentro deste arquivo, sem reaproveitar ou expor pela lib, então qualquer outro componente que precisar do mesmo formato duplica o tipo.
- **Confirmado, ceiling conhecido**: o corte natural para a próxima fatia já existe na própria UI — a aba `catalog`/`plan` (`NutritionWorkspace.tsx:41,137`) já separa duas responsabilidades que hoje só estão separadas visualmente, não em módulo. `Catalog` (linha 201) já é praticamente independente: recebe `foods`, `sources`, `busy`, `preferences` e duas funções, dá para virar arquivo próprio com hook `useCatalog` sem mudar comportamento.

## Skills recomendadas

| Trilha | Skill | Uso |
|---|---|---|
| Complexidade | `ponytail:ponytail-audit` | Medir componente-deus e abstrações forçadas antes de cortar |
| Complexidade | `ecc:code-explorer` | Mapear acoplamento real entre `NutritionWorkspace`, `lib/planDrafts`, `lib/planAssistant` antes do split |
| Complexidade | `ecc:type-design-analyzer` | Resolver duplicação de `CatalogFood`/`LocalPlanDraft` |
| Correção | `ecc:react-reviewer` (agent) | Revisar hooks, fingerprint de autosave, closures |
| Correção | `mattpocock-skills:code-review` | Segunda opinião independente do padrão ECC |
| Segurança | `ecc:security-reviewer` (agent) | RPCs de publicação/revisão, inserts diretos client-side |
| Segurança/dados | `ecc:database-reviewer` | Confirmar RLS por trás de `foods`, `plans`, `lab_results` — item pendente da trilha 1 |
| Clínica | `ecc:healthcare-cdss-patterns` | Separar estimativa, meta, modelo dietético e modelo de plano no schema e no tipo, não só no glossário |
| Privacidade | `ecc:healthcare-phi-compliance` | Dados de paciente trafegando client-side, anexos de exame |
| UX/acessibilidade | `ecc:frontend-a11y`, `ecc:accessibility` | Corrigir leitura por leitor de tela e navegação por teclado no modo rápido |
| UX/design | `ui-ux-pro-max:ui-ux-pro-max` | Retomar jornada avaliação → estimativa → meta → construção → revisão → publicação |
| UX/design | `ecc:frontend-design-direction` | Validar hierarquia visual do layout de três colunas |
| Desempenho | `ecc:performance-optimizer` (agent) | Debounce de busca, paginação de catálogo, autosave menos agressivo |
| Domínio | `mattpocock-skills:domain-modeling` | Levar a separação já feita no glossário para dentro do código |

## Próxima fatia vertical sugerida (não implementada agora)

Separar `NutritionWorkspace.tsx` em dois módulos, seguindo o corte que a própria aba do produto já sugere:

1. `NutritionCatalog.tsx` com hook `useFoodCatalog` — recebe o que hoje é `Catalog` (linha 201) mais os states de `foods`, `sources`, `foodPreferences` e as funções `load`, `addFood`, `saveFoodPreference`.
2. `PlanEditor.tsx` com hook `usePlanDraft` — recebe o resto: dias, autosave, assistente, modelos, revisão e publicação.

Isso resolve a trilha de complexidade sem mudar comportamento visível, e cria a base para depois corrigir a transação de `save()`/`addFood()` (trilha de correção funcional) em um lugar menor e testável.

## Validação desta auditoria

- Toda linha citada foi conferida contra o arquivo lido nesta sessão.
- Achados marcados como hipótese não têm caminho reproduzível confirmado e exigem acesso ao schema/RLS do Supabase para virar achado confirmado ou ser descartado.
