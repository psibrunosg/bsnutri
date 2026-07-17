# 01 - Base versionada de formularios de anamnese

**What to build:** criar a base minima para formularios versionados de pre-consulta e anamnese, com templates, versoes publicadas, campos e respostas.

**Blocked by:** None - can start immediately.

**Status:** implemented

- [x] Clinica cria template de formulario.
- [x] Template publicado gera versao imutavel.
- [x] Campo suporta texto curto, texto longo, numero, escala, selecao e data.
- [x] Resposta aponta para a versao respondida.
- [x] Recepcao nao acessa respostas clinicas.
- [x] Ha teste SQL de RLS por papel e organizacao.

## Implementacao

- Migration: `20260717160000_intake_consultation_templates.sql`.
- Teste SQL: `post_mvp_market_features.test.sql`.
