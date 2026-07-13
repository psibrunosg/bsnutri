alter table public.patients add column patient_user_id uuid references public.profiles(id) on delete set null;
create unique index patients_org_user_unique on public.patients(organization_id, patient_user_id) where patient_user_id is not null;

alter table public.plan_versions
  add column targets jsonb not null default '{}'::jsonb check (jsonb_typeof(targets) = 'object'),
  add column content_hash text,
  add column locked_at timestamptz,
  add column published_at timestamptz;

alter table public.plans add column current_published_version_id uuid;
alter table public.plans add constraint plans_current_version_tenant_fkey
foreign key (current_published_version_id, organization_id)
references public.plan_versions(id, organization_id) on delete set null (current_published_version_id);

create or replace function private.can_access_patient(target_patient_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.patients p
    where p.id = target_patient_id
      and (
        p.patient_user_id = (select auth.uid())
        or exists (
          select 1 from public.patient_guardians g
          where g.patient_id = p.id
            and g.guardian_user_id = (select auth.uid())
            and g.can_view_plan
        )
      )
  );
$$;
revoke all on function private.can_access_patient(uuid) from public, anon;
grant execute on function private.can_access_patient(uuid) to authenticated;

create or replace function private.guard_patient_self_claim()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.patient_user_id is distinct from new.patient_user_id
     and not private.has_organization_role(new.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    if old.patient_user_id is not null
       or new.patient_user_id <> (select auth.uid())
       or lower(coalesce(old.email,'')) <> lower(coalesce((select auth.jwt()->>'email'),''))
       or new.organization_id <> old.organization_id
       or new.full_name <> old.full_name
       or new.professional_id <> old.professional_id
       or new.status <> old.status then
      raise exception 'Vínculo de paciente inválido';
    end if;
  end if;
  return new;
end;
$$;
create trigger patients_guard_self_claim before update on public.patients
for each row execute function private.guard_patient_self_claim();

create or replace function public.claim_patient_access()
returns uuid[] language plpgsql security invoker set search_path = '' as $$
declare claimed_ids uuid[];
begin
  if auth.uid() is null or coalesce(auth.jwt()->>'email','') = '' then
    raise exception 'Conta autenticada com e-mail é obrigatória';
  end if;
  insert into public.profiles(id, full_name)
  values (auth.uid(), coalesce(auth.jwt()->>'email','Paciente'))
  on conflict (id) do nothing;
  with updated as (
    update public.patients set patient_user_id = auth.uid()
    where patient_user_id is null and lower(email) = lower(auth.jwt()->>'email')
    returning id
  ) select array_agg(id) into claimed_ids from updated;
  if claimed_ids is null then raise exception 'Nenhum cadastro de paciente disponível para este e-mail'; end if;
  return claimed_ids;
end;
$$;
revoke all on function public.claim_patient_access() from public, anon;
grant execute on function public.claim_patient_access() to authenticated;

alter policy patients_select_clinical_team on public.patients
using (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or patient_user_id = (select auth.uid())
  or (patient_user_id is null and lower(coalesce(email,'')) = lower(coalesce((select auth.jwt()->>'email'),'')))
);
alter policy patients_update_clinical_team on public.patients
using (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or (patient_user_id is null and lower(coalesce(email,'')) = lower(coalesce((select auth.jwt()->>'email'),'')))
)
with check (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or patient_user_id = (select auth.uid())
);

create or replace function private.version_is_locked(target_version_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.plan_versions where id = target_version_id and locked_at is not null);
$$;
revoke all on function private.version_is_locked(uuid) from public, anon, authenticated;

create or replace function private.guard_version_mutation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target_version uuid;
begin
  if tg_table_name = 'plan_versions' then target_version := case when tg_op='DELETE' then old.id else new.id end;
  elsif tg_table_name = 'plan_days' then target_version := case when tg_op='DELETE' then old.plan_version_id else new.plan_version_id end;
  elsif tg_table_name = 'meals' then
    select plan_version_id into target_version from public.plan_days where id = case when tg_op='DELETE' then old.plan_day_id else new.plan_day_id end;
  elsif tg_table_name = 'meal_items' then
    select d.plan_version_id into target_version from public.meals m join public.plan_days d on d.id=m.plan_day_id where m.id=case when tg_op='DELETE' then old.meal_id else new.meal_id end;
  end if;
  if private.version_is_locked(target_version) then raise exception 'Versão publicada é imutável'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.guard_version_mutation() from public, anon, authenticated;
create trigger versions_lock_guard before update or delete on public.plan_versions for each row execute function private.guard_version_mutation();
create trigger days_lock_guard before insert or update or delete on public.plan_days for each row execute function private.guard_version_mutation();
create trigger meals_lock_guard before insert or update or delete on public.meals for each row execute function private.guard_version_mutation();
create trigger items_lock_guard before insert or update or delete on public.meal_items for each row execute function private.guard_version_mutation();

create or replace function private.validate_version_ready(target_version_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.plan_days d join public.meals m on m.plan_day_id=d.id join public.meal_items i on i.meal_id=m.id
    where d.plan_version_id=target_version_id
  ) then raise exception 'A versão precisa ter ao menos um dia, refeição e item'; end if;
  if exists (
    select 1 from jsonb_each((select targets from public.plan_versions where id=target_version_id)) e
    where jsonb_typeof(e.value) <> 'number' or (e.value::text)::numeric < 0
  ) then raise exception 'Metas nutricionais inválidas'; end if;
end;
$$;
revoke all on function private.validate_version_ready(uuid) from public, anon;
grant execute on function private.validate_version_ready(uuid) to authenticated;

create or replace function public.review_plan_version(target_plan_id uuid, target_version_id uuid, target_targets jsonb default '{}')
returns void language plpgsql security invoker set search_path = '' as $$
declare target_org uuid;
begin
  select organization_id into target_org from public.plans where id=target_plan_id for update;
  if target_org is null or not private.has_organization_role(target_org, array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
  if not exists(select 1 from public.plan_versions where id=target_version_id and plan_id=target_plan_id and locked_at is null) then raise exception 'Versão inválida ou bloqueada'; end if;
  update public.plan_versions set targets=coalesce(target_targets,'{}'::jsonb), reviewed_by=auth.uid(), reviewed_at=now() where id=target_version_id;
  perform private.validate_version_ready(target_version_id);
  update public.plans set status='reviewed',reviewed_by=auth.uid(),reviewed_at=now() where id=target_plan_id;
end;
$$;

create or replace function public.publish_plan_version(target_plan_id uuid, target_version_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare target_org uuid; target_patient uuid; snapshot_text text;
begin
  select organization_id,patient_id into target_org,target_patient from public.plans where id=target_plan_id for update;
  if target_org is null or not private.has_organization_role(target_org, array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
  if not exists(select 1 from public.plan_versions where id=target_version_id and plan_id=target_plan_id and reviewed_at is not null and locked_at is null) then raise exception 'Revise a versão antes de publicar'; end if;
  perform private.validate_version_ready(target_version_id);

  update public.meal_items i set nutrient_snapshot=jsonb_build_object(
    'food_id',f.id,'food_name',f.name,'preparation_state',f.preparation_state,'grams',i.grams,
    'source',case when s.id is null then jsonb_build_object('code','clinic','version','custom-v1') else jsonb_build_object('code',s.code,'version',s.dataset_version,'attribution',s.attribution_text) end,
    'nutrients',coalesce((select jsonb_agg(jsonb_build_object('code',n.code,'unit',n.unit,'amount_per_100g',v.amount_per_100g,'amount',round(v.amount_per_100g*i.grams/100,6)) order by n.sort_order) from public.food_nutrient_values v join public.nutrients n on n.id=v.nutrient_id where v.food_id=f.id),'[]'::jsonb)
  ) from public.foods f left join public.food_sources s on s.id=f.source_id where i.food_id=f.id and exists(select 1 from public.meals m join public.plan_days d on d.id=m.plan_day_id where m.id=i.meal_id and d.plan_version_id=target_version_id);

  select md5(string_agg(i.nutrient_snapshot::text,'|' order by d.day_index,m.position,i.position)) into snapshot_text
  from public.plan_days d join public.meals m on m.plan_day_id=d.id join public.meal_items i on i.meal_id=m.id where d.plan_version_id=target_version_id;
  update public.plan_versions set content_hash=snapshot_text,locked_at=now(),published_at=now() where id=target_version_id;
  update public.plans set status='superseded' where patient_id=target_patient and organization_id=target_org and status='published' and id<>target_plan_id;
  update public.plans set status='published',current_published_version_id=target_version_id,published_by=auth.uid(),published_at=now() where id=target_plan_id;
  insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(target_org,auth.uid(),'publish','plan',target_plan_id,jsonb_build_object('version_id',target_version_id,'content_hash',snapshot_text));
end;
$$;
revoke all on function public.review_plan_version(uuid,uuid,jsonb), public.publish_plan_version(uuid,uuid) from public,anon;
grant execute on function public.review_plan_version(uuid,uuid,jsonb), public.publish_plan_version(uuid,uuid) to authenticated;

alter policy plans_read_clinical on public.plans using (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or (status in ('published','scheduled') and current_published_version_id is not null and private.can_access_patient(patient_id))
);

drop policy versions_clinical on public.plan_versions;
create policy versions_select on public.plan_versions for select to authenticated using (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  or (locked_at is not null and exists(select 1 from public.plans p where p.current_published_version_id=plan_versions.id and p.status in ('published','scheduled') and private.can_access_patient(p.patient_id)))
);
create policy versions_insert on public.plan_versions for insert to authenticated with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy versions_update on public.plan_versions for update to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy versions_delete on public.plan_versions for delete to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

drop policy days_clinical on public.plan_days;
create policy days_select on public.plan_days for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or exists(select 1 from public.plan_versions v join public.plans p on p.current_published_version_id=v.id where v.id=plan_version_id and p.status in ('published','scheduled') and private.can_access_patient(p.patient_id)));
create policy days_insert on public.plan_days for insert to authenticated with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy days_update on public.plan_days for update to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy days_delete on public.plan_days for delete to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

drop policy meals_clinical on public.meals;
create policy meals_select on public.meals for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or exists(select 1 from public.plan_days d join public.plan_versions v on v.id=d.plan_version_id join public.plans p on p.current_published_version_id=v.id where d.id=plan_day_id and p.status in ('published','scheduled') and private.can_access_patient(p.patient_id)));
create policy meals_insert on public.meals for insert to authenticated with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy meals_update on public.meals for update to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy meals_delete on public.meals for delete to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

drop policy items_clinical on public.meal_items;
create policy items_select on public.meal_items for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or exists(select 1 from public.meals m join public.plan_days d on d.id=m.plan_day_id join public.plan_versions v on v.id=d.plan_version_id join public.plans p on p.current_published_version_id=v.id where m.id=meal_id and p.status in ('published','scheduled') and private.can_access_patient(p.patient_id)));
create policy items_insert on public.meal_items for insert to authenticated with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy items_update on public.meal_items for update to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy items_delete on public.meal_items for delete to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
