# 09 - Regras de alerta do acompanhamento

**What to build:** o diario ampliado gera alertas apenas para desvio relevante: refeicao pulada, troca nao aprovada, fome ou saciedade extrema, sintoma moderado ou forte, ou pedido de ajuda.

**Blocked by:** 08 - Diario ampliado do paciente.

**Status:** implemented

- [x] Refeicao pulada pode gerar alerta.
- [x] Troca nao aprovada pode gerar alerta.
- [x] Fome ou saciedade extrema pode gerar alerta.
- [x] Sintoma moderado ou forte pode gerar alerta.
- [x] Pedido de ajuda sempre gera alerta.
- [x] Registro normal sem desvio nao gera alerta.
- [x] Ha teste de regra para cada gatilho.

## Implementation notes

- Added `20260717143000_follow_up_alert_rules.sql` to keep alerts limited to relevant deviations.
- Added `follow_up_alert_rules.test.sql` with isolated SQL coverage for every trigger and the no-deviation path.
