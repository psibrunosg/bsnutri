-- Função que carrega os 8 modelos de prática dietética (docs/seed/praticas-dieteticas.json) numa
-- clínica. catalog_key correlaciona cada modelo com foods.diet_tags (mesmo approach), permitindo à
-- UI filtrar os alimentos do modelo (foods.diet_tags && array[catalog_key]) assim que o modelo é
-- selecionado/carregado. Idempotente via unique index (organization_id, catalog_key).

create or replace function public.seed_practicas_dieteticas(
  target_organization_id uuid,
  target_created_by uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(auth.uid(), target_created_by);
begin
  if auth.uid() is not null and not private.has_organization_role(target_organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado';
  end if;
  if actor is null then
    raise exception 'created_by obrigatório';
  end if;

  insert into public.plan_templates (
    organization_id, name, objective, tags, snapshot, created_by, scope, dimensions, rules, catalog_key
  )
  values
  (
    target_organization_id,
    'Dieta Mediterrânea',
    'Prevenção cardiovascular e saúde cardiometabólica',
    array['mediterranean','cardiovascular','plant_forward'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["mediterranean"],"objectives":["cardiovascular_prevention","cardiometabolic_health"],"restrictions":[],"preferences":["plant_forward","olive_oil","fish","legumes"],"contexts":["outpatient","clinical","prevention"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado por gasto energético"},"protein_pct":{"min":15,"max":20},"carbohydrate_pct":{"min":45,"max":55},"fat_pct":{"min":25,"max":35},"saturated_fat_pct":{"max":7},"fiber_g":{"min":25},"sodium_mg":{"max":2300},"fish_servings_week":{"min":2},"olive_oil":"principal_fonte_gordura","red_meat_servings_month":{"max":4}},"guidance":["Basear alimentação em alimentos in natura e minimamente processados de origem vegetal","Usar azeite de oliva extravirgem como principal gordura adicionada","Consumir peixe 2+ vezes por semana","Leguminosas (feijão, lentilha, grão-de-bico) 4+ vezes por semana","Frutas e vegetais em abundância, variando cores","Castanhas e sementes diariamente (30g)","Cereais integrais como base (arroz integral, aveia, pão integral)","Limitar carnes vermelhas a <4 vezes/mês","Vinho tinto opcional e moderado se apropriado","Evitar ultraprocessados, açúcar refinado e gorduras saturadas em excesso"]}
    $rules$::jsonb,
    'mediterranean'
  ),
  (
    target_organization_id,
    'Dieta DASH',
    'Redução da pressão arterial e saúde cardiovascular',
    array['dash','hypertension','low_sodium'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["dash"],"objectives":["hypertension_control","cardiovascular_prevention"],"restrictions":["low_sodium"],"preferences":["fruits","vegetables","low_fat_dairy","whole_grains"],"contexts":["outpatient","clinical","hypertension"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado"},"protein_pct":{"min":18,"max":20},"carbohydrate_pct":{"min":50,"max":55},"fat_pct":{"min":25,"max":30},"saturated_fat_pct":{"max":6},"fiber_g":{"min":30},"sodium_mg":{"max":2300,"lower_variant":1500},"potassium_mg":{"min":4700},"calcium_mg":{"min":1250},"magnesium_mg":{"min":500},"added_sugars_pct":{"max":5}},"guidance":["Alvos base: 2000 kcal/dia, 2300mg sódio (versão baixa: 1500mg)","Grãos integrais 6-8 porções/dia (arroz integral, pão integral, aveia)","Frutas 4-5 porções/dia","Vegetais 4-5 porções/dia","Laticínios desnatados 2-3 porções/dia","Carnes magras 150g/dia (frango, peixe, cortes bovinos magros)","Castanhas, sementes e leguminosas 4-5 porções/semana","Gorduras e óleos 2-3 porções/dia (azeite, canola)","Doces <5 porções/semana","Reduzir sódio: evitar embutidos, enlatados com sal, fast food, ultraprocessados"]}
    $rules$::jsonb,
    'dash'
  ),
  (
    target_organization_id,
    'Dieta MIND',
    'Neuroproteção e redução de risco de demência',
    array['mind','neuroprotection','brain_health'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["mind"],"objectives":["neuroprotection","cognitive_health"],"restrictions":[],"preferences":["leafy_greens","berries","nuts","olive_oil","fish"],"contexts":["outpatient","prevention","elderly"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado"},"protein_pct":{"min":15,"max":20},"carbohydrate_pct":{"min":45,"max":55},"fat_pct":{"min":25,"max":35},"leafy_greens_servings_week":{"min":6},"berries_servings_week":{"min":2},"nuts_servings_week":{"min":5},"beans_servings_week":{"min":4},"whole_grains_servings_day":{"min":3},"poultry_meals_week":{"min":2},"fish_meals_week":{"min":1},"red_meat_servings_week":{"max":3},"cheese_servings_week":{"max":1},"butter_tablespoons_day":{"max":1},"fried_foods_servings_week":{"max":1},"pastries_sweets_servings_week":{"max":4}},"guidance":["Combina Mediterrânea + DASH com foco em alimentos neuroprotetores","Vegetais folhosos verde-escuros 6+ porções/semana (couve, espinafre, rúcula, agrião)","Frutas vermelhas 2+ porções/semana (mirtilo, morango, amora, framboesa)","Castanhas 5+ porções/semana (30g cada)","Feijão/leguminosas 4+ refeições/semana","Cereais integrais 3+ porções/dia","Frango 2+ refeições/semana","Peixe 1+ refeição/semana","Azeite de oliva como principal gordura","Limitar carne vermelha <3/semana, queijo <1/semana, manteiga <1 colher/dia","Limitar frituras <1/semana, doces <4/semana"]}
    $rules$::jsonb,
    'mind'
  ),
  (
    target_organization_id,
    'Dieta Cetogênica',
    'Cetose nutricional — controle glicêmico em Diabetes tipo 2 selecionado e epilepsia',
    array['ketogenic','low_carb','high_fat'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["ketogenic"],"objectives":["glycemic_control","epilepsy_management","short_term_weight_loss"],"restrictions":["very_low_carb"],"preferences":["high_fat","moderate_protein"],"contexts":["outpatient","clinical","monitored"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado"},"protein_pct":{"min":15,"max":20},"carbohydrate_g":{"max":50},"carbohydrate_pct":{"min":5,"max":10},"fat_pct":{"min":70,"max":80},"fiber_g":{"min":15,"notes":"De vegetais baixo carboidrato"},"net_carbs_g":{"max":30}},"guidance":["Cetose nutricional: 20-50g carboidrato/dia (líquidos: total - fibra)","Gordura 70-80% do VET (abacate, azeite, óleo de coco, castanhas, manteiga)","Proteína moderada 15-20% (carnes, ovos, peixe, frango)","Vegetais não amiláceos à vontade (folhosos, brócolis, abobrinha, couve-flor)","Evitar grãos, açúcar, tubérculos, frutas ricas em carboidrato, leguminosas","Monitorar cetonas e glicemia","Suplementar eletrólitos (sódio, potássio, magnésio)","Acompanhar perfil lipídico","Não indicado para gestantes, lactantes, distúrbios beta-oxidativos, sem supervisão"]}
    $rules$::jsonb,
    'ketogenic'
  ),
  (
    target_organization_id,
    'Dieta Low Carb',
    'Redução moderada de carboidratos — controle glicêmico e perda de peso',
    array['low_carb','moderate_carb_restriction'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["low_carb"],"objectives":["glycemic_control","weight_loss"],"restrictions":["reduced_carb"],"preferences":["protein","healthy_fats","non_starchy_vegetables"],"contexts":["outpatient","clinical"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado"},"protein_pct":{"min":20,"max":30},"carbohydrate_pct":{"min":15,"max":30},"fat_pct":{"min":40,"max":55},"carbohydrate_g":{"min":50,"max":130},"fiber_g":{"min":20}},"guidance":["50-130g de carboidrato/dia (20-30% VET)","Proteína 20-30% VET (carnes, peixes, ovos, laticínios, tofu)","Gorduras 40-55% VET (azeite, abacate, castanhas, óleo de coco moderado)","Vegetais não amiláceos à vontade","Tubérculos em pequenas porções","Frutas com moderação — evitar sucos","Evitar açúcar, ultraprocessados, pães brancos, massas, refrigerante","Leguminosas permitidas em pequenas porções","Não requer cetose nem monitoração de cetonas"]}
    $rules$::jsonb,
    'low_carb'
  ),
  (
    target_organization_id,
    'Dieta Vegana',
    'Padrão 100% vegetal — ética/saúde/sustentabilidade',
    array['vegan','plant_based','no_animal'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["vegan"],"objectives":["general_health","cardiovascular_prevention","ethical_environmental"],"restrictions":["no_meat","no_dairy","no_eggs","no_honey","no_animal_products"],"preferences":["whole_plant_foods"],"contexts":["outpatient","lifestyle"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado"},"protein_pct":{"min":12,"max":18},"carbohydrate_pct":{"min":50,"max":65},"fat_pct":{"min":20,"max":35},"fiber_g":{"min":30},"calcium_mg":{"min":1000,"notes":"De vegetais/leite vegetal fortificado"},"vitamin_b12_mcg":{"min":2.4,"notes":"Suplementação obrigatória"}},"guidance":["Exclui TODOS produtos de origem animal (carne, peixe, laticínios, ovos, mel)","Suplementar vitamina B12 obrigatoriamente","Combinar fontes vegetais de ferro com vitamina C","Cálcio: leite vegetal fortificado, couve, brócolis, tofu com cálcio, gergelim","Ômega-3: linhaça moída, chia, nozes ou suplemento DHA/EPA de microalga","Combinar proteínas vegetais para aminoácidos completos (arroz + feijão)","Proteína: tofu, tempeh, leguminosas, quinoa, seitan, pasta de amendoim","Evitar ultraprocessados veganos","Atenção a gestantes e crianças — acompanhamento especializado"]}
    $rules$::jsonb,
    'vegan'
  ),
  (
    target_organization_id,
    'Dieta Paleolítica',
    'Padrão ancestral — alimentos integrais pré-agricultura',
    array['paleo','ancestral'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["paleo"],"objectives":["general_health","weight_loss","metabolic_health"],"restrictions":["no_grains","no_legumes","no_dairy","no_refined_sugar","no_ultraprocessed"],"preferences":["lean_meat","fish","vegetables","fruits","nuts_seeds"],"contexts":["outpatient","lifestyle"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado"},"protein_pct":{"min":20,"max":35},"carbohydrate_pct":{"min":20,"max":40},"fat_pct":{"min":25,"max":45},"fiber_g":{"min":25}},"guidance":["Permitido: carnes magras, peixes, ovos, vegetais, frutas, castanhas, sementes, óleos saudáveis","Exclui: grãos, leguminosas, laticínios, açúcar refinado, sal adicionado, óleos vegetais refinados, ultraprocessados","Tubérculos em moderação","Carnes preferencialmente de pasto, frango caipira, peixe selvagem","Frutas integrais (evitar sucos concentrados)","Não contar calorias nem macronutrientes rigidamente","Suplementar vitamina D se baixa exposição solar","Atenção: restrição de cálcio (sem laticínios) — monitorar"]}
    $rules$::jsonb,
    'paleo'
  ),
  (
    target_organization_id,
    'Guia Alimentar para a População Brasileira',
    'Diretriz oficial brasileira para alimentação adequada e saudável',
    array['guia_br','nova_classification','population_guideline'],
    '{}'::jsonb,
    actor,
    'organization',
    $dim$
    {"approaches":["guia_br"],"objectives":["health_promotion","disease_prevention","sustainability"],"restrictions":["limit_ultraprocessed"],"preferences":["in_natura","minimally_processed","regional","seasonal"],"contexts":["outpatient","public_health","population"]}
    $dim$::jsonb,
    $rules$
    {"targets":{"energy_kcal":{"notes":"Individualizado; controle de peso como indicador"},"protein_pct":{"min":15,"max":20},"carbohydrate_pct":{"min":50,"max":60},"fat_pct":{"min":20,"max":30},"fiber_g":{"min":25},"ultraprocessed_pct":{"max":10}},"guidance":["1. Alimentos in natura ou minimamente processados: BASE da alimentação (>2/3 do prato)","2. Ingredientes culinários (óleos, gorduras, sal, açúcar): em PEQUENAS quantidades","3. Alimentos processados: com MODERAÇÃO (queijos, pães, conservas vegetais)","4. Alimentos ultraprocessados: EVITAR","Preparar pratos com base em alimentos in natura/minimamente processados","Limitar alimentos processados como complemento, não base","Comer com regularidade e atenção, em ambientes apropriados","Comprar em locais com variedade de in natura (feiras, mercados)","Desenvolver e partilhar habilidades culinárias","Ser crítico a propaganda de alimentos comercial"]}
    $rules$::jsonb,
    'guia_br'
  )
  on conflict (organization_id, catalog_key) where catalog_key is not null do update set
    name = excluded.name,
    objective = excluded.objective,
    tags = excluded.tags,
    scope = excluded.scope,
    dimensions = excluded.dimensions,
    rules = excluded.rules,
    updated_at = now();
end;
$$;

revoke all on function public.seed_practicas_dieteticas(uuid, uuid) from public, anon;
grant execute on function public.seed_practicas_dieteticas(uuid, uuid) to authenticated;

-- Auto-carregar os 8 modelos ao criar uma clínica.
create or replace function public.bootstrap_organization(
  full_name_input text,
  organization_name_input text,
  organization_slug_input text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  new_organization_id uuid;
begin
  if current_user_id is null then
    raise exception 'Autenticação obrigatória';
  end if;
  if char_length(trim(full_name_input)) < 2 then
    raise exception 'Nome completo inválido';
  end if;
  if char_length(trim(organization_name_input)) < 2 then
    raise exception 'Nome da clínica inválido';
  end if;
  if organization_slug_input !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Identificador da clínica inválido';
  end if;
  if exists (select 1 from public.memberships where user_id = current_user_id and status = 'active') then
    raise exception 'Usuário já possui uma organização ativa';
  end if;

  insert into public.profiles (id, full_name)
  values (current_user_id, trim(full_name_input))
  on conflict (id) do update set full_name = excluded.full_name, updated_at = now();

  insert into public.organizations (name, slug, created_by)
  values (trim(organization_name_input), organization_slug_input, current_user_id)
  returning id into new_organization_id;

  perform public.seed_practicas_dieteticas(new_organization_id, current_user_id);

  return new_organization_id;
end;
$$;

revoke all on function public.bootstrap_organization(text, text, text) from public, anon;
grant execute on function public.bootstrap_organization(text, text, text) to authenticated;

-- Backfill: clínicas já existentes também recebem os 8 modelos imediatamente.
do $$
declare r record;
begin
  for r in select id, created_by from public.organizations loop
    perform public.seed_practicas_dieteticas(r.id, r.created_by);
  end loop;
end
$$;
