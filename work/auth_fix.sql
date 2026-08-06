do $$
begin
  update auth.users
  set raw_user_meta_data = case email
    when 'mvp.profissional@teste.com' then '{"sub":"e1000000-0000-0000-0000-000000000001","email":"mvp.profissional@teste.com","email_verified":true,"full_name":"Profissional MVP","phone_verified":false}'::jsonb
    when 'mvp.recepcao@teste.com' then '{"sub":"e1000000-0000-0000-0000-000000000002","email":"mvp.recepcao@teste.com","email_verified":true,"full_name":"Recepção MVP","phone_verified":false}'::jsonb
    when 'mvp.paciente@teste.com' then '{"sub":"e1000000-0000-0000-0000-000000000003","email":"mvp.paciente@teste.com","email_verified":true,"full_name":"Paciente MVP","phone_verified":false}'::jsonb
    else raw_user_meta_data
  end
  where email in ('mvp.profissional@teste.com','mvp.recepcao@teste.com','mvp.paciente@teste.com');

  update auth.identities
  set provider_id = user_id::text,
      identity_data = case user_id::text
        when 'e1000000-0000-0000-0000-000000000001' then '{"sub":"e1000000-0000-0000-0000-000000000001","email":"mvp.profissional@teste.com","email_verified":true,"full_name":"Profissional MVP","phone_verified":false}'::jsonb
        when 'e1000000-0000-0000-0000-000000000002' then '{"sub":"e1000000-0000-0000-0000-000000000002","email":"mvp.recepcao@teste.com","email_verified":true,"full_name":"Recepção MVP","phone_verified":false}'::jsonb
        when 'e1000000-0000-0000-0000-000000000003' then '{"sub":"e1000000-0000-0000-0000-000000000003","email":"mvp.paciente@teste.com","email_verified":true,"full_name":"Paciente MVP","phone_verified":false}'::jsonb
        else identity_data
      end
  where user_id in ('e1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000003');
end
$$;
