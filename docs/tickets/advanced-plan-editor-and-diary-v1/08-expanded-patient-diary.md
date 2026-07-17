# 08 - Diário ampliado do paciente

**What to build:** o paciente registra refeição com estado, fome, saciedade, sintomas, observação, pedido de ajuda e foto opcional quando o Drive estiver conectado.

**Blocked by:** 05 - Controles de visibilidade do plano no portal; 06 - Configuração de Google Drive por organização.

**Status:** implemented

- [x] O diário permite registrar refeição feita, pulada ou adaptada.
- [x] O paciente informa fome e saciedade em escala simples.
- [x] O paciente registra sintoma com intensidade.
- [x] O paciente pode marcar "preciso de ajuda".
- [x] Foto aparece apenas quando Drive estiver conectado.
- [x] O registro aponta para plano publicado e refeição prevista.
- [x] Há teste de portal para diário com e sem foto.

**Implementation notes**

- `meal_checkins` recebeu `symptom_intensity` e `help_requested`.
- Pedido de ajuda gera alerta urgente no fluxo de alertas existente.
- O portal envia estado, fome, saciedade, sintomas, intensidade, ajuda, observação e foto opcional.
- O vínculo com plano publicado/refeição prevista segue no trigger `validate_checkin_chain`.
- `PatientPortal.test.tsx` cobre diário sem foto e fluxo com foto via Drive.
