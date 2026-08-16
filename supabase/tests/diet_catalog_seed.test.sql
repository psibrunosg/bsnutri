begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

-- 1) Alimentos do seed carregam com diet_tags corretos (correlação alimento <-> modelo).
-- O seed traz mais de um registro de azeite de oliva (estados de preparo distintos),
-- então a asserção precisa perguntar se algum deles acumula as duas tags.
select ok(
  (select bool_or(diet_tags @> array['dash','vegan']) from public.foods where lower(name)='azeite de oliva' and organization_id is null),
  'azeite de oliva compartilhado por multiplos modelos acumula diet_tags'
);

set local role postgres;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('9a000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','dietseed-a@teste.invalid','',now(),now(),now()),
 ('9a000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','dietseed-b@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('9a000000-0000-0000-0000-000000000001','Nutricionista Diet Seed A'),
 ('9a000000-0000-0000-0000-000000000002','Nutricionista Diet Seed B');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','9a000000-0000-0000-0000-000000000001',true);

-- 2) bootstrap_organization ja carrega os 8 modelos automaticamente.
select lives_ok($$select public.bootstrap_organization('Nutri Diet Seed','Clinica Diet Seed','clinica-diet-seed')$$,'bootstrap cria clinica');
select is(
  (select count(*)::integer from public.plan_templates t join public.organizations o on o.id=t.organization_id where o.slug='clinica-diet-seed'),
  8,
  'clinica nova recebe os 8 modelos ao ser criada'
);

-- 3) Reaplicar o seed é idempotente (upsert por catalog_key, sem duplicar).
select lives_ok(
  $$select public.seed_practicas_dieteticas((select id from public.organizations where slug='clinica-diet-seed'),'9a000000-0000-0000-0000-000000000001')$$,
  'seed pode ser reaplicado sem erro'
);
select is(
  (select count(*)::integer from public.plan_templates t join public.organizations o on o.id=t.organization_id where o.slug='clinica-diet-seed'),
  8,
  'reaplicar o seed nao duplica os modelos'
);

-- 4) Usuario sem vinculo com a clinica nao consegue semear modelos nela.
select set_config('request.jwt.claim.sub','9a000000-0000-0000-0000-000000000002',true);
select throws_ok(
  $$select public.seed_practicas_dieteticas((select id from public.organizations where slug='clinica-diet-seed'),'9a000000-0000-0000-0000-000000000002')$$,
  'Acesso negado',
  'usuario sem papel na organizacao nao semeia modelos de outra clinica'
);

select * from finish();
rollback;
