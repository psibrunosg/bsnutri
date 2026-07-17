# 07 - Foto do diário no Google Drive

**What to build:** o paciente envia foto de refeição quando a organização tem Drive conectado. O sistema salva a foto no Drive com estrutura organização, nutricionista, paciente e ano-mês, e registra metadados no banco.

**Blocked by:** 06 - Configuração de Google Drive por organização.

**Status:** implemented

- [x] Upload usa a estrutura de pastas definida para a organização.
- [x] Nome do arquivo usa data, refeição e ID curto do registro.
- [x] O banco salva ID do arquivo, paciente, refeição, ocorrência e autor.
- [x] Falha no Drive não cria registro de foto inconsistente.
- [x] O paciente só acessa fotos próprias.
- [x] Há teste com cliente de Drive simulado.

**Implementation notes**

- `driveClient.ts` monta caminho `organização/nutricionista/paciente/ano-mês` e nome `data-refeição-idcurto.jpg`.
- O portal salva o check-in, faz upload no Drive e só então insere metadados em `meal_checkin_photos`.
- Se o Drive falhar, nenhum registro de foto é criado.
- `meal_checkin_photos` guarda arquivo, paciente, refeição, ocorrência, check-in e autor.
- RLS permite paciente acessar apenas fotos próprias e equipe clínica autorizada.
- `PatientPortal.test.tsx` cobre sucesso e falha com cliente de Drive simulado.
