# BSNutri: transição do MVP para o sistema operacional

## Decisão principal

O próximo ciclo deve ter um único foco: transformar a montagem do plano alimentar em um fluxo rápido, confiável e completo.

O BSNutri já possui boa parte da infraestrutura ao redor da prescrição: pacientes, papéis, RLS, catálogo alimentar, dias, refeições, itens, cálculos, versões, revisão, publicação, modelos, substituições, lista de compras, diário e portal do paciente. O problema atual não é ausência de módulos. É que o valor central ainda está fragmentado e parte da experiência continua com aparência de protótipo.

Não devemos iniciar financeiro, chat, relatórios, automações amplas ou IA generativa agora. Esses recursos aumentam a superfície do produto sem resolver o principal motivo para um nutricionista usá-lo todos os dias.

## O que ainda mantém o fluxo com aparência manual

1. O editor concentra muitas funções em uma tela densa e em um componente grande.
2. Parte da criação ocorre em estado local antes do salvamento, sem uma experiência clara de salvamento automático e recuperação.
3. Salvar um plano como modelo ainda usa caixas nativas de `prompt`.
4. O assistente de plano organiza etapas, mas ainda funciona como shell de estado e validação, não como ganho real de produtividade.
5. Modelos podem ser criados e copiados, mas falta uma entrada simples que ofereça: começar vazio, usar modelo ou duplicar plano anterior.
6. O catálogo já é consultado, porém a busca e a inclusão de alimentos precisam ser avaliadas como tarefa de velocidade, não apenas como CRUD.
7. Os atalhos que mais reduzem trabalho ainda não formam uma jornada coesa: duplicar refeição, duplicar dia, editar quantidade em linha, trocar alimento e desfazer.
8. O sistema possui estrutura para cálculos e metas, mas a comparação precisa acompanhar a edição sem exigir navegação técnica.
9. A validação descrita no handoff ainda depende de smoke test manual no deploy.

## Fase imediata: fechar a validação do que já foi publicado

Antes de alterar o editor, executar e registrar evidência dos três fluxos do handoff:

1. profissional cria e atribui pré-consulta;
2. paciente salva rascunho e envia anamnese;
3. profissional salva plano como modelo e copia para outro paciente.

Se houver falha, corrigir somente o bloqueio encontrado. Essa validação deve durar no máximo um ciclo curto e não virar uma nova fase de produto.

## Próxima entrega: Editor Rápido de Planos

### Jornada mínima

1. Abrir o paciente e selecionar `Novo plano`.
2. Escolher entre `Modelo`, `Plano anterior` e `Em branco`.
3. Definir o tipo do plano: calculado, qualitativo ou híbrido.
4. Montar refeições por busca de alimentos, receitas ou orientação livre.
5. Ajustar quantidade ou medida caseira diretamente na linha.
6. Duplicar refeição ou dia sem reconstrução manual.
7. Ver energia e macronutrientes atualizados durante a edição.
8. Comparar os totais com a meta do paciente.
9. Visualizar como o paciente receberá.
10. Revisar e publicar a versão imutável.

### Escopo técnico mínimo

1. Criar uma entrada única para `modelo`, `plano anterior` ou `vazio`, reutilizando as RPCs e tabelas existentes.
2. Substituir `window.prompt` por formulário pequeno dentro do editor para nome e tags do modelo.
3. Persistir rascunho de maneira previsível, com indicador `salvando`, `salvo` e `erro`.
4. Garantir recuperação do rascunho após recarregar a página.
5. Implementar duplicação de refeição e dia.
6. Manter edição de quantidade na própria linha.
7. Exibir totais do plano e da refeição durante a edição.
8. Manter revisão e publicação pelas RPCs já existentes.
9. Criar um único teste de jornada do profissional cobrindo criação até publicação.
10. Validar no portal que o paciente recebe exatamente a versão publicada.

### O que não entra nessa entrega

1. IA gerando plano completo.
2. Importação ampla de TACO ou TBCA antes da decisão documental sobre licença.
3. Financeiro, chat, videochamada e relatórios gerenciais.
4. Aplicativo nativo.
5. Editor visual sofisticado com arrastar e soltar, caso botões de duplicação e ordenação resolvam a tarefa.
6. Micronutrientes completos antes de energia e macronutrientes estarem confiáveis no fluxo principal.

## Ordem recomendada de implementação

### 1. Medir o fluxo atual

Registrar uma sessão real com dados sintéticos:

1. tempo até publicar um plano de um dia;
2. quantidade de cliques;
3. pontos em que o profissional precisa redigitar;
4. erros ou dúvidas durante a montagem.

Essa será a linha de base. Sem ela, “facilidade” vira opinião.

### 2. Fechar a entrada e a persistência

Entregar:

1. modelo, plano anterior ou vazio;
2. autosave com recuperação;
3. formulário real para salvar modelo;
4. estados de vazio, carregamento e erro.

### 3. Entregar os atalhos de prescrição

Entregar:

1. busca rápida de alimento;
2. quantidade e medida caseira em linha;
3. duplicar refeição;
4. duplicar dia;
5. trocar alimento;
6. orientação livre no mesmo editor.

### 4. Integrar cálculo, revisão e publicação

Entregar:

1. totais por refeição e por plano;
2. comparação com meta;
3. avisos de dados ausentes e restrições;
4. prévia do paciente;
5. revisão e publicação;
6. conferência da versão publicada no portal.

### 5. Testar com uso real e só então ampliar

Realizar três montagens completas:

1. plano qualitativo simples;
2. plano calculado de um dia;
3. plano semanal derivado de modelo.

Corrigir os gargalos observados antes de iniciar outro módulo.

## Métricas para aprovar a entrega

1. Criar e publicar um plano simples em até 10 minutos.
2. Adaptar um modelo para outro paciente em até 5 minutos.
3. Recuperar rascunho após recarregar a página sem perda.
4. Não redigitar refeições ao criar variações de dia.
5. Totais exibidos no editor iguais aos totais da versão publicada.
6. O paciente visualizar somente a versão publicada.
7. Lint, testes, build e testes SQL aplicáveis verdes.

## Próximos ciclos depois do Editor Rápido

1. Receitas e medidas caseiras versionadas.
2. Equivalentes assistidos e substituições com comparação nutricional.
3. Consulta guiada conectando anamnese, antropometria, metas e plano.
4. Diário e acompanhamento orientados pela versão publicada.
5. Documentos e PDF.
6. Agenda, comunicação e operação da clínica.
7. Relatórios e financeiro leve.

## Riscos e lacunas

1. O editor principal já é grande. A separação deve ocorrer apenas quando uma parte puder ser isolada por responsabilidade real, sem criar uma arquitetura paralela.
2. A facilidade precisa ser validada com nutricionista montando plano, não apenas com testes técnicos.
3. Catálogo incompleto reduz a utilidade do editor mesmo que a interface esteja boa.
4. Dados nutricionais sem fonte, versão ou distinção entre zero e ausente comprometem os cálculos.
5. Autosave mal implementado pode sobrescrever alterações. Deve existir controle simples de versão ou atualização condicional.

## Melhorias futuras por grupo

### Prescrição

1. favoritos e alimentos recentes;
2. blocos de refeições reutilizáveis;
3. atalhos de teclado;
4. receitas próprias;
5. comparação com versão anterior;
6. equivalentes sugeridos com revisão profissional.

### Consulta

1. levar metas calculadas diretamente ao editor;
2. abrir anamnese e restrições ao lado da prescrição;
3. registrar pendências sem impedir encerramento da consulta.

### Paciente

1. plano mais legível no celular;
2. lista de compras por período;
3. registro de refeição em até três toques;
4. solicitação de troca ligada ao item prescrito.

### Gestão

1. medir tempo médio de montagem;
2. acompanhar uso de modelos;
3. identificar etapas que mais geram abandono ou retrabalho.

## Ideias frágeis registradas

1. IA para gerar plano completo. Pode voltar quando catálogo, metas, restrições, auditoria e revisão estiverem maduros.
2. Editor por arrastar e soltar. Pode ser útil, mas botões de duplicar e ordenar provavelmente entregam valor antes e com menos complexidade.
3. Aplicativo profissional nativo. A edição web responsiva atende primeiro; aplicativo pode ser avaliado quando houver uso recorrente.
4. Importação de grandes bases alimentares. Deve esperar análise de licença, importador reproduzível e política de atualização.

## Próxima ação objetiva

Executar o smoke test do handoff e, em seguida, abrir uma entrega única chamada `Editor Rápido de Planos`, começando pela medição do fluxo atual e pela entrada `modelo, plano anterior ou vazio`.
