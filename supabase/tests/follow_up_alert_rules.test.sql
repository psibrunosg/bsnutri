begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

set local role postgres;

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('13000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-alertas@teste.invalid','',now(),now(),now()),
 ('13000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','paciente-alertas@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('13000000-0000-0000-0000-000000000001','Nutricionista Alertas'),
 ('13000000-0000-0000-0000-000000000002','Paciente Alertas');

set local role authenticated;
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations(id,name,slug,created_by) values
 ('23000000-0000-0000-0000-000000000001','Clinica Alertas','clinica-alertas','13000000-0000-0000-0000-000000000001');

set local role postgres;
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by,patient_user_id) values
 ('33000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001','ALT-A01','Paciente Alertas','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000002');
insert into public.plans(id,organization_id,patient_id,created_by,title,status) values
 ('53000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001','Plano alerta','published');
insert into public.plan_versions(id,organization_id,plan_id,version_no,created_by) values
 ('63000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000001',1,'13000000-0000-0000-0000-000000000001');
select set_config('bsnutri.workflow_rpc','on',true);
update public.plans set current_published_version_id='63000000-0000-0000-0000-000000000001' where id='53000000-0000-0000-0000-000000000001';
insert into public.plan_days(id,organization_id,plan_version_id,day_index,label) values
 ('73000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001',0,'Dia alerta');
insert into public.meals(id,organization_id,plan_day_id,position,label) values
 ('83000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001',0,'Almoco');

set local role authenticated;
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claim.role','authenticated',true);
select lives_ok($$insert into public.meal_checkins(id,organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,hunger_before,satiety_after,symptoms,symptom_intensity,help_requested,created_by) values
 ('b3000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-01','completed',5,7,null,null,false,'13000000-0000-0000-0000-000000000002'),
 ('b3000000-0000-0000-0000-000000000002','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-02','skipped',null,null,null,null,false,'13000000-0000-0000-0000-000000000002'),
 ('b3000000-0000-0000-0000-000000000003','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-03','adapted',null,null,null,null,false,'13000000-0000-0000-0000-000000000002'),
 ('b3000000-0000-0000-0000-000000000004','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-04','completed',9,null,null,null,false,'13000000-0000-0000-0000-000000000002'),
 ('b3000000-0000-0000-0000-000000000005','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-05','completed',null,1,null,null,false,'13000000-0000-0000-0000-000000000002'),
 ('b3000000-0000-0000-0000-000000000006','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-06','completed',null,null,'Nausea',4,false,'13000000-0000-0000-0000-000000000002'),
 ('b3000000-0000-0000-0000-000000000007','23000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','2030-02-07','completed',null,null,null,null,true,'13000000-0000-0000-0000-000000000002')$$,'paciente registra diario com e sem desvios');

set local role authenticated;
select set_config('request.jwt.claim.sub','13000000-0000-0000-0000-000000000001',true);
select is((select count(*)::integer from public.adherence_alerts),6,'somente desvios relevantes geram alertas');
select is((select count(*)::integer from public.adherence_alerts where checkin_id='b3000000-0000-0000-0000-000000000001'),0,'registro normal sem desvio nao gera alerta');
select is((select count(*)::integer from public.adherence_alerts where message='Paciente registrou refeicao pulada.'),1,'refeicao pulada gera alerta');
select is((select count(*)::integer from public.adherence_alerts where message='Paciente registrou refeicao adaptada ou troca nao aprovada.'),1,'troca nao aprovada gera alerta');
select is((select count(*)::integer from public.adherence_alerts where message='Paciente registrou fome extrema antes da refeicao.'),1,'fome extrema gera alerta');
select is((select count(*)::integer from public.adherence_alerts where message='Paciente registrou saciedade extrema baixa depois da refeicao.'),1,'saciedade extrema gera alerta');
select is((select count(*)::integer from public.adherence_alerts where message='Paciente registrou sintoma moderado ou forte.'),1,'sintoma moderado ou forte gera alerta');
select is((select severity::text from public.adherence_alerts where message='Paciente pediu ajuda no diario alimentar.'),'urgent','pedido de ajuda sempre gera alerta urgente');

select * from finish();
rollback;
