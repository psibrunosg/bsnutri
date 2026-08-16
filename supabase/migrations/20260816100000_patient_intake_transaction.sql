-- Task 3: cadastro transacional de paciente, avaliação e antropometria.
-- Acrescenta os campos usados pelo cadastro clínico novo e uma RPC SECURITY INVOKER
-- que grava paciente + avaliação + antropometria + auditoria em uma única transação.

alter table public.patients
  add column if not exists tags text[] not null default '{}'::text[];

alter table public.anthropometry
  add column if not exists hip_cm numeric(6,2) check (hip_cm > 0),
  add column if not exists arm_cm numeric(6,2) check (arm_cm > 0);

create index if not exists patients_tags_idx on public.patients using gin (tags);

create or replace function public.create_patient_intake(
  target_organization_id uuid,
  full_name_input text,
  email_input text default null,
  phone_input text default null,
  birth_date_input date default null,
  tags_input text[] default '{}'::text[],
  objective_input text default null,
  food_preferences_input text default null,
  food_restrictions_input text default null,
  allergies_input text default null,
  clinical_notes_input text default null,
  weight_kg_input numeric default null,
  height_cm_input numeric default null,
  waist_cm_input numeric default null,
  hip_cm_input numeric default null,
  arm_cm_input numeric default null,
  body_fat_percent_input numeric default null,
  measured_at_input timestamptz default now()
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
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

revoke all on function public.create_patient_intake(uuid, text, text, text, date, text[], text, text, text, text, text, numeric, numeric, numeric, numeric, numeric, numeric, timestamptz) from public;
grant execute on function public.create_patient_intake(uuid, text, text, text, date, text[], text, text, text, text, text, numeric, numeric, numeric, numeric, numeric, numeric, timestamptz) to authenticated;
