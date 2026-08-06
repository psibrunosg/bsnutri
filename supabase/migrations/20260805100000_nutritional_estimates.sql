create table public.nutritional_estimates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  protocol text not null check (protocol in ('harris_benedict', 'mifflin_st_jeor', 'eer_iom', 'tinsley')),
  current_weight_kg numeric not null check (current_weight_kg > 0),
  height_cm numeric not null check (height_cm > 0),
  age_years integer not null check (age_years >= 0),
  biological_sex text not null check (biological_sex in ('female', 'male')),
  activity_factor numeric not null check (activity_factor >= 1),
  basal_metabolic_rate numeric not null check (basal_metabolic_rate >= 0),
  total_energy_expenditure numeric not null check (total_energy_expenditure >= 0),
  calculated_on timestamptz not null default now(),
  notes text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint nutritional_estimates_patient_tenant_fkey
    foreign key (patient_id, organization_id)
    references public.patients(id, organization_id) on delete cascade
);

create index nutritional_estimates_patient_calculated_idx on public.nutritional_estimates(patient_id, calculated_on desc);

alter table public.nutritional_estimates enable row level security;

grant select, insert, update, delete on public.nutritional_estimates to authenticated;

create policy nutritional_estimates_select_clinical_team on public.nutritional_estimates for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

create policy nutritional_estimates_insert_clinical_team on public.nutritional_estimates for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and created_by = (select auth.uid())
);

create policy nutritional_estimates_update_clinical_team on public.nutritional_estimates for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

create policy nutritional_estimates_delete_admin_or_nutritionist on public.nutritional_estimates for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));
