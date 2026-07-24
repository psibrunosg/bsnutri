begin;

create extension if not exists pgtap with schema extensions;
select plan(19);

set local role postgres;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
  ('19000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','catalogo-a@teste.invalid','',now(),now(),now()),
  ('19000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','catalogo-b@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
  ('19000000-0000-0000-0000-000000000001','Nutricionista Catalogo A'),
  ('19000000-0000-0000-0000-000000000002','Nutricionista Catalogo B');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000001',true);
insert into public.organizations(id,name,slug,created_by) values
  ('29000000-0000-0000-0000-000000000001','Clinica Catalogo A','clinica-catalogo-a','19000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000002',true);
insert into public.organizations(id,name,slug,created_by) values
  ('29000000-0000-0000-0000-000000000002','Clinica Catalogo B','clinica-catalogo-b','19000000-0000-0000-0000-000000000002');

select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000001',true);
set local role postgres;
insert into public.food_sources(id,code,name,license_name,attribution_text,dataset_version) values
  ('49000000-0000-0000-0000-000000000001','catalogo-global-teste','Catálogo global de teste','Teste','Teste','v1');
insert into public.foods(id,source_id,source_food_code,name,preparation_state,catalog_kind) values
  ('39000000-0000-0000-0000-000000000004','49000000-0000-0000-0000-000000000001','global-arroz','Arroz global','cozido','food');
set local role authenticated;
insert into public.foods(id,organization_id,name,preparation_state,catalog_kind,created_by) values
  ('39000000-0000-0000-0000-000000000001','29000000-0000-0000-0000-000000000001','Arroz','cozido','food','19000000-0000-0000-0000-000000000001');
insert into public.foods(id,organization_id,name,preparation_state,catalog_kind,yield_grams,serving_grams,portion_count,household_measure_label,household_measure_grams,created_by) values
  ('39000000-0000-0000-0000-000000000002','29000000-0000-0000-0000-000000000001','Arroz temperado','pronto','preparation',300,100,3,'1 concha',100,'19000000-0000-0000-0000-000000000001'),
  ('39000000-0000-0000-0000-000000000003','29000000-0000-0000-0000-000000000001','Prato brasileiro','refeicao','combination',400,400,'19000000-0000-0000-0000-000000000001');
insert into public.food_components(parent_food_id,component_food_id,organization_id,grams,position) values
  ('39000000-0000-0000-0000-000000000002','39000000-0000-0000-0000-000000000001','29000000-0000-0000-0000-000000000001',250,0),
  ('39000000-0000-0000-0000-000000000003','39000000-0000-0000-0000-000000000002','29000000-0000-0000-0000-000000000001',300,0);

select is((select catalog_kind::text from public.foods where id='39000000-0000-0000-0000-000000000001'),'food','cadastra alimento');
select is((select catalog_kind::text from public.foods where id='39000000-0000-0000-0000-000000000002'),'preparation','cadastra preparacao');
select is((select catalog_kind::text from public.foods where id='39000000-0000-0000-0000-000000000003'),'combination','cadastra combinacao');
select is((select count(*)::integer from public.food_components),2,'registra componentes das entidades compostas');
select is((select serving_grams::integer from public.foods where id='39000000-0000-0000-0000-000000000002'),100,'preserva rendimento e porcao');
select is((select portion_count::integer from public.foods where id='39000000-0000-0000-0000-000000000002'),3,'preserva numero de porcoes');
select is((select household_measure_label from public.foods where id='39000000-0000-0000-0000-000000000002'),'1 concha','preserva medida caseira explicita');
select throws_ok(
  $$insert into public.foods(organization_id,name,preparation_state,catalog_kind,household_measure_label,created_by) values ('29000000-0000-0000-0000-000000000001','Medida incompleta','pronto','food','1 colher','19000000-0000-0000-0000-000000000001')$$,
  '.*foods_household_measure_complete.*',
  'rejeita medida caseira sem peso registrado'
);
select is((select count(*)::integer from public.foods where organization_id is null),1,'catálogo global permanece visível ao membro clínico');
select is((select review_status from public.foods where id='39000000-0000-0000-0000-000000000001'),'pending_review','novo item próprio inicia pendente de revisão');
insert into public.foods(id,organization_id,name,preparation_state,catalog_kind,review_status,reviewed_by,created_by) values
  ('39000000-0000-0000-0000-000000000005','29000000-0000-0000-0000-000000000001','Item revisado','cru','food','reviewed','19000000-0000-0000-0000-000000000001','19000000-0000-0000-0000-000000000001');
select ok((select reviewed_at is not null from public.foods where id='39000000-0000-0000-0000-000000000005'),'revisão registra data e profissional autenticado');
select lives_ok(
  $$select public.import_catalog_foods('29000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000001','[{"name":"Abóbora","preparation_state":"cozida","energy_kcal":48,"protein_g":1.2,"carbohydrate_g":10.8,"fat_g":0.1}]'::jsonb)$$,
  'importação válida persiste alimento e nutrientes em uma transação'
);
select is((select review_status from public.foods where organization_id='29000000-0000-0000-0000-000000000001' and name='Abóbora'),'pending_review','item importado aguarda revisão');
select throws_ok(
  $$select public.import_catalog_foods('29000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000001','[{"name":"Arroz","preparation_state":"cozido","energy_kcal":130,"protein_g":2,"carbohydrate_g":28,"fat_g":0.3}]'::jsonb)$$,
  '.*já existem.*',
  'duplicidade é rejeitada antes de persistir'
);
select throws_ok(
  $$select public.import_catalog_foods('29000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000001','[{"name":"Couve","preparation_state":"crua","energy_kcal":-1,"protein_g":2,"carbohydrate_g":3,"fat_g":0.2}]'::jsonb)$$,
  '.*dados nutricionais inválidos.*',
  'dados inválidos são rejeitados antes de persistir'
);
select is((select count(*)::integer from public.foods where organization_id='29000000-0000-0000-0000-000000000001' and name='Couve'),0,'falha de pré-validação não deixa item parcial');
select throws_ok(
  $$insert into public.food_components(parent_food_id,component_food_id,organization_id,grams,position) values ('39000000-0000-0000-0000-000000000002','39000000-0000-0000-0000-000000000003','29000000-0000-0000-0000-000000000001',10,1)$$,
  '.*não podem formar ciclos.*',
  'bloqueia ciclo indireto entre preparação e combinação'
);

select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.food_components),0,'outra organizacao nao ve componentes');
select throws_ok(
  $$insert into public.food_components(parent_food_id,component_food_id,organization_id,grams,position) values ('39000000-0000-0000-0000-000000000002','39000000-0000-0000-0000-000000000001','29000000-0000-0000-0000-000000000002',10,1)$$,
  '.*row-level security.*',
  'outra organização não consegue vincular componente do catálogo alheio'
);

select * from finish();
rollback;
