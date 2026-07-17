begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

set local role postgres;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('16000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-drive@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recepcao-drive@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','paciente-drive@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-drive-b@teste.invalid','',now(),now(),now());

insert into public.profiles (id, full_name) values
  ('16000000-0000-0000-0000-000000000001','Owner Drive'),
  ('16000000-0000-0000-0000-000000000002','Recepcao Drive'),
  ('16000000-0000-0000-0000-000000000003','Paciente Drive'),
  ('16000000-0000-0000-0000-000000000004','Owner Drive B');

set local role authenticated;
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations (id,name,slug,created_by) values ('26000000-0000-0000-0000-000000000001','Clinica Drive A','clinica-drive-a','16000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000004',true);
insert into public.organizations (id,name,slug,created_by) values ('26000000-0000-0000-0000-000000000002','Clinica Drive B','clinica-drive-b','16000000-0000-0000-0000-000000000004');

set local role postgres;
insert into public.memberships (organization_id,user_id,role,status) values
  ('26000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000002','receptionist','active');
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by,patient_user_id) values
  ('36000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001','DRV-A','Paciente Drive','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000001',true);
select lives_ok($$insert into public.organization_drive_configs(organization_id,status,root_folder_id,connected_by,connected_at) values('26000000-0000-0000-0000-000000000001','connected','folder-a','16000000-0000-0000-0000-000000000001',now())$$,'owner configura Drive');
select is((select count(*)::integer from public.organization_drive_configs),1,'clinica ve propria config');

select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.organization_drive_configs),0,'recepcao nao le config Drive');
select throws_ok($$insert into public.organization_drive_configs(organization_id,status,root_folder_id,connected_by,connected_at) values('26000000-0000-0000-0000-000000000001','connected','folder-recepcao','16000000-0000-0000-0000-000000000002',now())$$,'42501',null,'recepcao nao configura Drive');

select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000003',true);
select is((select can_upload_photos from public.get_patient_drive_status('36000000-0000-0000-0000-000000000001')),true,'paciente recebe status de upload');
select is((select count(*)::integer from public.organization_drive_configs),0,'paciente nao le config Drive direta');

select * from finish();
rollback;
