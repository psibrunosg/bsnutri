# Benchmark Dietbox — 04 de agosto de 2026

> Atualizado no mesmo dia com mapeamento completo de todos os módulos do produto (não só Plano alimentar). Ver seção "Mapa completo de módulos" e "Prontuário e Gastos energéticos" mais abaixo — achado mais importante da segunda passada é a separação real entre estimativa energética e meta de plano, que confirma o achado 3 da auditoria de 31/07.


Análise da plataforma concorrente Dietbox (dietbox.me), já logada pelo usuário no navegador interno, sem uso de credenciais por este agente. Objetivo: extrair estrutura de dados (catálogo de alimentos, plano alimentar) e tokens de design pra comparar contra o BSNutri e informar o redesign.

Paciente de teste usado na navegação é o próprio usuário (auto-cadastro na ferramenta); nenhum dado de terceiro foi acessado ou é citado aqui.

## Navegação e IA

Menu lateral, grupo "Plano alimentar":
- **Cardápios** — biblioteca de planos completos (templates)
- **Refeições** — biblioteca de refeições reutilizáveis (templates menores)
- **Receitas**
- **Alimentos** — catálogo de alimentos

Grupo "Prescrições": Modelos de Prescrições, Suplementos, Fitoterápicos.
Grupo "Outros cadastros": Modelos de anamnese, Modelos de QPC, Solicitações de exames, **Listas de substituição**, Farmácias para orçamento, Formulários offline, Tags.

Padrão repetido em Alimentos, Refeições e Cardápios: duas abas, **"Meus X"** (conteúdo próprio do nutricionista) vs **"X do Dietbox"** (biblioteca curada pela plataforma). BSNutri já tem essa dualidade em modelos de plano (`builtInPlanModels` vs pessoal), mas não em alimentos nem em refeições.

## Catálogo de alimentos

Aba "Alimentos" tem 7 fontes selecionáveis: **Meus alimentos, Taco, IBGE, USDA, TBCA, Tucunduva, Dietbox, Suplementos**. TACO/IBGE/USDA/TBCA são tabelas de composição nutricional públicas e reconhecidas; Tucunduva/Dietbox/Suplementos são bases próprias da plataforma (a última cobre produtos de suplementação, ex.: whey, psyllium).

Nomenclatura segue padrão científico de tabela de composição: `Alimento, descritor, descritor` (ex.: "Abacaxi, cru", "Peito de galinha ou frango Refogado(a)", "Abadejo, filé, congelado, assado") — separado por vírgula, do geral pro específico.

### Schema de um alimento (campos do formulário de edição)

- **Nome**, **Porção** (base 100g), **Calorias**, **Grupo** (categoria, com "Adicionar novo grupo" inline)
- **Macronutrientes**: Proteínas, Carboidratos, Lipídeos
- **Micronutrientes** (seção colapsável "Ocultar/exibir", 25 campos): Açúcar, Cálcio, Colesterol, Ferro, Fibra alimentar, Gordura Monoinsaturada, Gordura Poli-insaturada, Gordura Saturada, Gordura Trans, Fósforo, Magnésio, Manganês, Potássio, Selênio, Sódio, Vitamina A (Retinol), B1 (Tiamina), B2 (Riboflavina), B3 (Niacina), B6 (Piridoxina), B9 (Ácido fólico), B12 (Cobalamina), C (Ácido ascórbico), D (Calciferol), E (Tocoferol), Zinco
- **Medidas caseiras**: lista de pares unidade→gramas (ex.: "Colher De Sopa: 9,0 g"), adicionável, várias por alimento

Comparado ao `CatalogFood.nutrients` do BSNutri (`src/lib/useFoodCatalog.ts`): hoje só 10 chaves (`energyKcal, proteinG, carbohydrateG, fatG, fiberG, sodiumMg, calciumMg, ironMg, potassiumMg, vitaminCMg`). Dietbox cobre quase 3× mais micronutrientes, incluindo todo o complexo B e gorduras por tipo (saturada/mono/poli/trans) — relevante pra prescrição clínica de dislipidemia, por exemplo.

## Estrutura do plano alimentar (Cardápio)

Editor de cardápio tem **três modos** selecionáveis no topo:
1. **Modelo de plano** — usa um modelo salvo como base
2. **Alimentos calculados** — modo padrão, item a item com quantidade e cálculo nutricional automático
3. **Texto livre** — plano escrito sem estrutura, sem cálculo (escape hatch pra prescrição rápida sem precisão nutricional)

BSNutri não tem equivalente ao "Texto livre" — todo plano passa pelo editor estruturado. Pode valer a pena como atalho pra consulta muito rápida.

Cada refeição (ex.: "Café da manhã 08:30"):
- Nome + horário
- Ações: **Ver nutrientes** (nutrientes só daquela refeição), duplicar, editar, excluir
- Lista de itens, formato **`Nome do alimento (Unidade: quantidade)`** — ex.: `Ovo de galinha Cozido(a) (Unidade: 2)`, `Pão, trigo, forma, integral (Fatia (30g): 1)`, `Whey Protein Concentrado DUX - Baunilha (Scoop: 2)`. Quando a medida caseira tem gramatura fixa, ela aparece entre parênteses no nome da unidade.
- **Substituição em nível de refeição inteira** ("Nenhuma refeição substituta" / "Adicionar Substituição") — o nutricionista cadastra uma refeição alternativa completa pro paciente trocar, não item por item.

Isso é uma diferença estrutural importante: BSNutri modela substituição por **item** (`hasReviewedSubstitution` em `EditableMealCard`, achado 2 da auditoria de 31/07), Dietbox modela por **refeição inteira**. Substituição por refeição é mais simples de garantir consistência nutricional (a refeição alternativa já foi calculada como um todo), mas é menos flexível pro paciente trocar só um item. Vale decisão consciente, não default por acidente.

Rodapé do editor, "Resumo de nutrientes": PTN/CHO/LIP em gramas **e em % do valor calórico total** (ex.: `PTN 145,42g (38,2%)`), Kcal total, link "Ver todos os nutrientes" (expande a lista completa) e "Configurar valores de referência" (metas de referência configuráveis por plano). BSNutri mostra só gramas absolutas no live-totals (`macroKeys`/`macroLabels`, `NutritionWorkspace.tsx`), sem percentual de VET — fácil de adicionar, é só dividir por `energyKcal`.

## Bibliotecas de template

**Cardápios** ("Meus cardápios" / "Cardápios Dietbox"): nomeados por padrão calórico + perfil, ex.: `Dieta 1.800 Kcal (20% PTN)`, `Dieta Low Carb - 1500 kcal`, `Dieta de Carga Glicêmica Leve e Hiperproteica 1.900 Kcal`. Mesma ideia do `builtInPlanModels`/`ModelDimensions` do BSNutri, mas a nomenclatura do Dietbox já embute kcal-alvo e %proteína no nome, o que facilita busca visual rápida sem abrir o modelo.

**Refeições**: mesma dualidade Meus/Dietbox, com filtro; permite montar refeição avulsa reutilizável fora do contexto de um plano completo — BSNutri não tem esse nível intermediário (só planos inteiros).

## Design tokens capturados (computed styles)

- Fonte: `Inter, sans-serif`, corpo 14px
- Fundo de página: `rgb(240,244,248)` (#F0F4F8, cinza-azulado bem claro)
- Cor de destaque/link/estado inativo: `rgb(12,173,243)` (#0CADF3, azul vivo)
- Cor de seleção ativa (toggle/botão selecionado): `rgb(5,73,102)` (#054966, azul petróleo escuro)
- Texto padrão: `rgb(92,92,92)` (#5C5C5C — cinza escuro, não preto puro)
- Botões: `border-radius: 6px`, padding `10px 20px`, `font-weight: 700`
- Cards: fundo branco, padding `12px 16px`

Paleta de dois tons de azul (vivo pra ação/link, petróleo escuro pra seleção/ênfase) sobre fundo neutro frio. Contraste de peso tipográfico (700 em botões) compensa ausência de sombra/borda forte.

## Mapa completo de módulos

Sidebar tem 5 grupos. Testado módulo a módulo (conta free do usuário — dois módulos são pagos, ver nota):

**Gestão**
- **Pacientes** — lista com filtro por status (Ativos/Todos/Inativos), busca por nome/tag, local de atendimento
- **Agenda** — 🔒 **pago** (redireciona pra checkout, planos Profissional R$49,90/mês e Premium, cobrança mensal/semestral/anual)
- **Agendamento online** — 🔒 **pago**, mesmo gate

**Fidelização**
- **Chat** — mensageria nutricionista↔paciente, layout tipo WhatsApp (texto, foto, arquivo, áudio), abas Não lidas/Todas
- **Canva** / **Materiais** — biblioteca de materiais educativos pro paciente (Meus/Lâminas Dietbox/Materiais Dietbox), filtro por nome/tag/tipo

**Plano alimentar**
- **Cardápios**, **Refeições**, **Alimentos** — já cobertos na primeira parte deste doc
- **Receitas** — biblioteca própria, separada de Alimentos (Dietbox trata receita como entidade própria; BSNutri já unifica isso em `catalogKind: 'preparation'|'combination'` dentro do próprio catálogo de alimentos — abordagens diferentes, não necessariamente errado nenhum dos dois)

**Prescrições**
- **Modelos de Prescrições** — texto livre de receita/prescrição nutricional
- **Suplementos** — cadastro próprio de suplemento (Meus suplementos)
- **Fitoterápicos** — Meus/Fitoterápicos Dietbox

**Outros cadastros**
- **Modelos de anamnese** — Minhas/Anamneses Dietbox
- **Modelos de QPC** (questionário de padrão de consumo) — 🔒 **pago**, mesmo gate de checkout
- **Solicitações de exames** — Minhas/Solicitações Dietbox, templates de pedido de exame laboratorial
- **Listas de substituição** — ver seção dedicada abaixo, é o achado mais rico deste grupo
- **Farmácias para orçamento** — cadastro de farmácia de manipulação pra cotação (nicho, baixa prioridade pro BSNutri)
- **Formulários offline**, **Tags** — não abertos em detalhe, baixa prioridade

BSNutri não tem hoje: Agenda (existe, é o `CareWorkspace.tsx`, não pago), Chat, Materiais educativos, Receitas como entidade própria, Prescrições/Suplementos/Fitoterápicos, QPC, Farmácias. Não é lista de "falta implementar tudo" — é mapa de onde o BSNutri já cobre (Agenda, parcialmente Anamnese via `form_templates`) e onde é gap real de produto, não só de UX.

## Listas de substituição — terceiro modelo de substituição

Achado mais importante fora do editor de plano. Dietbox tem **três** modelos de substituição, não um:

1. **Por item**, dentro do editor (não vi um equivalente direto — o BSNutri é quem faz isso, `hasReviewedSubstitution` em `EditableMealCard`)
2. **Por refeição inteira**, dentro do Cardápio (`Adicionar Substituição` por refeição, já documentado acima)
3. **Lista de substituição autônoma** (`/pt-BR/ListaSubstituicao`) — cadastro **independente de qualquer plano**, reutilizável entre pacientes. Estrutura:
   - Nome da lista (ex.: "Lista de substituição: Carboidratos")
   - **Grupos** dentro da lista (ex.: Frutas, Refeições intermediárias, Refeições principais)
   - Dentro de cada grupo, sub-tabela por **faixa calórica equivalente** (ex.: "Frutas - Média Calórica: 70 Kcal")
   - Tabela de alimentos nessa faixa: Alimento | Medida Caseira | Qtd. (g/ml) — todos os itens da tabela têm valor calórico equivalente, então são intercambiáveis entre si por definição

Isso é o método clássico de **lista de trocas/equivalência calórica** usado em nutrição clínica (ex.: sistema de trocas da ADA). É estruturalmente mais rigoroso que substituição ad-hoc: a equivalência é a regra de construção da tabela, não uma checagem manual por item. BSNutri não tem esse conceito — hoje a validação de substituição é reativa (`hasReviewedSubstitution`, um checkbox), não construída a partir de uma lista de equivalência calórica pré-validada.

## Prontuário e Gastos energéticos — separação real de estimativa e meta

O "Prontuário" do paciente (`/pt-BR/Patient/Edit/{id}` → botão Prontuário) é um painel único com:
- **Plano alimentar** (planos ativos, com kcal total de cada um já visível na lista, sem abrir)
- **Anamneses** (contador + timeline)
- **Avaliações antropométricas** (contador + timeline, uma delas marcada "disponível no app" — Dietbox tem app do paciente que alimenta essa avaliação diretamente)
- **Gastos energéticos (GET, GEB, TMB)** (contador + timeline) ← **achado principal**
- **Resumo** — texto narrativo auto-gerado a partir dos dados estruturados acima ("Bruno Souza Gonçalves é seu paciente desde 13/12/2025..."), editável, exportável em PDF/impressão

O registro de **Gastos energéticos** é uma entidade própria, versionada, separada do plano:
- Tipo (Adulto/Atleta), Descrição, Data, Altura, Peso atual (snapshot no momento do cálculo)
- **Protocolo** selecionável (ex.: "EER/IOM (2023)" — dropdown sugere múltiplos protocolos científicos disponíveis, não hardcoded)
- **Nível de atividade** com fator numérico visível (ex.: "Inativo (1,4)")
- **Atividades físicas** específicas adicionáveis (ajuste por MET, não só nível genérico)
- Fator de injúria (toggle, pra paciente clínico/hospitalar)
- **Resultado**: EER e EER+MET como dois números, mais "Calcular VENTA" (outro protocolo, expansível)
- **Regra de bolso**: faixas kcal pra perda/ganho de peso calculadas em paralelo à fórmula científica, como sanity-check

Isso é exatamente a separação que o achado 3 da auditoria de 31/07 (`docs/AUDITORIA_MODULO_NUTRITION_2026_07_31.md`) recomendou e que o BSNutri não tem: hoje `targets` em `NutritionWorkspace.tsx` é um número digitado manualmente, sem protocolo, sem rastro de método, sem reprodutibilidade. Dietbox prova que dá pra fazer diferente: estimativa é um registro próprio com protocolo e inputs auditáveis, e o plano alimentar consome esse resultado como ponto de partida pra meta — são duas entidades, não uma.

## Menu por paciente — achados que a primeira passada não pegou

O botão "Adicionar" dentro do prontuário abre um menu que não aparece em nenhum outro lugar do produto — é a navegação real por paciente, diferente do menu lateral global. Revela módulos que os dois primeiros mapeamentos não cobriram:

**FIDELIZAÇÃO**: Aplicativo 🔒, Diário, Metas 🔒, Videoconferência 🔒, Chat, Enviar e-mail
**GESTÃO**: Agenda 🔒, Financeiro 🔒
**OUTROS**: Alerta de hidratação, Materiais, **Lista de compras**, Listas de substituição, Receitas

🔒 = mesmo paywall já documentado (Agenda). Confirma que o padrão de gating é consistente: tudo que depende de agenda/cobrança/telemedicina é pago, cadastro clínico é livre.

### Tipos de avaliação — mais do que os 3 mapeados antes

O modal de "Adicionar avaliação" lista 7 tipos, não 3:
- Questionário pré consulta
- Anamnese
- Avaliação Antropométrica
- Gastos energéticos
- Exames laboratoriais
- **Recordatório alimentar** — ferramenta clínica padrão (registro do que o paciente comeu nas últimas 24h), não mapeada antes. BSNutri não tem esse instrumento. É simples de estruturar (lista de itens consumidos + horário, sem cálculo automático obrigatório) e é uma ferramenta clínica real, não feature de vaidade.
- Avaliação DB360 — ferramenta proprietária do Dietbox (nome de marca), não dá pra saber a fundo sem abrir; não é prioridade replicar algo com nome de produto de terceiro.

E "Adicionar prescrição" lista: Plano alimentar, Prescrições, Metas.

**Achado de UX real**: o modal tem uma frase fixa embaixo — *"Recomendamos realizar uma anamnese, uma avaliação antropométrica e o cálculo de gastos energéticos para elaborar um plano alimentar mais preciso."* — é uma dica de **sequência de trabalho recomendada**, não só uma lista de features soltas. BSNutri não guia o nutri em nenhuma ordem — cada tela é uma ilha. Isso é praticamente texto puro de implementar (uma linha de orientação contextual no editor de plano se as etapas anteriores não existirem) e amarra exatamente as Fases 1 e 2 do plano de implementação numa sequência lógica.

### Export do plano alimentar — gap confirmado no BSNutri

A visualização do plano tem, além de "Ver nutrientes": **Enviar e-mail**, **Salvar em PDF**, **Imprimir**, **Visualizar**. Conferido no código: `NutritionWorkspace.tsx` não tem nenhuma dessas ações — só `PatientDetail.tsx` tem `printClinicalDocument`, e só pro resumo clínico geral, não pro plano alimentar. Ou seja: hoje não existe nenhuma forma de o nutri entregar o plano pro paciente de dentro do BSNutri. É o gap mais básico encontrado até agora — a função central do produto (prescrever e entregar um plano) não tem saída.

### Comparativo — grid semanal com g/kg de peso corporal

A seção "Comparativo" (antes só notada como link não explorado) é um grid por dia da semana, cada card com kcal total e PTN/CHO/LIP em grama + % do VET — já documentado. O que não tinha sido visto: quando o paciente tem peso cadastrado, aparece também **g/kg de peso corporal** por macro (ex.: `PTN 145,42g (38%) — 1,56g/kg`). Essa é a unidade que a literatura clínica realmente usa pra prescrever proteína (ex.: "1,6–2,2 g/kg" pra hipertrofia, "0,8 g/kg" pra RDA geral) — % do VET sozinho não é suficiente pra esse tipo de decisão. BSNutri não calcula isso hoje em lugar nenhum (nem grama, nem %, nem g/kg — só grama absoluta).

### Lista de compras — vitória rápida de alto valor

Gera automaticamente a lista de compras consolidada a partir de todos os itens de todas as refeições do(s) plano(s) ativo(s): nome do alimento + soma de gramas necessárias na semana inteira, ordenado alfabeticamente, com export (Enviar/PDF/Imprimir) e "Configurar lista de compras". Isso é **derivável 100% dos dados que o BSNutri já tem** (`days[].meals[].items[]`) — não precisa de schema novo, é uma função pura de agregação (`groupBy(item.name) → sum(grams)`) mais uma tela de export. Fica pertinho de zero esforço/alto valor percebido pro paciente.

## Leitura pro BSNutri

Não é decisão de implementar tudo — é material de comparação. Pontos que valem considerar na próxima fatia do trabalho:

1. **Ampliar `macroLabels`/nutrientes do catálogo** — hoje 10 chaves, Dietbox usa ~28. Se o público inclui prescrição clínica (dislipidemia, anemia, etc.), faltam sódio já existe mas faltam gorduras por tipo e vitaminas do complexo B.
2. **% do VET nos totais** — mudança pequena em `NutritionWorkspace.tsx`, alto valor percebido pro nutri.
3. **Decidir substituição por item vs por refeição** — hoje BSNutri já implementa por item (mais granular); não é bug, é ver se cobre o caso de uso ou se vale oferecer os dois.
4. **Modo "texto livre"** — avaliar se atende parte dos nutris que só querem prescrever rápido sem montar item a item.
5. **Fontes múltiplas de catálogo** (tipo TACO/IBGE/TBCA) — BSNutri seed atual (`supabase/migrations/20260724180500_diet_catalog_foods_seed.sql`) é provisório; ver se vale importar uma tabela pública padronizada em vez de cadastro manual.
6. **Separar estimativa energética (GET/GEB/TMB) de meta de plano** — maior gap estrutural encontrado. Precisa de entidade própria (protocolo, inputs, resultado, data), não um campo solto em `targets`. Resolve o achado 3 da auditoria de 31/07 de forma concreta, com uma referência real de como implementar.
7. **Lista de substituição por equivalência calórica** — avaliar se cobre melhor o caso de uso clínico do que o checkbox `hasReviewedSubstitution` atual. Não precisa ser os três modelos do Dietbox (item + refeição + lista autônoma) — mas vale decidir qual modelo é o certo pro BSNutri em vez de manter o atual por padrão.
