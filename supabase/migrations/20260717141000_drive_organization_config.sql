create type public.drive_connection_status as enum ('missing','connected');

create table public.organization_drive_configs (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  status public.drive_connection_status not null default 'missing',
  root_folder_id text,
  connected_by uuid references public.profiles(id),
  connected_at timestamptz,
  updated_at timestamptz not null default now(),
  check ((status='missing' and root_folder_id is null) or (status='connected' and nullif(trim(root_folder_id),'') is not null))
);

create trigger drive_configs_updated_at before update on public.organization_drive_configs
for each row execute function private.set_updated_at();

alter table public.organization_drive_configs enable row level security;

create policy drive_configs_select_clinical on public.organization_drive_configs for select to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

create policy drive_configs_upsert_admin on public.organization_drive_configs for insert to authenticated
with check (private.has_organization_role(organization_id,array['owner','admin']::public.organization_role[]));

create policy drive_configs_update_admin on public.organization_drive_configs for update to authenticated
using (private.has_organization_role(organization_id,array['owner','admin']::public.organization_role[]))
with check (private.has_organization_role(organization_id,array['owner','admin']::public.organization_role[]));

grant select, insert, update on public.organization_drive_configs to authenticated;

create or replace function public.get_patient_drive_status(target_patient_id uuid)
returns table(status public.drive_connection_status, can_upload_photos boolean)
language plpgsql stable security definer set search_path='' as $$
declare target_org uuid;
begin
  if not private.can_access_patient(target_patient_id) then raise exception 'Acesso negado'; end if;
  select organization_id into target_org from public.patients where id=target_patient_id;
  return query
  select coalesce(c.status,'missing'::public.drive_connection_status), coalesce(c.status='connected',false)
  from (select target_org organization_id) o
  left join public.organization_drive_configs c on c.organization_id=o.organization_id;
end;
$$;

revoke all on function public.get_patient_drive_status(uuid) from public,anon;
grant execute on function public.get_patient_drive_status(uuid) to authenticated;
