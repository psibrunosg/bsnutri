alter policy foods_insert_clinical on public.foods
with check (organization_id is not null and created_by = (select auth.uid()) and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

alter policy food_values_insert_custom on public.food_nutrient_values
with check (exists (select 1 from public.foods f where f.id = food_id and f.organization_id is not null and f.created_by = (select auth.uid()) and private.is_active_member(f.organization_id)));

alter policy plans_insert_clinical on public.plans
with check (created_by = (select auth.uid()) and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

alter policy versions_clinical on public.plan_versions
using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (created_by = (select auth.uid()) and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
