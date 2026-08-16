-- `public.publish_plan_version` é SECURITY INVOKER e chama
-- `private.plan_assistant_has_steps` diretamente, mas a função estava revogada de
-- `authenticated`. Resultado: toda publicação falhava com
-- "permission denied for function plan_assistant_has_steps".
--
-- O predicado é `immutable` e opera apenas sobre o jsonb que o próprio chamador
-- informa: conceder execução não expõe dado algum. É o mesmo tratamento já dado a
-- `private.has_organization_role`, `private.can_access_patient` e
-- `private.validate_version_ready`, todas chamadas a partir de RPCs invoker.

grant execute on function private.plan_assistant_has_steps(jsonb, text[]) to authenticated;
