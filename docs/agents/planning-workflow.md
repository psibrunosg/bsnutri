# Procedimento permanente para planos do BSNutri

Este arquivo deve ser lido sempre que o usuário pedir um plano para o BSNutri.

## Regra central

Todo plano deve partir do estado real do repositório e terminar em trabalho executável. O foco padrão é o fluxo do profissional de nutrição. O paciente permanece como destinatário do plano publicado até que o usuário mude essa prioridade.

## Estrutura obrigatória

1. Ler `AGENTS.md`, `CONTEXT.md`, ADRs, especificações relacionadas, handoff mais recente e estado atual do código.
2. Organizar a ideia e declarar objetivo, usuário principal, problema, limites e resultado esperado.
3. Comparar o pedido com o que já existe antes de propor módulos, dependências ou telas novas.
4. Apontar fragilidades, riscos, lacunas, conflitos e dados ainda não confirmados.
5. Registrar também ideias frágeis, sem descartá-las como inúteis.
6. Definir a jornada de ponta a ponta antes de definir menus, telas ou schema.
7. Dividir o trabalho em fatias verticais demonstráveis, cada uma com critério de aceite, teste e gate.
8. Destacar as skills usadas em cada fase e explicar o efeito prático de cada uma.
9. Incluir o workflow de desenvolvimento autônomo, com preflight, issue, branch, implementação, verificação, revisão, documentação e handoff.
10. Incluir métricas de produto, qualidade técnica, segurança e experiência.
11. Sugerir melhorias agrupadas, mesmo quando não entrarem no escopo imediato.
12. Aplicar Humanizer ao texto final: português natural, sem travessões, floreio, conclusão genérica ou tom publicitário.

## Ordem padrão de decisão

1. Confirmar se a necessidade existe.
2. Reusar o domínio, o módulo, o helper e o padrão já presentes.
3. Usar recurso nativo da plataforma.
4. Usar dependência já instalada.
5. Adicionar o mínimo de código ou schema que resolva uma fatia real.
6. Criar abstração apenas quando duas necessidades concretas provarem a variação.

## Workflow autônomo mínimo

1. Selecionar uma issue pequena e verificável.
2. Ler callers, dados, políticas de acesso e testes do fluxo inteiro.
3. Fixar o seam que será testado e escrever um caso que falha quando houver lógica não trivial.
4. Implementar a menor fatia funcional.
5. Validar regra, interface, banco, acessibilidade e segurança na proporção do risco.
6. Revisar contra a issue e contra os padrões do repositório.
7. Rodar `npm test`, `npm run lint`, `npm run build` e testes SQL quando aplicável.
8. Atualizar documentação, issue e handoff.

## Regra para auditorias

Auditorias devem manter relatórios separados para:

1. segurança explorável;
2. correção funcional;
3. confiabilidade clínica e proveniência;
4. privacidade e acesso;
5. UX e acessibilidade;
6. desempenho e operação;
7. excesso de complexidade com Ponytail.

Um alerta de hardening não deve ser apresentado como vulnerabilidade confirmada. Um achado só é confirmado quando houver caminho reproduzível, impacto e evidência.

## Memória de direção do produto

1. Priorizar o profissional de nutrição.
2. Reduzir entrada manual por meio de cálculos transparentes e reutilização segura.
3. Manter decisão e publicação sob controle profissional.
4. Separar estimativa calculada, meta profissional, modelo dietético e modelo de plano.
5. Organizar modelos e fontes com versão, proveniência, revisão e validade.
6. Tratar o portal do paciente como entrega do plano nesta etapa.
7. Evitar expandir agenda, financeiro, marketplace, IA clínica ou aplicativo nativo antes de o núcleo profissional funcionar bem.
