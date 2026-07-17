# 06 - Configuração de Google Drive por organização

**What to build:** a organização passa a ter um estado de integração com Google Drive para fotos do diário. Sem Drive conectado, o sistema bloqueia upload de foto e mantém diário sem foto.

**Blocked by:** None - can start immediately.

**Status:** implemented

- [x] A organização consegue armazenar status de Drive conectado ou ausente.
- [x] O paciente vê upload de foto desabilitado quando não há Drive conectado.
- [x] O diário sem foto continua disponível.
- [x] Recepção não acessa a configuração clínica nem fotos.
- [x] Há teste SQL de isolamento por organização.
- [x] A chamada externa fica isolada em um cliente substituível nos testes.

**Implementation notes**

- Adicionada tabela `organization_drive_configs` com status `missing`/`connected`.
- Adicionada RPC `get_patient_drive_status()` para o paciente receber apenas o estado necessário do upload.
- O portal desabilita o input de foto quando Drive está ausente e mantém o check-in textual.
- `driveClient.ts` isola a chamada externa e aceita `fetch` substituível.
- `drive_config_isolation.test.sql` cobre isolamento por organização e bloqueio de recepção.
- `PatientPortal.test.tsx` e `driveClient.test.ts` cobrem o comportamento de interface e o cliente.
