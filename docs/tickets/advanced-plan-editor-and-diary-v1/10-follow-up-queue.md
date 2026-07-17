# 10 - Fila de acompanhamento do nutricionista

**What to build:** o nutricionista ve uma fila central de acompanhamento priorizada por risco clinico simples e recencia. Em cada alerta, pode enviar orientacao curta, solicitar revisao/substituicao ou marcar como acompanhado.

**Blocked by:** 09 - Regras de alerta do acompanhamento.

**Status:** implemented

- [x] A fila ordena sintomas fortes, pedido de ajuda, refeicao pulada recorrente, troca nao aprovada, fome/saciedade extrema e depois recencia.
- [x] O nutricionista pode enviar orientacao curta registrada no BSNutri.
- [x] O nutricionista pode solicitar revisao ou substituicao.
- [x] O nutricionista pode marcar alerta como acompanhado.
- [x] Recepcao nao acessa a fila clinica.
- [x] Ha teste SQL e de interface para acoes rapidas e prioridade.

## Implementation notes

- Added `follow_up_queue` view with `priority_score` and clinical RLS inherited from alerts.
- Added `follow_up_actions` to register guidance, review requests, substitution requests and followed-up actions.
- Added `create_follow_up_action()` RPC for quick actions and audit trail.
- Updated `CareWorkspace` to consume the prioritized queue and expose quick actions.
- Added SQL and UI tests for priority and action flows.
