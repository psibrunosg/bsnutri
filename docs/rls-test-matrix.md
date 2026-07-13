# Matriz de testes RLS e publicação

Esta matriz é o contrato mínimo de isolamento e integridade do BSNutri. A suíte automatizada fica em `supabase/tests/rls_isolation.test.sql` e deve rodar após `supabase db reset`.

## Isolamento clínico

| Cenário | Resultado esperado | Cobertura |
|---|---|---|
| Nutricionista A lista pacientes da clínica A | Permitido | Automatizada |
| Nutricionista A lista paciente da clínica B | Nenhuma linha | Automatizada |
| Nutricionista A cria paciente na clínica A como autor autenticado | Permitido | Automatizada |
| Nutricionista A cria paciente na clínica B | Bloqueado por RLS | Automatizada |
| Nutricionista A informa outro usuário em `created_by` | Bloqueado por RLS | Automatizada |
| Nutricionista B lista pacientes da clínica B | Permitido, sem linhas da clínica A | Automatizada |
| Estudante ativo lista pacientes da clínica A | Permitido | Automatizada |
| Estudante exclui paciente | Nenhuma linha excluída | Automatizada |
| Membro suspenso lista pacientes | Nenhuma linha | Automatizada |
| Recepção lista dados clínicos, metas ou planos | Nenhuma linha | Automatizada neste ciclo para pacientes, metas e planos |
| Administrador lista auditoria da própria clínica | Permitido | Manual pendente |
| Nutricionista lista auditoria | Nenhuma linha | Automatizada |

## Paciente e responsável

| Cenário | Resultado esperado | Cobertura |
|---|---|---|
| Paciente vinculado consulta seu plano publicado | Somente a versão publicada vigente | Automatizada |
| Paciente vinculado consulta rascunho, versão em revisão ou futura | Nenhuma linha | Automatizada |
| Paciente vinculado consulta plano publicado de outro paciente da mesma clínica | Nenhuma linha | Automatizada |
| Paciente não vinculado consulta qualquer plano | Nenhuma linha | Automatizada |
| Paciente tenta alterar plano, versão, dia, refeição ou item | Bloqueado por RLS | Automatizada |
| Responsável ativo consulta plano publicado do dependente | Permitido | Pendente até o fluxo de dependentes entrar no portal |
| Responsável consulta plano de paciente sem vínculo | Nenhuma linha | Pendente até o fluxo de dependentes entrar no portal |

## Metas nutricionais

| Cenário | Resultado esperado | Cobertura |
|---|---|---|
| Equipe clínica A lê e altera metas do paciente A | Permitido | Automatizada |
| Equipe clínica A consulta metas do paciente B | Nenhuma linha | Automatizada |
| Recepção consulta metas | Nenhuma linha | Automatizada |
| Paciente consulta metas liberadas junto ao plano publicado | Permitido somente quando a policy explicitamente liberar | Automatizada |
| Paciente altera metas | Bloqueado por RLS | Automatizada |
| Meta preserva unidade, valor e vínculo com a versão | Constraint e snapshot verificáveis | Automatizada |

## Publicação imutável e versionada

| Cenário | Resultado esperado | Cobertura |
|---|---|---|
| Profissional publica uma versão revisada | Estado, autor e horário de publicação gravados atomicamente | Automatizada |
| Profissional tenta publicar versão sem revisão | Bloqueado | Automatizada |
| Qualquer usuário altera versão já publicada | Bloqueado, inclusive equipe clínica | Automatizada |
| Qualquer usuário altera dias, refeições, itens ou metas de versão publicada | Bloqueado | Automatizada |
| Nova alteração após publicação | Cria nova versão; não sobrescreve o snapshot anterior | Automatizada |
| Restaurar versão anterior | Cria versão nova, mantendo histórico | Pendente até restauração entrar no produto |
| Nova publicação substitui a anterior | Versão anterior permanece histórica e deixa de ser vigente | Automatizada |
| Atualização posterior do alimento ou tabela | Snapshot nutricional publicado não muda | Automatizada |

## Gates de entrega

- Executar a suíte a cada alteração de migration ou policy.
- Tratar acesso cruzado entre organizações, leitura de rascunho pelo paciente e mutação de versão publicada como bloqueadores de deploy.
- Testar `select`, `insert`, `update` e `delete` separadamente. Uma policy permissiva em qualquer comando pode ampliar acesso sem intenção.
- Cada tabela descendente do plano deve provar duas condições: pertence ao mesmo tenant e herda a visibilidade da versão publicada.
- Uma publicação deve congelar cálculos, unidades, fontes e valores nutricionais usados. Atualizações do catálogo não podem reescrever o histórico.
- Repetir a validação no ambiente remoto antes do piloto, usando somente dados sintéticos e uma conta por papel.

## Roteiro manual remoto A/B

1. Crie clínicas sintéticas A e B, um nutricionista em cada uma, uma recepcionista A, um paciente vinculado A e um usuário sem vínculo.
2. Publique a versão 1 do plano A e mantenha a versão 2 como rascunho.
3. Como nutricionista A, confirme que consultas filtradas e não filtradas nunca retornam identificadores da clínica B.
4. Como recepcionista A, consulte diretamente pacientes, metas, planos e versões pelo cliente Supabase; todas as respostas devem estar vazias.
5. Como paciente A, confirme acesso à versão 1 e ausência da versão 2, inclusive ao consultar IDs conhecidos diretamente.
6. Como usuário não vinculado, repita a consulta por IDs conhecidos; nenhuma linha deve ser retornada.
7. Tente atualizar e excluir a versão 1 e seus descendentes como nutricionista, recepção e paciente. Todas as mutações devem falhar ou afetar zero linhas.
8. Atualize um alimento usado no plano. O snapshot da versão 1 deve permanecer byte a byte igual.
9. Suspenda um vínculo profissional e confirme que o acesso cessa sem precisar encerrar a conta.
10. Verifique nos logs que tentativas bloqueadas não expõem conteúdo sensível.
