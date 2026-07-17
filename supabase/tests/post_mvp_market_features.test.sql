begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

set local role postgres;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('15000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-post@teste.invalid','',now(),now(),now()),
 ('15000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recepcao-post@teste.invalid','',now(),now(),now()),
 ('15000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','paciente-post@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('15000000-0000-0000-0000-000000000001','Nutricionista Post'),
 ('15000000-0000-0000-0000-000000000002','Recepcao Post'),
 ('15000000-0000-0000-0000-000000000003','Paciente Post');

set local role authenticated;
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations(id,name,slug,created_by) values('25000000-0000-0000-0000-000000000001','Clinica Post','clinica-post','15000000-0000-0000-0000-000000000001');

set local role postgres;
insert into public.memberships(organization_id,user_id,role,status) values('25000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000002','receptionist','active');
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by,patient_user_id) values('35000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000001','PMF-01','Paciente Post','15000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
insert into public.form_templates(id,organization_id,name,status,created_by) values('45000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','Anamnese adulto','published','15000000-0000-0000-0000-000000000001');
insert into public.form_template_versions(id,organization_id,template_id,version_no,title,published_by) values('46000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-000000000001',1,'Anamnese adulto','15000000-0000-0000-0000-000000000001');
insert into public.form_fields(id,organization_id,version_id,position,label,field_type,required) values
 ('47000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',0,'Objetivo','short_text',true),
 ('47000000-0000-0000-0000-000000000002','25000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',1,'Rotina','long_text',false),
 ('47000000-0000-0000-0000-000000000003','25000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',2,'Peso','number',false),
 ('47000000-0000-0000-0000-000000000004','25000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',3,'Fome','scale',false),
 ('47000000-0000-0000-0000-000000000005','25000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',4,'Preferencia','select',false),
 ('47000000-0000-0000-0000-000000000006','25000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',5,'Data exame','date',false);
insert into public.form_assignments(id,organization_id,patient_id,version_id,assigned_by) values('48000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000001');
select is((select count(*)::integer from public.form_fields),6,'campos suportam tipos basicos da anamnese');

select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.form_responses),0,'recepcao nao acessa respostas clinicas');

select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.save_form_response('48000000-0000-0000-0000-000000000001','{"47000000-0000-0000-0000-000000000002":"Rotina corrida"}'::jsonb,false)$$,'paciente salva rascunho');
select throws_ok($$select public.save_form_response('48000000-0000-0000-0000-000000000001','{}'::jsonb,true)$$,null,null,'envio valida obrigatorios');
select lives_ok($$select public.save_form_response('48000000-0000-0000-0000-000000000001','{"47000000-0000-0000-0000-000000000001":"Hipertrofia"}'::jsonb,true)$$,'paciente envia pre-consulta');

select set_config('request.jwt.claim.sub','15000000-0000-0000-0000-000000000001',true);
select is((select version_id::text from public.form_responses where assignment_id='48000000-0000-0000-0000-000000000001'),'46000000-0000-0000-0000-000000000001','resposta aponta para versao respondida');
insert into public.consultation_summaries(organization_id,patient_id,summary,created_by) values('25000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000001','Resumo da consulta','15000000-0000-0000-0000-000000000001');
select is((select count(*)::integer from public.consultation_summaries),1,'profissional registra resumo clinico');

insert into public.plans(id,organization_id,patient_id,created_by,title,status) values('55000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000001','Plano base','draft');
insert into public.plan_versions(id,organization_id,plan_id,version_no,created_by) values('56000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000001',1,'15000000-0000-0000-0000-000000000001');
insert into public.plan_days(id,organization_id,plan_version_id,day_index,label) values('57000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',0,'Dia 1');
insert into public.meals(id,organization_id,plan_day_id,position,label) values('58000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-000000000001',0,'Almoco');
insert into public.meal_items(organization_id,meal_id,position,description,quantity,unit,grams,nutrient_snapshot) values('25000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-000000000001',0,'Arroz',100,'g',100,'{}');
select lives_ok($$select public.create_plan_template_from_plan('55000000-0000-0000-0000-000000000001','Modelo hipertrofia','Ganho de massa',array['hipertrofia'])$$,'profissional salva plano como modelo');
select lives_ok($$select public.copy_plan_template_to_patient((select id from public.plan_templates limit 1),'35000000-0000-0000-0000-000000000001')$$,'modelo copia para novo plano do paciente');
update public.plan_templates set name='Modelo alterado' where source_plan_id='55000000-0000-0000-0000-000000000001';
select isnt((select title from public.plans where title='Modelo hipertrofia' limit 1),(select name from public.plan_templates limit 1),'alterar modelo nao altera plano copiado');

select * from finish();
rollback;
