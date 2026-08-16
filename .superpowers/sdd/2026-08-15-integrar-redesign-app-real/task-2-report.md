# Task 2: navegação, sessão e shell responsivo

## Status

Implementação concluída no worktree isolado `integrar-redesign-app-real`.

Commit de código e testes: `285b500` (`feat: restore secure session navigation`).

Correção dos achados Important: `c0f4c3d` (`fix: harden session access navigation`).

Correção da re-review: `d98fc5d` (`fix: preserve valid session access`).

## Entrega

- `src/types.ts`: tipos nutricionais da base funcional restaurados e contratos de workspace, papel e acesso do paciente adicionados.
- `src/lib/appRoute.ts` e `src/lib/useAppRoute.ts`: contrato final de páginas e parâmetros opcionais, normalização por página, fallback seguro, serialização, push, replace e popstate.
- `src/lib/sessionBootstrap.ts`: decisão explícita entre profissional, recepção, paciente/responsável, onboarding e erro recuperável.
- `src/lib/supabaseBootstrapDataSource.ts`: consultas tipadas de membership, perfil, vínculo direto, responsável e claim, sempre separando `error` de ausência de dados.
- `src/pages/Login.tsx`: login, cadastro, solicitação de recuperação e definição de nova senha pelo Supabase, sem credenciais preenchidas nem texto de protótipo.
- `src/components/Shell.tsx`: shell visual preservado com identidade do banco e drawer abaixo de 1024 px, overlay, Escape, fechamento após navegação, retorno de foco e anéis de foco visível.
- `src/App.tsx`: bootstrap de sessão, configuração ausente, carregamento global, erro com retry/logout, onboarding apenas por submit, recepção restrita, portal derivado da sessão e estado único de integração para módulos profissionais.
- `src/lib/supabase.ts`: cliente Supabase associado ao tipo gerado `Database`.

O `StoreProvider` não participa mais do runtime. Os módulos antigos com dados locais não são importados pela entrada da aplicação, e a busca no artefato não encontrou strings de protótipo.

## Evidência TDD

### Navegação

RED: `npm test -- src/lib/appRoute.test.ts src/lib/useAppRoute.test.tsx`

- 2 arquivos falharam, 6 testes falharam porque `parseAppRoute`, `routeToSearch` e `useAppRoute` ainda não existiam.

GREEN: mesmo comando.

- 2 arquivos passaram, 6 testes passaram.

### Bootstrap

RED: `npm test -- src/lib/sessionBootstrap.test.ts`

- Após criar apenas o contrato compilável, 6 testes falharam contra o retorno provisório de onboarding.

GREEN: mesmo comando.

- 1 arquivo passou, 6 testes passaram.

### Autenticação

RED: `npm test -- src/pages/Login.test.tsx`

- 3 testes falharam porque o login visual ainda tinha credencial predefinida, não chamava Supabase e não oferecia cadastro/recuperação.

GREEN: mesmo comando.

- 1 arquivo passou, 3 testes passaram.

### Shell

RED: `npm test -- src/components/Shell.test.tsx`

- 3 testes falharam pela ausência do drawer acessível e da identidade real do workspace.

GREEN: mesmo comando.

- 1 arquivo passou, 3 testes passaram.

### Destinos da sessão

RED: `npm test -- src/App.session.test.tsx`

- 4 testes falharam porque `SessionDestination` ainda não existia.

GREEN: mesmo comando.

- 1 arquivo passou, 4 testes passaram.

### Correções da self-review

RED: `npm test -- src/lib/sessionBootstrap.test.ts src/components/Shell.test.tsx`

- 2 de 10 testes falharam: a exceção de domínio “Nenhum cadastro de paciente disponível para este e-mail” era tratada como erro e o foco permanecia no drawer oculto após navegar.

GREEN: mesmo comando.

- 2 arquivos passaram, 10 testes passaram.

Suíte focada consolidada antes da revisão: 6 arquivos e 22 testes passaram.

## Fix round 1: achados Important

### Guardian, autorização e múltiplos portais

RED:

- `npm test -- src/lib/guardianAccess.test.ts`: o módulo ainda não existia; após o contrato compilável, 2 de 2 testes falharam.
- `npm test -- src/lib/sessionBootstrap.test.ts`: 2 de 10 testes falharam porque memberships e vínculos de portal ainda escolhiam uma linha arbitrariamente.

GREEN:

- O acesso do responsável agora é derivado somente de `patient_guardians` (`patient_id`, `organization_id`, `relationship`, `can_view_plan`), sem leitura de `patients` para rotear.
- `can_view_plan=false` produz negação explícita sem executar claim; vínculos válidos são filtrados e preservam apenas os dados mínimos necessários até o portal da Task 6.
- Todas as memberships ativas e todos os vínculos diretos/de responsável são carregados sem `limit(1)`. Uma opção segue direto; várias opções abrem seleção determinística mantida somente no estado da sessão.
- `npm test -- src/lib/sessionBootstrap.test.ts src/lib/guardianAccess.test.ts`: 2 arquivos e 12 testes passaram.

### Seleções explícitas

RED: `npm test -- src/App.session.test.tsx src/lib/sessionBootstrap.test.ts`

- 2 de 16 testes falharam porque os destinos de seleção de consultório e portal ainda não existiam.

GREEN: mesmo comando.

- 2 arquivos e 16 testes passaram; as opções são ordenadas deterministicamente e nenhuma organização, papel ou paciente é escolhido implicitamente.

### Erro de sessão e concorrência

RED:

- `npm test -- src/App.auth.test.tsx`: 1 de 1 teste falhou porque o erro de `getSession` sobrevivia a `SIGNED_OUT`.
- `npm test -- src/App.race.test.tsx`: após corrigir uma ambiguidade inicial da query do próprio teste, 1 de 1 teste falhou de forma comportamental porque o bootstrap tardio do usuário A substituía o acesso já carregado do usuário B.

GREEN:

- Transições de autenticação bem-sucedidas limpam `sessionError`.
- Um token de geração e a validação do `user.id` impedem que sessão antiga aplique `access`, erro ou loading depois de logout/troca de usuário.
- Ambos os testes focais passaram, 1 de 1 em cada arquivo.

### Drawer acessível e reduced motion

RED:

- `npm test -- src/components/Shell.test.tsx`: o novo cenário de teclado/foco falhou primeiro por encontrar dois landmarks de navegação; o mesmo teste exigia overlay não tabbable, fundo inert e trap de foco.
- `npm test -- src/components/Shell.test.tsx src/pages/Login.test.tsx`: 2 de 8 testes falharam porque drawer e entrada do login não respeitavam `prefers-reduced-motion`.

GREEN:

- O drawer prende `Tab`/`Shift+Tab`, devolve foco ao fechar, usa overlay não tabbable, remove o landmark aninhado e torna `main` inert/`aria-hidden` enquanto aberto.
- Drawer e login observam `prefers-reduced-motion`; o drawer remove a transição e o login elimina a animação inicial/duração.
- `npm test -- src/components/Shell.test.tsx src/pages/Login.test.tsx`: 2 arquivos e 8 testes passaram.

### Consolidação da rodada

- `npm test -- src/App.auth.test.tsx src/App.race.test.tsx src/App.session.test.tsx src/components/Shell.test.tsx src/pages/Login.test.tsx src/lib/guardianAccess.test.ts src/lib/sessionBootstrap.test.ts`: 7 arquivos e 28 testes passaram.
- O pool do Vitest foi alterado de `vmThreads` para `forks` porque o pool anterior reutilizava o módulo `App` entre arquivos apesar da isolação configurada, contaminando mocks incompatíveis; os mesmos três arquivos do App passaram juntos no pool isolado.

## Fix round 2: re-review dos achados Important

### Acesso direto combinado com guardian negado

RED: `npm test -- src/lib/sessionBootstrap.test.ts`

- 1 de 11 testes falhou: um vínculo direto válido resultava no erro do guardian sem permissão para visualizar planos.

GREEN: `npm test -- src/lib/sessionBootstrap.test.ts src/lib/guardianAccess.test.ts`

- 2 arquivos e 13 testes passaram.
- A negação de guardian agora possui código de domínio próprio. Erros reais de consulta continuam bloqueando; a negação esperada é adiada até combinar todos os acessos diretos e de responsável válidos.
- Com ao menos um acesso válido, o destino segue direto ou abre seleção. Somente guardian negado continua em estado seguro de erro e não tenta claim.

### Drawer ao entrar no breakpoint desktop

RED: `npm test -- src/components/Shell.test.tsx`

- 1 de 5 testes falhou porque `data-open` continuava `true` após a media query entrar em 1024 px.

GREEN: mesmo comando.

- 1 arquivo e 5 testes passaram.
- O Shell acompanha `(min-width: 1024px)`, fecha o drawer ao entrar em desktop e, pelo mesmo estado, remove overlay, `inert`, `aria-hidden` e o trap de foco. O listener é removido no unmount.

### Consolidação da rodada 2

- `npm test -- src/lib/sessionBootstrap.test.ts src/lib/guardianAccess.test.ts src/components/Shell.test.tsx`: 3 arquivos e 18 testes passaram.
- Commit de código e testes: `d98fc5d`.

## Verificação final

- `npm test`: exit 0, 29 arquivos e 64 testes passaram.
- `npm run lint`: exit 0; dois warnings preexistentes de Fast Refresh permanecem em `src/lib/store.tsx`, que não está no runtime novo.
- `npm run build`: exit 0; TypeScript e Vite concluíram, 2143 módulos foram transformados e `verify:artifact` validou `dist`.
- `git diff --check`: exit 0.
- Escopo proibido: nenhum workflow, migration ou arquivo de Pages alterado.
- Busca no artefato: nenhuma ocorrência de `Helena`, `Protótipo`, `qualquer senha`, `Dados ficam apenas` ou `CRN a definir`.
- Busca no grafo de entrada: nenhuma ocorrência de `StoreProvider`, `localStorage` ou `lib/store` em `App`, `main`, shell, login ou navegação.

## Self-review

Foram feitas revisões independentes contra padrões do repositório e contra o brief.

Correções aplicadas:

1. A ausência esperada no `claim_patient_access` agora abre onboarding, sem transformar uma falha de rede em ausência.
2. A navegação pelo drawer agora devolve foco ao gatilho; o drawer móvel fechado também fica invisível, evitando controles deslocados visualmente.
3. O responsável não depende mais de uma leitura bloqueada por RLS em `patients`; autorização e destino vêm exclusivamente do vínculo permitido.
4. Ambiguidades de múltiplos consultórios e múltiplos portais agora exigem escolha explícita, sem `limit(1)`.
5. O ciclo de sessão invalida bootstraps antigos e limpa erros após transições válidas.
6. O drawer ganhou trap de foco/fundo inert e drawer/login respeitam movimento reduzido.
7. A negação de guardian não bloqueia mais um acesso direto ou de responsável válido na mesma conta.
8. O drawer móvel perde estado modal imediatamente quando o viewport entra no breakpoint desktop.

Decisões mantidas:

1. Os tipos nutricionais em `src/types.ts` permanecem porque sua restauração é requisito explícito desta task.
2. Os rótulos visuais do menu permanecem próximos ao redesign de `origin/main`, conforme o requisito de preservar o shell visual. A distinção clínica entre modelos será tratada quando as rotas das Tasks 3 a 6 forem conectadas.
3. Os parâmetros opcionais continuam como strings porque o brief define os nomes, mas não enumera valores fechados.

Risco residual:

- A cobertura completa do fluxo de confirmação e atualização de senha permanece deferida como achado Minor; os caminhos principais de login, cadastro e solicitação de recuperação continuam cobertos.

Não foi feita validação visual em navegador nesta task; a evidência de responsividade e acessibilidade é automatizada e de build.
