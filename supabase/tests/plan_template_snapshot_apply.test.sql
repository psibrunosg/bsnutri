begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

set local role postgres;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('15000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-snap@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values ('15000000-0000-0000-0000-000000000001','Nutri Snap');
insert into public.food_sources(code,name,license_name,attribution_text,dataset_version) values ('snap_test','Teste snapshot','Uso interno','Teste','snap_v1');
insert into public.foods(source_id,name,preparation_state) values ((select id from public.food_sources where code='snap_test'),'Arroz branco','cozido');

set local role authenticated;
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations(id,name,slug,created_by) values('25000000-0000-0000-0000-000000000001','Clinica Snap','clinica-snap','15000000-0000-0000-0000-000000000001');

set local role postgres;
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by) values('35000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000001','SNAP-01','Paciente Snap','15000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.plan_templates(id,organization_id,name,objective,tags,snapshot,created_by,scope,dimensions,rules) values (
 '65000000-0000-0000-0000-000000000001',
 '25000000-0000-0000-0000-000000000001',
 'Modelo Snapshot 1.500 Kcal',
 'Cardápio de teste',
 array['1500 kcal'],
 '{"dietboxId":99000001,"meals":[
   {"name":"Café da manhã","time":"07:00","items":[
     {"food":"Arroz branco","measure":"1 concha","grams":100,"macros":{"energyKcal":130,"proteinG":2.7,"carbohydrateG":28.1,"fatG":0.3}},
     {"food":"Alimento sem correspondencia","grams":50,"macros":{"energyKcal":90,"proteinG":5}}
   ]},
   {"name":"Almoço","items":[{"food":"Feijão","grams":0,"macros":{}}]}
 ]}'::jsonb,
 '15000000-0000-0000-0000-000000000001',
 'organization',
 '{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":[]}'::jsonb,
 '{"targets":{"energyKcal":1500},"guidance":[]}'::jsonb
);

select lives_ok($$select public.apply_plan_template_to_patient('65000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000001')$$,'aplica modelo com snapshot ao paciente');
select is((select status from public.plans where title='Modelo Snapshot 1.500 Kcal'),'draft','plano criado como rascunho para revisão');
select is((select count(*)::integer from public.plan_days pd join public.plan_versions v on v.id=pd.plan_version_id join public.plans p on p.id=v.plan_id where p.title='Modelo Snapshot 1.500 Kcal'),1,'um dia por padrão');
select is((select count(*)::integer from public.meals m join public.plan_days pd on pd.id=m.plan_day_id join public.plan_versions v on v.id=pd.plan_version_id join public.plans p on p.id=v.plan_id where p.title='Modelo Snapshot 1.500 Kcal'),2,'refeições materializadas do snapshot');
select is((select count(*)::integer from public.meal_items mi join public.meals m on m.id=mi.meal_id join public.plan_days pd on pd.id=m.plan_day_id join public.plan_versions v on v.id=pd.plan_version_id join public.plans p on p.id=v.plan_id where p.title='Modelo Snapshot 1.500 Kcal'),2,'itens com gramas>0 materializados, gramas 0 ignorados');
select is((select food_id is not null from public.meal_items mi join public.meals m on m.id=mi.meal_id where mi.description='Arroz branco (1 concha)'),true,'item vincula alimento do catálogo por nome');
select is((select mi.grams::int from public.meal_items mi where mi.description='Arroz branco (1 concha)'),100,'gramas preservados do snapshot');
select is((select (mi.nutrient_snapshot->>'energyKcal')::int from public.meal_items mi where mi.description='Arroz branco (1 concha)'),130,'macros por 100g preservados no nutrient_snapshot');
select is((select (v.targets->>'energyKcal')::int from public.plan_versions v join public.plans p on p.id=v.plan_id where p.title='Modelo Snapshot 1.500 Kcal' and v.version_no=1),1500,'meta energética do modelo aplicada à versão');
select lives_ok($$select public.apply_plan_template_to_patient('65000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000001',3)$$,'suporta repetição em N dias');
select lives_ok($$select public.apply_plan_template_to_patient('65000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000001',1,array['mon','wed','fri'])$$,'aplica nos dias da semana escolhidos');
select is((select count(*)::integer from public.plan_days d join public.plan_versions v on v.id=d.plan_version_id join public.plans p on p.id=v.plan_id where p.title='Modelo Snapshot 1.500 Kcal' and d.weekday is not null),3,'dias da semana gravados (seg, qua, sex)');

select * from finish();
rollback;
