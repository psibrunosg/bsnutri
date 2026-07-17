create table public.meal_checkin_photos (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  meal_checkin_id uuid not null,
  meal_id uuid not null,
  occurred_on date not null,
  drive_file_id text not null check (char_length(trim(drive_file_id)) > 3),
  drive_web_url text,
  file_name text not null check (char_length(trim(file_name)) between 6 and 180),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  unique (meal_checkin_id),
  foreign key (patient_id, organization_id) references public.patients(id, organization_id) on delete cascade,
  foreign key (meal_checkin_id, organization_id) references public.meal_checkins(id, organization_id) on delete cascade,
  foreign key (meal_id, organization_id) references public.meals(id, organization_id) on delete restrict
);

alter table public.meal_checkin_photos enable row level security;

create policy checkin_photos_select on public.meal_checkin_photos for select to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or private.can_access_patient(patient_id));

create policy checkin_photos_insert_patient on public.meal_checkin_photos for insert to authenticated
with check (created_by=(select auth.uid()) and private.can_access_patient(patient_id));

grant select, insert on public.meal_checkin_photos to authenticated;
