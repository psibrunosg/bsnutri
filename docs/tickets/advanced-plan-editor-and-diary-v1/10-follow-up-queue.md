# 10 - Fila de acompanhamento do nutricionista

**What to build:** o nutricionista vê uma fila central de acompanhamento priorizada por risco clínico simples e recência. Em cada alerta, pode enviar orientação curta, solicitar revisão/substituição ou marcar como acompanhado.

**Blocked by:** 09 - Regras de alerta do acompanhamento.

**Status:** ready-for-agent

- [ ] A fila ordena sintomas fortes, pedido de ajuda, refeição pulada recorrente, troca não aprovada, fome/saciedade extrema e depois recência.
- [ ] O nutricionista pode enviar orientação curta registrada no BSNutri.
- [ ] O nutricionista pode solicitar revisão ou substituição.
- [ ] O nutricionista pode marcar alerta como acompanhado.
- [ ] Recepção não acessa a fila clínica.
- [ ] Há teste SQL e de interface para ações rápidas e prioridade.
