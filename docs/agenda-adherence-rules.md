# Regras de agenda e adesão

Este documento define o comportamento esperado para o piloto. Ele é a referência funcional para schema, RLS, RPCs, interface e testes SQL. Datas devem ser armazenadas em UTC e exibidas no fuso da clínica.

## Agenda

### Estados e transições

Estados canônicos da consulta:

- `requested`: horário solicitado pelo paciente e ainda não confirmado;
- `confirmed`: horário aprovado pela clínica;
- `completed`: atendimento realizado;
- `cancelled_by_patient`: cancelamento solicitado pelo paciente;
- `cancelled_by_clinic`: cancelamento realizado pela clínica;
- `no_show`: paciente não compareceu.

Transições permitidas:

| Origem | Destino | Quem pode executar |
| --- | --- | --- |
| novo | `requested` | paciente vinculado, profissional ou recepção |
| novo | `confirmed` | profissional ou recepção |
| `requested` | `confirmed` | profissional ou recepção |
| `requested` | cancelado | paciente vinculado, profissional ou recepção |
| `confirmed` | `completed` ou `no_show` | profissional ou recepção |
| `confirmed` | cancelado | paciente vinculado, profissional ou recepção |

Estados finais não são editados. Uma correção administrativa deve gerar evento de auditoria explícito; nunca apagar o registro. Reagendamento cria uma nova reserva vinculada à anterior e cancela a anterior somente após a nova reserva ser validada.

### Conflitos e consistência

- Uma consulta ocupa o intervalo semiaberto `[início, fim)`. Consultas adjacentes são permitidas.
- `fim` deve ser posterior a `início` e a duração deve respeitar os limites definidos pela clínica.
- Estados cancelados não bloqueiam horários. `requested` e `confirmed` bloqueiam o profissional e, quando informada, a sala.
- Um profissional não pode ter intervalos sobrepostos, mesmo entre clínicas diferentes.
- Uma sala não pode ter intervalos sobrepostos dentro da mesma clínica.
- Consulta online ou domiciliar pode não ter sala. Consulta presencial exige sala.
- Validação e gravação devem ocorrer atomicamente no banco. Verificação somente na interface não evita corrida.
- Aprovação de solicitação repete a validação de conflito. Em disputa, apenas uma confirmação vence e a outra permanece solicitada com mensagem compreensível.
- Alterações vindas do Google Agenda não podem contornar isolamento, permissões ou validação de conflito. O identificador externo não contém dados clínicos.
- Exclusões ou cancelamentos externos não apagam o histórico local. Falhas de sincronização ficam registradas para nova tentativa.

### Privacidade e permissões

- Toda entidade pertence a uma clínica. RLS impede leitura e escrita cruzadas entre clínicas.
- Profissional vê sua agenda e os dados administrativos necessários. Recepção vê agenda, cadastro mínimo e contato, sem avaliação, plano, adesão, sintomas ou observações nutricionais.
- Paciente vê e altera apenas as próprias solicitações/consultas ou as de dependentes com vínculo ativo.
- Título e descrição enviados ao Google Agenda devem usar conteúdo mínimo, sem diagnóstico, objetivo nutricional, sintomas ou plano alimentar.
- Links de teleconsulta são visíveis somente às pessoas participantes e não entram em logs públicos.
- Auditoria registra criação, aprovação, reagendamento, conclusão, ausência, cancelamento e sincronização, com ator e horário.

## Adesão

### Estados e registro

Cada ocorrência de refeição vigente pode receber um registro:

- `completed`: realizada conforme o plano;
- `adapted`: realizada com adaptação;
- `not_completed`: não realizada.

O registro representa relato do paciente, não confirmação clínica. Deve guardar ocorrência/data, refeição e versão publicada do plano. Nunca apontar somente para um rascunho mutável. Um novo envio para a mesma ocorrência cria revisão ou atualização auditável, sem duplicar a contagem.

Campos de contexto são opcionais e independentes do estado: fome, saciedade, humor, energia e sono em escala configurada; sintomas e motivo em texto curto/estrutura definida. O diário pode ser desativado por paciente. Quando desativado, novos registros são bloqueados, mas o histórico autorizado é preservado.

### Privacidade

- Paciente cria e lê apenas seus registros ou os de dependente com vínculo ativo.
- Nutricionista da clínica lê os registros de seus pacientes conforme vínculo assistencial.
- Recepção nunca lê adesão, escalas, sintomas ou motivos.
- Respostas não são incluídas em integrações de agenda, financeiro, WhatsApp ou métricas públicas.
- Relatórios agregados respeitam a mesma RLS e não revelam texto livre fora do caso individual.
- Alteração e leitura sensível devem ser auditáveis. Exclusão segue política de retenção/anonimização, sem remoção silenciosa.

### Alertas

Alertas são sinais para triagem, não diagnóstico nem decisão automática. Fontes iniciais: alergia relatada, sintomas configurados, repetição de `not_completed`, baixa ingestão, fome intensa e perda rápida de peso.

Cada alerta deve conter: clínica, paciente, origem, regra e versão, gravidade (`info`, `attention`, `urgent`), justificativa legível, instante, estado (`open`, `acknowledged`, `resolved`, `dismissed`) e responsável quando reconhecido. O evento original permanece preservado.

- Regras e limiares são configuráveis pelo profissional quando clinicamente apropriado.
- Alertas repetidos equivalentes usam janela de deduplicação, sem ocultar agravamento.
- Somente profissional reconhece, resolve ou descarta alerta clínico. Recepção não acessa seu conteúdo.
- `urgent` prioriza a fila, mas não promete monitoramento em tempo real nem aciona emergência automaticamente.
- Reconhecimento registra ator e horário; resolução ou descarte exige justificativa breve.
- Falha ao gerar notificação não remove o alerta.

## Linguagem neutra

- Usar “realizada”, “adaptada” e “não realizada”. Evitar “certa”, “errada”, “falha”, “jacada”, “culpa”, “obediência” ou “comportamento ruim”.
- Perguntar “O que dificultou esta refeição?” em vez de presumir falta de compromisso.
- Apresentar adesão como contexto para ajuste colaborativo, não como nota, ranking ou punição.
- Não usar vermelho isoladamente para classificar pessoas. Cor pode indicar prioridade operacional, sempre acompanhada de texto/ícone.
- Textos de alerta descrevem o dado observado: “Três refeições não realizadas nos últimos dois dias”. Não inferem intenção ou diagnóstico.

## Matriz mínima de testes SQL

Quando o schema estiver disponível, os testes pgTAP devem comprovar:

1. transições válidas passam e transições inválidas/finais falham;
2. fim anterior ou igual ao início falha;
3. intervalos adjacentes passam e sobreposição de profissional falha, inclusive entre clínicas;
4. sobreposição de sala falha e consulta cancelada libera o intervalo;
5. duas confirmações concorrentes não ocupam o mesmo recurso;
6. consulta presencial sem sala falha; online/domiciliar sem sala passa;
7. usuário de outra clínica não lê nem altera agenda;
8. recepção administra agenda, mas não lê adesão ou alerta clínico;
9. paciente acessa somente seus eventos e os de dependentes autorizados;
10. paciente não confirma, conclui ou marca ausência por conta própria;
11. adesão só referencia versão publicada acessível e ocorrência válida;
12. uma ocorrência não é contada duas vezes após correção;
13. diário desativado bloqueia novo registro e preserva histórico;
14. profissional autorizado lê adesão; paciente alheio e recepção não leem;
15. alertas preservam origem, justificativa e histórico de estados;
16. paciente e recepção não reconhecem/resolvem alertas clínicos;
17. cancelamento, reagendamento e sincronização geram auditoria;
18. consultas, adesão e alertas não vazam por views, funções `security definer` ou relatórios agregados.

Além de casos positivos, cada regra de autorização deve ter teste negativo com outro usuário e outra clínica. Funções privilegiadas devem fixar `search_path`, validar o ator autenticado e não aceitar `organization_id` como autoridade suficiente.
