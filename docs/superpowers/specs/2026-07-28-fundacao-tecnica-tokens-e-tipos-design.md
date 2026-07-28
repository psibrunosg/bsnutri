# Spec: fundação técnica — tipos gerados, tokens consolidados, dependência morta

Data: 28/07/2026

## Problem Statement

Um áudito ponytail (over-engineering/complexidade) e um áudito de design system encontraram três problemas de fundação técnica no BSNutri, nenhum deles visível ao usuário final hoje, mas todos aumentando risco de bug e custo de manutenção conforme o roadmap avança:

1. Nenhum tipo TypeScript é gerado a partir do schema Supabase. `src/PatientPortal.tsx` sozinho hand-mantém 19 interfaces espelhando o shape de queries (`Item`, `Meal`, `Day`, `Version`, `Plan`, `Appointment`, etc.), e o mismatch entre o tipo escrito à mão e o retorno real do Supabase já aparece como um cast inseguro `as unknown as Plan[]` (linha 160). `tasks/todo.md` já lista "Gerar tipos TypeScript do schema reconciliado" como pendente.
2. `src/App.css` (171 linhas) declara três sistemas de variável CSS sobrepostos — `--bs-*`, `--color-*` e nomes soltos (`--primary`, `--leaf`, `--sage`, `--paper`, `--ink`...) — nenhum batendo exatamente os 10 tokens documentados em `design-system/bsnutri/MASTER.md`. Cerca de 30 cores hex aparecem hardcoded fora de qualquer `var()`, dominadas por uma paleta verde-oliva/bege (`#3e6b5c` usado 30 vezes) ausente do MASTER.md, que documenta uma paleta cyan/verde-saúde diferente.
3. `tailwindcss` e `@tailwindcss/vite` estão instalados e ativos (`vite.config.ts`, `@import "tailwindcss"` em `src/index.css`) mas nenhuma classe utility Tailwind é usada em nenhum componente — toda estilização real é CSS hand-rolled em `src/App.css`. A dependência paga custo de build sem uso.

## Solution

Três frentes independentes, sem nenhuma mudança de comportamento ou aparência visível ao usuário:

1. **Tipos gerados do Supabase.** Gerar `src/lib/database.types.ts` a partir do schema remoto (`qjclholskxmtxqqentuz`) via `generate_typescript_types`. Trocar as interfaces hand-rolled que espelham tabelas por `Database['public']['Tables'][...]['Row']` (e `Insert`/`Update` onde fizer sentido), começando por `PatientPortal.tsx`. Eliminar o `as unknown as Plan[]`. Tipos puramente de UI (ex: `OptionalModule`, `NutritionSummary` calculado, `DriveStatus`) continuam definidos à mão — não são shape de tabela.
2. **Consolidar tokens CSS em uma única camada semântica.** Fundir `--bs-*` e as variáveis soltas dentro do namespace `--color-*` já existente, seguindo primitivo → semântico (um único ponto de definição por cor, resto referencia via `var()`). É rename/merge de declaração — nenhum valor hex visível muda.
3. **Atualizar `MASTER.md` para refletir a paleta real.** A paleta verde-oliva/bege (`leaf`, `sage`) parece uma escolha deliberada (metáfora de planta/nutrição), não um erro — os nomes de variável não são acidentais. Em vez de reverter o CSS para o cyan genérico do doc auto-gerado, documentar a paleta em produção como fonte da verdade, mantendo os 10 papéis semânticos (primary, accent, background, destructive etc.) mas com os valores hex que já estão no ar.
4. **Remover a dependência Tailwind morta.** Tirar `tailwindcss` e `@tailwindcss/vite` de `package.json`, o plugin de `vite.config.ts` e o `@import "tailwindcss"` de `src/index.css`. Não adotar Tailwind agora — o sistema de CSS vars já é maduro e mexer nisso sem necessidade demonstrada seria reescrita, não simplificação.

## Components

- `src/lib/database.types.ts` — novo arquivo gerado (não editado à mão; regenerar quando o schema mudar).
- `src/PatientPortal.tsx` — maior beneficiário; troca de 19 interfaces por referências ao tipo gerado.
- `src/App.css` — token layer consolidado; nenhuma outra folha de estilo existe no projeto.
- `design-system/bsnutri/MASTER.md` — reescrito na seção de paleta para refletir os valores reais.
- `package.json`, `vite.config.ts`, `src/index.css` — remoção da dependência Tailwind.

## Data Flow

Sem mudança de fluxo de dados. Tipos gerados descrevem o shape que já trafega do Supabase; tokens CSS descrevem a mesma UI já renderizada. Este trabalho é puramente estrutural.

## Error Handling

Nenhum comportamento de erro muda. O cast inseguro removido (`as unknown as Plan[]`) na verdade melhora a superfície de erro: com tipo gerado, um mismatch real entre query e schema vira erro de compilação em vez de falha silenciosa em runtime.

## Testing

- `npm run build` e `npm run lint` devem continuar verdes após cada uma das três frentes — é o sinal principal de que nada visível quebrou.
- `npm test` cobre os componentes tocados (`PatientPortal.test.tsx` já existe); rodar antes/depois da troca de tipos para confirmar que o shape gerado bate com os dados de teste.
- Consolidação de tokens CSS: checagem visual manual (antes/depois, screenshot ou browser) das telas que usam `--leaf`/`--sage`/`--bs-*`, já que troca de nome de variável é o tipo de mudança onde um `grep` incompleto vira regressão visual silenciosa.
- Remoção do Tailwind: `npm run build` sem o plugin é a validação suficiente — se não há classe utility em uso, não há CSS ausente a testar.

## Out of Scope

- Qualquer redesign visual ou troca de paleta percebida pelo usuário.
- Adoção de Tailwind.
- Mudança nos 3 outros arquivos de componente menores com tipos duplicados pontuais (`ContentLibrary.tsx`, `SubstitutionWorkspace.tsx`) — ficam para uma segunda passada se o padrão em `PatientPortal.tsx` se provar útil.
- Qualquer regra de produto (publicação imutável, RLS, IA como rascunho) — nenhuma delas é tocada aqui.
