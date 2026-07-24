alter table public.lab_results
  add column attachment_name text check (attachment_name is null or char_length(trim(attachment_name)) between 2 and 180),
  add column attachment_url text check (attachment_url is null or attachment_url ~ '^https?://');

alter table public.lab_results
  add constraint lab_results_attachment_complete check (
    (attachment_name is null and attachment_url is null)
    or (attachment_name is not null and attachment_url is not null)
  );
