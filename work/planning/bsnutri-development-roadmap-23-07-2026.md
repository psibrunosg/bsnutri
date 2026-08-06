# BSNutri: mapa de desenvolvimento total

Atualizado em 23/07/2026 às 17:35.

## Decisão executiva

O programa seguirá o núcleo nutricionista-paciente antes dos módulos administrativos. A ordem inicial é:

1. Confiabilidade do Portal do Paciente.
2. Substituições inteligentes e revisáveis.
3. Diário ligado ao plano publicado.
4. Resumo semanal e fila clínica explicável.
5. Visibilidade configurável por paciente.

O editor completo continua prioritariamente desktop. O mobile será usado para consulta e ações rápidas. Segurança acompanha cada entrega, mesmo quando jurídico e administração não são o foco do ciclo.

## Especificação principal

1. GitHub: [issue #7](https://github.com/psibrunosg/bsnutri/issues/7)
2. Documento: `docs/specs/bsnutri-development-program-v1.md`
3. Escopo: 82 histórias de usuário, 33 decisões técnicas, 10 decisões de teste, gates e Definition of Done.

## Fase 0: confiabilidade

1. [#8 T01: Portal do Paciente resiliente a falhas parciais](https://github.com/psibrunosg/bsnutri/issues/8)

## Fase 1: prescrição e catálogo

Trabalho existente reutilizado:

1. [#2 Novo shell desktop do construtor de planos](https://github.com/psibrunosg/bsnutri/issues/2)
2. [#3 Catálogo com alimento, preparação e combinação](https://github.com/psibrunosg/bsnutri/issues/3)
3. [#4 Galeria e dimensões dos modelos de plano](https://github.com/psibrunosg/bsnutri/issues/4)
4. [#5 Aplicação adaptável do modelo ao paciente](https://github.com/psibrunosg/bsnutri/issues/5)
5. [#6 Modelos pessoais e da clínica](https://github.com/psibrunosg/bsnutri/issues/6)

Novas fatias:

1. [#9 T02: Sistema visual e estados compartilhados](https://github.com/psibrunosg/bsnutri/issues/9)
2. [#10 T03: Procedência e importação segura do catálogo](https://github.com/psibrunosg/bsnutri/issues/10)
3. [#11 T04: Busca cultural, tags, favoritos e renders](https://github.com/psibrunosg/bsnutri/issues/11)
4. [#12 T05: Receitas, rendimento e medidas caseiras](https://github.com/psibrunosg/bsnutri/issues/12)
5. [#13 T06: Faixas nutricionais e edição rápida](https://github.com/psibrunosg/bsnutri/issues/13)
6. [#14 T07: Comparação, pré-visualização e auditoria](https://github.com/psibrunosg/bsnutri/issues/14)
7. [#15 T08: Motor explicável de substituições](https://github.com/psibrunosg/bsnutri/issues/15)
8. [#16 T09: Curadoria e uso de substituições](https://github.com/psibrunosg/bsnutri/issues/16)

## Fase 2: paciente e acompanhamento

1. [#17 T10: Visibilidade configurável por paciente](https://github.com/psibrunosg/bsnutri/issues/17)
2. [#18 T11: Diário vinculado ao plano publicado](https://github.com/psibrunosg/bsnutri/issues/18)
3. [#19 T12: Contexto do diário e fallbacks de foto](https://github.com/psibrunosg/bsnutri/issues/19)
4. [#20 T13: Resumo semanal e fila clínica](https://github.com/psibrunosg/bsnutri/issues/20)
5. [#21 T14: Ciclo completo de metas](https://github.com/psibrunosg/bsnutri/issues/21)
6. [#22 T15: Página Hoje e lista de compras](https://github.com/psibrunosg/bsnutri/issues/22)
7. [#23 T16: Exames e evolução longitudinal](https://github.com/psibrunosg/bsnutri/issues/23)
8. [#24 T17: Biblioteca e sequências educativas](https://github.com/psibrunosg/bsnutri/issues/24)

## Fase 3: rotina clínica e comunicação

1. [#25 T18: Pré-consulta e resumo longitudinal](https://github.com/psibrunosg/bsnutri/issues/25)
2. [#26 T19: Rascunhos clínicos auditáveis](https://github.com/psibrunosg/bsnutri/issues/26)
3. [#27 T20: PDFs, relatórios e exportações](https://github.com/psibrunosg/bsnutri/issues/27)
4. [#28 T21: Mensagens, lembretes e tarefas](https://github.com/psibrunosg/bsnutri/issues/28)

## Fase 4: operação, gestão e plataforma

1. [#29 T22: Recepção sem acesso clínico](https://github.com/psibrunosg/bsnutri/issues/29)
2. [#30 T23: Gestão de equipe e operação](https://github.com/psibrunosg/bsnutri/issues/30)
3. [#31 T24: Hardening de RLS, storage e recuperação](https://github.com/psibrunosg/bsnutri/issues/31)
4. [#32 T25: PWA resiliente e ações rápidas mobile](https://github.com/psibrunosg/bsnutri/issues/32)

## Fase 5: modelos especializados

1. [#33 T26: Contrato de validação](https://github.com/psibrunosg/bsnutri/issues/33)
2. [#34 T27: Low FODMAP por fases](https://github.com/psibrunosg/bsnutri/issues/34)
3. [#35 T28: Cetogênica revisável](https://github.com/psibrunosg/bsnutri/issues/35)
4. [#36 T29: Renal revisável](https://github.com/psibrunosg/bsnutri/issues/36)
5. [#37 T30: Bariátrica por fases](https://github.com/psibrunosg/bsnutri/issues/37)
6. [#38 T31: Gestação e lactação](https://github.com/psibrunosg/bsnutri/issues/38)
7. [#39 T32: Pediatria e abordagens avançadas](https://github.com/psibrunosg/bsnutri/issues/39)

## Fronteira atual

1. A issue #8 foi concluída e fechada em 24/07/2026.
2. A issue #9 foi concluída e fechada em 24/07/2026.
3. As issues #3 e #10 estão implementadas no worktree, mas só poderão ser fechadas após a suíte SQL local validar as migrations e as políticas.
4. A próxima fronteira é ativar Docker Desktop, executar `supabase test db --local`, fechar #3 e #10 e então iniciar #11.
5. Depois, seguir para #13 e #14 conforme os bloqueadores forem comprovadamente concluídos.
6. Não iniciar integrações externas nem ideias frágeis neste programa.

## Status auditado em 24/07/2026

1. #8, Portal resiliente: concluída. Treze testes focados, lint, build e `git diff --check` aprovados.
2. #9, sistema visual: concluída. Tokens primitivos, semânticos e de componente consolidam botões, painéis, foco e estados de aviso ou erro.
3. #3, contrato do catálogo: implementação pronta. Dezessete testes focados, lint, build e `git diff --check` aprovados; falta `supabase test db --local` por indisponibilidade do Docker/Postgres local.
4. #10, procedência e importação: implementação pronta. Dezoito testes focados, lint, build e `git diff --check` aprovados; a validação SQL local depende do mesmo ambiente.
5. #11 a #27: majoritariamente parciais no worktree, exigem auditoria por critério antes de serem fechadas.
6. #12, #28 a #30 e #32 a #39: pendentes.
5. A auditoria completa está em `work/planning/auditoria-mapa-execucao-24-07-2026.md`.
6. A prontidão do catálogo e das substituições está em `work/planning/prontidao-catalogo-substituicoes-24-07-2026.md`.

## Qualidade obrigatória

1. Jornada demonstrável de ponta a ponta.
2. Teste no maior seam adequado.
3. Teste SQL positivo e negativo quando houver banco ou permissão.
4. `npm test`, `npm run lint` e `npm run build`.
5. Publicação imutável, auditoria e acessibilidade preservadas.
6. Handoff atualizado no Google Drive.

## Riscos registrados

1. O worktree atual contém implementações parciais ainda não consolidadas.
2. Issues abertas podem ter critérios parcialmente atendidos e exigem auditoria antes de codificação.
3. Modelos especializados não podem ser tratados como simples etiquetas.
4. Integrações aumentam suporte, dependência externa e risco de privacidade.
5. Aplicativo nativo, marketplace, comunidade, loja, gamificação, avaliação por fotos e IA clínica avançada permanecem como ideias frágeis.
