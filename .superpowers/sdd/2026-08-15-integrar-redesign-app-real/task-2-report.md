# Task 2: navegação, sessão e shell responsivo

## Status

Implementação concluída no worktree isolado `integrar-redesign-app-real`.

Commit de código e testes: `285b500` (`feat: restore secure session navigation`).

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

## Verificação final

- `npm test`: exit 0, 26 arquivos e 51 testes passaram.
- `npm run lint`: exit 0; dois warnings preexistentes de Fast Refresh permanecem em `src/lib/store.tsx`, que não está no runtime novo.
- `npm run build`: exit 0; TypeScript e Vite concluíram, 2141 módulos foram transformados e `verify:artifact` validou `dist`.
- `git diff --check`: exit 0.
- Escopo proibido: nenhum workflow, migration ou arquivo de Pages alterado.
- Busca no artefato: nenhuma ocorrência de `Helena`, `Protótipo`, `qualquer senha`, `Dados ficam apenas` ou `CRN a definir`.
- Busca no grafo de entrada: nenhuma ocorrência de `StoreProvider`, `localStorage` ou `lib/store` em `App`, `main`, shell, login ou navegação.

## Self-review

Foram feitas revisões independentes contra padrões do repositório e contra o brief.

Correções aplicadas:

1. A ausência esperada no `claim_patient_access` agora abre onboarding, sem transformar uma falha de rede em ausência.
2. A navegação pelo drawer agora devolve foco ao gatilho; o drawer móvel fechado também fica invisível, evitando controles deslocados visualmente.

Decisões mantidas:

1. Os tipos nutricionais em `src/types.ts` permanecem porque sua restauração é requisito explícito desta task.
2. Os rótulos visuais do menu permanecem próximos ao redesign de `origin/main`, conforme o requisito de preservar o shell visual. A distinção clínica entre modelos será tratada quando as rotas das Tasks 3 a 6 forem conectadas.
3. Os parâmetros opcionais continuam como strings porque o brief define os nomes, mas não enumera valores fechados.

Risco residual:

- O vínculo de responsável seleciona um único paciente visível. Responsáveis ligados a múltiplos pacientes precisarão de uma seleção derivada da sessão em uma task do portal, sem introduzir `patientId` livre na URL.

Não foi feita validação visual em navegador nesta task; a evidência de responsividade e acessibilidade é automatizada e de build.
