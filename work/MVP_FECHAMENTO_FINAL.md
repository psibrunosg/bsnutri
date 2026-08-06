# Fechamento final do MVP BSNutri

Atualizado em sexta-feira, 17 de julho de 2026, apos o deploy do commit `dabbf0c`.

## Definicao real de pronto

O MVP so fecha quando estas 3 jornadas estiverem provadas no deploy publicado:

1. `profissional` entra, acessa paciente e opera plano sem erro bloqueante.
2. `paciente` entra e consome somente conteudo publicado, sem acionar fluxo indevido.
3. `recepcao` entra e opera agenda sem navegar por dados clinicos.

## Estado atual

1. `profissional`: provado no deploy publicado.
2. `paciente`: provado no deploy publicado, sem chamada indevida de `claim_patient_access`.
3. `recepcao`: provado no deploy publicado em `Agenda e adesão`.
4. `lint`, `test` e `build`: verdes localmente em 17/07/2026.
5. suites SQL centrais: validadas no remoto.
6. fixture remota com usuarios reais: pronta para repetir o smoke.

## Linha de corte

Entra no MVP:

1. Auth funcional por papel.
2. Clinica, paciente, avaliacao basica e medidas.
3. Plano alimentar com publicacao imutavel.
4. Agenda com solicitacao, aprovacao, cancelamento e registro.
5. Adesao, substituicoes e lista de compras.
6. Isolamento por tenant e por papel.

Fica fora:

1. Dependentes e responsaveis completos.
2. Pagamentos, WhatsApp e integracoes externas.
3. BI avancado e automacoes preditivas.
4. Redesign e features nao bloqueantes.

## Ordem final de fechamento

1. Publicar o frontend local atual.
2. Repetir o smoke no deploy com:
   `mvp2.profissional@teste.com`
   `mvp2.recepcao@teste.com`
   `mvp2.paciente@teste.com`
3. Confirmar que `recepcao` cai direto em agenda e sem menu clinico.
4. Confirmar que `paciente` nao chama `claim_patient_access` sem necessidade.
5. Revisar os avisos restantes de hardening do Supabase.
6. Consolidar README, migrations finais, testes e artefatos de `work/`.
7. Registrar o pacote final do piloto e o handoff de retomada.

## Roteiro operacional

### Etapa 1. Validacao local antes do push

Rodar:

```powershell
npm run lint
npm test
npm run build
```

Evidencia esperada:

1. os 3 comandos terminam sem erro;
2. o `build` gera `dist/`;
3. nenhuma mudanca nova aparece alem do diff ja conhecido do MVP.

### Etapa 2. Publicacao no GitHub Pages

O workflow atual publica automaticamente em push para `main`:

1. arquivo: `.github/workflows/deploy.yml`
2. passos: `npm ci` -> `npm run lint` -> `npm test` -> `npm run build` -> upload de `dist` -> deploy pages

Evidencia esperada:

1. job `validate` verde;
2. job `deploy` verde;
3. deploy acessivel em `https://psibrunosg.github.io/bsnutri/`.

### Etapa 3. Smoke autenticado no deploy

Perfis do smoke:

1. `mvp2.profissional@teste.com`
2. `mvp2.recepcao@teste.com`
3. `mvp2.paciente@teste.com`

Evidencia esperada:

1. `profissional` entra e ve paciente ou dashboard clinico sem erro bloqueante;
2. `recepcao` entra e cai direto em agenda, sem menu clinico;
3. `paciente` entra e ve plano vigente, lista de compras e fluxo de consulta sem erro visivel;
4. nao aparece chamada indevida de `claim_patient_access` para paciente ja vinculado.

### Etapa 4. Hardening minimo

Checar:

1. funcoes `security definer` criticas;
2. `search_path` fixo;
3. permissoes de `EXECUTE`;
4. decisao registrada sobre `Leaked Password Protection`.

Evidencia esperada:

1. nenhum risco conhecido fica sem decisao;
2. o que nao entrar no piloto fica explicitamente registrado como pos-MVP.

### Etapa 5. Fechamento reproduzivel

Checar:

1. README com setup, secrets publicos e ordem de validacao;
2. artefatos `work/` separados entre util e descartavel;
3. handoff no Drive apontando proximo passo exato.

Evidencia esperada:

1. outro computador consegue retomar sem depender desta conversa;
2. a fixture remota e o smoke tem comando e ordem definidos.

## Gates finais

### Gate 1. Deploy publicado

Passa quando:

1. o deploy publicado refletir o frontend local corrigido;
2. `recepcao` nao enxergar navegacao clinica;
3. `paciente` nao disparar fluxo de claim indevido.

### Gate 2. Seguranca minima

Passa quando:

1. as funcoes `security definer` criticas estiverem revisadas;
2. `search_path` e permissoes de `EXECUTE` estiverem conferidos;
3. a decisao sobre `Leaked Password Protection` estiver registrada.

### Gate 3. Entrega reproduzivel

Passa quando:

1. outro computador conseguir subir o projeto com o README atual;
2. a ordem de validacao estiver documentada;
3. o handoff apontar comandos, credenciais sinteticas e proximo passo.

## Nao chamar de concluido enquanto

1. `recepcao` nao estiver provado no deploy.
2. `paciente` ainda disparar `claim_patient_access` no deploy.
3. o hardening minimo do Supabase estiver indefinido.
4. a retomada em outra maquina ainda depender desta conversa.

## Proximo passo objetivo

1. registrar a decisao final de hardening minimo do Supabase;
2. consolidar a reproducao final do piloto;
3. decidir se ainda falta algum ajuste pequeno de documentacao.

## Evidencia local mais recente

Em 17/07/2026:

1. `npm run lint`: aprovado
2. `npm test`: 3 arquivos e 9 testes aprovados
3. `npm run build`: aprovado com geracao de `dist/`

## Fechamento final

Em sexta-feira, 17 de julho de 2026:

1. deploy publicado provado com `profissional`, `recepcao` e `paciente`
2. advisor remoto de seguranca do banco retornou `No issues found`
3. `password_min_length` confirmado em `8`
4. `password_hibp_enabled` permaneceu `false` por decisao registrada do piloto
5. reproducao final consolidada em `docs/MVP_PILOTO_REPRODUCAO_FINAL.md`
