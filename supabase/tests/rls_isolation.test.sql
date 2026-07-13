begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nutri-a@teste.invalid', '', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'recepcao-a@teste.invalid', '', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nutri-b@teste.invalid', '', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'estudante-a@teste.invalid', '', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'suspenso-a@teste.invalid', '', now(), now(), now());

insert into public.profiles (id, full_name) values
  ('10000000-0000-0000-0000-000000000001', 'Nutricionista A'),
  ('10000000-0000-0000-0000-000000000002', 'Recepção A'),
  ('10000000-0000-0000-0000-000000000003', 'Nutricionista B'),
  ('10000000-0000-0000-0000-000000000004', 'Estudante A'),
  ('10000000-0000-0000-0000-000000000005', 'Membro Suspenso');

insert into public.organizations (id, name, slug, created_by) values
  ('20000000-0000-0000-0000-000000000001', 'Clínica A', 'clinica-a-teste', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002', 'Clínica B', 'clinica-b-teste', '10000000-0000-0000-0000-000000000003');

insert into public.memberships (organization_id, user_id, role, status) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'nutritionist', 'active'),
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'receptionist', 'active'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', 'nutritionist', 'active'),
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', 'student', 'active'),
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000005', 'nutritionist', 'suspended');

insert into public.patients (id, organization_id, professional_id, anonymous_code, full_name, created_by) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'P-A01', 'Paciente Sintético A', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', 'P-B01', 'Paciente Sintético B', '10000000-0000-0000-0000-000000000003');

insert into public.audit_events (organization_id, actor_id, action, entity_type) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'test', 'fixture');

set local role authenticated;

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.patients), 1, 'nutricionista vê somente paciente da própria clínica');
select is((select anonymous_code from public.patients), 'P-A01', 'isolamento impede leitura da clínica B');
select lives_ok($$insert into public.patients (organization_id, professional_id, anonymous_code, full_name, created_by) values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'P-A02', 'Paciente Inserido', '10000000-0000-0000-0000-000000000001')$$, 'nutricionista insere na própria clínica');
select throws_ok($$insert into public.patients (organization_id, professional_id, anonymous_code, full_name, created_by) values ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'P-B02', 'Acesso Cruzado', '10000000-0000-0000-0000-000000000001')$$, '42501', null, 'nutricionista não insere em outra clínica');
select throws_ok($$insert into public.patients (organization_id, professional_id, anonymous_code, full_name, created_by) values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'P-A03', 'Autor Inválido', '10000000-0000-0000-0000-000000000003')$$, '42501', null, 'created_by deve ser o usuário autenticado');
select is((select count(*)::integer from public.audit_events), 0, 'nutricionista não lê auditoria');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.patients), 0, 'recepção não lê dados nutricionais de pacientes');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
select is((select count(*)::integer from public.patients), 2, 'estudante lê pacientes da própria clínica');
select is((with deleted as (delete from public.patients where id = '30000000-0000-0000-0000-000000000001' returning 1) select count(*)::integer from deleted), 0, 'estudante não exclui paciente');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000005', true);
select is((select count(*)::integer from public.patients), 0, 'membro suspenso não acessa pacientes');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select is((select count(*)::integer from public.patients), 1, 'nutricionista B vê somente a clínica B');

select * from finish();
rollback;
