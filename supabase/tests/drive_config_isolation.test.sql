begin;

create extension if not exists pgtap with schema extensions;
select plan(7);

set local role postgres;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('16000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-drive@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recepcao-drive@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','paciente-drive@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-drive-b@teste.invalid','',now(),now(),now()),
  ('16000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','outro-paciente-drive@teste.invalid','',now(),now(),now());

insert into public.profiles (id, full_name) values
  ('16000000-0000-0000-0000-000000000001','Owner Drive'),
  ('16000000-0000-0000-0000-000000000002','Recepcao Drive'),
  ('16000000-0000-0000-0000-000000000003','Paciente Drive'),
  ('16000000-0000-0000-0000-000000000004','Owner Drive B'),
  ('16000000-0000-0000-0000-000000000005','Outro Paciente Drive');

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
  ('36000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001','DRV-A','Paciente Drive','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000003'),
  ('36000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001','DRV-B','Outro Paciente Drive','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000005');

insert into public.plans(id,organization_id,patient_id,created_by,title,status,current_published_version_id) values
  ('46000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000001','Plano Drive A','draft',null),
  ('46000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000002','16000000-0000-0000-0000-000000000001','Plano Drive B','draft',null);
insert into public.plan_versions(id,organization_id,plan_id,version_no,created_by,locked_at,published_at) values
  ('56000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',1,'16000000-0000-0000-0000-000000000001',now(),now()),
  ('56000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000002',1,'16000000-0000-0000-0000-000000000001',now(),now());
update public.plans set status='published',current_published_version_id='56000000-0000-0000-0000-000000000001' where id='46000000-0000-0000-0000-000000000001';
update public.plans set status='published',current_published_version_id='56000000-0000-0000-0000-000000000002' where id='46000000-0000-0000-0000-000000000002';
insert into public.plan_days(id,organization_id,plan_version_id,day_index,label) values
  ('66000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001',0,'Dia 1'),
  ('66000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000002',0,'Dia 1');
insert into public.meals(id,organization_id,plan_day_id,position,label) values
  ('76000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000001',0,'Almoco'),
  ('76000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000002',0,'Almoco');
set local role authenticated;
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000003',true);
insert into public.meal_checkins(id,organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,created_by) values
  ('86000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000001','2026-07-17','completed','16000000-0000-0000-0000-000000000003');
insert into public.meal_checkin_photos(id,organization_id,patient_id,meal_checkin_id,meal_id,occurred_on,drive_file_id,file_name,created_by) values
  ('96000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000001','2026-07-17','drive-file-a','photo-a.jpg','16000000-0000-0000-0000-000000000003');
select set_config('request.jwt.claim.sub','16000000-0000-0000-0000-000000000005',true);
insert into public.meal_checkins(id,organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,created_by) values
  ('86000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000002','56000000-0000-0000-0000-000000000002','76000000-0000-0000-0000-000000000002','2026-07-17','completed','16000000-0000-0000-0000-000000000005');
insert into public.meal_checkin_photos(id,organization_id,patient_id,meal_checkin_id,meal_id,occurred_on,drive_file_id,file_name,created_by) values
  ('96000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000001','36000000-0000-0000-0000-000000000002','86000000-0000-0000-0000-000000000002','76000000-0000-0000-0000-000000000002','2026-07-17','drive-file-b','photo-b.jpg','16000000-0000-0000-0000-000000000005');

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
select is((select count(*)::integer from public.meal_checkin_photos),1,'paciente le somente fotos proprias');

select * from finish();
rollback;
