# Checklist final do MVP BSNutri

Atualizado em sexta-feira, 17 de julho de 2026, apos o deploy do commit `dabbf0c`.

## Quando pode chamar de MVP concluido

Somente quando estas 3 jornadas estiverem provadas no deploy publicado:

1. `profissional` entra, acessa paciente e opera plano sem erro bloqueante.
2. `paciente` entra e consome somente conteudo publicado.
3. `recepcao` entra e opera agenda sem navegar em dados clinicos.

## Ordem final de validacao

1. rodar `npm run lint`
2. rodar `npm test`
3. rodar `npm run build`
4. publicar a versao atual em `main`
5. esperar os jobs `validate` e `deploy` verdes
6. abrir `https://psibrunosg.github.io/bsnutri/`
7. repetir o smoke com:
   `mvp2.profissional@teste.com`
   `mvp2.recepcao@teste.com`
   `mvp2.paciente@teste.com`

## Evidencia minima para aprovar

1. `profissional` entra e ve dashboard ou paciente sem erro bloqueante.
2. `recepcao` cai direto em agenda e sem menu clinico.
3. `paciente` entra, ve plano vigente e nao chama `claim_patient_access` sem necessidade.
4. o deploy publicado reflete o frontend local mais recente.
5. `lint`, `test` e `build` continuam verdes.
6. as suites SQL centrais continuam validadas.

## Evidencia local mais recente

Em sexta-feira, 17 de julho de 2026:

1. `npm run lint`: aprovado
2. `npm test`: 3 arquivos e 9 testes aprovados
3. `npm run build`: aprovado com geracao de `dist/`

## Evidencia de producao mais recente

No deploy publicado apos o commit `dabbf0c`:

1. `profissional`: entrou e abriu `Pacientes`
2. `recepcao`: entrou e abriu `Agenda e adesão`
3. `paciente`: entrou e abriu `Olá, Paciente`
4. nao houve erros de rede nas 3 jornadas
5. nao houve chamada indevida de `claim_patient_access`

## Hardening minimo fechado

Em sexta-feira, 17 de julho de 2026:

1. `npx --yes supabase@latest db advisors --type security --db-url ...`: `No issues found`
2. `password_min_length`: confirmado em `8`
3. `password_hibp_enabled`: mantido em `false` por decisao registrada do piloto
4. reproducao final consolidada em `docs/MVP_PILOTO_REPRODUCAO_FINAL.md`

## Gates finais

### Gate 1. Deploy publicado

1. o site publicado reflete o frontend local corrigido
2. `recepcao` nao enxerga navegacao clinica
3. `paciente` nao dispara fluxo de claim indevido

### Gate 2. Seguranca minima

1. funcoes `security definer` criticas revisadas
2. `search_path` e `EXECUTE` conferidos
3. decisao registrada sobre `Leaked Password Protection`

### Gate 3. Entrega reproduzivel

1. outro computador consegue retomar sem depender desta conversa
2. fixture remota e smoke tem ordem definida
3. handoff aponta o proximo passo exato

## Referencias

1. `work/MVP_FECHAMENTO_FINAL.md`
2. `docs/rls-test-matrix.md`
3. `G:\Meu Drive\0.Jarvis\11_handoffs\bsnutri_17_07_2026_0925.md`
