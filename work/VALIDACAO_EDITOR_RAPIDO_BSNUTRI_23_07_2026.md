# Validacao do Editor Rapido BSNutri - 23/07/2026

## Objetivo

Validar se o editor ja saiu do fluxo manual basico e permite montar plano com velocidade proxima ao objetivo do produto: facilidade para definir planos alimentares.

## Criterios de sucesso

1. Plano do zero em ate 10 minutos.
2. Adaptacao de modelo em ate 5 minutos.
3. Ajuste de plano anterior em ate 5 minutos.
4. Nenhuma perda de trabalho ao fechar ou atualizar a pagina antes de salvar.
5. Nutricionista consegue ajustar alimento e gramas sem remover e recriar item.

## Caso 1 - Plano em branco

Fluxo:

1. Abrir `Editor de plano`.
2. Clicar `Em branco`.
3. Selecionar paciente.
4. Definir objetivo clinico.
5. Buscar alimento.
6. Adicionar item com gramas.
7. Editar gramas no item.
8. Trocar alimento no item.
9. Duplicar refeicao.
10. Duplicar dia.
11. Salvar rascunho.

Aceite:

1. O editor nao exige recriar refeicao para ajustes simples.
2. Totais mudam ao alterar gramas ou alimento.
3. O fluxo fica compreensivel sem treinamento longo.

## Caso 2 - Adaptacao de modelo

Fluxo:

1. Selecionar paciente.
2. Clicar em um modelo existente.
3. Confirmar que o rascunho copiado abre automaticamente.
4. Ajustar gramas.
5. Trocar um alimento.
6. Salvar novo rascunho.

Aceite:

1. O usuario nao precisa procurar manualmente o plano copiado na lista.
2. O modelo vira rascunho independente.
3. A adaptacao acontece em poucos cliques.

## Caso 3 - Usar plano anterior como base

Fluxo:

1. Abrir plano anterior do paciente.
2. Clicar `Usar plano aberto como base`.
3. Confirmar que o titulo vira copia e o plano deixa de estar vinculado ao rascunho anterior.
4. Ajustar refeicoes, alimentos e gramas.
5. Salvar como novo rascunho.

Aceite:

1. O plano anterior nao e sobrescrito.
2. O novo plano pode ser salvo separadamente.
3. O usuario consegue reaproveitar estrutura sem recriar tudo.

## Caso 4 - Recuperacao de rascunho local

Fluxo:

1. Comecar um plano.
2. Alterar objetivo, titulo, refeicoes e itens.
3. Atualizar a pagina antes de salvar.
4. Clicar `Restaurar`.

Aceite:

1. O conteudo volta com paciente, titulo, dias, refeicoes, metas e assistente.
2. O usuario pode descartar se nao quiser recuperar.
3. O rascunho recuperado pode ser salvo normalmente.

## Cobertura automatizada atual

Os testes de UI ja cobrem:

1. Alternancia entre modo rapido e tecnico sem perder dados.
2. Duplicacao de dia e refeicao.
3. Busca de alimento ao adicionar item.
4. Edicao inline de gramas.
5. Troca de alimento sem remover item.
6. Criacao em branco.
7. Uso de plano aberto como base.
8. Restauracao e autosave local.
9. Copia de modelo com abertura automatica do rascunho.
10. Bloqueio extra antes de publicar sem substituicoes revisadas.

## Pendencias apos validacao

Registrar para cada caso:

1. Tempo real gasto.
2. Onde houve duvida.
3. Onde faltou informacao visual.
4. Onde houve clique repetitivo.
5. Se o profissional entendeu a diferenca entre salvar rascunho, revisar e publicar.

