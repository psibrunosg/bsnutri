do $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claim.sub', 'e1000000-0000-0000-0000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('bsnutri.workflow_rpc', 'on', true);

  update public.plan_versions
  set locked_at = null,
      published_at = null,
      content_hash = null,
      reviewed_at = null,
      reviewed_by = null,
      targets = '{}'::jsonb
  where organization_id = 'fb000000-0000-0000-0000-000000000001';

  update public.plans
  set status = 'draft',
      reviewed_at = null,
      reviewed_by = null,
      published_at = null,
      published_by = null,
      current_published_version_id = null
  where organization_id = 'fb000000-0000-0000-0000-000000000001';

  delete from public.substitution_requests where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meal_item_substitutions where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.adherence_alerts where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meal_checkins where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.appointments where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.rooms where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meal_items where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meals where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.plan_days where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.plan_versions where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.plans where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.anthropometry where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.assessments where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.patients where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.memberships where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.organizations where id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.profiles where id in (
    'e1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003'
  );
  delete from auth.identities where user_id in (
    'e1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003'
  );
  delete from auth.users where id in (
    'e1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003'
  );

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values
    (
      'e1000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'mvp.profissional@teste.com',
      crypt('SenhaMvp123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"sub":"e1000000-0000-0000-0000-000000000001","email":"mvp.profissional@teste.com","email_verified":true,"full_name":"Profissional MVP","phone_verified":false}'::jsonb,
      now(),
      now()
    ),
    (
      'e1000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'mvp.recepcao@teste.com',
      crypt('SenhaMvp123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"sub":"e1000000-0000-0000-0000-000000000002","email":"mvp.recepcao@teste.com","email_verified":true,"full_name":"Recepção MVP","phone_verified":false}'::jsonb,
      now(),
      now()
    ),
    (
      'e1000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'mvp.paciente@teste.com',
      crypt('SenhaMvp123!', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"sub":"e1000000-0000-0000-0000-000000000003","email":"mvp.paciente@teste.com","email_verified":true,"full_name":"Paciente MVP","phone_verified":false}'::jsonb,
      now(),
      now()
    );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at,
    created_at, updated_at, id
  ) values
    (
      'e1000000-0000-0000-0000-000000000001',
      'e1000000-0000-0000-0000-000000000001',
      '{"sub":"e1000000-0000-0000-0000-000000000001","email":"mvp.profissional@teste.com","email_verified":true}'::jsonb,
      'email',
      now(),
      now(),
      now(),
      'd1000000-0000-0000-0000-000000000001'
    ),
    (
      'e1000000-0000-0000-0000-000000000002',
      'e1000000-0000-0000-0000-000000000002',
      '{"sub":"e1000000-0000-0000-0000-000000000002","email":"mvp.recepcao@teste.com","email_verified":true}'::jsonb,
      'email',
      now(),
      now(),
      now(),
      'd1000000-0000-0000-0000-000000000002'
    ),
    (
      'e1000000-0000-0000-0000-000000000003',
      'e1000000-0000-0000-0000-000000000003',
      '{"sub":"e1000000-0000-0000-0000-000000000003","email":"mvp.paciente@teste.com","email_verified":true}'::jsonb,
      'email',
      now(),
      now(),
      now(),
      'd1000000-0000-0000-0000-000000000003'
    );

  insert into public.profiles (id, full_name, display_name) values
    ('e1000000-0000-0000-0000-000000000001', 'Profissional MVP', 'Nutri MVP'),
    ('e1000000-0000-0000-0000-000000000002', 'Recepção MVP', 'Recepção MVP'),
    ('e1000000-0000-0000-0000-000000000003', 'Paciente MVP', 'Paciente MVP');

  insert into public.organizations (id, name, slug, created_by) values
    ('fb000000-0000-0000-0000-000000000001', 'Clínica MVP BSNutri', 'clinica-mvp-bsnutri', 'e1000000-0000-0000-0000-000000000001');

  insert into public.memberships (organization_id, user_id, role, status) values
    ('fb000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002', 'receptionist', 'active');

  insert into public.patients (
    id, organization_id, professional_id, anonymous_code, full_name, birth_date,
    email, phone, created_by, patient_user_id
  ) values (
    'fa000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000001',
    'MVP-001',
    'Paciente MVP',
    date '1995-05-20',
    'mvp.paciente@teste.com',
    '51999999999',
    'e1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000003'
  );

  insert into public.assessments (
    id, organization_id, patient_id, professional_id, objective, food_preferences,
    food_restrictions, allergies, clinical_notes
  ) values (
    'fc000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'fa000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000001',
    'Organizar rotina alimentar e reduzir episódios de fome intensa.',
    'Prefere refeições simples e arroz com feijão.',
    'Evita frituras durante a semana.',
    'Nenhuma alergia alimentar confirmada.',
    'Paciente sintético para smoke do MVP.'
  );

  insert into public.anthropometry (
    id, organization_id, patient_id, assessment_id, weight_kg, height_cm,
    body_fat_percent, waist_cm, notes, created_by
  ) values (
    'fd000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'fa000000-0000-0000-0000-000000000001',
    'fc000000-0000-0000-0000-000000000001',
    78.2,
    175,
    23.4,
    92,
    'Medida base para jornada do MVP.',
    'e1000000-0000-0000-0000-000000000001'
  );

  insert into public.rooms (id, organization_id, name) values
    ('f9000000-0000-0000-0000-000000000001', 'fb000000-0000-0000-0000-000000000001', 'Consultório 1');

  insert into public.plans (
    id, organization_id, patient_id, created_by, title, status, starts_on
  ) values (
    'f8000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'fa000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000001',
    'Plano alimentar MVP',
    'draft',
    current_date
  );

  insert into public.plan_versions (
    id, organization_id, plan_id, version_no, change_summary, created_by, targets
  ) values (
    'f7000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'f8000000-0000-0000-0000-000000000001',
    1,
    'Versão inicial de smoke do MVP.',
    'e1000000-0000-0000-0000-000000000001',
    '{"energy_kcal":2200,"protein_g":140}'::jsonb
  );

  insert into public.plan_days (
    id, organization_id, plan_version_id, day_index, label
  ) values (
    'f6000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'f7000000-0000-0000-0000-000000000001',
    0,
    'Dia base do MVP'
  );

  insert into public.meals (
    id, organization_id, plan_day_id, position, label, suggested_time
  ) values (
    'f5000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'f6000000-0000-0000-0000-000000000001',
    0,
    'Almoço',
    time '12:30'
  );

  insert into public.meal_items (
    id, organization_id, meal_id, position, description, quantity, unit, grams,
    nutrient_snapshot, notes
  ) values (
    'f4000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'f5000000-0000-0000-0000-000000000001',
    0,
    'Arroz, feijão e frango grelhado',
    250,
    'g',
    250,
    '{"food_name":"Arroz, feijão e frango grelhado","preparation_state":"caseiro"}'::jsonb,
    'Item sintético para o portal do paciente.'
  );

  insert into public.meal_item_substitutions (
    id, organization_id, plan_version_id, meal_item_id, description, grams, unit,
    professional_note, created_by
  ) values (
    'f2000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'f7000000-0000-0000-0000-000000000001',
    'f4000000-0000-0000-0000-000000000001',
    'Batata-doce com carne moída',
    250,
    'g',
    'Troca simples para dias com menos tempo de preparo.',
    'e1000000-0000-0000-0000-000000000001'
  );

  perform set_config('bsnutri.workflow_rpc', 'on', true);
  update public.plan_versions
  set reviewed_by = 'e1000000-0000-0000-0000-000000000001',
      reviewed_at = now(),
      locked_at = now(),
      published_at = now(),
      content_hash = md5('mvp-fixture')
  where id = 'f7000000-0000-0000-0000-000000000001';

  update public.plans
  set status = 'published',
      reviewed_by = 'e1000000-0000-0000-0000-000000000001',
      reviewed_at = now(),
      published_by = 'e1000000-0000-0000-0000-000000000001',
      published_at = now(),
      current_published_version_id = 'f7000000-0000-0000-0000-000000000001'
  where id = 'f8000000-0000-0000-0000-000000000001';

  insert into public.appointments (
    id, organization_id, patient_id, professional_id, room_id, requested_by, status,
    modality, starts_at, ends_at, patient_note
  ) values (
    'f3000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'fa000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000001',
    'f9000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000003',
    'requested',
    'in_person',
    current_date::timestamp + time '15:00',
    current_date::timestamp + time '16:00',
    'Pedido sintético de consulta para o smoke.'
  );

  perform set_config('request.jwt.claim.sub', 'e1000000-0000-0000-0000-000000000003', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.meal_checkins (
    id, organization_id, patient_id, plan_version_id, meal_id, occurred_on, state,
    hunger_before, satiety_after, mood, energy, sleep_quality, reaction_suspected,
    symptoms, note, created_by
  ) values (
    'f0000000-0000-0000-0000-000000000001',
    'fb000000-0000-0000-0000-000000000001',
    'fa000000-0000-0000-0000-000000000001',
    'f7000000-0000-0000-0000-000000000001',
    'f5000000-0000-0000-0000-000000000001',
    current_date,
    'adapted',
    9,
    6,
    5,
    5,
    6,
    true,
    'Leve desconforto após a refeição.',
    'Check-in sintético para gerar alerta.',
    'e1000000-0000-0000-0000-000000000003'
  );
end
$$;
