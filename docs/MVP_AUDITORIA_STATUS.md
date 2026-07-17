# Auditoria de status do MVP BSNutri

Atualizado em sexta-feira, 17 de julho de 2026.

## Como ler

Status:

1. `provado`: ha evidencia suficiente no estado atual.
2. `parcial`: existe evidencia relevante, mas ainda falta uma prova final.
3. `pendente`: ainda nao ha prova suficiente.

## Matriz de auditoria

| Item | Status | Evidencia atual | Falta para fechar |
|---|---|---|---|
| `npm run lint` verde | provado | validado em 17/07/2026 | manter verde apos publish final |
| `npm test` verde | provado | 3 arquivos e 9 testes aprovados em 17/07/2026 | manter verde apos diff final |
| `npm run build` verde | provado | build aprovado com geracao de `dist/` em 17/07/2026 | manter verde apos diff final |
| Suites SQL centrais validadas | provado | `bootstrap_organization`, `rls_isolation`, `publication_portal`, `appointments_adherence`, `mvp_smoke` ja validadas no remoto | repetir so se houver mudanca estrutural em SQL |
| Fixture remota com usuarios reais pronta | provado | bind com `mvp2.profissional`, `mvp2.recepcao` e `mvp2.paciente` confirmado | usar no smoke final publicado |
| Jornada `profissional` no deploy publicado | provado | login e dashboard/paciente ja observados no deploy publicado | manter apos novo deploy |
| Jornada `paciente` no deploy publicado | parcial | portal abriu, plano e lista apareceram no deploy publicado | provar no deploy atualizado que nao ha `claim_patient_access` indevido |
| Jornada `recepcao` no deploy publicado | pendente | correcao local pronta em `src/App.tsx`, mas deploy publicado ainda estava antigo | publicar frontend atual e repetir smoke |
| Deploy publicado refletindo frontend local atual | pendente | ultimo smoke mostrou UI antiga para `recepcao` | publicar em `main` e checar GitHub Pages |
| Hardening minimo de `security definer` | parcial | risco conhecido mapeado no plano | registrar decisao final por funcao critica |
| `Leaked Password Protection` decidido | pendente | alerta conhecido no Supabase | registrar decisao do piloto |
| Entrega reproduzivel em outra maquina | parcial | plano, checklist e handoff criados | confirmar fluxo final de retomada apos publish e smoke |

## Conclusao honesta hoje

O MVP nao esta concluido.

Os itens que ainda impedem o fechamento sao:

1. provar `recepcao` no deploy publicado;
2. provar `paciente` no deploy publicado sem `claim_patient_access` indevido;
3. registrar a decisao de hardening minimo do Supabase;
4. consolidar a prova final de reproducao do piloto.

## Prova que falta agora

1. push da versao atual para `main`;
2. jobs `validate` e `deploy` verdes;
3. smoke publicado dos 3 perfis reais;
4. registro final do hardening minimo.
