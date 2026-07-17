# 03 - Objetivo clínico e presets de micronutrientes

**What to build:** o plano passa a ter objetivo clínico e presets editáveis de micronutrientes. Entram emagrecimento, hipertrofia, resistência à insulina, hipertensão, vegetariano e criança/adolescente.

**Blocked by:** 01 - Assistente obrigatório do editor.

**Status:** implemented

- [x] O nutricionista escolhe um ou mais presets clínicos no assistente.
- [x] O sistema sugere micronutrientes prioritários conforme os presets.
- [x] O nutricionista pode editar a lista sugerida antes de publicar.
- [x] A seleção fica preservada no rascunho e no snapshot publicado.
- [x] Há teste de regra para cada preset inicial.

**Implementation notes**

- Presets e micronutrientes foram adicionados ao `assistant_state`, que já é salvo no rascunho e bloqueado junto da versão publicada.
- A regra de sugestão fica em `src/lib/planAssistant.ts`.
- O assistente exibe checkboxes de presets e uma lista editável de micronutrientes prioritários.
- `NutritionWorkspace.test.ts` cobre sugestão para cada preset inicial e retomada do estado salvo.
