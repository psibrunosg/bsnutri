# 02 - Fluxo de pre-consulta do paciente

**What to build:** permitir que o paciente receba uma tarefa de pre-consulta, salve rascunho e envie a anamnese pelo portal.

**Blocked by:** 01 - Base versionada de formularios de anamnese.

**Status:** implemented

- [x] Profissional atribui formulario publicado ao paciente.
- [x] Paciente ve tarefa pendente no portal.
- [x] Paciente salva rascunho sem enviar.
- [x] Envio valida campos obrigatorios.
- [x] Profissional ve status pendente, rascunho ou enviado.
- [x] Ha teste de interface mobile-basico do envio.

## Implementacao

- Portal: `PatientPortal.tsx`.
- Prontuario profissional: `PatientDetail.tsx`.
- Teste UI: `PatientPortal.test.tsx`.
