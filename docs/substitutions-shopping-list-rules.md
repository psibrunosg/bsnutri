# Regras de substituições e lista de compras

Este documento define o comportamento esperado no piloto para substituições alimentares e geração de lista de compras. Ele orienta schema, RLS, funções, interface e testes. O plano publicado continua sendo a fonte clínica de verdade.

## Substituições

### Modelo e autoria

- Uma opção de substituição pertence a um item de refeição e à versão do plano em que foi prescrita.
- O profissional pode cadastrar nenhuma, uma ou várias opções para o mesmo item.
- Cada opção registra alimento, quantidade, unidade, medida caseira opcional, observação e ordem de exibição.
- A quantidade prescrita e o alimento são dados clínicos. O paciente não os altera diretamente.
- A IA pode sugerir substituições, mas toda sugestão permanece em rascunho até revisão explícita do profissional.
- A revisão registra profissional e horário. Publicar um plano com sugestão de IA não revisada deve falhar.
- Alterar uma substituição de versão publicada cria nova versão. Nunca muda retroativamente o que o paciente recebeu.

### Equivalência e segurança

- A substituição é uma alternativa prescrita, não uma declaração de equivalência perfeita.
- O sistema calcula a diferença nutricional em relação ao item original usando o mesmo catálogo, porção e snapshot usados no plano.
- O profissional visualiza energia, macronutrientes e nutrientes relevantes disponíveis. Ausência de dado não é tratada como zero.
- Limiares de proximidade são apoio visual configurável e não aprovam automaticamente uma opção.
- Alérgenos, restrições, preferências e incompatibilidades conhecidas geram aviso legível antes da revisão e da publicação.
- Um aviso não pode ser ocultado apenas por mudança de nome do alimento ou de medida caseira.
- Alimento inativo ou sem informação nutricional pode permanecer em histórico publicado, mas não pode entrar em nova opção sem confirmação explícita do profissional.

### Uso pelo paciente

- O paciente vê somente opções revisadas da versão publicada vigente e pode escolher uma delas durante o registro da refeição.
- A escolha não altera o plano nem substitui a prescrição para dias futuros.
- O check-in registra o item original, a opção escolhida e a versão publicada, preservando o contexto histórico.
- Quando nenhuma opção prescrita atende, o paciente pode enviar uma solicitação de troca com texto curto. A solicitação não vira opção automaticamente.
- O profissional pode aprovar a solicitação somente criando uma opção revisada em nova versão do plano.
- A interface usa linguagem neutra: “opção”, “troca” e “adaptação”. Evita classificar alimento ou escolha como “certo”, “errado”, “permitido” ou “proibido”.

### Privacidade e acesso

- RLS isola todas as opções, escolhas e solicitações por clínica e vínculo assistencial.
- Profissional autorizado administra substituições de seus pacientes e modelos da clínica.
- Paciente ou responsável com vínculo ativo lê opções publicadas e cria escolhas/solicitações apenas para si ou dependente autorizado.
- Recepção não lê nutrientes, justificativas clínicas, escolhas ou solicitações de troca.
- Modelos copiados para um paciente tornam-se independentes. Editar o plano do paciente não altera o modelo de origem.

## Lista de compras

### Origem e período

- A lista é uma projeção derivada de uma versão publicada, nunca de rascunho mutável.
- O usuário escolhe intervalo inclusivo de datas. O sistema considera somente os dias do plano que incidirem nesse intervalo.
- Por padrão, a lista usa os itens principais prescritos. Substituições aparecem em seção separada e não são somadas simultaneamente ao item original.
- Quando o usuário escolhe uma opção para uma ocorrência futura, somente aquela ocorrência troca a contribuição do item na lista.
- Regenerar a lista com os mesmos dados e escolhas produz o mesmo resultado.

### Normalização e agregação

- Quantidades são convertidas para unidade canônica antes da soma, preservando o valor e a unidade originais para apresentação e auditoria.
- Massa soma com massa e volume soma com volume. Unidades incompatíveis nunca são somadas silenciosamente.
- Medida caseira sem fator confiável permanece como linha separada, marcada como estimativa ou pendência de conversão.
- Ingredientes são agrupados por identificador do catálogo. Texto livre só é agrupado quando a normalização for inequivocamente igual.
- A agregação não arredonda entre etapas. O arredondamento ocorre apenas na apresentação e o valor canônico é preservado.
- Itens opcionais, temperos “a gosto” e água podem ser ocultados, mas essa preferência deve ser explícita e reversível.
- A lista pode ser organizada por categoria de mercado sem alterar quantidades ou procedência.

### Interação e compartilhamento

- O usuário pode marcar itens como comprados sem alterar o plano ou a próxima lista gerada.
- Ajustes manuais ficam identificados como tais e não modificam dados clínicos nem snapshots nutricionais.
- O piloto permite visualizar, imprimir e exportar arquivo. Compartilhamento inicial ocorre por link externo gerado pelo próprio usuário, sem expor dados clínicos além dos itens da lista.
- O conteúdo compartilhado não inclui diagnóstico, objetivo clínico, sintomas, adesão, nome do plano ou observações internas.
- Um link revogado ou expirado deixa de conceder acesso. Tokens não aparecem em logs de interface ou métricas.

### Consistência e histórico

- A lista guarda referência à versão publicada, período, escolhas consideradas e instante de geração.
- Nova publicação não reescreve listas antigas. O usuário pode regenerar conscientemente a partir da versão vigente.
- Exclusão ou inativação posterior de alimento não remove itens de listas históricas.
- Fuso horário da clínica determina a ocorrência diária. Alteração de fuso não pode duplicar nem omitir silenciosamente um dia já materializado.

## Casos limítrofes obrigatórios

1. intervalo de um único dia e intervalo atravessando a troca de semana;
2. mesma comida em refeições diferentes agregada corretamente;
3. gramas e quilogramas convertidos antes da soma;
4. gramas e mililitros mantidos separados sem densidade cadastrada;
5. medida caseira sem conversão exibida como pendência;
6. item original e todas as substituições não somados juntos;
7. escolha de substituição aplicada somente à ocorrência escolhida;
8. plano republicado preservando lista e escolhas históricas;
9. item de catálogo inativado preservado no histórico;
10. virada de horário de verão/fuso sem duplicação de ocorrência;
11. usuário de outra clínica sem acesso à lista ou às opções;
12. recepção sem acesso a substituições, nutrientes e solicitações.

## Matriz mínima de testes

### Testes unitários

1. normalização converte `kg` para `g` e `l` para `ml` sem arredondamento intermediário;
2. agregação é determinística e independe da ordem de entrada;
3. unidades incompatíveis resultam em linhas distintas;
4. período inclusivo materializa exatamente as ocorrências esperadas;
5. escolha de substituição remove apenas a contribuição original correspondente;
6. opções não escolhidas nunca entram no total principal;
7. agrupamento por catálogo não mistura textos livres ambíguos;
8. apresentação arredonda sem modificar o total canônico;
9. geração não altera os objetos do plano recebidos como entrada;
10. lista vazia e plano sem dias retornam resultado válido e explicável.

### Testes SQL e RLS

1. somente versão publicada aceita geração ou persistência de lista;
2. sugestão de IA sem revisão bloqueia publicação;
3. edição de versão publicada falha e nova versão preserva o histórico;
4. paciente lê somente opções revisadas e publicadas do próprio vínculo;
5. paciente não cria, aprova, ordena ou exclui opção prescrita;
6. solicitação de troca não altera diretamente plano ou catálogo;
7. outra clínica não lê nem modifica opção, escolha, solicitação ou lista;
8. recepção não acessa nenhuma dessas entidades clínicas;
9. lista persiste versão, período e escolhas usadas na geração;
10. revogação de compartilhamento invalida o token sem apagar o histórico;
11. funções privilegiadas fixam `search_path` e validam o ator autenticado;
12. identificadores fornecidos pelo cliente não contornam vínculo, organização ou publicação.

## Critérios de aceite do piloto

- Profissional cria e revisa opções no editor e as publica em versão imutável.
- Paciente escolhe uma opção publicada ou solicita uma troca sem alterar a prescrição.
- Lista de compras é gerada para período escolhido, com totais reprodutíveis e origem rastreável.
- Unidades não conversíveis são apresentadas com clareza, nunca somadas por aproximação silenciosa.
- Interface funciona integralmente em celular, tablet e desktop.
- Testes positivos e negativos cobrem isolamento entre clínicas, papéis e histórico publicado.
