# Checklist complementar pós-MVP do BSNutri

## Gate de estabilidade

- [x] Recuperar no repositório as migrations remotas de 14 a 17/07.
- [ ] Confirmar novamente schema remoto, migrations e `main` antes de novo DDL.
- [ ] Gerar tipos TypeScript do schema reconciliado.
- [ ] Revisar RLS, grants, funções privilegiadas, índices e advisors.
- [ ] Fazer pgTAP rodar em Docker ou CI.

## Núcleo nutricional

- [ ] Ampliar nutrientes, dados ausentes e casos de referência.
- [ ] Implementar equações energéticas e antropométricas selecionáveis.
- [ ] Implementar medidas caseiras canônicas e conversões auditáveis.
- [ ] Implementar receitas, rendimento, peso final e porções.
- [ ] Validar licenças e importar fonte nutricional aprovada.

## Editor e publicação

- [ ] Criar modelos independentes e cópias anonimizadas.
- [ ] Copiar dia/refeição e editar em massa.
- [ ] Implementar periodização e vigência futura.
- [ ] Comparar e restaurar versões como nova versão.
- [ ] Completar equivalência, tolerâncias e escolhas de substituição.

## Portal do paciente

- [ ] Preferências, restrições, horários e controles de visibilidade.
- [ ] Responsáveis e dependentes com revogação.
- [ ] Lista de compras personalizada, receitas, pessoas e exportação.
- [ ] PDF e impressão com identidade da clínica.
- [ ] Tutorial, ajuda e feedback permanente.

## Acompanhamento

- [ ] Alertas configuráveis e escolhas integradas ao check-in.
- [ ] Peso, medidas, exames, fotos e Storage privado.
- [ ] Lista de espera, encaixes e agenda completa.
- [ ] Google Agenda e teleconsulta externa.
- [ ] Mensagens e lembretes internos.

## Segurança e operação

- [ ] MFA obrigatório para equipe e sessões revogáveis.
- [ ] Testar recuperação de senha e redirects reais.
- [ ] Completar auditoria de leituras e mutações.
- [ ] Exportação, exclusão, anonimização e retenção LGPD.
- [ ] Backup independente e teste de restauração.
- [ ] Validar regra ética para estudante e supervisor.

## Qualidade e piloto

- [ ] E2E com duas clínicas e todos os papéis.
- [ ] Auditoria WCAG e responsividade completa.
- [ ] Observabilidade sem dados clínicos.
- [ ] Ensaio com quatro participantes sintéticos.
- [ ] Validação formal dos cálculos pelo nutricionista.
- [ ] Decisão final de hospedagem e checklist go/no-go.

Consulte `tasks/plan.md` para dependências, critérios de aceite, verificações e riscos.
