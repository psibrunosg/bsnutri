# 06 - Configuração de Google Drive por organização

**What to build:** a organização passa a ter um estado de integração com Google Drive para fotos do diário. Sem Drive conectado, o sistema bloqueia upload de foto e mantém diário sem foto.

**Blocked by:** None - can start immediately.

**Status:** ready-for-agent

- [ ] A organização consegue armazenar status de Drive conectado ou ausente.
- [ ] O paciente vê upload de foto desabilitado quando não há Drive conectado.
- [ ] O diário sem foto continua disponível.
- [ ] Recepção não acessa a configuração clínica nem fotos.
- [ ] Há teste SQL de isolamento por organização.
- [ ] A chamada externa fica isolada em um cliente substituível nos testes.
