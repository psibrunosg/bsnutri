# Alimentos — População Brasileira

CSV pronto para importar no BSNutri via **Importar alimentos** (formato: `nome;preparo;energia;proteína;carboidrato;gordura`).

## Conteúdo

- **135 alimentos** representativos do consumo brasileiro (base POF 2017-2018 / IBGE + TBCA)
- Cobertura: cereais, tubérculos, leguminosas, carnes, ovos, pescados, laticínios, frutas, hortaliças, oleaginosas, gorduras, açúcares/doces, bebidas
- Porção de referência: **100 g** (cozido/grelhado/in natura conforme preparo indicado)
- Unidades: **kcal** (energia), **g** (macronutrientes)

## Fonte dos valores

Valores **aproximados** baseados na **Tabela Brasileira de Composição de Alimentos (TBCA/USP)** e USDA SR Legacy. Não são dados oficiais de lote — são médias de literatura para uso de referência.

> ⚠️ **Revisão obrigatória por nutricionista** antes de uso clínico. Variações regionais, marcas, cortes e métodos de preparo alteram significativamente a composição.

## Como importar

1. Abra o BSNutri → **Biblioteca da clínica** → seção **Importar alimentos**
2. Selecione a **Fonte da importação** (ex.: `TBCA 2024`, `POF 2017-18`, `Catálogo interno`)
3. Cole o conteúdo de `alimentos-populacao-brasileira.csv` no campo **Dados para prévia**
4. Confira a prévia (linhas verdes = OK, vermelhas = erro)
5. Clique **Importar prévia validada**

## Estrutura do CSV

```csv
nome;preparo;energia;proteína;carboidrato;gordura
Arroz branco;cozido;130;2.7;28.1;0.3
Feijão carioca;cozido;76;4.8;13.6;0.3
...
```

- Separador: **ponto e vírgula** (`;`)
- Decimal: **ponto** (`.`) ou vírgula (`,`) — ambos aceitos
- Header opcional (ignorado se começar com `nome;`)
- Valores não-negativos; nome ≥ 2 caracteres

## Personalização

Edite o CSV para:
- Ajustar nomes/preparos ao vocabulário da sua clínica
- Adicionar alimentos regionais (ex.: pequi, buriti, tucupi, pirarucu)
- Corrigir valores com base em fichas técnicas de fornecedores
- Remover itens que não usa

## Licença

Dados de composição: domínio público (TBCA/USDA).
Arquivo: uso livre no projeto BSNutri.