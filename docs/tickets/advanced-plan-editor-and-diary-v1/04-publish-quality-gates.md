# 04 - Gates de qualidade para publicação

**What to build:** a revisão e publicação passam a validar metas obrigatórias, etapas do assistente e pendências de substituição. Faltas de substituição geram aviso e confirmação extra, mas não bloqueiam.

**Blocked by:** 01 - Assistente obrigatório do editor; 03 - Objetivo clínico e presets de micronutrientes.

**Status:** implemented

- [x] Publicação exige energia, macros, fibras, água e micronutrientes prioritários.
- [x] Publicação exige etapas obrigatórias do assistente concluídas.
- [x] Refeições sem substituições revisadas aparecem como aviso de qualidade.
- [x] O nutricionista precisa confirmar publicação quando houver esse aviso.
- [x] A versão publicada continua imutável.
- [x] Há teste SQL e de interface para bloqueio, aviso e confirmação.

**Implementation notes**

- Gates de qualidade adicionados em `src/lib/planAssistant.ts`.
- O editor agora possui meta de água e bloqueia revisão/publicação quando faltam metas ou micronutrientes prioritários.
- Publicação com item sem substituição revisada exige segundo clique de confirmação.
- `publication_portal.test.sql` cobre bloqueio SQL de metas obrigatórias.
- `NutritionWorkspace.ui.test.tsx` cobre aviso e confirmação no front.
- A imutabilidade publicada segue garantida pelos triggers existentes e pelo teste SQL já presente.
