# Validação clínica da lista inicial de alimentos

Data da análise: 24/07/2026

## Resultado

A lista contém 135 alimentos e pode entrar no BSNutri como catálogo provisório para cálculo de energia e macronutrientes. Ela não deve receber o status de fonte clínica validada.

O problema principal não é haver números absurdos em toda a lista. A maior parte é nutricionalmente plausível. O problema é a falta de rastreabilidade: não há código do alimento na fonte, versão da base, método de preparo detalhado, parte comestível, marca, receita ou critério de arredondamento. Também há indícios claros de mistura entre fontes e definições diferentes do mesmo alimento.

Na prática, o uso seguro é:

1. cadastrar os 135 itens como `pending_review`;
2. permitir busca e edição pelo nutricionista;
3. não identificá-los como "verificados", "TACO", "TBCA" ou "IBGE";
4. não usá-los silenciosamente em modelos automáticos que o sistema apresente como clinicamente revisados;
5. substituir cada registro por uma versão rastreável durante a curadoria.

## Fontes oficiais consultadas

1. [TBCA, versão 7.2](https://www.tbca.net.br/index.html), desenvolvida pela USP, BRASILFOODS e FoRC. A base informa mais de 5.700 alimentos, incluindo mais de 4.000 preparações.
2. [TACO, 4ª edição revisada e ampliada, 2011](https://www.gov.br/agricultura/pt-br/assuntos/inspecao/produtos-vegetal/legislacao-programas-nacionais-e-seguranca-dos-alimentos-1/legislacao/legislacao-vinhos-e-bebidas/tabela-brasileira-de-composicao-de-alimentos_taco_2011.pdf/view), publicada pelo NEPA/Unicamp e disponibilizada no portal do Ministério da Agricultura.
3. [IBGE, POF 2008-2009, Tabelas de Composição Nutricional dos Alimentos Consumidos no Brasil](https://biblioteca.ibge.gov.br/visualizacao/livros/liv50002.pdf). A publicação apresenta energia, macronutrientes, fibra, gorduras, açúcares, minerais, vitaminas e a fonte de referência por 100 g de parte comestível.
4. [Arquivos completos da tabela do IBGE](https://ftp.ibge.gov.br/Orcamentos_Familiares/Pesquisa_de_Orcamentos_Familiares_2008_2009/Tabelas_de_Composicao_Nutricional_dos_Alimentos_Consumidos_no_Brasil/).
5. [USDA FoodData Central, documentação dos tipos de dados](https://fdc.nal.usda.gov/data-documentation/) e [documentação de Foundation Foods](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/). A base distingue alimentos básicos analisados, alimentos de inquéritos alimentares e produtos de marca. Essa distinção importa, pois os dados de marca vêm dos fabricantes e não equivalem a análise laboratorial de um alimento genérico.
6. [USDA FoodData Central API](https://fdc.nal.usda.gov/api-guide/). Os dados são publicados em domínio público sob CC0 1.0 e podem ser incorporados com registro da fonte.

A TBCA exige cuidado específico de licenciamento. As páginas de composição informam CC BY-NC-ND 4.0, exigem citação, proíbem comercialização e também registram restrição à reprodução total ou parcial. Um exemplo pode ser conferido na [página oficial de composição de um alimento](https://www.tbca.net.br/base-dados/int_composicao_estatistica2.php?cod_produto=1960C). Portanto, copiar a TBCA em massa para um produto comercial não deve ser o caminho padrão sem autorização formal.

## Como a lista foi avaliada

A análise considerou quatro critérios:

1. plausibilidade interna entre energia, proteína, carboidrato e gordura;
2. correspondência do nome com o estado de preparo;
3. comparação pontual com valores oficiais do IBGE;
4. dependência de marca, corte, receita, drenagem, teor de água ou ingredientes adicionados.

As comparações abaixo usam a ordem kcal, proteína, carboidrato e gordura por 100 g. Diferença em relação ao IBGE não prova que o valor informado esteja errado. Pode significar que se trata de outro alimento, outra base ou outro preparo. Sem o código e a origem, essa distinção se perde.

## Comparação pontual

| Alimento | Lista recebida | Referência IBGE comparável | Avaliação |
|---|---:|---:|---|
| Ovo de galinha, cozido | 155; 13,0; 1,1; 11,0 | 155; 12,58; 1,12; 10,61 | Alinhamento bom, diferenças de arredondamento |
| Leite integral | 61; 3,2; 4,8; 3,3 | 60,03; 3,22; 4,52; 3,25 | Alinhamento bom |
| Água de coco | 19; 0,7; 3,7; 0,2 | 19,28; 0,73; 3,76; 0,20 | Alinhamento muito bom |
| Peito de frango, grelhado | 165; 31,0; 0; 3,6 | 173; 30,91; 0; 4,51 | Diferença moderada, possivelmente outra base ou retirada de gordura |
| Pão francês | 270; 8,0; 56,0; 1,0 | Pão de sal: 300; 8,0; 58,6; 3,1 | Energia e gordura materialmente menores na lista |
| Pão de queijo | 363; 5,0; 33,0; 18,0 | 363; 5,10; 34,20; 24,60 | Gordura 27% menor na lista, apesar da mesma energia |
| Pão integral | 253; 9,0; 49,0; 3,0 | 247; 12,95; 41,29; 3,35 | Diferenças importantes em proteína e carboidrato |
| Alcatra, grelhada | 163; 24,0; 0; 6,6 | 204; 30,67; 0; 9,0 | Diferença grande em energia, proteína e gordura |
| Patinho, cozido | 163; 26,0; 0; 6,0 | 199; 36,12; 0; 5,0 | Proteína muito menor na lista |
| Acém, cozido | 215; 26,0; 0; 12,0 | 242; 24,22; 0; 15,42 | Energia e gordura menores na lista |
| Refrigerante de cola | 42; 0; 11,0; 0 | 36,87; 0,07; 9,53; 0,02 | Compatível com fórmulas comerciais diferentes, não com um item genérico único |

O IBGE também mostra por que o preparo precisa ser mais específico. Na sua compilação, o arroz branco e o integral receberam 0,98 ml de óleo de soja por 100 g. Para o feijão, foi usada uma diluição de 60% de alimento e 40% de água para aproximar a composição brasileira. Preparações com molho foram padronizadas com 80 g do alimento e 20 g de molho. Portanto, "cozido" não informa se há óleo, sal, caldo ou a quantidade de água retida. Esses detalhes alteram o resultado clínico.

## Itens que exigem revisão prioritária

### 1. Preparações cuja descrição está incompleta

Estes itens podem permanecer como estimativas, mas o nome atual não define o alimento com precisão suficiente:

1. arroz branco e integral, feijões, lentilha e grão-de-bico: informar se houve óleo, sal e proporção de caldo;
2. pipoca: os valores se parecem com pipoca estourada sem óleo, mas o cadastro diz apenas "estourada";
3. tapioca preparada e cuscuz nordestino: informar hidratação, rendimento e ingredientes;
4. macarrão: separar cozido sem óleo, com óleo e com molho;
5. carnes: informar corte, presença de gordura aparente, pele, osso e óleo adicionado;
6. atum em água: informar se o peso é drenado;
7. bacalhau: informar dessalga e teor de sódio;
8. açaí: registrar se a polpa é pura, adoçada e qual é o teor de sólidos;
9. palmito em conserva: registrar se o valor se refere ao produto drenado;
10. café, chá e sucos: informar açúcar adicionado e diluição.

### 2. Produtos dependentes de marca

Uma média genérica serve para triagem, não para prescrição de maior precisão. Devem receber marca ou uma referência composta documentada:

1. pão de forma, pão integral e pão de queijo industrializado;
2. presunto, mortadela e calabresa;
3. atum em conserva;
4. iogurte natural, queijos, requeijão, cottage e leite condensado;
5. manteiga de amendoim e margarina;
6. achocolatado em pó;
7. biscoito maisena e cream cracker;
8. refrigerante, cerveja e vinho;
9. catchup, maionese e molho de tomate.

Nesses produtos, sódio, açúcar, gordura e umidade mudam bastante entre fabricantes. O valor médio não substitui o rótulo do produto consumido.

### 3. Receitas que não devem ser tratadas como alimento único

Brigadeiro, bolo de chocolate, doce de leite, goiabada e pão de queijo artesanal dependem da receita e do rendimento. O cadastro correto precisa manter a receita, o peso final e a perda ou ganho de água. Um único valor genérico pode existir como exemplo, desde que o sistema o identifique como receita de referência.

### 4. Alimentos simples com valores plausíveis

Os valores de frutas, hortaliças, ovos, leite, óleos, açúcares e várias leguminosas são, em geral, plausíveis como médias por 100 g. Ainda assim, plausibilidade não substitui procedência. Frutas variam por cultivar e maturação; hortaliças variam com cocção e drenagem; carnes variam com corte e gordura retirada.

## Limites clínicos da estrutura atual

Energia, proteína, carboidrato e gordura bastam para uma estimativa inicial de macros. Não bastam para avaliar vários objetivos já previstos no BSNutri.

1. Controle glicêmico precisa, no mínimo, de fibra, açúcares e descrição do processamento. Resposta glicêmica não pode ser inferida apenas do carboidrato total.
2. Hipertensão e doença renal exigem atenção a sódio, potássio e fósforo.
3. Dislipidemias pedem gordura saturada e, conforme o caso, perfil de ácidos graxos.
4. Anemias e outras deficiências pedem micronutrientes e informação sobre biodisponibilidade, não apenas macros.
5. Cerveja e vinho precisam de álcool em gramas. Parte relevante da energia vem do etanol e não aparece nos três macronutrientes registrados.
6. Planos por porção exigem medidas caseiras confiáveis e peso da parte comestível.

## Critério recomendado para liberar um alimento

Um alimento pode mudar de `pending_review` para `reviewed` quando tiver:

1. fonte oficial identificada;
2. versão ou data da fonte;
3. código do alimento na fonte;
4. base de referência por 100 g de parte comestível;
5. descrição compatível com o preparo;
6. marca, quando aplicável;
7. receita e rendimento, quando for preparação;
8. pelo menos energia, proteína, carboidrato, gordura, fibra e sódio;
9. data e responsável pela revisão;
10. comparação documentada quando duas fontes oficiais divergirem.

Para alimentos brasileiros, a ordem prática de curadoria é TACO ou fonte pública do IBGE, depois TBCA apenas dentro dos limites de licença. O USDA é útil para preencher lacunas e para produtos internacionais, mas o sistema deve manter o identificador FDC e o tipo de dado. Foundation Foods, FNDDS e Branded Foods não são intercambiáveis.

## Conclusão

Os 135 registros são aproveitáveis como catálogo provisório de energia e macronutrientes. Eles não formam uma base clínica auditada.

Há três grupos:

1. itens com bom alinhamento pontual, como ovo, leite integral e água de coco;
2. itens plausíveis, mas sem origem e definição suficientes;
3. itens com discrepâncias importantes ou alta dependência de marca e receita, especialmente pães, cortes bovinos, embutidos, laticínios, preparações doces, molhos e bebidas comerciais.

A decisão correta é cadastrar agora com origem "lista fornecida pelo usuário", manter `pending_review` e bloquear qualquer selo de validação clínica. A curadoria deve trocar valores provisórios por registros versionados e rastreáveis, sem sobrescrever o histórico.
