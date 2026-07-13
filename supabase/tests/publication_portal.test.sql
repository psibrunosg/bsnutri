begin;

create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('11000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-a-publicacao@teste.invalid','',now(),now(),now()),
  ('11000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recepcao-a-publicacao@teste.invalid','',now(),now(),now()),
  ('11000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-b-publicacao@teste.invalid','',now(),now(),now()),
  ('11000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','paciente-a@teste.invalid','',now(),now(),now()),
  ('11000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sem-vinculo@teste.invalid','',now(),now(),now());

insert into public.profiles (id, full_name) values
  ('11000000-0000-0000-0000-000000000001','Nutricionista Publicação A'),
  ('11000000-0000-0000-0000-000000000002','Recepção Publicação A'),
  ('11000000-0000-0000-0000-000000000003','Nutricionista Publicação B'),
  ('11000000-0000-0000-0000-000000000004','Paciente Vinculado A'),
  ('11000000-0000-0000-0000-000000000005','Paciente Não Vinculado');

insert into public.organizations (id,name,slug,created_by) values
  ('21000000-0000-0000-0000-000000000001','Clínica Publicação A','clinica-publicacao-a','11000000-0000-0000-0000-000000000001'),
  ('21000000-0000-0000-0000-000000000002','Clínica Publicação B','clinica-publicacao-b','11000000-0000-0000-0000-000000000003');
insert into public.memberships (organization_id,user_id,role,status) values
  ('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','nutritionist','active'),
  ('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000002','receptionist','active'),
  ('21000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000003','nutritionist','active');

insert into public.patients (id,organization_id,professional_id,anonymous_code,full_name,created_by,patient_user_id) values
  ('31000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','PUB-A01','Paciente Publicação A','11000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000004'),
  ('31000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000003','PUB-B01','Paciente Publicação B','11000000-0000-0000-0000-000000000003',null);

insert into public.plans (id,organization_id,patient_id,created_by,title) values
  ('41000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','Plano A'),
  ('41000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000002','31000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000003','Plano B');
insert into public.plan_versions (id,organization_id,plan_id,version_no,created_by) values
  ('51000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',1,'11000000-0000-0000-0000-000000000001'),
  ('51000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',2,'11000000-0000-0000-0000-000000000001'),
  ('51000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000002','41000000-0000-0000-0000-000000000002',1,'11000000-0000-0000-0000-000000000003');
insert into public.plan_days (id,organization_id,plan_version_id,day_index,label) values
  ('61000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',0,'Dia publicado'),
  ('61000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002',0,'Dia rascunho');
insert into public.meals (id,organization_id,plan_day_id,position,label) values
  ('71000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',0,'Almoço');
insert into public.meal_items (id,organization_id,meal_id,position,description,quantity,unit,grams,nutrient_snapshot) values
  ('81000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001',0,'Arroz sintético',100,'g',100,'{"energy_kcal":130}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.review_plan_version('41000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','{"energy_kcal":2000,"protein_g":100}'::jsonb)$$,'nutricionista revisa versão com metas');
select lives_ok($$select public.publish_plan_version('41000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001')$$,'nutricionista publica versão revisada');
select ok((select locked_at is not null and published_at is not null and content_hash is not null from public.plan_versions where id='51000000-0000-0000-0000-000000000001'),'publicação bloqueia e assina a versão');
select is((select targets->>'energy_kcal' from public.plan_versions where id='51000000-0000-0000-0000-000000000001'),'2000','metas revisadas ficam preservadas');
select throws_ok($$update public.plan_versions set targets='{"energy_kcal":1}' where id='51000000-0000-0000-0000-000000000001'$$,null,null,'versão publicada é imutável');
select throws_ok($$update public.meal_items set grams=1 where id='81000000-0000-0000-0000-000000000001'$$,null,null,'item de versão publicada é imutável');
select throws_ok($$delete from public.plan_days where id='61000000-0000-0000-0000-000000000001'$$,null,null,'descendente publicado não pode ser excluído');
select is((select count(*)::integer from public.plans where organization_id='21000000-0000-0000-0000-000000000002'),0,'nutricionista A não lê plano B');

select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.plans),0,'recepção não lê planos');
select is((select count(*)::integer from public.plan_versions),0,'recepção não lê versões nem metas');

select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000004',true);
select is((select count(*)::integer from public.plans),1,'paciente vinculado lê seu plano publicado');
select is((select count(*)::integer from public.plan_versions),1,'paciente lê somente a versão publicada vigente');
select is((select count(*)::integer from public.plan_days),1,'paciente lê somente dias da versão publicada');

select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000005',true);
select is((select count(*)::integer from public.plans),0,'usuário sem vínculo não lê planos');
select is((select count(*)::integer from public.plan_versions),0,'usuário sem vínculo não lê versões ou metas');

select * from finish();
rollback;
