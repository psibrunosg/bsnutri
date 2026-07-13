revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

drop policy memberships_manage_admin on public.memberships;
create policy memberships_insert_admin_or_bootstrap on public.memberships for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[])
  or (
    user_id = (select auth.uid())
    and role = 'owner'
    and exists (
      select 1 from public.organizations o
      where o.id = memberships.organization_id and o.created_by = (select auth.uid())
    )
  )
);
drop policy memberships_bootstrap_owner on public.memberships;
create policy memberships_update_admin on public.memberships for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[]));
create policy memberships_delete_admin on public.memberships for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin']::public.organization_role[]));

drop policy patients_manage_clinical_team on public.patients;
create policy patients_insert_clinical_team on public.patients for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and created_by = (select auth.uid())
);
create policy patients_update_clinical_team on public.patients for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy patients_delete_admin_or_nutritionist on public.patients for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));

drop policy guardians_manage_clinical_team on public.patient_guardians;
create policy guardians_insert_clinical_team on public.patient_guardians for insert to authenticated
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));
create policy guardians_update_clinical_team on public.patient_guardians for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));
create policy guardians_delete_clinical_team on public.patient_guardians for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));

drop policy assessments_manage_clinical_team on public.assessments;
create policy assessments_insert_clinical_team on public.assessments for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and professional_id = (select auth.uid())
);
create policy assessments_update_clinical_team on public.assessments for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy assessments_delete_admin_or_nutritionist on public.assessments for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));

drop policy anthropometry_manage_clinical_team on public.anthropometry;
create policy anthropometry_insert_clinical_team on public.anthropometry for insert to authenticated
with check (
  public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and created_by = (select auth.uid())
);
create policy anthropometry_update_clinical_team on public.anthropometry for update to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (public.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy anthropometry_delete_admin_or_nutritionist on public.anthropometry for delete to authenticated
using (public.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[]));
