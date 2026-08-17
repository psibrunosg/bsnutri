


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






CREATE SCHEMA IF NOT EXISTS "private";


ALTER SCHEMA "private" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."alert_kind" AS ENUM (
    'allergy_or_reaction',
    'severe_symptom',
    'low_intake',
    'intense_hunger',
    'rapid_weight_change',
    'other'
);


ALTER TYPE "public"."alert_kind" OWNER TO "postgres";


CREATE TYPE "public"."alert_severity" AS ENUM (
    'info',
    'attention',
    'urgent'
);


ALTER TYPE "public"."alert_severity" OWNER TO "postgres";


CREATE TYPE "public"."alert_status" AS ENUM (
    'open',
    'acknowledged',
    'resolved'
);


ALTER TYPE "public"."alert_status" OWNER TO "postgres";


CREATE TYPE "public"."appointment_modality" AS ENUM (
    'in_person',
    'online',
    'home_visit'
);


ALTER TYPE "public"."appointment_modality" OWNER TO "postgres";


CREATE TYPE "public"."appointment_status" AS ENUM (
    'requested',
    'approved',
    'rejected',
    'cancelled',
    'completed',
    'no_show'
);


ALTER TYPE "public"."appointment_status" OWNER TO "postgres";


CREATE TYPE "public"."catalog_kind" AS ENUM (
    'food',
    'preparation',
    'combination'
);


ALTER TYPE "public"."catalog_kind" OWNER TO "postgres";


CREATE TYPE "public"."checkin_state" AS ENUM (
    'completed',
    'adapted',
    'skipped'
);


ALTER TYPE "public"."checkin_state" OWNER TO "postgres";


CREATE TYPE "public"."clinical_draft_kind" AS ENUM (
    'summary',
    'guidance',
    'plan_structure'
);


ALTER TYPE "public"."clinical_draft_kind" OWNER TO "postgres";


CREATE TYPE "public"."clinical_draft_status" AS ENUM (
    'draft',
    'approved',
    'discarded'
);


ALTER TYPE "public"."clinical_draft_status" OWNER TO "postgres";


CREATE TYPE "public"."day_kind" AS ENUM (
    'standard',
    'training',
    'rest',
    'shift',
    'weekend',
    'custom'
);


ALTER TYPE "public"."day_kind" OWNER TO "postgres";


CREATE TYPE "public"."drive_connection_status" AS ENUM (
    'missing',
    'connected'
);


ALTER TYPE "public"."drive_connection_status" OWNER TO "postgres";


CREATE TYPE "public"."form_assignment_status" AS ENUM (
    'pending',
    'draft',
    'submitted'
);


ALTER TYPE "public"."form_assignment_status" OWNER TO "postgres";


CREATE TYPE "public"."form_field_type" AS ENUM (
    'short_text',
    'long_text',
    'number',
    'scale',
    'select',
    'date'
);


ALTER TYPE "public"."form_field_type" OWNER TO "postgres";


CREATE TYPE "public"."membership_status" AS ENUM (
    'invited',
    'active',
    'suspended'
);


ALTER TYPE "public"."membership_status" OWNER TO "postgres";


CREATE TYPE "public"."organization_role" AS ENUM (
    'owner',
    'admin',
    'nutritionist',
    'student',
    'receptionist'
);


ALTER TYPE "public"."organization_role" OWNER TO "postgres";


CREATE TYPE "public"."patient_goal_kind" AS ENUM (
    'water',
    'meals',
    'weight',
    'behavior'
);


ALTER TYPE "public"."patient_goal_kind" OWNER TO "postgres";


CREATE TYPE "public"."plan_status" AS ENUM (
    'draft',
    'in_review',
    'reviewed',
    'approved',
    'scheduled',
    'published',
    'superseded',
    'archived'
);


ALTER TYPE "public"."plan_status" OWNER TO "postgres";


CREATE TYPE "public"."plan_template_scope" AS ENUM (
    'personal',
    'organization'
);


ALTER TYPE "public"."plan_template_scope" OWNER TO "postgres";


CREATE TYPE "public"."plan_template_status" AS ENUM (
    'needs_review',
    'approved',
    'archived'
);


ALTER TYPE "public"."plan_template_status" OWNER TO "postgres";


CREATE TYPE "public"."substitution_request_status" AS ENUM (
    'requested',
    'approved',
    'rejected',
    'cancelled'
);


ALTER TYPE "public"."substitution_request_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."assert_form_required_fields"("target_version_id" "uuid", "target_values" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
begin
 if exists(select 1 from public.form_fields f where f.version_id=target_version_id and f.required and nullif(trim(coalesce(target_values->>(f.id::text),'')),'') is null) then
  raise exception 'Campos obrigatorios pendentes';
 end if;
end; $$;


ALTER FUNCTION "private"."assert_form_required_fields"("target_version_id" "uuid", "target_values" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."auto_approve_own_plan_template"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare origin text := new.provenance->>'origin';
begin
  -- Modelo importado ou semeado continua nascendo pendente de revisão.
  if new.catalog_key is not null or origin = 'seed' then
    return new;
  end if;

  if new.created_by = (select auth.uid()) then
    new.status := 'approved';
    new.reviewed_by := new.created_by;
    new.reviewed_at := now();
    new.review_notes := coalesce(new.review_notes, 'Aprovado automaticamente: criado pelo próprio profissional.');
    if new.provenance = '{}'::jsonb then
      new.provenance := jsonb_build_object('origin', case when new.source_plan_id is not null then 'plan' else 'manual' end);
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "private"."auto_approve_own_plan_template"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."bootstrap_owner_membership"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null or new.created_by <> auth.uid() then
    raise exception 'Organização deve ser criada pelo usuário autenticado';
  end if;
  if exists (select 1 from public.memberships where user_id = auth.uid() and status = 'active') then
    raise exception 'Usuário já possui uma organização ativa';
  end if;
  insert into public.memberships (organization_id, user_id, role, status)
  values (new.id, auth.uid(), 'owner', 'active');
  return new;
end;
$$;


ALTER FUNCTION "private"."bootstrap_owner_membership"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_access_patient"("target_patient_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."can_access_patient"("target_patient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_manage_patient_appointments"("target_patient_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 select exists(
   select 1
   from public.patients p
   where p.id = target_patient_id
     and (
       p.patient_user_id = nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
       or exists (
         select 1
         from public.patient_guardians g
         where g.patient_id = p.id
           and g.guardian_user_id = nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
           and g.can_manage_appointments
       )
     )
 );
$$;


ALTER FUNCTION "private"."can_manage_patient_appointments"("target_patient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."create_checkin_alert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
 if new.help_requested then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'severe_symptom','urgent','Paciente pediu ajuda no diario alimentar.');
 elsif new.reaction_suspected then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'allergy_or_reaction','urgent','Paciente sinalizou possivel reacao ou alergia.');
 elsif new.state='skipped' then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'low_intake','attention','Paciente registrou refeicao pulada.');
 elsif new.state='adapted' then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'other','attention','Paciente registrou refeicao adaptada ou troca nao aprovada.');
 elsif coalesce(new.hunger_before,0)>=9 then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'intense_hunger','attention','Paciente registrou fome extrema antes da refeicao.');
 elsif coalesce(new.satiety_after,10)<=1 then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'low_intake','attention','Paciente registrou saciedade extrema baixa depois da refeicao.');
 elsif nullif(trim(coalesce(new.symptoms,'')),'') is not null and coalesce(new.symptom_intensity,0)>=4 then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'severe_symptom',case when new.symptom_intensity>=7 then 'urgent'::public.alert_severity else 'attention'::public.alert_severity end,'Paciente registrou sintoma moderado ou forte.');
 end if;
 return new;
end; $$;


ALTER FUNCTION "private"."create_checkin_alert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."guard_appointment_status"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
 if old.status is distinct from new.status and current_setting('bsnutri.appointment_rpc',true) is distinct from 'on' then raise exception 'Use o fluxo de agenda do BSNutri'; end if;
 return new;
end; $$;


ALTER FUNCTION "private"."guard_appointment_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."guard_patient_self_claim"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."guard_patient_self_claim"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."guard_plan_workflow"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if current_setting('bsnutri.workflow_rpc',true) is distinct from 'on'
     and (
       (old.status is distinct from new.status and not (old.status='draft' and new.status='archived'))
       or old.reviewed_by is distinct from new.reviewed_by
       or old.reviewed_at is distinct from new.reviewed_at
       or old.published_by is distinct from new.published_by
       or old.published_at is distinct from new.published_at
       or old.current_published_version_id is distinct from new.current_published_version_id
     ) then
    raise exception 'Use o fluxo de revisão e publicação do BSNutri';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "private"."guard_plan_workflow"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."guard_published_substitution"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare target_version uuid := case when tg_op='DELETE' then old.plan_version_id else new.plan_version_id end;
begin
  if exists(select 1 from public.plan_versions where id=target_version and locked_at is not null) then
    raise exception 'Alternativas de uma versão publicada são imutáveis';
  end if;
  return case when tg_op='DELETE' then old else new end;
end; $$;


ALTER FUNCTION "private"."guard_published_substitution"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."guard_substitution_request_workflow"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if old.organization_id<>new.organization_id or old.patient_id<>new.patient_id
    or old.plan_version_id<>new.plan_version_id or old.meal_item_id<>new.meal_item_id
    or old.substitution_id<>new.substitution_id or old.requested_by<>new.requested_by then
    raise exception 'O conteúdo da solicitação é imutável';
  end if;
  if old.status<>'requested' or new.status not in ('approved','rejected','cancelled') then
    raise exception 'Transição de solicitação inválida';
  end if;
  return new;
end; $$;


ALTER FUNCTION "private"."guard_substitution_request_workflow"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."guard_version_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."guard_version_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role = any(allowed_roles)
  );
$$;


ALTER FUNCTION "private"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."is_active_member"("target_organization_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = target_organization_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;


ALTER FUNCTION "private"."is_active_member"("target_organization_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."plan_assistant_has_steps"("target_state" "jsonb", "required_steps" "text"[]) RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select coalesce(target_state->'completedSteps','[]'::jsonb) @> to_jsonb(required_steps);
$$;


ALTER FUNCTION "private"."plan_assistant_has_steps"("target_state" "jsonb", "required_steps" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."plan_target_value"("targets" "jsonb", "keys" "text"[]) RETURNS numeric
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select max((value::text)::numeric)
  from jsonb_each(targets) item(key, value)
  where key = any(keys) and jsonb_typeof(value) = 'number';
$$;


ALTER FUNCTION "private"."plan_target_value"("targets" "jsonb", "keys" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."prevent_content_version_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin raise exception 'Versões publicadas de conteúdo são imutáveis'; end; $$;


ALTER FUNCTION "private"."prevent_content_version_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."set_catalog_review_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.organization_id is null then return new; end if;

  if new.review_status = 'reviewed' then
    if not private.has_organization_role(new.organization_id, array['owner','admin','nutritionist']::public.organization_role[]) then
      raise exception 'Somente a equipe clínica pode revisar um item do catálogo';
    end if;
    if new.reviewed_by is distinct from auth.uid() then
      raise exception 'A revisão deve registrar o profissional autenticado';
    end if;
    new.reviewed_at = coalesce(new.reviewed_at, now());
  else
    new.reviewed_at = null;
    new.reviewed_by = null;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "private"."set_catalog_review_metadata"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "private"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."snapshot_substitutions_on_publication"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if old.locked_at is null and new.locked_at is not null then
    update public.meal_item_substitutions s set nutrient_snapshot=jsonb_build_object(
      'food_id',f.id,'food_name',f.name,'preparation_state',f.preparation_state,'grams',s.grams,
      'source',coalesce(fs.name,'Cadastro profissional'),
      'nutrients',coalesce((select jsonb_agg(jsonb_build_object('code',n.code,'unit',n.unit,'amount_per_100g',v.amount_per_100g,'amount',round(v.amount_per_100g*s.grams/100,6)) order by n.sort_order) from public.food_nutrient_values v join public.nutrients n on n.id=v.nutrient_id where v.food_id=f.id),'[]'::jsonb)
    ) from public.foods f left join public.food_sources fs on fs.id=f.source_id
    where s.plan_version_id=new.id and s.substitute_food_id=f.id;
  end if;
  return new;
end; $$;


ALTER FUNCTION "private"."snapshot_substitutions_on_publication"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_checkin_chain"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
 if not exists(select 1 from public.meals m join public.plan_days d on d.id=m.plan_day_id join public.plan_versions v on v.id=d.plan_version_id join public.plans p on p.current_published_version_id=v.id where m.id=new.meal_id and v.id=new.plan_version_id and p.patient_id=new.patient_id and p.organization_id=new.organization_id and p.status in('published','scheduled')) then raise exception 'Check-in deve pertencer ao plano vigente publicado'; end if;
 if new.created_by<>(select auth.uid()) then raise exception 'Autor inválido'; end if;
 return new;
end; $$;


ALTER FUNCTION "private"."validate_checkin_chain"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_checkin_substitution"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.substitution_request_id is not null and not exists (
    select 1 from public.substitution_requests r
    where r.id=new.substitution_request_id and r.organization_id=new.organization_id
      and r.patient_id=new.patient_id and r.plan_version_id=new.plan_version_id
      and r.meal_item_id in (select i.id from public.meal_items i where i.meal_id=new.meal_id)
      and r.status='approved'
  ) then raise exception 'A troca registrada deve ser aprovada e pertencer a esta refeição'; end if;
  return new;
end; $$;


ALTER FUNCTION "private"."validate_checkin_substitution"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_food_component_integrity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."validate_food_component_integrity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_meal_item_food_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare food_org uuid;
begin
  if new.food_id is null then return new; end if;
  select organization_id into food_org from public.foods where id = new.food_id;
  if not found or (food_org is not null and food_org <> new.organization_id) then
    raise exception 'Alimento não pertence à organização do plano';
  end if;
  return new;
end; $$;


ALTER FUNCTION "private"."validate_meal_item_food_tenant"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_substitution_chain"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare food_org uuid;
begin
  if not exists (
    select 1 from public.meal_items i
    join public.meals m on m.id=i.meal_id
    join public.plan_days d on d.id=m.plan_day_id
    join public.plan_versions v on v.id=d.plan_version_id
    where i.id=new.meal_item_id and v.id=new.plan_version_id
      and v.organization_id=new.organization_id
  ) then raise exception 'A substituição deve pertencer ao item e à versão informados'; end if;
  if new.substitute_food_id is not null then
    select organization_id into food_org from public.foods where id=new.substitute_food_id and is_active;
    if not found or (food_org is not null and food_org<>new.organization_id) then
      raise exception 'Alimento substituto indisponível para esta organização';
    end if;
  end if;
  return new;
end; $$;


ALTER FUNCTION "private"."validate_substitution_chain"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_substitution_request_chain"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if not exists (
    select 1 from public.meal_item_substitutions s
    join public.plans p on p.current_published_version_id=s.plan_version_id
    where s.id=new.substitution_id and s.organization_id=new.organization_id
      and s.plan_version_id=new.plan_version_id and s.meal_item_id=new.meal_item_id
      and s.is_active and p.patient_id=new.patient_id and p.status in ('published','scheduled')
  ) then raise exception 'Substituição indisponível para o plano vigente'; end if;
  return new;
end; $$;


ALTER FUNCTION "private"."validate_substitution_request_chain"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validate_version_ready"("target_version_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."validate_version_ready"("target_version_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."version_is_locked"("target_version_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists(select 1 from public.plan_versions where id = target_version_id and locked_at is not null);
$$;


ALTER FUNCTION "private"."version_is_locked"("target_version_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_custom_catalog_food"("target_food" "jsonb", "target_nutrients" "jsonb" DEFAULT '[]'::"jsonb", "target_components" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  org_id uuid;
  new_food_id uuid;
  n_item jsonb;
  c_item jsonb;
begin
  org_id := (target_food->>'organization_id')::uuid;
  if org_id is null or not private.has_organization_role(org_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado ou organização inválida para cadastro de alimento';
  end if;

  insert into public.foods (
    organization_id, source_id, source_reference, source_accessed_on,
    source_reliability, review_status, reviewed_by, name,
    preparation_state, search_terms, cultural_tags, restriction_tags,
    preference_tags, availability_tags, cost_band, catalog_kind,
    yield_grams, serving_grams, portion_count,
    household_measure_label, household_measure_grams, render_path, created_by
  )
  values (
    org_id,
    nullif(target_food->>'source_id', '')::uuid,
    nullif(target_food->>'source_reference', ''),
    nullif(target_food->>'source_accessed_on', '')::date,
    nullif(target_food->>'source_reliability', '')::smallint,
    coalesce(nullif(target_food->>'review_status', ''), 'pending_review'),
    nullif(target_food->>'reviewed_by', '')::uuid,
    target_food->>'name',
    coalesce(nullif(target_food->>'preparation_state', ''), 'unspecified'),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'search_terms', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'cultural_tags', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'restriction_tags', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'preference_tags', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'availability_tags', '[]'::jsonb))), '{}'::text[]),
    nullif(target_food->>'cost_band', ''),
    coalesce((target_food->>'catalog_kind')::public.catalog_kind, 'food'::public.catalog_kind),
    nullif(target_food->>'yield_grams', '')::numeric,
    nullif(target_food->>'serving_grams', '')::numeric,
    nullif(target_food->>'portion_count', '')::numeric,
    nullif(target_food->>'household_measure_label', ''),
    nullif(target_food->>'household_measure_grams', '')::numeric,
    target_food->>'render_path',
    auth.uid()
  )
  returning id into new_food_id;

  for n_item in select elem from jsonb_array_elements(target_nutrients) elem loop
    insert into public.food_nutrient_values (
      food_id, nutrient_id, amount_per_100g, data_version
    )
    values (
      new_food_id,
      (n_item->>'nutrient_id')::uuid,
      coalesce((n_item->>'amount_per_100g')::numeric, 0),
      coalesce(nullif(n_item->>'data_version', ''), 'custom-v1')
    );
  end loop;

  for c_item in select elem from jsonb_array_elements(target_components) elem loop
    insert into public.food_components (
      organization_id, parent_food_id, component_food_id, grams, position
    )
    values (
      org_id,
      new_food_id,
      (c_item->>'component_food_id')::uuid,
      coalesce((c_item->>'grams')::numeric, 0),
      coalesce((c_item->>'position')::integer, 0)
    );
  end loop;

  return new_food_id;
end;
$$;


ALTER FUNCTION "public"."add_custom_catalog_food"("target_food" "jsonb", "target_nutrients" "jsonb", "target_components" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "title" "text" DEFAULT 'Plano alimentar'::"text" NOT NULL,
    "status" "public"."plan_status" DEFAULT 'draft'::"public"."plan_status" NOT NULL,
    "starts_on" "date",
    "ends_on" "date",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "published_by" "uuid",
    "published_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "current_published_version_id" "uuid",
    CONSTRAINT "plans_check" CHECK ((("ends_on" IS NULL) OR ("starts_on" IS NULL) OR ("ends_on" >= "starts_on")))
);


ALTER TABLE "public"."plans" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer DEFAULT 1, "target_weekdays" "text"[] DEFAULT NULL::"text"[]) RETURNS "public"."plans"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare result public.plans; target_values jsonb;
begin
  select rules->'targets' into target_values from public.plan_templates where id = target_template_id;
  select * into result from public.copy_plan_template_to_patient(target_template_id, target_patient_id, target_days, target_weekdays);
  update public.plan_versions set targets = coalesce(target_values, targets), change_summary = 'Proposta criada a partir de modelo'
  where plan_id = result.id and version_no = 1;
  return result;
end;
$$;


ALTER FUNCTION "public"."apply_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer, "target_weekdays" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."audit_clinical_export"("target_patient_id" "uuid", "target_kind" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare org_id uuid;
begin
 select organization_id into org_id from public.patients where id=target_patient_id;
 if org_id is null or not private.has_organization_role(org_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(org_id,auth.uid(),'clinical_export','patient',target_patient_id,jsonb_build_object('kind',target_kind));
end; $$;


ALTER FUNCTION "public"."audit_clinical_export"("target_patient_id" "uuid", "target_kind" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autosave_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb") RETURNS timestamp with time zone
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  plan_row public.plans;
  new_day uuid;
  new_meal uuid;
  day_json jsonb;
  meal_json jsonb;
  item_json jsonb;
  day_idx integer := 0;
  meal_pos integer;
  item_pos integer;
  eq_list_id uuid;
begin
  select * into plan_row from public.plans where id = target_plan_id;
  if plan_row.id is null
     or not private.has_organization_role(plan_row.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado ao plano' using errcode = '42501';
  end if;

  if plan_row.status <> 'draft' then
    raise exception 'Somente rascunho aceita gravação automática' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.plan_versions
     where id = target_version_id and plan_id = target_plan_id and locked_at is null
  ) then
    raise exception 'Versão inválida ou bloqueada' using errcode = '42501';
  end if;

  if jsonb_array_length(coalesce(target_days, '[]'::jsonb)) = 0 then
    raise exception 'Estrutura de dias vazia no plano';
  end if;

  delete from public.plan_days where plan_version_id = target_version_id;

  for day_json in select elem from jsonb_array_elements(target_days) elem loop
    insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
    values (
      plan_row.organization_id,
      target_version_id,
      coalesce((day_json->>'day_index')::integer, day_idx),
      coalesce(day_json->>'label', 'Dia ' || (day_idx + 1)),
      coalesce((day_json->>'kind')::public.day_kind, 'standard'::public.day_kind)
    )
    returning id into new_day;
    day_idx := day_idx + 1;

    meal_pos := 0;
    for meal_json in select elem from jsonb_array_elements(coalesce(day_json->'meals', '[]'::jsonb)) elem loop
      eq_list_id := null;
      if (meal_json->>'equivalencyListId') is not null and (meal_json->>'equivalencyListId') <> '' then
        eq_list_id := (meal_json->>'equivalencyListId')::uuid;
      elsif (meal_json->>'equivalency_list_id') is not null and (meal_json->>'equivalency_list_id') <> '' then
        eq_list_id := (meal_json->>'equivalency_list_id')::uuid;
      end if;

      insert into public.meals (organization_id, plan_day_id, position, label, equivalency_list_id, notes)
      values (
        plan_row.organization_id, new_day, coalesce((meal_json->>'position')::integer, meal_pos),
        coalesce(meal_json->>'label', 'Refeição'), eq_list_id, nullif(trim(meal_json->>'notes'), '')
      )
      returning id into new_meal;
      meal_pos := meal_pos + 1;

      item_pos := 0;
      for item_json in select elem from jsonb_array_elements(coalesce(meal_json->'items', '[]'::jsonb)) elem loop
        if coalesce((item_json->>'grams')::numeric, 0) > 0 then
          insert into public.meal_items (organization_id, meal_id, position, food_id, description, quantity, unit, grams, nutrient_snapshot)
          values (
            plan_row.organization_id, new_meal, coalesce((item_json->>'position')::integer, item_pos),
            nullif(item_json->>'food_id', '')::uuid,
            coalesce(item_json->>'description', 'Item'),
            (item_json->>'grams')::numeric, 'g', (item_json->>'grams')::numeric,
            coalesce(item_json->'nutrient_snapshot', '{}'::jsonb)
          );
          item_pos := item_pos + 1;
        end if;
      end loop;
    end loop;
  end loop;

  update public.plan_versions
     set assistant_state = coalesce(target_assistant_state, assistant_state),
         targets = coalesce(target_targets, targets)
   where id = target_version_id;

  update public.plans set updated_at = now() where id = target_plan_id;

  return now();
end;
$$;


ALTER FUNCTION "public"."autosave_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bootstrap_organization"("full_name_input" "text", "organization_name_input" "text", "organization_slug_input" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
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
$_$;


ALTER FUNCTION "public"."bootstrap_organization"("full_name_input" "text", "organization_name_input" "text", "organization_slug_input" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_appointment"("target_id" "uuid", "reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare row_data public.appointments%rowtype;
begin
 perform set_config('bsnutri.appointment_rpc','on',true); select * into row_data from public.appointments where id=target_id for update;
 if row_data.id is null or not(private.has_organization_role(row_data.organization_id,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) or private.can_manage_patient_appointments(row_data.patient_id)) then raise exception 'Acesso negado'; end if;
 if row_data.status in('completed','no_show','cancelled') then raise exception 'Agendamento não pode ser cancelado'; end if;
 update public.appointments set status='cancelled',cancellation_reason=reason where id=target_id;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(row_data.organization_id,auth.uid(),'appointment_cancelled','appointment',target_id,jsonb_build_object('reason',reason));
end; $$;


ALTER FUNCTION "public"."cancel_appointment"("target_id" "uuid", "reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_patient_access"() RETURNS "uuid"[]
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."claim_patient_access"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."copy_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer DEFAULT 1, "target_weekdays" "text"[] DEFAULT NULL::"text"[]) RETURNS "public"."plans"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  t public.plan_templates;
  patient_org uuid;
  result public.plans;
  source_version uuid;
  new_version uuid;
  new_day uuid;
  new_meal uuid;
  day_row record;
  meal_row record;
  snapshot_meal jsonb;
  snapshot_item jsonb;
  meal_pos integer;
  item_pos integer;
  meal_food_id uuid;
  item_description text;
  day_desc jsonb;
begin
  select * into t from public.plan_templates where id = target_template_id;
  select organization_id into patient_org from public.patients where id = target_patient_id;
  if t.id is null or patient_org <> t.organization_id
     or not private.has_organization_role(t.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado';
  end if;
  if t.status <> 'approved' then
    raise exception 'Modelo não aprovado para uso clínico' using errcode = '42501';
  end if;

  insert into public.plans (organization_id, patient_id, created_by, title, status)
  values (t.organization_id, target_patient_id, auth.uid(), t.name, 'draft')
  returning * into result;

  insert into public.plan_versions (organization_id, plan_id, version_no, created_by, change_summary, assistant_state, targets)
  values (
    t.organization_id, result.id, 1, auth.uid(), 'Proposta criada a partir de modelo',
    coalesce(t.snapshot #> '{versions,0,assistant_state}', '{}'::jsonb),
    coalesce(t.snapshot #> '{versions,0,targets}', t.rules->'targets', '{}'::jsonb)
  );
  select id into new_version from public.plan_versions where plan_id = result.id and version_no = 1;

  if t.source_plan_id is not null then
    select id into source_version from public.plan_versions where plan_id = t.source_plan_id order by version_no desc limit 1;
    for day_row in select * from public.plan_days where plan_version_id = source_version order by day_index loop
      insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
      values (t.organization_id, new_version, day_row.day_index, day_row.label, day_row.kind)
      returning id into new_day;
      for meal_row in select * from public.meals where plan_day_id = day_row.id order by position loop
        insert into public.meals (organization_id, plan_day_id, position, label, suggested_time)
        values (t.organization_id, new_day, meal_row.position, meal_row.label, meal_row.suggested_time)
        returning id into new_meal;
        insert into public.meal_items (organization_id, meal_id, position, food_id, description, quantity, unit, grams, nutrient_snapshot, notes)
        select t.organization_id, new_meal, position, food_id, description, quantity, unit, grams, nutrient_snapshot, notes
        from public.meal_items where meal_id = meal_row.id order by position;
      end loop;
    end loop;
  else
    if target_weekdays is not null and array_length(target_weekdays, 1) > 0 then
      select coalesce(jsonb_agg(jsonb_build_object('index', w.idx, 'label', w.label, 'weekday', w.code) order by w.idx), '[]'::jsonb)
      into day_desc
      from (
        select un.idx, un.wd,
               case un.wd when 'mon' then 'Segunda-feira' when 'tue' then 'Terça-feira' when 'wed' then 'Quarta-feira'
                          when 'thu' then 'Quinta-feira' when 'fri' then 'Sexta-feira' when 'sat' then 'Sábado'
                          when 'sun' then 'Domingo' end as label,
               case un.wd when 'mon' then 0 when 'tue' then 1 when 'wed' then 2 when 'thu' then 3
                          when 'fri' then 4 when 'sat' then 5 when 'sun' then 6 end as code
        from unnest(target_weekdays) with ordinality as un(wd, idx)
      ) w
      where w.label is not null;
    else
      select jsonb_agg(jsonb_build_object('index', g, 'label', case when target_days > 1 then 'Dia ' || (g+1) else 'Dia 1' end, 'weekday', null))
      into day_desc
      from generate_series(0, greatest(target_days, 1) - 1) g;
    end if;

    for day_row in
      select (elem->>'index')::int as day_index, elem->>'label' as label, (elem->>'weekday')::smallint as weekday
      from jsonb_array_elements(coalesce(day_desc, '[]'::jsonb)) elem
    loop
      insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind, weekday)
      values (t.organization_id, new_version, day_row.day_index, day_row.label, 'standard', day_row.weekday)
      returning id into new_day;
      meal_pos := 0;
      for snapshot_meal in select elem from jsonb_array_elements(coalesce(t.snapshot->'meals','[]'::jsonb)) elem loop
        insert into public.meals (organization_id, plan_day_id, position, label, suggested_time)
        values (t.organization_id, new_day, meal_pos, snapshot_meal->>'name', nullif(snapshot_meal->>'time','')::time)
        returning id into new_meal;
        meal_pos := meal_pos + 1;
        item_pos := 0;
        for snapshot_item in select elem from jsonb_array_elements(coalesce(snapshot_meal->'items','[]'::jsonb)) elem loop
          if snapshot_item->>'grams' is not null and (snapshot_item->>'grams')::numeric > 0 then
            item_description := snapshot_item->>'food';
            if snapshot_item->>'measure' is not null and snapshot_item->>'measure' <> '' then
              item_description := item_description || ' (' || (snapshot_item->>'measure') || ')';
            end if;
            select id into meal_food_id
            from public.foods
            where is_active
              and lower(btrim(name)) = lower(btrim(snapshot_item->>'food'))
              and (organization_id = t.organization_id or organization_id is null)
            order by organization_id nulls last, id
            limit 1;
            insert into public.meal_items (organization_id, meal_id, position, food_id, description, quantity, unit, grams, nutrient_snapshot)
            values (t.organization_id, new_meal, item_pos, meal_food_id, item_description,
                    (snapshot_item->>'grams')::numeric, 'g', (snapshot_item->>'grams')::numeric,
                    coalesce(snapshot_item->'macros','{}'::jsonb));
            item_pos := item_pos + 1;
          end if;
        end loop;
      end loop;
    end loop;
  end if;
  return result;
end;
$$;


ALTER FUNCTION "public"."copy_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer, "target_weekdays" "text"[]) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."follow_up_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "alert_id" "uuid" NOT NULL,
    "action_type" "text" NOT NULL,
    "note" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "follow_up_actions_action_type_check" CHECK (("action_type" = ANY (ARRAY['guidance'::"text", 'review_request'::"text", 'substitution_request'::"text", 'followed_up'::"text"])))
);


ALTER TABLE "public"."follow_up_actions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_follow_up_action"("target_alert_id" "uuid", "target_action" "text", "target_note" "text" DEFAULT NULL::"text") RETURNS "public"."follow_up_actions"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
 row_data public.adherence_alerts;
 result public.follow_up_actions;
 clean_note text := nullif(trim(coalesce(target_note,'')),'');
begin
 if target_action not in ('guidance','review_request','substitution_request','followed_up') then
  raise exception 'acao de acompanhamento invalida';
 end if;
 select * into row_data from public.adherence_alerts where id=target_alert_id;
 if row_data.id is null or not private.has_organization_role(row_data.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then
  raise exception 'alerta indisponivel';
 end if;
 if target_action in ('guidance','review_request','substitution_request') and clean_note is null then
  raise exception 'nota obrigatoria para acao de acompanhamento';
 end if;
 insert into public.follow_up_actions(organization_id,patient_id,alert_id,action_type,note,created_by)
 values(row_data.organization_id,row_data.patient_id,row_data.id,target_action,clean_note,auth.uid())
 returning * into result;
 if target_action='followed_up' then
  update public.adherence_alerts set status='resolved',resolved_by=auth.uid(),resolved_at=now() where id=row_data.id;
 elsif row_data.status='open' then
  update public.adherence_alerts set status='acknowledged',acknowledged_by=auth.uid(),acknowledged_at=now() where id=row_data.id;
 end if;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values(row_data.organization_id,auth.uid(),'follow_up_'||target_action,'adherence_alert',row_data.id,jsonb_build_object('note',clean_note));
 return result;
end; $$;


ALTER FUNCTION "public"."create_follow_up_action"("target_alert_id" "uuid", "target_action" "text", "target_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_patient_intake"("target_organization_id" "uuid", "full_name_input" "text", "email_input" "text" DEFAULT NULL::"text", "phone_input" "text" DEFAULT NULL::"text", "birth_date_input" "date" DEFAULT NULL::"date", "tags_input" "text"[] DEFAULT '{}'::"text"[], "objective_input" "text" DEFAULT NULL::"text", "food_preferences_input" "text" DEFAULT NULL::"text", "food_restrictions_input" "text" DEFAULT NULL::"text", "allergies_input" "text" DEFAULT NULL::"text", "clinical_notes_input" "text" DEFAULT NULL::"text", "weight_kg_input" numeric DEFAULT NULL::numeric, "height_cm_input" numeric DEFAULT NULL::numeric, "waist_cm_input" numeric DEFAULT NULL::numeric, "hip_cm_input" numeric DEFAULT NULL::numeric, "arm_cm_input" numeric DEFAULT NULL::numeric, "body_fat_percent_input" numeric DEFAULT NULL::numeric, "measured_at_input" timestamp with time zone DEFAULT "now"()) RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare
  actor uuid := (select auth.uid());
  new_patient_id uuid;
  new_assessment_id uuid;
  next_code text;
  attempt integer := 0;
  normalized_name text := trim(coalesce(full_name_input, ''));
  normalized_email text := nullif(trim(coalesce(email_input, '')), '');
  normalized_phone text := nullif(trim(coalesce(phone_input, '')), '');
  normalized_tags text[] := coalesce(
    (select array_agg(distinct lower(trim(tag)) order by lower(trim(tag))) from unnest(coalesce(tags_input, '{}'::text[])) as tag where trim(tag) <> ''),
    '{}'::text[]
  );
  has_anthropometry boolean := weight_kg_input is not null
    or height_cm_input is not null
    or waist_cm_input is not null
    or hip_cm_input is not null
    or arm_cm_input is not null
    or body_fat_percent_input is not null;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if char_length(normalized_name) < 2 then
    raise exception 'full_name_input must have at least 2 characters' using errcode = '22023';
  end if;

  loop
    attempt := attempt + 1;
    select 'P' || lpad((count(*) + attempt)::text, 4, '0')
      into next_code
      from public.patients
     where organization_id = target_organization_id;

    begin
      insert into public.patients (
        organization_id, professional_id, created_by, anonymous_code,
        full_name, email, phone, birth_date, tags
      ) values (
        target_organization_id, actor, actor, next_code,
        normalized_name, normalized_email, normalized_phone, birth_date_input, normalized_tags
      ) returning id into new_patient_id;
      exit;
    exception when unique_violation then
      if attempt >= 10 then
        raise;
      end if;
    end;
  end loop;

  insert into public.assessments (
    organization_id, patient_id, professional_id,
    objective, food_preferences, food_restrictions, allergies, clinical_notes
  ) values (
    target_organization_id, new_patient_id, actor,
    nullif(trim(coalesce(objective_input, '')), ''),
    nullif(trim(coalesce(food_preferences_input, '')), ''),
    nullif(trim(coalesce(food_restrictions_input, '')), ''),
    nullif(trim(coalesce(allergies_input, '')), ''),
    nullif(trim(coalesce(clinical_notes_input, '')), '')
  ) returning id into new_assessment_id;

  if has_anthropometry then
    insert into public.anthropometry (
      organization_id, patient_id, assessment_id, measured_at,
      weight_kg, height_cm, waist_cm, hip_cm, arm_cm, body_fat_percent, created_by
    ) values (
      target_organization_id, new_patient_id, new_assessment_id, coalesce(measured_at_input, now()),
      weight_kg_input, height_cm_input, waist_cm_input, hip_cm_input, arm_cm_input, body_fat_percent_input, actor
    );
  end if;

  insert into public.audit_events (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (
    target_organization_id, actor, 'patient_intake', 'patient', new_patient_id,
    jsonb_build_object('assessment_id', new_assessment_id, 'anthropometry', has_anthropometry)
  );

  return new_patient_id;
end;
$$;


ALTER FUNCTION "public"."create_patient_intake"("target_organization_id" "uuid", "full_name_input" "text", "email_input" "text", "phone_input" "text", "birth_date_input" "date", "tags_input" "text"[], "objective_input" "text", "food_preferences_input" "text", "food_restrictions_input" "text", "allergies_input" "text", "clinical_notes_input" "text", "weight_kg_input" numeric, "height_cm_input" numeric, "waist_cm_input" numeric, "hip_cm_input" numeric, "arm_cm_input" numeric, "body_fat_percent_input" numeric, "measured_at_input" timestamp with time zone) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plan_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "source_plan_id" "uuid",
    "name" "text" NOT NULL,
    "objective" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "snapshot" "jsonb" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "scope" "public"."plan_template_scope" DEFAULT 'organization'::"public"."plan_template_scope" NOT NULL,
    "dimensions" "jsonb" DEFAULT '{"contexts": [], "approaches": [], "objectives": [], "preferences": [], "restrictions": []}'::"jsonb" NOT NULL,
    "rules" "jsonb" DEFAULT '{"targets": {}, "guidance": []}'::"jsonb" NOT NULL,
    "catalog_key" "text",
    "status" "public"."plan_template_status" DEFAULT 'needs_review'::"public"."plan_template_status" NOT NULL,
    "provenance" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "review_notes" "text",
    CONSTRAINT "plan_templates_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "name")) <= 140))),
    CONSTRAINT "plan_templates_review_consistency" CHECK (((("status" = 'needs_review'::"public"."plan_template_status") AND ("reviewed_by" IS NULL) AND ("reviewed_at" IS NULL)) OR (("status" = ANY (ARRAY['approved'::"public"."plan_template_status", 'archived'::"public"."plan_template_status"])) AND ("reviewed_by" IS NOT NULL) AND ("reviewed_at" IS NOT NULL))))
);


ALTER TABLE "public"."plan_templates" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_plan_template_from_plan"("target_plan_id" "uuid", "target_name" "text", "target_objective" "text" DEFAULT NULL::"text", "target_tags" "text"[] DEFAULT '{}'::"text"[]) RETURNS "public"."plan_templates"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare p public.plans; snapshot jsonb; result public.plan_templates;
begin
 select * into p from public.plans where id=target_plan_id;
 if p.id is null or not private.has_organization_role(p.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 select jsonb_build_object('plan',to_jsonb(p),'versions',coalesce(jsonb_agg(to_jsonb(v) order by v.version_no),'[]'::jsonb)) into snapshot from public.plan_versions v where v.plan_id=p.id;
 insert into public.plan_templates(organization_id,source_plan_id,name,objective,tags,snapshot,created_by)
 values(p.organization_id,p.id,nullif(trim(target_name),''),nullif(trim(coalesce(target_objective,'')),''),coalesce(target_tags,'{}'),snapshot,auth.uid())
 returning * into result;
 return result;
end; $$;


ALTER FUNCTION "public"."create_plan_template_from_plan"("target_plan_id" "uuid", "target_name" "text", "target_objective" "text", "target_tags" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_plan_template_from_plan_v2"("target_plan_id" "uuid", "target_name" "text", "target_scope" "public"."plan_template_scope" DEFAULT 'personal'::"public"."plan_template_scope", "target_dimensions" "jsonb" DEFAULT '{"contexts": [], "approaches": [], "objectives": [], "preferences": [], "restrictions": []}'::"jsonb", "target_rules" "jsonb" DEFAULT '{"targets": {}, "guidance": []}'::"jsonb") RETURNS "public"."plan_templates"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."create_plan_template_from_plan_v2"("target_plan_id" "uuid", "target_name" "text", "target_scope" "public"."plan_template_scope", "target_dimensions" "jsonb", "target_rules" "jsonb") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patient_content_deliveries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "content_version_id" "uuid" NOT NULL,
    "snapshot" "jsonb" NOT NULL,
    "delivered_by" "uuid" NOT NULL,
    "delivered_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."patient_content_deliveries" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."deliver_content_to_patient"("target_version_id" "uuid", "target_patient_id" "uuid") RETURNS "public"."patient_content_deliveries"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare version_row public.content_library_versions; patient_org uuid; result public.patient_content_deliveries;
begin
 select * into version_row from public.content_library_versions where id=target_version_id;
 select organization_id into patient_org from public.patients where id=target_patient_id;
 if version_row.id is null or patient_org<>version_row.organization_id or not private.has_organization_role(version_row.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 insert into public.patient_content_deliveries(organization_id,patient_id,content_version_id,snapshot,delivered_by)
 values(version_row.organization_id,target_patient_id,version_row.id,jsonb_build_object('title',version_row.title,'body',version_row.body,'content_type',(select content_type from public.content_library_items where id=version_row.item_id),'version',version_row.version_no),auth.uid()) returning * into result;
 return result;
end; $$;


ALTER FUNCTION "public"."deliver_content_to_patient"("target_version_id" "uuid", "target_patient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_current_shopping_list"("target_patient_id" "uuid", "target_days" integer DEFAULT 7) RETURNS TABLE("item_key" "text", "description" "text", "total_grams" numeric, "occurrences" bigint)
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
begin
  if target_days not between 1 and 31 then raise exception 'O período deve ter entre 1 e 31 dias'; end if;
  if not private.can_access_patient(target_patient_id) then raise exception 'Acesso negado'; end if;
  return query
  with current_version as (
    select p.current_published_version_id id
    from public.plans p where p.patient_id=target_patient_id and p.status in ('published','scheduled')
      and p.current_published_version_id is not null order by p.published_at desc nulls last limit 1
  ), cycle as (
    select greatest(count(*),1)::integer day_count from public.plan_days d join current_version v on v.id=d.plan_version_id
  ), selected_days as (
    select d.id, count(*)::bigint repetitions
    from generate_series(0,target_days-1) g(day_number)
    join cycle c on true
    join public.plan_days d on d.day_index=(g.day_number % c.day_count)
    join current_version v on v.id=d.plan_version_id group by d.id
  )
  select coalesce(i.nutrient_snapshot->>'food_id',i.id::text) item_key,
    coalesce(i.nutrient_snapshot->>'food_name',i.description) description,
    round(sum(i.grams*sd.repetitions),2) total_grams,
    sum(sd.repetitions)::bigint occurrences
  from selected_days sd join public.meals m on m.plan_day_id=sd.id join public.meal_items i on i.meal_id=m.id
  group by coalesce(i.nutrient_snapshot->>'food_id',i.id::text),coalesce(i.nutrient_snapshot->>'food_name',i.description)
  order by 2;
end;
$$;


ALTER FUNCTION "public"."get_current_shopping_list"("target_patient_id" "uuid", "target_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_patient_drive_status"("target_patient_id" "uuid") RETURNS TABLE("status" "public"."drive_connection_status", "can_upload_photos" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target_org uuid;
begin
  if not private.can_access_patient(target_patient_id) then raise exception 'Acesso negado'; end if;
  select organization_id into target_org from public.patients where id=target_patient_id;
  return query
  select coalesce(c.status,'missing'::public.drive_connection_status), coalesce(c.status='connected',false)
  from (select target_org organization_id) o
  left join public.organization_drive_configs c on c.organization_id=o.organization_id;
end;
$$;


ALTER FUNCTION "public"."get_patient_drive_status"("target_patient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_patient_weekly_summary"("target_patient_id" "uuid", "target_days" integer DEFAULT 7) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
 select jsonb_build_object(
  'period_days',greatest(1,least(target_days,31)),
  'meal_checkins',(select count(*) from public.meal_checkins where patient_id=target_patient_id and occurred_on>=current_date-greatest(1,least(target_days,31))+1),
  'completed_meals',(select count(*) from public.meal_checkins where patient_id=target_patient_id and occurred_on>=current_date-greatest(1,least(target_days,31))+1 and state='completed'),
  'water_ml',(select coalesce(sum(amount_ml),0) from public.patient_water_logs where patient_id=target_patient_id and occurred_on>=current_date-greatest(1,least(target_days,31))+1),
  'active_goals',(select count(*) from public.patient_goals where patient_id=target_patient_id and active and starts_on<=current_date and coalesce(ends_on,current_date)>=current_date)
 )
 where private.can_access_patient(target_patient_id) or exists(select 1 from public.patients p where p.id=target_patient_id and private.has_organization_role(p.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
$$;


ALTER FUNCTION "public"."get_patient_weekly_summary"("target_patient_id" "uuid", "target_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$ select private.has_organization_role(target_organization_id, allowed_roles); $$;


ALTER FUNCTION "public"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_catalog_foods"("target_organization_id" "uuid", "target_source_id" "uuid", "target_items" "jsonb") RETURNS TABLE("id" "uuid", "name" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."import_catalog_foods"("target_organization_id" "uuid", "target_source_id" "uuid", "target_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_active_member"("target_organization_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$ select private.is_active_member(target_organization_id); $$;


ALTER FUNCTION "public"."is_active_member"("target_organization_id" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."content_library_versions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "item_id" "uuid" NOT NULL,
    "version_no" integer NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "published_by" "uuid" NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "content_library_versions_body_check" CHECK ((("char_length"(TRIM(BOTH FROM "body")) >= 2) AND ("char_length"(TRIM(BOTH FROM "body")) <= 12000)))
);


ALTER TABLE "public"."content_library_versions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."publish_content_library_version"("target_item_id" "uuid", "target_body" "text") RETURNS "public"."content_library_versions"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare item public.content_library_items; result public.content_library_versions;
begin
 select * into item from public.content_library_items where id=target_item_id;
 if item.id is null or not private.has_organization_role(item.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 insert into public.content_library_versions(organization_id,item_id,version_no,title,body,published_by)
 values(item.organization_id,item.id,(select coalesce(max(version_no),0)+1 from public.content_library_versions where item_id=item.id),item.title,nullif(trim(target_body),''),auth.uid()) returning * into result;
 update public.content_library_items set status='published',updated_at=now() where id=item.id;
 return result;
end; $$;


ALTER FUNCTION "public"."publish_content_library_version"("target_item_id" "uuid", "target_body" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."publish_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."publish_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."review_appointment"("target_id" "uuid", "target_status" "public"."appointment_status", "target_staff_note" "text" DEFAULT NULL::"text", "target_meeting_url" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target_org uuid;
begin
 perform set_config('bsnutri.appointment_rpc','on',true); select organization_id into target_org from public.appointments where id=target_id for update;
 if target_status not in('approved','rejected') then raise exception 'Decisão inválida'; end if;
 if not private.has_organization_role(target_org,array['owner','admin','nutritionist','receptionist']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 update public.appointments set status=target_status,staff_note=target_staff_note,external_meeting_url=coalesce(target_meeting_url,external_meeting_url),reviewed_by=auth.uid(),reviewed_at=now() where id=target_id;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(target_org,auth.uid(),'appointment_'||target_status::text,'appointment',target_id,'{}');
end; $$;


ALTER FUNCTION "public"."review_appointment"("target_id" "uuid", "target_status" "public"."appointment_status", "target_staff_note" "text", "target_meeting_url" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clinical_drafts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "kind" "public"."clinical_draft_kind" NOT NULL,
    "source_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "body" "text" NOT NULL,
    "provider" "text" DEFAULT 'structured-local'::"text" NOT NULL,
    "status" "public"."clinical_draft_status" DEFAULT 'draft'::"public"."clinical_draft_status" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "clinical_drafts_body_check" CHECK ((("char_length"(TRIM(BOTH FROM "body")) >= 2) AND ("char_length"(TRIM(BOTH FROM "body")) <= 12000))),
    CONSTRAINT "clinical_drafts_check" CHECK (((("status" = 'draft'::"public"."clinical_draft_status") AND ("reviewed_by" IS NULL) AND ("reviewed_at" IS NULL)) OR (("status" = ANY (ARRAY['approved'::"public"."clinical_draft_status", 'discarded'::"public"."clinical_draft_status"])) AND ("reviewed_by" IS NOT NULL) AND ("reviewed_at" IS NOT NULL))))
);


ALTER TABLE "public"."clinical_drafts" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."review_clinical_draft"("target_draft_id" "uuid", "target_status" "public"."clinical_draft_status") RETURNS "public"."clinical_drafts"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare result public.clinical_drafts;
begin
 if target_status not in ('approved','discarded') then raise exception 'Status de revisão inválido'; end if;
 update public.clinical_drafts set status=target_status,reviewed_by=auth.uid(),reviewed_at=now() where id=target_draft_id and status='draft' and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) returning * into result;
 if result.id is null then raise exception 'Rascunho indisponível'; end if;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(result.organization_id,auth.uid(),'clinical_draft_'||target_status::text,'clinical_draft',result.id,jsonb_build_object('kind',result.kind,'provider',result.provider));
 return result;
end; $$;


ALTER FUNCTION "public"."review_clinical_draft"("target_draft_id" "uuid", "target_status" "public"."clinical_draft_status") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."review_plan_template"("target_template_id" "uuid", "target_status" "public"."plan_template_status", "target_notes" "text" DEFAULT NULL::"text") RETURNS "public"."plan_templates"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare result public.plan_templates;
begin
  if target_status not in ('approved', 'archived', 'needs_review') then
    raise exception 'Status de revisão inválido';
  end if;

  update public.plan_templates
     set status = target_status,
         reviewed_by = case when target_status = 'needs_review' then null else auth.uid() end,
         reviewed_at = case when target_status = 'needs_review' then null else now() end,
         review_notes = target_notes,
         updated_at = now()
   where id = target_template_id
     and private.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[])
  returning * into result;

  if result.id is null then
    raise exception 'Modelo indisponível para revisão';
  end if;

  insert into public.audit_events (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (result.organization_id, auth.uid(), 'plan_template_' || target_status::text, 'plan_template', result.id,
          jsonb_build_object('provenance', result.provenance));

  return result;
end;
$$;


ALTER FUNCTION "public"."review_plan_template"("target_template_id" "uuid", "target_status" "public"."plan_template_status", "target_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."review_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_targets" "jsonb" DEFAULT '{}'::"jsonb", "target_assistant_state" "jsonb" DEFAULT NULL::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare target_org uuid;
begin
  perform set_config('bsnutri.workflow_rpc','on',true);
  select organization_id into target_org from public.plans where id=target_plan_id for update;
  if target_org is null or not private.has_organization_role(target_org, array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
  if not exists(select 1 from public.plan_versions where id=target_version_id and plan_id=target_plan_id and locked_at is null) then raise exception 'Versao invalida ou bloqueada'; end if;
  update public.plan_versions
    set targets=coalesce(target_targets,'{}'::jsonb),
        assistant_state=coalesce(target_assistant_state,assistant_state),
        reviewed_by=auth.uid(),
        reviewed_at=now()
    where id=target_version_id;
  perform private.validate_version_ready(target_version_id);
  update public.plan_versions
    set assistant_state=jsonb_set(assistant_state,'{completedSteps}',coalesce(assistant_state->'completedSteps','[]'::jsonb) || '["review"]'::jsonb,true)
    where id=target_version_id;
  update public.plans set status='reviewed',reviewed_by=auth.uid(),reviewed_at=now() where id=target_plan_id;
end;
$$;


ALTER FUNCTION "public"."review_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_targets" "jsonb", "target_assistant_state" "jsonb") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."substitution_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "plan_version_id" "uuid" NOT NULL,
    "meal_item_id" "uuid" NOT NULL,
    "substitution_id" "uuid" NOT NULL,
    "requested_by" "uuid" NOT NULL,
    "status" "public"."substitution_request_status" DEFAULT 'requested'::"public"."substitution_request_status" NOT NULL,
    "patient_note" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "professional_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "substitution_requests_patient_note_check" CHECK ((("patient_note" IS NULL) OR ("char_length"("patient_note") <= 500))),
    CONSTRAINT "substitution_requests_professional_note_check" CHECK ((("professional_note" IS NULL) OR ("char_length"("professional_note") <= 500)))
);


ALTER TABLE "public"."substitution_requests" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."review_substitution_request"("target_request_id" "uuid", "target_status" "public"."substitution_request_status", "target_note" "text" DEFAULT NULL::"text") RETURNS "public"."substitution_requests"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare result public.substitution_requests;
begin
  if target_status not in ('approved','rejected') then raise exception 'Decisão inválida'; end if;
  update public.substitution_requests r set status=target_status, professional_note=nullif(trim(target_note),''),
    reviewed_by=(select auth.uid()), reviewed_at=now()
  where r.id=target_request_id and r.status='requested'
    and private.has_organization_role(r.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
  returning * into result;
  if result.id is null then raise exception 'Solicitação não encontrada ou já revisada'; end if;
  return result;
end; $$;


ALTER FUNCTION "public"."review_substitution_request"("target_request_id" "uuid", "target_status" "public"."substitution_request_status", "target_note" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."form_responses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "assignment_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "version_id" "uuid" NOT NULL,
    "values" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "status" "public"."form_assignment_status" DEFAULT 'draft'::"public"."form_assignment_status" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "submitted_at" timestamp with time zone
);


ALTER TABLE "public"."form_responses" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_form_response"("target_assignment_id" "uuid", "target_values" "jsonb", "target_submit" boolean DEFAULT false) RETURNS "public"."form_responses"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare a public.form_assignments; result public.form_responses; next_status public.form_assignment_status := case when target_submit then 'submitted'::public.form_assignment_status else 'draft'::public.form_assignment_status end;
begin
 select * into a from public.form_assignments where id=target_assignment_id;
 if a.id is null or not private.can_access_patient(a.patient_id) then raise exception 'Acesso negado'; end if;
 if target_submit then perform private.assert_form_required_fields(a.version_id,target_values); end if;
 insert into public.form_responses(organization_id,assignment_id,patient_id,version_id,values,status,created_by,submitted_at)
 values(a.organization_id,a.id,a.patient_id,a.version_id,target_values,next_status,auth.uid(),case when target_submit then now() else null end)
 on conflict (assignment_id) do update set values=excluded.values,status=excluded.status,updated_at=now(),submitted_at=excluded.submitted_at
 returning * into result;
 update public.form_assignments set status=next_status,submitted_at=case when target_submit then now() else submitted_at end where id=a.id;
 return result;
end; $$;


ALTER FUNCTION "public"."save_form_response"("target_assignment_id" "uuid", "target_values" "jsonb", "target_submit" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_plan_draft"("target_organization_id" "uuid", "target_patient_id" "uuid", "target_title" "text", "target_change_summary" "text", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb", "target_created_by" "uuid" DEFAULT "auth"."uid"()) RETURNS "public"."plans"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  patient_org uuid;
  result public.plans;
  new_version uuid;
  new_day uuid;
  new_meal uuid;
  day_json jsonb;
  meal_json jsonb;
  item_json jsonb;
  day_idx integer := 0;
  meal_pos integer;
  item_pos integer;
  item_food_id uuid;
  eq_list_id uuid;
begin
  select organization_id into patient_org from public.patients where id = target_patient_id;
  if patient_org is null or patient_org <> target_organization_id
     or not private.has_organization_role(target_organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado ao paciente ou organização';
  end if;

  if jsonb_array_length(coalesce(target_days, '[]'::jsonb)) = 0 then
    raise exception 'Estrutura de dias vazia no plano';
  end if;

  insert into public.plans (organization_id, patient_id, created_by, title, status)
  values (target_organization_id, target_patient_id, coalesce(target_created_by, auth.uid()), coalesce(nullif(trim(target_title), ''), 'Plano alimentar'), 'draft')
  returning * into result;

  insert into public.plan_versions (organization_id, plan_id, version_no, created_by, change_summary, assistant_state, targets)
  values (
    target_organization_id, result.id, 1, coalesce(target_created_by, auth.uid()), coalesce(target_change_summary, 'Versão inicial'),
    coalesce(target_assistant_state, '{}'::jsonb),
    coalesce(target_targets, '{}'::jsonb)
  )
  returning id into new_version;

  for day_json in select elem from jsonb_array_elements(target_days) elem loop
    insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
    values (
      target_organization_id,
      new_version,
      coalesce((day_json->>'day_index')::integer, day_idx),
      coalesce(day_json->>'label', 'Dia ' || (day_idx + 1)),
      coalesce((day_json->>'kind')::public.day_kind, 'standard'::public.day_kind)
    )
    returning id into new_day;
    day_idx := day_idx + 1;

    meal_pos := 0;
    for meal_json in select elem from jsonb_array_elements(coalesce(day_json->'meals', '[]'::jsonb)) elem loop
      eq_list_id := null;
      if (meal_json->>'equivalencyListId') is not null and (meal_json->>'equivalencyListId') <> '' then
        eq_list_id := (meal_json->>'equivalencyListId')::uuid;
      elsif (meal_json->>'equivalency_list_id') is not null and (meal_json->>'equivalency_list_id') <> '' then
        eq_list_id := (meal_json->>'equivalency_list_id')::uuid;
      end if;

      insert into public.meals (organization_id, plan_day_id, position, label, equivalency_list_id, notes)
      values (
        target_organization_id,
        new_day,
        coalesce((meal_json->>'position')::integer, meal_pos),
        coalesce(meal_json->>'label', meal_json->>'name', 'Refeição'),
        eq_list_id,
        nullif(trim(meal_json->>'notes'), '')
      )
      returning id into new_meal;
      meal_pos := meal_pos + 1;

      item_pos := 0;
      for item_json in select elem from jsonb_array_elements(coalesce(meal_json->'items', '[]'::jsonb)) elem loop
        item_food_id := nullif(coalesce(item_json->>'food_id', item_json->>'foodId', ''), '')::uuid;

        insert into public.meal_items (
          organization_id,
          meal_id,
          position,
          food_id,
          description,
          quantity,
          unit,
          grams,
          nutrient_snapshot
        )
        values (
          target_organization_id,
          new_meal,
          coalesce((item_json->>'position')::integer, item_pos),
          item_food_id,
          coalesce(item_json->>'description', item_json->>'name', 'Item alimentar'),
          coalesce((item_json->>'grams')::numeric(12,4), 100),
          'g',
          coalesce((item_json->>'grams')::numeric(12,4), 100),
          coalesce(item_json->'nutrientsPer100g', item_json->'nutrient_snapshot', '{}'::jsonb)
        );

        item_pos := item_pos + 1;
      end loop;
    end loop;
  end loop;

  return result;
end;
$$;


ALTER FUNCTION "public"."save_plan_draft"("target_organization_id" "uuid", "target_patient_id" "uuid", "target_title" "text", "target_change_summary" "text", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb", "target_created_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."seed_plan_templates_dietbox"("target_organization_id" "uuid", "target_created_by" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  actor uuid := coalesce(auth.uid(), target_created_by);
  model jsonb;
begin
  if auth.uid() is not null and not private.has_organization_role(target_organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado';
  end if;
  if actor is null then
    raise exception 'created_by obrigatório';
  end if;

  for model in select jsonb_array_elements($data$[{"name":"Dieta 1.800 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1800 kcal","20% ptn"],"snapshot":{"dietboxId":26642622,"originalName":"Dieta 1.800 Kcal (20% PTN)","kcalTotal":1805,"summary":{"energyKcal":1804.8,"proteinG":91.6,"carbohydrateG":273.9,"fatG":40.9,"fiberG":20.2,"sodiumMg":1678,"calciumMg":923.3,"ironMg":16.2,"potassiumMg":2520.6},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":165,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Pequeno"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":12,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"2 Ponta De Faca"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Castanha do Pará sem sal","grams":4,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 1"},{"food":"Uva passa","grams":24,"macros":{"energyKcal":300,"proteinG":3.23,"carbohydrateG":79.1,"fatG":0.46,"fiberG":3.47,"sodiumMg":12,"calciumMg":49,"ironMg":2.09,"potassiumMg":751},"measure":"1 Punhado (24g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada, de legumes, cozida no vapor","grams":60,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Colher de Sopa: 3"},{"food":"Peito de galinha ou frango Cozido(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"File: 1"},{"food":"Espaguete, cozido, enriquecido, com sal","grams":270,"macros":{"energyKcal":141,"proteinG":4.77,"carbohydrateG":28.34,"fatG":0.67,"fiberG":1.7,"sodiumMg":100,"calciumMg":7,"ironMg":1.4,"potassiumMg":31},"measure":"3 Pegador"},{"food":"Molho de tomate","grams":60,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43},"measure":"3 Colher de sopa (20g)"},{"food":"Chocolate, meio amargo","grams":15,"macros":{"energyKcal":474.92,"proteinG":4.86,"carbohydrateG":62.42,"fatG":29.86,"fiberG":4.94,"sodiumMg":8.87,"calciumMg":44.67,"ironMg":3.61,"potassiumMg":431.7},"measure":"Pedaço: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"},{"food":"Pão de queijo","grams":30,"macros":{"energyKcal":363,"proteinG":5.1,"carbohydrateG":34.2,"fatG":24.6,"fiberG":0.6,"sodiumMg":773,"calciumMg":102,"ironMg":0.3,"potassiumMg":93},"measure":"3 Unidade Pequena"}],"time":"15:00"},{"name":"Jantar","items":[{"food":"Blanquet de peru","grams":10,"macros":{"energyKcal":126,"proteinG":17.5,"carbohydrateG":2.04,"fatG":4.84,"fiberG":0.2,"sodiumMg":1114,"calciumMg":8,"ironMg":2.34,"potassiumMg":287},"measure":"Fatia: 1"},{"food":"Queijo prato","grams":30,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"2 Fatia"},{"food":"Requeijão light","grams":24,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"4 Ponta De Faca"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Alface, americana, crua","grams":15,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 3"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Suco de uva integral","grams":165,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"1 Copo pequeno (165ml)"}],"time":"20:00","notes":"Alface e tomate à vontade"},{"name":"Ceia","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"},{"food":"Aveia em flocos","grams":14,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"2 Colher De Sobremesa"}],"time":"23:00"},{"name":"Lanche da tarde 2","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"},{"food":"Canela em pó","grams":1,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"1 Colher de café (1,2g)"}],"time":"18:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1800},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta de Carga Glicêmica Leve e Hiperproteica 1.900 Kcal","objective":"Cardápio clínico para plano hiperproteico — adaptar à avaliação nutricional do paciente.","tags":["1900 kcal","glycemic_load"],"snapshot":{"dietboxId":26642585,"originalName":"Dieta de Carga Glicêmica Leve e Hiperproteica 1.900 Kcal","kcalTotal":1932,"summary":{"energyKcal":1932.3,"proteinG":150.4,"carbohydrateG":205,"fatG":58.4,"fiberG":23.1,"sodiumMg":1823.2,"calciumMg":601.2,"ironMg":15.4,"potassiumMg":3545.9},"meals":[{"name":"Café da manhã","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Café sem açúcar","grams":150,"macros":{"energyKcal":6.5,"proteinG":0.33,"carbohydrateG":1.11,"fatG":0.01,"fiberG":0,"sodiumMg":0.04,"calciumMg":5.75,"ironMg":0.13,"potassiumMg":95.35},"measure":"infusão) (Mililitro (1ml): 150"},{"food":"Melancia","grams":200,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.55,"fatG":0.15,"fiberG":0.4,"sodiumMg":1,"calciumMg":7,"ironMg":0.24,"potassiumMg":112},"measure":"Fatia: 1"},{"food":"Suco de laranja sem açúcar","grams":165,"macros":{"energyKcal":45,"proteinG":0.7,"carbohydrateG":10.41,"fatG":0.2,"fiberG":0.2,"sodiumMg":1,"calciumMg":11,"ironMg":0.2,"potassiumMg":200},"measure":"Copo pequeno (165ml): 1"}],"time":"06:00"},{"name":"Colação","items":[{"food":"Maçã orgânica","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1) ou pera  (Unidade: 1) ou Kiwi  (Copo Grande: 1","subs":[{"food":"pera","grams":130,"macros":{"energyKcal":58,"proteinG":0.38,"carbohydrateG":15.46,"fatG":0.12,"fiberG":3.16,"sodiumMg":1,"calciumMg":9,"ironMg":0.17,"potassiumMg":119}},{"food":"Kiwi","grams":125,"macros":{"energyKcal":61,"proteinG":1.14,"carbohydrateG":14.66,"fatG":0.52,"fiberG":3,"sodiumMg":3,"calciumMg":34,"ironMg":0.31,"potassiumMg":312}}]},{"food":"Castanha de caju, crua, s/ sal","grams":10,"macros":{"energyKcal":582,"proteinG":18.2,"carbohydrateG":30.2,"fatG":43.8,"fiberG":3.3,"sodiumMg":12,"calciumMg":37,"ironMg":6.68,"potassiumMg":660},"measure":"Grama: 10"}],"time":"09:00"},{"name":"Lanche da tarde","items":[{"food":"Iogurte natural desnatado - Danone®","grams":170,"macros":{"energyKcal":48.65,"proteinG":4.32,"carbohydrateG":7.03,"fatG":0,"fiberG":0,"sodiumMg":72.97,"calciumMg":151.35,"ironMg":0,"potassiumMg":0},"measure":"Pote (170g): 1"},{"food":"Banana, prata, crua","grams":180,"macros":{"energyKcal":98.25,"proteinG":1.27,"carbohydrateG":25.96,"fatG":0.07,"fiberG":2.04,"sodiumMg":0,"calciumMg":7.56,"ironMg":0.38,"potassiumMg":357.68},"measure":"Unidade Pequena: 2"}],"time":"16:00"},{"name":"Lanche da tarde 2","items":[{"food":"Peito de galinha ou frango Cozido(a) (Grama: 20) Desfiado","grams":20,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247}},{"food":"Requeijão light","grams":30,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sopa: 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Cenoura (crua) (Grama: 20) Ralada","grams":20,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323}}],"time":"17:00"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 3"},{"food":"Salmão grelhado N.FIT","grams":150,"macros":{"energyKcal":192,"proteinG":23,"carbohydrateG":0,"fatG":11,"fiberG":0,"sodiumMg":302,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 150"},{"food":"Seleta","grams":30,"macros":{"energyKcal":47,"proteinG":2.53,"carbohydrateG":9.06,"fatG":0.26,"fiberG":2.8,"sodiumMg":482.78,"calciumMg":22.65,"ironMg":0.79,"potassiumMg":176.05},"measure":"jardineira)  (Grama: 30"},{"food":"Salada ou verdura crua, exceto de fruta","grams":120,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Colher De Arroz/Servir: 2"},{"food":"Mandioca Assado(a)","grams":30,"macros":{"energyKcal":125,"proteinG":0.6,"carbohydrateG":30.1,"fatG":0.3,"fiberG":1.6,"sodiumMg":1,"calciumMg":19,"ironMg":0.1,"potassiumMg":100},"measure":"Grama: 30"}],"time":"21:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 3"},{"food":"Feijão cozido","grams":52,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Colher de sopa (26,2g): 2"},{"food":"Bife grelhado de contra filé","grams":200,"macros":{"energyKcal":195,"proteinG":30.4,"carbohydrateG":0,"fatG":7.21,"fiberG":0,"sodiumMg":66,"calciumMg":11,"ironMg":3.37,"potassiumMg":403},"measure":"Unidade média (100g): 2) ou Filé de frango grelhado (Filé grande (190g): 1","subs":[{"food":"Filé de frango grelhado","grams":190,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23}}]},{"food":"Cenoura","grams":25,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (Colher de sopa cheia (picada) (25g): 1"},{"food":"Brócolis","grams":26,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Colher de sopa picado (13,23g): 2"}],"time":"12:30"}]},"dimensions":{"approaches":["glycemic_load"],"objectives":["high_protein"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1900},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Low Carb - 1500 kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","low_carb"],"snapshot":{"dietboxId":26642602,"originalName":"Dieta Low Carb - 1500 kcal","kcalTotal":1506,"summary":{"energyKcal":1506.2,"proteinG":145.4,"carbohydrateG":129.9,"fatG":46.6,"fiberG":29.8,"sodiumMg":1414.6,"calciumMg":547.4,"ironMg":11.5,"potassiumMg":3445.3},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha Cozido(a)","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Pão, trigo, forma, integral","grams":30,"macros":{"energyKcal":253.19,"proteinG":9.43,"carbohydrateG":49.94,"fatG":3.65,"fiberG":6.88,"sodiumMg":506.1,"calciumMg":131.76,"ironMg":2.99,"potassiumMg":162.87},"measure":"Fatia (30g): 1"},{"food":"Queijo, cottage, magro, 1% gordura","grams":20,"macros":{"energyKcal":72,"proteinG":12.39,"carbohydrateG":2.72,"fatG":1.02,"fiberG":0,"sodiumMg":406,"calciumMg":61,"ironMg":0.14,"potassiumMg":86},"measure":"Grama: 20"},{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia pequena (100g): 1"}],"time":"08:30"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Carne, boi, acém, moída, refogada","grams":120,"macros":{"energyKcal":213,"proteinG":25.5,"carbohydrateG":0.71,"fatG":12.1,"fiberG":0.13,"sodiumMg":263,"calciumMg":5.79,"ironMg":2.15,"potassiumMg":320},"measure":"c/ óleo, cebola e alho), c/ sal (Grama: 120"},{"food":"Arroz branco","grams":80,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 80"},{"food":"Feijão, preto, cozido","grams":80,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"concha: 1"}],"time":"12:00"},{"name":"Jantar","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Batata doce, cozido, assada com casca, com sal","grams":60,"macros":{"energyKcal":90,"proteinG":2.01,"carbohydrateG":20.71,"fatG":0.15,"fiberG":3.3,"sodiumMg":246,"calciumMg":38,"ironMg":0.69,"potassiumMg":475},"measure":"Grama: 60"},{"food":"Peito de galinha ou frango Refogado(a)","grams":120,"macros":{"energyKcal":195.66,"proteinG":30.91,"carbohydrateG":0,"fatG":7.07,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 120"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sobremesa: 1"}],"time":"19:30"},{"name":"Lanche da tarde","items":[{"food":"Whey Protein Concentrado DUX - Baunilha","grams":56,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 2"},{"food":"Morango, congelado, sem adoçante","grams":100,"macros":{"energyKcal":35,"proteinG":0.43,"carbohydrateG":9.13,"fatG":0.11,"fiberG":2.1,"sodiumMg":2,"calciumMg":16,"ironMg":0.75,"potassiumMg":148},"measure":"Grama: 100"},{"food":"Leite, vaca, desnatado, UHT, Vigor","grams":150,"macros":{"energyKcal":39,"proteinG":2.98,"carbohydrateG":5.95,"fatG":0.36,"fiberG":0,"sodiumMg":51.4,"calciumMg":134,"ironMg":0,"potassiumMg":140},"measure":"Grama: 150"},{"food":"Psyllium - Vitao Alimentos","grams":5,"macros":{"energyKcal":70,"proteinG":6,"carbohydrateG":8,"fatG":0,"fiberG":70,"sodiumMg":150,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 5"}],"time":"16:00"}]},"dimensions":{"approaches":["low_carb"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio APLV - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26962417,"originalName":"Cardápio APLV - opção 1","kcalTotal":1516,"summary":{"energyKcal":1515.8,"proteinG":102.5,"carbohydrateG":155.6,"fatG":56.9,"fiberG":21,"sodiumMg":754.2,"calciumMg":294.4,"ironMg":8.8,"potassiumMg":2638.5},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de amêndoas","grams":200,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 200"},{"food":"Aveia em flocos","grams":20,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 20"},{"food":"Banana","grams":70,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Grama: 70"},{"food":"Proteína Vegana","grams":20,"macros":{"energyKcal":382.9,"proteinG":53.3,"carbohydrateG":28.9,"fatG":6,"fiberG":3.6,"sodiumMg":468.9,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Morango","grams":60,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média: 5"},{"food":"Pasta de Amendoim","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Canela em pó (Colher de café: 1) - opcional","grams":1,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500}}],"time":"08:00","notes":"Sugestão: mingau de aveia com bana e morango + pasta de amendoim"},{"name":"Almoço","items":[{"food":"Batata, inglesa, cozida","grams":120,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Grama: 120"},{"food":"Peixe, água doce, Tilápia, cozido","grams":120,"macros":{"energyKcal":112,"proteinG":23.1,"carbohydrateG":0,"fatG":2.12,"fiberG":0,"sodiumMg":76.9,"calciumMg":26.1,"ironMg":0.37,"potassiumMg":391},"measure":"Grama: 120"},{"food":"Gergelim, semente","grams":9,"macros":{"energyKcal":583.55,"proteinG":21.16,"carbohydrateG":21.62,"fatG":50.43,"fiberG":11.87,"sodiumMg":2.58,"calciumMg":825.45,"ironMg":5.45,"potassiumMg":546.29},"measure":"Colher de sopa: 1"},{"food":"Legumes assados/cozidos/refogados..","grams":100,"macros":{"energyKcal":46,"proteinG":1.73,"carbohydrateG":10.6,"fatG":0.25,"fiberG":2.97,"sodiumMg":124,"calciumMg":31.2,"ironMg":0.42,"potassiumMg":270}},{"food":"Azeite de oliva","grams":4,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de chá: 2"}],"time":"12:00","notes":"Sugestão: peixe com crosta de gergelim + batata e legumes"},{"name":"Sobremesa","items":[{"food":"Nuts","grams":15,"macros":{"energyKcal":560,"proteinG":19.33,"carbohydrateG":26.67,"fatG":42,"fiberG":6,"sodiumMg":40,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Fruta","grams":26,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Fatia: 1"}],"time":"12:39","notes":"Sugestão: nuts + fruta"},{"name":"Sobremesa","items":[{"food":"Damasco seco","grams":14,"macros":{"energyKcal":238,"proteinG":3.66,"carbohydrateG":61.8,"fatG":0.46,"fiberG":7.8,"sodiumMg":10,"calciumMg":45,"ironMg":4.71,"potassiumMg":1378},"measure":"Unidade: 2"},{"food":"Castanha de caju","grams":6,"macros":{"energyKcal":574,"proteinG":15.31,"carbohydrateG":32.69,"fatG":46.35,"fiberG":3,"sodiumMg":16,"calciumMg":45,"ironMg":6,"potassiumMg":565},"measure":"Unidade: 3"}],"time":"19:30"},{"name":"Jantar","items":[{"food":"Frango, peito, cozido","grams":80,"macros":{"energyKcal":162.87,"proteinG":31.47,"carbohydrateG":0,"fatG":3.16,"fiberG":0,"sodiumMg":36.17,"calciumMg":6.44,"ironMg":0.34,"potassiumMg":231.05},"measure":"Grama: 80"},{"food":"Cebola, molho de tomate, temeperos - à gosto","grams":30,"macros":{"energyKcal":40,"proteinG":1.1,"carbohydrateG":9.34,"fatG":0.1,"fiberG":1.93,"sodiumMg":4,"calciumMg":23,"ironMg":0.21,"potassiumMg":146}},{"food":"Requeijão vegetal, c/ bebida à base de castanha de caju, c/ sal","grams":20,"macros":{"energyKcal":160,"proteinG":3.72,"carbohydrateG":19.6,"fatG":7.77,"fiberG":1.37,"sodiumMg":216,"calciumMg":15.5,"ironMg":1.38,"potassiumMg":175},"measure":"Grama: 20"},{"food":"Arroz branco","grams":80,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 80"},{"food":"Salada de alface, tomate, cenoura...","grams":64,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Azeite de oliva","grams":4,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Cha: 2"}],"time":"19:00","notes":"Sugestão: strogonoff de frango com requeijão de castanha de caju e salada"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Aveia em flocos","grams":20,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 20"},{"food":"Banana","grams":70,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Grama: 70"},{"food":"Pasta de Amendoim","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"15:00","notes":"Sugestão: bolo de banana ou panqueca e banana "}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1516},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio APLV - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26963446,"originalName":"Cardápio APLV - opção 2","kcalTotal":1551,"summary":{"energyKcal":1551.3,"proteinG":99.3,"carbohydrateG":159.3,"fatG":58,"fiberG":23.5,"sodiumMg":920.3,"calciumMg":221.4,"ironMg":9.7,"potassiumMg":2456.9},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Aveia em flocos","grams":10,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 10"},{"food":"Tapioca de goma","grams":10,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Avocado","grams":20,"macros":{"energyKcal":161,"proteinG":2,"carbohydrateG":8.53,"fatG":14.7,"fiberG":6.7,"sodiumMg":7,"calciumMg":12,"ironMg":0.55,"potassiumMg":485},"measure":"Grama: 20"},{"food":"Tomate cereja","grams":50,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade: 5"},{"food":"Fruta","grams":26,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Fatia: 1"},{"food":"Granola","grams":10,"macros":{"energyKcal":354.3,"proteinG":11.3,"carbohydrateG":47.5,"fatG":13.3,"fiberG":3,"sodiumMg":277.5,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"08:00","notes":"Sugestão: panqueca salgada recheada de avocado e tomate + fruta com granola"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":100,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 100"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g"},{"food":"Peixe não especificado","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (1 File"},{"food":"Brócolis cozido/assado/refogado","grams":40,"macros":{"energyKcal":35,"proteinG":2.38,"carbohydrateG":7.18,"fatG":0.41,"fiberG":3.3,"sodiumMg":41,"calciumMg":40,"ironMg":0.67,"potassiumMg":293}},{"food":"Salada ou verdura crua, exceto de fruta","grams":120,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"2 Escumadeira"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml"}],"time":"12:00"},{"name":"Sobremesa","items":[{"food":"Goiabada Cremosa Zero Adição de Açúcares","grams":50,"macros":{"energyKcal":70,"proteinG":0,"carbohydrateG":15,"fatG":0,"fiberG":1.5,"sodiumMg":35,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Unidade: 1"}],"time":"13:00"},{"name":"Sobremesa","items":[{"food":"Kiwi","grams":94,"macros":{"energyKcal":61,"proteinG":1.14,"carbohydrateG":14.66,"fatG":0.52,"fiberG":3,"sodiumMg":3,"calciumMg":34,"ironMg":0.31,"potassiumMg":312},"measure":"Unidade: 1"},{"food":"Cacau Nibs","grams":10,"macros":{"energyKcal":613.33,"proteinG":9.33,"carbohydrateG":42.67,"fatG":44.67,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"19:30"},{"name":"Jantar","items":[{"food":"Macarrão  Cozido(a)","grams":100,"macros":{"energyKcal":158,"proteinG":5.8,"carbohydrateG":30.86,"fatG":0.93,"fiberG":1.8,"sodiumMg":1,"calciumMg":7,"ironMg":1.28,"potassiumMg":44},"measure":"Grama: 100"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Carne moída","grams":80,"macros":{"energyKcal":214,"proteinG":26.62,"carbohydrateG":0,"fatG":11.1,"fiberG":0,"sodiumMg":61,"calciumMg":13,"ironMg":2.89,"potassiumMg":300},"measure":"Grama: 80"},{"food":"Cebola, temperos - à gosto..","grams":30,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157}},{"food":"Azeite de oliva","grams":4,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de chá: 2"},{"food":"Salada de alface, tomate, cenoura...","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"19:00"},{"name":"Lanche da tarde","items":[{"food":"Aveia em flocos","grams":20,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 20"},{"food":"Leite de amêndoas","grams":200,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 200"},{"food":"Proteína Vegana","grams":20,"macros":{"energyKcal":382.9,"proteinG":53.3,"carbohydrateG":28.9,"fatG":6,"fiberG":3.6,"sodiumMg":468.9,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Pasta de Amendoim","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Maçã","grams":90,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade Pequena: 1"}],"time":"15:00","notes":"Sugestão: mingau proteico de maçã"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1551},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Centro-Oeste - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26963857,"originalName":"Cardápio Centro-Oeste - opção 1","kcalTotal":1806,"summary":{"energyKcal":1805.8,"proteinG":113.6,"carbohydrateG":207.8,"fatG":58.1,"fiberG":25.6,"sodiumMg":2915.9,"calciumMg":600.6,"ironMg":8.9,"potassiumMg":2206.2},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Tapioca de goma","grams":30,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 30"},{"food":"Queijo muçarela","grams":20,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Sementes","grams":10,"macros":{"energyKcal":386.67,"proteinG":19.33,"carbohydrateG":4.67,"fatG":32,"fiberG":35.33,"sodiumMg":20,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"08:00","notes":"Sugestão: pão de queijo de frigideira + fruta com sementes"},{"name":"Almoço","items":[{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Feijão carioca","grams":100,"macros":{"energyKcal":103,"proteinG":6,"carbohydrateG":18,"fatG":1,"fiberG":5,"sodiumMg":129,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 100"},{"food":"Filé de frango/carne grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Unidade: 1"},{"food":"Abobora com quiabo","grams":80,"macros":{"energyKcal":21,"proteinG":1.3,"carbohydrateG":4.71,"fatG":0.14,"fiberG":1.8,"sodiumMg":3.5,"calciumMg":46,"ironMg":0.43,"potassiumMg":0},"measure":"Colher De Sopa: 4"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sobremesa: 1"},{"food":"Salada de alface, tomate, cenoura...","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"12:00"},{"name":"Sobremesa","items":[{"food":"Baru","grams":10,"macros":{"energyKcal":300,"proteinG":5.6,"carbohydrateG":58.4,"fatG":3.4,"fiberG":29.5,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Fruta","grams":52,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Fatia: 2"}],"time":"13:00","notes":"Sugestão: fruta + baru"},{"name":"Lanche da tarde","items":[{"food":"Bolo de milho","grams":60,"macros":{"energyKcal":346.72,"proteinG":4.43,"carbohydrateG":34.32,"fatG":21.92,"fiberG":1.05,"sodiumMg":207.49,"calciumMg":53.56,"ironMg":1.79,"potassiumMg":151.39},"measure":"Grama: 60"},{"food":"Morango","grams":70,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade pequena: 10"},{"food":"Leite de vaca desnatado","grams":200,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Grama: 200"},{"food":"Whey Protein","grams":15,"macros":{"energyKcal":404.3,"proteinG":66.7,"carbohydrateG":18.7,"fatG":7,"fiberG":0,"sodiumMg":380,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"}],"time":"15:00","notes":"Sugestão: bolo de milho + batida proteica"},{"name":"Sobremesa","items":[{"food":"Baru/ Outra castanha ou nuts","grams":10,"macros":{"energyKcal":300,"proteinG":5.6,"carbohydrateG":58.4,"fatG":3.4,"fiberG":29.5,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Fruta","grams":52,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Fatia: 2"}],"time":"19:30","notes":"Sugestão: fruta + baru"},{"name":"Jantar","items":[{"food":"Arroz tipo Galinhada","grams":150,"macros":{"energyKcal":143.5,"proteinG":4.47,"carbohydrateG":23.93,"fatG":3.07,"fiberG":0.65,"sodiumMg":534.1,"calciumMg":16.96,"ironMg":1.18,"potassiumMg":99.56},"measure":"Grama: 150"},{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 2"},{"food":"Alface","grams":32,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Escumadeira: 2"},{"food":"Frango, cozido","grams":80,"macros":{"energyKcal":162.87,"proteinG":31.47,"carbohydrateG":0,"fatG":3.16,"fiberG":0,"sodiumMg":36.17,"calciumMg":6.44,"ironMg":0.34,"potassiumMg":231.05},"measure":"Grama: 80"}],"time":"19:00","notes":"Sugestão: galinhada + salada com vinagrete"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1806},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Centro-Oeste - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26964477,"originalName":"Cardápio Centro-Oeste - opção 2","kcalTotal":1631,"summary":{"energyKcal":1631,"proteinG":95.4,"carbohydrateG":206.7,"fatG":50.6,"fiberG":20.9,"sodiumMg":1895.9,"calciumMg":295.2,"ironMg":9.4,"potassiumMg":2383},"meals":[{"name":"Café da manhã","items":[{"food":"Pão de queijo","grams":40,"macros":{"energyKcal":363,"proteinG":5.1,"carbohydrateG":34.2,"fatG":24.6,"fiberG":0.6,"sodiumMg":773,"calciumMg":102,"ironMg":0.3,"potassiumMg":93},"measure":"Unidade: 2"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"}],"time":"08:00","notes":"Sugestão: pães de queijo + ovos mexidos + porção de fruta"},{"name":"Almoço","items":[{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Unidade: 1"},{"food":"Pequi","grams":15,"macros":{"energyKcal":110.34,"proteinG":1.35,"carbohydrateG":18.54,"fatG":4.4,"fiberG":4.43,"sodiumMg":0,"calciumMg":24.97,"ironMg":1.09,"potassiumMg":0},"measure":"para temperar o frango"},{"food":"Mandioca cozida","grams":100,"macros":{"energyKcal":125,"proteinG":0.6,"carbohydrateG":30.1,"fatG":0.3,"fiberG":1.6,"sodiumMg":1,"calciumMg":19,"ironMg":0.1,"potassiumMg":100},"measure":"Grama: 100"},{"food":"Quiabo  Cozido(a)","grams":80,"macros":{"energyKcal":22,"proteinG":1.87,"carbohydrateG":4.51,"fatG":0.21,"fiberG":2.5,"sodiumMg":6,"calciumMg":77,"ironMg":0.28,"potassiumMg":135},"measure":"Colher De Arroz/Servir: 1"},{"food":"Feijão cozido","grams":70,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Colher de servir: 1"},{"food":"Salada de alface, tomate, vegetais...","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"12:00","notes":"Sugestão: frango com pequi e quiabo, mandioca e feijão + salada"},{"name":"Sobremesa","items":[{"food":"Mamão verde, doce em calda, drenado","grams":30,"macros":{"energyKcal":209.38,"proteinG":0.32,"carbohydrateG":57.64,"fatG":0.1,"fiberG":1.23,"sodiumMg":4.74,"calciumMg":12.44,"ironMg":0.15,"potassiumMg":8.67},"measure":"Grama: 30"}],"time":"13:00"},{"name":"Lanche da tarde","items":[{"food":"Pamonha","grams":160,"macros":{"energyKcal":171,"proteinG":2.6,"carbohydrateG":30.7,"fatG":4.8,"fiberG":2.4,"sodiumMg":132,"calciumMg":4,"ironMg":0.4,"potassiumMg":125},"measure":"Unidade: 1"},{"food":"Whey Protein","grams":20,"macros":{"energyKcal":404.3,"proteinG":66.7,"carbohydrateG":18.7,"fatG":7,"fiberG":0,"sodiumMg":380,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Fruta","grams":78,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Fatia: 3"},{"food":"Água","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Grama: 200"}],"time":"15:00","notes":"Sugestão: Pamonha doce ou salgada + batida proteica"},{"name":"Jantar","items":[{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Carne bovina magra","grams":80,"macros":{"energyKcal":185.19,"proteinG":28.73,"carbohydrateG":0,"fatG":6.92,"fiberG":0,"sodiumMg":65.07,"calciumMg":5.01,"ironMg":2.95,"potassiumMg":386.39},"measure":"patinho, filé mignon, alcatra, coxão mole..) (Grama: 80"},{"food":"Cebola","grams":20,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"Colher de sopa cheia: 2"},{"food":"Legumes assados/cozidos/ refogados","grams":100,"macros":{"energyKcal":46,"proteinG":1.73,"carbohydrateG":10.6,"fatG":0.25,"fiberG":2.97,"sodiumMg":124,"calciumMg":31.2,"ironMg":0.42,"potassiumMg":270}},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa: 1"}],"time":"19:00","notes":"Sugestão: carreteiro de uma panela"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1631},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Nordeste - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26840286,"originalName":"Cardápio Nordeste - opção 1","kcalTotal":1824,"summary":{"energyKcal":1824,"proteinG":79.5,"carbohydrateG":234.4,"fatG":66.2,"fiberG":22.4,"sodiumMg":2125,"calciumMg":608.9,"ironMg":11.5,"potassiumMg":2290.1},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Cuscuz de milho","grams":40,"macros":{"energyKcal":243.88,"proteinG":4.54,"carbohydrateG":49.84,"fatG":3.53,"fiberG":3.46,"sodiumMg":63.06,"calciumMg":1.67,"ironMg":1.42,"potassiumMg":36.65},"measure":"Grama: 40"},{"food":"Banana","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.) Cru(a) (Unidade: 1"},{"food":"Queijo, coalho","grams":15,"macros":{"energyKcal":335,"proteinG":23.7,"carbohydrateG":1.94,"fatG":25.9,"fiberG":0,"sodiumMg":526,"calciumMg":731,"ironMg":0.23,"potassiumMg":126},"measure":"Grama: 15"},{"food":"Mix de Sementes","grams":10,"macros":{"energyKcal":526.67,"proteinG":16.67,"carbohydrateG":42.67,"fatG":32.67,"fiberG":0,"sodiumMg":720,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sobremesa: 1"}],"time":"08:00","notes":"Sugestões:\n-Cuscuz cozido + ovos cozidos + queijo grelhado + fruta com sementes por cima\n-Cuscuz + ovo = colocar os ovos na frigideira e depois o cuscuz, deixar cozinhar, adicionar sal temperos e o queijo. Consumir a fruta com as sementes."},{"name":"Almoço","items":[{"food":"Arroz","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Feijão-de-corda","grams":140,"macros":{"energyKcal":121.33,"proteinG":3.17,"carbohydrateG":20.32,"fatG":3.13,"fiberG":5,"sodiumMg":4,"calciumMg":128,"ironMg":1.12,"potassiumMg":418},"measure":"Concha: 1"},{"food":"Carne de sol acebolada","grams":80,"macros":{"energyKcal":238.07,"proteinG":17.69,"carbohydrateG":2.88,"fatG":16.88,"fiberG":0.55,"sodiumMg":1267.58,"calciumMg":16.16,"ironMg":1.3,"potassiumMg":107.67},"measure":"Grama: 80"},{"food":"Abóbora, legumes - à vontade","grams":100,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230}},{"food":"Alface, tomate, cenoura... - à vontade","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"12:00","notes":"Pode substituir a porção de carne por:\n- 1 filé de frango médio grelhado com pouco de gordura \n- 2 filés de peixe médio grelhados com pouco de gordura \n- 2 ovos cozidos, mexidos... \n\n------\n\nAssim como a porção de arroz pode ser substituída pode:\n-100g de macarrão cozido\n-150g de batata inglesa \n-120g de batata doce cozida"},{"name":"Lanche da tarde","items":[{"food":"Farinha de Fubá","grams":30,"macros":{"energyKcal":362,"proteinG":8.13,"carbohydrateG":76.9,"fatG":3.6,"fiberG":7.3,"sodiumMg":35,"calciumMg":6,"ironMg":3.46,"potassiumMg":287},"measure":"Grama: 30"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Coco fresco ralado","grams":10,"macros":{"energyKcal":354,"proteinG":3.34,"carbohydrateG":15.2,"fatG":33.5,"fiberG":9.4,"sodiumMg":20,"calciumMg":14,"ironMg":2.44,"potassiumMg":356},"measure":"Grama: 10"},{"food":"Melado, mel ou adoçante à gosto","grams":5,"macros":{"energyKcal":296.51,"proteinG":0,"carbohydrateG":76.62,"fatG":0,"fiberG":0,"sodiumMg":4.01,"calciumMg":102.06,"ironMg":5.39,"potassiumMg":395.06}},{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote 110 g: 1"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"}],"time":"16:00","notes":"Sugestão: Bolo de fubá com coco + iogurte com fruta \n-Misturar a farinha de fubá com o coco ralado fresco e os ovos. Levar para um recipiente que vai ao forno/ microoondas/ airfryer. Tempo de cozimento de acordo com cada equipamento e poteência.\n-Consumir junto com o bolo, a fruta."},{"name":"Jantar","items":[{"food":"Tapioca de goma","grams":60,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 60"},{"food":"Frango desfiado","grams":80,"macros":{"energyKcal":115,"proteinG":17,"carbohydrateG":7,"fatG":2,"fiberG":2,"sodiumMg":312,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 80"},{"food":"Milho","grams":24,"macros":{"energyKcal":160.14,"proteinG":3.32,"carbohydrateG":25.11,"fatG":7.18,"fiberG":4.25,"sodiumMg":244.96,"calciumMg":3.15,"ironMg":0.45,"potassiumMg":212.05},"measure":"em grão)  (Colher De Sopa: 1"},{"food":"Requeijão","grams":15,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sobremesa: 1) - ou Queijo (Fatia: 1"},{"food":"Alface, tomate, cenoura..","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"legumes e folhas à vontade"}],"time":"19:00","notes":"Sugestão: \n-Tapioca de frango e milho com salada"},{"name":"Lanche da manhã","items":[{"food":"Caju","grams":90,"macros":{"energyKcal":46,"proteinG":0.8,"carbohydrateG":11.6,"fatG":0.2,"fiberG":1.5,"sodiumMg":0,"calciumMg":4,"ironMg":1,"potassiumMg":0},"measure":"Unidade média: 1"},{"food":"Castanha de caju","grams":10,"macros":{"energyKcal":574,"proteinG":15.31,"carbohydrateG":32.69,"fatG":46.35,"fiberG":3,"sodiumMg":16,"calciumMg":45,"ironMg":6,"potassiumMg":565},"measure":"Unidade: 5"}],"time":"10:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1824},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Nordeste - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26849817,"originalName":"Cardápio Nordeste - opção 2","kcalTotal":1686,"summary":{"energyKcal":1686.3,"proteinG":97.3,"carbohydrateG":200.2,"fatG":54.8,"fiberG":22.9,"sodiumMg":2567.6,"calciumMg":550.4,"ironMg":8.2,"potassiumMg":1667.4},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Legumes / vegetais (cenoura, tomate) - opcional","grams":50,"macros":{"energyKcal":53,"proteinG":1,"carbohydrateG":7,"fatG":2,"fiberG":2,"sodiumMg":148,"calciumMg":0,"ironMg":0,"potassiumMg":0}},{"food":"Queijo, coalho (Grama: 30) - ou outro queijo de sua preferência","grams":30,"macros":{"energyKcal":335,"proteinG":23.7,"carbohydrateG":1.94,"fatG":25.9,"fiberG":0,"sodiumMg":526,"calciumMg":731,"ironMg":0.23,"potassiumMg":126}},{"food":"Banana da terra","grams":100,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"Grama: 100"},{"food":"Mix de nuts","grams":10,"macros":{"energyKcal":560,"proteinG":19.33,"carbohydrateG":26.67,"fatG":42,"fiberG":6,"sodiumMg":40,"calciumMg":0,"ironMg":0,"potassiumMg":0}}],"time":"08:00","notes":"Sugestão:\n- Omelete com legumes (ex: cenoura ralada ou tomate) + banana da terra grelhada com nuts e queijo coalho grelhado."},{"name":"Almoço","items":[{"food":"Baião de dois","grams":150,"macros":{"energyKcal":138,"proteinG":2.9,"carbohydrateG":26.2,"fatG":2.1,"fiberG":0.3,"sodiumMg":0,"calciumMg":7,"ironMg":0.5,"potassiumMg":0},"measure":"Grama: 150"},{"food":"Frango grelhado","grams":80,"macros":{"energyKcal":134,"proteinG":25,"carbohydrateG":1,"fatG":3,"fiberG":0,"sodiumMg":341,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 80"},{"food":"Abóbora Cozida/ Legumes cozidos, assados, refogados...","grams":100,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230}},{"food":"Alface, tomate, cenoura... - à vontade","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Cuscuz de milho","grams":50,"macros":{"energyKcal":243.88,"proteinG":4.54,"carbohydrateG":49.84,"fatG":3.53,"fiberG":3.46,"sodiumMg":63.06,"calciumMg":1.67,"ironMg":1.42,"potassiumMg":36.65},"measure":"Grama: 50"},{"food":"Frango desfiado com cenoura e milho","grams":80,"macros":{"energyKcal":115,"proteinG":17,"carbohydrateG":7,"fatG":2,"fiberG":2,"sodiumMg":312,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 80"},{"food":"Queijo","grams":20,"macros":{"energyKcal":240,"proteinG":17.6,"carbohydrateG":10.6,"fatG":14.1,"fiberG":0,"sodiumMg":1587,"calciumMg":529,"ironMg":0.2,"potassiumMg":330},"measure":"Fatia: 2) ou Rqueijão (Colher de sobremesa: 1"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Mix de nuts","grams":10,"macros":{"energyKcal":560,"proteinG":19.33,"carbohydrateG":26.67,"fatG":42,"fiberG":6,"sodiumMg":40,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"16:00","notes":"Sugestão:\n-Cuscuz recheado com frango desfiado e queijo + porção de frutas com nuts\n\n*pode substituit o frango por 2 ovos ou 20g de whey protein (para bater com frutas por exemplo)"},{"name":"Ceia","items":[{"food":"Caju","grams":160,"macros":{"energyKcal":46,"proteinG":0.8,"carbohydrateG":11.6,"fatG":0.2,"fiberG":1.5,"sodiumMg":0,"calciumMg":4,"ironMg":1,"potassiumMg":0},"measure":"Unidade pequena: 2"},{"food":"Chocolate 70% cacau","grams":15,"macros":{"energyKcal":618.18,"proteinG":6.82,"carbohydrateG":36.36,"fatG":36.36,"fiberG":20.91,"sodiumMg":9.09,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"}],"time":"20:00"},{"name":"Jantar","items":[{"food":"Arroz","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Feijão-de-corda","grams":80,"macros":{"energyKcal":121.33,"proteinG":3.17,"carbohydrateG":20.32,"fatG":3.13,"fiberG":5,"sodiumMg":4,"calciumMg":128,"ironMg":1.12,"potassiumMg":418},"measure":"Grama: 80"},{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 2"},{"food":"Frango grelhado","grams":80,"macros":{"energyKcal":134,"proteinG":25,"carbohydrateG":1,"fatG":3,"fiberG":0,"sodiumMg":341,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 80"},{"food":"Alface, tomate, cenoura, chuchu... - à vontade","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"19:00","notes":"Sugestões:\n-Pode substituir a porção de arroz pela mesma quantidade de macaxeira ou macarrão cozido\n-Pode substituir a mesma porção de frango por outra proteína como carne bovina, ou 2 ovos"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1686},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio sem glúten - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26960891,"originalName":"Cardápio sem glúten - opção 1","kcalTotal":1769,"summary":{"energyKcal":1769,"proteinG":90.9,"carbohydrateG":159.8,"fatG":86.4,"fiberG":30.4,"sodiumMg":1511.6,"calciumMg":386.9,"ironMg":9.7,"potassiumMg":2799.7},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Biscoito de arroz pequeno","grams":16,"macros":{"energyKcal":376.67,"proteinG":8.67,"carbohydrateG":80,"fatG":2,"fiberG":2.67,"sodiumMg":336.67,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Unidade: 8"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Chia em Grãos","grams":15,"macros":{"energyKcal":386.67,"proteinG":19.33,"carbohydrateG":4.67,"fatG":32,"fiberG":35.33,"sodiumMg":20,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"}],"time":"08:00","notes":"Sugestão: biscoito de arroz + ovos mexidos e fruta + chia"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":100,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 100"},{"food":"Lentilha, cozida","grams":80,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"1 Concha"},{"food":"Ovo poché","grams":100,"macros":{"energyKcal":149,"proteinG":12.4,"carbohydrateG":1.23,"fatG":9.99,"fiberG":0,"sodiumMg":122,"calciumMg":49,"ironMg":1.44,"potassiumMg":120},"measure":"2 Unidades"},{"food":"Couve-flor","grams":50,"macros":{"energyKcal":23,"proteinG":1.85,"carbohydrateG":4.12,"fatG":0.45,"fiberG":1.73,"sodiumMg":15,"calciumMg":16,"ironMg":0.33,"potassiumMg":142},"measure":"cozida"},{"food":"Brócolis","grams":13,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido"},{"food":"Cenoura","grams":12,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (1 Colher de sopa ralada (12g)"},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222}},{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0}}],"time":"12:00","notes":"Sugestão: Arroz integral, lentilha, ovo poche e vegetais"},{"name":"Lanche da tarde","items":[{"food":"Mamão papaia","grams":150,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia pequena: 1,5"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Frango desfiado cremoso","grams":70,"macros":{"energyKcal":124,"proteinG":18,"carbohydrateG":4,"fatG":4,"fiberG":0,"sodiumMg":252,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa: 3"},{"food":"Tapioca de goma","grams":37.5,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 2,5"}],"time":"15:00","notes":"Sugestão: crepioca de frango "},{"name":"Sobremesa","items":[{"food":"Chocolate 70% cacau","grams":15,"macros":{"energyKcal":618.18,"proteinG":6.82,"carbohydrateG":36.36,"fatG":36.36,"fiberG":20.91,"sodiumMg":9.09,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"}],"time":"12:30"},{"name":"Sobremesa","items":[{"food":"Nuts","grams":10,"macros":{"energyKcal":716,"proteinG":7.79,"carbohydrateG":12.83,"fatG":76.08,"fiberG":8,"sodiumMg":265,"calciumMg":70,"ironMg":2.65,"potassiumMg":363},"measure":"Grama: 10"},{"food":"Fruta","grams":78,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"}],"time":"19:30"},{"name":"Jantar","items":[{"food":"Espaguete de abobrinha","grams":230,"macros":{"energyKcal":47.29,"proteinG":1.17,"carbohydrateG":4.54,"fatG":3.18,"fiberG":1.32,"sodiumMg":0.23,"calciumMg":16.84,"ironMg":0.27,"potassiumMg":247.59},"measure":"Porção: 1"},{"food":"Carne moída","grams":75,"macros":{"energyKcal":293.11,"proteinG":24.09,"carbohydrateG":0.86,"fatG":20.83,"fiberG":0.13,"sodiumMg":411.33,"calciumMg":13.75,"ironMg":2.45,"potassiumMg":301.72},"measure":"refogada) (Colher de sopa cheia (25g): 3"},{"food":"Seleta","grams":34,"macros":{"energyKcal":47,"proteinG":2.53,"carbohydrateG":9.06,"fatG":0.26,"fiberG":2.8,"sodiumMg":482.78,"calciumMg":22.65,"ironMg":0.79,"potassiumMg":176.05},"measure":"jardineira)  (Porção: 1"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Queijo ralado","grams":8,"macros":{"energyKcal":431,"proteinG":38.46,"carbohydrateG":4.06,"fatG":28.61,"fiberG":0,"sodiumMg":1529,"calciumMg":1109,"ironMg":0.9,"potassiumMg":125},"measure":"Colher De Sobremesa: 1"}],"time":"19:00","notes":"Sugestão: espaguete de abobrinha à bolanhesa"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["gluten_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1769},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio sem glúten e sem lactose - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26961327,"originalName":"Cardápio sem glúten e sem lactose - opção 1","kcalTotal":1590,"summary":{"energyKcal":1590.2,"proteinG":116.3,"carbohydrateG":192.4,"fatG":42.8,"fiberG":35.4,"sodiumMg":1510.4,"calciumMg":358.1,"ironMg":9.9,"potassiumMg":3315.6},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Biscoito de arroz","grams":16,"macros":{"energyKcal":376.67,"proteinG":8.67,"carbohydrateG":80,"fatG":2,"fiberG":2.67,"sodiumMg":336.67,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Unidade: 8"},{"food":"Fruta","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Leite de amêndoas","grams":150,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 150"},{"food":"Chia em Grãos","grams":10,"macros":{"energyKcal":386.67,"proteinG":19.33,"carbohydrateG":4.67,"fatG":32,"fiberG":35.33,"sodiumMg":20,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"08:00","notes":"Sugestão: ovos mexidos + bolacha de arroz + batida com leite vegetal e fruta com chia"},{"name":"Almoço","items":[{"food":"Chuchu, cozido","grams":72,"macros":{"energyKcal":18.54,"proteinG":0.41,"carbohydrateG":4.79,"fatG":0,"fiberG":1.04,"sodiumMg":1.81,"calciumMg":7.83,"ironMg":0.06,"potassiumMg":54.35},"measure":"Colher De Sopa Cheia : 4"},{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé pequeno (100g) : 1"},{"food":"Batata doce cozida sem sal","grams":126,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Colher de sopa cheia (picada) (42g) : 3"},{"food":"Beterraba, cozida","grams":40,"macros":{"energyKcal":32.15,"proteinG":1.29,"carbohydrateG":7.23,"fatG":0.09,"fiberG":1.88,"sodiumMg":22.76,"calciumMg":15.26,"ironMg":0.24,"potassiumMg":245.48},"measure":"Colher de Sopa Cheia Picada (20g) : 2"},{"food":"Cenoura, cozida","grams":54,"macros":{"energyKcal":29.86,"proteinG":0.85,"carbohydrateG":6.69,"fatG":0.22,"fiberG":2.63,"sodiumMg":7.88,"calciumMg":25.62,"ironMg":0.09,"potassiumMg":175.51},"measure":"Colher De Sopa Cheia : 3"}],"time":"12:00","notes":"Sugetsão: frango grelhado com legumes e batata doce"},{"name":"Sobremesa","items":[{"food":"Linhaça, semente","grams":10,"macros":{"energyKcal":453,"proteinG":14.1,"carbohydrateG":43.3,"fatG":32.3,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211,"ironMg":4.7,"potassiumMg":869},"measure":"Colher de sobremesa rasa : 1"},{"food":"Abacaxi, polpa, in natura","grams":150,"macros":{"energyKcal":50,"proteinG":0.68,"carbohydrateG":11.6,"fatG":0.33,"fiberG":1.12,"sodiumMg":2.84,"calciumMg":18.4,"ironMg":0.47,"potassiumMg":137},"measure":"Pedaço/ Unidade/ Fatia (M) : 2"},{"food":"Canela, pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.85,"fatG":3.19,"fiberG":54.3,"sodiumMg":26,"calciumMg":1228,"ironMg":38.07,"potassiumMg":500},"measure":"colher de chá : 1"}],"time":"13:00"},{"name":"Sobremesa","items":[{"food":"Morango, in natura","grams":24,"macros":{"energyKcal":30,"proteinG":0.82,"carbohydrateG":6.54,"fatG":0.4,"fiberG":1.67,"sodiumMg":11,"calciumMg":15.4,"ironMg":0.28,"potassiumMg":102},"measure":"Unidade(s): 3"},{"food":"Chá de camomila","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Copo(s) americano(s): 1"},{"food":"Uva, Rubi","grams":24,"macros":{"energyKcal":49.06,"proteinG":0.61,"carbohydrateG":12.7,"fatG":0.16,"fiberG":0.93,"sodiumMg":7.92,"calciumMg":7.62,"ironMg":0.17,"potassiumMg":158.89},"measure":"Unidade(s): 3"},{"food":"Castanha do Brasil, crua","grams":12,"macros":{"energyKcal":674,"proteinG":14.5,"carbohydrateG":15.1,"fatG":63.5,"fiberG":7.93,"sodiumMg":0.4,"calciumMg":162,"ironMg":2.98,"potassiumMg":625},"measure":"Unidade(s): 3"}],"time":"19:30"},{"name":"Lanche da tarde","items":[{"food":"Batata doce cozida sem sal","grams":140,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Unidade média (140g): 1"},{"food":"Sal e pimenta à gosto","grams":1,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":39000,"calciumMg":0,"ironMg":0,"potassiumMg":0}},{"food":"Filé de frango (cozido e desfiado) - 4 colheres de sopa","grams":72,"macros":{"energyKcal":163.67,"proteinG":30.59,"carbohydrateG":0.25,"fatG":3.53,"fiberG":0.02,"sodiumMg":370.13,"calciumMg":16.35,"ironMg":1.05,"potassiumMg":255.3}},{"food":"Farelo de aveia - 2 colheres de sopa","grams":22,"macros":{"energyKcal":350,"proteinG":20,"carbohydrateG":50,"fatG":10,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":5,"potassiumMg":0}}],"time":"15:00","notes":"Cozinhe a batata doce e amasse formando um purê. Divida em 4 partes e faça bolinhas, recheando com o frango. Empane na farinha de aveia e asse em forno pré aquecido à 180 graus até dourarem/"},{"name":"Jantar","items":[{"food":"Peixe não especificado","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Assado(a) (File: 1"},{"food":"Batata","grams":100,"macros":{"energyKcal":87,"proteinG":1.88,"carbohydrateG":20.1,"fatG":0.1,"fiberG":1.8,"sodiumMg":4,"calciumMg":5,"ironMg":0.31,"potassiumMg":379},"measure":"cozida) (Grama: 100"},{"food":"Pimentão","grams":18,"macros":{"energyKcal":20,"proteinG":0.86,"carbohydrateG":4.64,"fatG":0.17,"fiberG":1.7,"sodiumMg":3,"calciumMg":10,"ironMg":0.34,"potassiumMg":175},"measure":"Fatia: 3"},{"food":"Cebola","grams":30,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"Unidade pequena (30g): 1"},{"food":"Cenoura","grams":120,"macros":{"energyKcal":41,"proteinG":0.93,"carbohydrateG":9.58,"fatG":0.24,"fiberG":2.8,"sodiumMg":69,"calciumMg":33,"ironMg":0.3,"potassiumMg":320},"measure":"Unidade: 1"},{"food":"Limão","grams":84,"macros":{"energyKcal":30,"proteinG":0.7,"carbohydrateG":10.54,"fatG":0.2,"fiberG":2.8,"sodiumMg":2,"calciumMg":33,"ironMg":0.6,"potassiumMg":102},"measure":"comum, galego, etc.)  (Unidade: 1"}],"time":"19:00","notes":"Tempere o peixe com o limão, sal e pimenta à gosto. Disponha em uma forma com as rodelas de cebola, batata, pimentão e cenoura. Leve assar em forno pré aquecido a 180 graus por cerca de 40 minutos."}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["gluten_free","lactose_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1590},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio sem glúten e sem lactose - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26961904,"originalName":"Cardápio sem glúten e sem lactose - opção 2","kcalTotal":1470,"summary":{"energyKcal":1469.6,"proteinG":109.3,"carbohydrateG":148.4,"fatG":51.3,"fiberG":27.3,"sodiumMg":1371,"calciumMg":240.3,"ironMg":8.7,"potassiumMg":3016},"meals":[{"name":"Café da manhã","items":[{"food":"Tapioca de goma","grams":25,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 25"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Avocado","grams":30,"macros":{"energyKcal":161,"proteinG":2,"carbohydrateG":8.53,"fatG":14.7,"fiberG":6.7,"sodiumMg":7,"calciumMg":12,"ironMg":0.55,"potassiumMg":485},"measure":"Grama: 30"},{"food":"Tomate","grams":15,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Colher de sopa cheia em cubos: 1"},{"food":"Café","grams":300,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0.47,"fatG":0.02,"fiberG":0.47,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49.05},"measure":"Caneca: 1"},{"food":"Proteína Vegana","grams":10,"macros":{"energyKcal":382.9,"proteinG":53.3,"carbohydrateG":28.9,"fatG":6,"fiberG":3.6,"sodiumMg":468.9,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"08:00","notes":"Sugestão: café proteico + crepioca com avocado e tomate"},{"name":"Almoço","items":[{"food":"Batata","grams":150,"macros":{"energyKcal":87,"proteinG":1.88,"carbohydrateG":20.1,"fatG":0.1,"fiberG":1.8,"sodiumMg":4,"calciumMg":5,"ironMg":0.31,"potassiumMg":379},"measure":"cozida) (Grama: 150"},{"food":"Carne bovina, patinho, sem gordura, crua","grams":80,"macros":{"energyKcal":133,"proteinG":22,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":49,"calciumMg":3,"ironMg":1.8,"potassiumMg":318},"measure":"Grama: 80"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Cebola, tomate, legumes e temperos - à gosto","grams":20,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157}},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de café: 2"},{"food":"Salada de alface, tomate, cenoura...","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"12:00","notes":"Sugestão: escondidinho de batata com carne moída + salada "},{"name":"Sobremesa","items":[{"food":"Tâmara","grams":10,"macros":{"energyKcal":311,"proteinG":2,"carbohydrateG":80.1,"fatG":0.2,"fiberG":9.7,"sodiumMg":14,"calciumMg":47,"ironMg":2.6,"potassiumMg":730},"measure":"Grama: 10"},{"food":"Morango","grams":12,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média: 1"},{"food":"Pasta de Amendoim","grams":5,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 5"}],"time":"12:30","notes":"Sugestão: bombom de tâmara"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 80"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé médio (140g"},{"food":"Brócolis","grams":26,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido"},{"food":"Cenoura","grams":24,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua"},{"food":"Alface","grams":20,"macros":{"energyKcal":18,"proteinG":1.31,"carbohydrateG":3.51,"fatG":0.3,"fiberG":1.27,"sodiumMg":9,"calciumMg":68,"ironMg":1.4,"potassiumMg":264}},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222}}],"time":"19:00"},{"name":"Sobremesa","items":[{"food":"Tâmara","grams":10,"macros":{"energyKcal":311,"proteinG":2,"carbohydrateG":80.1,"fatG":0.2,"fiberG":9.7,"sodiumMg":14,"calciumMg":47,"ironMg":2.6,"potassiumMg":730},"measure":"Grama: 10"},{"food":"Morango","grams":12,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média: 1"},{"food":"Pasta de Amendoim","grams":5,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 5"}],"time":"19:30","notes":"Sugestão: bombom de tâmara"},{"name":"Lanche da tarde","items":[{"food":"Morango","grams":60,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média: 5"},{"food":"Mamão, Papaia, cru","grams":135,"macros":{"energyKcal":40.16,"proteinG":0.46,"carbohydrateG":10.44,"fatG":0.12,"fiberG":1.04,"sodiumMg":1.63,"calciumMg":22.42,"ironMg":0.19,"potassiumMg":126.15},"measure":"Metade: 1"},{"food":"Kiwi","grams":76,"macros":{"energyKcal":61,"proteinG":0.99,"carbohydrateG":14.9,"fatG":0.44,"fiberG":1.9,"sodiumMg":5,"calciumMg":26,"ironMg":0.41,"potassiumMg":332},"measure":"Unidade média: 1"},{"food":"Proteína Vegetal","grams":20,"macros":{"energyKcal":333.7,"proteinG":60,"carbohydrateG":13.1,"fatG":4.6,"fiberG":9.7,"sodiumMg":562.9,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Chia em Grãos","grams":10,"macros":{"energyKcal":386.67,"proteinG":19.33,"carbohydrateG":4.67,"fatG":32,"fiberG":35.33,"sodiumMg":20,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Pasta de Amendoim","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Leite de amêndoas","grams":200,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 200"}],"time":"15:00","notes":"Sugestão: smoothie de frutas proteico com pasta de amendoime chia"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["gluten_free","lactose_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1470},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio sem glúten - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26971995,"originalName":"Cardápio sem glúten - opção 2","kcalTotal":1676,"summary":{"energyKcal":1676,"proteinG":92.1,"carbohydrateG":184,"fatG":63.4,"fiberG":30.2,"sodiumMg":1147,"calciumMg":208.8,"ironMg":5.8,"potassiumMg":2651.4},"meals":[{"name":"Café da manhã","items":[{"food":"Pão sem Glúten","grams":50,"macros":{"energyKcal":194,"proteinG":3.4,"carbohydrateG":34,"fatG":5,"fiberG":1,"sodiumMg":340,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia: 2"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Pasta de Amendoim","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10) ou Nuts (Grama: 10"}],"time":"08:00","notes":"Sugestão: ovos mexidos ou cozidos com pão sem glúten, porção de rutas com nuts ou pasta de amendoim"},{"name":"Almoço","items":[{"food":"Cenoura Cozido(a)","grams":75,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"Colher De Sopa: 3"},{"food":"Arroz integral","grams":100,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Grama: 100"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Almôndega de frango","grams":80,"macros":{"energyKcal":130.77,"proteinG":16.99,"carbohydrateG":5.75,"fatG":4.34,"fiberG":1.45,"sodiumMg":329.59,"calciumMg":15.36,"ironMg":0.65,"potassiumMg":243.68},"measure":"Grama: 80"},{"food":"Brócolis cozido","grams":50,"macros":{"energyKcal":35,"proteinG":2.38,"carbohydrateG":7.18,"fatG":0.41,"fiberG":3.3,"sodiumMg":41,"calciumMg":40,"ironMg":0.67,"potassiumMg":293},"measure":"Colher de sopa: 3"},{"food":"Azeite de oliva","grams":4,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Cha: 2"}],"time":"12:00","notes":"Sugestão: arroz integral, almôndegas de frango ao molho de tomate com vegetais."},{"name":"Lanche da tarde","items":[{"food":"Tapioca de goma","grams":22.5,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 1,5"},{"food":"Frango desfiado cremoso","grams":80,"macros":{"energyKcal":124,"proteinG":18,"carbohydrateG":4,"fatG":4,"fiberG":0,"sodiumMg":252,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa: 4"},{"food":"Abacaxi","grams":75,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113},"measure":"Fatia média: 1"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"}],"time":"15:00","notes":"Sugestão: Crepioca de frango desfiado cremoso + abacaxi (ou outra fruta de sua preferência)"},{"name":"Jantar","items":[{"food":"Manga","grams":50,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":2.77,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156},"measure":"Grama: 50"},{"food":"Frango, em tiras/desfiado/grelhado..","grams":80,"macros":{"energyKcal":162.87,"proteinG":31.47,"carbohydrateG":0,"fatG":3.16,"fiberG":0,"sodiumMg":36.17,"calciumMg":6.44,"ironMg":0.34,"potassiumMg":231.05},"measure":"Grama: 80"},{"food":"Cebola roxa","grams":10,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"Colher de sopa cheia: 1"},{"food":"Alface","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Avocado","grams":60,"macros":{"energyKcal":161,"proteinG":2,"carbohydrateG":8.53,"fatG":14.7,"fiberG":6.7,"sodiumMg":7,"calciumMg":12,"ironMg":0.55,"potassiumMg":485},"measure":"Grama: 60"},{"food":"Cenoura","grams":36,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Colher de sopa ralada: 3"}],"time":"19:00","notes":"Sugestão: poke caseiro de frango"},{"name":"Sobremesa","items":[{"food":"Chocolate 70% cacau","grams":15,"macros":{"energyKcal":618.18,"proteinG":6.82,"carbohydrateG":36.36,"fatG":36.36,"fiberG":20.91,"sodiumMg":9.09,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"}],"time":"12:30"},{"name":"Sobremesa","items":[{"food":"Chocolate 70% cacau","grams":15,"macros":{"energyKcal":618.18,"proteinG":6.82,"carbohydrateG":36.36,"fatG":36.36,"fiberG":20.91,"sodiumMg":9.09,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"}],"time":"19:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["gluten_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1676},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio sem lactose - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26952842,"originalName":"Cardápio sem lactose - opção 1","kcalTotal":1589,"summary":{"energyKcal":1588.9,"proteinG":86.8,"carbohydrateG":170.2,"fatG":63.8,"fiberG":22.1,"sodiumMg":752.6,"calciumMg":257.4,"ironMg":12.4,"potassiumMg":2190.7},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Pão de forma","grams":42,"macros":{"energyKcal":285.71,"proteinG":9.52,"carbohydrateG":52.38,"fatG":4.76,"fiberG":4.76,"sodiumMg":0,"calciumMg":0,"ironMg":0.95,"potassiumMg":0},"measure":"Fatia: 2"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Mix de sementes","grams":15,"macros":{"energyKcal":41,"proteinG":1.75,"carbohydrateG":8.36,"fatG":0.54,"fiberG":2.17,"sodiumMg":0,"calciumMg":18,"ironMg":0.37,"potassiumMg":350},"measure":"Grama: 15"}],"time":"08:00","notes":"Sugestão: \n1) patê de ovos + pão tostado + porção de frutas com sementes \n2) ovos mexidos + pão tostado + porção de frutas com sementes \n3) omelete com vegetais/ temperos + pão tostado + porção de frutas com sementes "},{"name":"Almoço","items":[{"food":"Arroz integral","grams":126,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (2 Colher de arroz cheia (63g)"},{"food":"Lentilha, cozida","grams":80,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"1 Concha"},{"food":"Ovo poché","grams":100,"macros":{"energyKcal":149,"proteinG":12.4,"carbohydrateG":1.23,"fatG":9.99,"fiberG":0,"sodiumMg":122,"calciumMg":49,"ironMg":1.44,"potassiumMg":120},"measure":"2 Unidade (50g)"},{"food":"Salada de alface, tomate, cenoura...","grams":80,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml)"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Banana","grams":80,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Grama: 80"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 15"},{"food":"Pasta de Amendoim","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"15:00","notes":"Sugestão: panqueca de banana ou bolinhos de micro-ondas de banana. \nopcional: canela para finalizar"},{"name":"Jantar","items":[{"food":"Macarrão  Cozido(a)","grams":100,"macros":{"energyKcal":158,"proteinG":5.8,"carbohydrateG":30.86,"fatG":0.93,"fiberG":1.8,"sodiumMg":1,"calciumMg":7,"ironMg":1.28,"potassiumMg":44},"measure":"Grama: 100"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Patinho","grams":80,"macros":{"energyKcal":185.19,"proteinG":28.73,"carbohydrateG":0,"fatG":6.92,"fiberG":0,"sodiumMg":65.07,"calciumMg":5.01,"ironMg":2.95,"potassiumMg":386.39},"measure":"carne bovina crua) (Grama: 80"},{"food":"Cebola, temperos, sal...","grams":20,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"à gosto"},{"food":"Azeite de oliva","grams":4,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de chá: 2"},{"food":"Salada de alface, tomate, cenoura..","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"19:00"},{"name":"Sobremesa","items":[{"food":"Tâmara","grams":10,"macros":{"energyKcal":311,"proteinG":2,"carbohydrateG":80.1,"fatG":0.2,"fiberG":9.7,"sodiumMg":14,"calciumMg":47,"ironMg":2.6,"potassiumMg":730},"measure":"Grama: 10"},{"food":"Pasta de Amendoim","grams":5,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 5"},{"food":"Morango","grams":12,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média: 1"}],"time":"12:30","notes":"Sugestão: bombom de tâmara com morango"},{"name":"Sobremesa","items":[{"food":"Paçoca zero/normal/açúcar mascavo","grams":18,"macros":{"energyKcal":472.17,"proteinG":10.35,"carbohydrateG":64.04,"fatG":21.53,"fiberG":3.89,"sodiumMg":3.07,"calciumMg":32.87,"ironMg":1.72,"potassiumMg":290.53},"measure":"Unidade: 1"}],"time":"19:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["lactose_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1589},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio sem lactose - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26960442,"originalName":"Cardápio sem lactose - opção 2","kcalTotal":1692,"summary":{"energyKcal":1692,"proteinG":111.8,"carbohydrateG":183.5,"fatG":58.3,"fiberG":22.9,"sodiumMg":1226.7,"calciumMg":383.5,"ironMg":14.4,"potassiumMg":2825},"meals":[{"name":"Café da manhã","items":[{"food":"Tofu","grams":150,"macros":{"energyKcal":61,"proteinG":6.55,"carbohydrateG":1.8,"fatG":3.69,"fiberG":0.2,"sodiumMg":8,"calciumMg":111,"ironMg":1.11,"potassiumMg":120},"measure":"Grama: 150"},{"food":"Leite de amêndoas","grams":50,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 50"},{"food":"Cúrcuma, sal, temperos - à gosto","grams":1,"macros":{"energyKcal":354,"proteinG":7.83,"carbohydrateG":64.9,"fatG":9.88,"fiberG":21.1,"sodiumMg":37.8,"calciumMg":183,"ironMg":41.4,"potassiumMg":2525}},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Semente de Abóbora","grams":15,"macros":{"energyKcal":526.67,"proteinG":16.67,"carbohydrateG":42.67,"fatG":32.67,"fiberG":0,"sodiumMg":720,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Pão de forma","grams":21,"macros":{"energyKcal":285.71,"proteinG":9.52,"carbohydrateG":52.38,"fatG":4.76,"fiberG":4.76,"sodiumMg":0,"calciumMg":0,"ironMg":0.95,"potassiumMg":0},"measure":"Fatia: 1"}],"time":"08:00","notes":"Sugestão: tofu mexido + finalização com semente de abóbora + toast + porção de fruta\n\n*para o tofu mexido, basta esmagar a peça de tofu com um garfo e na panela, adicionar o leite vegetal aos poucos para dar cremosidade."},{"name":"Almoço","items":[{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g"},{"food":"Peixe não especificado","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (1 File"},{"food":"Brócolis Ao vinagrete","grams":40,"macros":{"energyKcal":35,"proteinG":2.38,"carbohydrateG":7.18,"fatG":0.41,"fiberG":3.3,"sodiumMg":41,"calciumMg":40,"ironMg":0.67,"potassiumMg":293},"measure":"40 Grama"},{"food":"Salada ou verdura crua, exceto de fruta","grams":120,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"2 Escumadeira"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Tapioca de goma","grams":20,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Pasta de Amendoim - Eat Clean","grams":10,"macros":{"energyKcal":577.3,"proteinG":20,"carbohydrateG":31.3,"fatG":41.3,"fiberG":7.3,"sodiumMg":25.3,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Morango","grams":60,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Colher de sobremesa picado: 4"},{"food":"Aveia em flocos","grams":10,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 10"}],"time":"15:00"},{"name":"Jantar","items":[{"food":"Carne, bovina, filé mingnon, sem gordura, grelhado","grams":100,"macros":{"energyKcal":219.7,"proteinG":32.8,"carbohydrateG":0,"fatG":8.83,"fiberG":0,"sodiumMg":57.91,"calciumMg":4.31,"ironMg":2.87,"potassiumMg":325.98},"measure":"Bife : 1"},{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Couve-flor","grams":60,"macros":{"energyKcal":23,"proteinG":1.85,"carbohydrateG":4.12,"fatG":0.45,"fiberG":1.73,"sodiumMg":15,"calciumMg":16,"ironMg":0.33,"potassiumMg":142},"measure":"cozida) (Ramo médio (60g) : 1"},{"food":"Salada de lentilha","grams":50,"macros":{"energyKcal":138.35,"proteinG":9.59,"carbohydrateG":23.15,"fatG":1.58,"fiberG":11.04,"sodiumMg":107.2,"calciumMg":36.03,"ironMg":3.42,"potassiumMg":427.15},"measure":"Porção : 0,5"}],"time":"19:00","notes":"Sugestão: Arroz, filé mignon, salada de lentilha e couve-flor"},{"name":"Sobremesa","items":[{"food":"Morango, in natura","grams":24,"macros":{"energyKcal":30,"proteinG":0.82,"carbohydrateG":6.54,"fatG":0.4,"fiberG":1.67,"sodiumMg":11,"calciumMg":15.4,"ironMg":0.28,"potassiumMg":102},"measure":"Unidade(s): 3"},{"food":"Chá de camomila","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Copo(s) americano(s): 1"},{"food":"Uva, Rubi","grams":24,"macros":{"energyKcal":49.06,"proteinG":0.61,"carbohydrateG":12.7,"fatG":0.16,"fiberG":0.93,"sodiumMg":7.92,"calciumMg":7.62,"ironMg":0.17,"potassiumMg":158.89},"measure":"Unidade(s): 3"},{"food":"Castanha do Brasil, crua","grams":12,"macros":{"energyKcal":674,"proteinG":14.5,"carbohydrateG":15.1,"fatG":63.5,"fiberG":7.93,"sodiumMg":0.4,"calciumMg":162,"ironMg":2.98,"potassiumMg":625},"measure":"Unidade(s): 3"}],"time":"19:30"},{"name":"Sobremesa","items":[{"food":"Banana","grams":70,"macros":{"energyKcal":140,"proteinG":1.44,"carbohydrateG":33.7,"fatG":0.24,"fiberG":1.53,"sodiumMg":0,"calciumMg":3.28,"ironMg":0.29,"potassiumMg":328},"measure":"Grama: 70"},{"food":"Melado de cana","grams":2,"macros":{"energyKcal":306,"proteinG":0,"carbohydrateG":76.6,"fatG":0,"fiberG":0,"sodiumMg":8.16,"calciumMg":111,"ironMg":3.7,"potassiumMg":330},"measure":"Grama: 2"}],"time":"12:30","notes":"1. Leve a banana para grelhar na frigideira sem óleo;\n2. Adicione o melado por cima."}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["lactose_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1692},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Sudeste - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26972826,"originalName":"Cardápio Sudeste - opção 1","kcalTotal":1498,"summary":{"energyKcal":1497.6,"proteinG":109.7,"carbohydrateG":183.2,"fatG":38.2,"fiberG":20.6,"sodiumMg":1422.6,"calciumMg":746.4,"ironMg":10.9,"potassiumMg":2578.9},"meals":[{"name":"Café da manhã","items":[{"food":"Pão francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"Unidade: 1) ou Pão de forma (Fatia: 2"},{"food":"Requeijão Light","grams":20,"macros":{"energyKcal":188,"proteinG":13,"carbohydrateG":2.5,"fatG":14,"fiberG":0,"sodiumMg":140,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Queijo muçarela","grams":20,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1) ou Ovo de galinha (Unidade: 1"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"},{"food":"Iogurte desnatado","grams":100,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Grama: 100"}],"time":"08:00","notes":"Sugestão: Misto de queijo e requeijão + fruta com iogurte"},{"name":"Almoço","items":[{"food":"Alface, tomate, cenoura..","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Azeite de oliva","grams":1,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de café: 1"},{"food":"Frango, cozido","grams":100,"macros":{"energyKcal":162.87,"proteinG":31.47,"carbohydrateG":0,"fatG":3.16,"fiberG":0,"sodiumMg":36.17,"calciumMg":6.44,"ironMg":0.34,"potassiumMg":231.05},"measure":"Grama: 100"},{"food":"Quiabo","grams":200,"macros":{"energyKcal":22,"proteinG":1.87,"carbohydrateG":4.51,"fatG":0.21,"fiberG":2.5,"sodiumMg":6,"calciumMg":77,"ironMg":0.28,"potassiumMg":135},"measure":"Colher De Sopa: 5"},{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Cebola","grams":20,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"Colher de sopa cheia: 2"}],"time":"12:00","notes":"Sugestão: frango com quiabo, arroz e salada"},{"name":"Lanche da tarde","items":[{"food":"Pão de forma","grams":42,"macros":{"energyKcal":285.71,"proteinG":9.52,"carbohydrateG":52.38,"fatG":4.76,"fiberG":4.76,"sodiumMg":0,"calciumMg":0,"ironMg":0.95,"potassiumMg":0},"measure":"Fatia: 2"},{"food":"Queijo muçarela","grams":20,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1"},{"food":"Alface","grams":10,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Folha: 1"},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Fatia grande: 1"},{"food":"Frango desfiado com cenoura e milho","grams":60,"macros":{"energyKcal":115,"proteinG":17,"carbohydrateG":7,"fatG":2,"fiberG":2,"sodiumMg":312,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 60"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porção: 1"}],"time":"15:00","notes":"Sugestão: Sanduíche natural + fruta"},{"name":"Jantar","items":[{"food":"Picadinho de carne moída magra","grams":100,"macros":{"energyKcal":185.19,"proteinG":28.73,"carbohydrateG":0,"fatG":6.92,"fiberG":0,"sodiumMg":65.07,"calciumMg":5.01,"ironMg":2.95,"potassiumMg":386.39},"measure":"Grama: 100"},{"food":"Arroz","grams":80,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 80"},{"food":"Chuchu","grams":50,"macros":{"energyKcal":24,"proteinG":0.62,"carbohydrateG":5.1,"fatG":0.48,"fiberG":0.58,"sodiumMg":1,"calciumMg":13,"ironMg":0.22,"potassiumMg":173},"measure":"cozido"},{"food":"Cenoura","grams":50,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida"},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de café: 2"},{"food":"Alface e tomate - à gosto","grams":30,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"19:00","notes":"Sugestão: picadinho de carne com arroz, salada de chuchu e cenoura e completar com salada verde e tomate"},{"name":"Sobremesa","items":[{"food":"Damasco seco","grams":14,"macros":{"energyKcal":238,"proteinG":3.66,"carbohydrateG":61.8,"fatG":0.46,"fiberG":7.8,"sodiumMg":10,"calciumMg":45,"ironMg":4.71,"potassiumMg":1378},"measure":"Unidade: 2"},{"food":"Chocolate amargo - 70% cacau","grams":10,"macros":{"energyKcal":540,"proteinG":7.6,"carbohydrateG":32.8,"fatG":40,"fiberG":12,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"19:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1498},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Sudeste - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26973565,"originalName":"Cardápio Sudeste - opção 2","kcalTotal":1653,"summary":{"energyKcal":1652.7,"proteinG":79.5,"carbohydrateG":213.4,"fatG":55.4,"fiberG":25.7,"sodiumMg":2481.1,"calciumMg":596.2,"ironMg":9.2,"potassiumMg":2109.8},"meals":[{"name":"Café da manhã","items":[{"food":"Tapioca de goma","grams":45,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 45"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Muçarela","grams":15,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1"},{"food":"Mamão","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Grama: 100"},{"food":"Chia em Grãos","grams":10,"macros":{"energyKcal":386.67,"proteinG":19.33,"carbohydrateG":4.67,"fatG":32,"fiberG":35.33,"sodiumMg":20,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"08:00","notes":"Sugestão: tapiovo ou crepioca com mamão e chia"},{"name":"Almoço","items":[{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa : 2"},{"food":"Farofa","grams":45,"macros":{"energyKcal":406,"proteinG":2.1,"carbohydrateG":80.3,"fatG":9.1,"fiberG":7.8,"sodiumMg":575,"calciumMg":66,"ironMg":1.4,"potassiumMg":201},"measure":"Colher De Sopa : 3"},{"food":"Couve refogada","grams":40,"macros":{"energyKcal":117.11,"proteinG":2.81,"carbohydrateG":9.05,"fatG":8.78,"fiberG":2.58,"sodiumMg":802.08,"calciumMg":112.27,"ironMg":1.4,"potassiumMg":376.61},"measure":"Colher de sopa cheia (picada) (20g) : 2"},{"food":"Laranja","grams":90,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"Unidade pequena (90g) : 1"},{"food":"Arroz branco","grams":60,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Colher de arroz rasa (30g) : 2"},{"food":"Feijão cozido","grams":80,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Grama: 80"}],"time":"12:00"},{"name":"Sobremesa","items":[{"food":"Paçoquinha","grams":18,"macros":{"energyKcal":472.17,"proteinG":10.35,"carbohydrateG":64.04,"fatG":21.53,"fiberG":3.89,"sodiumMg":3.07,"calciumMg":32.87,"ironMg":1.72,"potassiumMg":290.53},"measure":"Unidade: 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Salada de frutas","grams":100,"macros":{"energyKcal":45,"proteinG":0.63,"carbohydrateG":11.1,"fatG":0.13,"fiberG":1.35,"sodiumMg":4.87,"calciumMg":8.31,"ironMg":0.33,"potassiumMg":147},"measure":"Grama: 100"},{"food":"Iogurte desnatado","grams":100,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Grama: 100"},{"food":"Pão de forma","grams":42,"macros":{"energyKcal":285.71,"proteinG":9.52,"carbohydrateG":52.38,"fatG":4.76,"fiberG":4.76,"sodiumMg":0,"calciumMg":0,"ironMg":0.95,"potassiumMg":0},"measure":"Fatia: 2"},{"food":"Frango desfiado cremoso","grams":60,"macros":{"energyKcal":124,"proteinG":18,"carbohydrateG":4,"fatG":4,"fiberG":0,"sodiumMg":252,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 60"},{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Folha: 2"},{"food":"Tomate","grams":60,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Fatia grande: 2"}],"time":"15:00","notes":"Sugetsão: sanduíche de frangoo com salada de frutas e iogurte"},{"name":"Jantar","items":[{"food":"Farinha de aveia","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 15"},{"food":"Farinha de trigo","grams":15,"macros":{"energyKcal":340,"proteinG":12,"carbohydrateG":70,"fatG":1,"fiberG":4,"sodiumMg":0,"calciumMg":16,"ironMg":4.2,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Frango desfiado com cenoura e milho","grams":80,"macros":{"energyKcal":115,"proteinG":17,"carbohydrateG":7,"fatG":2,"fiberG":2,"sodiumMg":312,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 80"},{"food":"Azeite de oliva","grams":4,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de chá: 2"},{"food":"Alface","grams":32,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Tomate","grams":90,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222}}],"time":"19:00","notes":"Sugestão: Panqueca de frango e milho com salada "}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1653},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Sul do Brasil - opção 1","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26851506,"originalName":"Cardápio Sul do Brasil - opção 1","kcalTotal":1755,"summary":{"energyKcal":1754.6,"proteinG":103.5,"carbohydrateG":186.5,"fatG":67.3,"fiberG":22.1,"sodiumMg":2101.3,"calciumMg":633.8,"ironMg":15.5,"potassiumMg":2463.1},"meals":[{"name":"Café da manhã","items":[{"food":"Pão francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"Unidade: 1) ou Pão de forma (Fatia: 2"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Queijo muçarela","grams":15,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1"},{"food":"Mamão","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Grama: 100"},{"food":"Chia ou Nuts","grams":10,"macros":{"energyKcal":386.67,"proteinG":19.33,"carbohydrateG":4.67,"fatG":32,"fiberG":35.33,"sodiumMg":20,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"08:00","notes":"Sugestões:\n-Misto quente com ovos mexidos / cozidos e queijo OU Toast com ovos e queijo por cima\n-Frutas com nuts ou chia"},{"name":"Almoço","items":[{"food":"Arroz","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Feijão cozido","grams":80,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Grama: 80"},{"food":"Carne grelhada","grams":100,"macros":{"energyKcal":245,"proteinG":30.2,"carbohydrateG":8.57,"fatG":10.1,"fiberG":0.64,"sodiumMg":262,"calciumMg":10.4,"ironMg":3.19,"potassiumMg":372},"measure":"bovina, de frango, suína..) (Grama: 100"},{"food":"Legumes","grams":40,"macros":{"energyKcal":47,"proteinG":2.53,"carbohydrateG":9.06,"fatG":0.26,"fiberG":2.8,"sodiumMg":482.78,"calciumMg":22.65,"ironMg":0.79,"potassiumMg":176.05},"measure":"cozidos, assados, refogados.."},{"food":"Alface, tomate, cenoura....","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Suco de Bergamota","grams":100,"macros":{"energyKcal":53,"proteinG":0.81,"carbohydrateG":13.34,"fatG":0.31,"fiberG":1.8,"sodiumMg":2,"calciumMg":37,"ironMg":0.15,"potassiumMg":166},"measure":"Copo: 1"}],"time":"12:00","notes":"Sugestões:\n-Arroz pode ser substituído por macarrão (100g cozido) batata inglesa (150g cozida) batata doce (120g cozida) aipim (100g cozido)\n-Feijão pode ser substituído por lentilha (80g) ou feijão carioca (80g)\n-Varie o modo de preparo dos legumes/salada (ex: um dia cozido, outro dia refogado...)"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Banana","grams":42,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade pequena: 1"},{"food":"Aveia","grams":15,"macros":{"energyKcal":389,"proteinG":16.89,"carbohydrateG":66.27,"fatG":6.9,"fiberG":10.6,"sodiumMg":2,"calciumMg":54,"ironMg":4.72,"potassiumMg":429},"measure":"Grama: 15"},{"food":"Geleia 100% fruta","grams":20,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa: 1"},{"food":"Canela em pó","grams":1,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"Colher de café: 1"},{"food":"Café com leite","grams":300,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"Caneca: 1"}],"time":"15:00","notes":"Sugestão:\n- Bolo de banana com aveia + geleia 100% fruta\n\nModo de preparo:\n- Bater os ovos, amassar a banana e misturar aos ovos. Adicionar a aveia e a canela. Dispor em um recipiente que vá ao forno/microondas/airfryer. Tempo de preparo de acordo com cada equipamento e potência. \n-Finalizar com a geleia por cima"},{"name":"Jantar","items":[{"food":"Macarrão","grams":100,"macros":{"energyKcal":141,"proteinG":4.78,"carbohydrateG":28.3,"fatG":0.67,"fiberG":1.5,"sodiumMg":1,"calciumMg":7,"ironMg":1.41,"potassiumMg":31},"measure":"cozido) (Grama: 100"},{"food":"Molho de tomate - à gosto","grams":100,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Almôndega de carne bovina","grams":80,"macros":{"energyKcal":255.96,"proteinG":19.5,"carbohydrateG":7.38,"fatG":15.96,"fiberG":0.56,"sodiumMg":214.56,"calciumMg":19.13,"ironMg":2.46,"potassiumMg":278.75},"measure":"Unidade: 3, grama: 80"},{"food":"Queijo ralado","grams":4,"macros":{"energyKcal":431,"proteinG":38.46,"carbohydrateG":4.06,"fatG":28.61,"fiberG":0,"sodiumMg":1529,"calciumMg":1109,"ironMg":0.9,"potassiumMg":125},"measure":"Colher De Cha: 1"},{"food":"Alface, tomate, cenoura... - à vontade","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}}],"time":"19:00","notes":"Sugestão: Macarrão cozido com almondêgas e salada.\n\n-Pode substituir a massa por Arroz (100g) ou Batata inglesa cozida (150g) ou Batata doce (120g)\n-Pode substituir a almôndega de carne por frango "},{"name":"Sobremesa","items":[{"food":"Paçoca","grams":18,"macros":{"energyKcal":472.17,"proteinG":10.35,"carbohydrateG":64.04,"fatG":21.53,"fiberG":3.89,"sodiumMg":3.07,"calciumMg":32.87,"ironMg":1.72,"potassiumMg":290.53},"measure":"Unidade: 1"}],"time":"13:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1755},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Cardápio Sul do Brasil - opção 2","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":26852979,"originalName":"Cardápio Sul do Brasil - opção 2","kcalTotal":1775,"summary":{"energyKcal":1774.7,"proteinG":109.5,"carbohydrateG":156.7,"fatG":73.7,"fiberG":19.6,"sodiumMg":1860.1,"calciumMg":658,"ironMg":14.1,"potassiumMg":2440.5},"meals":[{"name":"Café da manhã","items":[{"food":"Pão caseiro / de forma/ integral","grams":25,"macros":{"energyKcal":392.13,"proteinG":9.65,"carbohydrateG":69.73,"fatG":7.62,"fiberG":3.15,"sodiumMg":438.95,"calciumMg":15.99,"ironMg":4.3,"potassiumMg":115.07},"measure":"Fatia: 1"},{"food":"Omelete","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2 ovos"},{"food":"Queijo muçarela","grams":20,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1"},{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Metade: 1"},{"food":"Aveia","grams":5,"macros":{"energyKcal":389,"proteinG":16.89,"carbohydrateG":66.27,"fatG":6.9,"fiberG":10.6,"sodiumMg":2,"calciumMg":54,"ironMg":4.72,"potassiumMg":429},"measure":"Grama: 5"},{"food":"Café com leite","grams":200,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"Xicara De Cha: 1"}],"time":"08:00","notes":"Sugestão:\n-Omelete com queijo + fatia de pão + metade de mamão com aveia e café com leite"},{"name":"Almoço","items":[{"food":"Polenta","grams":140,"macros":{"energyKcal":74.6,"proteinG":1.45,"carbohydrateG":13,"fatG":1.78,"fiberG":0.26,"sodiumMg":250.52,"calciumMg":3.43,"ironMg":0.64,"potassiumMg":22.89},"measure":"Colher De Sopa: 4"},{"food":"Patinho","grams":100,"macros":{"energyKcal":185.19,"proteinG":28.73,"carbohydrateG":0,"fatG":6.92,"fiberG":0,"sodiumMg":65.07,"calciumMg":5.01,"ironMg":2.95,"potassiumMg":386.39},"measure":"carne bovina crua) (Grama: 100"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Cenoura, brócolis,","grams":50,"macros":{"energyKcal":41,"proteinG":0.93,"carbohydrateG":9.58,"fatG":0.24,"fiberG":2.8,"sodiumMg":69,"calciumMg":33,"ironMg":0.3,"potassiumMg":320},"measure":"vegetais da sua preferência"},{"food":"Salada de alface, tomate, cenoura...","grams":64,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Azeite de oliva","grams":1,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Cafe: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Pão, sovado","grams":50,"macros":{"energyKcal":300,"proteinG":8.4,"carbohydrateG":61.5,"fatG":2.84,"fiberG":2.43,"sodiumMg":430,"calciumMg":51.6,"ironMg":2.27,"potassiumMg":91.2},"measure":"Fatia: 2"},{"food":"Requeijão light","grams":15,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sobremesa: 1"},{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Geleia 100% fruta","grams":10,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Café com leite","grams":300,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"Caneca: 1"}],"time":"15:00","notes":"Sugestão: 1 toast de pão com ovo + 1 toast romeu e julieta saudável + café com leite "},{"name":"Jantar","items":[{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Carne de gado, magra","grams":100,"macros":{"energyKcal":204,"proteinG":30.67,"carbohydrateG":0,"fatG":9,"fiberG":0,"sodiumMg":41,"calciumMg":7,"ironMg":2.53,"potassiumMg":252},"measure":"Grama: 100"},{"food":"Molho de tomate","grams":50,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43}},{"food":"Cebola, vegetais e temperos - à gosto","grams":50,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157}},{"food":"Salada de alface, tomate, cenoura...","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Cafe: 2"}],"time":"19:00","notes":"Sugestão: carreteiro saudável. "},{"name":"Sobremesa","items":[{"food":"Chocolate 70%","grams":20,"macros":{"energyKcal":618.18,"proteinG":6.82,"carbohydrateG":36.36,"fatG":36.36,"fiberG":20.91,"sodiumMg":9.09,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"}],"time":"12:30"},{"name":"Sobremesa","items":[{"food":"Chocolate 70%","grams":20,"macros":{"energyKcal":618.18,"proteinG":6.82,"carbohydrateG":36.36,"fatG":36.36,"fiberG":20.91,"sodiumMg":9.09,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"}],"time":"19:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1775},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 1.200 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1200 kcal","20% ptn"],"snapshot":{"dietboxId":1231869,"originalName":"Dieta 1.200 Kcal (20% PTN)","kcalTotal":1197,"summary":{"energyKcal":1197.2,"proteinG":65.4,"carbohydrateG":170.5,"fatG":31.3,"fiberG":12.4,"sodiumMg":1241.4,"calciumMg":551.8,"ironMg":8.8,"potassiumMg":1740.9},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Copo Americano: 1"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":18,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Ponta De Faca: 3"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Castanha do Pará sem sal","grams":4,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 1"},{"food":"Uva passa","grams":18,"macros":{"energyKcal":300,"proteinG":3.23,"carbohydrateG":79.1,"fatG":0.46,"fiberG":3.47,"sodiumMg":12,"calciumMg":49,"ironMg":2.09,"potassiumMg":751},"measure":"Colher de sopa cheia (18g): 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada, de legumes, cozida no vapor","grams":60,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Colher de Sopa: 3"},{"food":"Peito de galinha ou frango Cozido(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"File: 1"},{"food":"Espaguete, cozido, enriquecido, com sal","grams":90,"macros":{"energyKcal":141,"proteinG":4.77,"carbohydrateG":28.34,"fatG":0.67,"fiberG":1.7,"sodiumMg":100,"calciumMg":7,"ironMg":1.4,"potassiumMg":31},"measure":"Pegador: 1"},{"food":"Molho de tomate","grams":40,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43},"measure":"Colher de sopa (20g): 2"},{"food":"Chocolate, meio amargo","grams":15,"macros":{"energyKcal":474.92,"proteinG":4.86,"carbohydrateG":62.42,"fatG":29.86,"fiberG":4.94,"sodiumMg":8.87,"calciumMg":44.67,"ironMg":3.61,"potassiumMg":431.7},"measure":"Pedaço: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"},{"food":"Pão de queijo","grams":20,"macros":{"energyKcal":363,"proteinG":5.1,"carbohydrateG":34.2,"fatG":24.6,"fiberG":0.6,"sodiumMg":773,"calciumMg":102,"ironMg":0.3,"potassiumMg":93},"measure":"Unidade Pequena: 2"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"Unidade (50g): 1"},{"food":"Blanquet de peru","grams":10,"macros":{"energyKcal":126,"proteinG":17.5,"carbohydrateG":2.04,"fatG":4.84,"fiberG":0.2,"sodiumMg":1114,"calciumMg":8,"ironMg":2.34,"potassiumMg":287},"measure":"Fatia: 1"},{"food":"Queijo prato","grams":15,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":18,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Ponta De Faca: 3"},{"food":"Tomate","grams":90,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"Fatia grande (30g): 3"},{"food":"Alface, americana, crua","grams":15,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 3"}],"time":"20:00","notes":"Alface e tomate à vontade"},{"name":"Ceia","items":[{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Copo Americano: 1"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 1.300 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1300 kcal","20% ptn"],"snapshot":{"dietboxId":493749,"originalName":"Dieta 1.300 Kcal (20% PTN)","kcalTotal":1340,"summary":{"energyKcal":1340.1,"proteinG":70.4,"carbohydrateG":168.8,"fatG":46.3,"fiberG":28.3,"sodiumMg":1233.2,"calciumMg":577.2,"ironMg":10.8,"potassiumMg":3762.5},"meals":[{"name":"Café da manhã","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo tipo \"cottage\"","grams":50,"macros":{"energyKcal":72.4,"proteinG":12.4,"carbohydrateG":2.73,"fatG":1.03,"fiberG":0,"sodiumMg":406,"calciumMg":60.9,"ironMg":0.14,"potassiumMg":85.5},"measure":"1% de gordura) (Colher de Sopa: 2"},{"food":"Orégano seco","grams":2,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.4,"fatG":10.3,"fiberG":15,"sodiumMg":14.7,"calciumMg":1576,"ironMg":44,"potassiumMg":1668},"measure":"1/2 Colher de chá: 1"},{"food":"Café","grams":50,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0.47,"fatG":0.02,"fiberG":0.47,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49.05},"measure":"Xicara De Cafe: 1"},{"food":"Adoçante Stevia","grams":1,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"2 gotas: 1"}],"time":"07:30"},{"name":"Colação","items":[{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote 110 g: 1"},{"food":"Goji Berry","grams":10,"macros":{"energyKcal":256,"proteinG":6.89,"carbohydrateG":23,"fatG":0,"fiberG":7.14,"sodiumMg":125,"calciumMg":0,"ironMg":0,"potassiumMg":1214.29},"measure":"Colher de Sopa: 1"},{"food":"Bananinha","grams":20,"macros":{"energyKcal":300,"proteinG":4,"carbohydrateG":65,"fatG":0,"fiberG":9,"sodiumMg":0,"calciumMg":22,"ironMg":0.8,"potassiumMg":1},"measure":"Unidade: 1"}],"time":"09:30"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":63,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Arroz/Servir: 1"},{"food":"Feijão","grams":50,"macros":{"energyKcal":97.41,"proteinG":5.84,"carbohydrateG":15.05,"fatG":1.79,"fiberG":3.78,"sodiumMg":5.2,"calciumMg":55.2,"ironMg":2.22,"potassiumMg":336.6},"measure":"preto, mulatinho, roxo, rosinha, etc.)  (Concha : 1"},{"food":"Peixe não especificado","grams":80,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (Grama: 80"},{"food":"Brócolis Ao vinagrete","grams":300,"macros":{"energyKcal":35,"proteinG":2.38,"carbohydrateG":7.18,"fatG":0.41,"fiberG":3.3,"sodiumMg":41,"calciumMg":40,"ironMg":0.67,"potassiumMg":293},"measure":"Ramo: 5"},{"food":"Suco de laranja cenoura e beterraba","grams":150,"macros":{"energyKcal":30.77,"proteinG":0.81,"carbohydrateG":7.11,"fatG":0.12,"fiberG":0.76,"sodiumMg":28.03,"calciumMg":17.14,"ironMg":0.39,"potassiumMg":222.58},"measure":"Copo Americano: 1"},{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"}],"time":"12:40","notes":"Comer meio prato de salada crua bem colorida ANTES da refeição. Mastigar bem e lembrar das 3 respirações."},{"name":"Lanche da tarde","items":[{"food":"Uva","grams":120,"macros":{"energyKcal":69,"proteinG":0.72,"carbohydrateG":18.1,"fatG":0.16,"fiberG":0.9,"sodiumMg":2,"calciumMg":10,"ironMg":0.36,"potassiumMg":191},"measure":"Bago: 15"},{"food":"Água de coco","grams":100,"macros":{"energyKcal":19,"proteinG":0.72,"carbohydrateG":3.71,"fatG":0.2,"fiberG":1.1,"sodiumMg":105,"calciumMg":24,"ironMg":0.29,"potassiumMg":250},"measure":"Grama: 100"}],"time":"16:00","notes":"Opções: Salada de frutas (1 xícaras); 1 Fruta + Barra de cereal; iogurte com 1 Colher de Sopa de Quinoa em flocos"},{"name":"Jantar","items":[{"food":"Salada de repolho com abacaxi e uva passa","grams":50,"macros":{"energyKcal":123.66,"proteinG":1.23,"carbohydrateG":10.06,"fatG":9.58,"fiberG":1.37,"sodiumMg":463.92,"calciumMg":34.77,"ironMg":0.5,"potassiumMg":187.03},"measure":"Grama: 50"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Suco de maracujá","grams":150,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"Copo Americano: 1"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"19:30","notes":"Sempre que possível, evitar as carnes (bovina, suína e frango). Como são calóricos, nem sempre temos tempo de digerir a noite.\nPeixes magros e ovos de galinha e/ou codorna são as melhores opções."},{"name":"Ceia","items":[{"food":"Gergelim","grams":20,"macros":{"energyKcal":631,"proteinG":20.45,"carbohydrateG":11.73,"fatG":61.21,"fiberG":11.6,"sodiumMg":47,"calciumMg":60,"ironMg":6.36,"potassiumMg":370},"measure":"Leite de gergelim hidratado: 1"},{"food":"Mel, de abelha","grams":9,"macros":{"energyKcal":309.24,"proteinG":0,"carbohydrateG":84.03,"fatG":0,"fiberG":0,"sodiumMg":6.04,"calciumMg":10.2,"ironMg":0.25,"potassiumMg":99.32},"measure":"Meia Colher de Sopa: 1"}],"time":"22:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1300},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 1.400 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1400 kcal","20% ptn"],"snapshot":{"dietboxId":1304489,"originalName":"Dieta 1.400 Kcal (20% PTN)","kcalTotal":1403,"summary":{"energyKcal":1403.1,"proteinG":74.2,"carbohydrateG":178,"fatG":48.5,"fiberG":31.1,"sodiumMg":1343.7,"calciumMg":601.3,"ironMg":11.1,"potassiumMg":3750.3},"meals":[{"name":"Café da manhã","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo tipo \"cottage\"","grams":50,"macros":{"energyKcal":72.4,"proteinG":12.4,"carbohydrateG":2.73,"fatG":1.03,"fiberG":0,"sodiumMg":406,"calciumMg":60.9,"ironMg":0.14,"potassiumMg":85.5},"measure":"1% de gordura) (Colher de Sopa: 2"},{"food":"Orégano seco","grams":2,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.4,"fatG":10.3,"fiberG":15,"sodiumMg":14.7,"calciumMg":1576,"ironMg":44,"potassiumMg":1668},"measure":"1/2 Colher de chá: 1"},{"food":"Café","grams":50,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0.47,"fatG":0.02,"fiberG":0.47,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49.05},"measure":"Xicara De Cafe: 1"}],"time":"07:30"},{"name":"Colação","items":[{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote 110 g: 1"},{"food":"Goji Berry","grams":10,"macros":{"energyKcal":256,"proteinG":6.89,"carbohydrateG":23,"fatG":0,"fiberG":7.14,"sodiumMg":125,"calciumMg":0,"ironMg":0,"potassiumMg":1214.29},"measure":"Colher de Sopa: 1"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"09:30"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":126,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"2 Colher De Arroz/Servir"},{"food":"Feijão","grams":50,"macros":{"energyKcal":97.41,"proteinG":5.84,"carbohydrateG":15.05,"fatG":1.79,"fiberG":3.78,"sodiumMg":5.2,"calciumMg":55.2,"ironMg":2.22,"potassiumMg":336.6},"measure":"preto, mulatinho, roxo, rosinha, etc.)  (Concha : 1"},{"food":"Peixe não especificado","grams":80,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (Grama: 80"},{"food":"Brócolis Ao vinagrete","grams":300,"macros":{"energyKcal":35,"proteinG":2.38,"carbohydrateG":7.18,"fatG":0.41,"fiberG":3.3,"sodiumMg":41,"calciumMg":40,"ironMg":0.67,"potassiumMg":293},"measure":"Ramo: 5"},{"food":"Suco de laranja cenoura e beterraba","grams":150,"macros":{"energyKcal":30.77,"proteinG":0.81,"carbohydrateG":7.11,"fatG":0.12,"fiberG":0.76,"sodiumMg":28.03,"calciumMg":17.14,"ironMg":0.39,"potassiumMg":222.58},"measure":"Copo Americano: 1"},{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"}],"time":"12:40","notes":"Comer meio prato de salada crua bem colorida ANTES da refeição. Mastigar bem e lembrar das 3 respirações."},{"name":"Lanche da tarde","items":[{"food":"Uva","grams":120,"macros":{"energyKcal":69,"proteinG":0.72,"carbohydrateG":18.1,"fatG":0.16,"fiberG":0.9,"sodiumMg":2,"calciumMg":10,"ironMg":0.36,"potassiumMg":191},"measure":"Bago: 15"},{"food":"Água de coco","grams":100,"macros":{"energyKcal":19,"proteinG":0.72,"carbohydrateG":3.71,"fatG":0.2,"fiberG":1.1,"sodiumMg":105,"calciumMg":24,"ironMg":0.29,"potassiumMg":250},"measure":"Grama: 100"}],"time":"16:00","notes":"Opções: Salada de frutas (1 xícaras); 1 Fruta + Barra de cereal; iogurte com 1 Colher de Sopa de Quinoa em flocos"},{"name":"Jantar","items":[{"food":"Salada de repolho com abacaxi e uva passa","grams":50,"macros":{"energyKcal":123.66,"proteinG":1.23,"carbohydrateG":10.06,"fatG":9.58,"fiberG":1.37,"sodiumMg":463.92,"calciumMg":34.77,"ironMg":0.5,"potassiumMg":187.03},"measure":"Grama: 50"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"19:30","notes":"Sempre que possível, evitar as carnes (bovina, suína e frango). Como são calóricos, nem sempre temos tempo de digerir a noite.\nPeixes magros e ovos de galinha e/ou codorna são as melhores opções."},{"name":"Ceia","items":[{"food":"Gergelim","grams":20,"macros":{"energyKcal":631,"proteinG":20.45,"carbohydrateG":11.73,"fatG":61.21,"fiberG":11.6,"sodiumMg":47,"calciumMg":60,"ironMg":6.36,"potassiumMg":370},"measure":"Leite de gergelim hidratado: 1"},{"food":"Mel, de abelha","grams":9,"macros":{"energyKcal":309.24,"proteinG":0,"carbohydrateG":84.03,"fatG":0,"fiberG":0,"sodiumMg":6.04,"calciumMg":10.2,"ironMg":0.25,"potassiumMg":99.32},"measure":"Meia Colher de Sopa: 1"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"}],"time":"22:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1400},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 1.500 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","20% ptn"],"snapshot":{"dietboxId":1262003,"originalName":"Dieta 1.500 Kcal (20% PTN)","kcalTotal":1571,"summary":{"energyKcal":1570.6,"proteinG":80.8,"carbohydrateG":245.4,"fatG":32.8,"fiberG":18.3,"sodiumMg":1412.3,"calciumMg":769.8,"ironMg":13.8,"potassiumMg":2596.9},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":165,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Pequeno"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":12,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"2 Ponta De Faca"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Castanha do Pará sem sal","grams":4,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 1"},{"food":"Uva passa","grams":18,"macros":{"energyKcal":300,"proteinG":3.23,"carbohydrateG":79.1,"fatG":0.46,"fiberG":3.47,"sodiumMg":12,"calciumMg":49,"ironMg":2.09,"potassiumMg":751},"measure":"Colher de sopa cheia (18g): 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada, de legumes, cozida no vapor","grams":60,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Colher de Sopa: 3"},{"food":"Peito de galinha ou frango Cozido(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"File: 1"},{"food":"Espaguete, cozido, enriquecido, com sal","grams":180,"macros":{"energyKcal":141,"proteinG":4.77,"carbohydrateG":28.34,"fatG":0.67,"fiberG":1.7,"sodiumMg":100,"calciumMg":7,"ironMg":1.4,"potassiumMg":31},"measure":"2 Pegador"},{"food":"Molho de tomate","grams":60,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43},"measure":"3 Colher de sopa (20g)"},{"food":"Chocolate, meio amargo","grams":15,"macros":{"energyKcal":474.92,"proteinG":4.86,"carbohydrateG":62.42,"fatG":29.86,"fiberG":4.94,"sodiumMg":8.87,"calciumMg":44.67,"ironMg":3.61,"potassiumMg":431.7},"measure":"Pedaço: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"},{"food":"Pão de queijo","grams":20,"macros":{"energyKcal":363,"proteinG":5.1,"carbohydrateG":34.2,"fatG":24.6,"fiberG":0.6,"sodiumMg":773,"calciumMg":102,"ironMg":0.3,"potassiumMg":93},"measure":"Unidade Pequena: 2"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Blanquet de peru","grams":10,"macros":{"energyKcal":126,"proteinG":17.5,"carbohydrateG":2.04,"fatG":4.84,"fiberG":0.2,"sodiumMg":1114,"calciumMg":8,"ironMg":2.34,"potassiumMg":287},"measure":"Fatia: 1"},{"food":"Queijo prato","grams":15,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":18,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Ponta De Faca: 3"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Alface, americana, crua","grams":15,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 3"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Suco de uva integral","grams":165,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"1 Copo pequeno (165ml)"}],"time":"20:00","notes":"Alface e tomate à vontade"},{"name":"Ceia","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"23:00"},{"name":"Pós-treino","items":[{"food":"Banana, nanica, crua","grams":60,"macros":{"energyKcal":91.53,"proteinG":1.4,"carbohydrateG":23.85,"fatG":0.12,"fiberG":1.95,"sodiumMg":0,"calciumMg":3.42,"ironMg":0.35,"potassiumMg":376.47},"measure":"Unidade: 1"}],"time":"20:00","notes":"1 banana"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 1.600 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1600 kcal","20% ptn"],"snapshot":{"dietboxId":1304495,"originalName":"Dieta 1.600 Kcal (20% PTN)","kcalTotal":1613,"summary":{"energyKcal":1612.9,"proteinG":81.6,"carbohydrateG":246.8,"fatG":38.4,"fiberG":32.8,"sodiumMg":1145,"calciumMg":619.8,"ironMg":18.3,"potassiumMg":2934},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":165,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Pequeno"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":12,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"2 Ponta De Faca"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Castanha do Pará sem sal","grams":4,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 1"},{"food":"Uva passa","grams":18,"macros":{"energyKcal":300,"proteinG":3.23,"carbohydrateG":79.1,"fatG":0.46,"fiberG":3.47,"sodiumMg":12,"calciumMg":49,"ironMg":2.09,"potassiumMg":751},"measure":"Colher de sopa cheia (18g): 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada, de legumes, cozida no vapor","grams":60,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Colher de Sopa: 3"},{"food":"Arroz integral","grams":63,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (1 Colher de arroz cheia (63g)"},{"food":"Lentilha","grams":160,"macros":{"energyKcal":136.28,"proteinG":9.02,"carbohydrateG":20.13,"fatG":2.67,"fiberG":5.86,"sodiumMg":2,"calciumMg":19,"ironMg":3.33,"potassiumMg":369},"measure":"1 Concha"},{"food":"Peito de galinha ou frango Cozido(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"File: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"},{"food":"Pão de queijo","grams":30,"macros":{"energyKcal":363,"proteinG":5.1,"carbohydrateG":34.2,"fatG":24.6,"fiberG":0.6,"sodiumMg":773,"calciumMg":102,"ironMg":0.3,"potassiumMg":93},"measure":"3 Unidade Pequena"}],"time":"15:00"},{"name":"Jantar","items":[{"food":"Blanquet de peru","grams":10,"macros":{"energyKcal":126,"proteinG":17.5,"carbohydrateG":2.04,"fatG":4.84,"fiberG":0.2,"sodiumMg":1114,"calciumMg":8,"ironMg":2.34,"potassiumMg":287},"measure":"Fatia: 1"},{"food":"Queijo prato","grams":30,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"2 Fatia"},{"food":"Requeijão light","grams":24,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"4 Ponta De Faca"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Alface, americana, crua","grams":15,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 3"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Suco de uva integral","grams":165,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"1 Copo pequeno (165ml)"}],"time":"20:00","notes":"Alface e tomate à vontade"},{"name":"Ceia","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"},{"food":"Canela em pó","grams":5,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"5 Grama"}],"time":"23:00"},{"name":"Lanche da tarde 2","items":[{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia média (170g)"},{"food":"Granola","grams":10,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"1 Colher De Sopa"}],"time":"18:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1600},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 1.700 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1700 kcal","20% ptn"],"snapshot":{"dietboxId":1301692,"originalName":"Dieta 1.700 Kcal (20% PTN)","kcalTotal":1716,"summary":{"energyKcal":1716.2,"proteinG":87,"carbohydrateG":259.6,"fatG":40.1,"fiberG":21.1,"sodiumMg":1596.7,"calciumMg":938.4,"ironMg":14.3,"potassiumMg":2890.8},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":165,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Pequeno"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":12,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"2 Ponta De Faca"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Castanha do Pará sem sal","grams":4,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 1"},{"food":"Uva passa","grams":18,"macros":{"energyKcal":300,"proteinG":3.23,"carbohydrateG":79.1,"fatG":0.46,"fiberG":3.47,"sodiumMg":12,"calciumMg":49,"ironMg":2.09,"potassiumMg":751},"measure":"Colher de sopa cheia (18g): 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada, de legumes, cozida no vapor","grams":60,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Colher de Sopa: 3"},{"food":"Peito de galinha ou frango Cozido(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"File: 1"},{"food":"Espaguete, cozido, enriquecido, com sal","grams":180,"macros":{"energyKcal":141,"proteinG":4.77,"carbohydrateG":28.34,"fatG":0.67,"fiberG":1.7,"sodiumMg":100,"calciumMg":7,"ironMg":1.4,"potassiumMg":31},"measure":"2 Pegador"},{"food":"Molho de tomate","grams":60,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43},"measure":"3 Colher de sopa (20g)"},{"food":"Chocolate, meio amargo","grams":15,"macros":{"energyKcal":474.92,"proteinG":4.86,"carbohydrateG":62.42,"fatG":29.86,"fiberG":4.94,"sodiumMg":8.87,"calciumMg":44.67,"ironMg":3.61,"potassiumMg":431.7},"measure":"Pedaço: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"},{"food":"Pão de queijo","grams":30,"macros":{"energyKcal":363,"proteinG":5.1,"carbohydrateG":34.2,"fatG":24.6,"fiberG":0.6,"sodiumMg":773,"calciumMg":102,"ironMg":0.3,"potassiumMg":93},"measure":"3 Unidade Pequena"}],"time":"15:00"},{"name":"Jantar","items":[{"food":"Blanquet de peru","grams":10,"macros":{"energyKcal":126,"proteinG":17.5,"carbohydrateG":2.04,"fatG":4.84,"fiberG":0.2,"sodiumMg":1114,"calciumMg":8,"ironMg":2.34,"potassiumMg":287},"measure":"Fatia: 1"},{"food":"Queijo prato","grams":30,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"2 Fatia"},{"food":"Requeijão light","grams":24,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"4 Ponta De Faca"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Alface, americana, crua","grams":15,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 3"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Suco de uva integral","grams":165,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"1 Copo pequeno (165ml)"}],"time":"20:00","notes":"Alface e tomate à vontade"},{"name":"Ceia","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"23:00"},{"name":"Lanche da tarde 2","items":[{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia média (170g)"},{"food":"Granola","grams":10,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"1 Colher De Sopa"}],"time":"18:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1700},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}}]$data$::jsonb) loop
    insert into public.plan_templates (organization_id, name, objective, tags, snapshot, created_by, scope, dimensions, rules)
    values (target_organization_id, model->>'name', model->>'objective', (select array(select jsonb_array_elements_text(model->'tags'))), model->'snapshot', actor, 'organization', model->'dimensions', model->'rules')
    on conflict (organization_id, (snapshot->>'dietboxId')) where snapshot ? 'dietboxId' do update set
      name = excluded.name, objective = excluded.objective, tags = excluded.tags, snapshot = excluded.snapshot,
      dimensions = excluded.dimensions, rules = excluded.rules, updated_at = now();
  end loop;

  for model in select jsonb_array_elements($data$[{"name":"Dieta 1.900 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1900 kcal","20% ptn"],"snapshot":{"dietboxId":1304516,"originalName":"Dieta 1.900 Kcal (20% PTN)","kcalTotal":1914,"summary":{"energyKcal":1914.3,"proteinG":99.8,"carbohydrateG":272,"fatG":53.8,"fiberG":34.9,"sodiumMg":1422,"calciumMg":753.8,"ironMg":14.3,"potassiumMg":3441.5},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Copo Americano: 1"},{"food":"Chia - semente","grams":10,"macros":{"energyKcal":520,"proteinG":16.67,"carbohydrateG":49.33,"fatG":32,"fiberG":30.67,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sobremesa: 1"},{"food":"Gengibre, cru","grams":2,"macros":{"energyKcal":80,"proteinG":1.82,"carbohydrateG":17.77,"fatG":0.75,"fiberG":2,"sodiumMg":13,"calciumMg":16,"ironMg":0.6,"potassiumMg":415},"measure":"colher de chá: 1"},{"food":"Café, pó, torrado","grams":6,"macros":{"energyKcal":418.62,"proteinG":14.7,"carbohydrateG":65.75,"fatG":11.95,"fiberG":51.23,"sodiumMg":1.13,"calciumMg":106.89,"ironMg":8.13,"potassiumMg":1608.58},"measure":"Colher De Chá Cheia: 1"},{"food":"Tofu","grams":20,"macros":{"energyKcal":61,"proteinG":6.55,"carbohydrateG":1.8,"fatG":3.69,"fiberG":0.2,"sodiumMg":8,"calciumMg":111,"ironMg":1.11,"potassiumMg":120},"measure":"Fatia: 1"},{"food":"Pão integral light","grams":46,"macros":{"energyKcal":198,"proteinG":9.1,"carbohydrateG":43.6,"fatG":2.3,"fiberG":12,"sodiumMg":511,"calciumMg":80,"ironMg":2.96,"potassiumMg":122},"measure":"Fatia: 2"},{"food":"Manteiga com ou sem sal","grams":5,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"Ponta De Faca: 1"},{"food":"Geleia sem açúcar","grams":10,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":4.75,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Ponta de Faca: 1"}],"time":"07:10","notes":"Suco: Bater laranja + chia + gengibre. \nPode adicionar uma pitada de canela no café\n\nOpção 2 de café da manhã: Vitamina de 100 ml de leite desnatado + 0,5 Colher de Sopa de abacate +1 Colher de Sopa de Mel + Colher de Sopa de Chia + Colher de Chá de cacau em pó \n\nOpção 3: 3 Colheres de Sopa de Granola + 1 Colher de Sopa de Goji Berry + 1 Colher de Sopa de Mel + Leite com café e açúcar"},{"name":"Colação","items":[{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Grama: 110"},{"food":"Uva passa","grams":18,"macros":{"energyKcal":299,"proteinG":3.07,"carbohydrateG":79.18,"fatG":0.46,"fiberG":3.7,"sodiumMg":11,"calciumMg":50,"ironMg":1.88,"potassiumMg":749},"measure":"1 Colher De Sopa"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":63,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Arroz/Servir: 1"},{"food":"Feijão, carioca, cozido","grams":65,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Concha Pequena Cheia: 1"},{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Agrião Cozido(a)","grams":25,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"Colher De Arroz/Servir: 0.5"},{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 2"},{"food":"Patinho Cozido(a)","grams":120,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Grama: 120"},{"food":"Melancia","grams":62,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.55,"fatG":0.15,"fiberG":0.4,"sodiumMg":1,"calciumMg":7,"ironMg":0.24,"potassiumMg":112},"measure":"Copo Americano: 1"},{"food":"Hortelã, fresco","grams":0.5,"macros":{"energyKcal":44,"proteinG":3.29,"carbohydrateG":8.41,"fatG":0.73,"fiberG":6.8,"sodiumMg":30,"calciumMg":199,"ironMg":11.87,"potassiumMg":458},"measure":"Grama: 0.5"}],"time":"12:30","notes":"A melancia é para o suco. Bater junto com o hortelã."},{"name":"Lanche da tarde","items":[{"food":"Castanha-do-pará","grams":12,"macros":{"energyKcal":656,"proteinG":14.32,"carbohydrateG":12.27,"fatG":66.43,"fiberG":7.5,"sodiumMg":3,"calciumMg":160,"ironMg":2.43,"potassiumMg":659},"measure":"Unidade: 3"},{"food":"Banana","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.)  (Unidade: 1"},{"food":"Maçã","grams":90,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade Pequena: 1"}],"time":"15:30"},{"name":"Lanche da tarde 2","items":[{"food":"Tapioca de goma","grams":45,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 3"},{"food":"Queijo, minas, frescal","grams":30,"macros":{"energyKcal":264.27,"proteinG":17.41,"carbohydrateG":3.24,"fatG":20.18,"fiberG":0,"sodiumMg":31.23,"calciumMg":579.25,"ironMg":0.93,"potassiumMg":104.85},"measure":"Fatia Média (30g): 1"},{"food":"Manjericão, seco","grams":0.5,"macros":{"energyKcal":251,"proteinG":14.37,"carbohydrateG":60.96,"fatG":3.98,"fiberG":40.5,"sodiumMg":34,"calciumMg":2113,"ironMg":42,"potassiumMg":3433},"measure":"colher de chá, folhas: 0.5"},{"food":"Suco de laranja","grams":240,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Medio"}],"time":"18:30"},{"name":"Jantar","items":[{"food":"Alface, americana, crua","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 2"},{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"},{"food":"Semente de girassol, torrada, com sal","grams":5,"macros":{"energyKcal":582,"proteinG":19.33,"carbohydrateG":24.07,"fatG":49.8,"fiberG":9,"sodiumMg":410,"calciumMg":70,"ironMg":3.8,"potassiumMg":850},"measure":"Colher de Sopa: 0.5"},{"food":"Batata doce, cozida, assada com casca, sem sal","grams":60,"macros":{"energyKcal":90,"proteinG":2.01,"carbohydrateG":20.71,"fatG":0.15,"fiberG":3.3,"sodiumMg":36,"calciumMg":38,"ironMg":0.69,"potassiumMg":475},"measure":"pequena: 1"},{"food":"Frango, peito, sem pele, grelhado","grams":60,"macros":{"energyKcal":159.19,"proteinG":32.03,"carbohydrateG":0,"fatG":2.48,"fiberG":0,"sodiumMg":50.25,"calciumMg":5.34,"ironMg":0.33,"potassiumMg":387.37},"measure":"Grama: 60"},{"food":"Suco de maracujá","grams":150,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"Copo Americano: 1"},{"food":"Gelatina de Ágar-ágar","grams":40,"macros":{"energyKcal":50,"proteinG":0,"carbohydrateG":12.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Potinho pequeno: 1"}],"time":"21:00","notes":"Salpicar a semente de girassol no prato."},{"name":"Ceia","items":[{"food":"Leite, de vaca, desnatado, UHT","grams":100,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Grama: 100"},{"food":"Cacau, pó","grams":5,"macros":{"energyKcal":398,"proteinG":5.88,"carbohydrateG":84.52,"fatG":4,"fiberG":3.5,"sodiumMg":504,"calciumMg":141,"ironMg":1.19,"potassiumMg":712},"measure":"Colher de Chá: 1"},{"food":"Canela, pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.85,"fatG":3.19,"fiberG":54.3,"sodiumMg":26,"calciumMg":1228,"ironMg":38.07,"potassiumMg":500},"measure":"colher de chá: 1"},{"food":"Mel","grams":21,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"colher de sopa: 1"}],"time":"22:30","notes":"Misturar todos os ingredientes no copo. Pode bater no liquidificador. "}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1900},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 2.000 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","20% ptn"],"snapshot":{"dietboxId":493751,"originalName":"Dieta 2.000 Kcal (20% PTN)","kcalTotal":1950,"summary":{"energyKcal":1950.2,"proteinG":100.9,"carbohydrateG":272.9,"fatG":55.7,"fiberG":37.6,"sodiumMg":1806.8,"calciumMg":740.5,"ironMg":13.7,"potassiumMg":3510.9},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Copo Americano: 1"},{"food":"Chia - semente","grams":10,"macros":{"energyKcal":520,"proteinG":16.67,"carbohydrateG":49.33,"fatG":32,"fiberG":30.67,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sobremesa: 1"},{"food":"Gengibre, cru","grams":2,"macros":{"energyKcal":80,"proteinG":1.82,"carbohydrateG":17.77,"fatG":0.75,"fiberG":2,"sodiumMg":13,"calciumMg":16,"ironMg":0.6,"potassiumMg":415},"measure":"colher de chá: 1"},{"food":"Café, pó, torrado","grams":6,"macros":{"energyKcal":418.62,"proteinG":14.7,"carbohydrateG":65.75,"fatG":11.95,"fiberG":51.23,"sodiumMg":1.13,"calciumMg":106.89,"ironMg":8.13,"potassiumMg":1608.58},"measure":"Colher De Chá Cheia: 1"},{"food":"Tofu","grams":20,"macros":{"energyKcal":61,"proteinG":6.55,"carbohydrateG":1.8,"fatG":3.69,"fiberG":0.2,"sodiumMg":8,"calciumMg":111,"ironMg":1.11,"potassiumMg":120},"measure":"Fatia: 1"},{"food":"Pão integral light","grams":46,"macros":{"energyKcal":198,"proteinG":9.1,"carbohydrateG":43.6,"fatG":2.3,"fiberG":12,"sodiumMg":511,"calciumMg":80,"ironMg":2.96,"potassiumMg":122},"measure":"Fatia: 2"},{"food":"Açúcar","grams":2,"macros":{"energyKcal":387,"proteinG":0,"carbohydrateG":99.98,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":1,"ironMg":0.01,"potassiumMg":2},"measure":"Colher De Cafe: 1"},{"food":"Manteiga com ou sem sal","grams":5,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"Ponta De Faca: 1"},{"food":"Geleia sem açúcar","grams":10,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":4.75,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Ponta de Faca: 1"}],"time":"07:10","notes":"Suco: Bater laranja + chia + gengibre. \nPode adicionar uma pitada de canela no café\n\nOpção 2 de café da manhã: Vitamina de 100 ml de leite desnatado + 0,5 Colher de Sopa de abacate +1 Colher de Sopa de Mel + Colher de Sopa de Chia + Colher de Chá de cacau em pó \n\nOpção 3: 3 Colheres de Sopa de Granola + 1 Colher de Sopa de Goji Berry + 1 Colher de Sopa de Mel + Leite com café e açúcar"},{"name":"Colação","items":[{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Grama: 110"},{"food":"Uva passa","grams":9,"macros":{"energyKcal":299,"proteinG":3.07,"carbohydrateG":79.18,"fatG":0.46,"fiberG":3.7,"sodiumMg":11,"calciumMg":50,"ironMg":1.88,"potassiumMg":749},"measure":"Colher De Sobremesa: 1"}],"time":"10:30","notes":"Opções: 15 uvas; 1 Banana + Barra de Cereal."},{"name":"Almoço","items":[{"food":"Arroz integral","grams":63,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Arroz/Servir: 1"},{"food":"Feijão, carioca, cozido","grams":65,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Concha Pequena Cheia: 1"},{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Agrião Cozido(a)","grams":25,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"Colher De Arroz/Servir: 0.5"},{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 2"},{"food":"Patinho Cozido(a)","grams":120,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Grama: 120"},{"food":"Melancia","grams":62,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.55,"fatG":0.15,"fiberG":0.4,"sodiumMg":1,"calciumMg":7,"ironMg":0.24,"potassiumMg":112},"measure":"Copo Americano: 1"},{"food":"Hortelã, fresco","grams":0.5,"macros":{"energyKcal":44,"proteinG":3.29,"carbohydrateG":8.41,"fatG":0.73,"fiberG":6.8,"sodiumMg":30,"calciumMg":199,"ironMg":11.87,"potassiumMg":458},"measure":"Grama: 0.5"}],"time":"12:30","notes":"A melancia é para o suco. Bater junto com o hortelã."},{"name":"Lanche da tarde","items":[{"food":"Castanha-do-pará","grams":12,"macros":{"energyKcal":656,"proteinG":14.32,"carbohydrateG":12.27,"fatG":66.43,"fiberG":7.5,"sodiumMg":3,"calciumMg":160,"ironMg":2.43,"potassiumMg":659},"measure":"Unidade: 3"},{"food":"Banana","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.)  (Unidade: 1"},{"food":"Maçã","grams":90,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade Pequena: 1"}],"time":"16:30"},{"name":"Pré-treino","items":[{"food":"Tapioca de goma","grams":45,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 3"},{"food":"Queijo, minas, frescal","grams":30,"macros":{"energyKcal":264.27,"proteinG":17.41,"carbohydrateG":3.24,"fatG":20.18,"fiberG":0,"sodiumMg":31.23,"calciumMg":579.25,"ironMg":0.93,"potassiumMg":104.85},"measure":"Fatia Média (30g): 1"},{"food":"Manjericão, seco","grams":0.5,"macros":{"energyKcal":251,"proteinG":14.37,"carbohydrateG":60.96,"fatG":3.98,"fiberG":40.5,"sodiumMg":34,"calciumMg":2113,"ironMg":42,"potassiumMg":3433},"measure":"colher de chá, folhas: 0.5"},{"food":"Suco de uva integral","grams":110,"macros":{"energyKcal":67,"proteinG":0.3,"carbohydrateG":15.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"ml: 110"}],"time":"19:00","notes":"40 min antes do treino - \n\nOpção 2: Batata doce e suco de laranja\nOpção 3: Bananinha passa + 2 fatias de Tofu\nOpção 4: 1/2 Pão integral com Queijo branco"},{"name":"Jantar","items":[{"food":"Alface, americana, crua","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 2"},{"food":"Vinagrete","grams":30,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 1"},{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"},{"food":"Semente de girassol, torrada, com sal","grams":5,"macros":{"energyKcal":582,"proteinG":19.33,"carbohydrateG":24.07,"fatG":49.8,"fiberG":9,"sodiumMg":410,"calciumMg":70,"ironMg":3.8,"potassiumMg":850},"measure":"Colher de Sopa: 0.5"},{"food":"Frango, peito, sem pele, grelhado","grams":60,"macros":{"energyKcal":159.19,"proteinG":32.03,"carbohydrateG":0,"fatG":2.48,"fiberG":0,"sodiumMg":50.25,"calciumMg":5.34,"ironMg":0.33,"potassiumMg":387.37},"measure":"Grama: 60"},{"food":"Lentilha, cozida","grams":40,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Colher de servir: 0.5"},{"food":"Batata doce, cozida, assada com casca, sem sal","grams":60,"macros":{"energyKcal":90,"proteinG":2.01,"carbohydrateG":20.71,"fatG":0.15,"fiberG":3.3,"sodiumMg":36,"calciumMg":38,"ironMg":0.69,"potassiumMg":475},"measure":"pequena: 1"},{"food":"Suco de maracujá","grams":150,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"Copo Americano: 1"},{"food":"Gelatina de Ágar-ágar","grams":40,"macros":{"energyKcal":50,"proteinG":0,"carbohydrateG":12.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Potinho pequeno: 1"},{"food":"Arroz integral","grams":40,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Sopa: 2"}],"time":"21:00","notes":"Salpicar a semente de girassol no prato."},{"name":"Ceia","items":[{"food":"Leite, de vaca, desnatado, UHT","grams":100,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Grama: 100"},{"food":"Cacau, pó","grams":5,"macros":{"energyKcal":398,"proteinG":5.88,"carbohydrateG":84.52,"fatG":4,"fiberG":3.5,"sodiumMg":504,"calciumMg":141,"ironMg":1.19,"potassiumMg":712},"measure":"Colher de Chá: 1"},{"food":"Canela, pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.85,"fatG":3.19,"fiberG":54.3,"sodiumMg":26,"calciumMg":1228,"ironMg":38.07,"potassiumMg":500},"measure":"colher de chá: 1"},{"food":"Aveia em flocos","grams":7,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sobremesa: 1"},{"food":"Mel","grams":21,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"colher de sopa: 1"}],"time":"22:30","notes":"Misturar todos os ingredientes no copo. Pode bater no liquidificador. "}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 2.100 Kcal (20% PTN)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2100 kcal","20% ptn"],"snapshot":{"dietboxId":1304671,"originalName":"Dieta 2.100 Kcal (20% PTN)","kcalTotal":2097,"summary":{"energyKcal":2097.3,"proteinG":104.8,"carbohydrateG":299.6,"fatG":58.5,"fiberG":40.4,"sodiumMg":1809.6,"calciumMg":768,"ironMg":14.2,"potassiumMg":3611.5},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Copo Americano: 1"},{"food":"Chia - semente","grams":10,"macros":{"energyKcal":520,"proteinG":16.67,"carbohydrateG":49.33,"fatG":32,"fiberG":30.67,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sobremesa: 1"},{"food":"Gengibre, cru","grams":2,"macros":{"energyKcal":80,"proteinG":1.82,"carbohydrateG":17.77,"fatG":0.75,"fiberG":2,"sodiumMg":13,"calciumMg":16,"ironMg":0.6,"potassiumMg":415},"measure":"colher de chá: 1"},{"food":"Café, pó, torrado","grams":6,"macros":{"energyKcal":418.62,"proteinG":14.7,"carbohydrateG":65.75,"fatG":11.95,"fiberG":51.23,"sodiumMg":1.13,"calciumMg":106.89,"ironMg":8.13,"potassiumMg":1608.58},"measure":"Colher De Chá Cheia: 1"},{"food":"Tofu","grams":40,"macros":{"energyKcal":61,"proteinG":6.55,"carbohydrateG":1.8,"fatG":3.69,"fiberG":0.2,"sodiumMg":8,"calciumMg":111,"ironMg":1.11,"potassiumMg":120},"measure":"2 Fatia"},{"food":"Pão integral light","grams":46,"macros":{"energyKcal":198,"proteinG":9.1,"carbohydrateG":43.6,"fatG":2.3,"fiberG":12,"sodiumMg":511,"calciumMg":80,"ironMg":2.96,"potassiumMg":122},"measure":"Fatia: 2"},{"food":"Açúcar","grams":2,"macros":{"energyKcal":387,"proteinG":0,"carbohydrateG":99.98,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":1,"ironMg":0.01,"potassiumMg":2},"measure":"Colher De Cafe: 1"},{"food":"Manteiga com ou sem sal","grams":5,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"Ponta De Faca: 1"},{"food":"Geleia sem açúcar","grams":10,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":4.75,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Ponta de Faca: 1"}],"time":"07:10","notes":"Suco: Bater laranja + chia + gengibre. \nPode adicionar uma pitada de canela no café\n\nOpção 2 de café da manhã: Vitamina de 100 ml de leite desnatado + 0,5 Colher de Sopa de abacate +1 Colher de Sopa de Mel + Colher de Sopa de Chia + Colher de Chá de cacau em pó \n\nOpção 3: 3 Colheres de Sopa de Granola + 1 Colher de Sopa de Goji Berry + 1 Colher de Sopa de Mel + Leite com café e açúcar"},{"name":"Colação","items":[{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Grama: 110"},{"food":"Uva passa","grams":9,"macros":{"energyKcal":299,"proteinG":3.07,"carbohydrateG":79.18,"fatG":0.46,"fiberG":3.7,"sodiumMg":11,"calciumMg":50,"ironMg":1.88,"potassiumMg":749},"measure":"Colher De Sobremesa: 1"}],"time":"10:30","notes":"Opções: 15 uvas; 1 Banana + Barra de Cereal."},{"name":"Almoço","items":[{"food":"Arroz integral","grams":126,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"2 Colher De Arroz/Servir"},{"food":"Feijão, carioca, cozido","grams":65,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Concha Pequena Cheia: 1"},{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Agrião Cozido(a)","grams":25,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"Colher De Arroz/Servir: 0.5"},{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 2"},{"food":"Patinho Cozido(a)","grams":120,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Grama: 120"},{"food":"Melancia","grams":62,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.55,"fatG":0.15,"fiberG":0.4,"sodiumMg":1,"calciumMg":7,"ironMg":0.24,"potassiumMg":112},"measure":"Copo Americano: 1"},{"food":"Hortelã, fresco","grams":0.5,"macros":{"energyKcal":44,"proteinG":3.29,"carbohydrateG":8.41,"fatG":0.73,"fiberG":6.8,"sodiumMg":30,"calciumMg":199,"ironMg":11.87,"potassiumMg":458},"measure":"Grama: 0.5"}],"time":"12:30","notes":"A melancia é para o suco. Bater junto com o hortelã."},{"name":"Lanche da tarde","items":[{"food":"Castanha-do-pará","grams":12,"macros":{"energyKcal":656,"proteinG":14.32,"carbohydrateG":12.27,"fatG":66.43,"fiberG":7.5,"sodiumMg":3,"calciumMg":160,"ironMg":2.43,"potassiumMg":659},"measure":"Unidade: 3"},{"food":"Banana","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.)  (Unidade: 1"},{"food":"Maçã","grams":90,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade Pequena: 1"}],"time":"16:30"},{"name":"Pré-treino","items":[{"food":"Tapioca de goma","grams":45,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 3"},{"food":"Queijo, minas, frescal","grams":30,"macros":{"energyKcal":264.27,"proteinG":17.41,"carbohydrateG":3.24,"fatG":20.18,"fiberG":0,"sodiumMg":31.23,"calciumMg":579.25,"ironMg":0.93,"potassiumMg":104.85},"measure":"Fatia Média (30g): 1"},{"food":"Manjericão, seco","grams":0.5,"macros":{"energyKcal":251,"proteinG":14.37,"carbohydrateG":60.96,"fatG":3.98,"fiberG":40.5,"sodiumMg":34,"calciumMg":2113,"ironMg":42,"potassiumMg":3433},"measure":"colher de chá, folhas: 0.5"},{"food":"Suco de uva integral","grams":110,"macros":{"energyKcal":67,"proteinG":0.3,"carbohydrateG":15.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"ml: 110"}],"time":"19:00","notes":"40 min antes do treino - \n\nOpção 2: Batata doce e suco de laranja\nOpção 3: Bananinha passa + 2 fatias de Tofu\nOpção 4: 1/2 Pão integral com Queijo branco"},{"name":"Jantar","items":[{"food":"Alface, americana, crua","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 2"},{"food":"Vinagrete","grams":30,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 1"},{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"},{"food":"Semente de girassol, torrada, com sal","grams":5,"macros":{"energyKcal":582,"proteinG":19.33,"carbohydrateG":24.07,"fatG":49.8,"fiberG":9,"sodiumMg":410,"calciumMg":70,"ironMg":3.8,"potassiumMg":850},"measure":"Colher de Sopa: 0.5"},{"food":"Frango, peito, sem pele, grelhado","grams":60,"macros":{"energyKcal":159.19,"proteinG":32.03,"carbohydrateG":0,"fatG":2.48,"fiberG":0,"sodiumMg":50.25,"calciumMg":5.34,"ironMg":0.33,"potassiumMg":387.37},"measure":"Grama: 60"},{"food":"Arroz integral","grams":80,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"4 Colher De Sopa"},{"food":"Lentilha, cozida","grams":40,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Colher de servir: 0.5"},{"food":"Batata doce, cozida, assada com casca, sem sal","grams":60,"macros":{"energyKcal":90,"proteinG":2.01,"carbohydrateG":20.71,"fatG":0.15,"fiberG":3.3,"sodiumMg":36,"calciumMg":38,"ironMg":0.69,"potassiumMg":475},"measure":"pequena: 1"},{"food":"Suco de maracujá","grams":150,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"Copo Americano: 1"},{"food":"Gelatina de Ágar-ágar","grams":40,"macros":{"energyKcal":50,"proteinG":0,"carbohydrateG":12.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Potinho pequeno: 1"}],"time":"21:00","notes":"Salpicar a semente de girassol no prato."},{"name":"Ceia","items":[{"food":"Leite, de vaca, desnatado, UHT","grams":100,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Grama: 100"},{"food":"Cacau, pó","grams":5,"macros":{"energyKcal":398,"proteinG":5.88,"carbohydrateG":84.52,"fatG":4,"fiberG":3.5,"sodiumMg":504,"calciumMg":141,"ironMg":1.19,"potassiumMg":712},"measure":"Colher de Chá: 1"},{"food":"Canela, pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.85,"fatG":3.19,"fiberG":54.3,"sodiumMg":26,"calciumMg":1228,"ironMg":38.07,"potassiumMg":500},"measure":"colher de chá: 1"},{"food":"Aveia em flocos","grams":7,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sobremesa: 1"},{"food":"Mel","grams":21,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"colher de sopa: 1"}],"time":"22:30","notes":"Misturar todos os ingredientes no copo. Pode bater no liquidificador. "}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2100},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 2.300 Kcal (20% PTN) - Com pré e pós treino","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2300 kcal","20% ptn"],"snapshot":{"dietboxId":493752,"originalName":"Dieta 2.300 Kcal (20% PTN) - Com pré e pós treino","kcalTotal":2167,"summary":{"energyKcal":2166.9,"proteinG":120.7,"carbohydrateG":291.6,"fatG":62.5,"fiberG":38.7,"sodiumMg":1521.6,"calciumMg":1129,"ironMg":16.7,"potassiumMg":4579.9},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja e cenoura","grams":200,"macros":{"energyKcal":30.77,"proteinG":0.81,"carbohydrateG":7.11,"fatG":0.12,"fiberG":0.76,"sodiumMg":28.03,"calciumMg":17.14,"ironMg":0.39,"potassiumMg":222.58},"measure":"Grama: 200"},{"food":"Chia - semente","grams":5,"macros":{"energyKcal":520,"proteinG":16.67,"carbohydrateG":49.33,"fatG":32,"fiberG":30.67,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sobremesa: 0.5"},{"food":"Gengibre, cru","grams":2,"macros":{"energyKcal":80,"proteinG":1.82,"carbohydrateG":17.77,"fatG":0.75,"fiberG":2,"sodiumMg":13,"calciumMg":16,"ironMg":0.6,"potassiumMg":415},"measure":"colher de chá: 1"},{"food":"Banana, crua","grams":118,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"média (17.8 a 20 cm comp): 1"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"},{"food":"Mel, de abelha","grams":15,"macros":{"energyKcal":309.24,"proteinG":0,"carbohydrateG":84.03,"fatG":0,"fiberG":0,"sodiumMg":6.04,"calciumMg":10.2,"ironMg":0.25,"potassiumMg":99.32},"measure":"Colher de sopa (15g): 1"},{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Mililitro: 150"},{"food":"Café, pó, torrado","grams":6,"macros":{"energyKcal":418.62,"proteinG":14.7,"carbohydrateG":65.75,"fatG":11.95,"fiberG":51.23,"sodiumMg":1.13,"calciumMg":106.89,"ironMg":8.13,"potassiumMg":1608.58},"measure":"Colher De Chá Cheia: 1"},{"food":"Pãozinho, francês","grams":19,"macros":{"energyKcal":277,"proteinG":8.6,"carbohydrateG":50.2,"fatG":4.3,"fiberG":3.2,"sodiumMg":609,"calciumMg":91,"ironMg":2.71,"potassiumMg":114},"measure":"pãozinho: 0.5"},{"food":"Queijo, cottage, cremoso, coalho grande ou pequeno","grams":15,"macros":{"energyKcal":103,"proteinG":12.49,"carbohydrateG":2.68,"fatG":4.51,"fiberG":0,"sodiumMg":405,"calciumMg":60,"ironMg":0.14,"potassiumMg":84},"measure":"Colher de Sopa: 0.5"}],"time":"07:10","notes":"Suco: Bater laranja + cenoura + chia + gengibre. "},{"name":"Colação","items":[{"food":"Chá de Folha de Amora","grams":300,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 300"},{"food":"Noz macadâmia, torrada, com sal","grams":10,"macros":{"energyKcal":716,"proteinG":7.79,"carbohydrateG":12.83,"fatG":76.08,"fiberG":8,"sodiumMg":265,"calciumMg":70,"ironMg":2.65,"potassiumMg":363},"measure":"5 unidades: 1"},{"food":"Melancia, crua","grams":20,"macros":{"energyKcal":32.61,"proteinG":0.88,"carbohydrateG":8.14,"fatG":0,"fiberG":0.12,"sodiumMg":0,"calciumMg":7.72,"ironMg":0.23,"potassiumMg":104.03},"measure":"Fatia Pequena: 1"}],"time":"10:30","notes":"Macadâmia pode ser substituída por: 2 castanhas do pará ou 6 amêndoas. "},{"name":"Almoço","items":[{"food":"Arroz integral","grams":63,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Arroz/Servir: 1"},{"food":"Feijão","grams":70,"macros":{"energyKcal":97.41,"proteinG":5.84,"carbohydrateG":15.05,"fatG":1.79,"fiberG":3.78,"sodiumMg":5.2,"calciumMg":55.2,"ironMg":2.22,"potassiumMg":336.6},"measure":"preto, mulatinho, roxo, rosinha, etc.)  (Concha: 0.5"},{"food":"Patinho Cozido(a)","grams":100,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Grama: 100"},{"food":"Cenoura Cozido(a)","grams":50,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"Colher De Sopa: 2"},{"food":"Espinafre Cozido(a)","grams":50,"macros":{"energyKcal":23,"proteinG":2.97,"carbohydrateG":3.75,"fatG":0.26,"fiberG":2.4,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"Colher De Sopa: 2"},{"food":"Vinagrete","grams":60,"macros":{"energyKcal":76.79,"proteinG":0.65,"carbohydrateG":3.68,"fatG":6.21,"fiberG":0.93,"sodiumMg":1299.77,"calciumMg":19.92,"ironMg":0.65,"potassiumMg":156.7},"measure":"Colher De Sopa: 2"},{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Iogurte desnatado","grams":50,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Grama: 50"},{"food":"Uva passa","grams":4,"macros":{"energyKcal":299,"proteinG":3.07,"carbohydrateG":79.18,"fatG":0.46,"fiberG":3.7,"sodiumMg":11,"calciumMg":50,"ironMg":1.88,"potassiumMg":749},"measure":"Colher De Sobremesa: 0.5"}],"time":"15:30"},{"name":"Pré-treino","items":[{"food":"Tapioca de goma","grams":45,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 3"},{"food":"Queijo, minas, frescal","grams":60,"macros":{"energyKcal":264.27,"proteinG":17.41,"carbohydrateG":3.24,"fatG":20.18,"fiberG":0,"sodiumMg":31.23,"calciumMg":579.25,"ironMg":0.93,"potassiumMg":104.85},"measure":"Fatia Média (30g): 2"},{"food":"Manjericão, seco","grams":0.5,"macros":{"energyKcal":251,"proteinG":14.37,"carbohydrateG":60.96,"fatG":3.98,"fiberG":40.5,"sodiumMg":34,"calciumMg":2113,"ironMg":42,"potassiumMg":3433},"measure":"colher de chá, folhas: 0.5"}],"time":"19:00","notes":"40 min antes do treino"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":126,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Arroz/Servir: 2"},{"food":"Lentilha, cozida","grams":40,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Colher de servir: 0.5"},{"food":"Frango, peito, sem pele, grelhado","grams":90,"macros":{"energyKcal":159.19,"proteinG":32.03,"carbohydrateG":0,"fatG":2.48,"fiberG":0,"sodiumMg":50.25,"calciumMg":5.34,"ironMg":0.33,"potassiumMg":387.37},"measure":"Pedaço pequeno (90g): 1"},{"food":"Alface, americana, crua","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 2"},{"food":"Beterraba","grams":24,"macros":{"energyKcal":43,"proteinG":1.61,"carbohydrateG":9.56,"fatG":0.17,"fiberG":2.8,"sodiumMg":78,"calciumMg":16,"ironMg":0.8,"potassiumMg":325},"measure":"Rodela: 2"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Semente de girassol, óleo assado, com sal","grams":20,"macros":{"energyKcal":592,"proteinG":20.06,"carbohydrateG":22.89,"fatG":51.3,"fiberG":10.6,"sodiumMg":410,"calciumMg":87,"ironMg":4.28,"potassiumMg":483},"measure":"Colher de Sopa: 1"},{"food":"Suco de maracujá","grams":150,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"Grama: 150"},{"food":"Gelatina de Ágar-ágar","grams":40,"macros":{"energyKcal":50,"proteinG":0,"carbohydrateG":12.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Potinho pequeno: 1"}],"time":"21:00","notes":"Salpicar a semente de girassol no prato."},{"name":"Ceia","items":[{"food":"Leite, de vaca, desnatado, UHT","grams":100,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Grama: 100"},{"food":"Cacau, pó","grams":5,"macros":{"energyKcal":398,"proteinG":5.88,"carbohydrateG":84.52,"fatG":4,"fiberG":3.5,"sodiumMg":504,"calciumMg":141,"ironMg":1.19,"potassiumMg":712},"measure":"Colher de Chá: 1"},{"food":"Canela, pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.85,"fatG":3.19,"fiberG":54.3,"sodiumMg":26,"calciumMg":1228,"ironMg":38.07,"potassiumMg":500},"measure":"colher de chá: 1"},{"food":"Aveia em flocos","grams":7,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sobremesa: 1"}],"time":"22:30","notes":"Misturar todos os ingredientes. Pode bater no liquidificador se quiser."},{"name":"Lanche da tarde","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"17:15","notes":"Pode ser substituído por: 6 uvas ou 1 fatia grande de abacaxi, 1 goiaba, 1 kiwi, 1 pera, 1/4 de mamão"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2300},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta 2.800 Kcal (20% PTN) - Dias de treino; Sem suplementação","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2800 kcal","20% ptn"],"snapshot":{"dietboxId":493754,"originalName":"Dieta 2.800 Kcal (20% PTN) - Dias de treino; Sem suplementação","kcalTotal":2693,"summary":{"energyKcal":2692.6,"proteinG":144.6,"carbohydrateG":346,"fatG":92.4,"fiberG":64,"sodiumMg":1775.1,"calciumMg":1232.7,"ironMg":27.4,"potassiumMg":5200.2},"meals":[{"name":"Café da manhã","items":[{"food":"Cereal matinal, Kellogg, Kellogg's All-Bran Original","grams":60,"macros":{"energyKcal":260,"proteinG":13.14,"carbohydrateG":74.24,"fatG":4.9,"fiberG":29.3,"sodiumMg":242,"calciumMg":389,"ironMg":17.6,"potassiumMg":1020},"measure":"1 xícara: 1"},{"food":"Iogurte natural","grams":170,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Mililitro: 170"},{"food":"Chia - semente","grams":10,"macros":{"energyKcal":520,"proteinG":16.67,"carbohydrateG":49.33,"fatG":32,"fiberG":30.67,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sobremesa: 1"},{"food":"Goji Berry","grams":10,"macros":{"energyKcal":256,"proteinG":6.89,"carbohydrateG":23,"fatG":0,"fiberG":7.14,"sodiumMg":125,"calciumMg":0,"ironMg":0,"potassiumMg":1214.29},"measure":"Colher de Sopa: 1"},{"food":"Semente de girassol, óleo assada, sem sal","grams":12,"macros":{"energyKcal":592,"proteinG":20.06,"carbohydrateG":22.89,"fatG":51.3,"fiberG":10.6,"sodiumMg":3,"calciumMg":87,"ironMg":4.28,"potassiumMg":483},"measure":"Colher de Sopa: 1"},{"food":"Mel","grams":42,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"colher de sopa: 2"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo, cottage, cremoso, coalho grande ou pequeno","grams":60,"macros":{"energyKcal":103,"proteinG":12.49,"carbohydrateG":2.68,"fatG":4.51,"fiberG":0,"sodiumMg":405,"calciumMg":60,"ironMg":0.14,"potassiumMg":84},"measure":"Colher de Sopa: 2"},{"food":"Gergelim, semente","grams":9,"macros":{"energyKcal":583.55,"proteinG":21.16,"carbohydrateG":21.62,"fatG":50.43,"fiberG":11.87,"sodiumMg":2.58,"calciumMg":825.45,"ironMg":5.45,"potassiumMg":546.29},"measure":"Colher De Sopa: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Uva, Itália, crua","grams":40,"macros":{"energyKcal":52.87,"proteinG":0.75,"carbohydrateG":13.57,"fatG":0.2,"fiberG":0.92,"sodiumMg":0,"calciumMg":6.66,"ironMg":0.14,"potassiumMg":161.94},"measure":"10 unidades: 1"},{"food":"Torrada","grams":21,"macros":{"energyKcal":426,"proteinG":10.1,"carbohydrateG":74.2,"fatG":9.7,"fiberG":2.5,"sodiumMg":232,"calciumMg":20,"ironMg":0.6,"potassiumMg":305},"measure":"unidade: 3"},{"food":"Geleia sem açúcar","grams":30,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":4.75,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Ponta de Faca: 3"}],"time":"10:00","notes":"ou 1 bananinha ou outra fruta"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":126,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Arroz/Servir: 2"},{"food":"Feijão, carioca, cozido","grams":140,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Concha Média Cheia: 1"},{"food":"Carne bovina  Ao alho e óleo","grams":150,"macros":{"energyKcal":261.14,"proteinG":24.24,"carbohydrateG":0,"fatG":17.59,"fiberG":0,"sodiumMg":82.37,"calciumMg":8.64,"ironMg":2.81,"potassiumMg":337.64},"measure":"Grama: 150"},{"food":"Outros legumes cozidos","grams":110,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Arroz/Servir: 2"},{"food":"Alface, americana, crua","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 2"},{"food":"Cenoura Ao vinagrete","grams":40,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"Colher De Arroz/Servir: 1"},{"food":"Espinafre Cozido(a)","grams":50,"macros":{"energyKcal":23,"proteinG":2.97,"carbohydrateG":3.75,"fatG":0.26,"fiberG":2.4,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"Colher De Arroz/Servir: 1"},{"food":"Couve, crua","grams":18,"macros":{"energyKcal":30,"proteinG":2.45,"carbohydrateG":5.69,"fatG":0.42,"fiberG":3.6,"sodiumMg":20,"calciumMg":145,"ironMg":0.19,"potassiumMg":169},"measure":"xícara, talhada: 0.5"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sobremesa: 1"},{"food":"Laranja, baía, suco","grams":300,"macros":{"energyKcal":36.65,"proteinG":0.65,"carbohydrateG":8.7,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":5.93,"ironMg":0.06,"potassiumMg":172.56},"measure":"Grama: 300"},{"food":"Broto de alfafa","grams":14,"macros":{"energyKcal":23,"proteinG":3.99,"carbohydrateG":2.1,"fatG":0.69,"fiberG":1.9,"sodiumMg":6,"calciumMg":32,"ironMg":0.96,"potassiumMg":79},"measure":"Colher De Arroz/Servir: 1"},{"food":"Gergelim, semente","grams":9,"macros":{"energyKcal":583.55,"proteinG":21.16,"carbohydrateG":21.62,"fatG":50.43,"fiberG":11.87,"sodiumMg":2.58,"calciumMg":825.45,"ironMg":5.45,"potassiumMg":546.29},"measure":"Colher De Sopa: 1"}],"time":"12:30","notes":"Sempre que tiver disponível, prefira o feijão preto e coloque no prato vegetais verde escuro (crus e cozidos).\nBrotos e alimentos germinados são os mais ricos em vitaminas e minerais. Sempre que tiver, pode comer à vontade."},{"name":"Lanche da tarde","items":[{"food":"Fruta","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Unidade: 1"},{"food":"Castanha-do-pará","grams":8,"macros":{"energyKcal":656,"proteinG":14.32,"carbohydrateG":12.27,"fatG":66.43,"fiberG":7.5,"sodiumMg":3,"calciumMg":160,"ironMg":2.43,"potassiumMg":659},"measure":"Unidade: 2"}],"time":"15:00"},{"name":"Pré-treino","items":[{"food":"Bananinha","grams":40,"macros":{"energyKcal":300,"proteinG":4,"carbohydrateG":65,"fatG":0,"fiberG":9,"sodiumMg":0,"calciumMg":22,"ironMg":0.8,"potassiumMg":1},"measure":"Unidade: 2"}],"time":"17:20","notes":"Ou Polenguinho Ou Barra de cereal Ou Vitamina com 1 fruta "},{"name":"Pós-treino","items":[{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Mililitro: 110"}],"time":"19:00","notes":"Comer o quanto antes um alimento fonte de proteína.  Uma opção, é levar leite em pó (2 colheres de sopa bem cheias e misturar na água com um pouco de caucau em pó ou canela. Levar em potinhos e misturar na própria garrafinha que você bebeu água durante o treino). Ideal é ser aquelas garrafinhas de academia mesmo, não as comuns (porque da pra lavar)."},{"name":"Jantar","items":[{"food":"Quinoa","grams":15,"macros":{"energyKcal":135.47,"proteinG":4.37,"carbohydrateG":19.83,"fatG":4.33,"fiberG":2.16,"sodiumMg":4.27,"calciumMg":16.57,"ironMg":1.41,"potassiumMg":174.05},"measure":"Colher De Sopa: 3"},{"food":"Agrião Ao vinagrete","grams":38,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"Porcao: 1"},{"food":"Limão, cravo, suco","grams":50,"macros":{"energyKcal":14.1,"proteinG":0.33,"carbohydrateG":5.25,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":10.18,"ironMg":0.08,"potassiumMg":119.88},"measure":"Copo Limonada: 1"},{"food":"Batata, doce, cozida","grams":180,"macros":{"energyKcal":76.76,"proteinG":0.64,"carbohydrateG":18.42,"fatG":0.09,"fiberG":2.21,"sodiumMg":2.7,"calciumMg":17.15,"ironMg":0.19,"potassiumMg":148.44},"measure":"Unidade Pequena: 2"},{"food":"Pepino, cru","grams":18,"macros":{"energyKcal":9.53,"proteinG":0.87,"carbohydrateG":2.04,"fatG":0,"fiberG":1.12,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.15,"potassiumMg":153.69},"measure":"Colher De Sopa Cheia: 1"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sobremesa: 1"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé Pequeno: 2"},{"food":"Espinafre","grams":45,"macros":{"energyKcal":23,"proteinG":2.98,"carbohydrateG":3.76,"fatG":0.26,"fiberG":2.3,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"cozido) (Colher de Sopa: 3"}],"time":"21:00","notes":"Cozinhar a quinoa de acordo com a embalagem. Misturar com o pepino como se fosse um tabule. Adicionar um pouco de sal e suco de meio limão. Colocar o azeite por cima e misturar. Temperar o frango com sal, cúrcuma e pimenta do reino. "}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2800},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta anti-inflamatória 1200 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1200 kcal","anti_inflammatory"],"snapshot":{"dietboxId":19507516,"originalName":"Dieta anti-inflamatória 1200 Kcal","kcalTotal":1223,"summary":{"energyKcal":1223.4,"proteinG":93.4,"carbohydrateG":133.4,"fatG":38.7,"fiberG":19.9,"sodiumMg":732.3,"calciumMg":432.8,"ironMg":10.1,"potassiumMg":2927.2},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja e cenoura","grams":150,"macros":{"energyKcal":30.77,"proteinG":0.81,"carbohydrateG":7.11,"fatG":0.12,"fiberG":0.76,"sodiumMg":28.03,"calciumMg":17.14,"ironMg":0.39,"potassiumMg":222.58},"measure":"Copo Americano: 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo ricota","grams":44,"macros":{"energyKcal":174,"proteinG":11.26,"carbohydrateG":3.04,"fatG":12.98,"fiberG":0,"sodiumMg":84,"calciumMg":207,"ironMg":0.38,"potassiumMg":105},"measure":"Colher De Sopa: 1"},{"food":"Orégano","grams":2,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.43,"fatG":10.25,"fiberG":42.8,"sodiumMg":15,"calciumMg":1576,"ironMg":44,"potassiumMg":1669},"measure":"Colher de chá (2g): 1"}],"time":"08:30","notes":"Aqui, você pode temperar a sua ricota a gosto. Um exemplo, foi o orégano, mas pode-se utilizar manjericão, alecrim, tomilho, salsa..."},{"name":"Colação","items":[{"food":"Nozes","grams":25,"macros":{"energyKcal":642,"proteinG":14.3,"carbohydrateG":18.3,"fatG":61.9,"fiberG":4.53,"sodiumMg":10,"calciumMg":94,"ironMg":2.45,"potassiumMg":502},"measure":"Colher de sopa moída (25g): 1"},{"food":"Banana, prata, crua","grams":90,"macros":{"energyKcal":98.25,"proteinG":1.27,"carbohydrateG":25.96,"fatG":0.07,"fiberG":2.04,"sodiumMg":0,"calciumMg":7.56,"ironMg":0.38,"potassiumMg":357.68},"measure":"Unidade Pequena: 1"}],"time":"10:30","notes":"Opção de fruta com topping."},{"name":"Almoço","items":[{"food":"Repolho Refogado(a)","grams":45,"macros":{"energyKcal":49.77,"proteinG":1.27,"carbohydrateG":5.51,"fatG":3.09,"fiberG":1.9,"sodiumMg":8,"calciumMg":48,"ironMg":0.17,"potassiumMg":196},"measure":"Colher De Arroz/Servir: 1"},{"food":"Tomate cereja","grams":80,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 8"},{"food":"Grão de bico","grams":45,"macros":{"energyKcal":188.48,"proteinG":8.86,"carbohydrateG":27.42,"fatG":5.36,"fiberG":7.6,"sodiumMg":7,"calciumMg":49,"ironMg":2.89,"potassiumMg":291},"measure":"Colher De Arroz/Servir: 1"},{"food":"Batata, inglesa, sauté","grams":80,"macros":{"energyKcal":67.89,"proteinG":1.29,"carbohydrateG":14.09,"fatG":0.9,"fiberG":1.38,"sodiumMg":8.18,"calciumMg":4.18,"ironMg":0.25,"potassiumMg":199.48},"measure":"Grama: 80"},{"food":"Peixe de água doce","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)  Assado(a) (File: 1"},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Cha: 1"}],"time":"12:30"},{"name":"Jantar","items":[{"food":"Couve Refogado(a)","grams":42,"macros":{"energyKcal":47.13,"proteinG":2.11,"carbohydrateG":4.91,"fatG":2.75,"fiberG":2.8,"sodiumMg":16,"calciumMg":140,"ironMg":1.16,"potassiumMg":116},"measure":"Colher De Arroz/Servir: 1"},{"food":"Abóbora Cozido(a)","grams":72,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230},"measure":"Colher De Sopa: 2"},{"food":"Lentilha cozida","grams":45,"macros":{"energyKcal":116,"proteinG":9.03,"carbohydrateG":20.1,"fatG":0.38,"fiberG":4.55,"sodiumMg":2,"calciumMg":19,"ironMg":3.34,"potassiumMg":369},"measure":"grãos) (Colher de servir (45g): 1"},{"food":"Arroz integral","grams":100,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 5"},{"food":"Peixe de água doce","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)  Assado(a) (File: 1"},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Cha: 1"}],"time":"18:30"},{"name":"Lanche da tarde","items":[{"food":"Smoothie proteico de frutas vermelhas","grams":80,"macros":{"energyKcal":80.46,"proteinG":5.76,"carbohydrateG":15.59,"fatG":0.2,"fiberG":0.83,"sodiumMg":22.17,"calciumMg":27.89,"ironMg":1.06,"potassiumMg":172.41},"measure":"Grama: 80"}],"time":"15:00"}]},"dimensions":{"approaches":["anti_inflammatory"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta anti-inflamatória 1500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","anti_inflammatory"],"snapshot":{"dietboxId":19507523,"originalName":"Dieta anti-inflamatória 1500 Kcal","kcalTotal":1507,"summary":{"energyKcal":1506.7,"proteinG":73.3,"carbohydrateG":169.1,"fatG":65.2,"fiberG":26.4,"sodiumMg":583,"calciumMg":431.1,"ironMg":10.8,"potassiumMg":2886.8},"meals":[{"name":"Café da manhã","items":[{"food":"Café","grams":50,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0.47,"fatG":0.02,"fiberG":0.47,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49.05},"measure":"Xicara De Cafe: 1"},{"food":"Salada de frutas completa","grams":250,"macros":{"energyKcal":52.51,"proteinG":0.7,"carbohydrateG":12.99,"fatG":0.29,"fiberG":1.26,"sodiumMg":1.45,"calciumMg":17.13,"ironMg":0.22,"potassiumMg":206.63},"measure":"laranja, banana, mamão, abacaxi, uva, melão, maçã, pêra, kiwi) (Xícara de chá (250g): 1"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 1"},{"food":"Chia, semente, seca","grams":10,"macros":{"energyKcal":443,"proteinG":16.5,"carbohydrateG":42.1,"fatG":30.7,"fiberG":34.4,"sodiumMg":16,"calciumMg":631,"ironMg":7.72,"potassiumMg":407},"measure":"Grama: 10"},{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote 110 g: 1"},{"food":"Mel","grams":15,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher De Sopa: 1"}],"time":"08:30","notes":"Opção de salada de frutas com toppings + iogurte com mel + café."},{"name":"Colação","items":[{"food":"Morango","grams":80,"macros":{"energyKcal":32,"proteinG":0.67,"carbohydrateG":7.68,"fatG":0.3,"fiberG":2,"sodiumMg":1,"calciumMg":16,"ironMg":0.41,"potassiumMg":153},"measure":"Grama: 80"},{"food":"Castanha de caju torrada sem sal","grams":20,"macros":{"energyKcal":574,"proteinG":15.3,"carbohydrateG":32.7,"fatG":46.4,"fiberG":3.02,"sodiumMg":16,"calciumMg":45,"ironMg":6.01,"potassiumMg":565},"measure":"Grama: 20"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Beterraba","grams":48,"macros":{"energyKcal":43,"proteinG":1.62,"carbohydrateG":9.57,"fatG":0.17,"fiberG":2.8,"sodiumMg":78,"calciumMg":16,"ironMg":0.8,"potassiumMg":325},"measure":"crua) (Colher de sopa cheia ralada (16g): 3"},{"food":"Ervilha em grão","grams":38,"macros":{"energyKcal":109.09,"proteinG":5.36,"carbohydrateG":15.63,"fatG":3.06,"fiberG":5.5,"sodiumMg":3,"calciumMg":27,"ironMg":1.54,"potassiumMg":271},"measure":"Colher De Arroz/Servir: 1"},{"food":"Frango com açafrão","grams":100,"macros":{"energyKcal":140,"proteinG":15.8,"carbohydrateG":2.74,"fatG":7.39,"fiberG":0.22,"sodiumMg":28.8,"calciumMg":13,"ironMg":0.84,"potassiumMg":256},"measure":"cúrcuma), s/ sal (Grama: 100"},{"food":"Aipim Cozido(a)","grams":60,"macros":{"energyKcal":125,"proteinG":0.6,"carbohydrateG":30.1,"fatG":0.3,"fiberG":1.6,"sodiumMg":1,"calciumMg":19,"ironMg":0.1,"potassiumMg":100},"measure":"Colher De Arroz/Servir: 1"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"}],"time":"12:30"},{"name":"Jantar","items":[{"food":"Rúcula, crua","grams":1,"macros":{"energyKcal":13.13,"proteinG":1.77,"carbohydrateG":2.22,"fatG":0.11,"fiberG":1.74,"sodiumMg":9.42,"calciumMg":116.56,"ironMg":0.94,"potassiumMg":233.4},"measure":"Xícara de chá: 1"},{"food":"Couve-flor","grams":50,"macros":{"energyKcal":23,"proteinG":1.84,"carbohydrateG":4.11,"fatG":0.45,"fiberG":2.3,"sodiumMg":15,"calciumMg":16,"ironMg":0.32,"potassiumMg":142},"measure":"Colher De Sopa: 2"},{"food":"Soja","grams":43,"macros":{"energyKcal":173,"proteinG":16.6,"carbohydrateG":9.93,"fatG":8.98,"fiberG":6.27,"sodiumMg":1,"calciumMg":102,"ironMg":5.15,"potassiumMg":515},"measure":"cozida) (Colher de servir (43g): 1"},{"food":"Salmão, filé, com pele, fresco,  grelhado","grams":100,"macros":{"energyKcal":228.73,"proteinG":23.92,"carbohydrateG":0,"fatG":14.04,"fiberG":0,"sodiumMg":85.14,"calciumMg":28.76,"ironMg":0.54,"potassiumMg":383.94},"measure":"Grama: 100"},{"food":"Batata, baroa, cozida","grams":100,"macros":{"energyKcal":80.12,"proteinG":0.85,"carbohydrateG":18.95,"fatG":0.17,"fiberG":1.76,"sodiumMg":2.1,"calciumMg":11.85,"ironMg":0.42,"potassiumMg":258.33},"measure":"Grama: 100"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"}],"time":"18:30"},{"name":"Lanche da tarde","items":[{"food":"Bolo de banana e maçã com cacau","grams":80,"macros":{"energyKcal":160.05,"proteinG":7.23,"carbohydrateG":25.46,"fatG":3.6,"fiberG":3.26,"sodiumMg":29.34,"calciumMg":24.56,"ironMg":1.74,"potassiumMg":281.28},"measure":"Grama: 80"},{"food":"Chá","grams":50,"macros":{"energyKcal":1,"proteinG":0,"carbohydrateG":0.3,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":0,"ironMg":0.02,"potassiumMg":37.03},"measure":"preto, camomila, erva-cidreira, capim limão, etc.)  (Xicara De Cafe: 1"}],"time":"15:30"},{"name":"Ceia","items":[{"food":"Pipoca salgada","grams":26,"macros":{"energyKcal":497.22,"proteinG":8.57,"carbohydrateG":55.67,"fatG":28.37,"fiberG":10.79,"sodiumMg":1274.08,"calciumMg":7.95,"ironMg":1.92,"potassiumMg":215.35},"measure":"Copo de requeijão (13g): 2"}],"time":"20:30"}]},"dimensions":{"approaches":["anti_inflammatory"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta anti-inflamatória 2000 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","anti_inflammatory"],"snapshot":{"dietboxId":19507491,"originalName":"Dieta anti-inflamatória 2000 Kcal","kcalTotal":2000,"summary":{"energyKcal":2000.1,"proteinG":128.5,"carbohydrateG":203.6,"fatG":79.2,"fiberG":34.6,"sodiumMg":1335.1,"calciumMg":295.6,"ironMg":9.1,"potassiumMg":3388.7},"meals":[{"name":"Café da manhã","items":[{"food":"Tapioca de goma","grams":60,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 60"},{"food":"Ovo de galinha Cozido(a)","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Semente de chia","grams":10,"macros":{"energyKcal":526.67,"proteinG":19.33,"carbohydrateG":40,"fatG":32,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Morango","grams":150,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Grama: 150"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Arroz integral","grams":150,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 150"},{"food":"Feijão, preto, cozido","grams":100,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Grama: 100"},{"food":"Azeite, de oliva, extra virgem","grams":10,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Frango grelhado com cúrcuma N.FIT","grams":130,"macros":{"energyKcal":134,"proteinG":25,"carbohydrateG":1,"fatG":3,"fiberG":0,"sodiumMg":341,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 130"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Abacate","grams":150,"macros":{"energyKcal":161,"proteinG":1.99,"carbohydrateG":7.4,"fatG":15.3,"fiberG":4.1,"sodiumMg":10,"calciumMg":11,"ironMg":1.03,"potassiumMg":599},"measure":"Grama: 150"},{"food":"Whey Protein Concentrado DUX - Baunilha","grams":28,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 1"},{"food":"Leite de amêndoas","grams":200,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 200"},{"food":"Aveia em flocos","grams":20,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 20"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Batata doce cozida sem sal","grams":160,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Grama: 160"},{"food":"Salmão grelhado N.FIT","grams":150,"macros":{"energyKcal":192,"proteinG":23,"carbohydrateG":0,"fatG":11,"fiberG":0,"sodiumMg":302,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 150"}],"time":"19:30"}]},"dimensions":{"approaches":["anti_inflammatory"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta anti-inflamatória para celulite 1200 Kcal","objective":"Cardápio clínico para objetivo estético — adaptar à avaliação nutricional do paciente.","tags":["1200 kcal","anti_inflammatory"],"snapshot":{"dietboxId":20201468,"originalName":"Dieta anti-inflamatória para celulite 1200 Kcal","kcalTotal":1210,"summary":{"energyKcal":1210.3,"proteinG":82.2,"carbohydrateG":120.5,"fatG":46.5,"fiberG":25.3,"sodiumMg":1029.7,"calciumMg":682,"ironMg":10.3,"potassiumMg":2567.9},"meals":[{"name":"Café da manhã","items":[{"food":"Melancia","grams":100,"macros":{"energyKcal":32,"proteinG":0.62,"carbohydrateG":7.19,"fatG":0.43,"fiberG":0.23,"sodiumMg":2,"calciumMg":8,"ironMg":0.17,"potassiumMg":116},"measure":"Fatia pequena (100g): 1"},{"food":"Hortelã","grams":2,"macros":{"energyKcal":43,"proteinG":3.8,"carbohydrateG":5.3,"fatG":0.7,"fiberG":0,"sodiumMg":15,"calciumMg":210,"ironMg":9.5,"potassiumMg":260},"measure":"Folha (0,4g): 2"},{"food":"Gengibre","grams":5,"macros":{"energyKcal":70.83,"proteinG":1.67,"carbohydrateG":15,"fatG":0.83,"fiberG":2.08,"sodiumMg":12.5,"calciumMg":16.67,"ironMg":0.5,"potassiumMg":416.67},"measure":"Colher de chá ralado (5g): 1"},{"food":"Água","grams":165,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo pequeno (165ml): 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo cottage com sal do himalaia - Verde Campo","grams":25,"macros":{"energyKcal":128,"proteinG":13.2,"carbohydrateG":3.2,"fatG":7,"fiberG":0,"sodiumMg":200,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa: 1"}],"time":"08:30","notes":"# Misturar a melancia + hortelã + gengibre e fazer um suco. Não coar!"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 4"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"},{"food":"Filé de peixe grelhado/assado","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"filé (120g): 1"},{"food":"Mix de cenoura e beterraba","grams":50,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (Colher de sopa cheia (picada) (25g): 2"},{"food":"Mix de folhas verdes","grams":60,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Escumadeira: 1"},{"food":"Azeite de oliva extra virgem","grams":2,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de chá (2,4ml): 1"},{"food":"Vinagre de maçã","grams":50,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa (10,65g): 5"}],"time":"12:00","notes":"# Temperar o mix de folhas verdes, a beterraba e a cenoura com azeite de oliva e o vinagre;"},{"name":"Jantar","items":[{"food":"Ovo de galinha","grams":135,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 3"},{"food":"Ricota","grams":50,"macros":{"energyKcal":174,"proteinG":11.3,"carbohydrateG":3.05,"fatG":13,"fiberG":0,"sodiumMg":84.1,"calciumMg":207,"ironMg":0.38,"potassiumMg":105},"measure":"Fatia (50g): 1"},{"food":"Tomate a vontade","grams":80,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Porção: 1"},{"food":"Orégano à gosto","grams":2,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.43,"fatG":10.25,"fiberG":42.8,"sodiumMg":15,"calciumMg":1576,"ironMg":44,"potassiumMg":1669}},{"food":"Manjericão fresco à gosto","grams":3,"macros":{"energyKcal":27,"proteinG":2.54,"carbohydrateG":4.35,"fatG":0.61,"fiberG":2.52,"sodiumMg":4.01,"calciumMg":154,"ironMg":3.17,"potassiumMg":462}},{"food":"Cúrcuma","grams":1,"macros":{"energyKcal":354,"proteinG":7.83,"carbohydrateG":64.9,"fatG":9.88,"fiberG":21.1,"sodiumMg":37.8,"calciumMg":183,"ironMg":41.4,"potassiumMg":2525},"measure":"Pitada: 1"},{"food":"Pimenta do reino em pó","grams":0.1,"macros":{"energyKcal":255,"proteinG":10.9,"carbohydrateG":64.8,"fatG":3.26,"fiberG":26.5,"sodiumMg":44,"calciumMg":437,"ironMg":28.9,"potassiumMg":1259},"measure":"Pitada: 1"}],"time":"19:00","notes":"# Omelete caprese de queijo;\n# Tempere com manjericão, orégano, cúrcuma, pimenta  à gosto. "},{"name":"Desjejum","items":[{"food":"Água","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (250ml): 1"}],"time":"08:00","notes":"# Oriente seu paciente a começar o dia tomando um copo de água em jejum;"},{"name":"Lanche da tarde","items":[{"food":"Morango","grams":96,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 8"},{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Copo médio (200 Ml): 1"},{"food":"Mel","grams":7,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher de chá (7g): 1"},{"food":"Mix de sementes","grams":10,"macros":{"energyKcal":495.1,"proteinG":14.08,"carbohydrateG":43.31,"fatG":32.25,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211.5,"ironMg":4.7,"potassiumMg":869.29},"measure":"linhaça, chia, abóbora, girassol....) (Colher sopa: 1"},{"food":"Farelo de aveia","grams":11,"macros":{"energyKcal":350,"proteinG":20,"carbohydrateG":50,"fatG":10,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":5,"potassiumMg":0},"measure":"Colher de sopa (11g): 1"},{"food":"Canela em pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"Colher de chá (2g): 1"}],"time":"15:00","notes":"# Overnight = Misturar todos os ingredientes e deixar na geladeira de um dia para o outro;"},{"name":"Café da manhã","items":[{"food":"Chá verde sem açúcar","grams":120,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Xícara: 1"}],"time":"10:00"},{"name":"Ceia","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média: 1"},{"food":"Cacau em pó","grams":2,"macros":{"energyKcal":400,"proteinG":20,"carbohydrateG":60,"fatG":0,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":11.4,"potassiumMg":0},"measure":"Colher de chá (2,46g): 1"},{"food":"Mix de sementes","grams":10,"macros":{"energyKcal":495.1,"proteinG":14.08,"carbohydrateG":43.31,"fatG":32.25,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211.5,"ironMg":4.7,"potassiumMg":869.29},"measure":"linhaça, chia, abóbora, girassol....) (Colher sopa: 1"}],"time":"21:00","notes":"# Banana amassada com mix de sementes + cacau;"}]},"dimensions":{"approaches":["anti_inflammatory"],"objectives":["aesthetic"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta anti-inflamatória para lipedema 1700 Kcal","objective":"Cardápio clínico para objetivo estético — adaptar à avaliação nutricional do paciente.","tags":["1700 kcal","anti_inflammatory"],"snapshot":{"dietboxId":20201475,"originalName":"Dieta anti-inflamatória para lipedema 1700 Kcal","kcalTotal":1739,"summary":{"energyKcal":1739.1,"proteinG":98.2,"carbohydrateG":167.4,"fatG":77.8,"fiberG":23.3,"sodiumMg":2083.5,"calciumMg":937.3,"ironMg":13.9,"potassiumMg":2696.6},"meals":[{"name":"Almoço","items":[{"food":"Quinoa cozida","grams":60,"macros":{"energyKcal":120,"proteinG":4.4,"carbohydrateG":21.3,"fatG":1.92,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa (15g): 4"},{"food":"Salmão, filé, com pele, fresco,  grelhado","grams":100,"macros":{"energyKcal":228.73,"proteinG":23.92,"carbohydrateG":0,"fatG":14.04,"fiberG":0,"sodiumMg":85.14,"calciumMg":28.76,"ironMg":0.54,"potassiumMg":383.94},"measure":"Filé (120g): 1"},{"food":"Espinafre Cozido(a)","grams":75,"macros":{"energyKcal":23,"proteinG":2.97,"carbohydrateG":3.75,"fatG":0.26,"fiberG":2.4,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"Colher De Sopa: 3"},{"food":"Tomate cereja","grams":40,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 4"},{"food":"Cenoura Cozido(a)","grams":25,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"Colher De Sopa: 1"}],"time":"12:00","notes":"# Espinafre cozido com cenoura e tomate cereja;"},{"name":"Colação","items":[{"food":"Água","grams":165,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Xícara de chá: 1"},{"food":"Chá verde erva","grams":10,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sobremesa: 1"},{"food":"Maçã cortada em cubos com casca","grams":75,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Metade: 1"}],"time":"10:00","notes":"# Suchá: Primeiramente faça o chá verde e deixe em infusão, com o recipiente tampado, e aguarde esfriar. Bata no liquidificador o chá coado, a maçã e o está pronto!"},{"name":"Café da manhã","items":[{"food":"Panqueca de Cacau","grams":151,"macros":{"energyKcal":269.06,"proteinG":12.47,"carbohydrateG":23.32,"fatG":13.06,"fiberG":3.67,"sodiumMg":75.08,"calciumMg":41.89,"ironMg":2.44,"potassiumMg":121.64},"measure":"Porção: 1"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média: 1"},{"food":"Canela em pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"Colher de chá (2g): 1"},{"food":"Café preto sem açúcar","grams":50,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0.47,"fatG":0.02,"fiberG":0.47,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49.05},"measure":"Xicara De Cafe: 1"}],"time":"08:00","notes":"# Panqueca de cacau recheada com banana + canela;\n# OBS: amassar a banana e misturar com canela para rechear a panqueca;"},{"name":"Lanche da tarde","items":[{"food":"Abacate","grams":40,"macros":{"energyKcal":161,"proteinG":1.99,"carbohydrateG":7.4,"fatG":15.3,"fiberG":4.1,"sodiumMg":10,"calciumMg":11,"ironMg":1.03,"potassiumMg":599},"measure":"Colher de sopa (amassado) (20g): 2"},{"food":"Leite vegetal","grams":200,"macros":{"energyKcal":100,"proteinG":2.5,"carbohydrateG":16,"fatG":3,"fiberG":0,"sodiumMg":75,"calciumMg":63,"ironMg":0.32,"potassiumMg":0},"measure":"Copo de médio (200ml): 1"},{"food":"Cacau em pó","grams":9,"macros":{"energyKcal":400,"proteinG":20,"carbohydrateG":60,"fatG":0,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":11.4,"potassiumMg":0},"measure":"Colher de sobremesa (9,9g): 1"},{"food":"Canela em pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"Colher de chá (2g): 1"}],"time":"15:00","notes":"# Shake de fruta com leite vegetal + cacau/canela;\n# Sugestão de leite vegetal: leite de coco ou leite de amêndoas ou leite de arroz ou leite de aveia;"},{"name":"Ceia","items":[{"food":"Morango","grams":96,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 8"},{"food":"Castanha-do-Brasil, crua","grams":12,"macros":{"energyKcal":642.96,"proteinG":14.54,"carbohydrateG":15.08,"fatG":63.46,"fiberG":7.93,"sodiumMg":0.65,"calciumMg":146.34,"ironMg":2.31,"potassiumMg":650.99},"measure":"Unidade Média (4g): 3"},{"food":"Nozes","grams":9,"macros":{"energyKcal":642,"proteinG":14.3,"carbohydrateG":18.3,"fatG":61.9,"fiberG":4.53,"sodiumMg":10,"calciumMg":94,"ironMg":2.45,"potassiumMg":502},"measure":"Unidade: 2"},{"food":"Chá de camomila sem açúcar","grams":200,"macros":{"energyKcal":1,"proteinG":0,"carbohydrateG":0.3,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":0,"ironMg":0.02,"potassiumMg":37.03},"measure":"Xicara De Cha: 1"}],"time":"21:00"},{"name":"Jantar","items":[{"food":"Pão, sírio, trigo integral","grams":28,"macros":{"energyKcal":266,"proteinG":9.8,"carbohydrateG":55,"fatG":2.6,"fiberG":7.4,"sodiumMg":532,"calciumMg":15,"ironMg":3.06,"potassiumMg":170},"measure":"1 pão, pequeno (10.2 cm diâmetro)"},{"food":"Queijo de minas","grams":90,"macros":{"energyKcal":240,"proteinG":17.6,"carbohydrateG":10.6,"fatG":14.1,"fiberG":0,"sodiumMg":1587,"calciumMg":529,"ironMg":0.2,"potassiumMg":330},"measure":"Fatia: 2"},{"food":"Filé de frango cozido(a) desfiado","grams":60,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Colher de sopa (25g): 3"},{"food":"Beterraba","grams":16,"macros":{"energyKcal":43,"proteinG":1.62,"carbohydrateG":9.57,"fatG":0.17,"fiberG":2.8,"sodiumMg":78,"calciumMg":16,"ironMg":0.8,"potassiumMg":325},"measure":"crua) (Colher de sopa cheia ralada (16g): 1"},{"food":"Alface americana","grams":10,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Folha: 1"},{"food":"Limonada sem açúcar","grams":200,"macros":{"energyKcal":5,"proteinG":0.08,"carbohydrateG":1.73,"fatG":0.01,"fiberG":0.08,"sodiumMg":2.6,"calciumMg":3,"ironMg":0.01,"potassiumMg":24.81},"measure":"Copo de médio (200ml): 1"}],"time":"19:00","notes":"# Wrap de pão sírio com frango + queijo minas + alface + beterraba;"}]},"dimensions":{"approaches":["anti_inflammatory"],"objectives":["aesthetic"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1700},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Branda 1.900 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1900 kcal"],"snapshot":{"dietboxId":1275959,"originalName":"Dieta Branda 1.900 Kcal","kcalTotal":1896,"summary":{"energyKcal":1896.4,"proteinG":101.6,"carbohydrateG":240.9,"fatG":57.8,"fiberG":11.9,"sodiumMg":2376.9,"calciumMg":776.6,"ironMg":11,"potassiumMg":2210.5},"meals":[{"name":"Café da manhã","items":[{"food":"Pão de forma tradicional","grams":50,"macros":{"energyKcal":339.4,"proteinG":9.63,"carbohydrateG":68.81,"fatG":3.03,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"2 Fatia (25g)"},{"food":"Manteiga com ou sem sal","grams":20,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"4 Ponta De Faca"},{"food":"Café com leite","grams":300,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"1 Caneca"}],"time":"07:30"},{"name":"Colação","items":[{"food":"Biscoito Água e Sal - São Luíz Nestlé®","grams":30,"macros":{"energyKcal":466,"proteinG":9.4,"carbohydrateG":68.3,"fatG":17.2,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"6 Unidade"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Arroz branco","grams":75,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (3 Colher de sopa cheia (25g)"},{"food":"Caldo-de-feijão","grams":130,"macros":{"energyKcal":75.5,"proteinG":4.78,"carbohydrateG":10.33,"fatG":1.77,"fiberG":2.2,"sodiumMg":401.39,"calciumMg":33.67,"ironMg":1.35,"potassiumMg":221.4},"measure":"1 Concha"},{"food":"Guisado","grams":70,"macros":{"energyKcal":242,"proteinG":24.22,"carbohydrateG":0,"fatG":15.42,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"1 Colher De Arroz/Servir"},{"food":"Cenoura","grams":25,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (1 Colher de sopa cheia (picada) (25g)"},{"food":"Brócolis","grams":13,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (1 Colher de sopa picado (13,23g)"}],"time":"12:30"},{"name":"Jantar","items":[{"food":"Espaguete, cozido, enriquecido, com sal","grams":180,"macros":{"energyKcal":141,"proteinG":4.77,"carbohydrateG":28.34,"fatG":0.67,"fiberG":1.7,"sodiumMg":100,"calciumMg":7,"ironMg":1.4,"potassiumMg":31},"measure":"2 Pegador"},{"food":"Caldo-de-feijão","grams":130,"macros":{"energyKcal":75.5,"proteinG":4.78,"carbohydrateG":10.33,"fatG":1.77,"fiberG":2.2,"sodiumMg":401.39,"calciumMg":33.67,"ironMg":1.35,"potassiumMg":221.4},"measure":"1 Concha"},{"food":"Peito de galinha ou frango Grelhado","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"1 Bife"},{"food":"Sopa creme de tomate","grams":158,"macros":{"energyKcal":37.72,"proteinG":1.55,"carbohydrateG":4.7,"fatG":1.57,"fiberG":0.48,"sodiumMg":309.02,"calciumMg":43.47,"ironMg":0.22,"potassiumMg":113.35},"measure":"2 Concha (79g)"}],"time":"21:00"},{"name":"Ceia","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"}],"time":"23:00"},{"name":"Lanche da tarde","items":[{"food":"Biscoito Maria","grams":30,"macros":{"energyKcal":449,"proteinG":7.4,"carbohydrateG":73.2,"fatG":14.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"6 Unidade"}],"time":"15:00"},{"name":"Lanche da tarde","items":[{"food":"Pão de forma tradicional","grams":25,"macros":{"energyKcal":339.4,"proteinG":9.63,"carbohydrateG":68.81,"fatG":3.03,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"1 Fatia (25g)"},{"food":"Geleia de frutas de qualquer marca ou sabor","grams":24,"macros":{"energyKcal":278,"proteinG":0.37,"carbohydrateG":68.86,"fatG":0.07,"fiberG":1.1,"sodiumMg":32,"calciumMg":20,"ironMg":0.49,"potassiumMg":77},"measure":"2 Ponta De Faca"}],"time":"17:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1900},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Cetogênica - 1200 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1200 kcal","ketogenic"],"snapshot":{"dietboxId":19201991,"originalName":"Dieta Cetogênica - 1200 Kcal","kcalTotal":1252,"summary":{"energyKcal":1252.4,"proteinG":78.6,"carbohydrateG":34.2,"fatG":91.4,"fiberG":16.1,"sodiumMg":659.2,"calciumMg":548.6,"ironMg":6.1,"potassiumMg":1808.5},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Abacate","grams":80,"macros":{"energyKcal":120,"proteinG":2.23,"carbohydrateG":7.82,"fatG":10.06,"fiberG":5.6,"sodiumMg":2,"calciumMg":10,"ironMg":0.17,"potassiumMg":351},"measure":"Grama: 80"},{"food":"Queijo de coalho","grams":45,"macros":{"energyKcal":373,"proteinG":24.48,"carbohydrateG":0.68,"fatG":30.28,"fiberG":0,"sodiumMg":536,"calciumMg":746,"ironMg":0.72,"potassiumMg":81},"measure":"Fatia: 1"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 100"},{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Brócolis","grams":80,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 80"},{"food":"Cenoura","grams":40,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (Colher de arroz cheia (picada) (40g): 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Abacate","grams":80,"macros":{"energyKcal":120,"proteinG":2.23,"carbohydrateG":7.82,"fatG":10.06,"fiberG":5.6,"sodiumMg":2,"calciumMg":10,"ironMg":0.17,"potassiumMg":351},"measure":"Grama: 80"},{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Queijo minas frescal","grams":30,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 1"},{"food":"Castanha do Pará sem sal","grams":12,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 3"}],"time":"17:00"},{"name":"Jantar","items":[{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"},{"food":"Ovo de galinha Cozido(a)","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Alface, americana, crua","grams":48,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Colher de sopa cheia: 6"},{"food":"Beterraba","grams":80,"macros":{"energyKcal":43,"proteinG":1.62,"carbohydrateG":9.57,"fatG":0.17,"fiberG":2.8,"sodiumMg":78,"calciumMg":16,"ironMg":0.8,"potassiumMg":325},"measure":"crua) (Unidade pequena (80g): 1"}],"time":"20:30"}]},"dimensions":{"approaches":["ketogenic"],"objectives":[],"restrictions":["very_low_carb"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Cetogênica - 1500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","ketogenic"],"snapshot":{"dietboxId":19202270,"originalName":"Dieta Cetogênica - 1500 Kcal","kcalTotal":1512,"summary":{"energyKcal":1512.1,"proteinG":133.4,"carbohydrateG":38.8,"fatG":92.6,"fiberG":17.2,"sodiumMg":742.9,"calciumMg":532.9,"ironMg":7.4,"potassiumMg":2575.4},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Abacate","grams":100,"macros":{"energyKcal":120,"proteinG":2.23,"carbohydrateG":7.82,"fatG":10.06,"fiberG":5.6,"sodiumMg":2,"calciumMg":10,"ironMg":0.17,"potassiumMg":351},"measure":"Grama: 100"},{"food":"Queijo minas frescal","grams":30,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 1"},{"food":"Chia, semente, seca","grams":10,"macros":{"energyKcal":443,"proteinG":16.5,"carbohydrateG":42.1,"fatG":30.7,"fiberG":34.4,"sodiumMg":16,"calciumMg":631,"ironMg":7.72,"potassiumMg":407},"measure":"Grama: 10"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Peixe de água doce","grams":200,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)  Cozido(a) (Grama: 200"},{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Pepino, cru","grams":100,"macros":{"energyKcal":9.53,"proteinG":0.87,"carbohydrateG":2.04,"fatG":0,"fiberG":1.12,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.15,"potassiumMg":153.69},"measure":"Grama: 100"},{"food":"Repolho branco","grams":90,"macros":{"energyKcal":25,"proteinG":1.45,"carbohydrateG":5.44,"fatG":0.27,"fiberG":2.03,"sodiumMg":18,"calciumMg":47,"ironMg":0.59,"potassiumMg":246},"measure":"cru) (Escumadeira média cheia picado (45g): 2"},{"food":"Cebola","grams":30,"macros":{"energyKcal":40,"proteinG":1.1,"carbohydrateG":9.34,"fatG":0.1,"fiberG":1.93,"sodiumMg":4,"calciumMg":23,"ironMg":0.21,"potassiumMg":146},"measure":"Grama: 30"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Queijo de coalho","grams":30,"macros":{"energyKcal":373,"proteinG":24.48,"carbohydrateG":0.68,"fatG":30.28,"fiberG":0,"sodiumMg":536,"calciumMg":746,"ironMg":0.72,"potassiumMg":81},"measure":"Grama: 30"},{"food":"Morango","grams":60,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 5"},{"food":"Castanha do Pará sem sal","grams":12,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 3"}],"time":"17:00"},{"name":"Jantar","items":[{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 150"},{"food":"Alface, americana, crua","grams":48,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Colher de sopa cheia: 6"},{"food":"Beterraba","grams":80,"macros":{"energyKcal":43,"proteinG":1.62,"carbohydrateG":9.57,"fatG":0.17,"fiberG":2.8,"sodiumMg":78,"calciumMg":16,"ironMg":0.8,"potassiumMg":325},"measure":"crua) (Unidade pequena (80g): 1"}],"time":"20:30"}]},"dimensions":{"approaches":["ketogenic"],"objectives":[],"restrictions":["very_low_carb"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Cetogênica - 2000 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","ketogenic"],"snapshot":{"dietboxId":19202274,"originalName":"Dieta Cetogênica - 2000 Kcal","kcalTotal":2052,"summary":{"energyKcal":2052,"proteinG":179.3,"carbohydrateG":50.6,"fatG":128.7,"fiberG":19.2,"sodiumMg":1344.3,"calciumMg":773.5,"ironMg":12.3,"potassiumMg":2679.3},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Abacate","grams":100,"macros":{"energyKcal":120,"proteinG":2.23,"carbohydrateG":7.82,"fatG":10.06,"fiberG":5.6,"sodiumMg":2,"calciumMg":10,"ironMg":0.17,"potassiumMg":351},"measure":"Grama: 100"},{"food":"Queijo minas frescal","grams":60,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 2"},{"food":"Castanha do Pará sem sal","grams":12,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 3"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sopa (7,6ml): 1"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Carne, boi, de primeira","grams":200,"macros":{"energyKcal":208,"proteinG":33.4,"carbohydrateG":0,"fatG":8.32,"fiberG":0,"sodiumMg":372,"calciumMg":4.47,"ironMg":2.62,"potassiumMg":332},"measure":"alcatra, contrafilé, coxão mole, filé mignon, lagarto, patinho)cozida/grelhada/assada, s/ óleo, c/ sal (Grama: 200"},{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Pepino, cru","grams":100,"macros":{"energyKcal":9.53,"proteinG":0.87,"carbohydrateG":2.04,"fatG":0,"fiberG":1.12,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.15,"potassiumMg":153.69},"measure":"Grama: 100"},{"food":"Repolho branco","grams":90,"macros":{"energyKcal":25,"proteinG":1.45,"carbohydrateG":5.44,"fatG":0.27,"fiberG":2.03,"sodiumMg":18,"calciumMg":47,"ironMg":0.59,"potassiumMg":246},"measure":"cru) (Escumadeira média cheia picado (45g): 2"},{"food":"Cebola","grams":30,"macros":{"energyKcal":40,"proteinG":1.1,"carbohydrateG":9.34,"fatG":0.1,"fiberG":1.93,"sodiumMg":4,"calciumMg":23,"ironMg":0.21,"potassiumMg":146},"measure":"Grama: 30"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Queijo de coalho","grams":30,"macros":{"energyKcal":373,"proteinG":24.48,"carbohydrateG":0.68,"fatG":30.28,"fiberG":0,"sodiumMg":536,"calciumMg":746,"ironMg":0.72,"potassiumMg":81},"measure":"Grama: 30"},{"food":"Morango","grams":120,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 10"}],"time":"17:00"},{"name":"Jantar","items":[{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":200,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 200"},{"food":"Alface, americana, crua","grams":48,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Colher de sopa cheia: 6"},{"food":"Brócolis, cozido","grams":100,"macros":{"energyKcal":24.64,"proteinG":2.13,"carbohydrateG":4.37,"fatG":0.46,"fiberG":3.42,"sodiumMg":2.12,"calciumMg":50.75,"ironMg":0.54,"potassiumMg":118.54},"measure":"Grama: 100"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Iogurte natural - Nestlé®","grams":170,"macros":{"energyKcal":77,"proteinG":4,"carbohydrateG":5.8,"fatG":4.2,"fiberG":0,"sodiumMg":52.5,"calciumMg":150.5,"ironMg":0,"potassiumMg":0},"measure":"Pote (170g): 1"},{"food":"Linhaça, semente","grams":10,"macros":{"energyKcal":453,"proteinG":14.1,"carbohydrateG":43.3,"fatG":32.3,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211,"ironMg":4.7,"potassiumMg":869},"measure":"Colher de sobremesa rasa: 1"}],"time":"22:00"}]},"dimensions":{"approaches":["ketogenic"],"objectives":[],"restrictions":["very_low_carb"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta com jejum intermitente de 1500 Kcal","objective":"Cardápio clínico para controle glicêmico — adaptar à avaliação nutricional do paciente.","tags":["1500 kcal","intermittent_fasting"],"snapshot":{"dietboxId":19507505,"originalName":"Dieta com jejum intermitente de 1500 Kcal","kcalTotal":1505,"summary":{"energyKcal":1504.9,"proteinG":126.9,"carbohydrateG":161.6,"fatG":40,"fiberG":33.7,"sodiumMg":878.9,"calciumMg":753.6,"ironMg":11.9,"potassiumMg":4053},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha Cozido(a)","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia média (170g): 1"},{"food":"Aveia em flocos","grams":20,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 20"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 100"},{"food":"Feijão, preto, cozido","grams":80,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Grama: 80"},{"food":"Frango em pedaços","grams":100,"macros":{"energyKcal":239,"proteinG":27.3,"carbohydrateG":0,"fatG":13.6,"fiberG":0,"sodiumMg":82,"calciumMg":15,"ironMg":1.26,"potassiumMg":223},"measure":"Grama: 100"}],"time":"13:00"},{"name":"Jantar","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Porco, fresco, carré, lombo, carne magra e gordura, grelhado","grams":100,"macros":{"energyKcal":201,"proteinG":29.86,"carbohydrateG":0,"fatG":8.11,"fiberG":0,"sodiumMg":64,"calciumMg":5,"ironMg":1.39,"potassiumMg":444},"measure":"Grama: 100"},{"food":"Lentilha, cozida","grams":80,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Grama: 80"},{"food":"Batata, inglesa, cozida","grams":90,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Grama: 90"}],"time":"18:00"},{"name":"Lanche da tarde","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Pote: 1"},{"food":"Whey Protein Concentrado DUX - Baunilha","grams":28,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 1"},{"food":"Morango","grams":100,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Grama: 100"},{"food":"Granola","grams":15,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"Grama: 15"}],"time":"15:30"},{"name":"Jejum Intermitente","items":[{"food":"Água","grams":2000,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (200ml): 10"}],"time":"08:00","notes":"MÉTODO 16:8: No método 16:8, o período em que se fica em jejum, ou seja sem comer, é de 16 horas, com uma “janela alimentar” de 8 horas para fazer as refeições.\n\nHidratação:\n- Água: O consumo de água ao longo do dia é fundamental e segue normal, mesmo no período de jejum.\n- Chás e Café: Chás sem açúcar e café sem adição de açúcar ou creme são permitidos durante o período de jejum.\n\nConsiderações Importantes:\n- Escute seu corpo. Se sentir fome excessiva ou desconforto, ajuste a programação do jejum conforme necessário. Converse sempre com seu nutricionista.\n- Priorize a prática de exercícios físicos em intensidades mais baixas durante o jejum, caso tenha indicação de executa-lo. Informe os profissionais que estão te acompanhado sobre a estratégia de jejum. \n\n"}]},"dimensions":{"approaches":["intermittent_fasting"],"objectives":["glycemic_control"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta com jejum intermitente de 2000 Kcal","objective":"Cardápio clínico para controle glicêmico — adaptar à avaliação nutricional do paciente.","tags":["2000 kcal","intermittent_fasting"],"snapshot":{"dietboxId":19507501,"originalName":"Dieta com jejum intermitente de 2000 Kcal","kcalTotal":2007,"summary":{"energyKcal":2007.4,"proteinG":144.8,"carbohydrateG":241.2,"fatG":54.8,"fiberG":37.5,"sodiumMg":1264.5,"calciumMg":396.3,"ironMg":17.5,"potassiumMg":3845.1},"meals":[{"name":"Café da manhã","items":[{"food":"Pão francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"Unidade (50g): 1"},{"food":"Queijo minas frescal","grams":30,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 1"},{"food":"Whey Protein Concentrado DUX - Baunilha","grams":28,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 1"},{"food":"Uva itália","grams":100,"macros":{"energyKcal":71,"proteinG":0.66,"carbohydrateG":17.8,"fatG":0.58,"fiberG":0.6,"sodiumMg":2,"calciumMg":11,"ironMg":0.26,"potassiumMg":185},"measure":"Grama: 100"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Macarrão, trigo integral, cozido","grams":200,"macros":{"energyKcal":124,"proteinG":5.33,"carbohydrateG":26.54,"fatG":0.54,"fiberG":2.8,"sodiumMg":3,"calciumMg":15,"ironMg":1.06,"potassiumMg":44},"measure":"Grama: 200"},{"food":"Feijão, preto, cozido","grams":100,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Grama: 100"},{"food":"Carne moída Cozido(a)","grams":150,"macros":{"energyKcal":214,"proteinG":26.62,"carbohydrateG":0,"fatG":11.1,"fiberG":0,"sodiumMg":61,"calciumMg":13,"ironMg":2.89,"potassiumMg":300},"measure":"Grama: 150"},{"food":"Abacaxi","grams":100,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113},"measure":"Fatia pequena (50g): 2"}],"time":"13:00"},{"name":"Jantar","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Arroz branco","grams":200,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 200"},{"food":"Salmão, sem pele, fresco, grelhado","grams":150,"macros":{"energyKcal":242.71,"proteinG":26.14,"carbohydrateG":0,"fatG":14.53,"fiberG":0,"sodiumMg":95.81,"calciumMg":15.09,"ironMg":0.37,"potassiumMg":517.9},"measure":"Grama: 150"},{"food":"Lentilha, cozida","grams":100,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Grama: 100"},{"food":"Melancia","grams":150,"macros":{"energyKcal":32,"proteinG":0.62,"carbohydrateG":7.19,"fatG":0.43,"fiberG":0.23,"sodiumMg":2,"calciumMg":8,"ironMg":0.17,"potassiumMg":116},"measure":"Grama: 150"}],"time":"18:00"},{"name":"Jejum Intermitente","items":[{"food":"Água","grams":2000,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (200ml): 10"}],"time":"08:00","notes":"MÉTODO 16:8: No método 16:8, o período em que se fica em jejum, ou seja sem comer, é de 16 horas, com uma “janela alimentar” de 8 horas para fazer as refeições.\n\nHidratação:\n- Água: O consumo de água ao longo do dia é fundamental e segue normal, mesmo no período de jejum.\n- Chás e Café: Chás sem açúcar e café sem adição de açúcar ou creme são permitidos durante o período de jejum.\n\nConsiderações Importantes:\n- Escute seu corpo. Se sentir fome excessiva ou desconforto, ajuste a programação do jejum conforme necessário. Converse sempre com seu nutricionista.\n- Priorize a prática de exercícios físicos em intensidades mais baixas durante o jejum, caso tenha indicação de executa-lo. Informe os profissionais que estão te acompanhado sobre a estratégia de jejum. \n\n"}]},"dimensions":{"approaches":["intermittent_fasting"],"objectives":["glycemic_control"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta com Restrição de Fibras e Resíduos 1.300 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1300 kcal"],"snapshot":{"dietboxId":1289713,"originalName":"Dieta com Restrição de Fibras e Resíduos 1.300 Kcal","kcalTotal":1307,"summary":{"energyKcal":1306.8,"proteinG":78.1,"carbohydrateG":152,"fatG":42.6,"fiberG":12.2,"sodiumMg":1112.2,"calciumMg":96,"ironMg":9.8,"potassiumMg":1875.1},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de soja - PADRÃO","grams":200,"macros":{"energyKcal":33,"proteinG":2.76,"carbohydrateG":1.82,"fatG":1.92,"fiberG":1.31,"sodiumMg":12,"calciumMg":4,"ironMg":0.58,"potassiumMg":141},"measure":"1 Copo de requeijão (200ml)"},{"food":"Pão caseiro","grams":50,"macros":{"energyKcal":392.13,"proteinG":9.65,"carbohydrateG":69.73,"fatG":7.62,"fiberG":3.15,"sodiumMg":438.95,"calciumMg":15.99,"ironMg":4.3,"potassiumMg":115.07},"measure":"1 Fatia (50g)"},{"food":"Geleia diet","grams":24,"macros":{"energyKcal":52.64,"proteinG":0.47,"carbohydrateG":12.72,"fatG":0.17,"fiberG":1.4,"sodiumMg":1.2,"calciumMg":11.05,"ironMg":0.23,"potassiumMg":85.44},"measure":"2 Ponta De Faca"},{"food":"Banana","grams":42,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade pequena (42g)"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Suco de maçã","grams":200,"macros":{"energyKcal":43,"proteinG":0.2,"carbohydrateG":9.97,"fatG":0.01,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"1 Copo médio (200ml)"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Arroz branco","grams":50,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (2 Colher de sopa cheia (25g)"},{"food":"Chuchu","grams":40,"macros":{"energyKcal":24,"proteinG":0.62,"carbohydrateG":5.1,"fatG":0.48,"fiberG":0.58,"sodiumMg":1,"calciumMg":13,"ironMg":0.22,"potassiumMg":173},"measure":"cozido) (2 Colher de sopa cheia (picado) (20g)"},{"food":"Polenta","grams":35,"macros":{"energyKcal":62.88,"proteinG":1.02,"carbohydrateG":11.32,"fatG":1.67,"fiberG":1.97,"sodiumMg":222.04,"calciumMg":2.84,"ironMg":0.36,"potassiumMg":46.43},"measure":"1 Colher de sopa cheia (35g)"},{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé pequeno (100g)"},{"food":"Suco de limão","grams":10,"macros":{"energyKcal":350,"proteinG":0,"carbohydrateG":87.5,"fatG":0,"fiberG":0,"sodiumMg":108,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"1 copo"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Leite de soja - PADRÃO","grams":200,"macros":{"energyKcal":33,"proteinG":2.76,"carbohydrateG":1.82,"fatG":1.92,"fiberG":1.31,"sodiumMg":12,"calciumMg":4,"ironMg":0.58,"potassiumMg":141},"measure":"1 Copo de requeijão (200ml)"},{"food":"Torrada levemente salgada","grams":20,"macros":{"energyKcal":388,"proteinG":11.1,"carbohydrateG":74.2,"fatG":5.2,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"2 Unidade"},{"food":"Geleia diet","grams":48,"macros":{"energyKcal":52.64,"proteinG":0.47,"carbohydrateG":12.72,"fatG":0.17,"fiberG":1.4,"sodiumMg":1.2,"calciumMg":11.05,"ironMg":0.23,"potassiumMg":85.44},"measure":"4 Ponta De Faca"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Purê de batata","grams":90,"macros":{"energyKcal":115.16,"proteinG":1.81,"carbohydrateG":17.76,"fatG":4.36,"fiberG":1.78,"sodiumMg":138.26,"calciumMg":18.21,"ironMg":0.27,"potassiumMg":298.44},"measure":"2 Colher De Sopa"},{"food":"Carne bovina Grelhado","grams":100,"macros":{"energyKcal":242,"proteinG":24.22,"carbohydrateG":0,"fatG":15.42,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"1 Bife"},{"food":"Cenoura Cozido(a)","grams":25,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"1 Colher De Sopa"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Biscoito cream cracker","grams":15,"macros":{"energyKcal":473,"proteinG":9.3,"carbohydrateG":67.3,"fatG":18.5,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"3 Unidade"},{"food":"Chá, erva-doce, infusão 5%","grams":50,"macros":{"energyKcal":1.4,"proteinG":0,"carbohydrateG":0.39,"fatG":0,"fiberG":0,"sodiumMg":0.63,"calciumMg":1.93,"ironMg":0,"potassiumMg":9.93},"measure":"1 xicara"}],"time":"22:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["low_fiber_low_residue"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1300},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta DASH 1.500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","dash"],"snapshot":{"dietboxId":19577991,"originalName":"Dieta DASH 1.500 Kcal","kcalTotal":1529,"summary":{"energyKcal":1529.2,"proteinG":131.5,"carbohydrateG":175.4,"fatG":34.8,"fiberG":26.8,"sodiumMg":806.2,"calciumMg":365.3,"ironMg":8.4,"potassiumMg":2703.1},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo, de galinha, inteiro, cozido/10minutos","grams":50,"macros":{"energyKcal":145.7,"proteinG":13.29,"carbohydrateG":0.61,"fatG":9.48,"fiberG":0,"sodiumMg":145.9,"calciumMg":49.22,"ironMg":1.52,"potassiumMg":138.9},"measure":"Unidade: 1"},{"food":"Melancia","grams":200,"macros":{"energyKcal":32,"proteinG":0.62,"carbohydrateG":7.19,"fatG":0.43,"fiberG":0.23,"sodiumMg":2,"calciumMg":8,"ironMg":0.17,"potassiumMg":116},"measure":"Fatia média (200g): 1"},{"food":"Pão integral - Wickbold®","grams":25,"macros":{"energyKcal":236,"proteinG":8.6,"carbohydrateG":46,"fatG":2,"fiberG":6.4,"sodiumMg":468,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (25g): 1"},{"food":"Queijo, minas, frescal, light","grams":30,"macros":{"energyKcal":161,"proteinG":18.7,"carbohydrateG":0.41,"fatG":9.4,"fiberG":0,"sodiumMg":22.6,"calciumMg":419,"ironMg":0.67,"potassiumMg":75.9},"measure":"Pedaço/ Unidade/ Fatia (M): 1"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Feijão carioca","grams":100,"macros":{"energyKcal":103,"proteinG":6,"carbohydrateG":18,"fatG":1,"fiberG":5,"sodiumMg":129,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 100"},{"food":"Arroz integral","grams":150,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Grama: 150"},{"food":"Filé de frango Assado(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Bife: 1"},{"food":"Abóbora moranga","grams":100,"macros":{"energyKcal":19.99,"proteinG":0.73,"carbohydrateG":4.88,"fatG":0.08,"fiberG":0.92,"sodiumMg":172.94,"calciumMg":15.97,"ironMg":0.61,"potassiumMg":231.07},"measure":"cozida) (Escumadeira média cheia (picada) (100g): 1"},{"food":"Brócolis","grams":80,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 80"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Morango","grams":120,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 10"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 3"},{"food":"Proteina de ervilha","grams":30,"macros":{"energyKcal":318.67,"proteinG":73.33,"carbohydrateG":0,"fatG":3.33,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Growht) (Grama: 30"},{"food":"Leite de amêndoas","grams":200,"macros":{"energyKcal":28.5,"proteinG":0.95,"carbohydrateG":0.85,"fatG":2.35,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"1 copo: 1"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Peixe de água doce","grams":150,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)   (Grama: 150"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Tomate cereja","grams":60,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 6"},{"food":"Pepino, c/ casca, cru","grams":54,"macros":{"energyKcal":10,"proteinG":0.7,"carbohydrateG":2.23,"fatG":0.09,"fiberG":1.04,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.23,"potassiumMg":153},"measure":"Colher de sopa cheia: 3"},{"food":"Cenoura","grams":48,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Colher de sopa ralada (12g): 4"},{"food":"Batata doce cozida sem sal","grams":140,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Unidade média (140g): 1"}],"time":"20:00"}]},"dimensions":{"approaches":["dash"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta DASH 2.000 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","dash"],"snapshot":{"dietboxId":19577997,"originalName":"Dieta DASH 2.000 Kcal","kcalTotal":1983,"summary":{"energyKcal":1983.2,"proteinG":161.2,"carbohydrateG":210.6,"fatG":59.3,"fiberG":37,"sodiumMg":1173.1,"calciumMg":1159.7,"ironMg":22.7,"potassiumMg":4909.2},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo, de galinha, inteiro, cozido/10minutos","grams":100,"macros":{"energyKcal":145.7,"proteinG":13.29,"carbohydrateG":0.61,"fatG":9.48,"fiberG":0,"sodiumMg":145.9,"calciumMg":49.22,"ironMg":1.52,"potassiumMg":138.9},"measure":"Unidade: 2"},{"food":"Morango","grams":120,"macros":{"energyKcal":32,"proteinG":0.67,"carbohydrateG":7.68,"fatG":0.3,"fiberG":2,"sodiumMg":1,"calciumMg":16,"ironMg":0.41,"potassiumMg":153},"measure":"Unidade: 10"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 3"},{"food":"Iogurte desnatado","grams":170,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Grama: 170"},{"food":"Café, fervido de pó de café, preparo com água encanada","grams":237,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0,"fatG":0.02,"fiberG":0,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49},"measure":"xícara: 1"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Grão de bico","grams":100,"macros":{"energyKcal":164,"proteinG":8.87,"carbohydrateG":27.4,"fatG":2.6,"fiberG":4.9,"sodiumMg":7,"calciumMg":49,"ironMg":2.9,"potassiumMg":291},"measure":"cozido) (Grama: 100"},{"food":"Batata, inglesa, cozida","grams":200,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Grama: 200"},{"food":"Patinho Cozido(a)","grams":100,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Grama: 100"},{"food":"Brócolis","grams":80,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 80"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Espinafre","grams":50,"macros":{"energyKcal":23,"proteinG":2.98,"carbohydrateG":3.76,"fatG":0.26,"fiberG":2.3,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"cozido) (Pegador (25g): 2"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"},{"food":"Cenoura","grams":24,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Colher de sopa ralada (12g): 2"},{"food":"Laranja","grams":90,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.75,"fatG":0.12,"fiberG":2.35,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"pera, seleta, lima, da terra, etc.)  (Banda: 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Mamão","grams":155,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Banda: 1"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 3"},{"food":"Proteína isolada de soja","grams":30,"macros":{"energyKcal":338,"proteinG":80.69,"carbohydrateG":7.36,"fatG":3.39,"fiberG":5.6,"sodiumMg":1005,"calciumMg":178,"ironMg":14.5,"potassiumMg":81},"measure":"Grama: 30"},{"food":"Leite, de vaca, desnatado, UHT","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Copo Cheio (200ml): 1"},{"food":"Castanha do Brasil, crua","grams":30,"macros":{"energyKcal":674,"proteinG":14.5,"carbohydrateG":15.1,"fatG":63.5,"fiberG":7.93,"sodiumMg":0.4,"calciumMg":162,"ironMg":2.98,"potassiumMg":625},"measure":"Porção média: 1"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Peixe de água doce","grams":150,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)   (Grama: 150"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Tomate cereja","grams":60,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 6"},{"food":"Pepino, c/ casca, cru","grams":54,"macros":{"energyKcal":10,"proteinG":0.7,"carbohydrateG":2.23,"fatG":0.09,"fiberG":1.04,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.23,"potassiumMg":153},"measure":"Colher de sopa cheia: 3"},{"food":"Cenoura","grams":48,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Colher de sopa ralada (12g): 4"},{"food":"Arroz integral","grams":150,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 150"},{"food":"Abobrinha","grams":90,"macros":{"energyKcal":20,"proteinG":0.91,"carbohydrateG":4.32,"fatG":0.31,"fiberG":1.4,"sodiumMg":1,"calciumMg":27,"ironMg":0.36,"potassiumMg":192},"measure":"cozida) (Escumadeira média cheia (picada) (90g): 1"}],"time":"20:00"}]},"dimensions":{"approaches":["dash"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta de 1.100 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1100 kcal"],"snapshot":{"dietboxId":16945004,"originalName":"Dieta de 1.100 Kcal","kcalTotal":1142,"summary":{"energyKcal":1142.1,"proteinG":70.5,"carbohydrateG":135.7,"fatG":38.1,"fiberG":31.4,"sodiumMg":2769.4,"calciumMg":1120.3,"ironMg":9.9,"potassiumMg":2387.9},"meals":[{"name":"Café da manhã","items":[{"food":"2 fatias de pão de centeio","grams":60,"macros":{"energyKcal":244,"proteinG":9.4,"carbohydrateG":48,"fatG":1.4,"fiberG":6,"sodiumMg":456,"calciumMg":0,"ironMg":3,"potassiumMg":0}},{"food":"1 fatia de queijo muçarela","grams":30,"macros":{"energyKcal":251,"proteinG":24.3,"carbohydrateG":2.77,"fatG":15.9,"fiberG":0,"sodiumMg":619,"calciumMg":782,"ironMg":0.22,"potassiumMg":84}},{"food":"1/2 fatia pequena de mamão","grams":50,"macros":{"energyKcal":45.34,"proteinG":0.82,"carbohydrateG":11.55,"fatG":0.12,"fiberG":1.81,"sodiumMg":3.26,"calciumMg":24.87,"ironMg":0.23,"potassiumMg":221.8}}],"time":"08:00"},{"name":"Lanche da manhã","items":[{"food":"200ml de Leite integral","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":63.76,"calciumMg":122.58,"ironMg":0,"potassiumMg":133.19}},{"food":"10 unidades de morango","grams":50,"macros":{"energyKcal":30.15,"proteinG":0.89,"carbohydrateG":6.82,"fatG":0.31,"fiberG":1.72,"sodiumMg":0,"calciumMg":10.9,"ironMg":0.32,"potassiumMg":184.4}}],"time":"10:00","notes":"Bater o leite com o morango"},{"name":"Almoço","items":[{"food":"3 colheres de sopa de arroz integral cozido","grams":60,"macros":{"energyKcal":123.53,"proteinG":2.59,"carbohydrateG":25.81,"fatG":1,"fiberG":2.75,"sodiumMg":1.24,"calciumMg":5.2,"ironMg":0.26,"potassiumMg":75.15}},{"food":"1 colher de servir de cenoura ralada crua","grams":24,"macros":{"energyKcal":34.14,"proteinG":1.32,"carbohydrateG":7.66,"fatG":0.17,"fiberG":3.18,"sodiumMg":3.33,"calciumMg":22.54,"ironMg":0.18,"potassiumMg":314.81}},{"food":"11 folhas de alface","grams":20,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110}},{"food":"5 colheres de sopa de repolho roxo","grams":25,"macros":{"energyKcal":30.91,"proteinG":1.91,"carbohydrateG":7.2,"fatG":0.06,"fiberG":1.97,"sodiumMg":2.34,"calciumMg":43.67,"ironMg":0.52,"potassiumMg":328.07}},{"food":"2 colheres de sopa de berinjela cozidas","grams":60,"macros":{"energyKcal":18.85,"proteinG":0.68,"carbohydrateG":4.47,"fatG":0.15,"fiberG":2.52,"sodiumMg":1.33,"calciumMg":10.77,"ironMg":0.22,"potassiumMg":105.48}},{"food":"7 unidades de tomate cereja","grams":70,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222}},{"food":"1 feijão cozido","grams":140,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62}},{"food":"1 unidade de bife grelhado","grams":100,"macros":{"energyKcal":195,"proteinG":30.4,"carbohydrateG":0,"fatG":7.21,"fiberG":0,"sodiumMg":66,"calciumMg":11,"ironMg":3.37,"potassiumMg":403}}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"1 porção pequena de pão de queijo","grams":19,"macros":{"energyKcal":330.09,"proteinG":11.85,"carbohydrateG":33,"fatG":16.62,"fiberG":1.17,"sodiumMg":585.49,"calciumMg":333.75,"ironMg":0.53,"potassiumMg":95.93}},{"food":"1 fatia média de mamão formosa","grams":170,"macros":{"energyKcal":45.34,"proteinG":0.82,"carbohydrateG":11.55,"fatG":0.12,"fiberG":1.81,"sodiumMg":3.26,"calciumMg":24.87,"ironMg":0.23,"potassiumMg":221.8}}],"time":"15:00"},{"name":"Jantar","items":[{"food":"3 fatias de polenta cozida","grams":60,"macros":{"energyKcal":102.74,"proteinG":2.29,"carbohydrateG":23.31,"fatG":0.3,"fiberG":2.4,"sodiumMg":441.89,"calciumMg":1.09,"ironMg":0,"potassiumMg":99.64}},{"food":"3 colheres de sopa de queijo tipo parmesão ralado","grams":33,"macros":{"energyKcal":466.66,"proteinG":26.67,"carbohydrateG":0,"fatG":40,"fiberG":0,"sodiumMg":1800,"calciumMg":1200,"ironMg":0,"potassiumMg":0}},{"food":"2 porções de caponata","grams":198,"macros":{"energyKcal":54.53,"proteinG":1.21,"carbohydrateG":6.39,"fatG":3.32,"fiberG":2.03,"sodiumMg":568.78,"calciumMg":20.35,"ironMg":0.64,"potassiumMg":118.86}}],"time":"20:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1100},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta de Baixa Carga Glicêmica","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["glycemic_load"],"snapshot":{"dietboxId":1231451,"originalName":"Dieta de Baixa Carga Glicêmica","kcalTotal":1027,"summary":{"energyKcal":1027.2,"proteinG":75.6,"carbohydrateG":151.4,"fatG":15.4,"fiberG":18.2,"sodiumMg":2555.8,"calciumMg":1090.8,"ironMg":4.5,"potassiumMg":2927.4},"meals":[{"name":"Café da manhã","items":[{"food":"Iogurte desnatado","grams":150,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Copo Americano: 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo prato","grams":15,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"Fatia: 1"},{"food":"Requeijão light","grams":15,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sobremesa: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada de repolho, preparo caseiro","grams":24,"macros":{"energyKcal":69,"proteinG":1.29,"carbohydrateG":12.41,"fatG":2.61,"fiberG":1.5,"sodiumMg":23,"calciumMg":45,"ironMg":0.59,"potassiumMg":181},"measure":"colher de sopa: 3"},{"food":"Outros legumes cozidos","grams":110,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Arroz/Servir: 2"},{"food":"Peixe não especificado","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Assado(a) (File: 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Iogurte desnatado","grams":150,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Copo Americano: 1"},{"food":"Salada de frutas","grams":150,"macros":{"energyKcal":51.24,"proteinG":0.62,"carbohydrateG":13.31,"fatG":0.14,"fiberG":1.68,"sodiumMg":0.82,"calciumMg":15.88,"ironMg":0.16,"potassiumMg":154.02},"measure":"Copo Americano: 1"}],"time":"15:00"},{"name":"Jantar","items":[{"food":"Sopa","grams":520,"macros":{"energyKcal":28.78,"proteinG":1.63,"carbohydrateG":3.81,"fatG":0.78,"fiberG":0.64,"sodiumMg":333.11,"calciumMg":6.74,"ironMg":0.22,"potassiumMg":57.45},"measure":"legumes, carne, etc.)  (Prato Fundo: 1"},{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Copo Americano: 1"}],"time":"22:30"}]},"dimensions":{"approaches":["glycemic_load"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1027},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta do Mediterrâneo 1.500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","mediterranean"],"snapshot":{"dietboxId":19578015,"originalName":"Dieta do Mediterrâneo 1.500 Kcal","kcalTotal":1533,"summary":{"energyKcal":1533.1,"proteinG":88.2,"carbohydrateG":166.8,"fatG":53.7,"fiberG":27.1,"sodiumMg":832.1,"calciumMg":268.8,"ironMg":15.2,"potassiumMg":2378.8},"meals":[{"name":"Café da manhã","items":[{"food":"Pão de forma 100% integral Plus Vita - Pullman®","grams":50,"macros":{"energyKcal":212,"proteinG":9.4,"carbohydrateG":38,"fatG":2.8,"fiberG":7,"sodiumMg":434,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (25g): 2"},{"food":"Queijo minas frescal","grams":30,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 1"},{"food":"Uva itália","grams":120,"macros":{"energyKcal":71,"proteinG":0.66,"carbohydrateG":17.8,"fatG":0.58,"fiberG":0.6,"sodiumMg":2,"calciumMg":11,"ironMg":0.26,"potassiumMg":185},"measure":"Grama: 120"},{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Chá verde","grams":120,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Xícara: 1"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"},{"food":"Salmão, filé, com pele, fresco,  grelhado","grams":120,"macros":{"energyKcal":228.73,"proteinG":23.92,"carbohydrateG":0,"fatG":14.04,"fiberG":0,"sodiumMg":85.14,"calciumMg":28.76,"ironMg":0.54,"potassiumMg":383.94},"measure":"Grama: 120"},{"food":"Arroz integral","grams":120,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Grama: 120"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Grama: 20"},{"food":"Tomate, cru","grams":69,"macros":{"energyKcal":18,"proteinG":1.04,"carbohydrateG":3.82,"fatG":0.17,"fiberG":1.6,"sodiumMg":3.13,"calciumMg":6.94,"ironMg":0.3,"potassiumMg":191},"measure":"Colher de sopa cheia: 3"},{"food":"Cebola Cru(a)","grams":12,"macros":{"energyKcal":40,"proteinG":1.1,"carbohydrateG":9.34,"fatG":0.1,"fiberG":1.93,"sodiumMg":4,"calciumMg":23,"ironMg":0.21,"potassiumMg":146},"measure":"Fatia: 2"},{"food":"Brócolis","grams":80,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 80"},{"food":"Vinho tinto","grams":75,"macros":{"energyKcal":72,"proteinG":0.2,"carbohydrateG":1.7,"fatG":0,"fiberG":0,"sodiumMg":5,"calciumMg":8,"ironMg":0.43,"potassiumMg":112},"measure":"Taça (150ml): 0,5"}],"time":"12:30","notes":"Vinho tinto: É sugestivo ingestão moderada e respeitando as crenças sociais"},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha Cozido(a)","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Torrada integral - Bauducco®","grams":20,"macros":{"energyKcal":366.66,"proteinG":13.33,"carbohydrateG":73.33,"fatG":3.33,"fiberG":6.66,"sodiumMg":416.67,"calciumMg":0,"ironMg":30.33,"potassiumMg":0},"measure":"Unidade (10g): 2"},{"food":"Suco Verde COM/TEM","grams":300,"macros":{"energyKcal":22.33,"proteinG":0.2,"carbohydrateG":5.33,"fatG":0,"fiberG":0.33,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Unidade: 1"}],"time":"17:00"},{"name":"Jantar","items":[{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"Folha De Hortaliça: 4"},{"food":"Rúcula, crua","grams":10,"macros":{"energyKcal":13.13,"proteinG":1.77,"carbohydrateG":2.22,"fatG":0.11,"fiberG":1.74,"sodiumMg":9.42,"calciumMg":116.56,"ironMg":0.94,"potassiumMg":233.4},"measure":"Grama: 10"},{"food":"Semente de abóbora sem sal","grams":20,"macros":{"energyKcal":446,"proteinG":18.6,"carbohydrateG":53.8,"fatG":19.4,"fiberG":35.9,"sodiumMg":18,"calciumMg":55,"ironMg":3.32,"potassiumMg":919},"measure":"Grama: 20"},{"food":"Tomate cereja","grams":50,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 5"},{"food":"Camarão Ao alho e óleo","grams":104,"macros":{"energyKcal":121.66,"proteinG":20.91,"carbohydrateG":0,"fatG":3.64,"fiberG":0,"sodiumMg":224,"calciumMg":39,"ironMg":3.09,"potassiumMg":182},"measure":"Porção: 1"},{"food":"Mandioquinha salsa","grams":150,"macros":{"energyKcal":76,"proteinG":1.37,"carbohydrateG":17.72,"fatG":0.14,"fiberG":2.5,"sodiumMg":27,"calciumMg":27,"ironMg":0.72,"potassiumMg":230},"measure":"batata-baroa) Cozido(a) (Grama: 150"},{"food":"Manga, crua","grams":80,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":1.8,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156},"measure":"Grama: 80"}],"time":"20:00"}]},"dimensions":{"approaches":["mediterranean"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta do Mediterrâneo 2.000 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","mediterranean"],"snapshot":{"dietboxId":19578010,"originalName":"Dieta do Mediterrâneo 2.000 Kcal","kcalTotal":2048,"summary":{"energyKcal":2047.5,"proteinG":150.6,"carbohydrateG":241.3,"fatG":52.3,"fiberG":35.2,"sodiumMg":1410.7,"calciumMg":836.4,"ironMg":15.9,"potassiumMg":3918.8},"meals":[{"name":"Café da manhã","items":[{"food":"Uva itália","grams":120,"macros":{"energyKcal":71,"proteinG":0.66,"carbohydrateG":17.8,"fatG":0.58,"fiberG":0.6,"sodiumMg":2,"calciumMg":11,"ironMg":0.26,"potassiumMg":185},"measure":"Grama: 120"},{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Chá verde","grams":120,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Xícara: 1"},{"food":"Iogurte caseiro","grams":170,"macros":{"energyKcal":4.68,"proteinG":0.37,"carbohydrateG":0.17,"fatG":0.28,"fiberG":0,"sodiumMg":62.66,"calciumMg":124.45,"ironMg":0,"potassiumMg":127.56},"measure":"Grama: 170"},{"food":"Aveia em flocos","grams":40,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 40"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"},{"food":"Peixe de água doce","grams":200,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)  Cozido(a) (Posta: 1"},{"food":"Arroz integral","grams":120,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Grama: 120"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Grama: 20"},{"food":"Tomate, cru","grams":69,"macros":{"energyKcal":18,"proteinG":1.04,"carbohydrateG":3.82,"fatG":0.17,"fiberG":1.6,"sodiumMg":3.13,"calciumMg":6.94,"ironMg":0.3,"potassiumMg":191},"measure":"Colher de sopa cheia: 3"},{"food":"Cebola Cru(a)","grams":12,"macros":{"energyKcal":40,"proteinG":1.1,"carbohydrateG":9.34,"fatG":0.1,"fiberG":1.93,"sodiumMg":4,"calciumMg":23,"ironMg":0.21,"potassiumMg":146},"measure":"Fatia: 2"},{"food":"Brócolis","grams":80,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 80"},{"food":"Vinho tinto","grams":75,"macros":{"energyKcal":72,"proteinG":0.2,"carbohydrateG":1.7,"fatG":0,"fiberG":0,"sodiumMg":5,"calciumMg":8,"ironMg":0.43,"potassiumMg":112},"measure":"Taça (150ml): 0,5"}],"time":"12:30","notes":"Vinho tinto: É sugestivo ingestão moderada e respeitando as crenças sociais"},{"name":"Lanche da tarde","items":[{"food":"Atum ao natural em água e sal - Coqueiro®","grams":85,"macros":{"energyKcal":115.5,"proteinG":25.8,"carbohydrateG":1.7,"fatG":0.6,"fiberG":0,"sodiumMg":209.1,"calciumMg":17.1,"ironMg":2.5,"potassiumMg":0},"measure":"Grama: 85"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"},{"food":"Castanha de caju","grams":30,"macros":{"energyKcal":574,"proteinG":15.31,"carbohydrateG":32.69,"fatG":46.35,"fiberG":3,"sodiumMg":16,"calciumMg":45,"ironMg":6,"potassiumMg":565},"measure":"Grama: 30"}],"time":"16:30"},{"name":"Ceia","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.)  (Unidade: 1"},{"food":"Leite, de vaca, desnatado, UHT","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Copo Cheio (200ml): 1"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"},{"food":"Cacau em Pó 100% Puro Mãe Terra","grams":10,"macros":{"energyKcal":280,"proteinG":19.5,"carbohydrateG":21,"fatG":13.5,"fiberG":37,"sodiumMg":0,"calciumMg":0,"ironMg":14,"potassiumMg":0},"measure":"Grama: 10"},{"food":"Mel","grams":21,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"colher de sopa: 1"}],"time":"21:30","notes":"Vitamina"},{"name":"Jantar","items":[{"food":"Filé de frango","grams":120,"macros":{"energyKcal":163.67,"proteinG":30.59,"carbohydrateG":0.25,"fatG":3.53,"fiberG":0.02,"sodiumMg":370.13,"calciumMg":16.35,"ironMg":1.05,"potassiumMg":255.3},"measure":"cozido) (Grama: 120"},{"food":"Batata doce cozida sem sal","grams":140,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Unidade média (140g): 1"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"},{"food":"Alface, americana, crua","grams":20,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Grama: 20"},{"food":"Tomate cereja","grams":50,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 5"},{"food":"Rúcula, crua","grams":20,"macros":{"energyKcal":17,"proteinG":2.48,"carbohydrateG":2.72,"fatG":0.12,"fiberG":2.43,"sodiumMg":6.71,"calciumMg":107,"ironMg":1.02,"potassiumMg":298},"measure":"Grama: 20"},{"food":"Cenoura","grams":24,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Colher de sopa ralada (12g): 2"},{"food":"Couve-flor, cozida","grams":80,"macros":{"energyKcal":19.11,"proteinG":1.24,"carbohydrateG":3.88,"fatG":0.27,"fiberG":2.13,"sodiumMg":1.79,"calciumMg":16.14,"ironMg":0.13,"potassiumMg":80.49},"measure":"Grama: 80"}],"time":"19:30"}]},"dimensions":{"approaches":["mediterranean"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta enteral artesanal 1500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal","enteral"],"snapshot":{"dietboxId":19507528,"originalName":"Dieta enteral artesanal 1500 Kcal","kcalTotal":1526,"summary":{"energyKcal":1526.1,"proteinG":72.2,"carbohydrateG":143.1,"fatG":76.5,"fiberG":25.7,"sodiumMg":892.5,"calciumMg":1000.2,"ironMg":7.3,"potassiumMg":3386.9},"meals":[{"name":"Café da manhã","items":[{"food":"Leite, vaca, integral, fluído","grams":240,"macros":{"energyKcal":64,"proteinG":2.93,"carbohydrateG":5.92,"fatG":3.23,"fiberG":0,"sodiumMg":63.8,"calciumMg":107,"ironMg":0.07,"potassiumMg":133},"measure":"Copo americano duplo: 1"},{"food":"Leite, de vaca, integral, pó","grams":18,"macros":{"energyKcal":496.65,"proteinG":25.42,"carbohydrateG":39.18,"fatG":26.9,"fiberG":0,"sodiumMg":323.2,"calciumMg":890.27,"ironMg":0.52,"potassiumMg":1131.66},"measure":"Colher De Sopa: 2"},{"food":"Manga, Palmer, crua","grams":40,"macros":{"energyKcal":72.49,"proteinG":0.41,"carbohydrateG":19.35,"fatG":0.17,"fiberG":1.63,"sodiumMg":1.86,"calciumMg":11.64,"ironMg":0.09,"potassiumMg":156.53},"measure":"Grama: 40"},{"food":"Farinha de aveia","grams":18,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 1"},{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"}],"time":"08:00","notes":"Aqui, é uma opção de vitamina encorpada e mais calórica. Com o auxílio de um liquidificador, bata bem os ingredientes de forma que fique bem homogêneo e sem grumos. O azeite pode ser substituído por TCM e deve ser adicionado ao final do preparo."},{"name":"Colação","items":[{"food":"Suco de laranja cenoura e beterraba","grams":150,"macros":{"energyKcal":30.77,"proteinG":0.81,"carbohydrateG":7.11,"fatG":0.12,"fiberG":0.76,"sodiumMg":28.03,"calciumMg":17.14,"ironMg":0.39,"potassiumMg":222.58},"measure":"Copo Americano: 1"}],"time":"10:30","notes":"Com auxílio de um liquidificador, bata a laranja, cenoura e beterraba, até o ponto mais homogêneo e sem grumos."},{"name":"Almoço","items":[{"food":"Agrião Cozido(a)","grams":50,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"Colher De Arroz/Servir: 1"},{"food":"Inhame","grams":62,"macros":{"energyKcal":116,"proteinG":1.5,"carbohydrateG":27.6,"fatG":0.14,"fiberG":3.9,"sodiumMg":8,"calciumMg":14,"ironMg":0.52,"potassiumMg":670},"measure":"cozido) (Colher de arroz cheia (picado) (62g): 1"},{"food":"Cenoura","grams":50,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (Colher de sopa cheia (picada) (25g): 2"},{"food":"Lentilha, cozida","grams":80,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Colher de servir: 1"},{"food":"Frango em pedaços Ensopado","grams":40,"macros":{"energyKcal":261.66,"proteinG":27.3,"carbohydrateG":0,"fatG":16.16,"fiberG":0,"sodiumMg":82,"calciumMg":15,"ironMg":1.26,"potassiumMg":223},"measure":"Colher De Arroz/Servir: 1"},{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"}],"time":"12:30","notes":"Aqui, você pode fazer um preparo só, para ser usado no almoço e jantar. De opções, você pode preparar o legume junto ao tubérculo, como se fosse fazer uma sopa de legumes, sendo a proteína, o frango, por ser mais fácil de \"desmanchar\" sem ficar retido nas bordas da sonda ou obstruindo a GTT. Você também pode preparar os alimentos em uma panela de pressão, assim, eles desmancham mais, o que facilita na hora de bater no liquidificador/mixer. Bata tudo, até que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final. A lentilha pode ser peneirada, devido à sua película poder ficar retida na sonda."},{"name":"Jantar","items":[{"food":"Agrião Cozido(a)","grams":50,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"Colher De Arroz/Servir: 1"},{"food":"Inhame","grams":62,"macros":{"energyKcal":116,"proteinG":1.5,"carbohydrateG":27.6,"fatG":0.14,"fiberG":3.9,"sodiumMg":8,"calciumMg":14,"ironMg":0.52,"potassiumMg":670},"measure":"cozido) (Colher de arroz cheia (picado) (62g): 1"},{"food":"Cenoura","grams":50,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (Colher de sopa cheia (picada) (25g): 2"},{"food":"Lentilha, cozida","grams":80,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9},"measure":"Colher de servir: 1"},{"food":"Frango em pedaços Ensopado","grams":40,"macros":{"energyKcal":261.66,"proteinG":27.3,"carbohydrateG":0,"fatG":16.16,"fiberG":0,"sodiumMg":82,"calciumMg":15,"ironMg":1.26,"potassiumMg":223},"measure":"Colher De Arroz/Servir: 1"},{"food":"Azeite de oliva","grams":16,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 2"}],"time":"18:30","notes":"Aqui, você pode fazer um preparo só, para ser usado no almoço e jantar. De opções, você pode preparar o legume junto ao tubérculo, como se fosse fazer uma sopa de legumes, sendo a proteína, o frango, por ser mais fácil de \"desmanchar\" sem ficar retido nas bordas da sonda ou obstruindo a GTT. Você também pode preparar os alimentos em uma panela de pressão, assim, eles desmancham mais, o que facilita na hora de bater no liquidificador/mixer. Bata tudo, até que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final. A lentilha pode ser peneirada, devido à sua película poder ficar retida na sonda."},{"name":"Lanche da tarde","items":[{"food":"Leite, vaca, integral, fluído","grams":240,"macros":{"energyKcal":64,"proteinG":2.93,"carbohydrateG":5.92,"fatG":3.23,"fiberG":0,"sodiumMg":63.8,"calciumMg":107,"ironMg":0.07,"potassiumMg":133},"measure":"Copo americano duplo: 1"},{"food":"Suplemento, à base de proteina, em pó","grams":15,"macros":{"energyKcal":357,"proteinG":78.1,"carbohydrateG":3.22,"fatG":1.56,"fiberG":3.1,"sodiumMg":156,"calciumMg":469,"ironMg":1.13,"potassiumMg":500},"measure":"Colher de sopa rasa: 1"},{"food":"Morango","grams":60,"macros":{"energyKcal":32,"proteinG":0.67,"carbohydrateG":7.68,"fatG":0.3,"fiberG":2,"sodiumMg":1,"calciumMg":16,"ironMg":0.41,"potassiumMg":153},"measure":"Unidade: 5"}],"time":"15:30","notes":"Outra opção de vitamina encorpada e mais proteica. Com auxílio de um liquidificador, bata bem os ingredientes de forma que fique bem homogêneo e sem grumos. "}]},"dimensions":{"approaches":["enteral"],"objectives":[],"restrictions":["enteral"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta enteral artesanal de 2000 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","enteral"],"snapshot":{"dietboxId":19507529,"originalName":"Dieta enteral artesanal de 2000 Kcal","kcalTotal":2038,"summary":{"energyKcal":2037.6,"proteinG":103.7,"carbohydrateG":213.2,"fatG":89.9,"fiberG":26.1,"sodiumMg":931.9,"calciumMg":1349.4,"ironMg":9.3,"potassiumMg":4946.7},"meals":[{"name":"Café da manhã","items":[{"food":"Maçã","grams":90,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade Pequena: 1"},{"food":"Água de coco","grams":150,"macros":{"energyKcal":19.27,"proteinG":0.73,"carbohydrateG":3.76,"fatG":0.2,"fiberG":1.12,"sodiumMg":106.52,"calciumMg":24.35,"ironMg":0.29,"potassiumMg":253.61},"measure":"Copo Americano: 1"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"08:00","notes":"Opção de suco encorpado e mais calórico. Basta bater os ingredientes (sem a casca da maçã) em um liquidificador, de forma que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final. O azeite também pode ser substituído por TCM."},{"name":"Colação","items":[{"food":"Suco de laranja com cenoura sem açúcar","grams":165,"macros":{"energyKcal":44.26,"proteinG":0.83,"carbohydrateG":10.29,"fatG":0.19,"fiberG":1.11,"sodiumMg":13.92,"calciumMg":17.09,"ironMg":0.31,"potassiumMg":246.83},"measure":"Copo pequeno (165ml): 1"}],"time":"10:00","notes":"Bata os ingredientes em um liquidificador/processador, de forma que fique bem homogêneo e sem grumos."},{"name":"Almoço","items":[{"food":"Mostarda","grams":90,"macros":{"energyKcal":15,"proteinG":2.26,"carbohydrateG":2.1,"fatG":0.24,"fiberG":2,"sodiumMg":16,"calciumMg":74,"ironMg":0.7,"potassiumMg":202},"measure":"verdura) Cozido(a) (Colher De Sopa: 2"},{"food":"Feijão","grams":70,"macros":{"energyKcal":97.41,"proteinG":5.84,"carbohydrateG":15.05,"fatG":1.79,"fiberG":3.78,"sodiumMg":5.2,"calciumMg":55.2,"ironMg":2.22,"potassiumMg":336.6},"measure":"preto, mulatinho, roxo, rosinha, etc.)  (Colher De Arroz/Servir: 2"},{"food":"Abóbora Cozido(a)","grams":72,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230},"measure":"Colher De Arroz/Servir: 1"},{"food":"Batata doce cozida sem sal","grams":84,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Colher de sopa cheia (picada) (42g): 2"},{"food":"Peixe de água doce","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)  Cozido(a) (File: 1"},{"food":"Azeite, de oliva, extra virgem","grams":16,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 2"}],"time":"12:30","notes":"Aqui, você pode fazer um preparo só, para ser usado no almoço e jantar. De opções, você pode preparar o legume junto ao tubérculo, como se fosse fazer uma sopa de legumes, sendo a proteína, o peixe, por ser mais fácil de \"desmanchar\" sem ficar retido nas bordas da sonda ou obstruindo a GTT. Você também pode preparar os alimentos em uma panela de pressão, assim, eles desmancham mais, o que facilita na hora de bater no liquidificador/mixer. Bata tudo, até que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final. Os feijões, podem ser peneirados, devido à sua película poder ficar retida na sonda."},{"name":"Jantar","items":[{"food":"Mostarda","grams":90,"macros":{"energyKcal":15,"proteinG":2.26,"carbohydrateG":2.1,"fatG":0.24,"fiberG":2,"sodiumMg":16,"calciumMg":74,"ironMg":0.7,"potassiumMg":202},"measure":"verdura) Cozido(a) (Colher De Sopa: 2"},{"food":"Feijão","grams":70,"macros":{"energyKcal":97.41,"proteinG":5.84,"carbohydrateG":15.05,"fatG":1.79,"fiberG":3.78,"sodiumMg":5.2,"calciumMg":55.2,"ironMg":2.22,"potassiumMg":336.6},"measure":"preto, mulatinho, roxo, rosinha, etc.)  (Colher De Arroz/Servir: 2"},{"food":"Abóbora Cozido(a)","grams":72,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230},"measure":"Colher De Arroz/Servir: 1"},{"food":"Batata doce cozida sem sal","grams":84,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Colher de sopa cheia (picada) (42g): 2"},{"food":"Peixe de água doce","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)  Cozido(a) (File: 1"},{"food":"Azeite, de oliva, extra virgem","grams":16,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 2"}],"time":"20:00","notes":"Aqui, você pode fazer um preparo só, para ser usado no almoço e jantar. De opções, você pode preparar o legume junto ao tubérculo, como se fosse fazer uma sopa de legumes, sendo a proteína, o peixe, por ser mais fácil de \"desmanchar\" sem ficar retido nas bordas da sonda ou obstruindo a GTT. Você também pode preparar os alimentos em uma panela de pressão, assim, eles desmancham mais, o que facilita na hora de bater no liquidificador/mixer. Bata tudo, até que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final."},{"name":"Lanche da tarde 1","items":[{"food":"Leite em pó integral","grams":32,"macros":{"energyKcal":480,"proteinG":25.76,"carbohydrateG":36.16,"fatG":26,"fiberG":0,"sodiumMg":320,"calciumMg":904,"ironMg":0.24,"potassiumMg":1144},"measure":"Colher De Sopa: 2"},{"food":"Leite, vaca, integral, UHT","grams":165,"macros":{"energyKcal":65,"proteinG":2.35,"carbohydrateG":7.16,"fatG":3.04,"fiberG":0,"sodiumMg":63.8,"calciumMg":107,"ironMg":0,"potassiumMg":133},"measure":"Copo americano pequeno: 1"},{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia pequena (100g): 1"},{"food":"Achocolatado em pó","grams":16,"macros":{"energyKcal":400,"proteinG":4.55,"carbohydrateG":90.28,"fatG":2.27,"fiberG":4.5,"sodiumMg":136,"calciumMg":455,"ironMg":0,"potassiumMg":280},"measure":"Colher De Sopa: 1"},{"food":"Farinha de aveia","grams":18,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 1"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"15:00","notes":"Opção de vitamina mais calórica. Basta bater os ingredientes (sim, leite em pó e leite líquido) em um liquidificador, de forma que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final. O azeite também pode ser substituído por TCM."},{"name":"Lanche da tarde 2","items":[{"food":"Leite, vaca, integral, UHT","grams":240,"macros":{"energyKcal":65,"proteinG":2.35,"carbohydrateG":7.16,"fatG":3.04,"fiberG":0,"sodiumMg":63.8,"calciumMg":107,"ironMg":0,"potassiumMg":133},"measure":"Copo americano duplo: 1"},{"food":"Iogurte natural","grams":110,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote 110 g: 1"},{"food":"Banana, prata, crua","grams":90,"macros":{"energyKcal":98.25,"proteinG":1.27,"carbohydrateG":25.96,"fatG":0.07,"fiberG":2.04,"sodiumMg":0,"calciumMg":7.56,"ironMg":0.38,"potassiumMg":357.68},"measure":"Unidade Pequena: 1"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"18:00","notes":"Opção de vitamina mais calórica. Basta bater os ingredientes em um liquidificador, de forma que fique bem homogêneo e sem grumos. Adicione o azeite apenas ao final. O azeite também pode ser substituído por TCM."}]},"dimensions":{"approaches":["enteral"],"objectives":[],"restrictions":["enteral"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}}]$data$::jsonb) loop
    insert into public.plan_templates (organization_id, name, objective, tags, snapshot, created_by, scope, dimensions, rules)
    values (target_organization_id, model->>'name', model->>'objective', (select array(select jsonb_array_elements_text(model->'tags'))), model->'snapshot', actor, 'organization', model->'dimensions', model->'rules')
    on conflict (organization_id, (snapshot->>'dietboxId')) where snapshot ? 'dietboxId' do update set
      name = excluded.name, objective = excluded.objective, tags = excluded.tags, snapshot = excluded.snapshot,
      dimensions = excluded.dimensions, rules = excluded.rules, updated_at = now();
  end loop;

  for model in select jsonb_array_elements($data$[{"name":"Dieta Hiperproteica","objective":"Cardápio clínico para plano hiperproteico — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":241329,"originalName":"Dieta Hiperproteica","kcalTotal":2052,"summary":{"energyKcal":2051.5,"proteinG":156.8,"carbohydrateG":211,"fatG":63.6,"fiberG":21.7,"sodiumMg":1734.3,"calciumMg":2108.5,"ironMg":10.7,"potassiumMg":3488.9},"meals":[{"name":"Jantar","items":[{"food":"Torrada de qualquer pão","grams":24,"macros":{"energyKcal":377,"proteinG":10.5,"carbohydrateG":74.6,"fatG":3.3,"fiberG":3.4,"sodiumMg":829,"calciumMg":19,"ironMg":1.2,"potassiumMg":189},"measure":"Unidade: 3"},{"food":"Omelete, de queijo","grams":150,"macros":{"energyKcal":268.01,"proteinG":15.57,"carbohydrateG":0.44,"fatG":22.01,"fiberG":0,"sodiumMg":216.05,"calciumMg":165.73,"ironMg":1.37,"potassiumMg":126.93},"measure":"Grama: 150"}],"time":"19:00"},{"name":"Ceia","items":[{"food":"Castanha, japonesa, assada","grams":5,"macros":{"energyKcal":201,"proteinG":2.97,"carbohydrateG":45.13,"fatG":0.8,"fiberG":0,"sodiumMg":19,"calciumMg":35,"ironMg":2.1,"potassiumMg":427},"measure":"Grama: 5"},{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"},{"food":"Achocolatado, pó","grams":10,"macros":{"energyKcal":401.02,"proteinG":4.2,"carbohydrateG":91.18,"fatG":2.17,"fiberG":3.89,"sodiumMg":64.79,"calciumMg":44.4,"ironMg":5.36,"potassiumMg":496.45},"measure":"Colher De Sobremesa: 1"},{"food":"Leite de vaca desnatado","grams":240,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Copo De Requeijao: 1"}],"time":"22:00"},{"name":"Desjejum","items":[{"food":"Pão, aveia, forma","grams":10,"macros":{"energyKcal":343.09,"proteinG":12.35,"carbohydrateG":59.57,"fatG":5.69,"fiberG":5.98,"sodiumMg":605.76,"calciumMg":108.69,"ironMg":4.73,"potassiumMg":210.08},"measure":"Fatia: 2"},{"food":"Queijo, minas, frescal","grams":60,"macros":{"energyKcal":264.27,"proteinG":17.41,"carbohydrateG":3.24,"fatG":20.18,"fiberG":0,"sodiumMg":31.23,"calciumMg":579.25,"ironMg":0.93,"potassiumMg":104.85},"measure":"Fatia Média (30g): 2"},{"food":"Mamão, Papaia, cru","grams":10,"macros":{"energyKcal":40.16,"proteinG":0.46,"carbohydrateG":10.44,"fatG":0.12,"fiberG":1.04,"sodiumMg":1.63,"calciumMg":22.42,"ironMg":0.19,"potassiumMg":126.15},"measure":"Fatia: 2"},{"food":"Quinoa","grams":10,"macros":{"energyKcal":135.47,"proteinG":4.37,"carbohydrateG":19.83,"fatG":4.33,"fiberG":2.16,"sodiumMg":4.27,"calciumMg":16.57,"ironMg":1.41,"potassiumMg":174.05},"measure":"Colher De Sopa: 2"},{"food":"Achocolatado em pó","grams":11,"macros":{"energyKcal":400,"proteinG":4.55,"carbohydrateG":90.28,"fatG":2.27,"fiberG":4.5,"sodiumMg":136,"calciumMg":455,"ironMg":0,"potassiumMg":280},"measure":"Colher De Sobremesa: 1"},{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Copo Grande: 1"},{"food":"Leite em pó desnatado","grams":20,"macros":{"energyKcal":358,"proteinG":35.1,"carbohydrateG":52.19,"fatG":0.72,"fiberG":0,"sodiumMg":549,"calciumMg":1231,"ironMg":0.31,"potassiumMg":1705},"measure":"Colher De Sopa: 2"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Iogurte, natural, desnatado","grams":200,"macros":{"energyKcal":41.49,"proteinG":3.83,"carbohydrateG":5.77,"fatG":0.32,"fiberG":0,"sodiumMg":59.64,"calciumMg":156.96,"ironMg":0,"potassiumMg":182.13},"measure":"Copo: 2"},{"food":"Granola","grams":10,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"Colher De Sobremesa: 2"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":80,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Sopa: 4"},{"food":"Feijão, carioca, cozido","grams":65,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Concha Pequena Cheia: 1"},{"food":"Filé de frango Grelhado(a)/brasa/churrasco","grams":200,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Bife: 2"},{"food":"Salada ou verdura crua, exceto de fruta","grams":60,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Colher De Arroz/Servir: 1"},{"food":"Suco de acerola","grams":150,"macros":{"energyKcal":23.06,"proteinG":0.4,"carbohydrateG":4.81,"fatG":0.3,"fiberG":0.3,"sodiumMg":3.01,"calciumMg":10.02,"ironMg":0.5,"potassiumMg":97.24},"measure":"Copo Americano: 1"}],"time":"13:00"},{"name":"Lanche da tarde","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Queijo, cottage, magro, 1% gordura","grams":60,"macros":{"energyKcal":72,"proteinG":12.39,"carbohydrateG":2.72,"fatG":1.02,"fiberG":0,"sodiumMg":406,"calciumMg":61,"ironMg":0.14,"potassiumMg":86},"measure":"Grama: 60"},{"food":"Abacaxi, cru, todas as variedades","grams":168,"macros":{"energyKcal":48,"proteinG":0.54,"carbohydrateG":12.63,"fatG":0.12,"fiberG":1.4,"sodiumMg":1,"calciumMg":13,"ironMg":0.28,"potassiumMg":0},"measure":"fatia, fina (8.9 diâmetro x 1.3 cm espessura): 3"},{"food":"Café, infusão 10%","grams":60,"macros":{"energyKcal":9.07,"proteinG":0.71,"carbohydrateG":1.48,"fatG":0.07,"fiberG":0,"sodiumMg":1.03,"calciumMg":3.16,"ironMg":0,"potassiumMg":155.7},"measure":"Xícara De Cafézinho: 1"}],"time":"16:00"}]},"dimensions":{"approaches":[],"objectives":["high_protein"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2052},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Hipocalêmica 1.400 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1400 kcal"],"snapshot":{"dietboxId":1304531,"originalName":"Dieta Hipocalêmica 1.400 Kcal","kcalTotal":1424,"summary":{"energyKcal":1424.2,"proteinG":70,"carbohydrateG":184.8,"fatG":46.5,"fiberG":12.3,"sodiumMg":1736.5,"calciumMg":1154.5,"ironMg":8.2,"potassiumMg":2510.4},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"},{"food":"Café, infusão 10%","grams":20,"macros":{"energyKcal":9.07,"proteinG":0.71,"carbohydrateG":1.48,"fatG":0.07,"fiberG":0,"sodiumMg":1.03,"calciumMg":3.16,"ironMg":0,"potassiumMg":155.7},"measure":"20 Grama"},{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"1 Unidade (50g)"},{"food":"Margarina com ou sem sal","grams":10,"macros":{"energyKcal":719,"proteinG":0.9,"carbohydrateG":0.9,"fatG":80.5,"fiberG":0,"sodiumMg":943,"calciumMg":30,"ironMg":0,"potassiumMg":42},"measure":"2 Ponta De Faca"},{"food":"Pêra","grams":100,"macros":{"energyKcal":59,"proteinG":0.39,"carbohydrateG":15.1,"fatG":0.4,"fiberG":2.4,"sodiumMg":0,"calciumMg":11,"ironMg":0.25,"potassiumMg":125},"measure":"1 Unidade"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (4 Colher de sopa cheia (25g)"},{"food":"Carne moída","grams":100,"macros":{"energyKcal":293.11,"proteinG":24.09,"carbohydrateG":0.86,"fatG":20.83,"fiberG":0.13,"sodiumMg":411.33,"calciumMg":13.75,"ironMg":2.45,"potassiumMg":301.72},"measure":"refogada) (4 Colher de sopa cheia (25g)"},{"food":"Cenoura Cozido(a)","grams":50,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"2 Colher De Sopa"},{"food":"Chuchu","grams":40,"macros":{"energyKcal":24,"proteinG":0.62,"carbohydrateG":5.1,"fatG":0.48,"fiberG":0.58,"sodiumMg":1,"calciumMg":13,"ironMg":0.22,"potassiumMg":173},"measure":"cozido) (2 Colher de sopa cheia (picado) (20g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"1 Pote"},{"food":"Biscoito cream cracker","grams":25,"macros":{"energyKcal":473,"proteinG":9.3,"carbohydrateG":67.3,"fatG":18.5,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"5 Unidade"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Arroz branco","grams":100,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (4 Colher de sopa cheia (25g)"},{"food":"Frango, inteiro, sem pele, assado","grams":15,"macros":{"energyKcal":187.34,"proteinG":28.03,"carbohydrateG":0,"fatG":7.5,"fiberG":0,"sodiumMg":70.27,"calciumMg":9.06,"ironMg":0.55,"potassiumMg":283.27},"measure":"1 Pedaço"},{"food":"Abobrinha Cozido(a)","grams":60,"macros":{"energyKcal":20,"proteinG":0.91,"carbohydrateG":4.31,"fatG":0.31,"fiberG":1.4,"sodiumMg":1,"calciumMg":27,"ironMg":0.36,"potassiumMg":192},"measure":"2 Colher De Sopa"},{"food":"Berinjela","grams":50,"macros":{"energyKcal":28,"proteinG":0.83,"carbohydrateG":6.65,"fatG":0.23,"fiberG":2.5,"sodiumMg":3,"calciumMg":6,"ironMg":0.35,"potassiumMg":248},"measure":"cozida) (2 Colher de sopa cheia (25g)"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"},{"food":"Café, infusão 10%","grams":20,"macros":{"energyKcal":9.07,"proteinG":0.71,"carbohydrateG":1.48,"fatG":0.07,"fiberG":0,"sodiumMg":1.03,"calciumMg":3.16,"ironMg":0,"potassiumMg":155.7},"measure":"20 Grama"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1400},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Hipocalórica 1.000 Kcal","objective":"Cardápio clínico para perda de peso — adaptar à avaliação nutricional do paciente.","tags":["1000 kcal"],"snapshot":{"dietboxId":1231501,"originalName":"Dieta Hipocalórica 1.000 Kcal","kcalTotal":1024,"summary":{"energyKcal":1024.1,"proteinG":84.2,"carbohydrateG":132.8,"fatG":20.6,"fiberG":18.7,"sodiumMg":2276.3,"calciumMg":765.8,"ironMg":4.3,"potassiumMg":2829},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Caneca: 1"},{"food":"Café solúvel granunado - Nescafé Tradição Nestlé®","grams":6,"macros":{"energyKcal":199,"proteinG":14,"carbohydrateG":35.3,"fatG":0.2,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Chá: 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Ricota","grams":40,"macros":{"energyKcal":174,"proteinG":11.3,"carbohydrateG":13.05,"fatG":13,"fiberG":0,"sodiumMg":84.1,"calciumMg":207,"ironMg":0.38,"potassiumMg":105},"measure":"Colher de sopa (20g): 2"},{"food":"Mamão","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Laranja, da terra, crua","grams":60,"macros":{"energyKcal":51.47,"proteinG":1.08,"carbohydrateG":12.86,"fatG":0.19,"fiberG":3.98,"sodiumMg":0.83,"calciumMg":51.08,"ironMg":0.15,"potassiumMg":172.52},"measure":"Unidade: 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":120,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Escumadeira: 2"},{"food":"Outros legumes cozidos","grams":110,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Arroz/Servir: 2"},{"food":"Frango, peito, sem pele, cozido","grams":140,"macros":{"energyKcal":162.87,"proteinG":31.47,"carbohydrateG":0,"fatG":3.16,"fiberG":0,"sodiumMg":36.17,"calciumMg":6.44,"ironMg":0.34,"potassiumMg":231.05},"measure":"Peito Pequeno (140g): 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Iogurte de qualquer sabor diet","grams":150,"macros":{"energyKcal":51.35,"proteinG":3.11,"carbohydrateG":3.88,"fatG":2.65,"fiberG":0.08,"sodiumMg":33.45,"calciumMg":66.71,"ironMg":0.06,"potassiumMg":85.59},"measure":"Copo Americano: 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Sopa","grams":520,"macros":{"energyKcal":28.78,"proteinG":1.63,"carbohydrateG":3.81,"fatG":0.78,"fiberG":0.64,"sodiumMg":333.11,"calciumMg":6.74,"ironMg":0.22,"potassiumMg":57.45},"measure":"legumes, carne, etc.)  (Prato Fundo: 1"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"22:30"}]},"dimensions":{"approaches":[],"objectives":["weight_loss"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Hipoglicêmica 1.200 Kcal","objective":"Cardápio clínico para controle glicêmico — adaptar à avaliação nutricional do paciente.","tags":["1200 kcal"],"snapshot":{"dietboxId":1255419,"originalName":"Dieta Hipoglicêmica 1.200 Kcal","kcalTotal":1210,"summary":{"energyKcal":1210.3,"proteinG":75.2,"carbohydrateG":162.9,"fatG":30.9,"fiberG":16.1,"sodiumMg":764.3,"calciumMg":503.4,"ironMg":8.1,"potassiumMg":2014.3},"meals":[{"name":"Café da manhã","items":[{"food":"Café com leite","grams":300,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"Caneca: 1"},{"food":"Bolo de banana integral","grams":70,"macros":{"energyKcal":300.05,"proteinG":3.93,"carbohydrateG":52.14,"fatG":9.07,"fiberG":1.66,"sodiumMg":218.07,"calciumMg":29.47,"ironMg":1.21,"potassiumMg":184.18},"measure":"Fatia: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Damasco seco","grams":14,"macros":{"energyKcal":238,"proteinG":3.66,"carbohydrateG":61.8,"fatG":0.46,"fiberG":7.8,"sodiumMg":10,"calciumMg":45,"ironMg":4.71,"potassiumMg":1378},"measure":"Unidade (7g): 2"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":40,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 2"},{"food":"Filé de frango","grams":100,"macros":{"energyKcal":163.67,"proteinG":30.59,"carbohydrateG":0.25,"fatG":3.53,"fiberG":0.02,"sodiumMg":370.13,"calciumMg":16.35,"ironMg":1.05,"potassiumMg":255.3},"measure":"cozido) (Filé: 1"},{"food":"Alface, folha verde, crua","grams":72,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"xícara, picada: 2"},{"food":"Manga","grams":45,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":2.77,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156},"measure":"Colher de servir (picada) (45g): 1"},{"food":"Rúcula","grams":8,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"Pegador (8g): 1"}],"time":"12:30","notes":"Arroz com filé de frango + Salada de alface e rúcula com manga"},{"name":"Lanche da tarde","items":[{"food":"Iogurte, natural, desnatado","grams":100,"macros":{"energyKcal":41.49,"proteinG":3.83,"carbohydrateG":5.77,"fatG":0.32,"fiberG":0,"sodiumMg":59.64,"calciumMg":156.96,"ironMg":0,"potassiumMg":182.13},"measure":"Copo: 1"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 3"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Filé-mignon","grams":70,"macros":{"energyKcal":204,"proteinG":30.67,"carbohydrateG":0,"fatG":9,"fiberG":0,"sodiumMg":41,"calciumMg":7,"ironMg":2.53,"potassiumMg":252},"measure":"Flié: 2"},{"food":"Mandioca Cozido(a)","grams":120,"macros":{"energyKcal":125,"proteinG":0.6,"carbohydrateG":30.1,"fatG":0.3,"fiberG":1.6,"sodiumMg":1,"calciumMg":19,"ironMg":0.1,"potassiumMg":100},"measure":"Escumadeira: 2"},{"food":"Alface","grams":50,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Prato Raso: 1"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de sobremesa (5,2ml): 1"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["glycemic_control"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Hipolipídica 1.350 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1350 kcal"],"snapshot":{"dietboxId":1238915,"originalName":"Dieta Hipolipídica 1.350 Kcal","kcalTotal":1618,"summary":{"energyKcal":1617.5,"proteinG":112.1,"carbohydrateG":219.8,"fatG":36.4,"fiberG":35.1,"sodiumMg":1241.6,"calciumMg":911.9,"ironMg":9.4,"potassiumMg":4560.4},"meals":[{"name":"Café da manhã","items":[{"food":"Leite, de vaca, desnatado, UHT","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"Copo Cheio (200ml): 1"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Queijo ricota","grams":70,"macros":{"energyKcal":174,"proteinG":11.26,"carbohydrateG":3.04,"fatG":12.98,"fiberG":0,"sodiumMg":84,"calciumMg":207,"ironMg":0.38,"potassiumMg":105},"measure":"Fatia: 2"}],"time":"08:00"},{"name":"Colação","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":40,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 2"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 3"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"}],"time":"12:30","notes":"Salada verde à vontade, sem óleo nem azeite "},{"name":"Lanche da tarde","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Peixe, carpa, cozida, grelhado","grams":170,"macros":{"energyKcal":162,"proteinG":22.86,"carbohydrateG":0,"fatG":7.17,"fiberG":0,"sodiumMg":63,"calciumMg":52,"ironMg":1.59,"potassiumMg":427},"measure":"filé: 1"},{"food":"Batata, inglesa, cozida","grams":210,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Unidade Média: 3"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 3"}],"time":"20:00","notes":"Salda verde à vontade, sem óleo ou azeite. "},{"name":"Ceia","items":[{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia média (170g): 1"}],"time":"23:30"},{"name":"Lanche da tarde","items":[{"food":"Laranja","grams":290,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"Unidade grande (290g): 1"}],"time":"02:00"},{"name":"Lanche da tarde","items":[{"food":"Laranja","grams":290,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"Unidade grande (290g): 1"}],"time":"14:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1350},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Hipoproteica 1.100 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1100 kcal"],"snapshot":{"dietboxId":1238881,"originalName":"Dieta Hipoproteica 1.100 Kcal","kcalTotal":1129,"summary":{"energyKcal":1128.6,"proteinG":26.7,"carbohydrateG":187.4,"fatG":32.9,"fiberG":26,"sodiumMg":1200,"calciumMg":221.4,"ironMg":8,"potassiumMg":1878},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Copo Americano: 1"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Manteiga com ou sem sal","grams":10,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"Ponta De Faca: 2"}],"time":"08:00"},{"name":"Colação","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Batata, inglesa, cozida","grams":70,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Unidade Média: 1"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 3"},{"food":"Arroz branco","grams":50,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Colher de sopa cheia (25g): 2"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Manteiga com ou sem sal","grams":20,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"Ponta De Faca: 4"},{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Batata, inglesa, cozida","grams":70,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Unidade Média: 1"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 3"},{"food":"Arroz branco","grams":50,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Colher de sopa cheia (25g): 2"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Banana","grams":42,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade pequena (42g): 1"},{"food":"Aveia","grams":15,"macros":{"energyKcal":389,"proteinG":16.89,"carbohydrateG":66.27,"fatG":6.9,"fiberG":10.6,"sodiumMg":2,"calciumMg":54,"ironMg":4.72,"potassiumMg":429},"measure":"Grama: 15"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1100},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Isenta de Glúten 1.600 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1600 kcal"],"snapshot":{"dietboxId":1289784,"originalName":"Dieta Isenta de Glúten 1.600 Kcal","kcalTotal":1612,"summary":{"energyKcal":1611.6,"proteinG":97.6,"carbohydrateG":130.5,"fatG":78.8,"fiberG":19.2,"sodiumMg":2886.7,"calciumMg":1206.2,"ironMg":9.3,"potassiumMg":2151.7},"meals":[{"name":"Café da manhã","items":[{"food":"Café com leite","grams":300,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"1 Caneca"},{"food":"Pão de milho","grams":35,"macros":{"energyKcal":316.62,"proteinG":7.2,"carbohydrateG":47.96,"fatG":10.43,"fiberG":4.38,"sodiumMg":774.22,"calciumMg":71,"ironMg":1.86,"potassiumMg":126.11},"measure":"1 Fatia"},{"food":"Margarina sem sal","grams":10,"macros":{"energyKcal":719,"proteinG":0.9,"carbohydrateG":0.9,"fatG":80.5,"fiberG":0,"sodiumMg":943,"calciumMg":30,"ironMg":0,"potassiumMg":42},"measure":"2 Ponta De Faca"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Maçã vermelha","grams":152,"macros":{"energyKcal":59,"proteinG":0.19,"carbohydrateG":15.3,"fatG":0.36,"fiberG":1.97,"sodiumMg":0,"calciumMg":7,"ironMg":0.18,"potassiumMg":115},"measure":"1 Unidade (152g)"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (3 Colher de sopa cheia (20g)"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Frango Grelhado(1 Bife)","grams":100,"macros":{"energyKcal":239,"proteinG":27.3,"carbohydrateG":0,"fatG":13.6,"fiberG":0,"sodiumMg":82,"calciumMg":15,"ironMg":1.26,"potassiumMg":223}},{"food":"Salada ou verdura cozida, exceto de fruta","grams":84,"macros":{"energyKcal":26,"proteinG":2.11,"carbohydrateG":4.91,"fatG":0.36,"fiberG":2.8,"sodiumMg":16,"calciumMg":140,"ironMg":1.16,"potassiumMg":116},"measure":"2 Colher De Arroz/Servir"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml)"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Americano"},{"food":"Pão de batata","grams":30,"macros":{"energyKcal":241.35,"proteinG":6.79,"carbohydrateG":36.57,"fatG":7.59,"fiberG":2.68,"sodiumMg":1009.1,"calciumMg":32.7,"ironMg":2.59,"potassiumMg":301.73},"measure":"1 Fatia"},{"food":"Queijo de minas","grams":90,"macros":{"energyKcal":240,"proteinG":17.6,"carbohydrateG":10.6,"fatG":14.1,"fiberG":0,"sodiumMg":1587,"calciumMg":529,"ironMg":0.2,"potassiumMg":330},"measure":"2 Fatia"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (3 Colher de sopa cheia (20g)"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Frango Grelhado(1 Bife)","grams":100,"macros":{"energyKcal":239,"proteinG":27.3,"carbohydrateG":0,"fatG":13.6,"fiberG":0,"sodiumMg":82,"calciumMg":15,"ironMg":1.26,"potassiumMg":223}},{"food":"Salada ou verdura cozida, exceto de fruta","grams":84,"macros":{"energyKcal":26,"proteinG":2.11,"carbohydrateG":4.91,"fatG":0.36,"fiberG":2.8,"sodiumMg":16,"calciumMg":140,"ironMg":1.16,"potassiumMg":116},"measure":"2 Colher De Arroz/Servir"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml)"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Copo Americano"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1600},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Low Carb - 1200 kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1200 kcal","low_carb"],"snapshot":{"dietboxId":19202066,"originalName":"Dieta Low Carb - 1200 kcal","kcalTotal":1198,"summary":{"energyKcal":1197.9,"proteinG":131.4,"carbohydrateG":100.8,"fatG":31.3,"fiberG":30,"sodiumMg":1723.3,"calciumMg":644.8,"ironMg":8.3,"potassiumMg":3408},"meals":[{"name":"Café da manhã","items":[{"food":"Café","grams":200,"macros":{"energyKcal":1,"proteinG":0.12,"carbohydrateG":0.47,"fatG":0.02,"fiberG":0.47,"sodiumMg":2,"calciumMg":2,"ironMg":0.01,"potassiumMg":49.05},"measure":"Mililitro: 200"},{"food":"Ovo de galinha Cozido(a)","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Iogurte desnatado","grams":160,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Grama: 160"},{"food":"Morango","grams":100,"macros":{"energyKcal":32,"proteinG":0.67,"carbohydrateG":7.68,"fatG":0.3,"fiberG":2,"sodiumMg":1,"calciumMg":16,"ironMg":0.41,"potassiumMg":153},"measure":"Grama: 100"},{"food":"Psyllium - Vitao Alimentos","grams":10,"macros":{"energyKcal":70,"proteinG":6,"carbohydrateG":8,"fatG":0,"fiberG":70,"sodiumMg":150,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"09:00"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"},{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé pequeno (100g): 1"},{"food":"Batata, inglesa, cozida","grams":70,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"Grama: 70"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Whey Protein Concentrado DUX - Banana","grams":28,"macros":{"energyKcal":389.2,"proteinG":71.4,"carbohydrateG":12.5,"fatG":6.5,"fiberG":1.8,"sodiumMg":210.7,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 1"},{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia pequena (100g): 1"},{"food":"Queijo, cottage, magro, 1% gordura","grams":20,"macros":{"energyKcal":72,"proteinG":12.39,"carbohydrateG":2.72,"fatG":1.02,"fiberG":0,"sodiumMg":406,"calciumMg":61,"ironMg":0.14,"potassiumMg":86},"measure":"Grama: 20"},{"food":"Pão, trigo, forma, integral","grams":30,"macros":{"energyKcal":253.19,"proteinG":9.43,"carbohydrateG":49.94,"fatG":3.65,"fiberG":6.88,"sodiumMg":506.1,"calciumMg":131.76,"ironMg":2.99,"potassiumMg":162.87},"measure":"Fatia (30g): 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"}],"time":"19:30"}]},"dimensions":{"approaches":["low_carb"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Low Carb - 2000 kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal","low_carb"],"snapshot":{"dietboxId":19202095,"originalName":"Dieta Low Carb - 2000 kcal","kcalTotal":2015,"summary":{"energyKcal":2014.5,"proteinG":192.3,"carbohydrateG":129.9,"fatG":81.3,"fiberG":30.2,"sodiumMg":1692,"calciumMg":680.8,"ironMg":14.1,"potassiumMg":4958.7},"meals":[{"name":"Café da manhã","items":[{"food":"Ovo de galinha Cozido(a)","grams":180,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 4"},{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia média (170g): 1"},{"food":"Pão de forma integral - Pullman®","grams":22,"macros":{"energyKcal":250,"proteinG":9.38,"carbohydrateG":46.88,"fatG":0,"fiberG":6.25,"sodiumMg":531.25,"calciumMg":240.63,"ironMg":2.09,"potassiumMg":0},"measure":"Fatia (22g): 1"},{"food":"Queijo, cottage, magro, 2% gordura","grams":20,"macros":{"energyKcal":90,"proteinG":13.74,"carbohydrateG":3.63,"fatG":1.93,"fiberG":0,"sodiumMg":406,"calciumMg":69,"ironMg":0.16,"potassiumMg":96},"measure":"Grama: 20"}],"time":"08:30"},{"name":"Almoço","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Arroz branco","grams":80,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Grama: 80"},{"food":"Peixe, salmão, rosa, assado, grelhado","grams":200,"macros":{"energyKcal":149,"proteinG":25.56,"carbohydrateG":0,"fatG":4.42,"fiberG":0,"sodiumMg":86,"calciumMg":17,"ironMg":0.99,"potassiumMg":414},"measure":"Grama: 200"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Abacate","grams":90,"macros":{"energyKcal":161,"proteinG":1.99,"carbohydrateG":7.4,"fatG":15.3,"fiberG":4.1,"sodiumMg":10,"calciumMg":11,"ironMg":1.03,"potassiumMg":599},"measure":"Colher de sopa cheia (picado) (45g): 2"},{"food":"Whey Protein Concentrado DUX - Baunilha","grams":56,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 2"},{"food":"Leite de vaca desnatado","grams":200,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Mililitro: 200"},{"food":"Psyllium - Vitao Alimentos","grams":10,"macros":{"energyKcal":70,"proteinG":6,"carbohydrateG":8,"fatG":0,"fiberG":70,"sodiumMg":150,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 10"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Salada ou verdura crua, exceto de fruta","grams":150,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Meio Prato Cheio: 1"},{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Batata doce, cozida, assada com casca, sem sal","grams":100,"macros":{"energyKcal":90,"proteinG":2.01,"carbohydrateG":20.71,"fatG":0.15,"fiberG":3.3,"sodiumMg":36,"calciumMg":38,"ironMg":0.69,"potassiumMg":475},"measure":"Grama: 100"},{"food":"Carne, boi, acém, moída, refogada","grams":200,"macros":{"energyKcal":213,"proteinG":25.5,"carbohydrateG":0.71,"fatG":12.1,"fiberG":0.13,"sodiumMg":263,"calciumMg":5.79,"ironMg":2.15,"potassiumMg":320},"measure":"c/ óleo, cebola e alho), c/ sal (Grama: 200"},{"food":"Azeite de oliva extra virgem - Andorinha®","grams":10,"macros":{"energyKcal":720,"proteinG":0,"carbohydrateG":0,"fatG":80,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":1,"potassiumMg":0},"measure":"Grama: 10"}],"time":"19:30"}]},"dimensions":{"approaches":["low_carb"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Low Carb 1.350 kcal (10% CHO)","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1350 kcal","low_carb"],"snapshot":{"dietboxId":1301664,"originalName":"Dieta Low Carb 1.350 kcal (10% CHO)","kcalTotal":1353,"summary":{"energyKcal":1352.9,"proteinG":120.4,"carbohydrateG":35.4,"fatG":79.7,"fiberG":8.8,"sodiumMg":1242.2,"calciumMg":615.2,"ironMg":9.4,"potassiumMg":1964.8},"meals":[{"name":"Café da manhã","items":[{"food":"Omelete, de queijo","grams":200,"macros":{"energyKcal":268.01,"proteinG":15.57,"carbohydrateG":0.44,"fatG":22.01,"fiberG":0,"sodiumMg":216.05,"calciumMg":165.73,"ironMg":1.37,"potassiumMg":126.93},"measure":"2 ovos"},{"food":"Linhaça, semente","grams":4,"macros":{"energyKcal":495.1,"proteinG":14.08,"carbohydrateG":43.31,"fatG":32.25,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211.5,"ironMg":4.7,"potassiumMg":869.29},"measure":"1 Colher De Chá"}],"time":"07:30"},{"name":"Café da manhã","items":[{"food":"Queijo tipo mussarela","grams":26,"macros":{"energyKcal":281,"proteinG":19.4,"carbohydrateG":2.23,"fatG":21.6,"fiberG":0,"sodiumMg":373,"calciumMg":517,"ironMg":0.18,"potassiumMg":67.1},"measure":"2 Fatia (13,5g)"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé médio (140g)"},{"food":"Brócolis","grams":120,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (2 Escumadeira picado (60g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Morango","grams":72,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Meia Xícara de chá picado (144g)"},{"food":"Creme de Leite","grams":20,"macros":{"energyKcal":221.48,"proteinG":1.51,"carbohydrateG":4.51,"fatG":22.48,"fiberG":0,"sodiumMg":51.72,"calciumMg":82.73,"ironMg":0.3,"potassiumMg":118.65},"measure":"1 Colher de Sopa"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Carne, bovina, patinho, sem gordura, grelhado","grams":100,"macros":{"energyKcal":219.26,"proteinG":35.9,"carbohydrateG":0,"fatG":7.31,"fiberG":0,"sodiumMg":60.29,"calciumMg":4.8,"ironMg":3.03,"potassiumMg":420.96},"measure":"1 Bife"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"3 Colher De Sopa"},{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml)"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Melão","grams":90,"macros":{"energyKcal":32,"proteinG":0.62,"carbohydrateG":7.19,"fatG":0.43,"fiberG":0.23,"sodiumMg":2,"calciumMg":8,"ironMg":0.17,"potassiumMg":116},"measure":"1 Fatia média (90g)"}],"time":"23:00"}]},"dimensions":{"approaches":["low_carb"],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1350},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Low FODMAP's 1200 kcal 28% PTN","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1200 kcal","28% ptn"],"snapshot":{"dietboxId":3939298,"originalName":"Dieta Low FODMAP's 1200 kcal 28% PTN","kcalTotal":1192,"summary":{"energyKcal":1191.8,"proteinG":84.8,"carbohydrateG":144.3,"fatG":32.1,"fiberG":20.5,"sodiumMg":996.4,"calciumMg":405.8,"ironMg":15.1,"potassiumMg":2356.7},"meals":[{"name":"Café da manhã","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média"},{"food":"Aveia em flocos","grams":14,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"2 Colher De Sobremesa"},{"food":"Canela em pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"1 Colher de chá (2g)"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"3 Colher De Sopa"},{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé pequeno (100g)"},{"food":"Cenoura crua","grams":24,"macros":{"energyKcal":41,"proteinG":0.93,"carbohydrateG":9.58,"fatG":0.24,"fiberG":2.8,"sodiumMg":69,"calciumMg":33,"ironMg":0.3,"potassiumMg":320},"measure":"2 Colher De Sopa"},{"food":"Alface","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"2 Pegador"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"3 Fatia média (15g)"}],"time":"12:30","notes":"Não consumir feijão ou outras leguminosas. "},{"name":"Jantar","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"3 Colher De Sopa"},{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé pequeno (100g)"},{"food":"Cenoura crua","grams":24,"macros":{"energyKcal":41,"proteinG":0.93,"carbohydrateG":9.58,"fatG":0.24,"fiberG":2.8,"sodiumMg":69,"calciumMg":33,"ironMg":0.3,"potassiumMg":320},"measure":"2 Colher De Sopa"},{"food":"Alface","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"2 Pegador"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"3 Fatia média (15g)"}],"time":"21:00","notes":"Não consumir feijão ou outras leguminosas. "},{"name":"Lanche da tarde","items":[{"food":"Biscoito de arroz","grams":6,"macros":{"energyKcal":359.1,"proteinG":6.82,"carbohydrateG":82.95,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"3 Unidade"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"2 Unidade"},{"food":"Abacaxi","grams":150,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113},"measure":"3 Fatia pequena (50g)"}],"time":"15:00","notes":"Os ovos podem ser feitos mexidos, para serem consumidos com o biscoito de arroz"},{"name":"Ceia","items":[{"food":"Laranja","grams":180,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"1 Unidade média"}],"time":"23:30"},{"name":"Lanche da tarde 2","items":[{"food":"Melão","grams":90,"macros":{"energyKcal":25,"proteinG":0.5,"carbohydrateG":6.2,"fatG":0.1,"fiberG":0.5,"sodiumMg":0,"calciumMg":15,"ironMg":1.2,"potassiumMg":0},"measure":"1 Fatia média (90g)"},{"food":"Mirtilo congelado","grams":50,"macros":{"energyKcal":70,"proteinG":0,"carbohydrateG":14,"fatG":0,"fiberG":2,"sodiumMg":6.34,"calciumMg":6.34,"ironMg":0,"potassiumMg":0},"measure":"1 Porção (50g)"},{"food":"Chia","grams":15,"macros":{"energyKcal":536,"proteinG":17.2,"carbohydrateG":44,"fatG":32.8,"fiberG":13.6,"sodiumMg":20,"calciumMg":872,"ironMg":48.8,"potassiumMg":892},"measure":"1 Colher de Sopa"}],"time":"17:30","notes":"Suco de melão com mirtilo e chia! Bater todos os ingredientes no liquidificador, e pode-se adicionar gelo e água se necessário"},{"name":"Colação","items":[{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia pequena"}],"time":"10:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["low_fodmap"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Low FODMAP's 2000 kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal"],"snapshot":{"dietboxId":7918250,"originalName":"Dieta Low FODMAP's 2000 kcal","kcalTotal":2042,"summary":{"energyKcal":2041.7,"proteinG":114.3,"carbohydrateG":150.2,"fatG":116.2,"fiberG":26.6,"sodiumMg":1367,"calciumMg":386.1,"ironMg":10.9,"potassiumMg":3514.6},"meals":[{"name":"Café da manhã","items":[{"food":"Tapioca de goma","grams":30,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"colher de sopa (15g): 2"},{"food":"Ovo de galinha","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"},{"food":"Queijo de búfala","grams":20,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Grama: 20"}],"time":"08:00","notes":"Tapioca recheada com ovo mexido e muçarela de búfala."},{"name":"Almoço","items":[{"food":"Alface","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"2 Pegador"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"3 Fatia média (15g)"},{"food":"Berinjela","grams":57,"macros":{"energyKcal":28,"proteinG":0.83,"carbohydrateG":6.65,"fatG":0.23,"fiberG":2.5,"sodiumMg":3,"calciumMg":6,"ironMg":0.35,"potassiumMg":248},"measure":"cozida) (Colher de servir (57g): 1"},{"food":"Abobrinha","grams":90,"macros":{"energyKcal":20,"proteinG":0.91,"carbohydrateG":4.32,"fatG":0.31,"fiberG":1.4,"sodiumMg":1,"calciumMg":27,"ironMg":0.36,"potassiumMg":192},"measure":"cozida) (Colher de sopa cheia (picada) (30g): 3"},{"food":"Arroz integral","grams":80,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Sopa: 4) ou Polenta (Colher de sopa cheia (35g): 5) ou Batata, inglesa, cozida/purê (Unidade Média: 2","subs":[{"food":"Polenta","grams":35,"macros":{"energyKcal":62.88,"proteinG":1.02,"carbohydrateG":11.32,"fatG":1.67,"fiberG":1.97,"sodiumMg":222.04,"calciumMg":2.84,"ironMg":0.36,"potassiumMg":46.43}},{"food":"Batata, inglesa, cozida","grams":70,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33}}]},{"food":"Filé de frango ou bovino grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"}],"time":"12:30","notes":"Não consumir feijão ou outras leguminosas. Obs: a berinjela pode ser feita refogada com a abobrinha."},{"name":"Lanche da tarde","items":[{"food":"Morango","grams":96,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 8) ou Melão (Fatia média (90g): 1) ou Kiwi (Unidade média (76g): 2) ou Uva  (Cacho: 1","subs":[{"food":"Melão","grams":90,"macros":{"energyKcal":25,"proteinG":0.5,"carbohydrateG":6.2,"fatG":0.1,"fiberG":0.5,"sodiumMg":0,"calciumMg":15,"ironMg":1.2,"potassiumMg":0}},{"food":"Kiwi","grams":76,"macros":{"energyKcal":61,"proteinG":0.99,"carbohydrateG":14.9,"fatG":0.44,"fiberG":1.9,"sodiumMg":5,"calciumMg":26,"ironMg":0.41,"potassiumMg":332}},{"food":"Uva","grams":170,"macros":{"energyKcal":69,"proteinG":0.72,"carbohydrateG":18.1,"fatG":0.16,"fiberG":0.9,"sodiumMg":2,"calciumMg":10,"ironMg":0.36,"potassiumMg":191}}]},{"food":"Leite de coco - 150ml","grams":150,"macros":{"energyKcal":202.46,"proteinG":1.61,"carbohydrateG":5.59,"fatG":20.85,"fiberG":0.91,"sodiumMg":12.03,"calciumMg":4.01,"ironMg":0.81,"potassiumMg":232.53}},{"food":"Semente de chia","grams":26,"macros":{"energyKcal":534,"proteinG":18.29,"carbohydrateG":28.88,"fatG":42.16,"fiberG":27.3,"sodiumMg":30,"calciumMg":255,"ironMg":5.73,"potassiumMg":813},"measure":"Colher De Sopa: 2"}],"time":"15:00","notes":"Fazer pudim de chia: em um pequeno pote de vidro, deixe hidratando a chia com o leite de coco. Para finalizar, adicione a fruta."},{"name":"Lanche da tarde 2","items":[{"food":"Leite de coco OU outro vegetal","grams":200,"macros":{"energyKcal":202.46,"proteinG":1.61,"carbohydrateG":5.59,"fatG":20.85,"fiberG":0.91,"sodiumMg":12.03,"calciumMg":4.01,"ironMg":0.81,"potassiumMg":232.53},"measure":"200ml"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média: 1"},{"food":"Cacau em pó -","grams":2,"macros":{"energyKcal":400,"proteinG":20,"carbohydrateG":60,"fatG":0,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":11.4,"potassiumMg":0},"measure":"Colher de chá (2,46g): 1"}],"time":"17:30","notes":"Batida de fruta com leite vegetal. A banana pode ser substituida por morangos, ou, mamão. "},{"name":"Colação","items":[{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia pequena (100g): 1) ou Melão (Fatia média (90g): 1) ou Kiwi, cru (Unidade: 2","subs":[{"food":"Melão","grams":90,"macros":{"energyKcal":25,"proteinG":0.5,"carbohydrateG":6.2,"fatG":0.1,"fiberG":0.5,"sodiumMg":0,"calciumMg":15,"ironMg":1.2,"potassiumMg":0}},{"food":"Kiwi, cru","grams":60,"macros":{"energyKcal":51.14,"proteinG":1.34,"carbohydrateG":11.5,"fatG":0.63,"fiberG":2.65,"sodiumMg":0,"calciumMg":23.91,"ironMg":0.25,"potassiumMg":268.92}}]}],"time":"10:30"},{"name":"Jantar","items":[{"food":"Alface","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"2 Pegador"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"3 Fatia média (15g)"},{"food":"Berinjela","grams":57,"macros":{"energyKcal":28,"proteinG":0.83,"carbohydrateG":6.65,"fatG":0.23,"fiberG":2.5,"sodiumMg":3,"calciumMg":6,"ironMg":0.35,"potassiumMg":248},"measure":"cozida) (Colher de servir (57g): 1"},{"food":"Abobrinha","grams":90,"macros":{"energyKcal":20,"proteinG":0.91,"carbohydrateG":4.32,"fatG":0.31,"fiberG":1.4,"sodiumMg":1,"calciumMg":27,"ironMg":0.36,"potassiumMg":192},"measure":"cozida) (Colher de sopa cheia (picada) (30g): 3"},{"food":"Arroz integral","grams":80,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Sopa: 4) ou Polenta (Colher de sopa cheia (35g): 5) ou Batata, inglesa, cozida/purê (Unidade Média: 2","subs":[{"food":"Polenta","grams":35,"macros":{"energyKcal":62.88,"proteinG":1.02,"carbohydrateG":11.32,"fatG":1.67,"fiberG":1.97,"sodiumMg":222.04,"calciumMg":2.84,"ironMg":0.36,"potassiumMg":46.43}},{"food":"Batata, inglesa, cozida","grams":70,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33}}]},{"food":"Filé de frango ou bovino grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"}],"time":"21:00","notes":"Não consumir feijão ou outras leguminosas. Obs: a berinjela pode ser feita refogada com a abobrinha."}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["low_fodmap"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Normocalórica","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":343772,"originalName":"Dieta Normocalórica","kcalTotal":1784,"summary":{"energyKcal":1784.2,"proteinG":87.6,"carbohydrateG":276.1,"fatG":38.7,"fiberG":24.4,"sodiumMg":904.6,"calciumMg":792,"ironMg":13.3,"potassiumMg":2610.5},"meals":[{"name":"Desjejum","items":[{"food":"Pão, trigo, francês","grams":50,"macros":{"energyKcal":299.81,"proteinG":7.95,"carbohydrateG":58.65,"fatG":3.1,"fiberG":2.31,"sodiumMg":647.67,"calciumMg":15.75,"ironMg":1,"potassiumMg":142.2},"measure":"Unidade Comercial: 1"},{"food":"Queijo, minas, frescal","grams":50,"macros":{"energyKcal":264.27,"proteinG":17.41,"carbohydrateG":3.24,"fatG":20.18,"fiberG":0,"sodiumMg":31.23,"calciumMg":579.25,"ironMg":0.93,"potassiumMg":104.85},"measure":"Grama: 50"},{"food":"Café, infusão 10%","grams":60,"macros":{"energyKcal":9.07,"proteinG":0.71,"carbohydrateG":1.48,"fatG":0.07,"fiberG":0,"sodiumMg":1.03,"calciumMg":3.16,"ironMg":0,"potassiumMg":155.7},"measure":"Xícara De Cafézinho: 1"},{"food":"Ameixa, crua","grams":180,"macros":{"energyKcal":52.54,"proteinG":0.77,"carbohydrateG":13.85,"fatG":0,"fiberG":2.43,"sodiumMg":0,"calciumMg":5.72,"ironMg":0.1,"potassiumMg":134.05},"measure":"Unidade Pequena: 2"}],"time":"07:00","notes":" "},{"name":"Colação","items":[{"food":"Barra de cereais","grams":25,"macros":{"energyKcal":352.92,"proteinG":3.17,"carbohydrateG":69.44,"fatG":8.55,"fiberG":2.32,"sodiumMg":284.16,"calciumMg":540.54,"ironMg":4.86,"potassiumMg":80.58},"measure":"Barra: 1"},{"food":"Banana, maçã, crua","grams":50,"macros":{"energyKcal":86.81,"proteinG":1.75,"carbohydrateG":22.34,"fatG":0.06,"fiberG":2.59,"sodiumMg":0,"calciumMg":3.22,"ironMg":0.2,"potassiumMg":264.39},"measure":"Porção Média: 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Salada, de legumes, cozida no vapor","grams":150,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Grama: 150"},{"food":"Carne, bovina, capa de contra-filé, sem gordura, grelhada","grams":100,"macros":{"energyKcal":239.44,"proteinG":35.06,"carbohydrateG":-0.01,"fatG":9.95,"fiberG":0,"sodiumMg":82.75,"calciumMg":8.84,"ironMg":2.84,"potassiumMg":384.84},"measure":"Bife: 1"},{"food":"Arroz, tipo 2, cozido","grams":80,"macros":{"energyKcal":130.12,"proteinG":2.57,"carbohydrateG":28.19,"fatG":0.36,"fiberG":1.07,"sodiumMg":1.96,"calciumMg":3.33,"ironMg":0.05,"potassiumMg":20.2},"measure":"Colher De Sopa Cheia: 4"},{"food":"Feijão, carioca, cozido","grams":34,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Colher De Sopa Cheia: 2"},{"food":"Laranja, baía, crua","grams":60,"macros":{"energyKcal":45.44,"proteinG":0.98,"carbohydrateG":11.47,"fatG":0.1,"fiberG":1.12,"sodiumMg":0,"calciumMg":35.41,"ironMg":0.14,"potassiumMg":174.15},"measure":"Unidade: 1"}],"time":"13:00"},{"name":"Lanche da tarde","items":[{"food":"Bolo, pronto, aipim","grams":25,"macros":{"energyKcal":323.85,"proteinG":4.42,"carbohydrateG":47.86,"fatG":12.75,"fiberG":0.69,"sodiumMg":111.01,"calciumMg":85.02,"ironMg":0.49,"potassiumMg":134.82},"measure":"Fatia Média: 1"},{"food":"Leite, de vaca, integral","grams":100,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":63.76,"calciumMg":122.58,"ironMg":0,"potassiumMg":133.19},"measure":"Copo: 1"},{"food":"Achocolatado, pó","grams":10,"macros":{"energyKcal":401.02,"proteinG":4.2,"carbohydrateG":91.18,"fatG":2.17,"fiberG":3.89,"sodiumMg":64.79,"calciumMg":44.4,"ironMg":5.36,"potassiumMg":496.45},"measure":"Colher De Sobremesa: 1"},{"food":"Banana, prata, crua","grams":90,"macros":{"energyKcal":98.25,"proteinG":1.27,"carbohydrateG":25.96,"fatG":0.07,"fiberG":2.04,"sodiumMg":0,"calciumMg":7.56,"ironMg":0.38,"potassiumMg":357.68},"measure":"Unidade Pequena: 1"},{"food":"Aveia, flocos, crua","grams":24,"macros":{"energyKcal":393.82,"proteinG":13.92,"carbohydrateG":66.64,"fatG":8.5,"fiberG":9.13,"sodiumMg":4.63,"calciumMg":47.89,"ironMg":4.45,"potassiumMg":336.33},"measure":"Colher De Sopa Nivelada: 2"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Macarrão, molho bolognesa","grams":300,"macros":{"energyKcal":119.53,"proteinG":4.93,"carbohydrateG":22.52,"fatG":0.89,"fiberG":0.78,"sodiumMg":8.94,"calciumMg":10.55,"ironMg":1.39,"potassiumMg":83.57},"measure":"Grama: 300"},{"food":"Frango, coxa, sem pele, cozida","grams":15,"macros":{"energyKcal":167.43,"proteinG":26.86,"carbohydrateG":0,"fatG":5.85,"fiberG":0,"sodiumMg":64.34,"calciumMg":11.78,"ironMg":0.83,"potassiumMg":191.14},"measure":"Pedaço: 1"},{"food":"Tomate, salada","grams":54,"macros":{"energyKcal":20.55,"proteinG":0.81,"carbohydrateG":5.12,"fatG":0,"fiberG":2.27,"sodiumMg":5.24,"calciumMg":6.95,"ironMg":0.29,"potassiumMg":161.16},"measure":"Colher De Sopa Cheia: 3"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Queijo, requeijão, cremoso","grams":18,"macros":{"energyKcal":256.58,"proteinG":9.63,"carbohydrateG":2.43,"fatG":23.44,"fiberG":0,"sodiumMg":557.92,"calciumMg":259.47,"ironMg":0.12,"potassiumMg":93.06},"measure":"Colher De Sopa Cheia: 1"},{"food":"Torrada, pão francês","grams":20,"macros":{"energyKcal":377.42,"proteinG":10.52,"carbohydrateG":74.56,"fatG":3.3,"fiberG":3.4,"sodiumMg":829.49,"calciumMg":18.74,"ironMg":1.24,"potassiumMg":189.49},"measure":"Fatia: 4"},{"food":"Chá, erva-doce, infusão 5%","grams":12,"macros":{"energyKcal":1.4,"proteinG":0,"carbohydrateG":0.39,"fatG":0,"fiberG":0,"sodiumMg":0.63,"calciumMg":1.93,"ironMg":0,"potassiumMg":9.93},"measure":"Colher De Chá Cheia: 2"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1784},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Ovolactovegetariana 1.800 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1800 kcal","vegetarian"],"snapshot":{"dietboxId":1320475,"originalName":"Dieta Ovolactovegetariana 1.800 Kcal","kcalTotal":1836,"summary":{"energyKcal":1836.2,"proteinG":85.1,"carbohydrateG":242.7,"fatG":61.8,"fiberG":17.9,"sodiumMg":3102.3,"calciumMg":1125.9,"ironMg":12.1,"potassiumMg":2869.6},"meals":[{"name":"Café da manhã","items":[{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"1 Unidade (50g)"},{"food":"Queijo tipo \"cottage\"","grams":37,"macros":{"energyKcal":94,"proteinG":19.5,"carbohydrateG":0,"fatG":4,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"1 Fatia (37g)"},{"food":"Café com leite","grams":300,"macros":{"energyKcal":31.44,"proteinG":1.72,"carbohydrateG":2.57,"fatG":1.69,"fiberG":0.24,"sodiumMg":21.63,"calciumMg":59.27,"ironMg":0.02,"potassiumMg":98.27},"measure":"1 Caneca"}],"time":"07:00"},{"name":"Lanche da tarde","items":[{"food":"Mamão formosa","grams":170,"macros":{"energyKcal":32,"proteinG":0.5,"carbohydrateG":8.3,"fatG":0.1,"fiberG":0.6,"sodiumMg":0,"calciumMg":20,"ironMg":0.4,"potassiumMg":0},"measure":"1 Fatia média (170g)"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":126,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (2 Colher de arroz cheia (63g)"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Ovo \"poché\"","grams":100,"macros":{"energyKcal":149,"proteinG":12.4,"carbohydrateG":1.23,"fatG":9.99,"fiberG":0,"sodiumMg":122,"calciumMg":49,"ironMg":1.44,"potassiumMg":120},"measure":"2 Unidade"},{"food":"Outros legumes cozidos","grams":110,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"2 Colher De Arroz/Servir"},{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Azeite de oliva","grams":7,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de sopa (7,6ml)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Tapioca de goma","grams":45,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"3 colher de sopa (15g)"},{"food":"Queijo tipo mussarela","grams":26,"macros":{"energyKcal":281,"proteinG":19.4,"carbohydrateG":2.23,"fatG":21.6,"fiberG":0,"sodiumMg":373,"calciumMg":517,"ironMg":0.18,"potassiumMg":67.1},"measure":"2 Fatia (13,5g)"},{"food":"Orégano seco","grams":1,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.4,"fatG":10.3,"fiberG":15,"sodiumMg":14.7,"calciumMg":1576,"ironMg":44,"potassiumMg":1668},"measure":"1 Colher de chá (0,62g)"},{"food":"Suco de laranja","grams":240,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Medio"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Omelete simples","grams":195,"macros":{"energyKcal":171.44,"proteinG":11.72,"carbohydrateG":1.15,"fatG":12.97,"fiberG":0,"sodiumMg":1022.89,"calciumMg":46.5,"ironMg":1.35,"potassiumMg":113.61},"measure":"Unidade com 3 ovos"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Manjericão fresco","grams":3,"macros":{"energyKcal":27,"proteinG":2.54,"carbohydrateG":4.35,"fatG":0.61,"fiberG":2.52,"sodiumMg":4.01,"calciumMg":154,"ironMg":3.17,"potassiumMg":462},"measure":"1 5 folhas (3g)"},{"food":"Suco de maracujá","grams":240,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"1 Copo Medio"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Laranja","grams":180,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"1 Unidade média (180g)"},{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"}],"time":"23:00"}]},"dimensions":{"approaches":["vegetarian"],"objectives":[],"restrictions":["no_meat"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1800},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Ácido Úrico Elevado 1.400 Kcal","objective":"Cardápio clínico para controle de ácido úrico — adaptar à avaliação nutricional do paciente.","tags":["1400 kcal"],"snapshot":{"dietboxId":1325019,"originalName":"Dieta para Ácido Úrico Elevado 1.400 Kcal","kcalTotal":1395,"summary":{"energyKcal":1395.4,"proteinG":102.8,"carbohydrateG":178.1,"fatG":33.4,"fiberG":17.3,"sodiumMg":757.8,"calciumMg":1208.1,"ironMg":10.6,"potassiumMg":3150.5},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Copo Grande"},{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"1 Unidade (50g)"},{"food":"Queijo tipo minas","grams":30,"macros":{"energyKcal":243,"proteinG":18,"carbohydrateG":0,"fatG":19,"fiberG":0,"sodiumMg":0,"calciumMg":685,"ironMg":0.4,"potassiumMg":0},"measure":"1 Fatia (30g)"},{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia pequena (100g)"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Rúcula","grams":20,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"1 Pires (20g)"},{"food":"Filé-mignon Grelhado(a)/brasa/churrasco","grams":100,"macros":{"energyKcal":204,"proteinG":30.67,"carbohydrateG":0,"fatG":9,"fiberG":0,"sodiumMg":41,"calciumMg":7,"ironMg":2.53,"potassiumMg":252},"measure":"1 Bife"},{"food":"Batata","grams":150,"macros":{"energyKcal":111.74,"proteinG":1.71,"carbohydrateG":20.01,"fatG":3.01,"fiberG":2.05,"sodiumMg":5,"calciumMg":8,"ironMg":0.31,"potassiumMg":328},"measure":"não especificada) Refogado(a) (5 Colher De Sopa"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"},{"food":"Morango","grams":60,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"5 Unidade média (12g)"},{"food":"Torrada de qualquer pão","grams":8,"macros":{"energyKcal":377,"proteinG":10.5,"carbohydrateG":74.6,"fatG":3.3,"fiberG":3.4,"sodiumMg":829,"calciumMg":19,"ironMg":1.2,"potassiumMg":189},"measure":"1 Unidade"},{"food":"Geleia diet","grams":36,"macros":{"energyKcal":52.64,"proteinG":0.47,"carbohydrateG":12.72,"fatG":0.17,"fiberG":1.4,"sodiumMg":1.2,"calciumMg":11.05,"ironMg":0.23,"potassiumMg":85.44},"measure":"3 Ponta De Faca"}],"time":"15:30"},{"name":"Jantar","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Rúcula","grams":20,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"1 Pires (20g)"},{"food":"Arroz integral","grams":80,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"4 Colher De Sopa"},{"food":"Filé-mignon Assado(a)","grams":100,"macros":{"energyKcal":204,"proteinG":30.67,"carbohydrateG":0,"fatG":9,"fiberG":0,"sodiumMg":41,"calciumMg":7,"ironMg":2.53,"potassiumMg":252},"measure":"1 Bife"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["gout"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1400},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Alergia a Proteína do Leite 1.000 Kcal","objective":"Cardápio clínico para alergia alimentar — adaptar à avaliação nutricional do paciente.","tags":["1000 kcal"],"snapshot":{"dietboxId":1300154,"originalName":"Dieta para Alergia a Proteína do Leite 1.000 Kcal","kcalTotal":1029,"summary":{"energyKcal":1029.3,"proteinG":62.7,"carbohydrateG":151.2,"fatG":22.2,"fiberG":15.9,"sodiumMg":1083.5,"calciumMg":201.3,"ironMg":10.3,"potassiumMg":2134.2},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo"},{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"1 Unidade (50g)"},{"food":"Peito de peru","grams":32,"macros":{"energyKcal":140,"proteinG":30.19,"carbohydrateG":0,"fatG":1.18,"fiberG":0,"sodiumMg":56,"calciumMg":15,"ironMg":1.57,"potassiumMg":277},"measure":"1 Fatia"}],"time":"07:30"},{"name":"Colação","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"3 Colher De Sopa"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Bife grelhado de contra filé","grams":100,"macros":{"energyKcal":195,"proteinG":30.4,"carbohydrateG":0,"fatG":7.21,"fiberG":0,"sodiumMg":66,"calciumMg":11,"ironMg":3.37,"potassiumMg":403},"measure":"1 Unidade média (100g)"},{"food":"Beterraba","grams":16,"macros":{"energyKcal":43,"proteinG":1.62,"carbohydrateG":9.57,"fatG":0.17,"fiberG":2.8,"sodiumMg":78,"calciumMg":16,"ironMg":0.8,"potassiumMg":325},"measure":"crua) (1 Colher de sopa cheia ralada (16g)"},{"food":"Cenoura Cru(a)","grams":12,"macros":{"energyKcal":41,"proteinG":0.93,"carbohydrateG":9.58,"fatG":0.24,"fiberG":2.8,"sodiumMg":69,"calciumMg":33,"ironMg":0.3,"potassiumMg":320},"measure":"1 Colher De Sopa"},{"food":"Alface","grams":16,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Colher De Arroz/Servir"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Salada de frutas","grams":210,"macros":{"energyKcal":51.24,"proteinG":0.62,"carbohydrateG":13.31,"fatG":0.14,"fiberG":1.68,"sodiumMg":0.82,"calciumMg":15.88,"ironMg":0.16,"potassiumMg":154.02},"measure":"1 Copo De Requeijao"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Sopa de legumes, carne e macarrão","grams":234,"macros":{"energyKcal":66.57,"proteinG":3.56,"carbohydrateG":4.1,"fatG":4.03,"fiberG":0.57,"sodiumMg":218.07,"calciumMg":12.65,"ironMg":0.69,"potassiumMg":131.93},"measure":"3 Concha (78g)"},{"food":"Suco de melão","grams":150,"macros":{"energyKcal":31.79,"proteinG":0.65,"carbohydrateG":8,"fatG":0.16,"fiberG":0.42,"sodiumMg":1.06,"calciumMg":7.42,"ironMg":0.25,"potassiumMg":118.68},"measure":"1 Copo Americano"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Uva","grams":85,"macros":{"energyKcal":69,"proteinG":0.72,"carbohydrateG":18.1,"fatG":0.16,"fiberG":0.9,"sodiumMg":2,"calciumMg":10,"ironMg":0.36,"potassiumMg":191},"measure":"0,5 Cacho"}],"time":"22:30"}]},"dimensions":{"approaches":[],"objectives":["food_allergy"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Constipação","objective":"Cardápio clínico para conforto gastrointestinal — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":16643271,"originalName":"Dieta para Constipação","kcalTotal":1448,"summary":{"energyKcal":1447.7,"proteinG":99.2,"carbohydrateG":204.3,"fatG":34.8,"fiberG":43.2,"sodiumMg":719.1,"calciumMg":546.3,"ironMg":8.2,"potassiumMg":3536.6},"meals":[{"name":"Café da manhã","items":[{"food":"1 Fatia Média de Mamão","grams":30,"macros":{"energyKcal":45.34,"proteinG":0.82,"carbohydrateG":11.55,"fatG":0.12,"fiberG":1.81,"sodiumMg":3.26,"calciumMg":24.87,"ironMg":0.23,"potassiumMg":221.8},"measure":"sem casca"},{"food":"5 Ameixas Pretas Secas","grams":450,"macros":{"energyKcal":52.54,"proteinG":0.77,"carbohydrateG":13.85,"fatG":0,"fiberG":2.43,"sodiumMg":0,"calciumMg":5.72,"ironMg":0.1,"potassiumMg":134.05}},{"food":"Suco de 1 Laranja","grams":60,"macros":{"energyKcal":51.47,"proteinG":1.08,"carbohydrateG":12.86,"fatG":0.19,"fiberG":3.98,"sodiumMg":0.83,"calciumMg":51.08,"ironMg":0.15,"potassiumMg":172.52},"measure":"sem casca e sem semente"},{"food":"2 Colheres de Sopa de Iogurte","grams":30,"macros":{"energyKcal":51.49,"proteinG":4.06,"carbohydrateG":1.92,"fatG":3.04,"fiberG":0,"sodiumMg":51.62,"calciumMg":143.1,"ironMg":0,"potassiumMg":71.28}}],"time":"07:00","notes":"Essa é uma receita de coquetel laxativo.\n-5 ameixas pretas\n-Mamão sem casca (1 pedaço)\n-Laranja sem casca e sem semente (1 unidade)\n-Iogurte ou creme de leite-2 col. de sopa\n-Gelo picado (estimula o intestino)\n\nModo de fazer: \n1.Deixar as ameixas pretas de molho em 50ml de água na geladeira na noite anterior\n2.Liquidificar tudo e tomar pela manhã em jejum. \n"},{"name":"Colação","items":[{"food":"2 fatias de pão integral","grams":10,"macros":{"energyKcal":310.96,"proteinG":8.4,"carbohydrateG":61.45,"fatG":2.84,"fiberG":2.43,"sodiumMg":430.79,"calciumMg":51.62,"ironMg":2.27,"potassiumMg":91.17}},{"food":"1 ponta de faca de húmus","grams":10,"macros":{"energyKcal":316.15,"proteinG":17.53,"carbohydrateG":46.34,"fatG":7.68,"fiberG":9.54,"sodiumMg":4.06,"calciumMg":89.52,"ironMg":4.15,"potassiumMg":881.66}},{"food":"2 Folhas de Rúcula","grams":120,"macros":{"energyKcal":13.13,"proteinG":1.77,"carbohydrateG":2.22,"fatG":0.11,"fiberG":1.74,"sodiumMg":9.42,"calciumMg":116.56,"ironMg":0.94,"potassiumMg":233.4}}],"time":"10:00","notes":"1 copo de água"},{"name":"Almoço","items":[{"food":"3 Colheres de Sopa de Arroz Integral","grams":54,"macros":{"energyKcal":123.53,"proteinG":2.59,"carbohydrateG":25.81,"fatG":1,"fiberG":2.75,"sodiumMg":1.24,"calciumMg":5.2,"ironMg":0.26,"potassiumMg":75.15}},{"food":"2 Colheres de Sopa de Lentilha","grams":36,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9}},{"food":"2 fatias de abóbora cozidas","grams":72,"macros":{"energyKcal":48.04,"proteinG":1.44,"carbohydrateG":10.76,"fatG":0.73,"fiberG":2.46,"sodiumMg":1.45,"calciumMg":7.63,"ironMg":0.35,"potassiumMg":199.1}},{"food":"3 colheres de Sopa de Couve Manteiga Refogada","grams":54,"macros":{"energyKcal":90.34,"proteinG":1.67,"carbohydrateG":8.71,"fatG":6.59,"fiberG":5.74,"sodiumMg":11.45,"calciumMg":177.33,"ironMg":0.5,"potassiumMg":314.89}},{"food":"1/2 Cenoura Média","grams":34,"macros":{"energyKcal":31,"proteinG":1.12,"carbohydrateG":7.55,"fatG":0.21,"fiberG":2.98,"sodiumMg":11.1,"calciumMg":21.4,"ironMg":0.47,"potassiumMg":278}},{"food":"2 Folhas de Alface","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"poode ser rúcula também"},{"food":"1 Fatia de Peito de Frango sem pele refogado","grams":110,"macros":{"energyKcal":161,"proteinG":29.7,"carbohydrateG":0.74,"fatG":4.4,"fiberG":0.13,"sodiumMg":277,"calciumMg":11.3,"ironMg":0.63,"potassiumMg":387}},{"food":"2 Fatias de Beterraba cozidas","grams":24,"macros":{"energyKcal":32.15,"proteinG":1.29,"carbohydrateG":7.23,"fatG":0.09,"fiberG":1.88,"sodiumMg":22.76,"calciumMg":15.26,"ironMg":0.24,"potassiumMg":245.48}},{"food":"1 Fio de Azeite de Oliva","grams":2,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0}}],"time":"12:30","notes":"A abóbora e a couve podem ser cortadas em fatias finas e colocadas em uma frigideira com um fio de azeite de oliva, mas também podem ser colocadas na lentilha, junto com a cenoura."},{"name":"Jantar","items":[{"food":"3 Colheres de Sopa de Arroz Integral","grams":54,"macros":{"energyKcal":123.53,"proteinG":2.59,"carbohydrateG":25.81,"fatG":1,"fiberG":2.75,"sodiumMg":1.24,"calciumMg":5.2,"ironMg":0.26,"potassiumMg":75.15}},{"food":"2 Colheres de Sopa de Lentilha","grams":36,"macros":{"energyKcal":92.64,"proteinG":6.31,"carbohydrateG":16.3,"fatG":0.52,"fiberG":7.86,"sodiumMg":1.18,"calciumMg":16.1,"ironMg":1.48,"potassiumMg":219.9}},{"food":"2 fatias de abóbora cozidas","grams":72,"macros":{"energyKcal":48.04,"proteinG":1.44,"carbohydrateG":10.76,"fatG":0.73,"fiberG":2.46,"sodiumMg":1.45,"calciumMg":7.63,"ironMg":0.35,"potassiumMg":199.1}},{"food":"3 colheres de Sopa de Couve Manteiga Refogada","grams":54,"macros":{"energyKcal":90.34,"proteinG":1.67,"carbohydrateG":8.71,"fatG":6.59,"fiberG":5.74,"sodiumMg":11.45,"calciumMg":177.33,"ironMg":0.5,"potassiumMg":314.89}},{"food":"1/2 Cenoura Média","grams":34,"macros":{"energyKcal":31,"proteinG":1.12,"carbohydrateG":7.55,"fatG":0.21,"fiberG":2.98,"sodiumMg":11.1,"calciumMg":21.4,"ironMg":0.47,"potassiumMg":278}},{"food":"2 Folhas de Alface","grams":10,"macros":{"energyKcal":8.79,"proteinG":0.61,"carbohydrateG":1.75,"fatG":0.13,"fiberG":1.02,"sodiumMg":7.31,"calciumMg":14.44,"ironMg":0.27,"potassiumMg":136},"measure":"poode ser rúcula também"},{"food":"1 Fatia de Peito de Frango sem pele refogado","grams":110,"macros":{"energyKcal":161,"proteinG":29.7,"carbohydrateG":0.74,"fatG":4.4,"fiberG":0.13,"sodiumMg":277,"calciumMg":11.3,"ironMg":0.63,"potassiumMg":387}},{"food":"2 Fatias de Beterraba cozidas","grams":24,"macros":{"energyKcal":32.15,"proteinG":1.29,"carbohydrateG":7.23,"fatG":0.09,"fiberG":1.88,"sodiumMg":22.76,"calciumMg":15.26,"ironMg":0.24,"potassiumMg":245.48}}],"time":"18:30","notes":"A abóbora e a couve podem ser cortadas em fatias finas e colocadas em uma frigideira com um fio de azeite de oliva, mas também podem ser colocadas na lentilha, junto com a cenoura."},{"name":"Lanche da tarde","items":[{"food":"1 Unidade de Banana picada ou amassada","grams":60,"macros":{"energyKcal":112.37,"proteinG":1.48,"carbohydrateG":29.34,"fatG":0.21,"fiberG":1.95,"sodiumMg":0,"calciumMg":3.19,"ironMg":0.34,"potassiumMg":354.81}},{"food":"2 Colheres de Sopa de Farinha de Aveia","grams":30,"macros":{"energyKcal":370,"proteinG":14.9,"carbohydrateG":67,"fatG":7,"fiberG":10.3,"sodiumMg":4.59,"calciumMg":47.5,"ironMg":4.41,"potassiumMg":333},"measure":"pode ser em flocos também"},{"food":"1 Colher de Sopa de Pasta de Amendoim","grams":20,"macros":{"energyKcal":587,"proteinG":27.3,"carbohydrateG":20,"fatG":44,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0}}],"time":"15:30"},{"name":"Ceia","items":[{"food":"1 xícara de chá de camomila + 1 cápsula de simbiótico","grams":1,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0}}],"time":"20:30"}]},"dimensions":{"approaches":[],"objectives":["gastrointestinal"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1448},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Crianças 1.400 Kcal","objective":"Cardápio clínico para nutrição pediátrica — adaptar à avaliação nutricional do paciente.","tags":["1400 kcal"],"snapshot":{"dietboxId":1329750,"originalName":"Dieta para Crianças 1.400 Kcal","kcalTotal":1430,"summary":{"energyKcal":1430.3,"proteinG":103.6,"carbohydrateG":143.1,"fatG":51.9,"fiberG":20.2,"sodiumMg":3682.2,"calciumMg":1270.3,"ironMg":8.4,"potassiumMg":2984.6},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de melancia sem açúcar","grams":200,"macros":{"energyKcal":28.02,"proteinG":0.54,"carbohydrateG":6.3,"fatG":0.38,"fiberG":0.2,"sodiumMg":2.13,"calciumMg":7.26,"ironMg":0.15,"potassiumMg":101.57},"measure":"1 Copo médio (200ml)"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Queijo polenguinho","grams":20,"macros":{"energyKcal":349,"proteinG":7.55,"carbohydrateG":2.66,"fatG":34.87,"fiberG":0,"sodiumMg":296,"calciumMg":80,"ironMg":1.2,"potassiumMg":119},"measure":"1 Unidade"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Chicória Cru(a)","grams":90,"macros":{"energyKcal":17,"proteinG":1.25,"carbohydrateG":3.35,"fatG":0.2,"fiberG":3.1,"sodiumMg":22,"calciumMg":52,"ironMg":0.83,"potassiumMg":314},"measure":"2 Pegador"},{"food":"Brócolis","grams":26,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (2 Colher de sopa picado (13,23g)"},{"food":"Couve-flor","grams":50,"macros":{"energyKcal":23,"proteinG":1.85,"carbohydrateG":4.12,"fatG":0.45,"fiberG":1.73,"sodiumMg":15,"calciumMg":16,"ironMg":0.33,"potassiumMg":142},"measure":"cozida) (2 Colher de sopa cheia (picada) (25g)"},{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (3 Colher de sopa cheia (20g)"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé médio (140g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Iogurte desnatado","grams":150,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Copo Americano"},{"food":"Granola","grams":10,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"1 Colher De Sopa"},{"food":"Morango","grams":24,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"1 Colher de sopa picado (24g)"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Pão, sírio, trigo integral","grams":28,"macros":{"energyKcal":266,"proteinG":9.8,"carbohydrateG":55,"fatG":2.6,"fiberG":7.4,"sodiumMg":532,"calciumMg":15,"ironMg":3.06,"potassiumMg":170},"measure":"1 pão, pequeno (10.2 cm diâmetro)"},{"food":"Molho de tomate","grams":40,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43},"measure":"2 Colher de sopa (20g)"},{"food":"Queijo de minas","grams":135,"macros":{"energyKcal":240,"proteinG":17.6,"carbohydrateG":10.6,"fatG":14.1,"fiberG":0,"sodiumMg":1587,"calciumMg":529,"ironMg":0.2,"potassiumMg":330},"measure":"3 Fatias picadas"},{"food":"Manjericão fresco","grams":8,"macros":{"energyKcal":27,"proteinG":2.54,"carbohydrateG":4.35,"fatG":0.61,"fiberG":2.52,"sodiumMg":4.01,"calciumMg":154,"ironMg":3.17,"potassiumMg":462},"measure":"2 Colher de chá (4g)"},{"food":"Ovo de galinha Cozido(a) Picado","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"2 Unidade"},{"food":"Manga","grams":151,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":2.77,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156},"measure":"1 Xícara de chá (picada) (151,5g)"}],"time":"20:00","notes":"Pão + Molho + Queijo + Manjericão + Ovos  = Pizza Saudável"}]},"dimensions":{"approaches":[],"objectives":["pediatric"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1400},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Diabetes tipo 2 com 1.300 kcal","objective":"Cardápio clínico para controle glicêmico — adaptar à avaliação nutricional do paciente.","tags":["1300 kcal"],"snapshot":{"dietboxId":1265362,"originalName":"Dieta para Diabetes tipo 2 com 1.300 kcal","kcalTotal":1288,"summary":{"energyKcal":1288,"proteinG":81.7,"carbohydrateG":162.4,"fatG":37.7,"fiberG":24.7,"sodiumMg":969.1,"calciumMg":610.1,"ironMg":10.7,"potassiumMg":2794.1},"meals":[{"name":"Café da manhã","items":[{"food":"Chá Verde","grams":50,"macros":{"energyKcal":1,"proteinG":0,"carbohydrateG":0.3,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":0,"ironMg":0.02,"potassiumMg":37.03},"measure":"1 Xicara De Cafe"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Requeijão light","grams":30,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"1 Colher De Sopa"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"07:30"},{"name":"Colação","items":[{"food":"Pêssego","grams":60,"macros":{"energyKcal":43,"proteinG":0.7,"carbohydrateG":11.1,"fatG":0.09,"fiberG":1.8,"sodiumMg":0,"calciumMg":5,"ironMg":0.11,"potassiumMg":197},"measure":"1 Unidade média (60g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"3 Colher De Sopa"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Cenoura","grams":12,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (1 Colher de sopa ralada (12g)"},{"food":"Filé de frango","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"100 Grama"},{"food":"Laranja","grams":180,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"1 Unidade média (180g)"},{"food":"Tomate","grams":75,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"5 Fatia média (15g)"},{"food":"Agrião","grams":20,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"1 Prato sobremesa cheio picado (20g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"1 Pote"},{"food":"Morango","grams":48,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"4 Unidade média (12g)"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Macarrão  Molho vermelho","grams":100,"macros":{"energyKcal":103.73,"proteinG":3.5,"carbohydrateG":18.27,"fatG":1.92,"fiberG":1.46,"sodiumMg":225.72,"calciumMg":12.08,"ironMg":1.04,"potassiumMg":145.67},"measure":"4 Colher De Sopa"},{"food":"Carne moída","grams":75,"macros":{"energyKcal":214,"proteinG":26.62,"carbohydrateG":0,"fatG":11.1,"fiberG":0,"sodiumMg":61,"calciumMg":13,"ironMg":2.89,"potassiumMg":300},"measure":"3 Colher De Sopa"},{"food":"Rúcula","grams":30,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"1 Prato De Sobremesa (30g)"},{"food":"Cenoura","grams":24,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (2 Colher de sopa ralada (12g)"},{"food":"Escarola refogada","grams":25,"macros":{"energyKcal":224.4,"proteinG":2.49,"carbohydrateG":9.86,"fatG":20.49,"fiberG":3.84,"sodiumMg":32.64,"calciumMg":86.13,"ironMg":1.31,"potassiumMg":530.21},"measure":"1 Colher de sopa picada (25g)"},{"food":"Abacaxi","grams":75,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113},"measure":"1 Fatia média (75g)"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["glycemic_control"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1300},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Diabéticos 1.400 Kcal","objective":"Cardápio clínico para controle glicêmico — adaptar à avaliação nutricional do paciente.","tags":["1400 kcal"],"snapshot":{"dietboxId":1233822,"originalName":"Dieta para Diabéticos 1.400 Kcal","kcalTotal":1392,"summary":{"energyKcal":1392.4,"proteinG":106.6,"carbohydrateG":135,"fatG":47.2,"fiberG":12.9,"sodiumMg":1425.6,"calciumMg":679.6,"ironMg":9.7,"potassiumMg":1955.4},"meals":[{"name":"Café da manhã","items":[{"food":"Iogurte de qualquer sabor diet","grams":200,"macros":{"energyKcal":51.35,"proteinG":3.11,"carbohydrateG":3.88,"fatG":2.65,"fiberG":0.08,"sodiumMg":33.45,"calciumMg":66.71,"ironMg":0.06,"potassiumMg":85.59},"measure":"Pote: 1"},{"food":"Biscoito Água e Sal - São Luíz Nestlé®","grams":30,"macros":{"energyKcal":466,"proteinG":9.4,"carbohydrateG":68.3,"fatG":17.2,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Unidade: 6"},{"food":"Geleia diet","grams":72,"macros":{"energyKcal":52.64,"proteinG":0.47,"carbohydrateG":12.72,"fatG":0.17,"fiberG":1.4,"sodiumMg":1.2,"calciumMg":11.05,"ironMg":0.23,"potassiumMg":85.44},"measure":"Ponta De Faca: 6"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Mamão formosa","grams":170,"macros":{"energyKcal":32,"proteinG":0.5,"carbohydrateG":8.3,"fatG":0.1,"fiberG":0.6,"sodiumMg":0,"calciumMg":20,"ironMg":0.4,"potassiumMg":0},"measure":"Fatia média (170g): 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 3"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"}],"time":"12:00","notes":"Salada verde e tomate à vontade. "},{"name":"Lanche da tarde","items":[{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Copo Americano: 1"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 1"},{"food":"Queijo de minas light","grams":38,"macros":{"energyKcal":90,"proteinG":13.74,"carbohydrateG":3.63,"fatG":1.93,"fiberG":0,"sodiumMg":406,"calciumMg":69,"ironMg":0.16,"potassiumMg":96},"measure":"Fatia: 2"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":130.95,"proteinG":2.56,"carbohydrateG":25.56,"fatG":1.97,"fiberG":2.72,"sodiumMg":1.23,"calciumMg":5.15,"ironMg":0.26,"potassiumMg":74.42},"measure":"Colher De Sopa: 3"},{"food":"Carne bovina  Refogado(a)","grams":100,"macros":{"energyKcal":264.66,"proteinG":24.22,"carbohydrateG":0,"fatG":17.98,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"Bife: 1"},{"food":"Lentilha cozida","grams":60,"macros":{"energyKcal":116,"proteinG":9.03,"carbohydrateG":20.1,"fatG":0.38,"fiberG":4.55,"sodiumMg":2,"calciumMg":19,"ironMg":3.34,"potassiumMg":369},"measure":"grãos) (Concha (60g): 1"}],"time":"20:00","notes":"Salada verde e tomate à vontade."},{"name":"Ceia","items":[{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"Copo Americano: 1"},{"food":"Biscoito doce diet","grams":20,"macros":{"energyKcal":453.92,"proteinG":6.22,"carbohydrateG":65.74,"fatG":21.89,"fiberG":2.95,"sodiumMg":407.53,"calciumMg":51.03,"ironMg":2.75,"potassiumMg":91.9},"measure":"Unidade: 4"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["glycemic_control"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1400},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Diverticulite - Fase de Remissão","objective":"Cardápio clínico para conforto gastrointestinal — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":19507544,"originalName":"Dieta para Diverticulite - Fase de Remissão","kcalTotal":1510,"summary":{"energyKcal":1510.2,"proteinG":116.5,"carbohydrateG":181.1,"fatG":38.2,"fiberG":22.7,"sodiumMg":971.8,"calciumMg":260.2,"ironMg":11,"potassiumMg":2622.8},"meals":[{"name":"Café da manhã","items":[{"food":"Cuscuz de milho","grams":90,"macros":{"energyKcal":243.88,"proteinG":4.54,"carbohydrateG":49.84,"fatG":3.53,"fiberG":3.46,"sodiumMg":63.06,"calciumMg":1.67,"ironMg":1.42,"potassiumMg":36.65},"measure":"Grama: 90"},{"food":"Ovo de galinha Cozido/Mexido","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Maçã com casca","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Peito de galinha ou frango Assado(a)","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Bife: 1"},{"food":"Batata doce cozida sem sal","grams":150,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Grama: 150"},{"food":"Alface, americana, crua","grams":32,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Colher de sopa cheia: 4"},{"food":"Tomate cereja","grams":50,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Unidade (10g): 5"},{"food":"Abóbora Assado(a)","grams":150,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230},"measure":"Grama: 150"},{"food":"Pepino, c/ casca, cru","grams":72,"macros":{"energyKcal":10,"proteinG":0.7,"carbohydrateG":2.23,"fatG":0.09,"fiberG":1.04,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.23,"potassiumMg":153},"measure":"Colher de sopa cheia: 4"},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"Colher de chá (2,4ml): 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Pão integral - Wickbold®","grams":50,"macros":{"energyKcal":236,"proteinG":8.6,"carbohydrateG":46,"fatG":2,"fiberG":6.4,"sodiumMg":468,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (25g): 2"},{"food":"Atum ao natural em água e sal - Coqueiro®","grams":85,"macros":{"energyKcal":115.5,"proteinG":25.8,"carbohydrateG":1.7,"fatG":0.6,"fiberG":0,"sodiumMg":209.1,"calciumMg":17.1,"ironMg":2.5,"potassiumMg":0},"measure":"Grama: 85"},{"food":"Castanha de caju, crua, s/ sal","grams":15,"macros":{"energyKcal":582,"proteinG":18.2,"carbohydrateG":30.2,"fatG":43.8,"fiberG":3.3,"sodiumMg":12,"calciumMg":37,"ironMg":6.68,"potassiumMg":660},"measure":"Grama: 15"},{"food":"Melancia","grams":200,"macros":{"energyKcal":32,"proteinG":0.62,"carbohydrateG":7.19,"fatG":0.43,"fiberG":0.23,"sodiumMg":2,"calciumMg":8,"ironMg":0.17,"potassiumMg":116},"measure":"Fatia média (200g): 1"}],"time":"17:30"},{"name":"Jantar","items":[{"food":"Peixe de água doce","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)   (Grama: 120"},{"food":"Arroz integral","grams":100,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 100"},{"food":"Brócolis","grams":100,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 100"},{"food":"Couve-flor","grams":80,"macros":{"energyKcal":23,"proteinG":1.85,"carbohydrateG":4.12,"fatG":0.45,"fiberG":1.73,"sodiumMg":15,"calciumMg":16,"ironMg":0.33,"potassiumMg":142},"measure":"cozida) (Grama: 80"},{"food":"Azeite de oliva","grams":5,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sobremesa: 1"}],"time":"20:00"}]},"dimensions":{"approaches":[],"objectives":["gastrointestinal"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1510},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Doença de Crohn 1.600 Kcal","objective":"Cardápio clínico para conforto gastrointestinal — adaptar à avaliação nutricional do paciente.","tags":["1600 kcal"],"snapshot":{"dietboxId":1266955,"originalName":"Dieta para Doença de Crohn 1.600 Kcal","kcalTotal":1599,"summary":{"energyKcal":1599.1,"proteinG":94.6,"carbohydrateG":198.1,"fatG":49,"fiberG":22.5,"sodiumMg":1592.6,"calciumMg":257.7,"ironMg":11.4,"potassiumMg":2969},"meals":[{"name":"Café da manhã","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"2 Colher De Sopa"}],"time":"07:30","notes":"Tomar um copo de água 15 min antes da refeição"},{"name":"Almoço","items":[{"food":"Aipim Cozido(a)","grams":120,"macros":{"energyKcal":125,"proteinG":0.6,"carbohydrateG":30.1,"fatG":0.3,"fiberG":1.6,"sodiumMg":1,"calciumMg":19,"ironMg":0.1,"potassiumMg":100},"measure":"2 Colher De Arroz/Servir"},{"food":"Caldo-de-feijão","grams":300,"macros":{"energyKcal":75.5,"proteinG":4.78,"carbohydrateG":10.33,"fatG":1.77,"fiberG":2.2,"sodiumMg":401.39,"calciumMg":33.67,"ironMg":1.35,"potassiumMg":221.4},"measure":"1 Cumbuca"},{"food":"Carne bovina Grelhado(a)/brasa/churrasco","grams":100,"macros":{"energyKcal":242,"proteinG":24.22,"carbohydrateG":0,"fatG":15.42,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"1 Bife"},{"food":"Cenoura Cozido(a)","grams":75,"macros":{"energyKcal":35,"proteinG":0.76,"carbohydrateG":8.22,"fatG":0.18,"fiberG":3,"sodiumMg":58,"calciumMg":30,"ironMg":0.34,"potassiumMg":235},"measure":"3 Colher De Sopa"}],"time":"12:30","notes":"Tomar um copo de água 30 min antes e 30 min após a refeição"},{"name":"Lanche da tarde","items":[{"food":"Pão de forma tradicional","grams":50,"macros":{"energyKcal":339.4,"proteinG":9.63,"carbohydrateG":68.81,"fatG":3.03,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"2 Fatia (25g)"},{"food":"Geleia diet","grams":48,"macros":{"energyKcal":52.64,"proteinG":0.47,"carbohydrateG":12.72,"fatG":0.17,"fiberG":1.4,"sodiumMg":1.2,"calciumMg":11.05,"ironMg":0.23,"potassiumMg":85.44},"measure":"4 Ponta De Faca"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Batata, inglesa, cozida","grams":75,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"3 colher de sopa cheia"},{"food":"Peixe, salmão grelhado","grams":154,"macros":{"energyKcal":231,"proteinG":25.72,"carbohydrateG":0,"fatG":13.38,"fiberG":0,"sodiumMg":60,"calciumMg":28,"ironMg":0.91,"potassiumMg":505},"measure":"1 filé"},{"food":"Brócolis","grams":13,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (1 Colher de sopa picado (13,23g)"},{"food":"Couve-flor","grams":25,"macros":{"energyKcal":23,"proteinG":1.85,"carbohydrateG":4.12,"fatG":0.45,"fiberG":1.73,"sodiumMg":15,"calciumMg":16,"ironMg":0.33,"potassiumMg":142},"measure":"cozida) (1 Colher de sopa cheia (picada) (25g)"},{"food":"Vagem","grams":20,"macros":{"energyKcal":35,"proteinG":1.9,"carbohydrateG":7.9,"fatG":0.28,"fiberG":3.2,"sodiumMg":3,"calciumMg":46,"ironMg":1.28,"potassiumMg":299},"measure":"cozida) (1 Colher de sopa (20g)"}],"time":"20:30","notes":"Tomar um copo de água 30 min antes e 30 min após a refeição"},{"name":"Colação","items":[{"food":"Biscoito, salgado, cream cracker","grams":20,"macros":{"energyKcal":431.73,"proteinG":10.06,"carbohydrateG":68.73,"fatG":14.44,"fiberG":2.51,"sodiumMg":854.36,"calciumMg":20,"ironMg":2.2,"potassiumMg":180.61},"measure":"4 Unidade (5g)"}],"time":"10:00"},{"name":"Ceia","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["gastrointestinal"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1600},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Gestante Primeiro Trimestre 1.200 Kcal","objective":"Cardápio clínico para gestação — adaptar à avaliação nutricional do paciente.","tags":["1200 kcal"],"snapshot":{"dietboxId":1326954,"originalName":"Dieta para Gestante Primeiro Trimestre 1.200 Kcal","kcalTotal":1185,"summary":{"energyKcal":1184.8,"proteinG":68.4,"carbohydrateG":178.6,"fatG":25.7,"fiberG":21.2,"sodiumMg":1414.4,"calciumMg":691.4,"ironMg":10.8,"potassiumMg":3293.1},"meals":[{"name":"Café da manhã","items":[{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia média (170g)"},{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"1 Unidade (50g)"},{"food":"Requeijão","grams":8,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"1 Colher De Cha"},{"food":"Leite de soja - PADRÃO","grams":165,"macros":{"energyKcal":33,"proteinG":2.76,"carbohydrateG":1.82,"fatG":1.92,"fiberG":1.31,"sodiumMg":12,"calciumMg":4,"ironMg":0.58,"potassiumMg":141},"measure":"1 Copo pequeno cheio (165ml)"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Morango","grams":96,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"8 Unidade média (12g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":40,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (2 Colher de sopa cheia (20g)"},{"food":"Feijão cozido","grams":52,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (2 Colher de sopa (26,2g)"},{"food":"Sobrecoxa de frango sem pele assada","grams":65,"macros":{"energyKcal":201.44,"proteinG":24.82,"carbohydrateG":0.38,"fatG":10.42,"fiberG":0.06,"sodiumMg":506.91,"calciumMg":12.96,"ironMg":1.27,"potassiumMg":233.73},"measure":"1 Unidade média (65g)"},{"food":"Abóbora Cozido(a)","grams":100,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230},"measure":"1 Escumadeira"},{"food":"Alface","grams":50,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Prato Raso"},{"food":"Tomate","grams":60,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"4 Fatia média (15g)"},{"food":"Cebola","grams":10,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"1 Colher de sopa cheia (picada) (10g)"},{"food":"Rabanete","grams":33,"macros":{"energyKcal":17,"proteinG":0.6,"carbohydrateG":3.6,"fatG":0.54,"fiberG":1,"sodiumMg":24,"calciumMg":21,"ironMg":0.29,"potassiumMg":232},"measure":"cru) (1 Colher de servir (fatias com casca) (33g)"},{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"1 Copo Americano"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":40,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (2 Colher de sopa cheia (20g)"},{"food":"Sobrecoxa de frango sem pele assada","grams":65,"macros":{"energyKcal":201.44,"proteinG":24.82,"carbohydrateG":0.38,"fatG":10.42,"fiberG":0.06,"sodiumMg":506.91,"calciumMg":12.96,"ironMg":1.27,"potassiumMg":233.73},"measure":"1 Unidade média (65g)"},{"food":"Abóbora Cozido(a)","grams":100,"macros":{"energyKcal":20,"proteinG":0.72,"carbohydrateG":4.9,"fatG":0.07,"fiberG":1.1,"sodiumMg":1,"calciumMg":15,"ironMg":0.57,"potassiumMg":230},"measure":"1 Escumadeira"},{"food":"Alface","grams":50,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Prato Raso"},{"food":"Tomate","grams":60,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"4 Fatia média (15g)"},{"food":"Cebola","grams":10,"macros":{"energyKcal":38,"proteinG":1.17,"carbohydrateG":8.64,"fatG":0.16,"fiberG":1.68,"sodiumMg":3,"calciumMg":20,"ironMg":0.22,"potassiumMg":157},"measure":"1 Colher de sopa cheia (picada) (10g)"},{"food":"Rabanete","grams":33,"macros":{"energyKcal":17,"proteinG":0.6,"carbohydrateG":3.6,"fatG":0.54,"fiberG":1,"sodiumMg":24,"calciumMg":21,"ironMg":0.29,"potassiumMg":232},"measure":"cru) (1 Colher de servir (fatias com casca) (33g)"},{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Americano"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"},{"food":"Granola","grams":10,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"1 Colher De Sopa"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["gestational"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Gestante Segundo Trimestre 1.600 Kcal","objective":"Cardápio clínico para gestação — adaptar à avaliação nutricional do paciente.","tags":["1600 kcal"],"snapshot":{"dietboxId":1326989,"originalName":"Dieta para Gestante Segundo Trimestre 1.600 Kcal","kcalTotal":1593,"summary":{"energyKcal":1592.5,"proteinG":99.1,"carbohydrateG":184.6,"fatG":56.5,"fiberG":26.2,"sodiumMg":2844.8,"calciumMg":1236.7,"ironMg":11.2,"potassiumMg":3848.6},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Queijo de minas","grams":90,"macros":{"energyKcal":240,"proteinG":17.6,"carbohydrateG":10.6,"fatG":14.1,"fiberG":0,"sodiumMg":1587,"calciumMg":529,"ironMg":0.2,"potassiumMg":330},"measure":"2 Fatia"},{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia média (170g)"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Salada de frutas","grams":210,"macros":{"energyKcal":51.24,"proteinG":0.62,"carbohydrateG":13.31,"fatG":0.14,"fiberG":1.68,"sodiumMg":0.82,"calciumMg":15.88,"ironMg":0.16,"potassiumMg":154.02},"measure":"1 Copo Medio"},{"food":"Nozes","grams":25,"macros":{"energyKcal":651,"proteinG":14.8,"carbohydrateG":18.5,"fatG":64,"fiberG":2.1,"sodiumMg":0,"calciumMg":99,"ironMg":3.1,"potassiumMg":0},"measure":"1 Colher de sopa moída (25g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (4 Colher de sopa cheia (20g)"},{"food":"Fígado bovino","grams":79,"macros":{"energyKcal":211.4,"proteinG":25.79,"carbohydrateG":8.16,"fatG":7.71,"fiberG":0.04,"sodiumMg":802.84,"calciumMg":118.54,"ironMg":6.08,"potassiumMg":357.48},"measure":"cozido) (1 Unidade (79,8g)"},{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Brócolis","grams":26,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (2 Colher de sopa picado (13,23g)"},{"food":"Cenoura","grams":24,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (2 Colher de sopa ralada (12g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Abacate","grams":80,"macros":{"energyKcal":161,"proteinG":1.99,"carbohydrateG":7.4,"fatG":15.3,"fiberG":4.1,"sodiumMg":10,"calciumMg":11,"ironMg":1.03,"potassiumMg":599},"measure":"4 Colher de sopa cheia (amassado) (20g)"},{"food":"Limão","grams":10,"macros":{"energyKcal":25,"proteinG":0.38,"carbohydrateG":8.64,"fatG":0.13,"fiberG":0.4,"sodiumMg":1,"calciumMg":7,"ironMg":0.03,"potassiumMg":124},"measure":"suco) (10 Mililitro (1ml)"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Filé de peixe Grelhado(a)/brasa/churrasco","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"1 File"},{"food":"Batata, inglesa, cozida","grams":100,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"4 colher de sopa cheia"},{"food":"Outros legumes cozidos","grams":120,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"4 Colher De Sopa"},{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Castanha do Pará sem sal","grams":4,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"1 Unidade (4g)"},{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["gestational"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1600},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Gestante Terceiro Trimestre 2.000 Kcal","objective":"Cardápio clínico para gestação — adaptar à avaliação nutricional do paciente.","tags":["2000 kcal"],"snapshot":{"dietboxId":1329651,"originalName":"Dieta para Gestante Terceiro Trimestre 2.000 Kcal","kcalTotal":2015,"summary":{"energyKcal":2014.6,"proteinG":122.5,"carbohydrateG":254.8,"fatG":57.7,"fiberG":23.5,"sodiumMg":2040.2,"calciumMg":1069.6,"ironMg":15.5,"potassiumMg":3459.1},"meals":[{"name":"Café da manhã","items":[{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Manteiga com ou sem sal","grams":15,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"3 Ponta De Faca"},{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia média (170g)"},{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"07:00","notes":"Mamão + Leite + Aveia = Vitamina de Mamão"},{"name":"Colação","items":[{"food":"Iogurte desnatado","grams":200,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Pote"},{"food":"Morango","grams":60,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"5 Unidade média (12g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Repolho branco","grams":36,"macros":{"energyKcal":25,"proteinG":1.45,"carbohydrateG":5.44,"fatG":0.27,"fiberG":2.03,"sodiumMg":18,"calciumMg":47,"ironMg":0.59,"potassiumMg":246},"measure":"cru) (2 Colher de sopa cheia picado (18g)"},{"food":"Brócolis","grams":26,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (2 Colher de sopa picado (13,23g)"},{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (3 Colher de sopa cheia (20g)"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé médio (140g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Bolo branco simples","grams":120,"macros":{"energyKcal":317.82,"proteinG":5.94,"carbohydrateG":55.21,"fatG":8.36,"fiberG":1.39,"sodiumMg":26.29,"calciumMg":32.62,"ironMg":1.85,"potassiumMg":103.14},"measure":"2 Fatia média (60g)"},{"food":"Limonada sem açúcar","grams":165,"macros":{"energyKcal":5,"proteinG":0.08,"carbohydrateG":1.73,"fatG":0.01,"fiberG":0.08,"sodiumMg":2.6,"calciumMg":3,"ironMg":0.01,"potassiumMg":24.81},"measure":"1 Copo pequeno cheio (165ml)"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":45,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"3 Fatia média (15g)"},{"food":"Macarrão","grams":220,"macros":{"energyKcal":158,"proteinG":5.8,"carbohydrateG":30.86,"fatG":0.93,"fiberG":1.8,"sodiumMg":1,"calciumMg":7,"ironMg":1.28,"potassiumMg":44},"measure":"2 Pegador"},{"food":"Molho de tomate","grams":60,"macros":{"energyKcal":39.47,"proteinG":0.93,"carbohydrateG":5.27,"fatG":2.08,"fiberG":1.16,"sodiumMg":325.6,"calciumMg":9.79,"ironMg":0.52,"potassiumMg":214.43},"measure":"3 Colher de sopa (20g)"},{"food":"Medalhão de filé mingon","grams":100,"macros":{"energyKcal":264.23,"proteinG":24.95,"carbohydrateG":0.06,"fatG":17.64,"fiberG":0,"sodiumMg":482.33,"calciumMg":8.34,"ironMg":3.16,"potassiumMg":371.44},"measure":"1 medalhão"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"},{"food":"Canela em pó","grams":4,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"2 Colher de chá (2g)"}],"time":"23:30"}]},"dimensions":{"approaches":[],"objectives":["gestational"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}}]$data$::jsonb) loop
    insert into public.plan_templates (organization_id, name, objective, tags, snapshot, created_by, scope, dimensions, rules)
    values (target_organization_id, model->>'name', model->>'objective', (select array(select jsonb_array_elements_text(model->'tags'))), model->'snapshot', actor, 'organization', model->'dimensions', model->'rules')
    on conflict (organization_id, (snapshot->>'dietboxId')) where snapshot ? 'dietboxId' do update set
      name = excluded.name, objective = excluded.objective, tags = excluded.tags, snapshot = excluded.snapshot,
      dimensions = excluded.dimensions, rules = excluded.rules, updated_at = now();
  end loop;

  for model in select jsonb_array_elements($data$[{"name":"Dieta para Hipercolesterolemia 1.200 Kcal","objective":"Cardápio clínico para controle lipídico — adaptar à avaliação nutricional do paciente.","tags":["1200 kcal"],"snapshot":{"dietboxId":1265395,"originalName":"Dieta para Hipercolesterolemia 1.200 Kcal","kcalTotal":1221,"summary":{"energyKcal":1220.6,"proteinG":71.1,"carbohydrateG":171.7,"fatG":32.5,"fiberG":26.2,"sodiumMg":1217.5,"calciumMg":677.9,"ironMg":11.8,"potassiumMg":2792.6},"meals":[{"name":"Café da manhã","items":[{"food":"Leite, de vaca, desnatado, UHT","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"1 Copo Cheio (200ml)"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"3 Colher De Sopa"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Requeijão light","grams":12,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"2 Ponta De Faca"},{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"}],"time":"07:00","notes":"Leite + Banana + Aveia = Batida de Banana"},{"name":"Colação","items":[{"food":"Melão","grams":90,"macros":{"energyKcal":32,"proteinG":0.62,"carbohydrateG":7.19,"fatG":0.43,"fiberG":0.23,"sodiumMg":2,"calciumMg":8,"ironMg":0.17,"potassiumMg":116},"measure":"1 Fatia média (90g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Escarola","grams":153,"macros":{"energyKcal":17,"proteinG":1.26,"carbohydrateG":3.36,"fatG":0.2,"fiberG":2.07,"sodiumMg":22,"calciumMg":52,"ironMg":0.83,"potassiumMg":314},"measure":"1 Xícara de chá (153g)"},{"food":"Arroz integral","grams":29.5,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Meia Escumadeira média cheia (59g)"},{"food":"Feijão cozido","grams":43,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Meia Concha"},{"food":"Frango em pedaços Cozido(a)","grams":40,"macros":{"energyKcal":239,"proteinG":27.3,"carbohydrateG":0,"fatG":13.6,"fiberG":0,"sodiumMg":82,"calciumMg":15,"ironMg":1.26,"potassiumMg":223},"measure":"1 Escumadeira"},{"food":"Espinafre Refogado(a)","grams":50,"macros":{"energyKcal":45.3,"proteinG":2.97,"carbohydrateG":3.75,"fatG":2.78,"fiberG":2.4,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"2 Colher De Sopa"},{"food":"Abacaxi","grams":50,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113},"measure":"1 Fatia pequena (50g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Mel","grams":21,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"1 colher de sopa"},{"food":"Castanha do Pará sem sal","grams":12,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"3 Unidade (4g)"}],"time":"16:30","notes":"Passar o mel no pão integral, que pode estar torrado."},{"name":"Jantar","items":[{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"1 Filé pequeno (100g)"},{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (3 Colher de sopa cheia (20g)"},{"food":"Brócolis","grams":39,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (3 Colher de sopa picado (13,23g)"},{"food":"Agrião","grams":20,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"1 Prato sobremesa cheio picado (20g)"},{"food":"Tomate","grams":75,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"5 Fatia média (15g)"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Manga","grams":60,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":1.76,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156},"measure":"1 Unidade Pequena"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["dyslipidemia"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertensão","objective":"Cardápio clínico para controle pressórico — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":1238703,"originalName":"Dieta para Hipertensão","kcalTotal":1848,"summary":{"energyKcal":1847.8,"proteinG":158.9,"carbohydrateG":180.1,"fatG":55.5,"fiberG":27.5,"sodiumMg":1309.9,"calciumMg":869.5,"ironMg":8.7,"potassiumMg":4415.3},"meals":[{"name":"Café da manhã","items":[{"food":"Iogurte desnatado","grams":150,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Copo Americano: 1"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"},{"food":"Castanha do Pará sem sal","grams":12,"macros":{"energyKcal":656,"proteinG":14.3,"carbohydrateG":12.8,"fatG":66.2,"fiberG":5.93,"sodiumMg":2,"calciumMg":176,"ironMg":3.41,"potassiumMg":600},"measure":"Unidade (4g): 3"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"},{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 4"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Concha (86g): 1"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 3"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Vitamina de abacate","grams":300,"macros":{"energyKcal":100.19,"proteinG":2.74,"carbohydrateG":12.8,"fatG":4.64,"fiberG":1.34,"sodiumMg":27.95,"calciumMg":80.07,"ironMg":0.06,"potassiumMg":182.22},"measure":"Copo Grande: 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Peixe, salmão, coho, selvagem, assado, grelhado","grams":356,"macros":{"energyKcal":139,"proteinG":23.45,"carbohydrateG":0,"fatG":4.3,"fiberG":0,"sodiumMg":58,"calciumMg":45,"ironMg":0.61,"potassiumMg":434},"measure":"filé: 1"},{"food":"Batata doce cozida sem sal","grams":84,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Colher de sopa cheia (picada) (42g): 2"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 3"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"},{"food":"Linhaça, semente","grams":12,"macros":{"energyKcal":495.1,"proteinG":14.08,"carbohydrateG":43.31,"fatG":32.25,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211.5,"ironMg":4.7,"potassiumMg":869.29},"measure":"Colher De Chá: 3"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["hypertension"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1848},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertrigliceridemia","objective":"Cardápio clínico para controle lipídico — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":19507538,"originalName":"Dieta para Hipertrigliceridemia","kcalTotal":1570,"summary":{"energyKcal":1569.6,"proteinG":118,"carbohydrateG":159.6,"fatG":53.9,"fiberG":26.3,"sodiumMg":2741.3,"calciumMg":764.9,"ironMg":9.7,"potassiumMg":3067.9},"meals":[{"name":"Café da manhã","items":[{"food":"Uva itália","grams":120,"macros":{"energyKcal":71,"proteinG":0.66,"carbohydrateG":17.8,"fatG":0.58,"fiberG":0.6,"sodiumMg":2,"calciumMg":11,"ironMg":0.26,"potassiumMg":185},"measure":"Grama: 120"},{"food":"Iogurte desnatado","grams":170,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"Grama: 170"},{"food":"Aveia em Flocos Finos ou Psyllium - 30g","grams":30,"macros":{"energyKcal":350,"proteinG":13.33,"carbohydrateG":60,"fatG":8,"fiberG":8.33,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0}},{"food":"Whey Protein Concentrado DUX - Morango","grams":20,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":200,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"},{"food":"Ômega 3 – EPA DHA Vitafor","grams":1,"macros":{"energyKcal":900,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 1"}],"time":"08:00","notes":"Adicionar Cacau e Canela em pó - 1 colher de chá de cada"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":100,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Grama: 100"},{"food":"Feijão, carioca, cozido","grams":80,"macros":{"energyKcal":76.42,"proteinG":4.78,"carbohydrateG":13.59,"fatG":0.54,"fiberG":8.51,"sodiumMg":1.76,"calciumMg":26.59,"ironMg":1.29,"potassiumMg":254.62},"measure":"Concha Média Rasa: 1"},{"food":"Peixe de água doce","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.)   (Grama: 120"},{"food":"Brócolis","grams":80,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"cozido) (Grama: 80"},{"food":"Cenoura","grams":30,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Grama: 30"},{"food":"Tomate orgânico","grams":45,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Rodela: 3"},{"food":"Alface orgânica","grams":40,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Folha: 4"},{"food":"Rúcula, crua","grams":20,"macros":{"energyKcal":17,"proteinG":2.48,"carbohydrateG":2.72,"fatG":0.12,"fiberG":2.43,"sodiumMg":6.71,"calciumMg":107,"ironMg":1.02,"potassiumMg":298},"measure":"Grama: 20"},{"food":"Azeite de oliva","grams":8,"macros":{"energyKcal":887.81,"proteinG":0,"carbohydrateG":0,"fatG":100.43,"fiberG":0,"sodiumMg":2.01,"calciumMg":1,"ironMg":0.56,"potassiumMg":1},"measure":"Colher De Sopa: 1"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Peito de frango desfiado - 50g","grams":50,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247}},{"food":"Pão integral - Wickbold®","grams":50,"macros":{"energyKcal":236,"proteinG":8.6,"carbohydrateG":46,"fatG":2,"fiberG":6.4,"sodiumMg":468,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (25g): 2"},{"food":"Queijo minas frescal","grams":30,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 1"},{"food":"Tomate orgânico","grams":30,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Rodela: 2"},{"food":"Alface orgânica","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Folha: 2"},{"food":"Banana","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.)  (Unidade: 1"}],"time":"17:00","notes":"Sanduíche"},{"name":"Jantar","items":[{"food":"Omelete simples - 3 ovos: 2 inteiros e 1 clara","grams":195,"macros":{"energyKcal":171.44,"proteinG":11.72,"carbohydrateG":1.15,"fatG":12.97,"fiberG":0,"sodiumMg":1022.89,"calciumMg":46.5,"ironMg":1.35,"potassiumMg":113.61}},{"food":"Rúcula","grams":24,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"Folha (6g): 4"},{"food":"Orégano seco","grams":3,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.4,"fatG":10.3,"fiberG":15,"sodiumMg":14.7,"calciumMg":1576,"ironMg":44,"potassiumMg":1668},"measure":"Grama: 3"},{"food":"Manjericão fresco","grams":3,"macros":{"energyKcal":27,"proteinG":2.54,"carbohydrateG":4.35,"fatG":0.61,"fiberG":2.52,"sodiumMg":4.01,"calciumMg":154,"ironMg":3.17,"potassiumMg":462},"measure":"5 folhas (3g): 1"},{"food":"Laranja","grams":180,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.75,"fatG":0.12,"fiberG":2.35,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"pera, seleta, lima, da terra, etc.)  (Unidade: 1"},{"food":"Ômega 3 – EPA DHA Vitafor","grams":1,"macros":{"energyKcal":900,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 1"}],"time":"20:30"}]},"dimensions":{"approaches":[],"objectives":["dyslipidemia"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1570},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertrofia 2.500 Kcal","objective":"Cardápio clínico para hipertrofia — adaptar à avaliação nutricional do paciente.","tags":["2500 kcal"],"snapshot":{"dietboxId":19865634,"originalName":"Dieta para Hipertrofia 2.500 Kcal","kcalTotal":2511,"summary":{"energyKcal":2510.6,"proteinG":154.3,"carbohydrateG":335.3,"fatG":60.6,"fiberG":31.1,"sodiumMg":1604.9,"calciumMg":822.2,"ironMg":17.2,"potassiumMg":4009.1},"meals":[{"name":"Desjejum","items":[{"food":"Farinha de tapioca","grams":64,"macros":{"energyKcal":331,"proteinG":0.5,"carbohydrateG":81.1,"fatG":0.3,"fiberG":0.6,"sodiumMg":2,"calciumMg":12,"ironMg":0.1,"potassiumMg":48},"measure":"Colher De Sopa: 4"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Muçarela","grams":40,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 2"}],"time":"08:00","notes":"Sugestão: Duas crepiocas com queijo"},{"name":"Almoço","items":[{"food":"Batata doce cozida sem sal","grams":300,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Grama: 300"},{"food":"Feijão, preto, cozido","grams":140,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Concha Média Cheia (140g): 1"},{"food":"Peixe não especificado","grams":180,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (Grama: 180"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"12:00","notes":"Como orientação a respeito dos vegetais e legumes, percebe-se que será difícil atingir quantidades significativas com relação as calorias oriundas deste, a ponto de prejudicar a dieta. Portando, sugiro uma mistura que vise 200-250g totais entre vegetais e legumes, sem distinção entre eles. "},{"name":"Lanche da tarde","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote: 1"},{"food":"Whey Protein","grams":15,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Arroz branco","grams":300,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Concha média cheia (100g): 3"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 150"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Suco de uva integral","grams":200,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"Copo médio (200ml): 1"}],"time":"19:30","notes":"Vegetais e legumes: orientação semelhante ao almoço. "},{"name":"Ceia","items":[{"food":"Mamão","grams":340,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia: 2"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"}],"time":"21:30"}]},"dimensions":{"approaches":[],"objectives":["hypertrophy"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertrofia 2.800 Kcal","objective":"Cardápio clínico para hipertrofia — adaptar à avaliação nutricional do paciente.","tags":["2800 kcal"],"snapshot":{"dietboxId":19865939,"originalName":"Dieta para Hipertrofia 2.800 Kcal","kcalTotal":2781,"summary":{"energyKcal":2780.7,"proteinG":167.8,"carbohydrateG":358.9,"fatG":77,"fiberG":30.2,"sodiumMg":1628.1,"calciumMg":993.6,"ironMg":20.1,"potassiumMg":3132.7},"meals":[{"name":"Desjejum","items":[{"food":"Farinha de tapioca","grams":64,"macros":{"energyKcal":331,"proteinG":0.5,"carbohydrateG":81.1,"fatG":0.3,"fiberG":0.6,"sodiumMg":2,"calciumMg":12,"ironMg":0.1,"potassiumMg":48},"measure":"Colher De Sopa: 4"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Muçarela","grams":40,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 2"},{"food":"Suco de uva integral","grams":200,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"Copo médio (200ml): 1"}],"time":"08:00","notes":"Sugestão: Duas crepiocas com queijo"},{"name":"Almoço","items":[{"food":"Arroz branco","grams":300,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Concha média cheia (100g): 3"},{"food":"Feijão, preto, cozido","grams":140,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Concha Média Cheia (140g): 1"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":120,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 120"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"12:00","notes":"Como orientação a respeito dos vegetais e legumes, percebe-se que será difícil atingir quantidades significativas com relação as calorias oriundas deste, a ponto de prejudicar a dieta. Portando, sugiro uma mistura que vise 200-250g totais entre vegetais e legumes, sem distinção entre eles. "},{"name":"Lanche da tarde","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote: 1"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"},{"food":"Mel","grams":15,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher De Sopa: 1"},{"food":"Granola","grams":39,"macros":{"energyKcal":487,"proteinG":12.3,"carbohydrateG":55.5,"fatG":27.2,"fiberG":10.5,"sodiumMg":10,"calciumMg":62,"ironMg":3.98,"potassiumMg":502},"measure":"Colher de sopa (13g): 3"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Macarrão, trigo integral, cozido","grams":250,"macros":{"energyKcal":124,"proteinG":5.33,"carbohydrateG":26.54,"fatG":0.54,"fiberG":2.8,"sodiumMg":3,"calciumMg":15,"ironMg":1.06,"potassiumMg":44},"measure":"Grama: 250"},{"food":"Peixe não especificado","grams":180,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (Grama: 180"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Suco de laranja","grams":200,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Garrafa (200 Ml): 1"}],"time":"19:30","notes":"Vegetais e legumes: orientação semelhante ao almoço. "},{"name":"Ceia","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote: 1"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"},{"food":"Whey Protein","grams":20,"macros":{"energyKcal":400,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":2.1,"sodiumMg":178.6,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 20"}],"time":"21:30"}]},"dimensions":{"approaches":[],"objectives":["hypertrophy"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2800},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertrofia 3.000 Kcal","objective":"Cardápio clínico para hipertrofia — adaptar à avaliação nutricional do paciente.","tags":["3000 kcal"],"snapshot":{"dietboxId":19866112,"originalName":"Dieta para Hipertrofia 3.000 Kcal","kcalTotal":3036,"summary":{"energyKcal":3036.1,"proteinG":172.6,"carbohydrateG":375.2,"fatG":104.1,"fiberG":47.4,"sodiumMg":694.9,"calciumMg":578,"ironMg":19.8,"potassiumMg":4486.9},"meals":[{"name":"Desjejum","items":[{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"},{"food":"Banana","grams":150,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 2"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Mel","grams":30,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher de sopa (15g): 2"}],"time":"08:00","notes":"Sugestão: Duas panquecas de banana com mel"},{"name":"Almoço","items":[{"food":"Batata doce cozida sem sal","grams":270,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Fatia grande (90g): 3"},{"food":"Feijão, preto, cozido","grams":140,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Concha Média Cheia (140g): 1"},{"food":"Carne bovina Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":242,"proteinG":24.22,"carbohydrateG":0,"fatG":15.42,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"Grama: 150"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"}],"time":"12:00","notes":"Como orientação a respeito dos vegetais e legumes, percebe-se que será difícil atingir quantidades significativas com relação as calorias oriundas deste, a ponto de prejudicar a dieta. Portando, sugiro uma mistura que vise 200-250g totais entre vegetais e legumes, sem distinção entre eles. "},{"name":"Lanche da tarde","items":[{"food":"Leite longa vida integral","grams":200,"macros":{"energyKcal":62,"proteinG":3.1,"carbohydrateG":4.9,"fatG":3.2,"fiberG":0,"sodiumMg":0,"calciumMg":120,"ironMg":0,"potassiumMg":0},"measure":"Copo de requeijão (200ml): 1"},{"food":"Whey Protein","grams":30,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 30"},{"food":"Banana","grams":150,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 2"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 3"}],"time":"16:00","notes":"Sugestão: vitamina com todos os ingredientes. "},{"name":"Jantar","items":[{"food":"Macarrão, trigo integral, cozido","grams":250,"macros":{"energyKcal":124,"proteinG":5.33,"carbohydrateG":26.54,"fatG":0.54,"fiberG":2.8,"sodiumMg":3,"calciumMg":15,"ironMg":1.06,"potassiumMg":44},"measure":"Grama: 250"},{"food":"Peixe não especificado","grams":180,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"inteiro, em posta, em filé, etc.) Grelhado(a)/brasa/churrasco (Grama: 180"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Chocolate, meio amargo","grams":30,"macros":{"energyKcal":474.92,"proteinG":4.86,"carbohydrateG":62.42,"fatG":29.86,"fiberG":4.94,"sodiumMg":8.87,"calciumMg":44.67,"ironMg":3.61,"potassiumMg":431.7},"measure":"Grama: 30"}],"time":"19:30","notes":"Vegetais e legumes: orientação semelhante ao almoço. "},{"name":"Ceia","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"},{"food":"Pasta de amendoim","grams":30,"macros":{"energyKcal":588,"proteinG":25.09,"carbohydrateG":19.56,"fatG":50.39,"fiberG":6,"sodiumMg":459,"calciumMg":43,"ironMg":1.87,"potassiumMg":649},"measure":"Grama: 30"},{"food":"Granola","grams":39,"macros":{"energyKcal":487,"proteinG":12.3,"carbohydrateG":55.5,"fatG":27.2,"fiberG":10.5,"sodiumMg":10,"calciumMg":62,"ironMg":3.98,"potassiumMg":502},"measure":"Colher de sopa (13g): 3"}],"time":"21:30"}]},"dimensions":{"approaches":[],"objectives":["hypertrophy"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":3000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertrofia 3.200 Kcal","objective":"Cardápio clínico para hipertrofia — adaptar à avaliação nutricional do paciente.","tags":["3200 kcal"],"snapshot":{"dietboxId":19866264,"originalName":"Dieta para Hipertrofia 3.200 Kcal","kcalTotal":3149,"summary":{"energyKcal":3149.2,"proteinG":180.9,"carbohydrateG":394.5,"fatG":97.7,"fiberG":44.2,"sodiumMg":1708.8,"calciumMg":821.2,"ironMg":26.7,"potassiumMg":3752.9},"meals":[{"name":"Desjejum","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"},{"food":"Aveia em flocos","grams":45,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 3"},{"food":"Leite longa vida integral","grams":200,"macros":{"energyKcal":62,"proteinG":3.1,"carbohydrateG":4.9,"fatG":3.2,"fiberG":0,"sodiumMg":0,"calciumMg":120,"ironMg":0,"potassiumMg":0},"measure":"Copo de requeijão (200ml): 1"},{"food":"Whey Protein","grams":15,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Mel","grams":15,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher de sopa (15g): 1"}],"time":"08:00","notes":"Sugestão: vitamina com todos os ingredientes. "},{"name":"Almoço","items":[{"food":"Arroz branco","grams":300,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Concha média cheia (100g): 3"},{"food":"Feijão, preto, cozido","grams":140,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Concha Média Cheia (140g): 1"},{"food":"Carne bovina Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":242,"proteinG":24.22,"carbohydrateG":0,"fatG":15.42,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"Grama: 150"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Suco de laranja","grams":200,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Garrafa (200 Ml): 1"}],"time":"12:00","notes":"Como orientação a respeito dos vegetais e legumes, percebe-se que será difícil atingir quantidades significativas com relação as calorias oriundas deste, a ponto de prejudicar a dieta. Portando, sugiro uma mistura que vise 200-250g totais entre vegetais e legumes, sem distinção entre eles. "},{"name":"Lanche da tarde","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Requeijão","grams":15,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sobremesa: 1"},{"food":"Muçarela","grams":20,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 1"},{"food":"Pêra","grams":120,"macros":{"energyKcal":59,"proteinG":0.39,"carbohydrateG":15.1,"fatG":0.4,"fiberG":2.4,"sodiumMg":0,"calciumMg":11,"ironMg":0.25,"potassiumMg":125},"measure":"unidade: 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Macarrão, trigo integral, cozido","grams":300,"macros":{"energyKcal":124,"proteinG":5.33,"carbohydrateG":26.54,"fatG":0.54,"fiberG":2.8,"sodiumMg":3,"calciumMg":15,"ironMg":1.06,"potassiumMg":44},"measure":"Grama: 300"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 150"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Suco de uva integral","grams":200,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"Copo médio (200ml): 1"}],"time":"19:30","notes":"Vegetais e legumes: orientação semelhante ao almoço. "},{"name":"Ceia","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Queijo minas frescal","grams":30,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 1"},{"food":"Mamão","grams":340,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia: 2"}],"time":"21:30"}]},"dimensions":{"approaches":[],"objectives":["hypertrophy"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":3200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Hipertrofia 3.500 Kcal","objective":"Cardápio clínico para hipertrofia — adaptar à avaliação nutricional do paciente.","tags":["3500 kcal"],"snapshot":{"dietboxId":19866445,"originalName":"Dieta para Hipertrofia 3.500 Kcal","kcalTotal":3534,"summary":{"energyKcal":3534,"proteinG":194.5,"carbohydrateG":434.8,"fatG":116.1,"fiberG":39.9,"sodiumMg":1874.2,"calciumMg":916.7,"ironMg":25.7,"potassiumMg":4928},"meals":[{"name":"Desjejum","items":[{"food":"Farinha de tapioca","grams":64,"macros":{"energyKcal":331,"proteinG":0.5,"carbohydrateG":81.1,"fatG":0.3,"fiberG":0.6,"sodiumMg":2,"calciumMg":12,"ironMg":0.1,"potassiumMg":48},"measure":"Colher De Sopa: 4"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Muçarela","grams":40,"macros":{"energyKcal":318,"proteinG":21.6,"carbohydrateG":2.47,"fatG":24.64,"fiberG":0,"sodiumMg":415,"calciumMg":575,"ironMg":0.2,"potassiumMg":75},"measure":"Fatia: 2"},{"food":"Suco de laranja","grams":200,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Garrafa (200 Ml): 1"}],"time":"08:00","notes":"Sugestão: Duas crepiocas com queijo"},{"name":"Almoço","items":[{"food":"Batata doce cozida sem sal","grams":300,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Grama: 300"},{"food":"Feijão, preto, cozido","grams":140,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"Concha Média Cheia (140g): 1"},{"food":"Carne bovina Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":242,"proteinG":24.22,"carbohydrateG":0,"fatG":15.42,"fiberG":0,"sodiumMg":67,"calciumMg":8,"ironMg":2.81,"potassiumMg":337},"measure":"Grama: 150"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Suco de laranja","grams":200,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Garrafa (200 Ml): 1"}],"time":"12:00","notes":"Como orientação a respeito dos vegetais e legumes, percebe-se que será difícil atingir quantidades significativas com relação as calorias oriundas deste, a ponto de prejudicar a dieta. Portando, sugiro uma mistura que vise 200-250g totais entre vegetais e legumes, sem distinção entre eles. "},{"name":"Lanche da tarde","items":[{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Banana","grams":150,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 2"},{"food":"Aveia em flocos","grams":30,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sopa: 2"},{"food":"Whey Protein","grams":30,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 30"}],"time":"16:00","notes":"Sugestão: Duas panquecas de banana com whey"},{"name":"Jantar","items":[{"food":"Arroz branco","grams":300,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (Concha média cheia (100g): 3"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":150,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 150"},{"food":"Azeite, de oliva, extra virgem","grams":8,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de Sopa (8g): 1"},{"food":"Suco de uva integral","grams":200,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"Copo médio (200ml): 1"}],"time":"19:30","notes":"Vegetais e legumes: orientação semelhante ao almoço. "},{"name":"Ceia","items":[{"food":"Mamão","grams":340,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.81,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"Fatia: 2"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média (75g): 1"},{"food":"Pasta de amendoim","grams":30,"macros":{"energyKcal":588,"proteinG":25.09,"carbohydrateG":19.56,"fatG":50.39,"fiberG":6,"sodiumMg":459,"calciumMg":43,"ironMg":1.87,"potassiumMg":649},"measure":"Grama: 30"}],"time":"21:30"},{"name":"Lanche da manhã","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Pote: 1"},{"food":"Whey Protein","grams":15,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 15"},{"food":"Granola","grams":26,"macros":{"energyKcal":487,"proteinG":12.3,"carbohydrateG":55.5,"fatG":27.2,"fiberG":10.5,"sodiumMg":10,"calciumMg":62,"ironMg":3.98,"potassiumMg":502},"measure":"Colher de sopa (13g): 2"}],"time":"10:00"}]},"dimensions":{"approaches":[],"objectives":["hypertrophy"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":3500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Idosos com Dificuldade de Deglutição 1.600 Kcal","objective":"Cardápio clínico para nutrição do idoso e dificuldade de deglutição — adaptar à avaliação nutricional do paciente.","tags":["1600 kcal"],"snapshot":{"dietboxId":1329833,"originalName":"Dieta para Idosos com Dificuldade de Deglutição 1.600 Kcal","kcalTotal":1633,"summary":{"energyKcal":1632.6,"proteinG":93.6,"carbohydrateG":237.6,"fatG":36.8,"fiberG":18.6,"sodiumMg":1782.7,"calciumMg":1312.8,"ironMg":13.2,"potassiumMg":4191.5},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"},{"food":"Mucilon","grams":37,"macros":{"energyKcal":78.24,"proteinG":2.42,"carbohydrateG":10.46,"fatG":3.06,"fiberG":0.17,"sodiumMg":319.33,"calciumMg":124.57,"ironMg":0.22,"potassiumMg":156.85},"measure":"1 Colher De Sopa"},{"food":"Pão Francês","grams":50,"macros":{"energyKcal":285.6,"proteinG":9.42,"carbohydrateG":56.8,"fatG":2.55,"fiberG":2.8,"sodiumMg":580,"calciumMg":111,"ironMg":3.08,"potassiumMg":94.2},"measure":"1 Unidade (50g)"},{"food":"Manteiga com ou sem sal","grams":15,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"3 Ponta De Faca"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Banana Amassada","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"},{"food":"Canela em pó","grams":4,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"2 Colher de chá (2g)"},{"food":"Chá","grams":300,"macros":{"energyKcal":1,"proteinG":0,"carbohydrateG":0.3,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":0,"ironMg":0.02,"potassiumMg":37.03},"measure":"preto, camomila, erva-cidreira, capim limão, etc.)  (1 Caneca"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Purê de batata","grams":160,"macros":{"energyKcal":115.16,"proteinG":1.81,"carbohydrateG":17.76,"fatG":4.36,"fiberG":1.78,"sodiumMg":138.26,"calciumMg":18.21,"ironMg":0.27,"potassiumMg":298.44},"measure":"2 Colher De Arroz/Servir"},{"food":"Caldo-de-feijão","grams":130,"macros":{"energyKcal":75.5,"proteinG":4.78,"carbohydrateG":10.33,"fatG":1.77,"fiberG":2.2,"sodiumMg":401.39,"calciumMg":33.67,"ironMg":1.35,"potassiumMg":221.4},"measure":"1 Concha"},{"food":"Carne moída","grams":60,"macros":{"energyKcal":214,"proteinG":26.62,"carbohydrateG":0,"fatG":11.1,"fiberG":0,"sodiumMg":61,"calciumMg":13,"ironMg":2.89,"potassiumMg":300},"measure":"1 Colher De Arroz/Servir"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Mamão papaia","grams":200,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"2 Fatia pequena (100g)"},{"food":"Leite de vaca desnatado","grams":240,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Copo Medio"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"}],"time":"16:30","notes":"Vitamina de Mamão - bem grossa para evitar aspiração"},{"name":"Jantar","items":[{"food":"Peixe","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"em filé)  Grelhado(a) (1 File"},{"food":"Batata, inglesa, cozida","grams":70,"macros":{"energyKcal":51.59,"proteinG":1.16,"carbohydrateG":11.94,"fatG":0,"fiberG":1.34,"sodiumMg":2.29,"calciumMg":3.52,"ironMg":0.19,"potassiumMg":161.33},"measure":"1 Unidade Média"},{"food":"Outros legumes cozidos","grams":60,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"2 Colher De Sopa"},{"food":"Suco de uva integral - Superbom®","grams":200,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"1 Copo médio (200ml)"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Iogurte desnatado de frutas - PADRÃO","grams":200,"macros":{"energyKcal":102,"proteinG":4.38,"carbohydrateG":19.1,"fatG":1.09,"fiberG":0.1,"sodiumMg":58.4,"calciumMg":152,"ironMg":0.07,"potassiumMg":195},"measure":"1 Copo (200g)"}],"time":"22:00"}]},"dimensions":{"approaches":[],"objectives":["elderly","swallowing"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1600},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Insuficiência Renal (1.000 kcal)","objective":"Cardápio clínico para terapia nutricional renal — adaptar à avaliação nutricional do paciente.","tags":["1000 kcal"],"snapshot":{"dietboxId":14237505,"originalName":"Dieta para Insuficiência Renal (1.000 kcal)","kcalTotal":1020,"summary":{"energyKcal":1020.2,"proteinG":61.6,"carbohydrateG":149.4,"fatG":22.9,"fiberG":21.4,"sodiumMg":820.6,"calciumMg":337.3,"ironMg":6.9,"potassiumMg":2000.9},"meals":[{"name":"Café da manhã","items":[{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Geleia 100% fruta: 10 Gramas","grams":10,"macros":{"energyKcal":155,"proteinG":0,"carbohydrateG":37.5,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0}},{"food":"Ricota - 1 Fatia","grams":50,"macros":{"energyKcal":174,"proteinG":11.3,"carbohydrateG":3.05,"fatG":13,"fiberG":0,"sodiumMg":84.1,"calciumMg":207,"ironMg":0.38,"potassiumMg":105},"measure":"50g"},{"food":"Manga - 2 fatias","grams":44,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":1.76,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156}}],"time":"07:00","notes":"Pão integral c/ geleia e ricota + manga."},{"name":"Colação","items":[{"food":"Maçã - 2 und. pequenas","grams":180,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107}}],"time":"10:00","notes":"Frutas com baixo teor de potássio: Abacaxi, Acerola, Ameixa fresca, Banana maçã, Caju, Caqui, Jabuticaba, Laranja lima, Lima da pérsia, Limão, Maçã, Manga, Melancia, Morango;\nPêra\nPêssego\nPitanga\n"},{"name":"Almoço","items":[{"food":"Alface - à vontade","grams":32,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Repolho - 2 colheres de servir","grams":90,"macros":{"energyKcal":23,"proteinG":1.27,"carbohydrateG":5.51,"fatG":0.06,"fiberG":1.9,"sodiumMg":8,"calciumMg":48,"ironMg":0.17,"potassiumMg":196}},{"food":"Cenoura","grams":30,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) - 2 Colher de sopa rasa (picada) (15g"},{"food":"Arroz branco","grams":90,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (3 Colher de arroz rasa (30g)"},{"food":"Peito de frango - 1 pedaço pequeno","grams":60,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"60g"},{"food":"Azeite de oliva extra virgem - 1 col. sobremesa","grams":5,"macros":{"energyKcal":720,"proteinG":0,"carbohydrateG":0,"fatG":80,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":1,"potassiumMg":0}},{"food":"Ameixa fresca - 1 unidade","grams":90,"macros":{"energyKcal":52.54,"proteinG":0.77,"carbohydrateG":13.85,"fatG":0,"fiberG":2.43,"sodiumMg":0,"calciumMg":5.72,"ironMg":0.1,"potassiumMg":134.05},"measure":"sobremesa"}],"time":"12:30","notes":"Legumes com baixo teor de potássio (se cozidos em água fervente e desprezando a água da fervura): Abóbora, Abobrinha, Acelga, Batata, Berinjela, Beterraba, Brócolis, Chuchu, Couve-flor, Couve-manteiga, Espinafre, Quiabo, Vagem"},{"name":"Lanche da tarde","items":[{"food":"Maçã - 1 und. pequena","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107}},{"food":"Abacaxi - 1 fatia média","grams":75,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113}},{"food":"Canela em pó - 1 col. café","grams":1,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500}}],"time":"16:00","notes":"Maçã e abacaxi assados com canela."},{"name":"Jantar","items":[{"food":"Alface - a vontade","grams":48,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194}},{"food":"Brócolis picado - 1 col. de servir","grams":27,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.07,"fatG":0.35,"fiberG":3,"sodiumMg":26,"calciumMg":46,"ironMg":0.84,"potassiumMg":292},"measure":"desprezar água do cozimento"},{"food":"Cenoura cozida - 2 col. sopa cheias","grams":50,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227}},{"food":"Arroz - 4 col. de sopa rasas","grams":60,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51}},{"food":"Filé de peixe assado - 1 posta","grams":100,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"100g"},{"food":"Pimentão amarelo","grams":48,"macros":{"energyKcal":27,"proteinG":1.01,"carbohydrateG":6.33,"fatG":0.21,"fiberG":2.3,"sodiumMg":2,"calciumMg":11,"ironMg":0.46,"potassiumMg":212},"measure":"cru) - 2 Colheres de sopa (picado"},{"food":"Azeite de oliva extravirgem - 1 col. sobremesa","grams":5,"macros":{"energyKcal":720,"proteinG":0,"carbohydrateG":0,"fatG":80,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":1,"potassiumMg":0}}],"time":"19:00","notes":"Temperar o peixe com pouco sal. Utilizar o pimentão, e demais ervas frescas para conferir sabor."}]},"dimensions":{"approaches":[],"objectives":["renal"],"restrictions":["renal"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Insuficiência Renal 1.200 kcal","objective":"Cardápio clínico para terapia nutricional renal — adaptar à avaliação nutricional do paciente.","tags":["1200 kcal"],"snapshot":{"dietboxId":1289756,"originalName":"Dieta para Insuficiência Renal 1.200 kcal","kcalTotal":1174,"summary":{"energyKcal":1174.4,"proteinG":49.4,"carbohydrateG":172.3,"fatG":34.3,"fiberG":21.3,"sodiumMg":1288.3,"calciumMg":969.4,"ironMg":7.8,"potassiumMg":2740.3},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":150,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Copo Americano"},{"food":"Abacate, cru","grams":9,"macros":{"energyKcal":96.15,"proteinG":1.24,"carbohydrateG":6.03,"fatG":8.4,"fiberG":6.31,"sodiumMg":0,"calciumMg":7.92,"ironMg":0.21,"potassiumMg":206.26},"measure":"1 Colher De Sopa"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Margarina vegetal cremosa sem sal - Doriana®","grams":13,"macros":{"energyKcal":750,"proteinG":0.1,"carbohydrateG":0.1,"fatG":82,"fiberG":0,"sodiumMg":120,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"1 Colher de sobremesa rasa (13g)"}],"time":"07:00","notes":"Leite + Abacate = Batida"},{"name":"Colação","items":[{"food":"Mamão, Papaia, cru","grams":5,"macros":{"energyKcal":40.16,"proteinG":0.46,"carbohydrateG":10.44,"fatG":0.12,"fiberG":1.04,"sodiumMg":1.63,"calciumMg":22.42,"ironMg":0.19,"potassiumMg":126.15},"measure":"1 Fatia"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz branco","grams":90,"macros":{"energyKcal":124.69,"proteinG":2.32,"carbohydrateG":25.47,"fatG":1.18,"fiberG":0.49,"sodiumMg":275.87,"calciumMg":12.43,"ironMg":1.37,"potassiumMg":45.51},"measure":"cozido) (3 Colher de arroz rasa (30g)"},{"food":"Feijão cozido","grams":86,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (1 Concha (86g)"},{"food":"Outros legumes cozidos","grams":110,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"2 Colher De Arroz/Servir"},{"food":"Semente de linhaça","grams":3,"macros":{"energyKcal":534,"proteinG":18.29,"carbohydrateG":28.88,"fatG":42.16,"fiberG":27.3,"sodiumMg":30,"calciumMg":255,"ironMg":5.73,"potassiumMg":813},"measure":"1 Colher De Sobremesa"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Salada de frutas","grams":150,"macros":{"energyKcal":51.24,"proteinG":0.62,"carbohydrateG":13.31,"fatG":0.14,"fiberG":1.68,"sodiumMg":0.82,"calciumMg":15.88,"ironMg":0.16,"potassiumMg":154.02},"measure":"1 Copo Americano"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"2 Fatia"},{"food":"Alface","grams":32,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"2 Escumadeira"},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"2 Fatia média (15g)"},{"food":"Ovo de galinha Cozido(a)","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"2 Unidade"},{"food":"Requeijão light","grams":24,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"4 Ponta De Faca"},{"food":"Banana","grams":150,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"2 Unidade média (75g)"},{"food":"Leite, de vaca, desnatado, UHT","grams":165,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":51.14,"calciumMg":133.81,"ironMg":0,"potassiumMg":140.03},"measure":"1 Copo Pequeno Cheio (165ml)"}],"time":"20:00","notes":"Leite + Banana = Vitamina\nOutros ingredientes = Sanduiche Vegetariano"},{"name":"Ceia","items":[{"food":"Iogurte desnatado","grams":150,"macros":{"energyKcal":56,"proteinG":5.73,"carbohydrateG":7.68,"fatG":0.18,"fiberG":0,"sodiumMg":77,"calciumMg":199,"ironMg":0.09,"potassiumMg":255},"measure":"1 Copo Americano"},{"food":"Granola","grams":20,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"2 Colher De Sopa"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["renal"],"restrictions":["renal"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Introdução Alimentar de Bebês - 1 ano","objective":"Cardápio clínico para nutrição pediátrica — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":1329705,"originalName":"Dieta para Introdução Alimentar de Bebês - 1 ano","kcalTotal":0,"summary":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"meals":[{"name":"Café da manhã","items":[],"time":"07:30"},{"name":"Colação","items":[],"time":"10:30"},{"name":"Almoço","items":[],"time":"12:30"},{"name":"Lanche da tarde","items":[],"time":"16:00"},{"name":"Jantar","items":[],"time":"20:00"},{"name":"Ceia","items":[],"time":"22:30"}]},"dimensions":{"approaches":[],"objectives":["pediatric"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":0},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Introdução Alimentar de Bebês - 6 meses","objective":"Cardápio clínico para nutrição pediátrica — adaptar à avaliação nutricional do paciente.","tags":[],"snapshot":{"dietboxId":1329684,"originalName":"Dieta para Introdução Alimentar de Bebês - 6 meses","kcalTotal":0,"summary":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"meals":[{"name":"Café da manhã","items":[],"time":"07:30"},{"name":"Colação","items":[],"time":"10:30"},{"name":"Almoço","items":[],"time":"12:30"},{"name":"Lanche da tarde","items":[],"time":"16:00"},{"name":"Jantar","items":[],"time":"20:00"},{"name":"Ceia","items":[],"time":"22:30"}]},"dimensions":{"approaches":[],"objectives":["pediatric"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":0},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Meia Idade Saudável 1.500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal"],"snapshot":{"dietboxId":20036552,"originalName":"Dieta para Meia Idade Saudável 1.500 Kcal","kcalTotal":1591,"summary":{"energyKcal":1590.6,"proteinG":114.9,"carbohydrateG":179.9,"fatG":45.1,"fiberG":15,"sodiumMg":1468.5,"calciumMg":755.9,"ironMg":11.3,"potassiumMg":3348.7},"meals":[{"name":"Café da manhã","items":[{"food":"Iogurte integral natural - PADRÃO","grams":200,"macros":{"energyKcal":61.4,"proteinG":3.48,"carbohydrateG":4.67,"fatG":3.26,"fiberG":0,"sodiumMg":46.4,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"Copo (200g): 1"},{"food":"Fruta","grams":75,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Unidade: 1"},{"food":"Aveia em flocos","grams":10,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Grama: 10"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Bebida, café, c/ leite","grams":240,"macros":{"energyKcal":37,"proteinG":1.82,"carbohydrateG":3.7,"fatG":1.65,"fiberG":0,"sodiumMg":32.4,"calciumMg":55.2,"ironMg":0.04,"potassiumMg":144},"measure":"meio a meio), s/ açúcar (Copo duplo americano: 1"},{"food":"Torrada integral - Bauducco®","grams":10,"macros":{"energyKcal":366.66,"proteinG":13.33,"carbohydrateG":73.33,"fatG":3.33,"fiberG":6.66,"sodiumMg":416.67,"calciumMg":0,"ironMg":30.33,"potassiumMg":0},"measure":"Unidade (10g): 1"},{"food":"Polenguinho - Polengui®","grams":20,"macros":{"energyKcal":300,"proteinG":10,"carbohydrateG":0,"fatG":25,"fiberG":0,"sodiumMg":850,"calciumMg":295,"ironMg":0,"potassiumMg":0},"measure":"Unidade (20g): 1"}],"time":"09:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 3"},{"food":"Feijão cozido","grams":26,"macros":{"energyKcal":61,"proteinG":3.34,"carbohydrateG":8.3,"fatG":1.6,"fiberG":4.2,"sodiumMg":191.4,"calciumMg":18.15,"ironMg":1.03,"potassiumMg":185.9},"measure":"50% grão/caldo) (Colher de sopa (26,2g): 1"},{"food":"Peixe, peixe branco, várias espécies, assado, grelhado","grams":154,"macros":{"energyKcal":172,"proteinG":24.47,"carbohydrateG":0,"fatG":7.51,"fiberG":0,"sodiumMg":65,"calciumMg":33,"ironMg":0.47,"potassiumMg":406},"measure":"filé: 1"},{"food":"Salada ou verdura crua, exceto de fruta","grams":45,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Colher De Sopa: 3"},{"food":"Salada, de legumes, cozida no vapor","grams":32,"macros":{"energyKcal":35.41,"proteinG":2.01,"carbohydrateG":7.09,"fatG":0.31,"fiberG":2.51,"sodiumMg":2.51,"calciumMg":32.9,"ironMg":0.44,"potassiumMg":244.3},"measure":"Colher de Sopa: 2"},{"food":"Chá com limão - Ice Tea Lipton®","grams":200,"macros":{"energyKcal":36,"proteinG":0,"carbohydrateG":8.8,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Copo de requeijão (200ml): 1"}],"time":"12:00"},{"name":"Lanche da tarde ","items":[{"food":"Tapioca de goma","grams":50,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Unidade: 1"},{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco (Grama: 20) Desfiado","grams":20,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247}},{"food":"Requeijão light","grams":15,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sobremesa: 1"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Batata-doce Cozido(a)","grams":266,"macros":{"energyKcal":76,"proteinG":1.37,"carbohydrateG":17.72,"fatG":0.14,"fiberG":2.5,"sodiumMg":27,"calciumMg":27,"ironMg":0.72,"potassiumMg":230},"measure":"1 Unidade Pequena"},{"food":"Quinoa","grams":15,"macros":{"energyKcal":135.47,"proteinG":4.37,"carbohydrateG":19.83,"fatG":4.33,"fiberG":2.16,"sodiumMg":4.27,"calciumMg":16.57,"ironMg":1.41,"potassiumMg":174.05},"measure":"3 Colher De Sopa"},{"food":"Filé de frango grelhado","grams":140,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé médio (140g): 1"},{"food":"Agrião Ao vinagrete","grams":38,"macros":{"energyKcal":11,"proteinG":2.3,"carbohydrateG":1.29,"fatG":0.1,"fiberG":0.5,"sodiumMg":316.36,"calciumMg":120.17,"ironMg":0.2,"potassiumMg":330.06},"measure":"1 Porcao"},{"food":"Pepino, cru","grams":18,"macros":{"energyKcal":9.53,"proteinG":0.87,"carbohydrateG":2.04,"fatG":0,"fiberG":1.12,"sodiumMg":0,"calciumMg":9.62,"ironMg":0.15,"potassiumMg":153.69},"measure":"1 Colher De Sopa Cheia"},{"food":"Espinafre","grams":50,"macros":{"energyKcal":23,"proteinG":2.98,"carbohydrateG":3.76,"fatG":0.26,"fiberG":2.3,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"cozido) (2 Colher de sopa cheia (25g)"},{"food":"Azeite de oliva","grams":2,"macros":{"energyKcal":884,"proteinG":0,"carbohydrateG":0,"fatG":100,"fiberG":0,"sodiumMg":0.4,"calciumMg":0.18,"ironMg":0.38,"potassiumMg":0},"measure":"1 Colher de chá (2,4ml)"},{"food":"Limão, cravo, suco","grams":50,"macros":{"energyKcal":14.1,"proteinG":0.33,"carbohydrateG":5.25,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":10.18,"ironMg":0.08,"potassiumMg":119.88},"measure":"1  Copo Limonada"}],"time":"20:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Meia Idade Saudável 2.000 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["2000 kcal"],"snapshot":{"dietboxId":20004998,"originalName":"Dieta para Meia Idade Saudável 2.000 Kcal","kcalTotal":1987,"summary":{"energyKcal":1986.8,"proteinG":115.2,"carbohydrateG":269,"fatG":53.1,"fiberG":37.6,"sodiumMg":1575.1,"calciumMg":760.1,"ironMg":16.8,"potassiumMg":3088.2},"meals":[{"name":"Café da manhã","items":[{"food":"Meio Mamão, Papaia, cru","grams":300,"macros":{"energyKcal":40.16,"proteinG":0.46,"carbohydrateG":10.44,"fatG":0.12,"fiberG":1.04,"sodiumMg":1.63,"calciumMg":22.42,"ironMg":0.19,"potassiumMg":126.15},"measure":"Grama: 300"},{"food":"Homus, c/ grão de bico, s/ sal","grams":20,"macros":{"energyKcal":275,"proteinG":7.65,"carbohydrateG":18,"fatG":20.7,"fiberG":6.67,"sodiumMg":20.9,"calciumMg":78.1,"ironMg":3.01,"potassiumMg":259},"measure":"Grama: 20) ou Pasta de amendoim  (Grama: 10","subs":[{"food":"Pasta de amendoim","grams":1,"macros":{"energyKcal":588,"proteinG":25.09,"carbohydrateG":19.56,"fatG":50.39,"fiberG":6,"sodiumMg":459,"calciumMg":43,"ironMg":1.87,"potassiumMg":649}}]},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Suco de abacaxi com hortelã sem açúcar","grams":200,"macros":{"energyKcal":22.07,"proteinG":0.2,"carbohydrateG":5.56,"fatG":0.19,"fiberG":0.56,"sodiumMg":2.43,"calciumMg":5.72,"ironMg":0.34,"potassiumMg":50.21},"measure":"Copo médio (200ml): 1"}],"time":"06:00"},{"name":"Jantar","items":[{"food":"Peito de galinha ou frango Grelhado(a)/brasa/churrasco","grams":30,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 30"},{"food":"Requeijão light","grams":30,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"Colher De Sopa: 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Cenoura (crua) (Grama: 20) ralada","grams":20,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323}},{"food":"Suco de uva integral - Superbom®","grams":200,"macros":{"energyKcal":61.6,"proteinG":0.3,"carbohydrateG":15.1,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":2,"potassiumMg":106},"measure":"Copo médio (200ml): 1"},{"food":"Chocolate amargo - 70% cacau","grams":12,"macros":{"energyKcal":540,"proteinG":7.6,"carbohydrateG":32.8,"fatG":40,"fiberG":12,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Grama: 12"}],"time":"21:00"},{"name":"Colação","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Presunto","grams":30,"macros":{"energyKcal":226,"proteinG":20.53,"carbohydrateG":0.42,"fatG":15.2,"fiberG":0,"sodiumMg":941,"calciumMg":8,"ironMg":1.37,"potassiumMg":357},"measure":"Fatia: 2"},{"food":"Queijo tipo mussarela","grams":26,"macros":{"energyKcal":281,"proteinG":19.4,"carbohydrateG":2.23,"fatG":21.6,"fiberG":0,"sodiumMg":373,"calciumMg":517,"ironMg":0.18,"potassiumMg":67.1},"measure":"Fatia (13,5g): 2"},{"food":"Alface crespa","grams":10,"macros":{"energyKcal":13,"proteinG":1.02,"carbohydrateG":2.1,"fatG":0.19,"fiberG":1,"sodiumMg":9,"calciumMg":19,"ironMg":0.5,"potassiumMg":158},"measure":"Folha média (10g): 1"},{"food":"Tomate","grams":10,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":222},"measure":"Fatia pequena (10g): 1"}],"time":"09:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 4"},{"food":"Brócolis, cozido","grams":20,"macros":{"energyKcal":24.64,"proteinG":2.13,"carbohydrateG":4.37,"fatG":0.46,"fiberG":3.42,"sodiumMg":2.12,"calciumMg":50.75,"ironMg":0.54,"potassiumMg":118.54},"measure":"Grama: 20"},{"food":"Feijão, preto, cozido","grams":80,"macros":{"energyKcal":77.03,"proteinG":4.48,"carbohydrateG":14.01,"fatG":0.54,"fiberG":8.4,"sodiumMg":1.85,"calciumMg":29,"ironMg":1.47,"potassiumMg":256.37},"measure":"concha: 1"},{"food":"Maminha Grelhado(a)/brasa/churrasco","grams":70,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Fatia: 2"},{"food":"Beterraba","grams":20,"macros":{"energyKcal":44,"proteinG":1.69,"carbohydrateG":9.97,"fatG":0.18,"fiberG":1.7,"sodiumMg":77,"calciumMg":16,"ironMg":0.79,"potassiumMg":305},"measure":"cozida) (Colher de sopa cheia (picada) (20g): 1"},{"food":"Vagem","grams":20,"macros":{"energyKcal":35,"proteinG":1.9,"carbohydrateG":7.9,"fatG":0.28,"fiberG":3.2,"sodiumMg":3,"calciumMg":46,"ironMg":1.28,"potassiumMg":299},"measure":"cozida) (Colher de sopa (20g): 1"}],"time":"12:30"},{"name":"Lanche da Tarde 1","items":[{"food":"Mix de Nuts","grams":15,"macros":{"energyKcal":513.33,"proteinG":22,"carbohydrateG":28.67,"fatG":34,"fiberG":6.67,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa: 1"},{"food":"Iogurte de qualquer sabor","grams":200,"macros":{"energyKcal":98.69,"proteinG":3.46,"carbohydrateG":14.62,"fatG":3.47,"fiberG":2.13,"sodiumMg":44.78,"calciumMg":120.93,"ironMg":0.09,"potassiumMg":162.44},"measure":"Pote: 1"},{"food":"Whey Protein Concentrado DUX - Baunilha","grams":28,"macros":{"energyKcal":410.7,"proteinG":71.4,"carbohydrateG":12.8,"fatG":7.1,"fiberG":0,"sodiumMg":321.4,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Scoop: 1"}],"time":"15:00"},{"name":"Lanche da Tarde 2","items":[{"food":"Banana","grams":150,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"ouro, prata, d´água, da terra, etc.)  (Unidade: 2"},{"food":"Mel","grams":5,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Grama: 5"},{"food":"Aveia em flocos","grams":7,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"Colher De Sobremesa: 1"},{"food":"Canela em pó","grams":1,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"Colher de café (1,2g): 1"}],"time":"17:00"},{"name":"Ceia","items":[{"food":"Chá","grams":300,"macros":{"energyKcal":1,"proteinG":0,"carbohydrateG":0.3,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":0,"ironMg":0.02,"potassiumMg":37.03},"measure":"preto, camomila, erva-cidreira, capim limão, etc.)  (Caneca: 1"},{"food":"Biscoito aveia e mel - Nestlé®","grams":18,"macros":{"energyKcal":450,"proteinG":15,"carbohydrateG":67.5,"fatG":7.25,"fiberG":2.5,"sodiumMg":112.5,"calciumMg":20,"ironMg":1.15,"potassiumMg":0},"measure":"Unidade (6g): 3) ou Biscoito, salgado, cream cracker (Unidade (5g): 3","subs":[{"food":"Biscoito, salgado, cream cracker","grams":5,"macros":{"energyKcal":431.73,"proteinG":10.06,"carbohydrateG":68.73,"fatG":14.44,"fiberG":2.51,"sodiumMg":854.36,"calciumMg":20,"ironMg":2.2,"potassiumMg":180.61}}]}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":2000},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Menopausa 1.600 Kcal","objective":"Cardápio clínico para menopausa — adaptar à avaliação nutricional do paciente.","tags":["1600 kcal"],"snapshot":{"dietboxId":1329884,"originalName":"Dieta para Menopausa 1.600 Kcal","kcalTotal":1605,"summary":{"energyKcal":1604.6,"proteinG":111.9,"carbohydrateG":215,"fatG":39.3,"fiberG":27,"sodiumMg":2032.9,"calciumMg":948.6,"ironMg":11.9,"potassiumMg":2749.7},"meals":[{"name":"Café da manhã","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"1 Pote"},{"food":"Morango","grams":48,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"2 Colher de sopa picado (24g)"},{"food":"Granola","grams":20,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"2 Colher De Sopa"},{"food":"Chá mate","grams":300,"macros":{"energyKcal":2.8,"proteinG":0.25,"carbohydrateG":2.31,"fatG":0,"fiberG":1.86,"sodiumMg":0.27,"calciumMg":4.7,"ironMg":0.15,"potassiumMg":11.01},"measure":"1 Caneca"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Ameixa","grams":42,"macros":{"energyKcal":46,"proteinG":0.7,"carbohydrateG":11.42,"fatG":0.28,"fiberG":1.4,"sodiumMg":0,"calciumMg":6,"ironMg":0.17,"potassiumMg":157},"measure":"1 Unidade"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Agrião","grams":10,"macros":{"energyKcal":17.22,"proteinG":1.6,"carbohydrateG":2.03,"fatG":0.3,"fiberG":1.47,"sodiumMg":12,"calciumMg":180,"ironMg":3.14,"potassiumMg":276},"measure":"1 Pires cheio picado (10g)"},{"food":"Cenoura","grams":36,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (3 Colher de sopa ralada (12g)"},{"food":"Macarrão","grams":220,"macros":{"energyKcal":158,"proteinG":5.8,"carbohydrateG":30.86,"fatG":0.93,"fiberG":1.8,"sodiumMg":1,"calciumMg":7,"ironMg":1.28,"potassiumMg":44},"measure":"2 Pegador"},{"food":"Filé-mignon Grelhado(a)/brasa/churrasco","grams":100,"macros":{"energyKcal":204,"proteinG":30.67,"carbohydrateG":0,"fatG":9,"fiberG":0,"sodiumMg":41,"calciumMg":7,"ironMg":2.53,"potassiumMg":252},"measure":"1 File"},{"food":"Vagem Cozido(a)","grams":60,"macros":{"energyKcal":35,"proteinG":1.89,"carbohydrateG":7.88,"fatG":0.28,"fiberG":3.2,"sodiumMg":1,"calciumMg":44,"ironMg":0.65,"potassiumMg":146},"measure":"3 Colher De Sopa"},{"food":"Abacaxi","grams":75,"macros":{"energyKcal":49,"proteinG":0.39,"carbohydrateG":12.4,"fatG":0.43,"fiberG":1.2,"sodiumMg":1,"calciumMg":7,"ironMg":0.37,"potassiumMg":113},"measure":"1 Fatia média (75g)"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Chá de abacaxi com Hortelã","grams":300,"macros":{"energyKcal":1,"proteinG":0,"carbohydrateG":0.3,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":0,"ironMg":0.02,"potassiumMg":37.03},"measure":"1 Caneca"},{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"16:00"},{"name":"Jantar","items":[{"food":"Pão, sírio, trigo integral","grams":64,"macros":{"energyKcal":266,"proteinG":9.8,"carbohydrateG":55,"fatG":2.6,"fiberG":7.4,"sodiumMg":532,"calciumMg":15,"ironMg":3.06,"potassiumMg":170},"measure":"1 pão, grande (16.5 cm diâmetro)"},{"food":"Queijo de minas","grams":90,"macros":{"energyKcal":240,"proteinG":17.6,"carbohydrateG":10.6,"fatG":14.1,"fiberG":0,"sodiumMg":1587,"calciumMg":529,"ironMg":0.2,"potassiumMg":330},"measure":"2 Fatia"},{"food":"Filé de frango desfiado","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"1 Unidade"},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"2 Fatia média (15g)"},{"food":"Alface","grams":8,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pegador"},{"food":"Limonada sem açúcar","grams":200,"macros":{"energyKcal":5,"proteinG":0.08,"carbohydrateG":1.73,"fatG":0.01,"fiberG":0.08,"sodiumMg":2.6,"calciumMg":3,"ironMg":0.01,"potassiumMg":24.81},"measure":"1 Copo de requeijão (200ml)"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Laranja","grams":180,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"1 Unidade média (180g)"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["menopause"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1600},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Pancreatite 1.300 Kcal","objective":"Cardápio clínico para conforto gastrointestinal — adaptar à avaliação nutricional do paciente.","tags":["1300 kcal"],"snapshot":{"dietboxId":1325089,"originalName":"Dieta para Pancreatite 1.300 Kcal","kcalTotal":1317,"summary":{"energyKcal":1316.9,"proteinG":91,"carbohydrateG":196.2,"fatG":20.6,"fiberG":16.4,"sodiumMg":678.5,"calciumMg":594.7,"ironMg":7.5,"potassiumMg":3016.2},"meals":[{"name":"Café da manhã","items":[{"food":"Leite de vaca desnatado","grams":300,"macros":{"energyKcal":34.15,"proteinG":3.39,"carbohydrateG":4.98,"fatG":0.08,"fiberG":0,"sodiumMg":42.19,"calciumMg":125.56,"ironMg":0.03,"potassiumMg":156.7},"measure":"1 Caneca"},{"food":"Banana","grams":150,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"2 Unidade média (75g)"},{"food":"Aveia em flocos","grams":15,"macros":{"energyKcal":384,"proteinG":16,"carbohydrateG":67,"fatG":6.3,"fiberG":9.8,"sodiumMg":4,"calciumMg":52,"ironMg":4.2,"potassiumMg":350},"measure":"1 Colher De Sopa"},{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Requeijão light","grams":24,"macros":{"energyKcal":231,"proteinG":10.6,"carbohydrateG":7,"fatG":17.6,"fiberG":0,"sodiumMg":296,"calciumMg":112,"ironMg":1.68,"potassiumMg":167},"measure":"4 Ponta De Faca"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Mamão papaia","grams":100,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia pequena (100g)"}],"time":"10:30"},{"name":"Almoço","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"2 Fatia média (15g)"},{"food":"Outros legumes cozidos","grams":60,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"2 Colher De Sopa"},{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (4 Colher de sopa cheia (20g)"},{"food":"Filé de frango","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"1 Unidade"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Bolo branco simples","grams":60,"macros":{"energyKcal":317.82,"proteinG":5.94,"carbohydrateG":55.21,"fatG":8.36,"fiberG":1.39,"sodiumMg":26.29,"calciumMg":32.62,"ironMg":1.85,"potassiumMg":103.14},"measure":"1 Fatia média (60g)"},{"food":"Suco de laranja","grams":240,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"1 Copo Medio"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":30,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"2 Fatia média (15g)"},{"food":"Peixe","grams":120,"macros":{"energyKcal":117,"proteinG":24.16,"carbohydrateG":0,"fatG":1.53,"fiberG":0,"sodiumMg":105,"calciumMg":18,"ironMg":0.34,"potassiumMg":344},"measure":"em filé)  Grelhado(a)/brasa/churrasco (1 File"},{"food":"Batata-inglesa Cozido(a)","grams":120,"macros":{"energyKcal":86,"proteinG":1.71,"carbohydrateG":20.01,"fatG":0.1,"fiberG":2.05,"sodiumMg":5,"calciumMg":8,"ironMg":0.31,"potassiumMg":328},"measure":"2 Colher De Arroz/Servir"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Ameixa","grams":84,"macros":{"energyKcal":46,"proteinG":0.7,"carbohydrateG":11.42,"fatG":0.28,"fiberG":1.4,"sodiumMg":0,"calciumMg":6,"ironMg":0.17,"potassiumMg":157},"measure":"2 Unidade"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":["gastrointestinal"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1300},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta para Refluxo Gastroesofágico 1.200 Kcal","objective":"Cardápio clínico para conforto gastrointestinal — adaptar à avaliação nutricional do paciente.","tags":["1200 kcal"],"snapshot":{"dietboxId":1321580,"originalName":"Dieta para Refluxo Gastroesofágico 1.200 Kcal","kcalTotal":1192,"summary":{"energyKcal":1192,"proteinG":64.4,"carbohydrateG":189.1,"fatG":22.9,"fiberG":17.7,"sodiumMg":507.4,"calciumMg":191.7,"ironMg":6.6,"potassiumMg":2241.9},"meals":[{"name":"Café da manhã","items":[{"food":"Pão integral","grams":25,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"1 Fatia"},{"food":"Margarina com ou sem sal","grams":8,"macros":{"energyKcal":719,"proteinG":0.9,"carbohydrateG":0.9,"fatG":80.5,"fiberG":0,"sodiumMg":943,"calciumMg":30,"ironMg":0,"potassiumMg":42},"measure":"1 Colher De Cha"},{"food":"Mamão papaia","grams":170,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia média (170g)"},{"food":"Linhaça, semente","grams":4,"macros":{"energyKcal":495.1,"proteinG":14.08,"carbohydrateG":43.31,"fatG":32.25,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211.5,"ironMg":4.7,"potassiumMg":869.29},"measure":"1 Colher De Chá"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Damasco seco","grams":21,"macros":{"energyKcal":238,"proteinG":3.66,"carbohydrateG":61.8,"fatG":0.46,"fiberG":7.8,"sodiumMg":10,"calciumMg":45,"ironMg":4.71,"potassiumMg":1378},"measure":"3 Unidade (7g)"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Alface","grams":20,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Pires"},{"food":"Tomate","grams":60,"macros":{"energyKcal":21,"proteinG":0.85,"carbohydrateG":4.65,"fatG":0.33,"fiberG":1.03,"sodiumMg":9,"calciumMg":5,"ironMg":0.45,"potassiumMg":22},"measure":"4 Fatia média (15g)"},{"food":"Arroz integral","grams":126,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (2 Colher de arroz cheia (63g)"},{"food":"Filé-mignon","grams":70,"macros":{"energyKcal":204,"proteinG":30.67,"carbohydrateG":0,"fatG":9,"fiberG":0,"sodiumMg":41,"calciumMg":7,"ironMg":2.53,"potassiumMg":252},"measure":"2 Pedaco"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"1 Unidade média (75g)"}],"time":"15:30"},{"name":"Jantar","items":[{"food":"Filé de frango","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"1 Unidade"},{"food":"Mandioca Cozido(a)","grams":200,"macros":{"energyKcal":125,"proteinG":0.6,"carbohydrateG":30.1,"fatG":0.3,"fiberG":1.6,"sodiumMg":1,"calciumMg":19,"ironMg":0.1,"potassiumMg":100},"measure":"2 Pedaco"},{"food":"Outros legumes cozidos","grams":90,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"3 Colher De Sopa"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Pêssego","grams":60,"macros":{"energyKcal":39,"proteinG":0.91,"carbohydrateG":9.54,"fatG":0.25,"fiberG":1.5,"sodiumMg":0,"calciumMg":6,"ironMg":0.25,"potassiumMg":190},"measure":"1 Unidade"}],"time":"23:00"},{"name":"Lanche da tarde 2","items":[{"food":"Gelatina","grams":42,"macros":{"energyKcal":266,"proteinG":0.15,"carbohydrateG":69.95,"fatG":0.02,"fiberG":1,"sodiumMg":30,"calciumMg":7,"ironMg":0.19,"potassiumMg":54},"measure":"2  colheres de sopa"}],"time":"17:30"}]},"dimensions":{"approaches":[],"objectives":["gastrointestinal"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1200},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Pós-Operatório imediato de Cirurgia Plástica 1400 Kcal","objective":"Cardápio clínico para período perioperatório — adaptar à avaliação nutricional do paciente.","tags":["1400 kcal"],"snapshot":{"dietboxId":20201478,"originalName":"Dieta Pós-Operatório imediato de Cirurgia Plástica 1400 Kcal","kcalTotal":1400,"summary":{"energyKcal":1399.8,"proteinG":96.9,"carbohydrateG":198.8,"fatG":29.1,"fiberG":29.7,"sodiumMg":980.3,"calciumMg":724.5,"ironMg":9.1,"potassiumMg":4141.7},"meals":[{"name":"Desjejum","items":[{"food":"Água","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (200ml): 1"}],"time":"08:00"},{"name":"Café da manhã","items":[{"food":"Suco de Mamão com Laranja natural sem açúcar","grams":664,"macros":{"energyKcal":36.73,"proteinG":0.74,"carbohydrateG":9.26,"fatG":0.11,"fiberG":1.47,"sodiumMg":1.52,"calciumMg":31.87,"ironMg":0.24,"potassiumMg":169.13},"measure":"Copo médio (200 ml: 1"},{"food":"Biscoito de arroz Camil","grams":8,"macros":{"energyKcal":376.67,"proteinG":8.67,"carbohydrateG":80,"fatG":2,"fiberG":2.67,"sodiumMg":336.67,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Unidade: 4"},{"food":"Mel","grams":7,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher de chá (7g): 1"},{"food":"Ovo de galinha Cozido(a)","grams":45,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 1"}],"time":"08:15","notes":"# Biscoito de arroz com mel;"},{"name":"Colação","items":[{"food":"Água de coco natural sem açúcar","grams":240,"macros":{"energyKcal":19.27,"proteinG":0.73,"carbohydrateG":3.76,"fatG":0.2,"fiberG":1.12,"sodiumMg":106.52,"calciumMg":24.35,"ironMg":0.29,"potassiumMg":253.61},"measure":"Copo Medio: 1"},{"food":"Módulo de proteína","grams":20,"macros":{"energyKcal":340,"proteinG":80,"carbohydrateG":5.33,"fatG":0,"fiberG":4,"sodiumMg":183,"calciumMg":413,"ironMg":0,"potassiumMg":0},"measure":"Dose: 1"}],"time":"10:00","notes":"# Para módulo de proteína considerar: Whey protein, proteína vegana ou de aminoácidos;"},{"name":"Almoço","items":[{"food":"Batata inglesa cozida sem sal","grams":140,"macros":{"energyKcal":105,"proteinG":1.66,"carbohydrateG":24.3,"fatG":0.3,"fiberG":2.3,"sodiumMg":13,"calciumMg":21,"ironMg":0.56,"potassiumMg":184},"measure":"Unidade média (140g): 1"},{"food":"Peito de frango desfiado","grams":80,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Colher De Sopa (20g): 4"},{"food":"Chuchu","grams":20,"macros":{"energyKcal":24,"proteinG":0.62,"carbohydrateG":5.1,"fatG":0.48,"fiberG":0.58,"sodiumMg":1,"calciumMg":13,"ironMg":0.22,"potassiumMg":173},"measure":"cozido) (Colher de sopa cheia (picado) (20g): 1"},{"food":"Cenoura","grams":30,"macros":{"energyKcal":45,"proteinG":1.1,"carbohydrateG":10.5,"fatG":0.18,"fiberG":2.53,"sodiumMg":66,"calciumMg":31,"ironMg":0.62,"potassiumMg":227},"measure":"cozida) (Colher de sopa rasa (picada) (15g): 2"}],"time":"12:00","notes":"# Escondidinho de frango;\n "},{"name":"Lanche da tarde","items":[{"food":"Frutas variadas picadas","grams":250,"macros":{"energyKcal":52.51,"proteinG":0.7,"carbohydrateG":12.99,"fatG":0.29,"fiberG":1.26,"sodiumMg":1.45,"calciumMg":17.13,"ironMg":0.22,"potassiumMg":206.63},"measure":"Xícara de chá (250g): 1"},{"food":"Água","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (200ml): 1"},{"food":"Módulo de proteína","grams":20,"macros":{"energyKcal":340,"proteinG":80,"carbohydrateG":5.33,"fatG":0,"fiberG":4,"sodiumMg":183,"calciumMg":413,"ironMg":0,"potassiumMg":0},"measure":"Dose: 1"}],"time":"15:00","notes":"# Salada de frutas; \n# Módulo de proteína misturado em água. Beber gelado!\n"},{"name":"Hidratação ","items":[{"food":"Água de coco natural sem açúcar","grams":240,"macros":{"energyKcal":19.27,"proteinG":0.73,"carbohydrateG":3.76,"fatG":0.2,"fiberG":1.12,"sodiumMg":106.52,"calciumMg":24.35,"ironMg":0.29,"potassiumMg":253.61},"measure":"Copo Medio: 1"}],"time":"12:30","notes":"# Após o almoço! "},{"name":"Jantar","items":[{"food":"Ovo de galinha","grams":135,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 3"},{"food":"Mix de legumes cozidos","grams":60,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Sopa: 2"},{"food":"Orégano seco","grams":1,"macros":{"energyKcal":306,"proteinG":11,"carbohydrateG":64.4,"fatG":10.3,"fiberG":15,"sodiumMg":14.7,"calciumMg":1576,"ironMg":44,"potassiumMg":1668},"measure":"1 Colher de café (037g)"},{"food":"Manjericão fresco","grams":3,"macros":{"energyKcal":27,"proteinG":2.54,"carbohydrateG":4.35,"fatG":0.61,"fiberG":2.52,"sodiumMg":4.01,"calciumMg":154,"ironMg":3.17,"potassiumMg":462},"measure":"5 folhas (3g)"},{"food":"Azeite de oliva extra virgem","grams":2,"macros":{"energyKcal":720,"proteinG":0,"carbohydrateG":0,"fatG":80,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":1,"potassiumMg":0},"measure":"Colher de chá (2,4ml): 1"}],"time":"19:00","notes":"# Omelete de legumes;"},{"name":"Ceia","items":[{"food":"Banana","grams":75,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média: 1"},{"food":"Farelo de aveia","grams":11,"macros":{"energyKcal":350,"proteinG":20,"carbohydrateG":50,"fatG":10,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":5,"potassiumMg":0},"measure":"Colher de sopa (11g): 1"}],"time":"21:00","notes":"# Banana amassada com aveia; "}]},"dimensions":{"approaches":[],"objectives":["perioperative"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1400},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Pré-Operatória de Cirurgia Plástica 1800 Kcal","objective":"Cardápio clínico para período perioperatório — adaptar à avaliação nutricional do paciente.","tags":["1800 kcal"],"snapshot":{"dietboxId":20201469,"originalName":"Dieta Pré-Operatória de Cirurgia Plástica 1800 Kcal","kcalTotal":1832,"summary":{"energyKcal":1831.8,"proteinG":121.7,"carbohydrateG":236.3,"fatG":51.1,"fiberG":34.7,"sodiumMg":1975.7,"calciumMg":473.4,"ironMg":13,"potassiumMg":4127.2},"meals":[{"name":"Desjejum","items":[{"food":"Água","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (200ml): 1"}],"time":"08:00"},{"name":"Café da manhã","items":[{"food":"Suco verde","grams":223,"macros":{"energyKcal":25.23,"proteinG":0.72,"carbohydrateG":6.07,"fatG":0.12,"fiberG":1.11,"sodiumMg":5.57,"calciumMg":30.85,"ironMg":0.21,"potassiumMg":122.25},"measure":"Porção: 1"},{"food":"Mix de sementes","grams":10,"macros":{"energyKcal":453,"proteinG":14.1,"carbohydrateG":43.3,"fatG":32.3,"fiberG":33.5,"sodiumMg":8.67,"calciumMg":211,"ironMg":4.7,"potassiumMg":869},"measure":"linhaça, chia, gergelim...) (Colher de chá: 2"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Omelete","grams":65,"macros":{"energyKcal":241.62,"proteinG":11.04,"carbohydrateG":0.98,"fatG":21.26,"fiberG":0,"sodiumMg":357.48,"calciumMg":44.4,"ironMg":1.05,"potassiumMg":110.58},"measure":"Unidade: 1"}],"time":"08:00","notes":"# Preparar o suco verde com o mix de sementes. Não coar o suco!\n# Preparar os ovos mexidos com azeite de oliva extra virgem!"},{"name":"Almoço","items":[{"food":"Purê de batata doce","grams":168,"macros":{"energyKcal":76,"proteinG":1.37,"carbohydrateG":17.72,"fatG":0.14,"fiberG":2.5,"sodiumMg":27,"calciumMg":27,"ironMg":0.72,"potassiumMg":230},"measure":"Colher de sopa (20g): 4"},{"food":"Filé de frango grelhado","grams":100,"macros":{"energyKcal":183.63,"proteinG":29.66,"carbohydrateG":0.31,"fatG":6.22,"fiberG":0.02,"sodiumMg":410.3,"calciumMg":16.22,"ironMg":1.02,"potassiumMg":248.23},"measure":"Filé pequeno (100g): 1"},{"food":"Mix de legumes cozidos","grams":40,"macros":{"energyKcal":38,"proteinG":3,"carbohydrateG":6,"fatG":0,"fiberG":3,"sodiumMg":151,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de arroz (40g): 1"},{"food":"Salada à vontade","grams":30,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237}},{"food":"Sobremesa: Laranja com bagaço","grams":180,"macros":{"energyKcal":47,"proteinG":0.94,"carbohydrateG":11.8,"fatG":0.12,"fiberG":1.9,"sodiumMg":0,"calciumMg":40,"ironMg":0.1,"potassiumMg":181},"measure":"Unidade média (180g): 1"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Banana","grams":150,"macros":{"energyKcal":92,"proteinG":1.04,"carbohydrateG":23.4,"fatG":0.48,"fiberG":2.03,"sodiumMg":1,"calciumMg":6,"ironMg":0.31,"potassiumMg":396},"measure":"Unidade média: 2"},{"food":"Mel","grams":7,"macros":{"energyKcal":304,"proteinG":0.3,"carbohydrateG":82.4,"fatG":0,"fiberG":0.2,"sodiumMg":4,"calciumMg":6,"ironMg":0.42,"potassiumMg":52},"measure":"Colher de chá (7g): 1"},{"food":"Farelo de aveia","grams":11,"macros":{"energyKcal":350,"proteinG":20,"carbohydrateG":50,"fatG":10,"fiberG":20,"sodiumMg":0,"calciumMg":0,"ironMg":5,"potassiumMg":0},"measure":"Colher de sopa (11g): 1"},{"food":"Canela em pó","grams":2,"macros":{"energyKcal":261,"proteinG":3.89,"carbohydrateG":79.8,"fatG":3.19,"fiberG":54.3,"sodiumMg":26.3,"calciumMg":1228,"ironMg":38.2,"potassiumMg":500},"measure":"Colher de chá (2g): 1"}],"time":"15:00","notes":"# Banana amassada com aveia + canela e mel;"},{"name":"Lanche da tarde II","items":[{"food":"Morango","grams":96,"macros":{"energyKcal":30,"proteinG":0.61,"carbohydrateG":7.03,"fatG":0.37,"fiberG":1.53,"sodiumMg":1,"calciumMg":14,"ironMg":0.38,"potassiumMg":166},"measure":"Unidade média (12g): 8) ou Mix de frutas vermelhas (mirtilo, cranberry (Colher de sopa: 2"},{"food":"Água de coco","grams":240,"macros":{"energyKcal":19.27,"proteinG":0.73,"carbohydrateG":3.76,"fatG":0.2,"fiberG":1.12,"sodiumMg":106.52,"calciumMg":24.35,"ironMg":0.29,"potassiumMg":253.61},"measure":"Copo Medio: 1"},{"food":"Módulo de proteína","grams":20,"macros":{"energyKcal":363,"proteinG":88.9,"carbohydrateG":7,"fatG":0,"fiberG":0,"sodiumMg":400,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Dose: 1"}],"time":"17:00","notes":"# Misturar todos os ingredientes e fazer um shake proteico;\n# Para módulo de proteína considerar: Whey protein, proteína vegana ou de aminoácidos;\n"},{"name":"Jantar","items":[{"food":"Arroz integral","grams":80,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 4"},{"food":"Carne moída","grams":100,"macros":{"energyKcal":293.11,"proteinG":24.09,"carbohydrateG":0.86,"fatG":20.83,"fiberG":0.13,"sodiumMg":411.33,"calciumMg":13.75,"ironMg":2.45,"potassiumMg":301.72},"measure":"refogada) (Colher de sopa cheia (25g): 4"},{"food":"Mix de legumes cozidos","grams":20,"macros":{"energyKcal":53,"proteinG":2,"carbohydrateG":11,"fatG":0,"fiberG":3,"sodiumMg":128,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Colher de arroz (40g): 1"}],"time":"19:00"},{"name":"Ceia ","items":[{"food":"Suco de maracujá natural sem açúcar","grams":240,"macros":{"energyKcal":60.14,"proteinG":0.67,"carbohydrateG":14.48,"fatG":0.18,"fiberG":0.2,"sodiumMg":6.01,"calciumMg":4.01,"ironMg":0.36,"potassiumMg":278.63},"measure":"Copo Medio: 1"},{"food":"Água","grams":200,"macros":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":3,"calciumMg":2,"ironMg":0.01,"potassiumMg":0},"measure":"Copo médio (200ml): 1"},{"food":"Módulo proteico","grams":20,"macros":{"energyKcal":363,"proteinG":88.9,"carbohydrateG":7,"fatG":0,"fiberG":0,"sodiumMg":400,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Dose: 1"}],"time":"21:00","notes":"# Suco de maracujá com módulo proteico; \n# Para módulo de proteína considerar: Whey protein, proteína vegana ou de aminoácidos;"},{"name":"Colação","items":[{"food":"Melão","grams":90,"macros":{"energyKcal":25,"proteinG":0.5,"carbohydrateG":6.2,"fatG":0.1,"fiberG":0.5,"sodiumMg":0,"calciumMg":15,"ironMg":1.2,"potassiumMg":0},"measure":"Fatia média (90g): 1"},{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"Unidade: 1"}],"time":"10:00","notes":"# Frutas picadas;"}]},"dimensions":{"approaches":[],"objectives":["perioperative"],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1800},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta Rica em Ferro 1.500 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1500 kcal"],"snapshot":{"dietboxId":1321924,"originalName":"Dieta Rica em Ferro 1.500 Kcal","kcalTotal":1514,"summary":{"energyKcal":1514.2,"proteinG":94,"carbohydrateG":197.7,"fatG":46,"fiberG":31.4,"sodiumMg":1683.4,"calciumMg":865.5,"ironMg":14.3,"potassiumMg":4229},"meals":[{"name":"Café da manhã","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"1 Pote"},{"food":"Granola","grams":10,"macros":{"energyKcal":388,"proteinG":9.5,"carbohydrateG":73.8,"fatG":6.3,"fiberG":8.5,"sodiumMg":50,"calciumMg":33.33,"ironMg":2.78,"potassiumMg":494},"measure":"1 Colher De Sopa"},{"food":"Mamão papaia","grams":290,"macros":{"energyKcal":39,"proteinG":0.61,"carbohydrateG":9.82,"fatG":0.14,"fiberG":1.8,"sodiumMg":3,"calciumMg":24,"ironMg":0.1,"potassiumMg":257},"measure":"1 Fatia grande (290g)"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Uva","grams":170,"macros":{"energyKcal":69,"proteinG":0.72,"carbohydrateG":18.1,"fatG":0.16,"fiberG":0.9,"sodiumMg":2,"calciumMg":10,"ironMg":0.36,"potassiumMg":191},"measure":"1 Cacho"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Alface","grams":30,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"1 Prato De Sobremesa"},{"food":"Pepino","grams":50,"macros":{"energyKcal":13,"proteinG":0.69,"carbohydrateG":2.77,"fatG":0.13,"fiberG":0.68,"sodiumMg":2,"calciumMg":14,"ironMg":0.26,"potassiumMg":144},"measure":"1 Colher de servir picado (50g)"},{"food":"Arroz integral","grams":60,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (3 Colher de sopa cheia (20g)"},{"food":"Lentilha","grams":160,"macros":{"energyKcal":136.28,"proteinG":9.02,"carbohydrateG":20.13,"fatG":2.67,"fiberG":5.86,"sodiumMg":2,"calciumMg":19,"ironMg":3.33,"potassiumMg":369},"measure":"1 Concha"},{"food":"Amêndoa Picada","grams":5,"macros":{"energyKcal":578,"proteinG":21.26,"carbohydrateG":19.74,"fatG":50.64,"fiberG":11.8,"sodiumMg":1,"calciumMg":248,"ironMg":4.3,"potassiumMg":728},"measure":"5 Unidade"},{"food":"Filé de frango","grams":100,"macros":{"energyKcal":173,"proteinG":30.91,"carbohydrateG":0,"fatG":4.51,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"1 Unidade"},{"food":"Espinafre","grams":50,"macros":{"energyKcal":23,"proteinG":2.98,"carbohydrateG":3.76,"fatG":0.26,"fiberG":2.3,"sodiumMg":70,"calciumMg":136,"ironMg":3.57,"potassiumMg":466},"measure":"cozido) (2 Pegador (25g)"},{"food":"Manga","grams":70,"macros":{"energyKcal":65,"proteinG":0.51,"carbohydrateG":17,"fatG":0.27,"fiberG":1.76,"sodiumMg":2,"calciumMg":10,"ironMg":0.13,"potassiumMg":156},"measure":"1 Metade"}],"time":"12:30"},{"name":"Lanche da tarde","items":[{"food":"Maçã","grams":150,"macros":{"energyKcal":52,"proteinG":0.26,"carbohydrateG":13.81,"fatG":0.17,"fiberG":2.4,"sodiumMg":1,"calciumMg":6,"ironMg":0.12,"potassiumMg":107},"measure":"1 Unidade"},{"food":"Pão de mel","grams":12,"macros":{"energyKcal":508.36,"proteinG":4.46,"carbohydrateG":85.04,"fatG":18.34,"fiberG":1.85,"sodiumMg":153.34,"calciumMg":89.98,"ironMg":3.54,"potassiumMg":600.85},"measure":"1 Unidade"}],"time":"16:30"},{"name":"Jantar","items":[{"food":"Acelga","grams":60,"macros":{"energyKcal":19,"proteinG":1.81,"carbohydrateG":3.75,"fatG":0.2,"fiberG":1.6,"sodiumMg":213,"calciumMg":51,"ironMg":1.8,"potassiumMg":379},"measure":"crua) (1 Prato pires raso (picado) (60g)"},{"food":"Brócolis","grams":46,"macros":{"energyKcal":28,"proteinG":2.99,"carbohydrateG":5.25,"fatG":0.35,"fiberG":3,"sodiumMg":27,"calciumMg":48,"ironMg":0.88,"potassiumMg":325},"measure":"cru) (1 Xícara de chá picado (46g)"},{"food":"Noz, crua","grams":18,"macros":{"energyKcal":620.06,"proteinG":13.97,"carbohydrateG":18.36,"fatG":59.36,"fiberG":7.25,"sodiumMg":4.57,"calciumMg":105.31,"ironMg":2.04,"potassiumMg":533.26},"measure":"2 Colher De Sopa"},{"food":"Salmão","grams":100,"macros":{"energyKcal":117,"proteinG":18.3,"carbohydrateG":0,"fatG":4.33,"fiberG":0,"sodiumMg":784,"calciumMg":11,"ironMg":0.85,"potassiumMg":175},"measure":"cozido) (1 Filé (100g)"},{"food":"Mostarda molho","grams":30,"macros":{"energyKcal":67,"proteinG":4.37,"carbohydrateG":5.33,"fatG":4.01,"fiberG":3.3,"sodiumMg":1135,"calciumMg":58,"ironMg":1.51,"potassiumMg":138},"measure":"30 Grama"},{"food":"Mexerica","grams":125,"macros":{"energyKcal":44,"proteinG":0.63,"carbohydrateG":11.2,"fatG":0.19,"fiberG":1.5,"sodiumMg":1,"calciumMg":14,"ironMg":0.1,"potassiumMg":157},"measure":"1 Unidade média (125g)"}],"time":"20:00"},{"name":"Ceia","items":[{"food":"Iogurte natural","grams":200,"macros":{"energyKcal":61,"proteinG":3.47,"carbohydrateG":4.66,"fatG":3.25,"fiberG":0,"sodiumMg":46,"calciumMg":121,"ironMg":0.05,"potassiumMg":155},"measure":"1 Pote"}],"time":"23:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1500},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta s/ Glúten e s/ Lactose","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":312419,"originalName":"Dieta s/ Glúten e s/ Lactose","kcalTotal":0,"summary":{"energyKcal":0,"proteinG":0,"carbohydrateG":0,"fatG":0,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"meals":[{"name":"Desjejum","items":[],"time":"07:00"},{"name":"Colação","items":[],"time":"10:00"},{"name":"Almoço","items":[],"time":"13:00"},{"name":"Lanche da tarde","items":[],"time":"16:00"},{"name":"Jantar","items":[],"time":"19:00"},{"name":"Ceia","items":[],"time":"22:00"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":[],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":0},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta sem frutose","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":[],"snapshot":{"dietboxId":19507552,"originalName":"Dieta sem frutose","kcalTotal":1760,"summary":{"energyKcal":1760.4,"proteinG":145.1,"carbohydrateG":135.8,"fatG":66.9,"fiberG":14.8,"sodiumMg":2842.3,"calciumMg":592.8,"ironMg":14.3,"potassiumMg":2859.8},"meals":[{"name":"Café da manhã","items":[{"food":"Tapioca de goma","grams":50,"macros":{"energyKcal":336,"proteinG":2,"carbohydrateG":82,"fatG":0,"fiberG":0,"sodiumMg":1.5,"calciumMg":4,"ironMg":0.16,"potassiumMg":0},"measure":"Grama: 50"},{"food":"Ovo de galinha","grams":90,"macros":{"energyKcal":155,"proteinG":12.58,"carbohydrateG":1.12,"fatG":10.61,"fiberG":0,"sodiumMg":124,"calciumMg":50,"ironMg":1.19,"potassiumMg":126},"measure":"Unidade: 2"},{"food":"Queijo minas frescal","grams":60,"macros":{"energyKcal":231,"proteinG":14.2,"carbohydrateG":2.9,"fatG":18.1,"fiberG":0,"sodiumMg":0,"calciumMg":0,"ironMg":0,"potassiumMg":0},"measure":"Fatia (30g): 2"},{"food":"Morango","grams":120,"macros":{"energyKcal":32,"proteinG":0.67,"carbohydrateG":7.68,"fatG":0.3,"fiberG":2,"sodiumMg":1,"calciumMg":16,"ironMg":0.41,"potassiumMg":153},"measure":"Grama: 120"}],"time":"08:00"},{"name":"Almoço","items":[{"food":"Batata","grams":200,"macros":{"energyKcal":87,"proteinG":1.88,"carbohydrateG":20.1,"fatG":0.1,"fiberG":1.8,"sodiumMg":4,"calciumMg":5,"ironMg":0.31,"potassiumMg":379},"measure":"cozida) (Grama: 200"},{"food":"Patinho Grelhado/Moído/Cozido","grams":150,"macros":{"energyKcal":199,"proteinG":36.12,"carbohydrateG":0,"fatG":5,"fiberG":0,"sodiumMg":45,"calciumMg":4,"ironMg":3.32,"potassiumMg":334},"measure":"Grama: 150"},{"food":"Alface, americana, crua","grams":30,"macros":{"energyKcal":6,"proteinG":0.41,"carbohydrateG":1.5,"fatG":0.11,"fiberG":1.24,"sodiumMg":5.93,"calciumMg":11.7,"ironMg":0.22,"potassiumMg":110},"measure":"Grama: 30"},{"food":"Cebola Grelhado(a)/brasa/churrasco","grams":20,"macros":{"energyKcal":44,"proteinG":1.36,"carbohydrateG":10.15,"fatG":0.19,"fiberG":1.4,"sodiumMg":3,"calciumMg":22,"ironMg":0.24,"potassiumMg":166},"measure":"Porção: 1"},{"food":"Cenoura","grams":50,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Grama: 50"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Requeijão cremoso light -","grams":30,"macros":{"energyKcal":133.33,"proteinG":10,"carbohydrateG":5,"fatG":0,"fiberG":0,"sodiumMg":416.67,"calciumMg":101.17,"ironMg":0,"potassiumMg":0},"measure":"Colher de sopa (30g): 1"},{"food":"Peito de frango desfiado","grams":70,"macros":{"energyKcal":195.66,"proteinG":30.91,"carbohydrateG":0,"fatG":7.07,"fiberG":0,"sodiumMg":77,"calciumMg":15,"ironMg":1.06,"potassiumMg":247},"measure":"Grama: 70"},{"food":"Cenoura","grams":30,"macros":{"energyKcal":43,"proteinG":1.04,"carbohydrateG":10.1,"fatG":0.19,"fiberG":2.6,"sodiumMg":35,"calciumMg":27,"ironMg":0.5,"potassiumMg":323},"measure":"crua) (Grama: 30"}],"time":"17:30"},{"name":"Jantar","items":[{"food":"Omelete simples - 3 ovos","grams":195,"macros":{"energyKcal":171.44,"proteinG":11.72,"carbohydrateG":1.15,"fatG":12.97,"fiberG":0,"sodiumMg":1022.89,"calciumMg":46.5,"ironMg":1.35,"potassiumMg":113.61}},{"food":"Queijo prato","grams":30,"macros":{"energyKcal":302,"proteinG":25.96,"carbohydrateG":3.83,"fatG":20.03,"fiberG":0,"sodiumMg":528,"calciumMg":731,"ironMg":0.25,"potassiumMg":95},"measure":"Fatia: 2"},{"food":"Espinafre","grams":50,"macros":{"energyKcal":22,"proteinG":2.87,"carbohydrateG":3.51,"fatG":0.35,"fiberG":2.7,"sodiumMg":79,"calciumMg":99,"ironMg":2.71,"potassiumMg":558},"measure":"cru) (Colher de sopa cheia (25g): 2"},{"food":"Cebolinha","grams":2,"macros":{"energyKcal":25,"proteinG":1.8,"carbohydrateG":5.65,"fatG":0.1,"fiberG":3.5,"sodiumMg":4,"calciumMg":61,"ironMg":1.92,"potassiumMg":260},"measure":"Colher De Sopa: 1"},{"food":"Cebola Cru(a)","grams":35,"macros":{"energyKcal":40,"proteinG":1.1,"carbohydrateG":9.34,"fatG":0.1,"fiberG":1.93,"sodiumMg":4,"calciumMg":23,"ironMg":0.21,"potassiumMg":146},"measure":"Banda: 1"},{"food":"Alface","grams":50,"macros":{"energyKcal":15,"proteinG":1.36,"carbohydrateG":2.79,"fatG":0.15,"fiberG":1.3,"sodiumMg":28,"calciumMg":36,"ironMg":0.86,"potassiumMg":194},"measure":"Folha: 5"}],"time":"20:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["low_fodmap"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1760},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}},{"name":"Dieta sem Lactose 1.300 Kcal","objective":"Cardápio pronto para adaptação clínica profissional no BSNutri.","tags":["1300 kcal"],"snapshot":{"dietboxId":1231575,"originalName":"Dieta sem Lactose 1.300 Kcal","kcalTotal":1343,"summary":{"energyKcal":1342.6,"proteinG":87.4,"carbohydrateG":132.5,"fatG":53.4,"fiberG":14.3,"sodiumMg":2551.1,"calciumMg":264,"ironMg":8.7,"potassiumMg":2238.8},"meals":[{"name":"Café da manhã","items":[{"food":"Suco de laranja","grams":150,"macros":{"energyKcal":41.83,"proteinG":0.59,"carbohydrateG":9.81,"fatG":0.14,"fiberG":0.31,"sodiumMg":1.99,"calciumMg":7.97,"ironMg":0.44,"potassiumMg":0},"measure":"Copo Americano: 1"},{"food":"Pão integral","grams":50,"macros":{"energyKcal":247,"proteinG":12.95,"carbohydrateG":41.29,"fatG":3.35,"fiberG":6.71,"sodiumMg":472,"calciumMg":107,"ironMg":2.43,"potassiumMg":248},"measure":"Fatia: 2"},{"food":"Presunto","grams":15,"macros":{"energyKcal":226,"proteinG":20.53,"carbohydrateG":0.42,"fatG":15.2,"fiberG":0,"sodiumMg":941,"calciumMg":8,"ironMg":1.37,"potassiumMg":357},"measure":"Fatia: 1"},{"food":"Manteiga com ou sem sal","grams":5,"macros":{"energyKcal":717,"proteinG":0.85,"carbohydrateG":0.06,"fatG":81.11,"fiberG":0,"sodiumMg":576,"calciumMg":24,"ironMg":0.02,"potassiumMg":24},"measure":"Ponta De Faca: 1"}],"time":"07:00"},{"name":"Colação","items":[{"food":"Fruta","grams":86,"macros":{"energyKcal":89,"proteinG":1.09,"carbohydrateG":22.84,"fatG":0.33,"fiberG":2.6,"sodiumMg":1,"calciumMg":5,"ironMg":0.26,"potassiumMg":358},"measure":"não especificada)  (Porcao: 1"}],"time":"10:00"},{"name":"Almoço","items":[{"food":"Arroz integral","grams":40,"macros":{"energyKcal":76.76,"proteinG":1.5,"carbohydrateG":14.56,"fatG":1.34,"fiberG":0.66,"sodiumMg":115.89,"calciumMg":6.01,"ironMg":0.29,"potassiumMg":42.09},"measure":"cozido) (Colher de sopa cheia (20g): 2"},{"food":"Frango, peito, sem pele, cozido","grams":140,"macros":{"energyKcal":162.87,"proteinG":31.47,"carbohydrateG":0,"fatG":3.16,"fiberG":0,"sodiumMg":36.17,"calciumMg":6.44,"ironMg":0.34,"potassiumMg":231.05},"measure":"Peito Pequeno (140g): 1"},{"food":"Outros legumes cozidos","grams":110,"macros":{"energyKcal":60.5,"proteinG":1.24,"carbohydrateG":14.12,"fatG":0.14,"fiberG":2.53,"sodiumMg":31.5,"calciumMg":19,"ironMg":0.33,"potassiumMg":281.5},"measure":"Colher De Arroz/Servir: 2"},{"food":"Salada ou verdura crua, exceto de fruta","grams":120,"macros":{"energyKcal":18,"proteinG":0.88,"carbohydrateG":3.92,"fatG":0.2,"fiberG":1.2,"sodiumMg":5,"calciumMg":10,"ironMg":0.27,"potassiumMg":237},"measure":"Escumadeira: 2"}],"time":"12:00"},{"name":"Lanche da tarde","items":[{"food":"Salada de frutas","grams":150,"macros":{"energyKcal":51.24,"proteinG":0.62,"carbohydrateG":13.31,"fatG":0.14,"fiberG":1.68,"sodiumMg":0.82,"calciumMg":15.88,"ironMg":0.16,"potassiumMg":154.02},"measure":"Copo Americano: 1"}],"time":"15:30"},{"name":"Jantar","items":[{"food":"Omelete simples","grams":195,"macros":{"energyKcal":171.44,"proteinG":11.72,"carbohydrateG":1.15,"fatG":12.97,"fiberG":0,"sodiumMg":1022.89,"calciumMg":46.5,"ironMg":1.35,"potassiumMg":113.61},"measure":"Unidade com três ovos: 1"},{"food":"Suco de abacaxi","grams":150,"macros":{"energyKcal":53.21,"proteinG":0.36,"carbohydrateG":12.92,"fatG":0.12,"fiberG":0.2,"sodiumMg":2.01,"calciumMg":13.05,"ironMg":0.31,"potassiumMg":130.51},"measure":"Copo Americano: 1"}],"time":"20:30"},{"name":"Ceia","items":[{"food":"Castanha de caju","grams":30,"macros":{"energyKcal":574,"proteinG":15.31,"carbohydrateG":32.69,"fatG":46.35,"fiberG":3,"sodiumMg":16,"calciumMg":45,"ironMg":6,"potassiumMg":565},"measure":"Unidade: 15"}],"time":"22:30"}]},"dimensions":{"approaches":[],"objectives":[],"restrictions":["lactose_free"],"preferences":[],"contexts":["outpatient"]},"rules":{"targets":{"energyKcal":1300},"guidance":["Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar."]}}]$data$::jsonb) loop
    insert into public.plan_templates (organization_id, name, objective, tags, snapshot, created_by, scope, dimensions, rules)
    values (target_organization_id, model->>'name', model->>'objective', (select array(select jsonb_array_elements_text(model->'tags'))), model->'snapshot', actor, 'organization', model->'dimensions', model->'rules')
    on conflict (organization_id, (snapshot->>'dietboxId')) where snapshot ? 'dietboxId' do update set
      name = excluded.name, objective = excluded.objective, tags = excluded.tags, snapshot = excluded.snapshot,
      dimensions = excluded.dimensions, rules = excluded.rules, updated_at = now();
  end loop;
end;
$_$;


ALTER FUNCTION "public"."seed_plan_templates_dietbox"("target_organization_id" "uuid", "target_created_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."seed_practicas_dieteticas"("target_organization_id" "uuid", "target_created_by" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
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
$_$;


ALTER FUNCTION "public"."seed_practicas_dieteticas"("target_organization_id" "uuid", "target_created_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_alert_status"("target_id" "uuid", "target_status" "public"."alert_status") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare target_org uuid;
begin
 select organization_id into target_org from public.adherence_alerts where id=target_id;
 if not private.has_organization_role(target_org,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 if target_status='acknowledged' then update public.adherence_alerts set status=target_status,acknowledged_by=auth.uid(),acknowledged_at=now() where id=target_id;
 elsif target_status='resolved' then update public.adherence_alerts set status=target_status,resolved_by=auth.uid(),resolved_at=now() where id=target_id;
 else raise exception 'Status inválido'; end if;
end; $$;


ALTER FUNCTION "public"."update_alert_status"("target_id" "uuid", "target_status" "public"."alert_status") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."adherence_alerts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "checkin_id" "uuid",
    "kind" "public"."alert_kind" NOT NULL,
    "severity" "public"."alert_severity" NOT NULL,
    "message" "text" NOT NULL,
    "status" "public"."alert_status" DEFAULT 'open'::"public"."alert_status" NOT NULL,
    "detected_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "acknowledged_by" "uuid",
    "acknowledged_at" timestamp with time zone,
    "resolved_by" "uuid",
    "resolved_at" timestamp with time zone
);


ALTER TABLE "public"."adherence_alerts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."anthropometry" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "assessment_id" "uuid",
    "measured_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "weight_kg" numeric(7,3),
    "height_cm" numeric(6,2),
    "body_fat_percent" numeric(5,2),
    "waist_cm" numeric(6,2),
    "notes" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "hip_cm" numeric(6,2),
    "arm_cm" numeric(6,2),
    CONSTRAINT "anthropometry_arm_cm_check" CHECK (("arm_cm" > (0)::numeric)),
    CONSTRAINT "anthropometry_body_fat_percent_check" CHECK ((("body_fat_percent" >= (0)::numeric) AND ("body_fat_percent" <= (100)::numeric))),
    CONSTRAINT "anthropometry_height_cm_check" CHECK (("height_cm" > (0)::numeric)),
    CONSTRAINT "anthropometry_hip_cm_check" CHECK (("hip_cm" > (0)::numeric)),
    CONSTRAINT "anthropometry_waist_cm_check" CHECK (("waist_cm" > (0)::numeric)),
    CONSTRAINT "anthropometry_weight_kg_check" CHECK (("weight_kg" > (0)::numeric))
);


ALTER TABLE "public"."anthropometry" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."appointments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "professional_id" "uuid" NOT NULL,
    "room_id" "uuid",
    "requested_by" "uuid" NOT NULL,
    "status" "public"."appointment_status" DEFAULT 'requested'::"public"."appointment_status" NOT NULL,
    "modality" "public"."appointment_modality" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "external_meeting_url" "text",
    "location_text" "text",
    "patient_note" "text",
    "staff_note" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "cancellation_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "appointments_check" CHECK (("ends_at" > "starts_at")),
    CONSTRAINT "appointments_check1" CHECK ((("modality" <> 'in_person'::"public"."appointment_modality") OR ("room_id" IS NOT NULL) OR ("location_text" IS NOT NULL))),
    CONSTRAINT "appointments_check2" CHECK ((("status" <> ALL (ARRAY['approved'::"public"."appointment_status", 'rejected'::"public"."appointment_status"])) OR (("reviewed_by" IS NOT NULL) AND ("reviewed_at" IS NOT NULL)))),
    CONSTRAINT "appointments_online_link_when_approved" CHECK ((("status" <> 'approved'::"public"."appointment_status") OR ("modality" <> 'online'::"public"."appointment_modality") OR (NULLIF(TRIM(BOTH FROM "external_meeting_url"), ''::"text") IS NOT NULL)))
);


ALTER TABLE "public"."appointments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."assessments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "professional_id" "uuid" NOT NULL,
    "assessed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "objective" "text",
    "food_preferences" "text",
    "food_restrictions" "text",
    "allergies" "text",
    "clinical_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."assessments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_events" (
    "id" bigint NOT NULL,
    "organization_id" "uuid",
    "actor_id" "uuid",
    "action" "text" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_events" OWNER TO "postgres";


ALTER TABLE "public"."audit_events" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."audit_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."consultation_summaries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "summary" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "consultation_summaries_summary_check" CHECK ((("char_length"(TRIM(BOTH FROM "summary")) >= 2) AND ("char_length"(TRIM(BOTH FROM "summary")) <= 4000)))
);


ALTER TABLE "public"."consultation_summaries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."content_library_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "content_type" "text" NOT NULL,
    "tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "content_library_items_content_type_check" CHECK (("content_type" = ANY (ARRAY['guidance'::"text", 'recipe'::"text", 'education'::"text", 'protocol'::"text"]))),
    CONSTRAINT "content_library_items_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'archived'::"text"]))),
    CONSTRAINT "content_library_items_title_check" CHECK ((("char_length"(TRIM(BOTH FROM "title")) >= 2) AND ("char_length"(TRIM(BOTH FROM "title")) <= 160)))
);


ALTER TABLE "public"."content_library_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."equivalency_list_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "equivalency_list_id" "uuid" NOT NULL,
    "food_id" "uuid",
    "description" "text" NOT NULL,
    "grams" numeric(12,4) NOT NULL,
    "household_measure" "text",
    "calories_per_portion" numeric(10,2) DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "equivalency_list_items_grams_check" CHECK (("grams" > (0)::numeric))
);


ALTER TABLE "public"."equivalency_list_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."equivalency_lists" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "title" "text" NOT NULL,
    "macro_group" "text" NOT NULL,
    "target_calories" numeric(10,2) NOT NULL,
    "calorie_tolerance_pct" numeric(5,2) DEFAULT 15 NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "equivalency_lists_calorie_tolerance_pct_check" CHECK (("calorie_tolerance_pct" >= (0)::numeric)),
    CONSTRAINT "equivalency_lists_target_calories_check" CHECK (("target_calories" >= (0)::numeric)),
    CONSTRAINT "equivalency_lists_title_check" CHECK (("char_length"(TRIM(BOTH FROM "title")) >= 2))
);


ALTER TABLE "public"."equivalency_lists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "professional_id" "uuid" NOT NULL,
    "anonymous_code" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "birth_date" "date",
    "email" "text",
    "phone" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "patient_user_id" "uuid",
    "tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "patients_full_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "full_name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "full_name")) <= 160))),
    CONSTRAINT "patients_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."patients" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."follow_up_queue" WITH ("security_invoker"='true') AS
 SELECT "a"."id",
    "a"."organization_id",
    "a"."patient_id",
    "p"."full_name" AS "patient_name",
    "a"."checkin_id",
    "a"."kind",
    "a"."severity",
    "a"."message",
    "a"."status",
    "a"."detected_at",
        CASE
            WHEN ("a"."status" = 'resolved'::"public"."alert_status") THEN 0
            WHEN ("a"."message" ~~* '%ajuda%'::"text") THEN 100
            WHEN (("a"."kind" = 'severe_symptom'::"public"."alert_kind") AND ("a"."severity" = 'urgent'::"public"."alert_severity")) THEN 95
            WHEN ("a"."kind" = 'severe_symptom'::"public"."alert_kind") THEN 90
            WHEN (("a"."kind" = 'low_intake'::"public"."alert_kind") AND ("a"."message" ~~* '%pulada%'::"text") AND ("count"(*) FILTER (WHERE (("a"."kind" = 'low_intake'::"public"."alert_kind") AND ("a"."message" ~~* '%pulada%'::"text"))) OVER (PARTITION BY "a"."patient_id") > 1)) THEN 80
            WHEN (("a"."kind" = 'low_intake'::"public"."alert_kind") AND ("a"."message" ~~* '%pulada%'::"text")) THEN 75
            WHEN ("a"."kind" = 'other'::"public"."alert_kind") THEN 70
            WHEN ("a"."kind" = ANY (ARRAY['intense_hunger'::"public"."alert_kind", 'low_intake'::"public"."alert_kind"])) THEN 60
            ELSE 10
        END AS "priority_score"
   FROM ("public"."adherence_alerts" "a"
     JOIN "public"."patients" "p" ON (("p"."id" = "a"."patient_id")))
  WHERE ("a"."status" <> 'resolved'::"public"."alert_status");


ALTER VIEW "public"."follow_up_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."food_components" (
    "parent_food_id" "uuid" NOT NULL,
    "component_food_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "grams" numeric(12,3) NOT NULL,
    "position" smallint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "food_components_check" CHECK (("parent_food_id" <> "component_food_id")),
    CONSTRAINT "food_components_grams_check" CHECK (("grams" > (0)::numeric)),
    CONSTRAINT "food_components_position_check" CHECK (("position" >= 0))
);


ALTER TABLE "public"."food_components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."food_nutrient_values" (
    "food_id" "uuid" NOT NULL,
    "nutrient_id" "uuid" NOT NULL,
    "amount_per_100g" numeric(18,6),
    "source_basis" "text" DEFAULT '100g_edible'::"text" NOT NULL,
    "data_version" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "food_nutrient_values_amount_per_100g_check" CHECK (("amount_per_100g" >= (0)::numeric)),
    CONSTRAINT "food_nutrient_values_source_basis_check" CHECK (("source_basis" = '100g_edible'::"text"))
);


ALTER TABLE "public"."food_nutrient_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."food_sources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "license_name" "text" NOT NULL,
    "license_url" "text",
    "attribution_text" "text" NOT NULL,
    "dataset_version" "text" NOT NULL,
    "released_on" "date",
    "imported_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."food_sources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."food_user_preferences" (
    "user_id" "uuid" NOT NULL,
    "food_id" "uuid" NOT NULL,
    "is_favorite" boolean DEFAULT false NOT NULL,
    "last_used_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."food_user_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."foods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "source_id" "uuid",
    "source_food_code" "text",
    "name" "text" NOT NULL,
    "preparation_state" "text" DEFAULT 'unspecified'::"text" NOT NULL,
    "edible_portion_pct" numeric(5,2) DEFAULT 100 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "catalog_kind" "public"."catalog_kind" DEFAULT 'food'::"public"."catalog_kind" NOT NULL,
    "yield_grams" numeric(12,3),
    "serving_grams" numeric(12,3),
    "render_path" "text",
    "source_reference" "text",
    "source_accessed_on" "date",
    "source_reliability" smallint,
    "review_status" "text" DEFAULT 'pending_review'::"text" NOT NULL,
    "reviewed_at" timestamp with time zone,
    "reviewed_by" "uuid",
    "search_terms" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "cultural_tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "restriction_tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "preference_tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "availability_tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "cost_band" "text",
    "household_measure_label" "text",
    "household_measure_grams" numeric(12,3),
    "portion_count" numeric(12,3),
    "diet_tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "foods_check" CHECK (((("organization_id" IS NULL) AND ("source_id" IS NOT NULL) AND ("created_by" IS NULL)) OR (("organization_id" IS NOT NULL) AND ("created_by" IS NOT NULL)))),
    CONSTRAINT "foods_composite_yield_check" CHECK (((("catalog_kind" = 'food'::"public"."catalog_kind") AND ("yield_grams" IS NULL)) OR (("catalog_kind" = ANY (ARRAY['preparation'::"public"."catalog_kind", 'combination'::"public"."catalog_kind"])) AND ("yield_grams" IS NOT NULL)))),
    CONSTRAINT "foods_cost_band_check" CHECK (("cost_band" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text"]))),
    CONSTRAINT "foods_edible_portion_pct_check" CHECK ((("edible_portion_pct" > (0)::numeric) AND ("edible_portion_pct" <= (100)::numeric))),
    CONSTRAINT "foods_household_measure_complete" CHECK (((("household_measure_label" IS NULL) AND ("household_measure_grams" IS NULL)) OR (("length"(TRIM(BOTH FROM "household_measure_label")) > 0) AND ("household_measure_grams" IS NOT NULL)))),
    CONSTRAINT "foods_household_measure_grams_check" CHECK ((("household_measure_grams" IS NULL) OR ("household_measure_grams" > (0)::numeric))),
    CONSTRAINT "foods_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "name")) <= 180))),
    CONSTRAINT "foods_portion_count_check" CHECK ((("portion_count" IS NULL) OR ("portion_count" > (0)::numeric))),
    CONSTRAINT "foods_render_path_webp" CHECK ((("render_path" IS NULL) OR ("render_path" ~ '^/food-renders/[a-z0-9][a-z0-9-]*\\.webp$'::"text"))),
    CONSTRAINT "foods_review_status_check" CHECK (("review_status" = ANY (ARRAY['pending_review'::"text", 'reviewed'::"text", 'rejected'::"text"]))),
    CONSTRAINT "foods_serving_grams_check" CHECK ((("serving_grams" IS NULL) OR ("serving_grams" > (0)::numeric))),
    CONSTRAINT "foods_source_reliability_check" CHECK ((("source_reliability" >= 1) AND ("source_reliability" <= 5))),
    CONSTRAINT "foods_yield_grams_check" CHECK ((("yield_grams" IS NULL) OR ("yield_grams" > (0)::numeric)))
);


ALTER TABLE "public"."foods" OWNER TO "postgres";


COMMENT ON COLUMN "public"."foods"."render_path" IS 'Caminho público de render WebP curado e versionado no repositório, por exemplo /food-renders/arroz-integral.webp.';



CREATE TABLE IF NOT EXISTS "public"."form_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "version_id" "uuid" NOT NULL,
    "status" "public"."form_assignment_status" DEFAULT 'pending'::"public"."form_assignment_status" NOT NULL,
    "assigned_by" "uuid" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "submitted_at" timestamp with time zone
);


ALTER TABLE "public"."form_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."form_fields" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "version_id" "uuid" NOT NULL,
    "position" integer NOT NULL,
    "label" "text" NOT NULL,
    "field_type" "public"."form_field_type" NOT NULL,
    "required" boolean DEFAULT false NOT NULL,
    "options" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    CONSTRAINT "form_fields_label_check" CHECK ((("char_length"(TRIM(BOTH FROM "label")) >= 2) AND ("char_length"(TRIM(BOTH FROM "label")) <= 160)))
);


ALTER TABLE "public"."form_fields" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."form_template_versions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "template_id" "uuid" NOT NULL,
    "version_no" integer NOT NULL,
    "title" "text" NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "published_by" "uuid" NOT NULL
);


ALTER TABLE "public"."form_template_versions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."form_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "purpose" "text" DEFAULT 'pre_consultation'::"text" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "form_templates_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "name")) <= 120))),
    CONSTRAINT "form_templates_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."form_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lab_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "assessment_id" "uuid",
    "collected_on" "date" NOT NULL,
    "test_name" "text" NOT NULL,
    "result_value" numeric,
    "unit" "text",
    "reference_range" "text",
    "notes" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "attachment_name" "text",
    "attachment_url" "text",
    CONSTRAINT "lab_results_attachment_complete" CHECK (((("attachment_name" IS NULL) AND ("attachment_url" IS NULL)) OR (("attachment_name" IS NOT NULL) AND ("attachment_url" IS NOT NULL)))),
    CONSTRAINT "lab_results_attachment_name_check" CHECK ((("attachment_name" IS NULL) OR (("char_length"(TRIM(BOTH FROM "attachment_name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "attachment_name")) <= 180)))),
    CONSTRAINT "lab_results_attachment_url_check" CHECK ((("attachment_url" IS NULL) OR ("attachment_url" ~ '^https?://'::"text"))),
    CONSTRAINT "lab_results_test_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "test_name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "test_name")) <= 160)))
);


ALTER TABLE "public"."lab_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meal_checkin_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "meal_checkin_id" "uuid" NOT NULL,
    "meal_id" "uuid" NOT NULL,
    "occurred_on" "date" NOT NULL,
    "drive_file_id" "text" NOT NULL,
    "drive_web_url" "text",
    "file_name" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "meal_checkin_photos_drive_file_id_check" CHECK (("char_length"(TRIM(BOTH FROM "drive_file_id")) > 3)),
    CONSTRAINT "meal_checkin_photos_file_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "file_name")) >= 6) AND ("char_length"(TRIM(BOTH FROM "file_name")) <= 180)))
);


ALTER TABLE "public"."meal_checkin_photos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meal_checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "plan_version_id" "uuid" NOT NULL,
    "meal_id" "uuid" NOT NULL,
    "occurred_on" "date" DEFAULT CURRENT_DATE NOT NULL,
    "state" "public"."checkin_state" NOT NULL,
    "hunger_before" smallint,
    "satiety_after" smallint,
    "mood" smallint,
    "energy" smallint,
    "sleep_quality" smallint,
    "reaction_suspected" boolean DEFAULT false NOT NULL,
    "symptoms" "text",
    "note" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "symptom_intensity" smallint,
    "help_requested" boolean DEFAULT false NOT NULL,
    "substitution_request_id" "uuid",
    CONSTRAINT "meal_checkins_energy_check" CHECK ((("energy" >= 0) AND ("energy" <= 10))),
    CONSTRAINT "meal_checkins_hunger_before_check" CHECK ((("hunger_before" >= 0) AND ("hunger_before" <= 10))),
    CONSTRAINT "meal_checkins_mood_check" CHECK ((("mood" >= 0) AND ("mood" <= 10))),
    CONSTRAINT "meal_checkins_satiety_after_check" CHECK ((("satiety_after" >= 0) AND ("satiety_after" <= 10))),
    CONSTRAINT "meal_checkins_sleep_quality_check" CHECK ((("sleep_quality" >= 0) AND ("sleep_quality" <= 10))),
    CONSTRAINT "meal_checkins_symptom_intensity_check" CHECK ((("symptom_intensity" >= 0) AND ("symptom_intensity" <= 10)))
);


ALTER TABLE "public"."meal_checkins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meal_item_substitutions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "plan_version_id" "uuid" NOT NULL,
    "meal_item_id" "uuid" NOT NULL,
    "substitute_food_id" "uuid",
    "description" "text" NOT NULL,
    "grams" numeric(12,4) NOT NULL,
    "unit" "text" DEFAULT 'g'::"text" NOT NULL,
    "professional_note" "text",
    "nutrient_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "meal_item_substitutions_description_check" CHECK ((("char_length"(TRIM(BOTH FROM "description")) >= 2) AND ("char_length"(TRIM(BOTH FROM "description")) <= 180))),
    CONSTRAINT "meal_item_substitutions_grams_check" CHECK (("grams" > (0)::numeric)),
    CONSTRAINT "meal_item_substitutions_nutrient_snapshot_check" CHECK (("jsonb_typeof"("nutrient_snapshot") = 'object'::"text")),
    CONSTRAINT "meal_item_substitutions_professional_note_check" CHECK ((("professional_note" IS NULL) OR ("char_length"("professional_note") <= 500))),
    CONSTRAINT "meal_item_substitutions_unit_check" CHECK (("unit" = ANY (ARRAY['g'::"text", 'ml'::"text", 'unit'::"text", 'portion'::"text"])))
);


ALTER TABLE "public"."meal_item_substitutions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meal_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "meal_id" "uuid" NOT NULL,
    "position" integer NOT NULL,
    "food_id" "uuid",
    "description" "text" NOT NULL,
    "quantity" numeric(12,4) NOT NULL,
    "unit" "text" NOT NULL,
    "grams" numeric(12,4) NOT NULL,
    "nutrient_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "notes" "text",
    CONSTRAINT "meal_items_grams_check" CHECK (("grams" > (0)::numeric)),
    CONSTRAINT "meal_items_nutrient_snapshot_check" CHECK (("jsonb_typeof"("nutrient_snapshot") = 'object'::"text")),
    CONSTRAINT "meal_items_position_check" CHECK (("position" >= 0)),
    CONSTRAINT "meal_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "meal_items_unit_check" CHECK (("unit" = ANY (ARRAY['g'::"text", 'ml'::"text", 'unit'::"text", 'portion'::"text"])))
);


ALTER TABLE "public"."meal_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "plan_day_id" "uuid" NOT NULL,
    "position" integer NOT NULL,
    "label" "text" NOT NULL,
    "suggested_time" time without time zone,
    "equivalency_list_id" "uuid",
    "notes" "text",
    CONSTRAINT "meals_notes_check" CHECK ((("notes" IS NULL) OR ("char_length"("notes") <= 2000))),
    CONSTRAINT "meals_position_check" CHECK (("position" >= 0))
);


ALTER TABLE "public"."meals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."organization_role" NOT NULL,
    "status" "public"."membership_status" DEFAULT 'active'::"public"."membership_status" NOT NULL,
    "supervisor_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "memberships_check" CHECK ((("role" = 'student'::"public"."organization_role") OR ("supervisor_id" IS NULL))),
    CONSTRAINT "memberships_check1" CHECK ((("supervisor_id" IS NULL) OR ("supervisor_id" <> "user_id")))
);


ALTER TABLE "public"."memberships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nutrients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "unit" "text" NOT NULL,
    "decimals" smallint DEFAULT 2 NOT NULL,
    "sort_order" smallint DEFAULT 0 NOT NULL,
    CONSTRAINT "nutrients_decimals_check" CHECK ((("decimals" >= 0) AND ("decimals" <= 6))),
    CONSTRAINT "nutrients_unit_check" CHECK (("unit" = ANY (ARRAY['kcal'::"text", 'kJ'::"text", 'g'::"text", 'mg'::"text", 'µg'::"text", 'mcg'::"text"])))
);


ALTER TABLE "public"."nutrients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nutritional_estimates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "protocol" "text" NOT NULL,
    "current_weight_kg" numeric NOT NULL,
    "height_cm" numeric NOT NULL,
    "age_years" integer NOT NULL,
    "biological_sex" "text" NOT NULL,
    "activity_factor" numeric NOT NULL,
    "basal_metabolic_rate" numeric NOT NULL,
    "total_energy_expenditure" numeric NOT NULL,
    "calculated_on" timestamp with time zone DEFAULT "now"() NOT NULL,
    "notes" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "nutritional_estimates_activity_factor_check" CHECK (("activity_factor" >= (1)::numeric)),
    CONSTRAINT "nutritional_estimates_age_years_check" CHECK (("age_years" >= 0)),
    CONSTRAINT "nutritional_estimates_basal_metabolic_rate_check" CHECK (("basal_metabolic_rate" >= (0)::numeric)),
    CONSTRAINT "nutritional_estimates_biological_sex_check" CHECK (("biological_sex" = ANY (ARRAY['female'::"text", 'male'::"text"]))),
    CONSTRAINT "nutritional_estimates_current_weight_kg_check" CHECK (("current_weight_kg" > (0)::numeric)),
    CONSTRAINT "nutritional_estimates_height_cm_check" CHECK (("height_cm" > (0)::numeric)),
    CONSTRAINT "nutritional_estimates_protocol_check" CHECK (("protocol" = ANY (ARRAY['harris_benedict'::"text", 'mifflin_st_jeor'::"text", 'eer_iom'::"text", 'tinsley'::"text"]))),
    CONSTRAINT "nutritional_estimates_total_energy_expenditure_check" CHECK (("total_energy_expenditure" >= (0)::numeric))
);


ALTER TABLE "public"."nutritional_estimates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_branding" (
    "organization_id" "uuid" NOT NULL,
    "public_name" "text" NOT NULL,
    "primary_color" "text" DEFAULT '#3e6b5c'::"text" NOT NULL,
    "logo_url" "text",
    "updated_by" "uuid" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "organization_branding_primary_color_check" CHECK (("primary_color" ~ '^#[0-9A-Fa-f]{6}$'::"text")),
    CONSTRAINT "organization_branding_public_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "public_name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "public_name")) <= 120)))
);


ALTER TABLE "public"."organization_branding" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_drive_configs" (
    "organization_id" "uuid" NOT NULL,
    "status" "public"."drive_connection_status" DEFAULT 'missing'::"public"."drive_connection_status" NOT NULL,
    "root_folder_id" "text",
    "connected_by" "uuid",
    "connected_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "organization_drive_configs_check" CHECK (((("status" = 'missing'::"public"."drive_connection_status") AND ("root_folder_id" IS NULL)) OR (("status" = 'connected'::"public"."drive_connection_status") AND (NULLIF(TRIM(BOTH FROM "root_folder_id"), ''::"text") IS NOT NULL))))
);


ALTER TABLE "public"."organization_drive_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "organizations_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "name")) <= 120))),
    CONSTRAINT "organizations_slug_check" CHECK (("slug" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text"))
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patient_consents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "consent_type" "text" NOT NULL,
    "document_version" "text" NOT NULL,
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone,
    "recorded_by" "uuid" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "patient_consents_check" CHECK ((("revoked_at" IS NULL) OR ("revoked_at" >= "granted_at"))),
    CONSTRAINT "patient_consents_consent_type_check" CHECK (("consent_type" = ANY (ARRAY['care'::"text", 'data_processing'::"text", 'guardian'::"text"])))
);


ALTER TABLE "public"."patient_consents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patient_goals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "kind" "public"."patient_goal_kind" NOT NULL,
    "title" "text" NOT NULL,
    "target_value" numeric,
    "target_unit" "text",
    "starts_on" "date" DEFAULT CURRENT_DATE NOT NULL,
    "ends_on" "date",
    "active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "patient_goals_check" CHECK ((("ends_on" IS NULL) OR ("ends_on" >= "starts_on"))),
    CONSTRAINT "patient_goals_title_check" CHECK ((("char_length"(TRIM(BOTH FROM "title")) >= 2) AND ("char_length"(TRIM(BOTH FROM "title")) <= 160)))
);


ALTER TABLE "public"."patient_goals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patient_guardians" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "guardian_user_id" "uuid" NOT NULL,
    "relationship" "text" NOT NULL,
    "can_view_plan" boolean DEFAULT true NOT NULL,
    "can_manage_appointments" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."patient_guardians" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patient_water_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "occurred_on" "date" DEFAULT CURRENT_DATE NOT NULL,
    "amount_ml" integer NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "patient_water_logs_amount_ml_check" CHECK ((("amount_ml" >= 1) AND ("amount_ml" <= 10000)))
);


ALTER TABLE "public"."patient_water_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plan_days" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "plan_version_id" "uuid" NOT NULL,
    "day_index" integer NOT NULL,
    "label" "text" NOT NULL,
    "kind" "public"."day_kind" DEFAULT 'standard'::"public"."day_kind" NOT NULL,
    "weekday" smallint,
    CONSTRAINT "plan_days_day_index_check" CHECK (("day_index" >= 0)),
    CONSTRAINT "plan_days_weekday_check" CHECK ((("weekday" >= 0) AND ("weekday" <= 6)))
);


ALTER TABLE "public"."plan_days" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plan_versions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "version_no" integer NOT NULL,
    "change_summary" "text",
    "created_by" "uuid" NOT NULL,
    "ai_generated" boolean DEFAULT false NOT NULL,
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "targets" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "content_hash" "text",
    "locked_at" timestamp with time zone,
    "published_at" timestamp with time zone,
    "assistant_state" "jsonb" DEFAULT '{"objective": "", "currentStep": "objective", "completedSteps": []}'::"jsonb" NOT NULL,
    CONSTRAINT "plan_versions_assistant_state_check" CHECK (("jsonb_typeof"("assistant_state") = 'object'::"text")),
    CONSTRAINT "plan_versions_targets_check" CHECK (("jsonb_typeof"("targets") = 'object'::"text")),
    CONSTRAINT "plan_versions_version_no_check" CHECK (("version_no" > 0))
);


ALTER TABLE "public"."plan_versions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "full_name" "text" NOT NULL,
    "display_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "profiles_full_name_check" CHECK ((("char_length"(TRIM(BOTH FROM "full_name")) >= 2) AND ("char_length"(TRIM(BOTH FROM "full_name")) <= 120)))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."rooms" OWNER TO "postgres";


ALTER TABLE ONLY "public"."adherence_alerts"
    ADD CONSTRAINT "adherence_alerts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."anthropometry"
    ADD CONSTRAINT "anthropometry_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_professional_no_overlap" EXCLUDE USING "gist" ("professional_id" WITH =, "tstzrange"("starts_at", "ends_at", '[)'::"text") WITH &&) WHERE (("status" = 'approved'::"public"."appointment_status"));



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_room_no_overlap" EXCLUDE USING "gist" ("room_id" WITH =, "tstzrange"("starts_at", "ends_at", '[)'::"text") WITH &&) WHERE ((("status" = 'approved'::"public"."appointment_status") AND ("room_id" IS NOT NULL)));



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_id_organization_unique" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clinical_drafts"
    ADD CONSTRAINT "clinical_drafts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."consultation_summaries"
    ADD CONSTRAINT "consultation_summaries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."content_library_items"
    ADD CONSTRAINT "content_library_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."content_library_versions"
    ADD CONSTRAINT "content_library_versions_item_id_version_no_key" UNIQUE ("item_id", "version_no");



ALTER TABLE ONLY "public"."content_library_versions"
    ADD CONSTRAINT "content_library_versions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."equivalency_list_items"
    ADD CONSTRAINT "equivalency_list_items_equivalency_list_id_position_key" UNIQUE ("equivalency_list_id", "position");



ALTER TABLE ONLY "public"."equivalency_list_items"
    ADD CONSTRAINT "equivalency_list_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."equivalency_lists"
    ADD CONSTRAINT "equivalency_lists_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."follow_up_actions"
    ADD CONSTRAINT "follow_up_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."food_components"
    ADD CONSTRAINT "food_components_pkey" PRIMARY KEY ("parent_food_id", "component_food_id");



ALTER TABLE ONLY "public"."food_nutrient_values"
    ADD CONSTRAINT "food_nutrient_values_pkey" PRIMARY KEY ("food_id", "nutrient_id");



ALTER TABLE ONLY "public"."food_sources"
    ADD CONSTRAINT "food_sources_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."food_sources"
    ADD CONSTRAINT "food_sources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."food_user_preferences"
    ADD CONSTRAINT "food_user_preferences_pkey" PRIMARY KEY ("user_id", "food_id");



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_assignments"
    ADD CONSTRAINT "form_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_fields"
    ADD CONSTRAINT "form_fields_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_fields"
    ADD CONSTRAINT "form_fields_version_id_position_key" UNIQUE ("version_id", "position");



ALTER TABLE ONLY "public"."form_responses"
    ADD CONSTRAINT "form_responses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_template_versions"
    ADD CONSTRAINT "form_template_versions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_template_versions"
    ADD CONSTRAINT "form_template_versions_template_id_version_no_key" UNIQUE ("template_id", "version_no");



ALTER TABLE ONLY "public"."form_templates"
    ADD CONSTRAINT "form_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lab_results"
    ADD CONSTRAINT "lab_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_meal_checkin_id_key" UNIQUE ("meal_checkin_id");



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_patient_id_meal_id_occurred_on_key" UNIQUE ("patient_id", "meal_id", "occurred_on");



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_meal_item_id_substitute_food_id_key" UNIQUE ("meal_item_id", "substitute_food_id");



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meal_items"
    ADD CONSTRAINT "meal_items_id_organization_unique" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."meal_items"
    ADD CONSTRAINT "meal_items_meal_id_position_key" UNIQUE ("meal_id", "position");



ALTER TABLE ONLY "public"."meal_items"
    ADD CONSTRAINT "meal_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_plan_day_id_position_key" UNIQUE ("plan_day_id", "position");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_organization_id_user_id_key" UNIQUE ("organization_id", "user_id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nutrients"
    ADD CONSTRAINT "nutrients_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."nutrients"
    ADD CONSTRAINT "nutrients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nutritional_estimates"
    ADD CONSTRAINT "nutritional_estimates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_branding"
    ADD CONSTRAINT "organization_branding_pkey" PRIMARY KEY ("organization_id");



ALTER TABLE ONLY "public"."organization_drive_configs"
    ADD CONSTRAINT "organization_drive_configs_pkey" PRIMARY KEY ("organization_id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."patient_consents"
    ADD CONSTRAINT "patient_consents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patient_content_deliveries"
    ADD CONSTRAINT "patient_content_deliveries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patient_goals"
    ADD CONSTRAINT "patient_goals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patient_guardians"
    ADD CONSTRAINT "patient_guardians_patient_id_guardian_user_id_key" UNIQUE ("patient_id", "guardian_user_id");



ALTER TABLE ONLY "public"."patient_guardians"
    ADD CONSTRAINT "patient_guardians_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patient_water_logs"
    ADD CONSTRAINT "patient_water_logs_patient_id_occurred_on_key" UNIQUE ("patient_id", "occurred_on");



ALTER TABLE ONLY "public"."patient_water_logs"
    ADD CONSTRAINT "patient_water_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_id_organization_unique" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_organization_id_anonymous_code_key" UNIQUE ("organization_id", "anonymous_code");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plan_days"
    ADD CONSTRAINT "plan_days_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."plan_days"
    ADD CONSTRAINT "plan_days_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plan_days"
    ADD CONSTRAINT "plan_days_plan_version_id_day_index_key" UNIQUE ("plan_version_id", "day_index");



ALTER TABLE ONLY "public"."plan_templates"
    ADD CONSTRAINT "plan_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_plan_id_version_no_key" UNIQUE ("plan_id", "version_no");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_organization_id_name_key" UNIQUE ("organization_id", "name");



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_id_organization_id_key" UNIQUE ("id", "organization_id");



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_pkey" PRIMARY KEY ("id");



CREATE INDEX "adherence_alerts_org_status_idx" ON "public"."adherence_alerts" USING "btree" ("organization_id", "status", "detected_at" DESC);



CREATE INDEX "anthropometry_patient_idx" ON "public"."anthropometry" USING "btree" ("patient_id", "measured_at" DESC);



CREATE INDEX "appointments_org_status_start_idx" ON "public"."appointments" USING "btree" ("organization_id", "status", "starts_at");



CREATE INDEX "appointments_patient_start_idx" ON "public"."appointments" USING "btree" ("patient_id", "starts_at");



CREATE INDEX "assessments_patient_idx" ON "public"."assessments" USING "btree" ("patient_id", "assessed_at" DESC);



CREATE INDEX "audit_events_org_idx" ON "public"."audit_events" USING "btree" ("organization_id", "created_at" DESC);



CREATE INDEX "clinical_drafts_patient_idx" ON "public"."clinical_drafts" USING "btree" ("patient_id", "created_at" DESC);



CREATE INDEX "content_library_items_org_status_idx" ON "public"."content_library_items" USING "btree" ("organization_id", "status", "updated_at" DESC);



CREATE INDEX "equivalency_list_items_list_idx" ON "public"."equivalency_list_items" USING "btree" ("equivalency_list_id", "position");



CREATE INDEX "equivalency_lists_org_idx" ON "public"."equivalency_lists" USING "btree" ("organization_id") WHERE "is_active";



CREATE INDEX "follow_up_actions_alert_idx" ON "public"."follow_up_actions" USING "btree" ("alert_id", "created_at" DESC);



CREATE INDEX "follow_up_actions_org_idx" ON "public"."follow_up_actions" USING "btree" ("organization_id", "created_at" DESC);



CREATE INDEX "food_components_component_idx" ON "public"."food_components" USING "btree" ("component_food_id");



CREATE INDEX "food_components_organization_idx" ON "public"."food_components" USING "btree" ("organization_id");



CREATE INDEX "food_nutrients_food_idx" ON "public"."food_nutrient_values" USING "btree" ("food_id");



CREATE INDEX "food_user_preferences_recent_idx" ON "public"."food_user_preferences" USING "btree" ("user_id", "last_used_at" DESC NULLS LAST);



CREATE INDEX "foods_availability_tags_idx" ON "public"."foods" USING "gin" ("availability_tags");



CREATE INDEX "foods_cultural_tags_idx" ON "public"."foods" USING "gin" ("cultural_tags");



CREATE INDEX "foods_diet_tags_idx" ON "public"."foods" USING "gin" ("diet_tags");



CREATE UNIQUE INDEX "foods_global_source_unique" ON "public"."foods" USING "btree" ("source_id", "source_food_code") WHERE ("organization_id" IS NULL);



CREATE UNIQUE INDEX "foods_org_name_state_unique" ON "public"."foods" USING "btree" ("organization_id", "lower"("name"), "preparation_state") WHERE ("organization_id" IS NOT NULL);



CREATE INDEX "foods_preference_tags_idx" ON "public"."foods" USING "gin" ("preference_tags");



CREATE INDEX "foods_restriction_tags_idx" ON "public"."foods" USING "gin" ("restriction_tags");



CREATE INDEX "foods_search_idx" ON "public"."foods" USING "btree" ("lower"("name"));



CREATE INDEX "foods_search_terms_idx" ON "public"."foods" USING "gin" ("search_terms");



CREATE UNIQUE INDEX "form_responses_one_per_assignment" ON "public"."form_responses" USING "btree" ("assignment_id");



CREATE INDEX "lab_results_patient_collected_idx" ON "public"."lab_results" USING "btree" ("patient_id", "collected_on" DESC);



CREATE INDEX "meal_checkins_patient_date_idx" ON "public"."meal_checkins" USING "btree" ("patient_id", "occurred_on" DESC);



CREATE INDEX "meal_items_meal_idx" ON "public"."meal_items" USING "btree" ("meal_id", "position");



CREATE INDEX "meals_day_idx" ON "public"."meals" USING "btree" ("plan_day_id", "position");



CREATE INDEX "memberships_user_idx" ON "public"."memberships" USING "btree" ("user_id", "status");



CREATE INDEX "nutritional_estimates_patient_calculated_idx" ON "public"."nutritional_estimates" USING "btree" ("patient_id", "calculated_on" DESC);



CREATE UNIQUE INDEX "one_open_substitution_request" ON "public"."substitution_requests" USING "btree" ("patient_id", "meal_item_id") WHERE ("status" = 'requested'::"public"."substitution_request_status");



CREATE INDEX "patient_consents_active_idx" ON "public"."patient_consents" USING "btree" ("patient_id", "granted_at" DESC) WHERE ("revoked_at" IS NULL);



CREATE INDEX "patient_content_deliveries_patient_idx" ON "public"."patient_content_deliveries" USING "btree" ("patient_id", "delivered_at" DESC);



CREATE INDEX "patient_goals_patient_active_idx" ON "public"."patient_goals" USING "btree" ("patient_id", "active", "starts_on" DESC);



CREATE INDEX "patient_water_logs_patient_day_idx" ON "public"."patient_water_logs" USING "btree" ("patient_id", "occurred_on" DESC);



CREATE INDEX "patients_org_idx" ON "public"."patients" USING "btree" ("organization_id", "status");



CREATE UNIQUE INDEX "patients_org_user_unique" ON "public"."patients" USING "btree" ("organization_id", "patient_user_id") WHERE ("patient_user_id" IS NOT NULL);



CREATE INDEX "patients_professional_idx" ON "public"."patients" USING "btree" ("professional_id");



CREATE INDEX "patients_tags_idx" ON "public"."patients" USING "gin" ("tags");



CREATE INDEX "plan_days_version_idx" ON "public"."plan_days" USING "btree" ("plan_version_id", "day_index");



CREATE UNIQUE INDEX "plan_templates_org_catalog_key_unique" ON "public"."plan_templates" USING "btree" ("organization_id", "catalog_key") WHERE ("catalog_key" IS NOT NULL);



CREATE UNIQUE INDEX "plan_templates_org_dietbox_id_key" ON "public"."plan_templates" USING "btree" ("organization_id", (("snapshot" ->> 'dietboxId'::"text"))) WHERE ("snapshot" ? 'dietboxId'::"text");



CREATE INDEX "plan_templates_status_idx" ON "public"."plan_templates" USING "btree" ("organization_id", "status", "name");



CREATE INDEX "plan_versions_plan_idx" ON "public"."plan_versions" USING "btree" ("plan_id", "version_no" DESC);



CREATE INDEX "plans_patient_idx" ON "public"."plans" USING "btree" ("organization_id", "patient_id", "status");



CREATE INDEX "substitution_requests_org_status_idx" ON "public"."substitution_requests" USING "btree" ("organization_id", "status", "created_at" DESC);



CREATE INDEX "substitution_requests_patient_idx" ON "public"."substitution_requests" USING "btree" ("patient_id", "created_at" DESC);



CREATE INDEX "substitutions_version_idx" ON "public"."meal_item_substitutions" USING "btree" ("plan_version_id", "meal_item_id") WHERE "is_active";



CREATE OR REPLACE TRIGGER "appointments_status_guard" BEFORE UPDATE ON "public"."appointments" FOR EACH ROW EXECUTE FUNCTION "private"."guard_appointment_status"();



CREATE OR REPLACE TRIGGER "appointments_updated_at" BEFORE UPDATE ON "public"."appointments" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "assessments_set_updated_at" BEFORE UPDATE ON "public"."assessments" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "checkins_create_alert" AFTER INSERT ON "public"."meal_checkins" FOR EACH ROW EXECUTE FUNCTION "private"."create_checkin_alert"();



CREATE OR REPLACE TRIGGER "checkins_validate" BEFORE INSERT OR UPDATE ON "public"."meal_checkins" FOR EACH ROW EXECUTE FUNCTION "private"."validate_checkin_chain"();



CREATE OR REPLACE TRIGGER "content_library_versions_immutable" BEFORE DELETE OR UPDATE ON "public"."content_library_versions" FOR EACH ROW EXECUTE FUNCTION "private"."prevent_content_version_mutation"();



CREATE OR REPLACE TRIGGER "days_lock_guard" BEFORE INSERT OR DELETE OR UPDATE ON "public"."plan_days" FOR EACH ROW EXECUTE FUNCTION "private"."guard_version_mutation"();



CREATE OR REPLACE TRIGGER "drive_configs_updated_at" BEFORE UPDATE ON "public"."organization_drive_configs" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "food_components_validate_integrity" BEFORE INSERT OR UPDATE OF "parent_food_id", "component_food_id", "organization_id" ON "public"."food_components" FOR EACH ROW EXECUTE FUNCTION "private"."validate_food_component_integrity"();



CREATE OR REPLACE TRIGGER "foods_set_review_metadata" BEFORE INSERT OR UPDATE OF "review_status", "reviewed_at", "reviewed_by" ON "public"."foods" FOR EACH ROW EXECUTE FUNCTION "private"."set_catalog_review_metadata"();



CREATE OR REPLACE TRIGGER "foods_set_updated_at" BEFORE UPDATE ON "public"."foods" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "items_lock_guard" BEFORE INSERT OR DELETE OR UPDATE ON "public"."meal_items" FOR EACH ROW EXECUTE FUNCTION "private"."guard_version_mutation"();



CREATE OR REPLACE TRIGGER "meal_checkins_updated_at" BEFORE UPDATE ON "public"."meal_checkins" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "meal_checkins_validate_substitution" BEFORE INSERT OR UPDATE OF "substitution_request_id", "organization_id", "patient_id", "plan_version_id", "meal_id" ON "public"."meal_checkins" FOR EACH ROW EXECUTE FUNCTION "private"."validate_checkin_substitution"();



CREATE OR REPLACE TRIGGER "meal_items_validate_food" BEFORE INSERT OR UPDATE ON "public"."meal_items" FOR EACH ROW EXECUTE FUNCTION "private"."validate_meal_item_food_tenant"();



CREATE OR REPLACE TRIGGER "meals_lock_guard" BEFORE INSERT OR DELETE OR UPDATE ON "public"."meals" FOR EACH ROW EXECUTE FUNCTION "private"."guard_version_mutation"();



CREATE OR REPLACE TRIGGER "memberships_set_updated_at" BEFORE UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "organizations_bootstrap_owner" AFTER INSERT ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "private"."bootstrap_owner_membership"();



CREATE OR REPLACE TRIGGER "organizations_set_updated_at" BEFORE UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "patients_guard_self_claim" BEFORE UPDATE ON "public"."patients" FOR EACH ROW EXECUTE FUNCTION "private"."guard_patient_self_claim"();



CREATE OR REPLACE TRIGGER "patients_set_updated_at" BEFORE UPDATE ON "public"."patients" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "plan_templates_auto_approve_own" BEFORE INSERT ON "public"."plan_templates" FOR EACH ROW EXECUTE FUNCTION "private"."auto_approve_own_plan_template"();



CREATE OR REPLACE TRIGGER "plans_set_updated_at" BEFORE UPDATE ON "public"."plans" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "plans_workflow_guard" BEFORE UPDATE ON "public"."plans" FOR EACH ROW EXECUTE FUNCTION "private"."guard_plan_workflow"();



CREATE OR REPLACE TRIGGER "profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "substitution_request_workflow" BEFORE UPDATE ON "public"."substitution_requests" FOR EACH ROW EXECUTE FUNCTION "private"."guard_substitution_request_workflow"();



CREATE OR REPLACE TRIGGER "substitution_requests_updated_at" BEFORE UPDATE ON "public"."substitution_requests" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "substitution_requests_validate" BEFORE INSERT OR UPDATE OF "organization_id", "patient_id", "plan_version_id", "meal_item_id", "substitution_id" ON "public"."substitution_requests" FOR EACH ROW EXECUTE FUNCTION "private"."validate_substitution_request_chain"();



CREATE OR REPLACE TRIGGER "substitutions_lock_guard" BEFORE INSERT OR DELETE OR UPDATE ON "public"."meal_item_substitutions" FOR EACH ROW EXECUTE FUNCTION "private"."guard_published_substitution"();



CREATE OR REPLACE TRIGGER "substitutions_updated_at" BEFORE UPDATE ON "public"."meal_item_substitutions" FOR EACH ROW EXECUTE FUNCTION "private"."set_updated_at"();



CREATE OR REPLACE TRIGGER "substitutions_validate" BEFORE INSERT OR UPDATE ON "public"."meal_item_substitutions" FOR EACH ROW EXECUTE FUNCTION "private"."validate_substitution_chain"();



CREATE OR REPLACE TRIGGER "versions_lock_guard" BEFORE DELETE OR UPDATE ON "public"."plan_versions" FOR EACH ROW EXECUTE FUNCTION "private"."guard_version_mutation"();



CREATE OR REPLACE TRIGGER "versions_snapshot_substitutions" BEFORE UPDATE OF "locked_at" ON "public"."plan_versions" FOR EACH ROW EXECUTE FUNCTION "private"."snapshot_substitutions_on_publication"();



ALTER TABLE ONLY "public"."adherence_alerts"
    ADD CONSTRAINT "adherence_alerts_acknowledged_by_fkey" FOREIGN KEY ("acknowledged_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."adherence_alerts"
    ADD CONSTRAINT "adherence_alerts_checkin_id_organization_id_fkey" FOREIGN KEY ("checkin_id", "organization_id") REFERENCES "public"."meal_checkins"("id", "organization_id") ON DELETE SET NULL ("checkin_id");



ALTER TABLE ONLY "public"."adherence_alerts"
    ADD CONSTRAINT "adherence_alerts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."adherence_alerts"
    ADD CONSTRAINT "adherence_alerts_patient_id_organization_id_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."adherence_alerts"
    ADD CONSTRAINT "adherence_alerts_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."anthropometry"
    ADD CONSTRAINT "anthropometry_assessment_tenant_fkey" FOREIGN KEY ("assessment_id", "organization_id") REFERENCES "public"."assessments"("id", "organization_id") ON DELETE SET NULL ("assessment_id");



ALTER TABLE ONLY "public"."anthropometry"
    ADD CONSTRAINT "anthropometry_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."anthropometry"
    ADD CONSTRAINT "anthropometry_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."anthropometry"
    ADD CONSTRAINT "anthropometry_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_patient_id_organization_id_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_professional_id_fkey" FOREIGN KEY ("professional_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_room_id_organization_id_fkey" FOREIGN KEY ("room_id", "organization_id") REFERENCES "public"."rooms"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_professional_id_fkey" FOREIGN KEY ("professional_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."clinical_drafts"
    ADD CONSTRAINT "clinical_drafts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."clinical_drafts"
    ADD CONSTRAINT "clinical_drafts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clinical_drafts"
    ADD CONSTRAINT "clinical_drafts_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clinical_drafts"
    ADD CONSTRAINT "clinical_drafts_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."consultation_summaries"
    ADD CONSTRAINT "consultation_summaries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."consultation_summaries"
    ADD CONSTRAINT "consultation_summaries_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."consultation_summaries"
    ADD CONSTRAINT "consultation_summaries_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."content_library_items"
    ADD CONSTRAINT "content_library_items_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."content_library_items"
    ADD CONSTRAINT "content_library_items_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."content_library_versions"
    ADD CONSTRAINT "content_library_versions_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."content_library_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."content_library_versions"
    ADD CONSTRAINT "content_library_versions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."content_library_versions"
    ADD CONSTRAINT "content_library_versions_published_by_fkey" FOREIGN KEY ("published_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."equivalency_list_items"
    ADD CONSTRAINT "equivalency_list_items_equivalency_list_id_fkey" FOREIGN KEY ("equivalency_list_id") REFERENCES "public"."equivalency_lists"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."equivalency_list_items"
    ADD CONSTRAINT "equivalency_list_items_food_id_fkey" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."equivalency_lists"
    ADD CONSTRAINT "equivalency_lists_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."equivalency_lists"
    ADD CONSTRAINT "equivalency_lists_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."follow_up_actions"
    ADD CONSTRAINT "follow_up_actions_alert_id_fkey" FOREIGN KEY ("alert_id") REFERENCES "public"."adherence_alerts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."follow_up_actions"
    ADD CONSTRAINT "follow_up_actions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."follow_up_actions"
    ADD CONSTRAINT "follow_up_actions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."follow_up_actions"
    ADD CONSTRAINT "follow_up_actions_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_components"
    ADD CONSTRAINT "food_components_component_food_id_fkey" FOREIGN KEY ("component_food_id") REFERENCES "public"."foods"("id");



ALTER TABLE ONLY "public"."food_components"
    ADD CONSTRAINT "food_components_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_components"
    ADD CONSTRAINT "food_components_parent_food_id_fkey" FOREIGN KEY ("parent_food_id") REFERENCES "public"."foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_nutrient_values"
    ADD CONSTRAINT "food_nutrient_values_food_id_fkey" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_nutrient_values"
    ADD CONSTRAINT "food_nutrient_values_nutrient_id_fkey" FOREIGN KEY ("nutrient_id") REFERENCES "public"."nutrients"("id");



ALTER TABLE ONLY "public"."food_user_preferences"
    ADD CONSTRAINT "food_user_preferences_food_id_fkey" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_user_preferences"
    ADD CONSTRAINT "food_user_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "public"."food_sources"("id");



ALTER TABLE ONLY "public"."form_assignments"
    ADD CONSTRAINT "form_assignments_assigned_by_fkey" FOREIGN KEY ("assigned_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."form_assignments"
    ADD CONSTRAINT "form_assignments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_assignments"
    ADD CONSTRAINT "form_assignments_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_assignments"
    ADD CONSTRAINT "form_assignments_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "public"."form_template_versions"("id");



ALTER TABLE ONLY "public"."form_fields"
    ADD CONSTRAINT "form_fields_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_fields"
    ADD CONSTRAINT "form_fields_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "public"."form_template_versions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_responses"
    ADD CONSTRAINT "form_responses_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "public"."form_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_responses"
    ADD CONSTRAINT "form_responses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."form_responses"
    ADD CONSTRAINT "form_responses_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_responses"
    ADD CONSTRAINT "form_responses_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_responses"
    ADD CONSTRAINT "form_responses_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "public"."form_template_versions"("id");



ALTER TABLE ONLY "public"."form_template_versions"
    ADD CONSTRAINT "form_template_versions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_template_versions"
    ADD CONSTRAINT "form_template_versions_published_by_fkey" FOREIGN KEY ("published_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."form_template_versions"
    ADD CONSTRAINT "form_template_versions_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."form_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_templates"
    ADD CONSTRAINT "form_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."form_templates"
    ADD CONSTRAINT "form_templates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lab_results"
    ADD CONSTRAINT "lab_results_assessment_tenant_fkey" FOREIGN KEY ("assessment_id", "organization_id") REFERENCES "public"."assessments"("id", "organization_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."lab_results"
    ADD CONSTRAINT "lab_results_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."lab_results"
    ADD CONSTRAINT "lab_results_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lab_results"
    ADD CONSTRAINT "lab_results_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_meal_checkin_id_organization_id_fkey" FOREIGN KEY ("meal_checkin_id", "organization_id") REFERENCES "public"."meal_checkins"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_meal_id_organization_id_fkey" FOREIGN KEY ("meal_id", "organization_id") REFERENCES "public"."meals"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_checkin_photos"
    ADD CONSTRAINT "meal_checkin_photos_patient_id_organization_id_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_meal_id_organization_id_fkey" FOREIGN KEY ("meal_id", "organization_id") REFERENCES "public"."meals"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_patient_id_organization_id_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_plan_version_id_organization_id_fkey" FOREIGN KEY ("plan_version_id", "organization_id") REFERENCES "public"."plan_versions"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meal_checkins"
    ADD CONSTRAINT "meal_checkins_substitution_request_id_fkey" FOREIGN KEY ("substitution_request_id") REFERENCES "public"."substitution_requests"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_meal_item_id_organization_id_fkey" FOREIGN KEY ("meal_item_id", "organization_id") REFERENCES "public"."meal_items"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_plan_version_id_organization_id_fkey" FOREIGN KEY ("plan_version_id", "organization_id") REFERENCES "public"."plan_versions"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meal_item_substitutions"
    ADD CONSTRAINT "meal_item_substitutions_substitute_food_id_fkey" FOREIGN KEY ("substitute_food_id") REFERENCES "public"."foods"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meal_items"
    ADD CONSTRAINT "meal_items_food_id_fkey" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id");



ALTER TABLE ONLY "public"."meal_items"
    ADD CONSTRAINT "meal_items_meal_id_organization_id_fkey" FOREIGN KEY ("meal_id", "organization_id") REFERENCES "public"."meals"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meal_items"
    ADD CONSTRAINT "meal_items_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_equivalency_list_id_fkey" FOREIGN KEY ("equivalency_list_id") REFERENCES "public"."equivalency_lists"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_plan_day_id_organization_id_fkey" FOREIGN KEY ("plan_day_id", "organization_id") REFERENCES "public"."plan_days"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nutritional_estimates"
    ADD CONSTRAINT "nutritional_estimates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."nutritional_estimates"
    ADD CONSTRAINT "nutritional_estimates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nutritional_estimates"
    ADD CONSTRAINT "nutritional_estimates_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_branding"
    ADD CONSTRAINT "organization_branding_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_branding"
    ADD CONSTRAINT "organization_branding_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."organization_drive_configs"
    ADD CONSTRAINT "organization_drive_configs_connected_by_fkey" FOREIGN KEY ("connected_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."organization_drive_configs"
    ADD CONSTRAINT "organization_drive_configs_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."patient_consents"
    ADD CONSTRAINT "patient_consents_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_consents"
    ADD CONSTRAINT "patient_consents_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_consents"
    ADD CONSTRAINT "patient_consents_recorded_by_fkey" FOREIGN KEY ("recorded_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."patient_content_deliveries"
    ADD CONSTRAINT "patient_content_deliveries_content_version_id_fkey" FOREIGN KEY ("content_version_id") REFERENCES "public"."content_library_versions"("id");



ALTER TABLE ONLY "public"."patient_content_deliveries"
    ADD CONSTRAINT "patient_content_deliveries_delivered_by_fkey" FOREIGN KEY ("delivered_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."patient_content_deliveries"
    ADD CONSTRAINT "patient_content_deliveries_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_content_deliveries"
    ADD CONSTRAINT "patient_content_deliveries_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_goals"
    ADD CONSTRAINT "patient_goals_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."patient_goals"
    ADD CONSTRAINT "patient_goals_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_goals"
    ADD CONSTRAINT "patient_goals_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_guardians"
    ADD CONSTRAINT "patient_guardians_guardian_user_id_fkey" FOREIGN KEY ("guardian_user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_guardians"
    ADD CONSTRAINT "patient_guardians_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_guardians"
    ADD CONSTRAINT "patient_guardians_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_water_logs"
    ADD CONSTRAINT "patient_water_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."patient_water_logs"
    ADD CONSTRAINT "patient_water_logs_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patient_water_logs"
    ADD CONSTRAINT "patient_water_logs_patient_tenant_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_patient_user_id_fkey" FOREIGN KEY ("patient_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_professional_id_fkey" FOREIGN KEY ("professional_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plan_days"
    ADD CONSTRAINT "plan_days_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_days"
    ADD CONSTRAINT "plan_days_plan_version_id_organization_id_fkey" FOREIGN KEY ("plan_version_id", "organization_id") REFERENCES "public"."plan_versions"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_templates"
    ADD CONSTRAINT "plan_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plan_templates"
    ADD CONSTRAINT "plan_templates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_templates"
    ADD CONSTRAINT "plan_templates_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plan_templates"
    ADD CONSTRAINT "plan_templates_source_plan_id_fkey" FOREIGN KEY ("source_plan_id") REFERENCES "public"."plans"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_plan_id_organization_id_fkey" FOREIGN KEY ("plan_id", "organization_id") REFERENCES "public"."plans"("id", "organization_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_versions"
    ADD CONSTRAINT "plan_versions_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_current_version_tenant_fkey" FOREIGN KEY ("current_published_version_id", "organization_id") REFERENCES "public"."plan_versions"("id", "organization_id") ON DELETE SET NULL ("current_published_version_id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_patient_id_organization_id_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_published_by_fkey" FOREIGN KEY ("published_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_meal_item_id_organization_id_fkey" FOREIGN KEY ("meal_item_id", "organization_id") REFERENCES "public"."meal_items"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_patient_id_organization_id_fkey" FOREIGN KEY ("patient_id", "organization_id") REFERENCES "public"."patients"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_plan_version_id_organization_id_fkey" FOREIGN KEY ("plan_version_id", "organization_id") REFERENCES "public"."plan_versions"("id", "organization_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."substitution_requests"
    ADD CONSTRAINT "substitution_requests_substitution_id_organization_id_fkey" FOREIGN KEY ("substitution_id", "organization_id") REFERENCES "public"."meal_item_substitutions"("id", "organization_id") ON DELETE RESTRICT;



CREATE POLICY "Equivalency list items accessible when list accessible" ON "public"."equivalency_list_items" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."equivalency_lists" "l"
  WHERE (("l"."id" = "equivalency_list_items"."equivalency_list_id") AND (("l"."organization_id" IS NULL) OR "private"."has_organization_role"("l"."organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (EXISTS ( SELECT 1
           FROM "public"."patients" "p"
          WHERE (("p"."organization_id" = "l"."organization_id") AND "private"."can_access_patient"("p"."id")))))))));



CREATE POLICY "Equivalency list items modifiable when list modifiable" ON "public"."equivalency_list_items" USING ((EXISTS ( SELECT 1
   FROM "public"."equivalency_lists" "l"
  WHERE (("l"."id" = "equivalency_list_items"."equivalency_list_id") AND ("l"."organization_id" IS NOT NULL) AND "private"."has_organization_role"("l"."organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"])))));



CREATE POLICY "Equivalency lists accessible by tenant members or global" ON "public"."equivalency_lists" FOR SELECT USING ((("organization_id" IS NULL) OR "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (EXISTS ( SELECT 1
   FROM "public"."patients" "p"
  WHERE (("p"."organization_id" = "equivalency_lists"."organization_id") AND "private"."can_access_patient"("p"."id"))))));



CREATE POLICY "Equivalency lists modifiable by professional roles" ON "public"."equivalency_lists" USING ((("organization_id" IS NOT NULL) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"])));



ALTER TABLE "public"."adherence_alerts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "alerts_select_clinical" ON "public"."adherence_alerts" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "alerts_update_clinical" ON "public"."adherence_alerts" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."anthropometry" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "anthropometry_delete_admin_or_nutritionist" ON "public"."anthropometry" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "anthropometry_insert_clinical_team" ON "public"."anthropometry" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("created_by" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "anthropometry_select_clinical_team" ON "public"."anthropometry" FOR SELECT TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "anthropometry_update_clinical_team" ON "public"."anthropometry" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."appointments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "appointments_insert" ON "public"."appointments" FOR INSERT TO "authenticated" WITH CHECK ((("status" = 'requested'::"public"."appointment_status") AND ("requested_by" = ( SELECT "auth"."uid"() AS "uid")) AND ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'receptionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR "private"."can_manage_patient_appointments"("patient_id"))));



CREATE POLICY "appointments_select" ON "public"."appointments" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'receptionist'::"public"."organization_role"]) OR ("professional_id" = ( SELECT "auth"."uid"() AS "uid")) OR "private"."can_manage_patient_appointments"("patient_id")));



CREATE POLICY "appointments_update" ON "public"."appointments" FOR UPDATE TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'receptionist'::"public"."organization_role"]) OR ("professional_id" = ( SELECT "auth"."uid"() AS "uid")) OR "private"."can_manage_patient_appointments"("patient_id"))) WITH CHECK (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'receptionist'::"public"."organization_role"]) OR ("professional_id" = ( SELECT "auth"."uid"() AS "uid")) OR "private"."can_manage_patient_appointments"("patient_id")));



ALTER TABLE "public"."assessments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "assessments_delete_admin_or_nutritionist" ON "public"."assessments" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "assessments_insert_clinical_team" ON "public"."assessments" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("professional_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "assessments_select_clinical_team" ON "public"."assessments" FOR SELECT TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "assessments_update_clinical_team" ON "public"."assessments" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."audit_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit_insert_member" ON "public"."audit_events" FOR INSERT TO "authenticated" WITH CHECK ((("actor_id" = ( SELECT "auth"."uid"() AS "uid")) AND "public"."is_active_member"("organization_id")));



CREATE POLICY "audit_select_admin" ON "public"."audit_events" FOR SELECT TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]));



CREATE POLICY "checkin_photos_insert_patient" ON "public"."meal_checkin_photos" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



CREATE POLICY "checkin_photos_select" ON "public"."meal_checkin_photos" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR "private"."can_access_patient"("patient_id")));



CREATE POLICY "checkins_insert_patient" ON "public"."meal_checkins" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



CREATE POLICY "checkins_select" ON "public"."meal_checkins" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR "private"."can_access_patient"("patient_id")));



CREATE POLICY "checkins_update_patient" ON "public"."meal_checkins" FOR UPDATE TO "authenticated" USING ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id") AND ("created_at" > ("now"() - '24:00:00'::interval)))) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



ALTER TABLE "public"."clinical_drafts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clinical_drafts_insert_team" ON "public"."clinical_drafts" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "clinical_drafts_select_team" ON "public"."clinical_drafts" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "clinical_drafts_update_team" ON "public"."clinical_drafts" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."consultation_summaries" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "consultation_summaries_clinical" ON "public"."consultation_summaries" TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



ALTER TABLE "public"."content_library_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "content_library_items_clinical" ON "public"."content_library_items" TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



ALTER TABLE "public"."content_library_versions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "content_library_versions_clinical_insert" ON "public"."content_library_versions" FOR INSERT TO "authenticated" WITH CHECK ((("published_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "content_library_versions_clinical_select" ON "public"."content_library_versions" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "days_delete" ON "public"."plan_days" FOR DELETE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "days_insert" ON "public"."plan_days" FOR INSERT TO "authenticated" WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "days_select" ON "public"."plan_days" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (EXISTS ( SELECT 1
   FROM ("public"."plan_versions" "v"
     JOIN "public"."plans" "p" ON (("p"."current_published_version_id" = "v"."id")))
  WHERE (("v"."id" = "plan_days"."plan_version_id") AND ("p"."status" = ANY (ARRAY['published'::"public"."plan_status", 'scheduled'::"public"."plan_status"])) AND "private"."can_access_patient"("p"."patient_id"))))));



CREATE POLICY "days_update" ON "public"."plan_days" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "drive_configs_select_clinical" ON "public"."organization_drive_configs" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "drive_configs_update_admin" ON "public"."organization_drive_configs" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]));



CREATE POLICY "drive_configs_upsert_admin" ON "public"."organization_drive_configs" FOR INSERT TO "authenticated" WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]));



ALTER TABLE "public"."equivalency_list_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."equivalency_lists" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."follow_up_actions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "follow_up_actions_insert_clinical" ON "public"."follow_up_actions" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "follow_up_actions_select_clinical" ON "public"."follow_up_actions" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."food_components" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "food_components_delete_clinical" ON "public"."food_components" FOR DELETE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "food_components_insert_clinical" ON "public"."food_components" FOR INSERT TO "authenticated" WITH CHECK (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND (EXISTS ( SELECT 1
   FROM "public"."foods" "parent"
  WHERE (("parent"."id" = "food_components"."parent_food_id") AND ("parent"."organization_id" = "food_components"."organization_id") AND ("parent"."catalog_kind" = ANY (ARRAY['preparation'::"public"."catalog_kind", 'combination'::"public"."catalog_kind"]))))) AND (EXISTS ( SELECT 1
   FROM "public"."foods" "component"
  WHERE (("component"."id" = "food_components"."component_food_id") AND (("component"."organization_id" IS NULL) OR ("component"."organization_id" = "food_components"."organization_id")))))));



CREATE POLICY "food_components_read" ON "public"."food_components" FOR SELECT TO "authenticated" USING (("private"."is_active_member"("organization_id") AND (EXISTS ( SELECT 1
   FROM "public"."foods" "parent"
  WHERE (("parent"."id" = "food_components"."parent_food_id") AND ("parent"."organization_id" = "food_components"."organization_id") AND ("parent"."catalog_kind" = ANY (ARRAY['preparation'::"public"."catalog_kind", 'combination'::"public"."catalog_kind"])))))));



CREATE POLICY "food_components_update_clinical" ON "public"."food_components" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND (EXISTS ( SELECT 1
   FROM "public"."foods" "parent"
  WHERE (("parent"."id" = "food_components"."parent_food_id") AND ("parent"."organization_id" = "food_components"."organization_id") AND ("parent"."catalog_kind" = ANY (ARRAY['preparation'::"public"."catalog_kind", 'combination'::"public"."catalog_kind"]))))) AND (EXISTS ( SELECT 1
   FROM "public"."foods" "component"
  WHERE (("component"."id" = "food_components"."component_food_id") AND (("component"."organization_id" IS NULL) OR ("component"."organization_id" = "food_components"."organization_id")))))));



ALTER TABLE "public"."food_nutrient_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."food_sources" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "food_sources_read" ON "public"."food_sources" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."food_user_preferences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "food_user_preferences_own" ON "public"."food_user_preferences" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "food_values_insert_custom" ON "public"."food_nutrient_values" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."foods" "f"
  WHERE (("f"."id" = "food_nutrient_values"."food_id") AND ("f"."organization_id" IS NOT NULL) AND ("f"."created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."is_active_member"("f"."organization_id")))));



CREATE POLICY "food_values_read" ON "public"."food_nutrient_values" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."foods" "f"
  WHERE (("f"."id" = "food_nutrient_values"."food_id") AND (("f"."organization_id" IS NULL) OR "private"."is_active_member"("f"."organization_id"))))));



CREATE POLICY "food_values_update_custom" ON "public"."food_nutrient_values" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."foods" "f"
  WHERE (("f"."id" = "food_nutrient_values"."food_id") AND ("f"."organization_id" IS NOT NULL) AND "private"."has_organization_role"("f"."organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."foods" "f"
  WHERE (("f"."id" = "food_nutrient_values"."food_id") AND ("f"."organization_id" IS NOT NULL) AND "private"."has_organization_role"("f"."organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])))));



ALTER TABLE "public"."foods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "foods_insert_clinical" ON "public"."foods" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" IS NOT NULL) AND ("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "foods_read" ON "public"."foods" FOR SELECT TO "authenticated" USING ((("organization_id" IS NULL) OR "private"."is_active_member"("organization_id")));



CREATE POLICY "foods_update_clinical" ON "public"."foods" FOR UPDATE TO "authenticated" USING ((("organization_id" IS NOT NULL) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]))) WITH CHECK ((("organization_id" IS NOT NULL) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



ALTER TABLE "public"."form_assignments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_assignments_insert_clinical" ON "public"."form_assignments" FOR INSERT TO "authenticated" WITH CHECK ((("assigned_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "form_assignments_select" ON "public"."form_assignments" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR "private"."can_access_patient"("patient_id")));



CREATE POLICY "form_assignments_update_patient" ON "public"."form_assignments" FOR UPDATE TO "authenticated" USING (("private"."can_access_patient"("patient_id") OR "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]))) WITH CHECK (("private"."can_access_patient"("patient_id") OR "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



ALTER TABLE "public"."form_fields" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_fields_clinical" ON "public"."form_fields" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (EXISTS ( SELECT 1
   FROM "public"."form_assignments" "a"
  WHERE (("a"."version_id" = "form_fields"."version_id") AND "private"."can_access_patient"("a"."patient_id"))))));



CREATE POLICY "form_fields_insert_clinical" ON "public"."form_fields" FOR INSERT TO "authenticated" WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."form_responses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_responses_insert_patient" ON "public"."form_responses" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



CREATE POLICY "form_responses_select" ON "public"."form_responses" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR "private"."can_access_patient"("patient_id")));



CREATE POLICY "form_responses_update_patient" ON "public"."form_responses" FOR UPDATE TO "authenticated" USING ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id") AND ("status" <> 'submitted'::"public"."form_assignment_status"))) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



ALTER TABLE "public"."form_template_versions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."form_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_templates_clinical" ON "public"."form_templates" TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "form_versions_clinical" ON "public"."form_template_versions" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "form_versions_insert_clinical" ON "public"."form_template_versions" FOR INSERT TO "authenticated" WITH CHECK ((("published_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "guardians_delete_clinical_team" ON "public"."patient_guardians" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "guardians_insert_clinical_team" ON "public"."patient_guardians" FOR INSERT TO "authenticated" WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "guardians_select_clinical_or_self" ON "public"."patient_guardians" FOR SELECT TO "authenticated" USING ((("guardian_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "guardians_update_clinical_team" ON "public"."patient_guardians" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "items_delete" ON "public"."meal_items" FOR DELETE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "items_insert" ON "public"."meal_items" FOR INSERT TO "authenticated" WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "items_select" ON "public"."meal_items" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (EXISTS ( SELECT 1
   FROM ((("public"."meals" "m"
     JOIN "public"."plan_days" "d" ON (("d"."id" = "m"."plan_day_id")))
     JOIN "public"."plan_versions" "v" ON (("v"."id" = "d"."plan_version_id")))
     JOIN "public"."plans" "p" ON (("p"."current_published_version_id" = "v"."id")))
  WHERE (("m"."id" = "meal_items"."meal_id") AND ("p"."status" = ANY (ARRAY['published'::"public"."plan_status", 'scheduled'::"public"."plan_status"])) AND "private"."can_access_patient"("p"."patient_id"))))));



CREATE POLICY "items_update" ON "public"."meal_items" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."lab_results" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "lab_results_delete_admin_or_nutritionist" ON "public"."lab_results" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "lab_results_insert_clinical_team" ON "public"."lab_results" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("created_by" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "lab_results_select_clinical_team" ON "public"."lab_results" FOR SELECT TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "lab_results_update_clinical_team" ON "public"."lab_results" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."meal_checkin_photos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meal_checkins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meal_item_substitutions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meal_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "meals_delete" ON "public"."meals" FOR DELETE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "meals_insert" ON "public"."meals" FOR INSERT TO "authenticated" WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "meals_select" ON "public"."meals" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (EXISTS ( SELECT 1
   FROM (("public"."plan_days" "d"
     JOIN "public"."plan_versions" "v" ON (("v"."id" = "d"."plan_version_id")))
     JOIN "public"."plans" "p" ON (("p"."current_published_version_id" = "v"."id")))
  WHERE (("d"."id" = "meals"."plan_day_id") AND ("p"."status" = ANY (ARRAY['published'::"public"."plan_status", 'scheduled'::"public"."plan_status"])) AND "private"."can_access_patient"("p"."patient_id"))))));



CREATE POLICY "meals_update" ON "public"."meals" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."memberships" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "memberships_delete_admin" ON "public"."memberships" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]));



CREATE POLICY "memberships_insert_admin_or_bootstrap" ON "public"."memberships" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]) OR (("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("role" = 'owner'::"public"."organization_role") AND (EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "memberships"."organization_id") AND ("o"."created_by" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "memberships_select_member" ON "public"."memberships" FOR SELECT TO "authenticated" USING ("public"."is_active_member"("organization_id"));



CREATE POLICY "memberships_update_admin" ON "public"."memberships" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]));



ALTER TABLE "public"."nutrients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nutrients_read" ON "public"."nutrients" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."nutritional_estimates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nutritional_estimates_delete_admin_or_nutritionist" ON "public"."nutritional_estimates" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "nutritional_estimates_insert_clinical_team" ON "public"."nutritional_estimates" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("created_by" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "nutritional_estimates_select_clinical_team" ON "public"."nutritional_estimates" FOR SELECT TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "nutritional_estimates_update_clinical_team" ON "public"."nutritional_estimates" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."organization_branding" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "organization_branding_admin_write" ON "public"."organization_branding" TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"])) WITH CHECK ((("updated_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"])));



CREATE POLICY "organization_branding_member_read" ON "public"."organization_branding" FOR SELECT TO "authenticated" USING (("public"."is_active_member"("organization_id") OR (EXISTS ( SELECT 1
   FROM "public"."patients" "p"
  WHERE (("p"."organization_id" = "organization_branding"."organization_id") AND "private"."can_access_patient"("p"."id"))))));



ALTER TABLE "public"."organization_drive_configs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "organizations_insert_authenticated" ON "public"."organizations" FOR INSERT TO "authenticated" WITH CHECK (("created_by" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "organizations_select_member" ON "public"."organizations" FOR SELECT TO "authenticated" USING ("public"."is_active_member"("id"));



CREATE POLICY "organizations_update_admin" ON "public"."organizations" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role"]));



ALTER TABLE "public"."patient_consents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patient_consents_delete_admin_or_nutritionist" ON "public"."patient_consents" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "patient_consents_insert_clinical_team" ON "public"."patient_consents" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("recorded_by" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "patient_consents_select_clinical_team" ON "public"."patient_consents" FOR SELECT TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "patient_consents_update_clinical_team" ON "public"."patient_consents" FOR UPDATE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."patient_content_deliveries" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patient_content_deliveries_clinical" ON "public"."patient_content_deliveries" TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ((("delivered_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "patient_content_deliveries_patient_select" ON "public"."patient_content_deliveries" FOR SELECT TO "authenticated" USING ("private"."can_access_patient"("patient_id"));



ALTER TABLE "public"."patient_goals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patient_goals_clinical" ON "public"."patient_goals" TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "patient_goals_patient_select" ON "public"."patient_goals" FOR SELECT TO "authenticated" USING ("private"."can_access_patient"("patient_id"));



ALTER TABLE "public"."patient_guardians" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."patient_water_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patient_water_logs_clinical_select" ON "public"."patient_water_logs" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "patient_water_logs_patient_insert" ON "public"."patient_water_logs" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



CREATE POLICY "patient_water_logs_patient_select" ON "public"."patient_water_logs" FOR SELECT TO "authenticated" USING ("private"."can_access_patient"("patient_id"));



CREATE POLICY "patient_water_logs_patient_update" ON "public"."patient_water_logs" FOR UPDATE TO "authenticated" USING ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id"))) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."can_access_patient"("patient_id")));



ALTER TABLE "public"."patients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patients_delete_admin_or_nutritionist" ON "public"."patients" FOR DELETE TO "authenticated" USING ("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role"]));



CREATE POLICY "patients_insert_clinical_team" ON "public"."patients" FOR INSERT TO "authenticated" WITH CHECK (("public"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("created_by" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "patients_select_clinical_team" ON "public"."patients" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR ("patient_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (("patient_user_id" IS NULL) AND (NULLIF(TRIM(BOTH FROM COALESCE("email", ''::"text")), ''::"text") IS NOT NULL) AND ("lower"("email") = "lower"(COALESCE((( SELECT "auth"."jwt"() AS "jwt") ->> 'email'::"text"), ''::"text"))))));



CREATE POLICY "patients_update_clinical_team" ON "public"."patients" FOR UPDATE TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (("patient_user_id" IS NULL) AND (NULLIF(TRIM(BOTH FROM COALESCE("email", ''::"text")), ''::"text") IS NOT NULL) AND ("lower"("email") = "lower"(COALESCE((( SELECT "auth"."jwt"() AS "jwt") ->> 'email'::"text"), ''::"text")))))) WITH CHECK (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR ("patient_user_id" = ( SELECT "auth"."uid"() AS "uid"))));



ALTER TABLE "public"."plan_days" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plan_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "plan_templates_clinical" ON "public"."plan_templates" TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND (("scope" = 'organization'::"public"."plan_template_scope") OR ("created_by" = ( SELECT "auth"."uid"() AS "uid"))))) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) AND ("scope" = ANY (ARRAY['personal'::"public"."plan_template_scope", 'organization'::"public"."plan_template_scope"]))));



ALTER TABLE "public"."plan_versions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "plans_insert_clinical" ON "public"."plans" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "plans_read_clinical" ON "public"."plans" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (("status" = ANY (ARRAY['published'::"public"."plan_status", 'scheduled'::"public"."plan_status"])) AND ("current_published_version_id" IS NOT NULL) AND "private"."can_access_patient"("patient_id"))));



CREATE POLICY "plans_update_clinical" ON "public"."plans" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_self" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "profiles_select_self_or_colleague" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM ("public"."memberships" "mine"
     JOIN "public"."memberships" "theirs" ON (("theirs"."organization_id" = "mine"."organization_id")))
  WHERE (("mine"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("mine"."status" = 'active'::"public"."membership_status") AND ("theirs"."user_id" = "profiles"."id"))))));



CREATE POLICY "profiles_update_self" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."rooms" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "rooms_delete_admin" ON "public"."rooms" FOR DELETE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'receptionist'::"public"."organization_role"]));



CREATE POLICY "rooms_insert_admin" ON "public"."rooms" FOR INSERT TO "authenticated" WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'receptionist'::"public"."organization_role"]));



CREATE POLICY "rooms_select_staff" ON "public"."rooms" FOR SELECT TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'receptionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "rooms_update_admin" ON "public"."rooms" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'receptionist'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'receptionist'::"public"."organization_role"]));



ALTER TABLE "public"."substitution_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "substitution_requests_insert" ON "public"."substitution_requests" FOR INSERT TO "authenticated" WITH CHECK ((("requested_by" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'requested'::"public"."substitution_request_status") AND ("reviewed_by" IS NULL) AND ("reviewed_at" IS NULL) AND "private"."can_access_patient"("patient_id")));



CREATE POLICY "substitution_requests_review" ON "public"."substitution_requests" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "substitution_requests_select" ON "public"."substitution_requests" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR "private"."can_access_patient"("patient_id")));



CREATE POLICY "substitutions_insert" ON "public"."meal_item_substitutions" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "substitutions_select" ON "public"."meal_item_substitutions" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR ("is_active" AND (EXISTS ( SELECT 1
   FROM "public"."plans" "p"
  WHERE (("p"."current_published_version_id" = "meal_item_substitutions"."plan_version_id") AND ("p"."status" = ANY (ARRAY['published'::"public"."plan_status", 'scheduled'::"public"."plan_status"])) AND "private"."can_access_patient"("p"."patient_id")))))));



CREATE POLICY "substitutions_update" ON "public"."meal_item_substitutions" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "versions_delete" ON "public"."plan_versions" FOR DELETE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));



CREATE POLICY "versions_insert" ON "public"."plan_versions" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) AND "private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])));



CREATE POLICY "versions_select" ON "public"."plan_versions" FOR SELECT TO "authenticated" USING (("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]) OR (("locked_at" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."plans" "p"
  WHERE (("p"."current_published_version_id" = "plan_versions"."id") AND ("p"."status" = ANY (ARRAY['published'::"public"."plan_status", 'scheduled'::"public"."plan_status"])) AND "private"."can_access_patient"("p"."patient_id")))))));



CREATE POLICY "versions_update" ON "public"."plan_versions" FOR UPDATE TO "authenticated" USING ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"])) WITH CHECK ("private"."has_organization_role"("organization_id", ARRAY['owner'::"public"."organization_role", 'admin'::"public"."organization_role", 'nutritionist'::"public"."organization_role", 'student'::"public"."organization_role"]));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "private" TO "authenticated";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
















































































































































































































































































































































































































































































































































































































































































































































REVOKE ALL ON FUNCTION "private"."auto_approve_own_plan_template"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."bootstrap_owner_membership"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."can_access_patient"("target_patient_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_access_patient"("target_patient_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "private"."can_manage_patient_appointments"("target_patient_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_manage_patient_appointments"("target_patient_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "private"."guard_version_mutation"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "private"."is_active_member"("target_organization_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."is_active_member"("target_organization_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "private"."plan_assistant_has_steps"("target_state" "jsonb", "required_steps" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."plan_assistant_has_steps"("target_state" "jsonb", "required_steps" "text"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "private"."plan_target_value"("targets" "jsonb", "keys" "text"[]) FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."validate_version_ready"("target_version_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."validate_version_ready"("target_version_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "private"."version_is_locked"("target_version_id" "uuid") FROM PUBLIC;



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plans" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."plans" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plans" TO "service_role";



REVOKE ALL ON FUNCTION "public"."apply_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer, "target_weekdays" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."apply_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer, "target_weekdays" "text"[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."audit_clinical_export"("target_patient_id" "uuid", "target_kind" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."autosave_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."autosave_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."bootstrap_organization"("full_name_input" "text", "organization_name_input" "text", "organization_slug_input" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."bootstrap_organization"("full_name_input" "text", "organization_name_input" "text", "organization_slug_input" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."cancel_appointment"("target_id" "uuid", "reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_appointment"("target_id" "uuid", "reason" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."claim_patient_access"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_patient_access"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."copy_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer, "target_weekdays" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."copy_plan_template_to_patient"("target_template_id" "uuid", "target_patient_id" "uuid", "target_days" integer, "target_weekdays" "text"[]) TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."follow_up_actions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."follow_up_actions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."follow_up_actions" TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_follow_up_action"("target_alert_id" "uuid", "target_action" "text", "target_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_follow_up_action"("target_alert_id" "uuid", "target_action" "text", "target_note" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_patient_intake"("target_organization_id" "uuid", "full_name_input" "text", "email_input" "text", "phone_input" "text", "birth_date_input" "date", "tags_input" "text"[], "objective_input" "text", "food_preferences_input" "text", "food_restrictions_input" "text", "allergies_input" "text", "clinical_notes_input" "text", "weight_kg_input" numeric, "height_cm_input" numeric, "waist_cm_input" numeric, "hip_cm_input" numeric, "arm_cm_input" numeric, "body_fat_percent_input" numeric, "measured_at_input" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_patient_intake"("target_organization_id" "uuid", "full_name_input" "text", "email_input" "text", "phone_input" "text", "birth_date_input" "date", "tags_input" "text"[], "objective_input" "text", "food_preferences_input" "text", "food_restrictions_input" "text", "allergies_input" "text", "clinical_notes_input" "text", "weight_kg_input" numeric, "height_cm_input" numeric, "waist_cm_input" numeric, "hip_cm_input" numeric, "arm_cm_input" numeric, "body_fat_percent_input" numeric, "measured_at_input" timestamp with time zone) TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plan_templates" TO "anon";
GRANT ALL ON TABLE "public"."plan_templates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plan_templates" TO "service_role";



GRANT ALL ON FUNCTION "public"."create_plan_template_from_plan"("target_plan_id" "uuid", "target_name" "text", "target_objective" "text", "target_tags" "text"[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_plan_template_from_plan_v2"("target_plan_id" "uuid", "target_name" "text", "target_scope" "public"."plan_template_scope", "target_dimensions" "jsonb", "target_rules" "jsonb") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_content_deliveries" TO "anon";
GRANT ALL ON TABLE "public"."patient_content_deliveries" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_content_deliveries" TO "service_role";



GRANT ALL ON FUNCTION "public"."deliver_content_to_patient"("target_version_id" "uuid", "target_patient_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_current_shopping_list"("target_patient_id" "uuid", "target_days" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_current_shopping_list"("target_patient_id" "uuid", "target_days" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_patient_drive_status"("target_patient_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_patient_drive_status"("target_patient_id" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."get_patient_weekly_summary"("target_patient_id" "uuid", "target_days" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."has_organization_role"("target_organization_id" "uuid", "allowed_roles" "public"."organization_role"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."import_catalog_foods"("target_organization_id" "uuid", "target_source_id" "uuid", "target_items" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_catalog_foods"("target_organization_id" "uuid", "target_source_id" "uuid", "target_items" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."is_active_member"("target_organization_id" "uuid") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."content_library_versions" TO "anon";
GRANT ALL ON TABLE "public"."content_library_versions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."content_library_versions" TO "service_role";



GRANT ALL ON FUNCTION "public"."publish_content_library_version"("target_item_id" "uuid", "target_body" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."publish_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."publish_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."review_appointment"("target_id" "uuid", "target_status" "public"."appointment_status", "target_staff_note" "text", "target_meeting_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."review_appointment"("target_id" "uuid", "target_status" "public"."appointment_status", "target_staff_note" "text", "target_meeting_url" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."clinical_drafts" TO "anon";
GRANT ALL ON TABLE "public"."clinical_drafts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."clinical_drafts" TO "service_role";



GRANT ALL ON FUNCTION "public"."review_clinical_draft"("target_draft_id" "uuid", "target_status" "public"."clinical_draft_status") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."review_plan_template"("target_template_id" "uuid", "target_status" "public"."plan_template_status", "target_notes" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."review_plan_template"("target_template_id" "uuid", "target_status" "public"."plan_template_status", "target_notes" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."review_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_targets" "jsonb", "target_assistant_state" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."review_plan_version"("target_plan_id" "uuid", "target_version_id" "uuid", "target_targets" "jsonb", "target_assistant_state" "jsonb") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."substitution_requests" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."substitution_requests" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."substitution_requests" TO "service_role";



REVOKE ALL ON FUNCTION "public"."review_substitution_request"("target_request_id" "uuid", "target_status" "public"."substitution_request_status", "target_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."review_substitution_request"("target_request_id" "uuid", "target_status" "public"."substitution_request_status", "target_note" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_responses" TO "anon";
GRANT ALL ON TABLE "public"."form_responses" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_responses" TO "service_role";



GRANT ALL ON FUNCTION "public"."save_form_response"("target_assignment_id" "uuid", "target_values" "jsonb", "target_submit" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."save_plan_draft"("target_organization_id" "uuid", "target_patient_id" "uuid", "target_title" "text", "target_change_summary" "text", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb", "target_created_by" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_plan_draft"("target_organization_id" "uuid", "target_patient_id" "uuid", "target_title" "text", "target_change_summary" "text", "target_assistant_state" "jsonb", "target_targets" "jsonb", "target_days" "jsonb", "target_created_by" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."seed_plan_templates_dietbox"("target_organization_id" "uuid", "target_created_by" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."seed_plan_templates_dietbox"("target_organization_id" "uuid", "target_created_by" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."seed_practicas_dieteticas"("target_organization_id" "uuid", "target_created_by" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."seed_practicas_dieteticas"("target_organization_id" "uuid", "target_created_by" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."update_alert_status"("target_id" "uuid", "target_status" "public"."alert_status") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_alert_status"("target_id" "uuid", "target_status" "public"."alert_status") TO "authenticated";


















GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."adherence_alerts" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."adherence_alerts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."adherence_alerts" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."anthropometry" TO "anon";
GRANT ALL ON TABLE "public"."anthropometry" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."anthropometry" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."appointments" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."appointments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."appointments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."assessments" TO "anon";
GRANT ALL ON TABLE "public"."assessments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."assessments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."audit_events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."audit_events" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."audit_events" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."audit_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."audit_events_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."consultation_summaries" TO "anon";
GRANT ALL ON TABLE "public"."consultation_summaries" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."consultation_summaries" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."content_library_items" TO "anon";
GRANT ALL ON TABLE "public"."content_library_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."content_library_items" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."equivalency_list_items" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."equivalency_list_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."equivalency_list_items" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."equivalency_lists" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."equivalency_lists" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."equivalency_lists" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patients" TO "anon";
GRANT ALL ON TABLE "public"."patients" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patients" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."follow_up_queue" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."follow_up_queue" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."follow_up_queue" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_components" TO "anon";
GRANT ALL ON TABLE "public"."food_components" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_components" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_nutrient_values" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."food_nutrient_values" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_nutrient_values" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_sources" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_sources" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_sources" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_user_preferences" TO "anon";
GRANT ALL ON TABLE "public"."food_user_preferences" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."food_user_preferences" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."foods" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."foods" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."foods" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_assignments" TO "anon";
GRANT ALL ON TABLE "public"."form_assignments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_assignments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_fields" TO "anon";
GRANT ALL ON TABLE "public"."form_fields" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_fields" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_template_versions" TO "anon";
GRANT ALL ON TABLE "public"."form_template_versions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_template_versions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_templates" TO "anon";
GRANT ALL ON TABLE "public"."form_templates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."form_templates" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."lab_results" TO "anon";
GRANT ALL ON TABLE "public"."lab_results" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."lab_results" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_checkin_photos" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_checkin_photos" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_checkin_photos" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_checkins" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."meal_checkins" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_checkins" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_item_substitutions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."meal_item_substitutions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_item_substitutions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_items" TO "anon";
GRANT ALL ON TABLE "public"."meal_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meal_items" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meals" TO "anon";
GRANT ALL ON TABLE "public"."meals" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."meals" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."memberships" TO "anon";
GRANT ALL ON TABLE "public"."memberships" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."memberships" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."nutrients" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."nutrients" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."nutrients" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."nutritional_estimates" TO "anon";
GRANT ALL ON TABLE "public"."nutritional_estimates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."nutritional_estimates" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."organization_branding" TO "anon";
GRANT ALL ON TABLE "public"."organization_branding" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."organization_branding" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."organization_drive_configs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."organization_drive_configs" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."organization_drive_configs" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."organizations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."organizations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."organizations" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_consents" TO "anon";
GRANT ALL ON TABLE "public"."patient_consents" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_consents" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_goals" TO "anon";
GRANT ALL ON TABLE "public"."patient_goals" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_goals" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_guardians" TO "anon";
GRANT ALL ON TABLE "public"."patient_guardians" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_guardians" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_water_logs" TO "anon";
GRANT ALL ON TABLE "public"."patient_water_logs" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."patient_water_logs" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plan_days" TO "anon";
GRANT ALL ON TABLE "public"."plan_days" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plan_days" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plan_versions" TO "anon";
GRANT ALL ON TABLE "public"."plan_versions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."plan_versions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."rooms" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."rooms" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."rooms" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";































