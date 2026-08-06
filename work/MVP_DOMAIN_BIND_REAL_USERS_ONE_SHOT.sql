do $$
declare
  professional_user_id uuid;
  receptionist_user_id uuid;
  patient_user_id uuid;
begin
  select id into professional_user_id from auth.users where email = 'mvp2.profissional@teste.com' limit 1;
  select id into receptionist_user_id from auth.users where email = 'mvp2.recepcao@teste.com' limit 1;
  select id into patient_user_id from auth.users where email = 'mvp2.paciente@teste.com' limit 1;

  if professional_user_id is null then
    raise exception 'Usuário profissional real não encontrado em auth.users';
  end if;
  if receptionist_user_id is null then
    raise exception 'Usuário recepção real não encontrado em auth.users';
  end if;
  if patient_user_id is null then
    raise exception 'Usuário paciente real não encontrado em auth.users';
  end if;

  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claim.sub', professional_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('bsnutri.workflow_rpc', 'on', true);

  insert into public.profiles (id, full_name, display_name) values
    (professional_user_id, 'Profissional MVP 2', 'Nutri MVP 2'),
    (receptionist_user_id, 'Recepção MVP 2', 'Recepção MVP 2'),
    (patient_user_id, 'Paciente MVP 2', 'Paciente MVP 2')
  on conflict (id) do update
  set full_name = excluded.full_name,
      display_name = excluded.display_name,
      updated_at = now();

  insert into public.organizations (id, name, slug, created_by) values
    ('fb000000-0000-0000-0000-000000000002', 'Clínica MVP BSNutri Real', 'clinica-mvp-bsnutri-real', professional_user_id);

  insert into public.memberships (organization_id, user_id, role, status) values
    ('fb000000-0000-0000-0000-000000000002', receptionist_user_id, 'receptionist', 'active');

  insert into public.patients (
    id, organization_id, professional_id, anonymous_code, full_name, birth_date,
    email, phone, created_by, patient_user_id
  ) values (
    'fa000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    professional_user_id,
    'MVP-002',
    'Paciente MVP 2',
    date '1995-05-20',
    'mvp2.paciente@teste.com',
    '51999999998',
    professional_user_id,
    patient_user_id
  );

  insert into public.assessments (
    id, organization_id, patient_id, professional_id, objective, food_preferences,
    food_restrictions, allergies, clinical_notes
  ) values (
    'fc000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'fa000000-0000-0000-0000-000000000002',
    professional_user_id,
    'Organizar rotina alimentar e reduzir episódios de fome intensa.',
    'Prefere refeições simples e arroz com feijão.',
    'Evita frituras durante a semana.',
    'Nenhuma alergia alimentar confirmada.',
    'Paciente sintético para smoke do MVP com Auth real.'
  );

  insert into public.anthropometry (
    id, organization_id, patient_id, assessment_id, weight_kg, height_cm,
    body_fat_percent, waist_cm, notes, created_by
  ) values (
    'fd000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'fa000000-0000-0000-0000-000000000002',
    'fc000000-0000-0000-0000-000000000002',
    78.2,
    175,
    23.4,
    92,
    'Medida base para jornada do MVP com Auth real.',
    professional_user_id
  );

  insert into public.rooms (id, organization_id, name) values
    ('f9000000-0000-0000-0000-000000000002', 'fb000000-0000-0000-0000-000000000002', 'Consultório 2');

  insert into public.plans (
    id, organization_id, patient_id, created_by, title, status, starts_on
  ) values (
    'f8000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'fa000000-0000-0000-0000-000000000002',
    professional_user_id,
    'Plano alimentar MVP Real',
    'draft',
    current_date
  );

  insert into public.plan_versions (
    id, organization_id, plan_id, version_no, change_summary, created_by, targets
  ) values (
    'f7000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'f8000000-0000-0000-0000-000000000002',
    1,
    'Versão inicial de smoke do MVP com Auth real.',
    professional_user_id,
    '{"energy_kcal":2200,"protein_g":140}'::jsonb
  );

  insert into public.plan_days (
    id, organization_id, plan_version_id, day_index, label
  ) values (
    'f6000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'f7000000-0000-0000-0000-000000000002',
    0,
    'Dia base do MVP Real'
  );

  insert into public.meals (
    id, organization_id, plan_day_id, position, label, suggested_time
  ) values (
    'f5000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'f6000000-0000-0000-0000-000000000002',
    0,
    'Almoço',
    time '12:30'
  );

  insert into public.meal_items (
    id, organization_id, meal_id, position, description, quantity, unit, grams,
    nutrient_snapshot, notes
  ) values (
    'f4000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'f5000000-0000-0000-0000-000000000002',
    0,
    'Arroz, feijão e frango grelhado',
    250,
    'g',
    250,
    '{"food_name":"Arroz, feijão e frango grelhado","preparation_state":"caseiro"}'::jsonb,
    'Item sintético para o portal do paciente com Auth real.'
  );

  insert into public.meal_item_substitutions (
    id, organization_id, plan_version_id, meal_item_id, description, grams, unit,
    professional_note, created_by
  ) values (
    'f2000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'f7000000-0000-0000-0000-000000000002',
    'f4000000-0000-0000-0000-000000000002',
    'Batata-doce com carne moída',
    250,
    'g',
    'Troca simples para dias com menos tempo de preparo.',
    professional_user_id
  );

  update public.plan_versions
  set reviewed_by = professional_user_id,
      reviewed_at = now(),
      locked_at = now(),
      published_at = now(),
      content_hash = md5('mvp-fixture-real')
  where id = 'f7000000-0000-0000-0000-000000000002';

  update public.plans
  set status = 'published',
      reviewed_by = professional_user_id,
      reviewed_at = now(),
      published_by = professional_user_id,
      published_at = now(),
      current_published_version_id = 'f7000000-0000-0000-0000-000000000002'
  where id = 'f8000000-0000-0000-0000-000000000002';

  insert into public.appointments (
    id, organization_id, patient_id, professional_id, room_id, requested_by, status,
    modality, starts_at, ends_at, patient_note
  ) values (
    'f3000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'fa000000-0000-0000-0000-000000000002',
    professional_user_id,
    'f9000000-0000-0000-0000-000000000002',
    patient_user_id,
    'requested',
    'in_person',
    current_date::timestamp + time '15:30',
    current_date::timestamp + time '16:30',
    'Pedido sintético de consulta para o smoke com Auth real.'
  );

  perform set_config('request.jwt.claim.sub', patient_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.meal_checkins (
    id, organization_id, patient_id, plan_version_id, meal_id, occurred_on, state,
    hunger_before, satiety_after, mood, energy, sleep_quality, reaction_suspected,
    symptoms, note, created_by
  ) values (
    'f0000000-0000-0000-0000-000000000002',
    'fb000000-0000-0000-0000-000000000002',
    'fa000000-0000-0000-0000-000000000002',
    'f7000000-0000-0000-0000-000000000002',
    'f5000000-0000-0000-0000-000000000002',
    current_date,
    'adapted',
    9,
    6,
    5,
    5,
    6,
    true,
    'Leve desconforto após a refeição.',
    'Check-in sintético para gerar alerta com Auth real.',
    patient_user_id
  );
end
$$;
