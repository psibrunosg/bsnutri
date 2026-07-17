alter table public.meal_checkins
  add column symptom_intensity smallint check(symptom_intensity between 0 and 10),
  add column help_requested boolean not null default false;

create or replace function private.create_checkin_alert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.help_requested then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'severe_symptom','urgent','Paciente pediu ajuda no diario alimentar.');
 elsif new.reaction_suspected then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'allergy_or_reaction','urgent','Paciente sinalizou possivel reacao ou alergia.');
 elsif nullif(trim(coalesce(new.symptoms,'')),'') is not null then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'severe_symptom',case when coalesce(new.symptom_intensity,0)>=7 then 'urgent'::public.alert_severity else 'attention'::public.alert_severity end,'Paciente registrou sintomas no check-in.');
 elsif new.hunger_before>=9 then insert into public.adherence_alerts(organization_id,patient_id,checkin_id,kind,severity,message) values(new.organization_id,new.patient_id,new.id,'intense_hunger','attention','Paciente registrou fome intensa antes da refeicao.'); end if;
 return new;
end; $$;
