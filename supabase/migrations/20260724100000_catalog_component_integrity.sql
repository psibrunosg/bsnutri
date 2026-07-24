create or replace function private.validate_food_component_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_organization_id uuid;
  parent_kind public.catalog_kind;
  component_organization_id uuid;
begin
  select organization_id, catalog_kind
    into parent_organization_id, parent_kind
  from public.foods
  where id = new.parent_food_id;

  select organization_id
    into component_organization_id
  from public.foods
  where id = new.component_food_id;

  if parent_organization_id is distinct from new.organization_id
    or parent_kind not in ('preparation', 'combination')
    or (component_organization_id is not null and component_organization_id <> new.organization_id) then
    raise exception 'Componente não pertence ao catálogo permitido';
  end if;

  if exists (
    with recursive descendants(id) as (
      select component_food_id
      from public.food_components
      where parent_food_id = new.component_food_id
        and (tg_op <> 'UPDATE' or (parent_food_id, component_food_id) <> (old.parent_food_id, old.component_food_id))
      union
      select component.component_food_id
      from public.food_components component
      join descendants on descendants.id = component.parent_food_id
      where tg_op <> 'UPDATE' or (component.parent_food_id, component.component_food_id) <> (old.parent_food_id, old.component_food_id)
    )
    select 1 from descendants where id = new.parent_food_id
  ) then
    raise exception 'Componentes do catálogo não podem formar ciclos';
  end if;

  return new;
end;
$$;

create trigger food_components_validate_integrity
before insert or update of parent_food_id, component_food_id, organization_id
on public.food_components
for each row execute function private.validate_food_component_integrity();
