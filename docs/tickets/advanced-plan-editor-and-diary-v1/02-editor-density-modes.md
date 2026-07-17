# 02 - Modos consulta rápida e técnico

**What to build:** a tela de plano passa a ter alternância entre consulta rápida e técnico. O modo consulta rápida prioriza refeições, horários, alimentos, quantidades e observações. O modo técnico mostra metas, cálculos, pendências, equivalentes, visibilidade do paciente e publicação.

**Blocked by:** 01 - Assistente obrigatório do editor.

**Status:** implemented

- [x] A alternância muda apenas a densidade da tela, não o rascunho salvo.
- [x] O modo consulta rápida permite montar refeições com poucos cliques.
- [x] O modo técnico mostra metas, pendências e ações de revisão/publicação.
- [x] A interface funciona em desktop e largura móvel.
- [x] Há teste de interface cobrindo alternância sem perda de dados.

**Implementation notes**

- Adicionado seletor de densidade `Consulta rapida` / `Tecnico` no editor de plano.
- O modo rapido preserva o mesmo rascunho e prioriza montagem de refeicoes e salvamento.
- O modo tecnico expõe metas, calculos, pendencias do assistente e acoes de revisao/publicacao.
- Cobertura adicionada em `src/NutritionWorkspace.ui.test.tsx`.
