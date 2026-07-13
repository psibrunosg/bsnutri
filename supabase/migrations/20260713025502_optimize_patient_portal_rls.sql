alter policy patients_select_clinical_team on public.patients
using (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or patient_user_id = (select auth.uid())
  or (patient_user_id is null and lower(coalesce(email,'')) = lower(coalesce(((select auth.jwt())->>'email'),'')))
);

alter policy patients_update_clinical_team on public.patients
using (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or (patient_user_id is null and lower(coalesce(email,'')) = lower(coalesce(((select auth.jwt())->>'email'),'')))
)
with check (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or patient_user_id = (select auth.uid())
);
