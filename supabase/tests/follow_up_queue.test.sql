begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

set local role postgres;

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
 ('14000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nutri-fila@teste.invalid','',now(),now(),now()),
 ('14000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recepcao-fila@teste.invalid','',now(),now(),now());
insert into public.profiles(id,full_name) values
 ('14000000-0000-0000-0000-000000000001','Nutricionista Fila'),
 ('14000000-0000-0000-0000-000000000002','Recepcao Fila');

set local role authenticated;
select set_config('request.jwt.claim.sub','14000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into public.organizations(id,name,slug,created_by) values
 ('24000000-0000-0000-0000-000000000001','Clinica Fila','clinica-fila','14000000-0000-0000-0000-000000000001');

set local role postgres;
insert into public.memberships(organization_id,user_id,role,status) values
 ('24000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000002','receptionist','active');
insert into public.patients(id,organization_id,professional_id,anonymous_code,full_name,created_by) values
 ('34000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000001','FIL-A01','Paciente Fila','14000000-0000-0000-0000-000000000001');
insert into public.adherence_alerts(id,organization_id,patient_id,kind,severity,message,detected_at) values
 ('c4000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000001','other','attention','Paciente registrou refeicao adaptada ou troca nao aprovada.','2030-03-03 10:00+00'),
 ('c4000000-0000-0000-0000-000000000002','24000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000001','low_intake','attention','Paciente registrou refeicao pulada.','2030-03-04 10:00+00'),
 ('c4000000-0000-0000-0000-000000000003','24000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000001','intense_hunger','attention','Paciente registrou fome extrema antes da refeicao.','2030-03-05 10:00+00'),
 ('c4000000-0000-0000-0000-000000000004','24000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000001','severe_symptom','urgent','Paciente pediu ajuda no diario alimentar.','2030-03-01 10:00+00');

set local role authenticated;
select set_config('request.jwt.claim.sub','14000000-0000-0000-0000-000000000001',true);
select is((select id::text from public.follow_up_queue order by priority_score desc, detected_at desc limit 1),'c4000000-0000-0000-0000-000000000004','fila prioriza pedido de ajuda e sintoma forte');
select lives_ok($$select public.create_follow_up_action('c4000000-0000-0000-0000-000000000004','guidance','Hidrate-se e me avise em 2 horas.')$$,'nutricionista registra orientacao curta');
select is((select action_type from public.follow_up_actions where alert_id='c4000000-0000-0000-0000-000000000004'),'guidance','orientacao fica registrada no BSNutri');
select is((select status::text from public.adherence_alerts where id='c4000000-0000-0000-0000-000000000004'),'acknowledged','orientacao reconhece alerta aberto');
select lives_ok($$select public.create_follow_up_action('c4000000-0000-0000-0000-000000000001','review_request','Revisar lanche da tarde.')$$,'nutricionista solicita revisao');
select lives_ok($$select public.create_follow_up_action('c4000000-0000-0000-0000-000000000003','substitution_request','Avaliar substituicao do jantar.')$$,'nutricionista solicita substituicao');
select lives_ok($$select public.create_follow_up_action('c4000000-0000-0000-0000-000000000002','followed_up',null)$$,'nutricionista marca alerta como acompanhado');
select is((select count(*)::integer from public.follow_up_queue where id='c4000000-0000-0000-0000-000000000002'),0,'alerta acompanhado sai da fila');

select set_config('request.jwt.claim.sub','14000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.follow_up_queue),0,'recepcao nao acessa fila clinica');

select * from finish();
rollback;
