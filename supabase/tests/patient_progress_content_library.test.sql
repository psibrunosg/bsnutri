begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

set local role postgres;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('71000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-progress@teste.invalid','',now(),now(),now()),
 ('71000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','reception-progress@teste.invalid','',now(),now(),now()),
 ('71000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','patient-progress@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('71000000-0000-0000-0000-000000000001','Nutricionista'),('71000000-0000-0000-0000-000000000002','Recepção'),('71000000-0000-0000-0000-000000000003','Paciente');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations(id,name,slug,created_by) values('72000000-0000-0000-0000-000000000001','Clínica Progresso','clinica-progresso','71000000-0000-0000-0000-000000000001');
set local role postgres;
insert into public.memberships(organization_id,user_id,role,status) values('72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','receptionist','active');
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by,patient_user_id) values('73000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','PG-01','Paciente','71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
insert into public.patient_goals(organization_id,patient_id,kind,title,target_value,target_unit,created_by) values('72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','water','Água',2200,'ml','71000000-0000-0000-0000-000000000001');
insert into public.content_library_items(id,organization_id,title,content_type,created_by) values('74000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','Fibras no café','guidance','71000000-0000-0000-0000-000000000001');
select lives_ok($$select public.publish_content_library_version('74000000-0000-0000-0000-000000000001','Inclua uma fonte de fibra no café da manhã.')$$,'profissional publica versão de conteúdo');
select lives_ok($$select public.deliver_content_to_patient((select id from public.content_library_versions limit 1),'73000000-0000-0000-0000-000000000001')$$,'profissional entrega cópia ao paciente');
select throws_ok($$update public.content_library_versions set body='alterado'$$,null,null,'versão publicada é imutável');

select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.patient_goals),0,'recepção não acessa metas clínicas');
select is((select count(*)::integer from public.patient_content_deliveries),0,'recepção não acessa conteúdos entregues');
select * from finish();
rollback;
