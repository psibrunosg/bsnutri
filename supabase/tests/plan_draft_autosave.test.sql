begin;

create extension if not exists pgtap with schema extensions;
select plan(7);

set local role postgres;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('13000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'autosave-nutri-a@teste.invalid', '', now(), now(), now()),
  ('13000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'autosave-nutri-b@teste.invalid', '', now(), now(), now());

insert into public.profiles (id, full_name) values
  ('13000000-0000-0000-0000-000000000001', 'Nutricionista Autosave A'),
  ('13000000-0000-0000-0000-000000000002', 'Nutricionista Autosave B');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000001', true);
insert into public.organizations (id, name, slug, created_by) values
  ('23000000-0000-0000-0000-000000000001', 'Clínica Autosave A', 'clinica-autosave-a', '13000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000002', true);
insert into public.organizations (id, name, slug, created_by) values
  ('23000000-0000-0000-0000-000000000002', 'Clínica Autosave B', 'clinica-autosave-b', '13000000-0000-0000-0000-000000000002');

set local role postgres;
insert into public.patients (id, organization_id, professional_id, anonymous_code, full_name, created_by) values
  ('33000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000001', 'P-AS1', 'Paciente Autosave', '13000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000001', true);

select public.save_plan_draft(
  '23000000-0000-0000-0000-000000000001',
  '33000000-0000-0000-0000-000000000001',
  'Plano Autosave',
  'Versão inicial',
  '{}'::jsonb,
  '{"energyKcal":2000}'::jsonb,
  '[{"day_index":0,"label":"Dia 1","kind":"standard","meals":[{"position":0,"label":"Café da manhã","items":[{"position":0,"description":"Aveia","grams":30,"nutrient_snapshot":{}}]}]}]'::jsonb
);

-- autosave substitui a estrutura da versão aberta sem criar outro plano
select lives_ok(
  $$select public.autosave_plan_version(
      (select id from public.plans where organization_id = '23000000-0000-0000-0000-000000000001'),
      (select id from public.plan_versions where organization_id = '23000000-0000-0000-0000-000000000001'),
      '{}'::jsonb,
      '{"energyKcal":2100}'::jsonb,
      '[{"day_index":0,"label":"Dia 1","kind":"standard","meals":[{"position":0,"label":"Café da manhã","items":[{"position":0,"description":"Aveia","grams":40,"nutrient_snapshot":{}},{"position":1,"description":"Banana","grams":100,"nutrient_snapshot":{}}]}]}]'::jsonb
    )$$,
  'autosave grava na versão de rascunho aberta'
);

select is(
  (select count(*)::integer from public.plans where organization_id = '23000000-0000-0000-0000-000000000001'),
  1,
  'autosave não cria um plano a cada gravação'
);

select is(
  (select count(*)::integer from public.meal_items where organization_id = '23000000-0000-0000-0000-000000000001'),
  2,
  'estrutura anterior é substituída pela nova'
);

select is(
  (select (targets->>'energyKcal')::integer from public.plan_versions where organization_id = '23000000-0000-0000-0000-000000000001'),
  2100,
  'metas acompanham o autosave'
);

-- isolamento multi-organização
select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.autosave_plan_version(
      (select id from public.plans limit 1),
      (select id from public.plan_versions limit 1),
      '{}'::jsonb, '{}'::jsonb,
      '[{"day_index":0,"label":"Dia 1","kind":"standard","meals":[]}]'::jsonb
    )$$,
  '42501',
  null,
  'profissional de outra organização não grava no rascunho alheio'
);

-- Versão publicada é imutável, inclusive para o autosave.
-- O fluxo completo de revisão e publicação é coberto por publication_portal;
-- aqui basta o estado final, montado direto para manter a suíte focada na guarda.
set local role postgres;
select set_config('bsnutri.workflow_rpc', 'on', true);
update public.plan_versions
   set reviewed_at = now(), reviewed_by = '13000000-0000-0000-0000-000000000001',
       locked_at = now(), published_at = now()
 where organization_id = '23000000-0000-0000-0000-000000000001';
update public.plans set status = 'published' where organization_id = '23000000-0000-0000-0000-000000000001';
select set_config('bsnutri.workflow_rpc', 'off', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$select public.autosave_plan_version(
      (select id from public.plans where organization_id = '23000000-0000-0000-0000-000000000001'),
      (select id from public.plan_versions where organization_id = '23000000-0000-0000-0000-000000000001'),
      '{}'::jsonb, '{}'::jsonb,
      '[{"day_index":0,"label":"Dia 1","kind":"standard","meals":[]}]'::jsonb
    )$$,
  '42501',
  null,
  'versão publicada não aceita gravação automática'
);

select is(
  (select count(*)::integer from public.meal_items where organization_id = '23000000-0000-0000-0000-000000000001'),
  2,
  'conteúdo publicado permanece intacto após tentativa de autosave'
);

select * from finish();
rollback;
