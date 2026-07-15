create table public.patient_consents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  consent_type text not null check (consent_type in ('care', 'data_processing', 'guardian')),
  document_version text not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  recorded_by uuid not null references public.profiles(id),
  notes text,
  created_at timestamptz not null default now(),
  constraint patient_consents_patient_tenant_fkey
    foreign key (patient_id, organization_id)
    references public.patients(id, organization_id) on delete cascade,
  check (revoked_at is null or revoked_at >= granted_at)
);

create table public.lab_results (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  assessment_id uuid,
  collected_on date not null,
  test_name text not null check (char_length(trim(test_name)) between 2 and 160),
  result_value numeric,
  unit text,
  reference_range text,
  notes text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint lab_results_patient_tenant_fkey
    foreign key (patient_id, organization_id)
    references public.patients(id, organization_id) on delete cascade,
  constraint lab_results_assessment_tenant_fkey
    foreign key (assessment_id, organization_id)
    references public.assessments(id, organization_id) on delete set null
);

create index patient_consents_active_idx on public.patient_consents(patient_id, granted_at desc) where revoked_at is null;
create index lab_results_patient_collected_idx on public.lab_results(patient_id, collected_on desc);

alter table public.patient_consents enable row level security;
alter table public.lab_results enable row level security;

grant select, insert, update, delete on public.patient_consents to authenticated;
grant select, insert, update, delete on public.lab_results to authenticated;

create policy patient_consents_select_clinical_team on public.patient_consents for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patient_consents_insert_clinical_team on public.patient_consents for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and recorded_by = (select auth.uid())
);
create policy patient_consents_update_clinical_team on public.patient_consents for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patient_consents_delete_admin_or_nutritionist on public.patient_consents for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));

create policy lab_results_select_clinical_team on public.lab_results for select to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy lab_results_insert_clinical_team on public.lab_results for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and created_by = (select auth.uid())
);
create policy lab_results_update_clinical_team on public.lab_results for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy lab_results_delete_admin_or_nutritionist on public.lab_results for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));
