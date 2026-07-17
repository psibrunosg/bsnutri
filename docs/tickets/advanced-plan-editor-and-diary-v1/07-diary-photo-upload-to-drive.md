# 07 - Foto do diário no Google Drive

**What to build:** o paciente envia foto de refeição quando a organização tem Drive conectado. O sistema salva a foto no Drive com estrutura organização, nutricionista, paciente e ano-mês, e registra metadados no banco.

**Blocked by:** 06 - Configuração de Google Drive por organização.

**Status:** ready-for-agent

- [ ] Upload usa a estrutura de pastas definida para a organização.
- [ ] Nome do arquivo usa data, refeição e ID curto do registro.
- [ ] O banco salva ID do arquivo, paciente, refeição, ocorrência e autor.
- [ ] Falha no Drive não cria registro de foto inconsistente.
- [ ] O paciente só acessa fotos próprias.
- [ ] Há teste com cliente de Drive simulado.
