begin;

create extension if not exists pgtap with schema extensions;
select plan(27);

set local role postgres;

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('12000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-agenda-a@teste.invalid','',now(),now(),now()),
 ('12000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recepcao-agenda-a@teste.invalid','',now(),now(),now()),
 ('12000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','paciente-agenda-a@teste.invalid','',now(),now(),now()),
 ('12000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-agenda-b@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('12000000-0000-0000-0000-000000000001','Nutricionista Agenda A'),
 ('12000000-0000-0000-0000-000000000002','Recepção Agenda A'),
 ('12000000-0000-0000-0000-000000000003','Paciente Agenda A'),
 ('12000000-0000-0000-0000-000000000004','Nutricionista Agenda B');
set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations(id,name,slug,created_by) values
 ('22000000-0000-0000-0000-000000000001','Clínica Agenda A','clinica-agenda-a','12000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000004',true);
insert into public.organizations(id,name,slug,created_by) values
 ('22000000-0000-0000-0000-000000000002','Clínica Agenda B','clinica-agenda-b','12000000-0000-0000-0000-000000000004');
set local role postgres;
insert into public.memberships(organization_id,user_id,role,status) values
  ('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000002','receptionist','active');
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by,patient_user_id) values
 ('32000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','AGE-A01','Paciente Agenda A','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003'),
 ('32000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000002','12000000-0000-0000-0000-000000000004','AGE-B01','Paciente Agenda B','12000000-0000-0000-0000-000000000004',null);
insert into public.rooms(id,organization_id,name) values
 ('42000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','Sala 1'),
 ('42000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000002','Sala 1');

insert into public.plans(id,organization_id,patient_id,created_by,title,status) values
 ('52000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','Plano de adesão','published');
insert into public.plan_versions(id,organization_id,plan_id,version_no,created_by) values
 ('62000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000001',1,'12000000-0000-0000-0000-000000000001');
select set_config('bsnutri.workflow_rpc','on',true);
update public.plans set current_published_version_id='62000000-0000-0000-0000-000000000001' where id='52000000-0000-0000-0000-000000000001';
insert into public.plan_days(id,organization_id,plan_version_id,day_index,label) values
 ('72000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',0,'Dia vigente');
insert into public.meals(id,organization_id,plan_day_id,position,label) values
 ('82000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001',0,'Almoço');

insert into public.appointments(id,organization_id,patient_id,professional_id,room_id,requested_by,status,modality,starts_at,ends_at,reviewed_by,reviewed_at) values
 ('92000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003','requested','in_person','2030-01-10 13:00+00','2030-01-10 14:00+00',null,null),
 ('92000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','approved','in_person','2030-01-11 13:00+00','2030-01-11 14:00+00','12000000-0000-0000-0000-000000000001',now()),
 ('92000000-0000-0000-0000-000000000003','22000000-0000-0000-0000-000000000002','32000000-0000-0000-0000-000000000002','12000000-0000-0000-0000-000000000004','42000000-0000-0000-0000-000000000002','12000000-0000-0000-0000-000000000004','requested','in_person','2030-01-12 13:00+00','2030-01-12 14:00+00',null,null);

select throws_ok($$insert into public.appointments(organization_id,patient_id,professional_id,requested_by,modality,starts_at,ends_at) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','online','2030-01-10 14:00+00','2030-01-10 14:00+00')$$,null,null,'fim deve ser posterior ao início');
select throws_ok($$insert into public.appointments(organization_id,patient_id,professional_id,requested_by,status,modality,starts_at,ends_at,reviewed_by,reviewed_at) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','approved','online','2030-01-11 13:30+00','2030-01-11 14:30+00','12000000-0000-0000-0000-000000000001',now())$$,null,null,'profissional não pode ter consulta aprovada sobreposta');
select lives_ok($$insert into public.appointments(organization_id,patient_id,professional_id,requested_by,status,modality,starts_at,ends_at,external_meeting_url,reviewed_by,reviewed_at) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','approved','online','2030-01-11 14:00+00','2030-01-11 15:00+00','https://meet.example.com/adjacente','12000000-0000-0000-0000-000000000001',now())$$,'intervalos adjacentes são permitidos');
select throws_ok($$insert into public.appointments(organization_id,patient_id,professional_id,requested_by,status,modality,starts_at,ends_at) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','approved','online','2030-01-20 13:00+00','2030-01-20 14:00+00')$$,null,null,'aprovação exige revisor e horário de revisão');

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claim.role','authenticated',true);
select is((select count(*)::integer from public.appointments),3,'paciente vê somente suas consultas da própria clínica');
select lives_ok($$insert into public.appointments(organization_id,patient_id,professional_id,requested_by,modality,starts_at,ends_at) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003','online','2030-02-01 13:00+00','2030-02-01 14:00+00')$$,'paciente solicita consulta própria');
select throws_ok($$update public.appointments set status='approved' where id='92000000-0000-0000-0000-000000000001'$$,null,null,'status não pode ser alterado fora do fluxo');
select throws_ok($$select public.review_appointment('92000000-0000-0000-0000-000000000001','approved',null,null)$$,null,null,'paciente não aprova consulta');
select lives_ok($$select public.cancel_appointment('92000000-0000-0000-0000-000000000001','Imprevisto')$$,'paciente cancela consulta própria');
select is((select status::text from public.appointments where id='92000000-0000-0000-0000-000000000001'),'cancelled','cancelamento altera estado pelo fluxo');
insert into public.appointments(id,organization_id,patient_id,professional_id,room_id,requested_by,status,modality,starts_at,ends_at) values('92000000-0000-0000-0000-000000000004','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003','requested','in_person','2030-01-15 13:00+00','2030-01-15 14:00+00');

select lives_ok($$insert into public.meal_checkins(id,organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,hunger_before,reaction_suspected,created_by) values('a2000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','2030-01-10','adapted',9,true,'12000000-0000-0000-0000-000000000003')$$,'paciente registra adesão no plano vigente');
select is((select count(*)::integer from public.adherence_alerts),0,'paciente não vê alerta clínico');
select throws_ok($$insert into public.meal_checkins(organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,created_by) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','2030-01-10','completed','12000000-0000-0000-0000-000000000003')$$,null,null,'uma refeição por ocorrência não duplica');
select throws_ok($$insert into public.meal_checkins(organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,created_by) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',gen_random_uuid(),'2030-01-11','completed','12000000-0000-0000-0000-000000000003')$$,null,null,'check-in fora da cadeia vigente falha');
select throws_ok($$insert into public.meal_checkins(organization_id,patient_id,plan_version_id,meal_id,occurred_on,state,created_by) values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','2030-01-11','completed','12000000-0000-0000-0000-000000000001')$$,null,null,'autor diferente do usuário autenticado falha');

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
select ok((select count(*) from public.appointments)>0,'recepção vê a agenda da clínica');
select is((select count(*)::integer from public.meal_checkins),0,'recepção não vê adesão');
select is((select count(*)::integer from public.adherence_alerts),0,'recepção não vê alertas clínicos');

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select is((select count(*)::integer from public.meal_checkins),1,'nutricionista vê adesão da clínica');
select is((select count(*)::integer from public.adherence_alerts),1,'reação gera um alerta urgente');
select is((select severity::text from public.adherence_alerts limit 1),'urgent','alerta de reação tem prioridade urgente');
select lives_ok($$select public.update_alert_status((select id from public.adherence_alerts limit 1),'acknowledged')$$,'nutricionista reconhece alerta');
select ok((select acknowledged_by='12000000-0000-0000-0000-000000000001' and acknowledged_at is not null from public.adherence_alerts limit 1),'reconhecimento registra ator e horário');
select lives_ok($$select public.review_appointment((select id from public.appointments where status='requested' and organization_id='22000000-0000-0000-0000-000000000001' order by starts_at desc limit 1),'approved','Confirmada','https://meet.example.com/agenda-a')$$,'nutricionista aprova solicitação');
set local role postgres;
select ok((select count(*) from public.audit_events where action in('appointment_approved','appointment_cancelled'))>=2,'decisões de agenda geram auditoria');
set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000004',true);
select is((select count(*)::integer from public.appointments),1,'nutricionista de outra clínica não lê agenda A');
select is((select count(*)::integer from public.meal_checkins),0,'nutricionista de outra clínica não lê adesão A');

select * from finish();
rollback;
