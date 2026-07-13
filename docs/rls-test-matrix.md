# Matriz de testes RLS

Esta matriz é o contrato mínimo de isolamento do BSNutri. A suíte automatizada está em `supabase/tests/rls_isolation.test.sql` e deve rodar após `supabase db reset`.

| Cenário | Resultado esperado | Automatizado |
|---|---|---|
| Nutricionista ativo lista pacientes da própria clínica | Permitido | Sim |
| Nutricionista da clínica A lista pacientes da clínica B | Nenhuma linha | Sim |
| Recepcionista lista dados de pacientes | Nenhuma linha | Sim |
| Usuário sem vínculo lista pacientes | Nenhuma linha | Sim |
| Nutricionista insere paciente na própria clínica como autor | Permitido | Sim |
| Nutricionista insere paciente em outra clínica | Bloqueado por RLS | Sim |
| Nutricionista atribui outro usuário em `created_by` | Bloqueado por RLS | Sim |
| Estudante ativo lista pacientes da própria clínica | Permitido | Sim |
| Estudante exclui paciente | Nenhuma linha excluída | Sim |
| Administrador lista auditoria da própria clínica | Permitido | Sim |
| Nutricionista lista auditoria | Nenhuma linha | Sim |
| Membro suspenso acessa dados da clínica | Nenhuma linha | Sim |
| Responsável acessa plano publicado do dependente | Permitido | Pendente, tabela de planos ainda não existe |
| Paciente acessa somente os próprios dados liberados | Permitido | Pendente, vínculo de usuário paciente ainda não existe |
| Recepção acessa agenda sem conteúdo nutricional | Permitido apenas na agenda | Pendente, agenda ainda não existe |

## Critérios de execução

- Executar a suíte a cada alteração de migration ou policy.
- Tratar qualquer acesso cruzado entre organizações como bloqueador de publicação.
- Criar casos novos antes ou junto de cada tabela clínica.
- Testar `select`, `insert`, `update` e `delete` separadamente. Uma policy permissiva em qualquer comando pode ampliar acesso sem intenção.
- Repetir a validação no ambiente remoto antes do piloto, usando somente dados sintéticos e uma conta de teste por papel.

## Teste manual remoto

O teste automatizado usa o banco local para poder criar fixtures dentro de uma transação. No projeto remoto, valide pelo frontend com contas sintéticas de duas clínicas:

1. Entre como nutricionista da clínica A e confirme que nenhum identificador da clínica B aparece nas respostas da API.
2. Entre como recepcionista e tente consultar diretamente as tabelas clínicas pelo cliente Supabase.
3. Suspenda um vínculo e confirme que o acesso cessa sem precisar encerrar a conta.
4. Verifique em logs que tentativas bloqueadas não expõem conteúdo sensível.

