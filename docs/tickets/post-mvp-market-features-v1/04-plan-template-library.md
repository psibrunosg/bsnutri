# 04 - Biblioteca de modelos de plano

**What to build:** permitir que a clinica salve modelos de plano e copie um modelo para um paciente sem manter vinculo mutavel com o original.

**Blocked by:** None - can start after current editor is stable.

**Status:** implemented

- [x] Profissional salva plano como modelo da organizacao.
- [x] Modelo tem nome, objetivo e tags.
- [x] Modelo pode ser copiado para novo plano do paciente.
- [x] Alterar modelo nao altera plano ja copiado.
- [x] Apenas equipe clinica acessa modelos.
- [x] Ha teste SQL de copia independente.

## Implementacao

- Biblioteca simples em `NutritionWorkspace.tsx`.
- RPCs: `create_plan_template_from_plan` e `copy_plan_template_to_patient`.
- Teste SQL: `post_mvp_market_features.test.sql`.
