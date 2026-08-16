begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

set local role postgres;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('12000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'review-nutri-a@teste.invalid', '', now(), now(), now()),
  ('12000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'review-nutri-b@teste.invalid', '', now(), now(), now()),
  ('12000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'review-estudante-a@teste.invalid', '', now(), now(), now());

insert into public.profiles (id, full_name) values
  ('12000000-0000-0000-0000-000000000001', 'Nutricionista Revisão A'),
  ('12000000-0000-0000-0000-000000000002', 'Nutricionista Revisão B'),
  ('12000000-0000-0000-0000-000000000003', 'Estudante Revisão A');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000001', true);
insert into public.organizations (id, name, slug, created_by) values
  ('22000000-0000-0000-0000-000000000001', 'Clínica Revisão A', 'clinica-revisao-a', '12000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000002', true);
insert into public.organizations (id, name, slug, created_by) values
  ('22000000-0000-0000-0000-000000000002', 'Clínica Revisão B', 'clinica-revisao-b', '12000000-0000-0000-0000-000000000002');

set local role postgres;
insert into public.memberships (organization_id, user_id, role, status) values
  ('22000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000003', 'student', 'active');

insert into public.patients (id, organization_id, professional_id, anonymous_code, full_name, created_by) values
  ('32000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000001', 'P-R01', 'Paciente Revisão A', '12000000-0000-0000-0000-000000000001');

insert into public.plan_templates (id, organization_id, name, snapshot, created_by, catalog_key) values
  ('42000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-000000000001', 'Modelo Importado',
   '{"meals":[{"name":"Café da manhã","items":[{"food":"Aveia","grams":30}]}]}'::jsonb,
   '12000000-0000-0000-0000-000000000001', 'seed-modelo-1');

-- backfill de proveniência roda na migration; aqui simulamos um registro pós-migration
update public.plan_templates
   set provenance = jsonb_build_object('origin', 'seed', 'catalog_key', 'seed-modelo-1')
 where id = '42000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000001', true);

select is(
  (select status::text from public.plan_templates where id = '42000000-0000-0000-0000-000000000001'),
  'needs_review',
  'modelo importado nasce pendente de revisão'
);

select is(
  (select provenance->>'origin' from public.plan_templates where id = '42000000-0000-0000-0000-000000000001'),
  'seed',
  'proveniência do modelo importado é preservada'
);

select throws_ok(
  $$select public.apply_plan_template_to_patient('42000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', 1)$$,
  '42501',
  null,
  'modelo não aprovado é bloqueado no banco, não apenas na UI'
);

select throws_ok(
  $$select public.copy_plan_template_to_patient('42000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', 1)$$,
  '42501',
  null,
  'bloqueio vale também para a chamada direta do copiador'
);

select is(
  (select count(*)::integer from public.plans where organization_id = '22000000-0000-0000-0000-000000000001'),
  0,
  'nenhum plano é criado a partir de modelo não aprovado'
);

-- estagiário não aprova modelo
select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.review_plan_template('42000000-0000-0000-0000-000000000001', 'approved')$$,
  'Modelo indisponível para revisão',
  'estagiário não aprova modelo'
);

-- nutricionista aprova e o uso é liberado
select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.review_plan_template('42000000-0000-0000-0000-000000000001', 'approved', 'Conferido contra a fonte técnica')$$,
  'nutricionista aprova o modelo após revisão'
);

select lives_ok(
  $$select public.apply_plan_template_to_patient('42000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', 1)$$,
  'modelo aprovado pode ser aplicado ao paciente'
);

-- isolamento multi-organização
select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.review_plan_template('42000000-0000-0000-0000-000000000001', 'archived')$$,
  'Modelo indisponível para revisão',
  'profissional de outra organização não revisa o modelo'
);

select * from finish();
rollback;
