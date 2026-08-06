# Plano de termino do MVP BSNutri

Atualizado em 17/07/2026 10:15.

## Definicao de pronto

MVP pronto quando tres jornadas reais fecham ponta a ponta no remoto:

1. profissional cria e publica cuidado sem quebrar isolamento;
2. paciente consome plano publicado e registra adesao sem tocar em rascunho;
3. recepcao opera agenda sem acesso clinico.

Tudo isso precisa acontecer com:

1. RLS e funcoes privilegiadas validadas;
2. versoes publicadas imutaveis;
3. testes locais e SQL verdes;
4. publicacao reproduzivel em outro computador.

## Linha de corte

Fica no MVP:

1. autenticacao e troca de papeis;
2. clinica, paciente, avaliacao basica e medidas;
3. plano alimentar com publicacao imutavel;
4. agenda com solicitacao, aprovacao, cancelamento e registro de atendimento;
5. adesao do paciente;
6. substituicoes revisadas;
7. lista de compras reproduzivel;
8. isolamento multi-tenant e por papel.

Fica fora do MVP:

1. portal completo de responsaveis e dependentes;
2. pagamentos, WhatsApp, calendario externo e prontuario de terceiros;
3. BI avancado, automacoes preditivas e catalogo comunitario amplo;
4. restauracao completa de versoes e features nao bloqueantes;
5. redesign ou abstracoes novas sem impacto direto nas jornadas acima.

## Sequencia de execucao

## Caminho critico

Se a meta for fechar o MVP com o menor risco e o menor retrabalho, a ordem correta agora e esta:

1. provar login e jornada dos 3 papeis no deploy publicado;
2. resolver qualquer quebra funcional descoberta nesse smoke;
3. fechar o hardening minimo de Supabase que ainda ficou em aberto;
4. consolidar documentacao e pacote reproduzivel do piloto.

Tudo fora disso so entra agora se bloquear diretamente uma dessas 4 entregas.

### Fase 1. Zerar banco e seguranca

Objetivo:
remover bloqueios de banco antes de mexer em interface.

Status:
quase concluida.

Passos:

1. Manter verde o pacote SQL remoto:
   `bootstrap_organization`,
   `rls_isolation`,
   `publication_portal`,
   `appointments_adherence`,
   `mvp_smoke`.
2. Revisar toda funcao `security definer` ligada a publicacao, agenda, lista e adesao.
3. Confirmar `search_path` fixo, autorizacao por tenant/papel e `EXECUTE` restrito.
4. Garantir que migration aplicada nao seja reescrita; so novas migrations corrigem delta.

Bloqueadores de deploy:

1. acesso cruzado entre clinicas;
2. paciente lendo rascunho;
3. mutacao de versao publicada;
4. recepcao lendo dado clinico;
5. compartilhamento ou lista gerada sem vinculo/publicacao valida.

Saida obrigatoria:

1. 100% das suites SQL aprovadas no remoto.
2. nenhum papel le ou altera dado fora da propria permissao.
3. correcao RLS do portal do paciente mantida pela migration `20260717084500_fix_patient_portal_null_email_rls.sql`.

### Fase 2. Fechar jornadas essenciais

Objetivo:
garantir que produto entrega valor sem depender de fluxo manual fora da plataforma.

Fluxo do profissional:

1. entrar;
2. criar clinica ou operar clinica existente;
3. cadastrar paciente;
4. registrar avaliacao e medidas minimas;
5. montar plano;
6. revisar substituicoes pendentes;
7. publicar versao imutavel.

Fluxo da agenda:

1. solicitar atendimento;
2. aprovar ou rejeitar;
3. cancelar;
4. registrar atendimento presencial ou online.

Fluxo do paciente:

1. abrir plano publicado vigente;
2. registrar adesao;
3. escolher substituicao revisada ou solicitar troca;
4. consultar lista de compras por periodo.

Fluxo da recepcao:

1. acessar agenda permitida;
2. operar estados da agenda dentro do papel;
3. nunca acessar pacientes clinicos, metas, planos, check-ins ou alertas.

Status:
em aberto, agora e a fase mais importante.

Regra de trabalho:

1. corrigir so o que bloquear esses fluxos;
2. sem criar modulo novo se adaptacao curta resolve;
3. mobile e desktop precisam fechar jornada.

Saida obrigatoria:

1. recarregar pagina preserva estado salvo no Supabase.
2. cada fluxo termina sem erro visivel.
3. smoke autenticado cobre pelo menos um login de profissional, um de recepcao e um de paciente na versao publicada.

### Fase 3. Validacao de release

Objetivo:
provar que MVP sai do ambiente de desenvolvimento e roda como produto.

Status:
parcialmente concluida.

Passos:

1. Manter `npm run lint` verde.
2. Manter `npm test` verde.
3. Manter `npm run build` verde.
4. Executar roteiro remoto A/B de `docs/rls-test-matrix.md`.
5. Validar URL de auth, redirects, recuperacao de senha e variaveis publicas do pipeline.
6. Fazer smoke autenticado na versao publicada via GitHub Pages.

Saida obrigatoria:

1. pipeline verde.
2. login volta para app certo.
3. teste A/B nao encontra vazamento entre clinicas.
4. app publicado abre sem erro fatal.
5. fluxo de recuperar senha e telas publicas de auth seguem funcionando no deploy.

### Fase 4. Consolidacao e entrega

Objetivo:
deixar projeto reproduzivel e pronto para seguir em outra maquina.

Passos:

1. remover fixture e arquivo temporario que nao entra no piloto;
2. manter so dados sinteticos e harness util;
3. atualizar README com setup, validacao, roteiro piloto e ordem de testes;
4. revisar diff final e separar o que e MVP do que e experimento;
5. registrar commit ou tag exata do piloto;
6. salvar handoff final no Drive.

Saida obrigatoria:

1. outro computador sobe projeto com `npm ci`;
2. variaveis publicas e passos minimos estao documentados;
3. handoff aponta proximo passo exato.

## Criterio final de aceite

So chamar de MVP fechado quando todos os itens abaixo estiverem comprovados:

1. `npm test`, `npm run lint` e `npm run build` continuam verdes no estado final.
2. as suites SQL remotas centrais continuam verdes no estado final.
3. profissional consegue entrar, operar dashboard, paciente e plano sem erro bloqueante.
4. recepcao consegue operar agenda sem enxergar dado clinico.
5. paciente consegue entrar e consumir apenas conteudo publicado.
6. recuperacao de senha e redirect de auth continuam funcionando no deploy.
7. nenhum teste manual encontra vazamento entre clinicas ou entre papeis.
8. README e handoff permitem retomar o projeto em outro computador sem depender desta conversa.

## Ordem pratica de fechamento

1. Confirmar fixture remota dos 3 usuarios.
2. Rodar smoke autenticado do deploy.
3. Corrigir o que quebrar nesse smoke.
4. Revisar funcoes `security definer` e politica de auth.
5. Atualizar README com setup e validacao.
6. Revisar diff final do MVP.
7. Registrar pacote final do piloto.

## Pendencias atuais confirmadas

1. `npm test`: 9/9 aprovados.
2. `npm run lint`: aprovado.
3. `npm run build`: aprovado.
4. suites SQL remotas validadas: `bootstrap_organization`, `rls_isolation`, `publication_portal`, `appointments_adherence`, `mvp_smoke`.
5. deploy publicado em `https://psibrunosg.github.io/bsnutri/` abriu sem erro fatal e telas publicas de auth responderam.
6. a fixture persistente do smoke autenticado foi recriada no remoto em 17/07/2026 com os artefatos locais abaixo.
7. ja existem dois artefatos locais para recriar essa fixture:
   `work/MVP_REMOTE_FIXTURE.sql` para cliente SQL tradicional
   e `work/MVP_REMOTE_FIXTURE_ONE_SHOT.sql` para `supabase db query`.
8. a validacao da fixture remota em 17/07/2026 confirmou:
   `auth_users = 3`,
   `organizations = 1`,
   `memberships = 2`,
   `patients = 1`,
   `published_plans = 1`,
   `requested_appointments = 1`,
   `checkins = 1`,
   `open_alerts = 1`.
9. o smoke autenticado no deploy ainda esta bloqueado no Auth: em 17/07/2026 o endpoint `POST /auth/v1/token?grant_type=password` retornou `500` para os 3 usuarios sinteticos.
10. o ajuste estrutural em `auth.identities.provider_id` e `auth.users.raw_user_meta_data` aproximou os usuarios sinteticos do formato real, mas ainda nao removeu o `500`; a hipotese principal agora e que usuario criado por SQL direto nao equivale integralmente ao fluxo do GoTrue.
11. o admin Auth da Supabase criou 3 usuarios reais com sucesso em 17/07/2026:
   `mvp2.profissional@teste.com`,
   `mvp2.recepcao@teste.com`,
   `mvp2.paciente@teste.com`.
12. para reduzir retrabalho, o dominio do MVP foi separado do Auth em artefatos novos:
   `work/MVP_DOMAIN_BIND_BY_EMAIL_ONE_SHOT.sql`
   e `work/MVP_DOMAIN_BIND_REAL_USERS_ONE_SHOT.sql`.
13. o bind com usuarios reais foi aplicado com sucesso e confirmou no remoto:
   `orgs = 1`,
   `memberships = 2`,
   `patients = 1`,
   `published_plans = 1`,
   `appointments = 1`,
   `open_alerts = 1`.
14. o smoke real no deploy publicado em 17/07/2026 mostrou:
   `profissional` entra e vê dashboard com paciente;
   `paciente` entra no portal e vê plano, lista de compras e solicitação de consulta sem erro visível de lista;
   `recepcao` ainda aparece na UI antiga do deploy publicado, então o ajuste de frontend local ainda precisa ser publicado para validação final do papel.
15. o frontend local já foi ajustado para abrir `recepcao` direto em `Agenda e adesão` e ocultar navegação clínica; `npm run lint`, `npm test` e `npm run build` passaram após a mudança.
16. no deploy publicado ainda resta uma chamada desnecessária a `claim_patient_access` no fluxo do paciente, indicando que o site publicado ainda não incorporou a correção local de frontend.
17. Supabase advisors ainda apontam funcoes `security definer` expostas a `authenticated` e `Leaked Password Protection Disabled`; isso precisa decisao final de hardening antes de chamar MVP fechado.
18. worktree segue suja com alteracoes em frontend, migration e testes SQL; consolidar so apos revisar o que entra no piloto.

## Proxima acao exata

1. publicar a versao atual do frontend com as correcoes de `recepcao` e do fluxo de `claim_patient_access`;
2. repetir smoke no deploy publicado com `mvp2.profissional@teste.com`, `mvp2.recepcao@teste.com` e `mvp2.paciente@teste.com`;
3. confirmar que `recepcao` cai direto em `Agenda e adesão` sem navegação clínica e que `paciente` não chama mais `claim_patient_access` sem necessidade;
4. por fim, decidir o hardening final das funcoes `security definer` e registrar o pacote exato do piloto.
