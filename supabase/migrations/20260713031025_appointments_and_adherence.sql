create extension if not exists btree_gist;
create type public.appointment_status as enum ('requested','approved','rejected','cancelled','completed','no_show');
create type public.appointment_modality as enum ('in_person','online','home_visit');
create type public.checkin_state as enum ('completed','adapted','skipped');
create type public.alert_kind as enum ('allergy_or_reaction','severe_symptom','low_intake','intense_hunger','rapid_weight_change','other');
create type public.alert_severity as enum ('info','attention','urgent');
create type public.alert_status as enum ('open','acknowledged','resolved');

create table public.rooms (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null, active boolean not null default true, created_at timestamptz not null default now(),
 unique(organization_id,name), unique(id,organization_id)
);

create table public.appointments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 patient_id uuid not null, professional_id uuid not null references public.profiles(id), room_id uuid,
 requested_by uuid not null references public.profiles(id), status public.appointment_status not null default 'requested',
 modality public.appointment_modality not null, starts_at timestamptz not null, ends_at timestamptz not null,
 external_meeting_url text, location_text text, patient_note text, staff_note text,
 reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, cancellation_reason text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(id,organization_id),
 foreign key(patient_id,organization_id) references public.patients(id,organization_id) on delete restrict,
 foreign key(room_id,organization_id) references public.rooms(id,organization_id) on delete restrict,
 check(ends_at>starts_at), check(modality<>'in_person' or room_id is not null or location_text is not null),
 check(status not in ('approved','rejected') or (reviewed_by is not null and reviewed_at is not null))
);
alter table public.appointments add constraint appointments_professional_no_overlap exclude using gist
 (professional_id with =, tstzrange(starts_at,ends_at,'[)') with &&) where(status='approved');
alter table public.appointments add constraint appointments_room_no_overlap exclude using gist
 (room_id with =, tstzrange(starts_at,ends_at,'[)') with &&) where(status='approved' and room_id is not null);
create index appointments_org_status_start_idx on public.appointments(organization_id,status,starts_at);
create index appointments_patient_start_idx on public.appointments(patient_id,starts_at);
create trigger appointments_updated_at before update on public.appointments for each row execute function private.set_updated_at();

create table public.meal_checkins (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 patient_id uuid not null, plan_version_id uuid not null, meal_id uuid not null,
 occurred_on date not null default current_date, state public.checkin_state not null,
 hunger_before smallint check(hunger_before between 0 and 10), satiety_after smallint check(satiety_after between 0 and 10),
 mood smallint check(mood between 0 and 10), energy smallint check(energy between 0 and 10), sleep_quality smallint check(sleep_quality between 0 and 10),
 reaction_suspected boolean not null default false, symptoms text, note text,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(patient_id,meal_id,occurred_on), unique(id,organization_id),
 foreign key(patient_id,organization_id) references public.patients(id,organization_id) on delete cascade,
 foreign key(plan_version_id,organization_id) references public.plan_versions(id,organization_id) on delete restrict,
 foreign key(meal_id,organization_id) references public.meals(id,organization_id) on delete restrict
);
create index meal_checkins_patient_date_idx on public.meal_checkins(patient_id,occurred_on desc);
create trigger meal_checkins_updated_at before update on public.meal_checkins for each row execute function private.set_updated_at();

create table public.adherence_alerts (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 patient_id uuid not null, checkin_id uuid, kind public.alert_kind not null, severity public.alert_severity not null,
 message text not null, status public.alert_status not null default 'open', detected_at timestamptz not null default now(),
 acknowledged_by uuid references public.profiles(id), acknowledged_at timestamptz, resolved_by uuid references public.profiles(id), resolved_at timestamptz,
 foreign key(patient_id,organization_id) references public.patients(id,organization_id) on delete cascade,
 foreign key(checkin_id,organization_id) references public.meal_checkins(id,organization_id) on delete set null(checkin_id)
);
create index adherence_alerts_org_status_idx on public.adherence_alerts(organization_id,status,detected_at desc);

create or replace function private.can_manage_patient_appointments(target_patient_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.patients p where p.id=target_patient_id and (p.patient_user_id=(select auth.uid()) or exists(select 1 from public.patient_guardians g where g.patient_id=p.id and g.guardian_user_id=(select auth.uid()) and g.can_manage_appointments)));
$$;
revoke all on function private.can_manage_patient_appointments(uuid) from public,anon;
grant execute on function private.can_manage_patient_appointments(uuid) to authenticated;

create or replace function private.guard_appointment_status()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if old.status is distinct from new.status and current_setting('bsnutri.appointment_rpc',true) is distinct from 'on' then raise exception 'Use o fluxo de agenda do BSNutri'; end if;
 return new;
end; $$;
create trigger appointments_status_guard before update on public.appointments for each row execute function private.guard_appointment_status();

create or replace function private.validate_checkin_chain()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.meals m join public.plan_days d on d.id=m.plan_day_id join public.plan_versions v on v.id=d.plan_version_id join public.plans p on p.current_published_version_id=v.id where m.id=new.meal_id and v.id=new.plan_version_id and p.patient_id=new.patient_id and p.organization_id=new.organization_id and p.status in('published','scheduled')) then raise exception 'Check-in deve pertencer ao plano vigente publicado'; end if;
 if new.created_by<>(select auth.uid()) then raise exception 'Autor inválido'; end if;
 return new;
end; $$;
create trigger checkins_validate before insert or update on public.meal_checkins for each row execute function private.validate_checkin_chain();

create or replace function private.create_checkin_alert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.reaction_suspected then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'allergy_or_reaction','urgent','Paciente sinalizou possível reação ou alergia.');
 elsif nullif(trim(coalesce(new.symptoms,'')),'') is not null then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'severe_symptom','attention','Paciente registrou sintomas no check-in.');
 elsif new.hunger_before>=9 then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'intense_hunger','attention','Paciente registrou fome intensa antes da refeição.'); end if;
 return new;
end; $$;
create trigger checkins_create_alert after insert on public.meal_checkins for each row execute function private.create_checkin_alert();

alter table public.rooms enable row level security; alter table public.appointments enable row level security;
alter table public.meal_checkins enable row level security; alter table public.adherence_alerts enable row level security;

create policy rooms_select_staff on public.rooms for select to authenticated using(private.has_organization_role(organization_id,array['owner','admin','nutritionist','receptionist','student']::public.organization_role[]));
create policy rooms_insert_admin on public.rooms for insert to authenticated with check(private.has_organization_role(organization_id,array['owner','admin','receptionist']::public.organization_role[]));
create policy rooms_update_admin on public.rooms for update to authenticated using(private.has_organization_role(organization_id,array['owner','admin','receptionist']::public.organization_role[])) with check(private.has_organization_role(organization_id,array['owner','admin','receptionist']::public.organization_role[]));
create policy rooms_delete_admin on public.rooms for delete to authenticated using(private.has_organization_role(organization_id,array['owner','admin','receptionist']::public.organization_role[]));

create policy appointments_select on public.appointments for select to authenticated using(private.has_organization_role(organization_id,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) or professional_id=(select auth.uid()) or private.can_manage_patient_appointments(patient_id));
create policy appointments_insert on public.appointments for insert to authenticated with check(status='requested' and requested_by=(select auth.uid()) and (private.has_organization_role(organization_id,array['owner','admin','nutritionist','receptionist','student']::public.organization_role[]) or private.can_manage_patient_appointments(patient_id)));
create policy appointments_update on public.appointments for update to authenticated using(private.has_organization_role(organization_id,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) or professional_id=(select auth.uid()) or private.can_manage_patient_appointments(patient_id)) with check(private.has_organization_role(organization_id,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) or professional_id=(select auth.uid()) or private.can_manage_patient_appointments(patient_id));

create policy checkins_select on public.meal_checkins for select to authenticated using(private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or private.can_access_patient(patient_id));
create policy checkins_insert_patient on public.meal_checkins for insert to authenticated with check(created_by=(select auth.uid()) and private.can_access_patient(patient_id));
create policy checkins_update_patient on public.meal_checkins for update to authenticated using(created_by=(select auth.uid()) and private.can_access_patient(patient_id) and created_at>now()-interval '24 hours') with check(created_by=(select auth.uid()) and private.can_access_patient(patient_id));
create policy alerts_select_clinical on public.adherence_alerts for select to authenticated using(private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy alerts_update_clinical on public.adherence_alerts for update to authenticated using(private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check(private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

create or replace function public.review_appointment(target_id uuid,target_status public.appointment_status,target_staff_note text default null,target_meeting_url text default null)
returns void language plpgsql security invoker set search_path='' as $$
declare target_org uuid;
begin
 perform set_config('bsnutri.appointment_rpc','on',true); select organization_id into target_org from public.appointments where id=target_id for update;
 if target_status not in('approved','rejected') then raise exception 'Decisão inválida'; end if;
 if not private.has_organization_role(target_org,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 update public.appointments set status=target_status,staff_note=target_staff_note,external_meeting_url=coalesce(target_meeting_url,external_meeting_url),reviewed_by=auth.uid(),reviewed_at=now() where id=target_id;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(target_org,auth.uid(),'appointment_'||target_status::text,'appointment',target_id,'{}');
end; $$;
create or replace function public.cancel_appointment(target_id uuid,reason text)
returns void language plpgsql security invoker set search_path='' as $$
declare row_data public.appointments%rowtype;
begin
 perform set_config('bsnutri.appointment_rpc','on',true); select * into row_data from public.appointments where id=target_id for update;
 if row_data.id is null or not(private.has_organization_role(row_data.organization_id,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) or private.can_manage_patient_appointments(row_data.patient_id)) then raise exception 'Acesso negado'; end if;
 if row_data.status in('completed','no_show','cancelled') then raise exception 'Agendamento não pode ser cancelado'; end if;
 update public.appointments set status='cancelled',cancellation_reason=reason where id=target_id;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(row_data.organization_id,auth.uid(),'appointment_cancelled','appointment',target_id,jsonb_build_object('reason',reason));
end; $$;
create or replace function public.update_alert_status(target_id uuid,target_status public.alert_status)
returns void language plpgsql security invoker set search_path='' as $$
declare target_org uuid;
begin
 select organization_id into target_org from public.adherence_alerts where id=target_id;
 if not private.has_organization_role(target_org,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 if target_status='acknowledged' then update public.adherence_alerts set status=target_status,acknowledged_by=auth.uid(),acknowledged_at=now() where id=target_id;
 elsif target_status='resolved' then update public.adherence_alerts set status=target_status,resolved_by=auth.uid(),resolved_at=now() where id=target_id;
 else raise exception 'Status inválido'; end if;
end; $$;
revoke all on function public.review_appointment(uuid,public.appointment_status,text,text),public.cancel_appointment(uuid,text),public.update_alert_status(uuid,public.alert_status) from public,anon;
grant execute on function public.review_appointment(uuid,public.appointment_status,text,text),public.cancel_appointment(uuid,text),public.update_alert_status(uuid,public.alert_status) to authenticated;
grant select,insert,update on public.rooms,public.appointments,public.meal_checkins,public.adherence_alerts to authenticated;
