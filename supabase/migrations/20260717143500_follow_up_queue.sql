create table public.follow_up_actions (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 patient_id uuid not null references public.patients(id) on delete cascade,
 alert_id uuid not null references public.adherence_alerts(id) on delete cascade,
 action_type text not null check (action_type in ('guidance','review_request','substitution_request','followed_up')),
 note text,
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now()
);

create index follow_up_actions_alert_idx on public.follow_up_actions(alert_id,created_at desc);
create index follow_up_actions_org_idx on public.follow_up_actions(organization_id,created_at desc);

alter table public.follow_up_actions enable row level security;

create policy follow_up_actions_select_clinical on public.follow_up_actions for select to authenticated using (
 private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
);
create policy follow_up_actions_insert_clinical on public.follow_up_actions for insert to authenticated with check (
 created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
);

create or replace view public.follow_up_queue
with (security_invoker = true) as
select
 a.id,
 a.organization_id,
 a.patient_id,
 p.full_name as patient_name,
 a.checkin_id,
 a.kind,
 a.severity,
 a.message,
 a.status,
 a.detected_at,
 case
  when a.status='resolved' then 0
  when a.message ilike '%ajuda%' then 100
  when a.kind='severe_symptom' and a.severity='urgent' then 95
  when a.kind='severe_symptom' then 90
  when a.kind='low_intake' and a.message ilike '%pulada%' and count(*) filter (where a.kind='low_intake' and a.message ilike '%pulada%') over (partition by a.patient_id) > 1 then 80
  when a.kind='low_intake' and a.message ilike '%pulada%' then 75
  when a.kind='other' then 70
  when a.kind in ('intense_hunger','low_intake') then 60
  else 10
 end as priority_score
from public.adherence_alerts a
join public.patients p on p.id=a.patient_id
where a.status <> 'resolved';

create or replace function public.create_follow_up_action(target_alert_id uuid,target_action text,target_note text default null)
returns public.follow_up_actions language plpgsql security invoker set search_path='' as $$
declare
 row_data public.adherence_alerts;
 result public.follow_up_actions;
 clean_note text := nullif(trim(coalesce(target_note,'')),'');
begin
 if target_action not in ('guidance','review_request','substitution_request','followed_up') then
  raise exception 'acao de acompanhamento invalida';
 end if;
 select * into row_data from public.adherence_alerts where id=target_alert_id;
 if row_data.id is null or not private.has_organization_role(row_data.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then
  raise exception 'alerta indisponivel';
 end if;
 if target_action in ('guidance','review_request','substitution_request') and clean_note is null then
  raise exception 'nota obrigatoria para acao de acompanhamento';
 end if;
 insert into public.follow_up_actions(organization_id,patient_id,alert_id,action_type,note,created_by)
 values(row_data.organization_id,row_data.patient_id,row_data.id,target_action,clean_note,auth.uid())
 returning * into result;
 if target_action='followed_up' then
  update public.adherence_alerts set status='resolved',resolved_by=auth.uid(),resolved_at=now() where id=row_data.id;
 elsif row_data.status='open' then
  update public.adherence_alerts set status='acknowledged',acknowledged_by=auth.uid(),acknowledged_at=now() where id=row_data.id;
 end if;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values(row_data.organization_id,auth.uid(),'follow_up_'||target_action,'adherence_alert',row_data.id,jsonb_build_object('note',clean_note));
 return result;
end; $$;

revoke all on function public.create_follow_up_action(uuid,text,text) from public,anon;
grant execute on function public.create_follow_up_action(uuid,text,text) to authenticated;
grant select on public.follow_up_queue to authenticated;
grant select,insert on public.follow_up_actions to authenticated;
