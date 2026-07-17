begin;

set local role postgres;

create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('13000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bootstrap@teste.invalid', '', now(), now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$select public.bootstrap_organization('Usuário Bootstrap', 'Clínica Bootstrap', 'clinica-bootstrap-teste')$$,
  'usuário autenticado cria a primeira organização'
);
select is(
  (select created_by from public.organizations where slug = 'clinica-bootstrap-teste'),
  '13000000-0000-0000-0000-000000000001'::uuid,
  'organização fica vinculada ao proprietário'
);
select is(
  (select role::text from public.memberships where user_id = '13000000-0000-0000-0000-000000000001'),
  'owner',
  'gatilho cria a membership de proprietário'
);

select * from finish();
rollback;
