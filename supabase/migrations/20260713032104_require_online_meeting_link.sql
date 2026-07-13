alter table public.appointments add constraint appointments_online_link_when_approved
check(status<>'approved' or modality<>'online' or nullif(trim(external_meeting_url),'') is not null);
