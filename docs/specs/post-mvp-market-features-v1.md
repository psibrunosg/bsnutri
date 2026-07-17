# Spec: pos-MVP baseado em referencias de mercado V1

## Problem Statement

O MVP do BSNutri ja prova as jornadas basicas de profissional, paciente e recepcao. O proximo ciclo precisa aproximar o produto dos softwares fortes do mercado sem copiar tudo de uma vez: Dietbox, WebDiet, Nutrium e Healthie mostram que o valor real esta em entrada clinica bem feita, plano alimentar rapido, portal do paciente util, evolucao clara, biblioteca reaproveitavel, marca profissional e IA revisavel.

O risco principal e tentar adicionar "mais recursos" sem amarrar a rotina clinica. Este ciclo foca nos blocos escolhidos:

1. portal do paciente forte;
2. anamnese e pre-consulta;
3. editor de plano competitivo;
4. exames e evolucao clinica;
5. biblioteca profissional;
6. personalizacao e marca;
7. IA util.

## Solution

Construir o ciclo em incrementos pequenos, mantendo o que ja existe: RLS, publicacao imutavel, versoes de plano, portal do paciente, diario, alertas, Drive e fila clinica.

A ordem tecnica sera:

1. anamnese e pre-consulta;
2. editor de plano competitivo;
3. portal do paciente forte;
4. exames e evolucao clinica;
5. biblioteca profissional;
6. IA util;
7. personalizacao e marca.

## Market References

1. Dietbox: questionario pre-consulta, anamnese, exames, planos calculados/livres, app do paciente, WhatsApp, agenda e materiais editaveis.
2. WebDiet: periodizacao alimentar, diario fotografico, modelos, app do paciente e personalizacao visual.
3. Nutrium: consulta guiada, templates, receitas, equivalentes, diario, agua, atividade, peso, mensagens e lista de compras.
4. Healthie: formularios, portal configuravel, documentos, metas, diario, programas, chat e prontuario operacional.

## Implementation Decisions

1. Nao criar app nativo agora; melhorar o portal web/PWA.
2. Nao criar motor generico de formularios alem do necessario para anamnese e pre-consulta.
3. Formularios publicados sao versionados e imutaveis.
4. Plano publicado continua imutavel.
5. Biblioteca profissional usa copia para paciente, nunca referencia mutavel.
6. IA sempre gera rascunho revisavel, nunca aplica conduta sozinha.
7. Marca visual deve ser configuracao simples por organizacao: logo, cor primaria e nome publico.
8. Recepcao continua sem acesso a dados clinicos.

## Out of Scope

1. Chat completo.
2. WhatsApp oficial automatico.
3. Pagamentos e financeiro.
4. App nativo.
5. Marketplace, cursos ou comunidade.
6. Interpretacao automatica final de exames.
7. IA enviando mensagem ao paciente sem revisao profissional.

## Tickets

1. `01-intake-form-foundation.md`
2. `02-patient-pre-consultation-flow.md`
3. `03-consultation-review-panel.md`
4. `04-plan-template-library.md`
5. `05-recipes-and-household-measures.md`
6. `06-periodized-plan-editor.md`
7. `07-patient-today-home.md`
8. `08-patient-goals-and-weekly-summary.md`
9. `09-exams-and-evolution-timeline.md`
10. `10-professional-content-library.md`
11. `11-ai-clinical-draft-assistant.md`
12. `12-clinic-branding-and-exports.md`

## Done Definition

1. migration incremental quando houver dado novo;
2. RLS positiva e negativa por papel;
3. teste de interface quando houver fluxo visivel;
4. `npm test`, `npm run lint`, `npm run build`;
5. `supabase test db` quando o ambiente permitir;
6. documento do ticket atualizado;
7. handoff salvo no Drive.
