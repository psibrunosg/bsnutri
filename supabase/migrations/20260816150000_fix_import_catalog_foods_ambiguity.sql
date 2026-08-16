-- `import_catalog_foods` declara `returns table (id uuid, name text)`, o que cria as
-- variáveis `id` e `name` no corpo da função. As consultas internas referenciavam
-- `id` e `name` sem qualificação, então toda importação falhava com
-- "column reference \"id\" is ambiguous" antes de gravar qualquer item.
--
-- Esta migration mantém o comportamento e apenas qualifica as referências.

create or replace function public.import_catalog_foods(
  target_organization_id uuid,
  target_source_id uuid,
  target_items jsonb
)
returns table (id uuid, name text)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  source_version text;
  item record;
  new_food_id uuid;
  inserted_values integer;
begin
  if not private.has_organization_role(target_organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Sem permissão para importar itens neste catálogo';
  end if;
  if jsonb_typeof(target_items) <> 'array' or jsonb_array_length(target_items) = 0 or jsonb_array_length(target_items) > 100 then
    raise exception 'A importação deve conter entre 1 e 100 itens';
  end if;

  select source.dataset_version into source_version
    from public.food_sources source
   where source.id = target_source_id;
  if not found then raise exception 'Fonte de dados inválida'; end if;

  if exists (
    select 1 from jsonb_to_recordset(target_items) as input(name text, preparation_state text, energy_kcal numeric, protein_g numeric, carbohydrate_g numeric, fat_g numeric)
    where char_length(trim(coalesce(input.name,''))) not between 2 and 180
      or input.energy_kcal is null or input.protein_g is null or input.carbohydrate_g is null or input.fat_g is null
      or input.energy_kcal < 0 or input.protein_g < 0 or input.carbohydrate_g < 0 or input.fat_g < 0
  ) then raise exception 'A importação contém dados nutricionais inválidos'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(target_items) as input(name text, preparation_state text, energy_kcal numeric, protein_g numeric, carbohydrate_g numeric, fat_g numeric)
    group by lower(trim(input.name)), lower(coalesce(nullif(trim(input.preparation_state),''),'unspecified'))
    having count(*) > 1
  ) then raise exception 'A importação contém itens duplicados'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(target_items) as input(name text, preparation_state text, energy_kcal numeric, protein_g numeric, carbohydrate_g numeric, fat_g numeric)
    join public.foods food on food.organization_id = target_organization_id
      and lower(food.name) = lower(trim(input.name))
      and food.preparation_state = coalesce(nullif(trim(input.preparation_state),''),'unspecified')
  ) then raise exception 'Um ou mais itens já existem neste catálogo'; end if;

  for item in
    select trim(input.name) as name,
           coalesce(nullif(trim(input.preparation_state),''),'unspecified') as preparation_state,
           input.energy_kcal, input.protein_g, input.carbohydrate_g, input.fat_g
    from jsonb_to_recordset(target_items) as input(name text, preparation_state text, energy_kcal numeric, protein_g numeric, carbohydrate_g numeric, fat_g numeric)
  loop
    insert into public.foods (organization_id,source_id,name,preparation_state,catalog_kind,source_reference,source_accessed_on,review_status,created_by)
    values (target_organization_id,target_source_id,item.name,item.preparation_state,'food','Importação de catálogo',current_date,'pending_review',auth.uid())
    returning foods.id into new_food_id;

    insert into public.food_nutrient_values (food_id,nutrient_id,amount_per_100g,data_version)
    select new_food_id,nutrient.id,value.amount,source_version
    from (values ('energy_kcal'::text,item.energy_kcal),('protein_g'::text,item.protein_g),('carbohydrate_g'::text,item.carbohydrate_g),('fat_g'::text,item.fat_g)) as value(code,amount)
    join public.nutrients nutrient on nutrient.code = value.code;
    get diagnostics inserted_values = row_count;
    if inserted_values <> 4 then raise exception 'Definições nutricionais obrigatórias não estão disponíveis'; end if;

    return query select new_food_id, item.name;
  end loop;
end;
$$;

revoke execute on function public.import_catalog_foods(uuid,uuid,jsonb) from public, anon;
grant execute on function public.import_catalog_foods(uuid,uuid,jsonb) to authenticated;
