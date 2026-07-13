create extension if not exists pgcrypto;

create type public.organization_role as enum ('owner', 'admin', 'nutritionist', 'student', 'receptionist');
create type public.membership_status as enum ('invited', 'active', 'suspended');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) between 2 and 120),
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.organization_role not null,
  status public.membership_status not null default 'active',
  supervisor_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id),
  check (role = 'student' or supervisor_id is null),
  check (supervisor_id is null or supervisor_id <> user_id)
);

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  professional_id uuid not null references public.profiles(id),
  anonymous_code text not null,
  full_name text not null check (char_length(trim(full_name)) between 2 and 160),
  birth_date date,
  email text,
  phone text,
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, anonymous_code)
);

create table public.patient_guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  guardian_user_id uuid not null references public.profiles(id) on delete cascade,
  relationship text not null,
  can_view_plan boolean not null default true,
  can_manage_appointments boolean not null default true,
  created_at timestamptz not null default now(),
  unique (patient_id, guardian_user_id)
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  professional_id uuid not null references public.profiles(id),
  assessed_at timestamptz not null default now(),
  objective text,
  food_preferences text,
  food_restrictions text,
  allergies text,
  clinical_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.anthropometry (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  assessment_id uuid references public.assessments(id) on delete set null,
  measured_at timestamptz not null default now(),
  weight_kg numeric(7,3) check (weight_kg > 0),
  height_cm numeric(6,2) check (height_cm > 0),
  body_fat_percent numeric(5,2) check (body_fat_percent between 0 and 100),
  waist_cm numeric(6,2) check (waist_cm > 0),
  notes text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index memberships_user_idx on public.memberships(user_id, status);
create index patients_org_idx on public.patients(organization_id, status);
create index patients_professional_idx on public.patients(professional_id);
create index assessments_patient_idx on public.assessments(patient_id, assessed_at desc);
create index anthropometry_patient_idx on public.anthropometry(patient_id, measured_at desc);
create index audit_events_org_idx on public.audit_events(organization_id, created_at desc);

create or replace function public.is_active_member(target_organization_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create or replace function public.has_organization_role(
  target_organization_id uuid,
  allowed_roles public.organization_role[]
)
returns boolean
language sql
stable
security invoker
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

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.memberships enable row level security;
alter table public.patients enable row level security;
alter table public.patient_guardians enable row level security;
alter table public.assessments enable row level security;
alter table public.anthropometry enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_select_self_or_colleague on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1 from public.memberships mine
    join public.memberships theirs on theirs.organization_id = mine.organization_id
    where mine.user_id = (select auth.uid()) and mine.status = 'active' and theirs.user_id = profiles.id
  )
);
create policy profiles_update_self on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy profiles_insert_self on public.profiles for insert to authenticated
with check (id = (select auth.uid()));

create policy organizations_select_member on public.organizations for select to authenticated
using (public.is_active_member(id));
create policy organizations_insert_authenticated on public.organizations for insert to authenticated
with check (created_by = (select auth.uid()));
create policy organizations_update_admin on public.organizations for update to authenticated
using (public.has_organization_role(id, array['owner','admin']::public.organization_role[]))
with check (public.has_organization_role(id, array['owner','admin']::public.organization_role[]));

create policy memberships_select_member on public.memberships for select to authenticated
using (public.is_active_member(organization_id));
create policy memberships_manage_admin on public.memberships for all to authenticated
using (public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[]));
create policy memberships_bootstrap_owner on public.memberships for insert to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and exists (
    select 1 from public.organizations o
    where o.id = memberships.organization_id and o.created_by = (select auth.uid())
  )
);

create policy patients_select_clinical_team on public.patients for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patients_manage_clinical_team on public.patients for all to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and created_by = (select auth.uid())
);

create policy guardians_select_clinical_or_self on public.patient_guardians for select to authenticated
using (
  guardian_user_id = (select auth.uid())
  or public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
);
create policy guardians_manage_clinical_team on public.patient_guardians for all to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));

create policy assessments_select_clinical_team on public.assessments for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy assessments_manage_clinical_team on public.assessments for all to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and professional_id = (select auth.uid())
);

create policy anthropometry_select_clinical_team on public.anthropometry for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy anthropometry_manage_clinical_team on public.anthropometry for all to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and created_by = (select auth.uid())
);

create policy audit_select_admin on public.audit_events for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[]));
create policy audit_insert_member on public.audit_events for insert to authenticated
with check (actor_id = (select auth.uid()) and public.is_active_member(organization_id));

grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.organizations to authenticated;
grant select, insert, update, delete on public.memberships to authenticated;
grant select, insert, update, delete on public.patients to authenticated;
grant select, insert, update, delete on public.patient_guardians to authenticated;
grant select, insert, update, delete on public.assessments to authenticated;
grant select, insert, update, delete on public.anthropometry to authenticated;
grant select, insert on public.audit_events to authenticated;
grant usage, select on sequence public.audit_events_id_seq to authenticated;
grant execute on function public.is_active_member(uuid) to authenticated;
grant execute on function public.has_organization_role(uuid, public.organization_role[]) to authenticated;
