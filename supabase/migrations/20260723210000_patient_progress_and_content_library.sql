create type public.patient_goal_kind as enum ('water','meals','weight','behavior');

create table public.patient_goals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  kind public.patient_goal_kind not null,
  title text not null check (char_length(trim(title)) between 2 and 160),
  target_value numeric,
  target_unit text,
  starts_on date not null default current_date,
  ends_on date,
  active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint patient_goals_patient_tenant_fkey foreign key (patient_id,organization_id) references public.patients(id,organization_id) on delete cascade,
  check (ends_on is null or ends_on >= starts_on)
);

create table public.patient_water_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  occurred_on date not null default current_date,
  amount_ml integer not null check (amount_ml between 1 and 10000),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint patient_water_logs_patient_tenant_fkey foreign key (patient_id,organization_id) references public.patients(id,organization_id) on delete cascade,
  unique (patient_id,occurred_on)
);

create table public.content_library_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 160),
  content_type text not null check (content_type in ('guidance','recipe','education','protocol')),
  tags text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.content_library_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid not null references public.content_library_items(id) on delete cascade,
  version_no integer not null,
  title text not null,
  body text not null check (char_length(trim(body)) between 2 and 12000),
  published_by uuid not null references public.profiles(id),
  published_at timestamptz not null default now(),
  unique (item_id,version_no)
);

create table public.patient_content_deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  content_version_id uuid not null references public.content_library_versions(id),
  snapshot jsonb not null,
  delivered_by uuid not null references public.profiles(id),
  delivered_at timestamptz not null default now(),
  constraint patient_content_deliveries_patient_tenant_fkey foreign key (patient_id,organization_id) references public.patients(id,organization_id) on delete cascade
);

create index patient_goals_patient_active_idx on public.patient_goals(patient_id,active,starts_on desc);
create index patient_water_logs_patient_day_idx on public.patient_water_logs(patient_id,occurred_on desc);
create index content_library_items_org_status_idx on public.content_library_items(organization_id,status,updated_at desc);
create index patient_content_deliveries_patient_idx on public.patient_content_deliveries(patient_id,delivered_at desc);

alter table public.patient_goals enable row level security;
alter table public.patient_water_logs enable row level security;
alter table public.content_library_items enable row level security;
alter table public.content_library_versions enable row level security;
alter table public.patient_content_deliveries enable row level security;

create policy patient_goals_clinical on public.patient_goals for all to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patient_goals_patient_select on public.patient_goals for select to authenticated using (private.can_access_patient(patient_id));

create policy patient_water_logs_clinical_select on public.patient_water_logs for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patient_water_logs_patient_select on public.patient_water_logs for select to authenticated using (private.can_access_patient(patient_id));
create policy patient_water_logs_patient_insert on public.patient_water_logs for insert to authenticated with check (created_by=(select auth.uid()) and private.can_access_patient(patient_id));
create policy patient_water_logs_patient_update on public.patient_water_logs for update to authenticated using (created_by=(select auth.uid()) and private.can_access_patient(patient_id)) with check (created_by=(select auth.uid()) and private.can_access_patient(patient_id));

create policy content_library_items_clinical on public.content_library_items for all to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy content_library_versions_clinical_select on public.content_library_versions for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy content_library_versions_clinical_insert on public.content_library_versions for insert to authenticated with check (published_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patient_content_deliveries_clinical on public.patient_content_deliveries for all to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (delivered_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patient_content_deliveries_patient_select on public.patient_content_deliveries for select to authenticated using (private.can_access_patient(patient_id));

create or replace function private.prevent_content_version_mutation()
returns trigger language plpgsql set search_path='' as $$ begin raise exception 'Versões publicadas de conteúdo são imutáveis'; end; $$;
create trigger content_library_versions_immutable before update or delete on public.content_library_versions for each row execute function private.prevent_content_version_mutation();

create or replace function public.publish_content_library_version(target_item_id uuid,target_body text)
returns public.content_library_versions language plpgsql security invoker set search_path='' as $$
declare item public.content_library_items; result public.content_library_versions;
begin
 select * into item from public.content_library_items where id=target_item_id;
 if item.id is null or not private.has_organization_role(item.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 insert into public.content_library_versions(organization_id,item_id,version_no,title,body,published_by)
 values(item.organization_id,item.id,(select coalesce(max(version_no),0)+1 from public.content_library_versions where item_id=item.id),item.title,nullif(trim(target_body),''),auth.uid()) returning * into result;
 update public.content_library_items set status='published',updated_at=now() where id=item.id;
 return result;
end; $$;

create or replace function public.deliver_content_to_patient(target_version_id uuid,target_patient_id uuid)
returns public.patient_content_deliveries language plpgsql security invoker set search_path='' as $$
declare version_row public.content_library_versions; patient_org uuid; result public.patient_content_deliveries;
begin
 select * into version_row from public.content_library_versions where id=target_version_id;
 select organization_id into patient_org from public.patients where id=target_patient_id;
 if version_row.id is null or patient_org<>version_row.organization_id or not private.has_organization_role(version_row.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 insert into public.patient_content_deliveries(organization_id,patient_id,content_version_id,snapshot,delivered_by)
 values(version_row.organization_id,target_patient_id,version_row.id,jsonb_build_object('title',version_row.title,'body',version_row.body,'content_type',(select content_type from public.content_library_items where id=version_row.item_id),'version',version_row.version_no),auth.uid()) returning * into result;
 return result;
end; $$;

create or replace function public.get_patient_weekly_summary(target_patient_id uuid,target_days integer default 7)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
  'period_days',greatest(1,least(target_days,31)),
  'meal_checkins',(select count(*) from public.meal_checkins where patient_id=target_patient_id and occurred_on>=current_date-greatest(1,least(target_days,31))+1),
  'completed_meals',(select count(*) from public.meal_checkins where patient_id=target_patient_id and occurred_on>=current_date-greatest(1,least(target_days,31))+1 and state='completed'),
  'water_ml',(select coalesce(sum(amount_ml),0) from public.patient_water_logs where patient_id=target_patient_id and occurred_on>=current_date-greatest(1,least(target_days,31))+1),
  'active_goals',(select count(*) from public.patient_goals where patient_id=target_patient_id and active and starts_on<=current_date and coalesce(ends_on,current_date)>=current_date)
 )
 where private.can_access_patient(target_patient_id) or exists(select 1 from public.patients p where p.id=target_patient_id and private.has_organization_role(p.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
$$;

grant select,insert,update,delete on public.patient_goals,public.patient_water_logs,public.content_library_items,public.content_library_versions,public.patient_content_deliveries to authenticated;
grant execute on function public.publish_content_library_version(uuid,text),public.deliver_content_to_patient(uuid,uuid),public.get_patient_weekly_summary(uuid,integer) to authenticated;
