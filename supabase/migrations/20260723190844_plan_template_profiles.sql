create type public.plan_template_scope as enum ('personal','organization');

alter table public.plan_templates
  add column scope public.plan_template_scope not null default 'organization',
  add column dimensions jsonb not null default '{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":[]}'::jsonb,
  add column rules jsonb not null default '{"targets":{},"guidance":[]}'::jsonb;

drop policy plan_templates_clinical on public.plan_templates;
create policy plan_templates_clinical on public.plan_templates for all to authenticated
using (
  private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
  and (scope='organization' or created_by=(select auth.uid()))
)
with check (
  created_by=(select auth.uid())
  and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
  and scope in ('personal','organization')
);

create or replace function public.create_plan_template_from_plan_v2(target_plan_id uuid,target_name text,target_scope public.plan_template_scope default 'personal',target_dimensions jsonb default '{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":[]}'::jsonb,target_rules jsonb default '{"targets":{},"guidance":[]}'::jsonb)
returns public.plan_templates language plpgsql security invoker set search_path='' as $$
declare p public.plans; snapshot jsonb; result public.plan_templates;
begin
  select * into p from public.plans where id=target_plan_id;
  if p.id is null or not private.has_organization_role(p.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
  select jsonb_build_object('versions',coalesce(jsonb_agg(to_jsonb(v) order by v.version_no),'[]'::jsonb)) into snapshot from public.plan_versions v where v.plan_id=p.id;
  insert into public.plan_templates(organization_id,source_plan_id,name,objective,tags,snapshot,created_by,scope,dimensions,rules)
  values(p.organization_id,p.id,nullif(trim(target_name),''),nullif(trim(coalesce(target_dimensions->'objectives'->>0,'')),''),array(select jsonb_array_elements_text(coalesce(target_dimensions->'approaches','[]'::jsonb))),snapshot,auth.uid(),target_scope,coalesce(target_dimensions,'{}'::jsonb),coalesce(target_rules,'{}'::jsonb))
  returning * into result;
  return result;
end; $$;

create or replace function public.apply_plan_template_to_patient(target_template_id uuid,target_patient_id uuid)
returns public.plans language plpgsql security invoker set search_path='' as $$
declare result public.plans; target_values jsonb;
begin
  select rules->'targets' into target_values from public.plan_templates where id=target_template_id;
  select public.copy_plan_template_to_patient(target_template_id,target_patient_id) into result;
  update public.plan_versions set targets=coalesce(target_values,targets),change_summary='Proposta criada a partir de modelo' where plan_id=result.id and version_no=1;
  return result;
end; $$;

grant execute on function public.create_plan_template_from_plan_v2(uuid,text,public.plan_template_scope,jsonb,jsonb),public.apply_plan_template_to_patient(uuid,uuid) to authenticated;
