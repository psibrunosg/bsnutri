begin;

create extension if not exists pgtap with schema extensions;
select plan(5);

set local role postgres;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('1a000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','modelos-a@teste.invalid','',now(),now(),now()),
 ('1a000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','modelos-b@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('1a000000-0000-0000-0000-000000000001','Nutricionista Modelos A'),
 ('1a000000-0000-0000-0000-000000000002','Nutricionista Modelos B');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','1a000000-0000-0000-0000-000000000001',true);
insert into public.organizations(id,name,slug,created_by) values('2a000000-0000-0000-0000-000000000001','Clinica Modelos','clinica-modelos','1a000000-0000-0000-0000-000000000001');

set local role postgres;
insert into public.memberships(organization_id,user_id,role,status) values('2a000000-0000-0000-0000-000000000001','1a000000-0000-0000-0000-000000000002','nutritionist','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','1a000000-0000-0000-0000-000000000001',true);
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by) values('3a000000-0000-0000-0000-000000000001','2a000000-0000-0000-0000-000000000001','1a000000-0000-0000-0000-000000000001','MOD-01','Paciente Modelo','1a000000-0000-0000-0000-000000000001');
insert into public.plans(id,organization_id,patient_id,created_by,title,status) values('4a000000-0000-0000-0000-000000000001','2a000000-0000-0000-0000-000000000001','3a000000-0000-0000-0000-000000000001','1a000000-0000-0000-0000-000000000001','Plano fonte','draft');
insert into public.plan_versions(organization_id,plan_id,version_no,created_by,targets) values('2a000000-0000-0000-0000-000000000001','4a000000-0000-0000-0000-000000000001',1,'1a000000-0000-0000-0000-000000000001','{"energyKcal":1800}'::jsonb);

select lives_ok($$select public.create_plan_template_from_plan_v2('4a000000-0000-0000-0000-000000000001','Modelo pessoal','personal','{"approaches":["Flexível"],"objectives":["Emagrecimento"],"restrictions":[],"preferences":[],"contexts":[]}'::jsonb,'{"targets":{"energyKcal":1700},"guidance":["Revisar"]}'::jsonb)$$,'cria modelo pessoal com dimensoes e regras');
select is((select scope::text from public.plan_templates where name='Modelo pessoal'),'personal','modelo guarda escopo pessoal');
select is((select snapshot ? 'plan' from public.plan_templates where name='Modelo pessoal'),false,'snapshot novo nao copia dados do paciente');

select set_config('request.jwt.claim.sub','1a000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.plan_templates where name='Modelo pessoal'),0,'outro profissional nao le modelo pessoal');

select set_config('request.jwt.claim.sub','1a000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.apply_plan_template_to_patient((select id from public.plan_templates where name='Modelo pessoal'),'3a000000-0000-0000-0000-000000000001')$$,'aplica modelo em rascunho independente');

select * from finish();
rollback;
