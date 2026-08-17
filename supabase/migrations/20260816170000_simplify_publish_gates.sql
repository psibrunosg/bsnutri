-- Publicar exigia percorrer o assistente clínico inteiro: quatro etapas
-- declaradas, metas de energia/macros/fibra/água e micronutrientes prioritários.
-- Na prática isso impedia o uso real do produto — o plano existia, o paciente
-- existia, e mesmo assim não dava para entregar nada.
--
-- Fica o que protege o paciente de um documento vazio ou incoerente:
--   1. a versão precisa ter conteúdo (dia, refeição e item);
--   2. metas informadas precisam ser números não negativos.
-- Sai a exigência de declaração de etapas e de metas obrigatórias. Meta em
-- branco volta a significar "não estipulada", não um bloqueio.

create or replace function private.validate_version_ready(target_version_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare target_targets jsonb;
begin
  select targets into target_targets from public.plan_versions where id = target_version_id;

  if not exists (
    select 1 from public.plan_days d
      join public.meals m on m.plan_day_id = d.id
      join public.meal_items i on i.meal_id = m.id
    where d.plan_version_id = target_version_id
  ) then
    raise exception 'A versao precisa ter ao menos um dia, refeicao e item';
  end if;

  if exists (
    select 1 from jsonb_each(coalesce(target_targets, '{}'::jsonb)) e
    where jsonb_typeof(e.value) <> 'number' or (e.value::text)::numeric < 0
  ) then
    raise exception 'Metas nutricionais invalidas';
  end if;
end;
$$;

revoke all on function private.validate_version_ready(uuid) from public, anon;
grant execute on function private.validate_version_ready(uuid) to authenticated;

-- `publish_plan_version` também exigia a etapa 'review' declarada no assistente.
-- A revisão continua sendo um passo real: `review_plan_version` precisa ter
-- rodado e gravado `reviewed_at`. O que sai é a exigência de o profissional
-- declarar a etapa em uma tela separada.
create or replace function public.publish_plan_version(target_plan_id uuid, target_version_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare target_org uuid; target_patient uuid; snapshot_text text;
begin
  perform set_config('bsnutri.workflow_rpc','on',true);
  select organization_id,patient_id into target_org,target_patient from public.plans where id=target_plan_id for update;
  if target_org is null or not private.has_organization_role(target_org, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado';
  end if;
  if not exists(select 1 from public.plan_versions where id=target_version_id and plan_id=target_plan_id and reviewed_at is not null and locked_at is null) then
    raise exception 'Revise a versao antes de publicar';
  end if;
  perform private.validate_version_ready(target_version_id);

  update public.meal_items i set nutrient_snapshot=jsonb_build_object(
    'food_id',f.id,'food_name',f.name,'preparation_state',f.preparation_state,'grams',i.grams,
    'source',case when s.id is null then jsonb_build_object('code','clinic','version','custom-v1') else jsonb_build_object('code',s.code,'version',s.dataset_version,'attribution',s.attribution_text) end,
    'nutrients',coalesce((select jsonb_agg(jsonb_build_object('code',n.code,'unit',n.unit,'amount_per_100g',v.amount_per_100g,'amount',round(v.amount_per_100g*i.grams/100,6)) order by n.sort_order) from public.food_nutrient_values v join public.nutrients n on n.id=v.nutrient_id where v.food_id=f.id),'[]'::jsonb)
  ) from public.foods f left join public.food_sources s on s.id=f.source_id
  where i.food_id=f.id and exists(select 1 from public.meals m join public.plan_days d on d.id=m.plan_day_id where m.id=i.meal_id and d.plan_version_id=target_version_id);

  select md5(string_agg(i.nutrient_snapshot::text,'|' order by d.day_index,m.position,i.position)) into snapshot_text
  from public.plan_days d join public.meals m on m.plan_day_id=d.id join public.meal_items i on i.meal_id=m.id
  where d.plan_version_id=target_version_id;

  update public.plan_versions set content_hash=snapshot_text,locked_at=now(),published_at=now() where id=target_version_id;
  update public.plans set status='superseded' where patient_id=target_patient and organization_id=target_org and status='published' and id<>target_plan_id;
  update public.plans set status='published',current_published_version_id=target_version_id,published_by=auth.uid(),published_at=now() where id=target_plan_id;
  insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata)
  values(target_org,auth.uid(),'publish','plan',target_plan_id,jsonb_build_object('version_id',target_version_id,'content_hash',snapshot_text));
end;
$$;

revoke all on function public.publish_plan_version(uuid, uuid) from public, anon;
grant execute on function public.publish_plan_version(uuid, uuid) to authenticated;
