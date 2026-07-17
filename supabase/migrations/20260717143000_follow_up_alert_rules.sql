create or replace function private.create_checkin_alert()
returns trigger language plpgsql security definer set search_path='' as $$
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
