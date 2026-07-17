begin;

set local role postgres;

create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('14000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mvp-nutri@teste.invalid', '', now(), now(), now()),
  ('14000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mvp-paciente@teste.invalid', '', now(), now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
  $$select public.bootstrap_organization('Nutri MVP', 'Clínica MVP', 'clinica-mvp')$$,
  'bootstrap cria clínica'
);

select is(
  (select count(*)::integer from public.organizations where slug = 'clinica-mvp'),
  1,
  'clínica existe'
);
select is(
  (select count(*)::integer from public.memberships where role = 'owner'),
  1,
  'owner criado'
);
select is(
  (select count(*)::integer from public.patients),
  0,
  'sem pacientes no smoke'
);

select ok(
  exists (
    select 1
    from public.profiles
    where id = '14000000-0000-0000-0000-000000000001'
  ),
  'perfil criado no bootstrap'
);
select ok(
  exists (
    select 1
    from public.memberships m
    join public.organizations o on o.id = m.organization_id
    where o.slug = 'clinica-mvp' and m.user_id = '14000000-0000-0000-0000-000000000001' and m.role = 'owner'
  ),
  'membership owner ligada à clínica'
);
select lives_ok(
  $$insert into public.patients (organization_id, professional_id, anonymous_code, full_name, created_by) values ((select id from public.organizations where slug = 'clinica-mvp'), '14000000-0000-0000-0000-000000000001', 'MVP-001', 'Paciente MVP', '14000000-0000-0000-0000-000000000001')$$,
  'paciente básico entra no núcleo'
);
select is(
  (select count(*)::integer from public.patients where anonymous_code = 'MVP-001'),
  1,
  'paciente persistido'
);

select * from finish();
rollback;
