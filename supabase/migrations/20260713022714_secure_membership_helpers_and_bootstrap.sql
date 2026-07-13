create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_active_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create or replace function private.has_organization_role(
  target_organization_id uuid,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role = any(allowed_roles)
  );
$$;

revoke all on function private.is_active_member(uuid) from public, anon;
revoke all on function private.has_organization_role(uuid, public.organization_role[]) from public, anon;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.has_organization_role(uuid, public.organization_role[]) to authenticated;

create or replace function public.is_active_member(target_organization_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select private.is_active_member(target_organization_id); $$;

create or replace function public.has_organization_role(
  target_organization_id uuid,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select private.has_organization_role(target_organization_id, allowed_roles); $$;

create or replace function public.bootstrap_organization(
  full_name_input text,
  organization_name_input text,
  organization_slug_input text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  new_organization_id uuid;
begin
  if current_user_id is null then
    raise exception 'Autenticação obrigatória';
  end if;
  if char_length(trim(full_name_input)) < 2 then
    raise exception 'Nome completo inválido';
  end if;
  if char_length(trim(organization_name_input)) < 2 then
    raise exception 'Nome da clínica inválido';
  end if;
  if organization_slug_input !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Identificador da clínica inválido';
  end if;
  if exists (select 1 from public.memberships where user_id = current_user_id and status = 'active') then
    raise exception 'Usuário já possui uma organização ativa';
  end if;

  insert into public.profiles (id, full_name)
  values (current_user_id, trim(full_name_input))
  on conflict (id) do update set full_name = excluded.full_name, updated_at = now();

  insert into public.organizations (name, slug, created_by)
  values (trim(organization_name_input), organization_slug_input, current_user_id)
  returning id into new_organization_id;

  insert into public.memberships (organization_id, user_id, role, status)
  values (new_organization_id, current_user_id, 'owner', 'active');

  return new_organization_id;
end;
$$;

revoke all on function public.bootstrap_organization(text, text, text) from public, anon;
grant execute on function public.bootstrap_organization(text, text, text) to authenticated;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function private.set_updated_at();
create trigger organizations_set_updated_at before update on public.organizations
for each row execute function private.set_updated_at();
create trigger memberships_set_updated_at before update on public.memberships
for each row execute function private.set_updated_at();
create trigger patients_set_updated_at before update on public.patients
for each row execute function private.set_updated_at();
create trigger assessments_set_updated_at before update on public.assessments
for each row execute function private.set_updated_at();

alter table public.patients add constraint patients_id_organization_unique unique (id, organization_id);
alter table public.assessments add constraint assessments_id_organization_unique unique (id, organization_id);

alter table public.patient_guardians drop constraint patient_guardians_patient_id_fkey;
alter table public.patient_guardians add constraint patient_guardians_patient_tenant_fkey
foreign key (patient_id, organization_id) references public.patients(id, organization_id) on delete cascade;

alter table public.assessments drop constraint assessments_patient_id_fkey;
alter table public.assessments add constraint assessments_patient_tenant_fkey
foreign key (patient_id, organization_id) references public.patients(id, organization_id) on delete cascade;

alter table public.anthropometry drop constraint anthropometry_patient_id_fkey;
alter table public.anthropometry add constraint anthropometry_patient_tenant_fkey
foreign key (patient_id, organization_id) references public.patients(id, organization_id) on delete cascade;

alter table public.anthropometry drop constraint anthropometry_assessment_id_fkey;
alter table public.anthropometry add constraint anthropometry_assessment_tenant_fkey
foreign key (assessment_id, organization_id) references public.assessments(id, organization_id) on delete set null (assessment_id);
