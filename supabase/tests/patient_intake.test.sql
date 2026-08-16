begin;

create extension if not exists pgtap with schema extensions;
select plan(13);

set local role postgres;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('11000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'intake-nutri-a@teste.invalid', '', now(), now(), now()),
  ('11000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'intake-nutri-b@teste.invalid', '', now(), now(), now()),
  ('11000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'intake-recepcao-a@teste.invalid', '', now(), now(), now());

insert into public.profiles (id, full_name) values
  ('11000000-0000-0000-0000-000000000001', 'Nutricionista Intake A'),
  ('11000000-0000-0000-0000-000000000002', 'Nutricionista Intake B'),
  ('11000000-0000-0000-0000-000000000003', 'Recepção Intake A');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);
insert into public.organizations (id, name, slug, created_by) values
  ('21000000-0000-0000-0000-000000000001', 'Clínica Intake A', 'clinica-intake-a', '11000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000002', true);
insert into public.organizations (id, name, slug, created_by) values
  ('21000000-0000-0000-0000-000000000002', 'Clínica Intake B', 'clinica-intake-b', '11000000-0000-0000-0000-000000000002');

set local role postgres;
insert into public.memberships (organization_id, user_id, role, status) values
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', 'receptionist', 'active');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);

-- cadastro completo em transação única
select lives_ok(
  $$select public.create_patient_intake(
      '21000000-0000-0000-0000-000000000001',
      'Paciente Intake Um',
      'intake-um@teste.invalid', '(53) 90000-0000', '1990-05-10',
      array['Low Carb', ' corrida ', 'low carb'],
      'Perda de peso', 'Frutas cítricas', 'Sem lactose', 'Amendoim', 'Rotina noturna',
      72.5, 168, 80.5, 96.5, 28.5, 24.5
    )$$,
  'nutricionista cria paciente completo na própria organização'
);

select is(
  (select count(*)::integer from public.patients where organization_id = '21000000-0000-0000-0000-000000000001'),
  1,
  'paciente gravado na organização do profissional'
);

select is(
  (select tags from public.patients where organization_id = '21000000-0000-0000-0000-000000000001'),
  array['corrida', 'low carb']::text[],
  'tags normalizadas, deduplicadas e ordenadas'
);

select is(
  (select professional_id from public.patients where organization_id = '21000000-0000-0000-0000-000000000001'),
  '11000000-0000-0000-0000-000000000001'::uuid,
  'autoria derivada de auth.uid(), não do cliente'
);

select is(
  (select count(*)::integer from public.assessments where organization_id = '21000000-0000-0000-0000-000000000001' and objective = 'Perda de peso'),
  1,
  'avaliação criada junto com o paciente'
);

select is(
  (select hip_cm from public.anthropometry where organization_id = '21000000-0000-0000-0000-000000000001'),
  96.5::numeric(6,2),
  'antropometria grava circunferência de quadril'
);

select is(
  (select arm_cm from public.anthropometry where organization_id = '21000000-0000-0000-0000-000000000001'),
  28.5::numeric(6,2),
  'antropometria grava circunferência de braço'
);

select is(
  (select assessment_id from public.anthropometry where organization_id = '21000000-0000-0000-0000-000000000001'),
  (select id from public.assessments where organization_id = '21000000-0000-0000-0000-000000000001'),
  'antropometria vinculada à avaliação da mesma transação'
);

select is(
  (select count(*)::integer from public.audit_events where organization_id = '21000000-0000-0000-0000-000000000001' and action = 'patient_intake'),
  1,
  'auditoria registrada na mesma transação'
);

-- cadastro sem antropometria não cria linha vazia
select public.create_patient_intake(
  '21000000-0000-0000-0000-000000000001',
  'Paciente Intake Dois'
);

select is(
  (select count(*)::integer from public.anthropometry where organization_id = '21000000-0000-0000-0000-000000000001'),
  1,
  'cadastro sem medidas não cria antropometria vazia'
);

-- rollback transacional: antropometria inválida desfaz paciente e avaliação
select throws_ok(
  $$select public.create_patient_intake(
      '21000000-0000-0000-0000-000000000001',
      'Paciente Intake Inválido',
      null, null, null, '{}'::text[],
      null, null, null, null, null,
      -5, 170
    )$$,
  '23514',
  null,
  'peso inválido é rejeitado pela restrição de domínio'
);

select is(
  (select count(*)::integer from public.patients where organization_id = '21000000-0000-0000-0000-000000000001'),
  2,
  'falha de antropometria não deixa paciente órfão'
);

-- isolamento multi-organização
select throws_ok(
  $$select public.create_patient_intake('21000000-0000-0000-0000-000000000002', 'Paciente Cruzado')$$,
  '42501',
  null,
  'profissional não cria paciente em outra organização'
);

select * from finish();
rollback;
